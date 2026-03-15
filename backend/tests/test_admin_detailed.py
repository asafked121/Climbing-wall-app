import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database import Base, get_db
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app import security, models
import os

from app.database import Base, get_db, engine, SessionLocal as TestingSessionLocal

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def auth_headers(setup_db):
    db = TestingSessionLocal()
    # Create an admin user
    hashed_password = security.get_password_hash("password")
    admin_user = models.User(email="admin@example.com", username="admin_testing", password_hash=hashed_password, role="admin", is_banned=False)
    admin_user_2 = models.User(email="admin2@example.com", username="admin_testing2", password_hash=hashed_password, role="admin", is_banned=False)
    super_admin = models.User(email="super@example.com", username="super_admin", password_hash=hashed_password, role="super_admin", is_banned=False)
    student = models.User(email="student@example.com", username="student_user", password_hash=hashed_password, role="student", is_banned=False)
    setter_user = models.User(email="setter@example.com", username="setter_user", password_hash=hashed_password, role="setter", is_banned=False)
    
    db.add(admin_user)
    db.add(admin_user_2)
    db.add(super_admin)
    db.add(student)
    db.add(setter_user)
    db.commit()
    
    access_token_admin = security.create_access_token(data={"sub": "admin@example.com", "role": "admin"})
    access_token_super = security.create_access_token(data={"sub": "super@example.com", "role": "super_admin"})
    access_token_setter = security.create_access_token(data={"sub": "setter@example.com", "role": "setter"})
    access_token_student = security.create_access_token(data={"sub": "student@example.com", "role": "student"})
    db.close()
    
    return {
        "admin": {"Cookie": f"access_token={access_token_admin}"},
        "super_admin": {"Cookie": f"access_token={access_token_super}"},
        "setter": {"Cookie": f"access_token={access_token_setter}"},
        "student": {"Cookie": f"access_token={access_token_student}"},
    }

def test_get_users(auth_headers):
    # Test getting all users
    response = client.get("/admin/users", headers=auth_headers["admin"])
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 3 # admin, super, student

def test_ban_user(auth_headers):
    db = TestingSessionLocal()
    student = db.query(models.User).filter_by(email="student@example.com").first()
    student_id = student.id
    db.close()

    # Admin bans student
    response = client.patch(f"/admin/users/{student_id}/ban", json={"is_banned": True}, headers=auth_headers["admin"])
    assert response.status_code == 200
    assert response.json()["is_banned"] is True

    # Check login fails for banned user
    login_response = client.post("/auth/login", json={"email": "student@example.com", "password": "password"})
    assert login_response.status_code == 403
    assert login_response.json()["detail"] == "User is banned"

def test_ban_super_admin_fails(auth_headers):
    db = TestingSessionLocal()
    super_admin = db.query(models.User).filter_by(email="super@example.com").first()
    super_admin_id = super_admin.id
    db.close()

    response = client.patch(f"/admin/users/{super_admin_id}/ban", json={"is_banned": True}, headers=auth_headers["admin"])
    assert response.status_code == 403
    assert response.json()["detail"] == "Cannot ban super admins"

def test_admin_cannot_ban_admin(auth_headers):
    db = TestingSessionLocal()
    admin_2 = db.query(models.User).filter_by(email="admin2@example.com").first()
    admin_2_id = admin_2.id
    db.close()

    response = client.patch(f"/admin/users/{admin_2_id}/ban", json={"is_banned": True}, headers=auth_headers["admin"])
    assert response.status_code == 403
    assert response.json()["detail"] == "Admins cannot ban other admins"

def test_role_update_student_to_setter(auth_headers):
    db = TestingSessionLocal()
    student = db.query(models.User).filter_by(email="student@example.com").first()
    student_id = student.id
    db.close()

    # Admin makes student a setter
    response = client.patch(f"/admin/users/{student_id}/role", json={"role": "setter"}, headers=auth_headers["admin"])
    assert response.status_code == 200
    assert response.json()["role"] == "setter"

def test_admin_cannot_promote_to_admin(auth_headers):
    db = TestingSessionLocal()
    student = db.query(models.User).filter_by(email="student@example.com").first()
    student_id = student.id
    db.close()

    # Admin attempts to make student an admin
    response = client.patch(f"/admin/users/{student_id}/role", json={"role": "admin"}, headers=auth_headers["admin"])
    assert response.status_code == 403

def test_super_admin_can_promote_to_admin(auth_headers):
    db = TestingSessionLocal()
    student = db.query(models.User).filter_by(email="student@example.com").first()
    student_id = student.id
    db.close()

    # Super Admin makes student an admin
    response = client.patch(f"/admin/users/{student_id}/role", json={"role": "admin"}, headers=auth_headers["super_admin"])
    assert response.status_code == 200
    assert response.json()["role"] == "admin"

def test_route_update(auth_headers):
    # Setup Zone and Setter
    zone_response = client.post("/admin/zones", json={"name": "Testing Zone", "description": "Desc"}, headers=auth_headers["admin"])
    zone_id = zone_response.json()["id"]

    setter_response = client.post("/admin/setters", json={"name": "John Doe", "is_active": True}, headers=auth_headers["admin"])
    setter_id = setter_response.json()["id"]

    route_response = client.post("/admin/routes", json={"zone_id": zone_id, "setter_id": setter_id, "color": "Blue", "intended_grade": "V4"}, headers=auth_headers["admin"])
    route_id = route_response.json()["id"]

    # Test Patch
    update_response = client.patch(f"/admin/routes/{route_id}", json={"color": "Red", "intended_grade": "V5"}, headers=auth_headers["admin"])
    
    assert update_response.status_code == 200
    assert update_response.json()["color"] == "Red"
    assert update_response.json()["intended_grade"] == "V5"
    assert update_response.json()["zone_id"] == zone_id
    assert update_response.json()["setter_id"] == setter_id

