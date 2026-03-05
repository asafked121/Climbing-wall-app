from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, case
from datetime import datetime, date, timedelta, timezone
from typing import Optional

from app import models, schemas
from app.database import get_db
from app.dependencies import get_current_super_admin

router = APIRouter(prefix="/admin", tags=["analytics"])


def _base_route_query(db: Session, status: Optional[str], route_type: Optional[str],
                      date_from: Optional[date], date_to: Optional[date]):
    """Return a base query on Route with optional filters applied."""
    query = db.query(models.Route)
    if status:
        query = query.filter(models.Route.status == status)
    if route_type:
        query = query.join(models.Zone, models.Route.zone_id == models.Zone.id).filter(
            models.Zone.route_type == route_type
        )
    if date_from:
        query = query.filter(models.Route.set_date >= date_from)
    if date_to:
        query = query.filter(models.Route.set_date <= date_to)
    return query


def _apply_route_filters(query, status: Optional[str], route_type: Optional[str],
                         date_from: Optional[date], date_to: Optional[date]):
    """Apply route filters to a query that already has Route joined."""
    if status:
        query = query.filter(models.Route.status == status)
    if route_type:
        query = query.join(models.Zone, models.Route.zone_id == models.Zone.id).filter(
            models.Zone.route_type == route_type
        )
    if date_from:
        query = query.filter(models.Route.set_date >= date_from)
    if date_to:
        query = query.filter(models.Route.set_date <= date_to)
    return query


def _build_grade_distribution(db, status, route_type, date_from, date_to) -> list[dict]:
    """Count of routes per intended grade."""
    query = _base_route_query(db, status, route_type, date_from, date_to)
    rows = (
        query.with_entities(models.Route.intended_grade, func.count(models.Route.id))
        .group_by(models.Route.intended_grade)
        .all()
    )
    return [{"grade": grade, "count": count} for grade, count in rows]


def _build_ascents_by_grade(db, status, route_type, date_from, date_to) -> list[dict]:
    """Total ascents grouped by the route's intended grade."""
    query = _base_route_query(db, status, route_type, date_from, date_to)
    rows = (
        query.with_entities(models.Route.intended_grade, func.count(models.Ascent.id))
        .join(models.Ascent, models.Ascent.route_id == models.Route.id)
        .group_by(models.Route.intended_grade)
        .all()
    )
    return [{"grade": grade, "count": count} for grade, count in rows]


def _build_route_status(db, route_type, date_from, date_to) -> dict:
    """Active vs archived route counts (ignores the status filter itself)."""
    query = db.query(models.Route)
    if route_type:
        query = query.join(models.Zone, models.Route.zone_id == models.Zone.id).filter(
            models.Zone.route_type == route_type
        )
    if date_from:
        query = query.filter(models.Route.set_date >= date_from)
    if date_to:
        query = query.filter(models.Route.set_date <= date_to)
    rows = (
        query.with_entities(
            func.sum(case((models.Route.status == "active", 1), else_=0)).label("active"),
            func.sum(case((models.Route.status == "archived", 1), else_=0)).label("archived"),
        )
        .one()
    )
    return {"active": rows.active or 0, "archived": rows.archived or 0}


def _build_zone_utilization(db, status, route_type, date_from, date_to) -> list[dict]:
    """Route count per zone with filters."""
    join_conditions = [models.Route.zone_id == models.Zone.id]
    if status:
        join_conditions.append(models.Route.status == status)
    if date_from:
        join_conditions.append(models.Route.set_date >= date_from)
    if date_to:
        join_conditions.append(models.Route.set_date <= date_to)

    combined = join_conditions[0]
    for cond in join_conditions[1:]:
        combined = combined & cond

    query = (
        db.query(models.Zone.name, func.count(models.Route.id))
        .outerjoin(models.Route, combined)
    )
    if route_type:
        query = query.filter(models.Zone.route_type == route_type)
    rows = (
        query.group_by(models.Zone.id, models.Zone.name)
        .all()
    )
    return [{"zone": name, "count": count} for name, count in rows]


