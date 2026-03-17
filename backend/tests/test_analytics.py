import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database import Base, get_db
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app import security, models
from datetime import datetime, timedelta, timezone


from app import security, models
from datetime import datetime, timedelta, timezone

@pytest.fixture
def auth_headers(session):
    hashed_password = security.get_password_hash("password")

    super_admin = models.User(
        email="super@example.com", username="super_admin",
        password_hash=hashed_password, role="super_admin", is_banned=False,
    )
    admin_user = models.User(
        email="admin@example.com", username="admin_user",
        password_hash=hashed_password, role="admin", is_banned=False,
    )
    student = models.User(
        email="student@example.com", username="student_user",
        password_hash=hashed_password, role="student", is_banned=False,
    )
    setter_user = models.User(
        email="setter@example.com", username="setter_user",
        password_hash=hashed_password, role="setter", is_banned=False,
    )

    session.add_all([super_admin, admin_user, student, setter_user])
    session.commit()

    tokens = {
        "super_admin": security.create_access_token(data={"sub": "super@example.com", "role": "super_admin"}),
        "admin": security.create_access_token(data={"sub": "admin@example.com", "role": "admin"}),
        "student": security.create_access_token(data={"sub": "student@example.com", "role": "student"}),
        "setter": security.create_access_token(data={"sub": "setter@example.com", "role": "setter"}),
    }

    return {role: {"Cookie": f"access_token={token}"} for role, token in tokens.items()}


@pytest.fixture
def seeded_data(session):
    """Seed zones, routes, ascents, and ratings for analytics queries."""
    hashed_password = security.get_password_hash("password")

    user = models.User(
        email="climber@example.com", username="climber",
        password_hash=hashed_password, role="student", is_banned=False,
    )
    session.add(user)
    session.flush()

    zone_a = models.Zone(name="Zone A", description="Bouldering", route_type="boulder")
    zone_b = models.Zone(name="Zone B", description="Top rope", route_type="top_rope")
    session.add_all([zone_a, zone_b])
    session.flush()

    route_v3 = models.Route(zone_id=zone_a.id, color="Red", intended_grade="V3", status="active")
    route_v5 = models.Route(zone_id=zone_a.id, color="Blue", intended_grade="V5", status="active")
    route_archived = models.Route(zone_id=zone_b.id, color="Green", intended_grade="5.10a", status="archived")
    session.add_all([route_v3, route_v5, route_archived])
    session.flush()

    # Add ascents — some today, some in the past
    today = datetime.now(timezone.utc)
    yesterday = today - timedelta(days=1)
    session.add(models.Ascent(user_id=user.id, route_id=route_v3.id, ascent_type="boulder", date=today))
    session.add(models.Ascent(user_id=user.id, route_id=route_v3.id, ascent_type="boulder", date=yesterday))
    session.add(models.Ascent(user_id=user.id, route_id=route_v5.id, ascent_type="boulder", date=today))

    # Add ratings
    session.add(models.RouteRating(user_id=user.id, route_id=route_v3.id, rating=4))

    session.commit()


# --- Normal Cases ---

def test_getAnalytics_superAdmin_returnsAllMetrics(client, auth_headers, seeded_data):
    """Super admin gets analytics with seeded data — all fields present and correctly shaped."""
    response = client.get("/admin/analytics", headers=auth_headers["super_admin"])
    assert response.status_code == 200

    data = response.json()
    assert "grade_distribution" in data
    assert "ascents_by_grade" in data
    assert "route_status" in data
    assert "zone_utilization" in data
    assert "activity_trend" in data
    assert "rating_distribution" in data
    assert "top_rated_routes" in data


def test_getAnalytics_gradeDistribution_countsActiveRoutes(client, auth_headers, seeded_data):
    """Grade distribution should only count active routes."""
    response = client.get("/admin/analytics?status=active", headers=auth_headers["super_admin"])
    data = response.json()

    grades = {item["grade"]: item["count"] for item in data["grade_distribution"]}
    # V3 and V5 are active; 5.10a is archived
    assert grades.get("V3") == 1
    assert grades.get("V5") == 1
    assert "5.10a" not in grades