def test_create_and_get_setters(auth_headers):
    response = client.post("/admin/setters", json={"name": "Sally Setter", "is_active": True}, headers=auth_headers["admin"])
    assert response.status_code == 201
    assert response.json()["name"] == "Sally Setter"

    response_get = client.get("/admin/setters", headers=auth_headers["admin"])
    assert response_get.status_code == 200
    # There could be John Doe from earlier tests, but length should be >= 1
    assert len(response_get.json()) >= 1

# --- Setter Role Route Management Tests ---

def test_setter_canCreateRoute_Normal(auth_headers):
    """Setter role should be able to create routes via /admin/routes."""
    # Admin creates the zone (setters can't create zones)
    zone_response = client.post("/admin/zones", json={"name": "Setter Zone", "description": "For setters"}, headers=auth_headers["admin"])
    assert zone_response.status_code == 201
    zone_id = zone_response.json()["id"]

    # Setter creates a route
    route_response = client.post("/admin/routes", json={
        "zone_id": zone_id, "color": "Green", "intended_grade": "V3"
    }, headers=auth_headers["setter"])
    assert route_response.status_code == 201
    assert route_response.json()["color"] == "Green"
    assert route_response.json()["intended_grade"] == "V3"

def test_setter_canUpdateRoute_Normal(auth_headers):
    """Setter role should be able to update existing routes."""
    zone_response = client.post("/admin/zones", json={"name": "Update Zone", "description": "Desc"}, headers=auth_headers["admin"])
    zone_id = zone_response.json()["id"]

    # Admin creates a route
    route_response = client.post("/admin/routes", json={
        "zone_id": zone_id, "color": "Red", "intended_grade": "V2"
    }, headers=auth_headers["admin"])
    route_id = route_response.json()["id"]

    # Setter updates it
    update_response = client.patch(f"/admin/routes/{route_id}", json={
        "color": "Blue", "intended_grade": "V5"
    }, headers=auth_headers["setter"])
    assert update_response.status_code == 200
    assert update_response.json()["color"] == "Blue"
    assert update_response.json()["intended_grade"] == "V5"

def test_student_cannotCreateRoute_Extraordinary(auth_headers):
    """Student role should still be rejected from creating routes."""
    zone_response = client.post("/admin/zones", json={"name": "Student Zone", "description": "Desc"}, headers=auth_headers["admin"])
    zone_id = zone_response.json()["id"]

    route_response = client.post("/admin/routes", json={
        "zone_id": zone_id, "color": "Red", "intended_grade": "V1"
    }, headers=auth_headers["student"])
    assert route_response.status_code == 403

def test_setter_cannotManageUsers_Extraordinary(auth_headers):
    """Setter role should NOT be able to access admin-only endpoints like user management."""
    response = client.get("/admin/users", headers=auth_headers["setter"])
    assert response.status_code == 403

def test_get_users_filtering(auth_headers):
    # Test filtering by role
    response = client.get("/admin/users?role=student", headers=auth_headers["admin"])
    assert response.status_code == 200
    for user in response.json():
        assert user["role"] == "student"

    # Test filtering by banned status
    # First ban a student
    db = TestingSessionLocal()
    student = db.query(models.User).filter_by(role="student").first()
    client.patch(f"/admin/users/{student.id}/ban", json={"is_banned": True}, headers=auth_headers["admin"])
    db.close()

    response = client.get("/admin/users?is_banned=true", headers=auth_headers["admin"])
    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["is_banned"] is True

    response = client.get("/admin/users?is_banned=false", headers=auth_headers["admin"])
    assert response.status_code == 200
    for user in response.json():
        assert user["is_banned"] is False

def test_get_setters_filtering(auth_headers):
    # Create an inactive setter
    client.post("/admin/setters", json={"name": "Inactive Sam", "is_active": False}, headers=auth_headers["admin"])
    client.post("/admin/setters", json={"name": "Active Amy", "is_active": True}, headers=auth_headers["admin"])

    # Test filtering by is_active
    response = client.get("/admin/setters?is_active=false", headers=auth_headers["admin"])
    assert response.status_code == 200
    assert any(s["name"] == "Inactive Sam" for s in response.json())
    assert all(s["is_active"] is False for s in response.json())

    response = client.get("/admin/setters?is_active=true", headers=auth_headers["admin"])
    assert response.status_code == 200
    assert any(s["name"] == "Active Amy" for s in response.json())
    assert all(s["is_active"] is True for s in response.json())

    # Test search by name
    response = client.get("/admin/setters?name=amy", headers=auth_headers["admin"])
    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["name"] == "Active Amy"

def test_toggle_setter_active_status(auth_headers):
    # Create a setter
    res = client.post("/admin/setters", json={"name": "Toggle Tim", "is_active": True}, headers=auth_headers["admin"])
    setter_id = res.json()["id"]

    # Deactivate
    response = client.patch(f"/admin/setters/{setter_id}", json={"is_active": False}, headers=auth_headers["admin"])
    assert response.status_code == 200
    assert response.json()["is_active"] is False

    # Activate
    response = client.patch(f"/admin/setters/{setter_id}", json={"is_active": True}, headers=auth_headers["admin"])
    assert response.status_code == 200
    assert response.json()["is_active"] is True

