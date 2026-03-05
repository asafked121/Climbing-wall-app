from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
import os
from sqlalchemy.orm import Session
from typing import List, Optional
from app import models, schemas
from app.database import get_db
from app.dependencies import get_current_user, get_optional_current_user, get_current_setter_or_admin

BOULDER_GRADES = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12"]
TOP_ROPE_GRADES = [
    "5.5", "5.6", "5.7", "5.8", "5.9",
    "5.10a", "5.10b", "5.10c", "5.10d",
    "5.11a", "5.11b", "5.11c", "5.11d",
    "5.12a", "5.12b", "5.12c", "5.12d",
]
GRADES_BY_TYPE = {"boulder": BOULDER_GRADES, "top_rope": TOP_ROPE_GRADES}

router = APIRouter(prefix="/routes", tags=["routes"])


def _resolve_color_name(db: Session, hex_value: str) -> str:
    """Look up the human-readable color name for a hex value from the colors table."""
    color = db.query(models.Color).filter(models.Color.hex_value == hex_value).first()
    return color.name if color else hex_value


def _attach_color_name(db: Session, route_obj):
    """Attach color_name to a route ORM object for serialization."""
    route_obj.color_name = _resolve_color_name(db, route_obj.color)
    return route_obj

@router.get("", response_model=List[schemas.RouteSummaryResponse])
def get_routes(
    zone_id: Optional[int] = None,
    intended_grade: Optional[str] = None,
    status: Optional[str] = "active",
    route_type: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_current_user)
):
    query = db.query(models.Route)
    
    if status and status != "all":
        query = query.filter(models.Route.status == status)
    
    if zone_id is not None:
        query = query.filter(models.Route.zone_id == zone_id)
    if intended_grade is not None:
        query = query.filter(models.Route.intended_grade == intended_grade)
    if route_type is not None:
        zone_ids = [z.id for z in db.query(models.Zone).filter(models.Zone.route_type == route_type).all()]
        query = query.filter(models.Route.zone_id.in_(zone_ids))
        
    routes = query.all()
    for route in routes:
        _attach_color_name(db, route)
    return routes

@router.get("/colors", response_model=List[schemas.ColorResponse])
def get_colors(db: Session = Depends(get_db)):
    return db.query(models.Color).all()

@router.get("/grades")
def get_grades_for_zone(zone_id: int, db: Session = Depends(get_db)):
    zone = db.query(models.Zone).filter(models.Zone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")
    return GRADES_BY_TYPE.get(zone.route_type, [])

@router.get("/zones", response_model=List[schemas.ZoneResponse])
def get_zones(db: Session = Depends(get_db), current_user: Optional[models.User] = Depends(get_optional_current_user)):
    return db.query(models.Zone).all()

@router.get("/{route_id}", response_model=schemas.RouteDetailResponse)
def get_route(route_id: int, db: Session = Depends(get_db), current_user: Optional[models.User] = Depends(get_optional_current_user)):
    db_route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not db_route:
        raise HTTPException(status_code=404, detail="Route not found")
    _attach_color_name(db, db_route)
    return db_route

@router.post("/{route_id}/photo", response_model=schemas.RouteDetailResponse)
async def upload_route_photo(
    route_id: int, 
    file: UploadFile = File(...), 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_setter_or_admin)
):
    db_route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not db_route:
        raise HTTPException(status_code=404, detail="Route not found")
        
    zone = db.query(models.Zone).filter(models.Zone.id == db_route.zone_id).first()
    route_type = zone.route_type if zone else "unknown"
    grade = db_route.intended_grade.replace(".", "_") # sanitize path
    
    directory = f"photos/{route_type}/{grade}"
    os.makedirs(directory, exist_ok=True)
    
    file_extension = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"route_{route_id}.{file_extension}"
    file_path = os.path.join(directory, filename)
    
    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)
        
    db_route.photo_url = f"/{file_path}"
    db.commit()
    db.refresh(db_route)
    
    return db_route