def test_getAnalytics_routeStatus_correctBreakdown(client, auth_headers, seeded_data):
    """Route status should correctly split active and archived."""
    response = client.get("/admin/analytics", headers=auth_headers["super_admin"])
    data = response.json()

    assert data["route_status"]["active"] == 2
    assert data["route_status"]["archived"] == 1


def test_getAnalytics_ascentsByGrade_groupsCorrectly(client, auth_headers, seeded_data):
    """Ascents by grade should total ascents per route grade."""
    response = client.get("/admin/analytics", headers=auth_headers["super_admin"])
    data = response.json()

    ascents = {item["grade"]: item["count"] for item in data["ascents_by_grade"]}
    assert ascents.get("V3") == 2  # 2 ascents on V3 route
    assert ascents.get("V5") == 1  # 1 ascent on V5 route


def test_getAnalytics_activityTrend_has30Days(client, auth_headers, seeded_data):
    """Activity trend should always return exactly 30 data points."""
    response = client.get("/admin/analytics", headers=auth_headers["super_admin"])
    data = response.json()

    assert len(data["activity_trend"]) == 30
    # Each entry should have date and count
    for point in data["activity_trend"]:
        assert "date" in point
        assert "count" in point


def test_getAnalytics_ratingDistribution_allFiveStars(client, auth_headers, seeded_data):
    """Rating distribution should return entries for all 5 ratings (1-5)."""
    response = client.get("/admin/analytics", headers=auth_headers["super_admin"])
    data = response.json()

    ratings = {item["rating"]: item["count"] for item in data["rating_distribution"]}
    assert len(data["rating_distribution"]) == 5
    assert ratings.get(4) == 1  # We seeded one 4-star rating
    assert ratings.get(1) == 0
    assert ratings.get(5) == 0


def test_getAnalytics_topRatedRoutes_orderAndFields(client, auth_headers, seeded_data):
    """Top rated routes should include route_id, grade, color, avg_rating, rating_count."""
    response = client.get("/admin/analytics", headers=auth_headers["super_admin"])
    data = response.json()

    assert len(data["top_rated_routes"]) >= 1
    top = data["top_rated_routes"][0]
    assert "route_id" in top
    assert "grade" in top
    assert "color" in top
    assert "avg_rating" in top
    assert "rating_count" in top
    assert top["avg_rating"] == 4.0


# --- Edge Cases ---

def test_getAnalytics_emptyDatabase_returnsZeros(client, auth_headers):
    """With no routes/ascents/ratings, analytics should return empty/zero — no 500 errors."""
    response = client.get("/admin/analytics", headers=auth_headers["super_admin"])
    assert response.status_code == 200

    data = response.json()
    assert data["grade_distribution"] == []
    assert data["ascents_by_grade"] == []
    assert data["route_status"]["active"] == 0
    assert data["route_status"]["archived"] == 0
    assert data["zone_utilization"] == []
    assert len(data["activity_trend"]) == 30
    assert all(p["count"] == 0 for p in data["activity_trend"])
    assert len(data["rating_distribution"]) == 5
    assert all(r["count"] == 0 for r in data["rating_distribution"])
    assert data["top_rated_routes"] == []


# --- Extraordinary Cases (Sad Path) ---

def test_getAnalytics_studentRole_returns403(client, auth_headers):
    """Student role should be denied access."""
    response = client.get("/admin/analytics", headers=auth_headers["student"])
    assert response.status_code == 403


def test_getAnalytics_adminRole_returns403(client, auth_headers):
    """Regular admin role should be denied access — super admin only."""
    response = client.get("/admin/analytics", headers=auth_headers["admin"])
    assert response.status_code == 403


def test_getAnalytics_setterRole_returns403(client, auth_headers):
    """Setter role should be denied access."""
    response = client.get("/admin/analytics", headers=auth_headers["setter"])
    assert response.status_code == 403


def test_getAnalytics_unauthenticated_returns401(client):
    """Unauthenticated request should get 401."""
    response = client.get("/admin/analytics")
    assert response.status_code == 401