def _build_activity_trend(db, status, route_type, date_from, date_to) -> list[dict]:
    """Ascents per day for the last 30 days, with zero-fill for missing days."""
    today = datetime.now(timezone.utc).date()
    start_date = today - timedelta(days=29)

    query = (
        db.query(func.date(models.Ascent.date).label("day"), func.count(models.Ascent.id))
        .filter(func.date(models.Ascent.date) >= start_date)
    )

    if status or route_type or date_from or date_to:
        query = query.join(models.Route, models.Route.id == models.Ascent.route_id)
        query = _apply_route_filters(query, status, route_type, date_from, date_to)

    rows = query.group_by(func.date(models.Ascent.date)).all()
    counts_by_day = {str(day): count for day, count in rows}

    trend = []
    for offset in range(30):
        day = start_date + timedelta(days=offset)
        day_str = str(day)
        trend.append({"date": day_str, "count": counts_by_day.get(day_str, 0)})
    return trend


def _build_rating_distribution(db, status, route_type, date_from, date_to) -> list[dict]:
    """Count of each star rating (1–5)."""
    query = db.query(models.RouteRating.rating, func.count(models.RouteRating.id))

    if status or route_type or date_from or date_to:
        query = query.join(models.Route, models.Route.id == models.RouteRating.route_id)
        query = _apply_route_filters(query, status, route_type, date_from, date_to)

    rows = query.group_by(models.RouteRating.rating).all()
    counts = {rating: count for rating, count in rows}
    return [{"rating": r, "count": counts.get(r, 0)} for r in range(1, 6)]


def _build_top_rated_routes(db, status, route_type, date_from, date_to) -> list[dict]:
    """Top 5 routes by average rating (minimum 1 rating)."""
    query = (
        db.query(
            models.Route.id,
            models.Route.intended_grade,
            models.Route.color,
            func.avg(models.RouteRating.rating).label("avg_rating"),
            func.count(models.RouteRating.id).label("rating_count"),
        )
        .join(models.RouteRating, models.RouteRating.route_id == models.Route.id)
    )
    query = _apply_route_filters(query, status, route_type, date_from, date_to)

    rows = (
        query.group_by(models.Route.id)
        .order_by(func.avg(models.RouteRating.rating).desc())
        .limit(5)
        .all()
    )
    return [
        {
            "route_id": row.id,
            "grade": row.intended_grade,
            "color": row.color,
            "avg_rating": round(float(row.avg_rating), 2),
            "rating_count": row.rating_count,
        }
        for row in rows
    ]


@router.get("/analytics", response_model=schemas.AnalyticsResponse)
def get_analytics(
    status: Optional[str] = Query(None, description="Filter by route status: 'active' or 'archived'"),
    route_type: Optional[str] = Query(None, description="Filter by route type: 'boulder' or 'top_rope'"),
    date_from: Optional[date] = Query(None, description="Filter routes set on or after this date (YYYY-MM-DD)"),
    date_to: Optional[date] = Query(None, description="Filter routes set on or before this date (YYYY-MM-DD)"),
    db: Session = Depends(get_db),
    current_super_admin: models.User = Depends(get_current_super_admin),
):
    """Aggregated analytics data — super admin only."""
    return schemas.AnalyticsResponse(
        grade_distribution=_build_grade_distribution(db, status, route_type, date_from, date_to),
        ascents_by_grade=_build_ascents_by_grade(db, status, route_type, date_from, date_to),
        route_status=_build_route_status(db, route_type, date_from, date_to),
        zone_utilization=_build_zone_utilization(db, status, route_type, date_from, date_to),
        activity_trend=_build_activity_trend(db, status, route_type, date_from, date_to),
        rating_distribution=_build_rating_distribution(db, status, route_type, date_from, date_to),
        top_rated_routes=_build_top_rated_routes(db, status, route_type, date_from, date_to),
    )
