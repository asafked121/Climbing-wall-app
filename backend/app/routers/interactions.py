from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from app import models, schemas
from app.database import get_db
from app.dependencies import get_current_active_user

router = APIRouter(prefix="/routes", tags=["interactions"])


@router.post(
    "/{route_id}/votes",
    response_model=schemas.GradeVoteResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_vote(
    route_id: int,
    vote: schemas.GradeVoteCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user),
):
    db_route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not db_route:
        raise HTTPException(status_code=404, detail="Route not found")

    existing_vote = (
        db.query(models.GradeVote)
        .filter(
            models.GradeVote.user_id == current_user.id,
            models.GradeVote.route_id == route_id,
        )
        .first()
    )

    if existing_vote:
        existing_vote.voted_grade = vote.voted_grade
        db.commit()
        db.refresh(existing_vote)
        return existing_vote

    db_vote = models.GradeVote(
        user_id=current_user.id, route_id=route_id, voted_grade=vote.voted_grade
    )
    try:
        db.add(db_vote)
        db.commit()
        db.refresh(db_vote)
        return db_vote
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Error saving vote")


@router.post(
    "/{route_id}/comments",
    response_model=schemas.CommentResponse,
    status_code=status.HTTP_201_CREATED,
)
def post_comment(
    route_id: int,
    comment: schemas.CommentCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user),
):
    db_route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not db_route:
        raise HTTPException(status_code=404, detail="Route not found")

    db_comment = models.Comment(
        user_id=current_user.id, route_id=route_id, content=comment.content
    )
    db.add(db_comment)
    db.commit()
    db.refresh(db_comment)
    return db_comment


@router.post(
    "/{route_id}/ratings",
    response_model=schemas.RouteRatingResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_rating(
    route_id: int,
    rating: schemas.RouteRatingCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user),
):
    db_route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not db_route:
        raise HTTPException(status_code=404, detail="Route not found")

    existing_rating = (
        db.query(models.RouteRating)
        .filter(
            models.RouteRating.user_id == current_user.id,
            models.RouteRating.route_id == route_id,
        )
        .first()
    )

    if existing_rating:
        existing_rating.rating = rating.rating
        db.commit()
        db.refresh(existing_rating)
        return existing_rating

    db_rating = models.RouteRating(
        user_id=current_user.id, route_id=route_id, rating=rating.rating
    )
    try:
        db.add(db_rating)
        db.commit()
        db.refresh(db_rating)
        return db_rating
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Error saving rating")


@router.post(
    "/{route_id}/ascents",
    response_model=schemas.AscentResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_ascent(
    route_id: int,
    ascent: schemas.AscentCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user),
):
    db_route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not db_route:
        raise HTTPException(status_code=404, detail="Route not found")

    db_zone = db.query(models.Zone).filter(models.Zone.id == db_route.zone_id).first()
    if not db_zone:
        raise HTTPException(status_code=404, detail="Zone not found")

    # Constraint: Restrict Lead climbing to specific zones
    if ascent.ascent_type == "lead" and not db_zone.allows_lead:
        raise HTTPException(
            status_code=400,
            detail="Lead climbing is not allowed in this zone",
        )

    # Constraint: Cannot log same type twice
    existing_ascents = (
        db.query(models.Ascent)
        .filter(
            models.Ascent.user_id == current_user.id, models.Ascent.route_id == route_id
        )
        .all()
    )

    for ea in existing_ascents:
        if ea.ascent_type == ascent.ascent_type:
            raise HTTPException(
                status_code=400,
                detail=f"You have already logged this route as {ascent.ascent_type}",
            )

    db_ascent = models.Ascent(
        user_id=current_user.id, route_id=route_id, ascent_type=ascent.ascent_type
    )
    db.add(db_ascent)
    db.commit()
    db.refresh(db_ascent)
    return db_ascent


@router.delete("/ascents/{ascent_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_ascent(
    ascent_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user),
):
    db_ascent = db.query(models.Ascent).filter(models.Ascent.id == ascent_id).first()
    if not db_ascent:
        raise HTTPException(status_code=404, detail="Ascent not found")
    if db_ascent.user_id != current_user.id and current_user.role not in [
        "admin",
        "super_admin",
    ]:
        raise HTTPException(
            status_code=403, detail="Not authorized to delete this ascent"
        )

    db.delete(db_ascent)
    db.commit()
    return


@router.get("/user/{user_id}/ascents", response_model=list[schemas.AscentResponse])
def get_user_ascents(user_id: int, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    ascents = db.query(models.Ascent).filter(models.Ascent.user_id == user_id).all()
    return ascents
