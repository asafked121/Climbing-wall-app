from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
import os
import secrets
import json

from app.database import get_db
from app.models import User, CustomRoute, CustomRouteVote, CustomRouteComment
from app.schemas import (
    CustomRouteCreate, CustomRouteResponse, CustomRouteDetailResponse,
    CustomRouteVoteCreate, CustomRouteCommentCreate, CustomRouteCommentResponse, CustomRouteVoteResponse
)
from app.dependencies import get_current_user
import cv2
import numpy as np

router = APIRouter(
    prefix="/custom-routes",
    tags=["custom-routes"]
)

@router.post("/detect-holds", summary="Detect holds using OpenCV")
async def detect_holds(file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    """
    Detect climbing holds using a multi-strategy OpenCV approach:
    1. HSV color saturation to find colorful holds against neutral walls
    2. Adaptive thresholding for contrast-based detection
    3. Morphological operations to clean up noise
    4. Merge nearby detections to avoid duplicates
    """
    if not file.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File provided is not an image.")

    contents = await file.read()

    np_img = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(np_img, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Cannot decode image.")

    height, width = img.shape[:2]

    # Scale the minimum area thresholds relative to image size
    image_area = height * width
    min_hold_area = image_area * 0.0002   # 0.02% of image — catches small holds
    max_hold_area = image_area * 0.10     # 10% of image

    all_candidates = []

    # --- Strategy 1: HSV saturation-based detection (finds colorful holds) ---
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    # Climbing holds are usually colorful; walls are neutral/gray
    saturation = hsv[:, :, 1]
    _, sat_mask = cv2.threshold(saturation, 60, 255, cv2.THRESH_BINARY)

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    sat_mask = cv2.morphologyEx(sat_mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    sat_mask = cv2.morphologyEx(sat_mask, cv2.MORPH_OPEN, kernel, iterations=1)

    contours_sat, _ = cv2.findContours(sat_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in contours_sat:
        area = cv2.contourArea(c)
        if min_hold_area < area < max_hold_area:
            M = cv2.moments(c)
            if M["m00"] != 0:
                cX = int(M["m10"] / M["m00"])
                cY = int(M["m01"] / M["m00"])
                _, radius = cv2.minEnclosingCircle(c)
                all_candidates.append({"x": cX, "y": cY, "radius": int(max(radius, 8))})

    # --- Strategy 2: Adaptive thresholding (finds holds by contrast) ---
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (9, 9), 0)
    adaptive = cv2.adaptiveThreshold(
        blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 31, 10
    )

    adaptive = cv2.morphologyEx(adaptive, cv2.MORPH_CLOSE, kernel, iterations=2)
    adaptive = cv2.morphologyEx(adaptive, cv2.MORPH_OPEN, kernel, iterations=1)

    contours_adapt, _ = cv2.findContours(adaptive, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in contours_adapt:
        area = cv2.contourArea(c)
        if min_hold_area < area < max_hold_area:
            M = cv2.moments(c)
            if M["m00"] != 0:
                cX = int(M["m10"] / M["m00"])
                cY = int(M["m01"] / M["m00"])
                _, radius = cv2.minEnclosingCircle(c)
                all_candidates.append({"x": cX, "y": cY, "radius": int(max(radius, 8))})

    # --- Merge nearby candidates (avoid duplicates from multi-strategy) ---
    def _merge_candidates(candidates, merge_distance):
        if not candidates:
            return []
        merged = []
        used = [False] * len(candidates)
        for i, c1 in enumerate(candidates):
            if used[i]:
                continue
            group = [c1]
            used[i] = True
            for j, c2 in enumerate(candidates):
                if used[j] or i == j:
                    continue
                dist = ((c1["x"] - c2["x"]) ** 2 + (c1["y"] - c2["y"]) ** 2) ** 0.5
                if dist < merge_distance:
                    group.append(c2)
                    used[j] = True
            avg_x = int(sum(g["x"] for g in group) / len(group))
            avg_y = int(sum(g["y"] for g in group) / len(group))
            avg_r = int(sum(g["radius"] for g in group) / len(group))
            merged.append({"x": avg_x, "y": avg_y, "radius": max(avg_r, 8)})
        return merged

    merge_dist = max(width, height) * 0.03  # 3% of the larger dimension
    holds_merged = _merge_candidates(all_candidates, merge_dist)

    # Assign IDs
    holds = [
        {"id": secrets.token_hex(4), "x": h["x"], "y": h["y"], "radius": h["radius"]}
        for h in holds_merged
    ]

    # Save the image so the frontend can use it immediately
    random_hex = secrets.token_hex(8)
    _, ext = os.path.splitext(file.filename)
    filename = f"{random_hex}{ext}"
    filepath = os.path.join("data/photos", filename)

    with open(filepath, "wb") as f:
        f.write(contents)

    return {
        "photo_url": f"/photos/{filename}",
        "holds": holds
    }


@router.post("/", response_model=CustomRouteResponse, status_code=status.HTTP_201_CREATED)
def create_custom_route(route: CustomRouteCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_route = CustomRoute(
        **route.model_dump(),
        user_id=current_user.id
    )
    db.add(db_route)
    db.commit()
    db.refresh(db_route)
    return db_route


@router.get("/", response_model=List[CustomRouteResponse])
def get_custom_routes(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    # Get recent custom routes
    routes = db.query(CustomRoute).order_by(CustomRoute.created_at.desc()).offset(skip).limit(limit).all()
    return routes


@router.get("/{route_id}", response_model=CustomRouteDetailResponse)
def get_custom_route(route_id: int, db: Session = Depends(get_db)):
    route = db.query(CustomRoute).filter(CustomRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Custom route not found")
    return route


@router.post("/{route_id}/vote", response_model=CustomRouteVoteResponse)
def vote_custom_route(route_id: int, vote: CustomRouteVoteCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    route = db.query(CustomRoute).filter(CustomRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Custom route not found")
        
    existing_vote = db.query(CustomRouteVote).filter(
        CustomRouteVote.user_id == current_user.id,
        CustomRouteVote.custom_route_id == route_id
    ).first()

    if existing_vote:
        existing_vote.voted_grade = vote.voted_grade
        db.commit()
        db.refresh(existing_vote)
        return existing_vote
    else:
        new_vote = CustomRouteVote(
            custom_route_id=route_id,
            user_id=current_user.id,
            voted_grade=vote.voted_grade
        )
        db.add(new_vote)
        db.commit()
        db.refresh(new_vote)
        return new_vote


@router.post("/{route_id}/comment", response_model=CustomRouteCommentResponse)
def comment_custom_route(route_id: int, comment: CustomRouteCommentCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    route = db.query(CustomRoute).filter(CustomRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Custom route not found")
        
    new_comment = CustomRouteComment(
        custom_route_id=route_id,
        user_id=current_user.id,
        content=comment.content
    )
    db.add(new_comment)
    db.commit()
    db.refresh(new_comment)
    return new_comment
