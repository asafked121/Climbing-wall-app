import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database import Base, get_db
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app import security, models
import os

from app import security, models

@pytest.fixture
def auth_headers(session):
    # Create users using the provided session fixture for proper isolation
    hashed_password = security.get_password_hash("password")
    admin_user = models.User(email="admin@example.com", username="admin_testing", password_hash=hashed_password, role="admin", is_banned=False)
    admin_user_2 = models.User(email="admin2@example.com", username="admin_testing2", password_hash=hashed_password, role="admin", is_banned=False)
    super_admin = models.User(email="super@example.com", username="super_admin", password_hash=hashed_password, role="super_admin", is_banned=False)
    student = models.User(email="student@example.com", username="student_user", password_hash=hashed_password, role="student", is_banned=False)
    setter_user = models.User(email="setter@example.com", username="setter_user", password_hash=hashed_password, role="setter", is_banned=False)
    
    session.add_all([admin_user, admin_user_2, super_admin, student, setter_user])
    session.commit()
    
    tokens = {
        "admin": security.create_access_token(data={"sub": "admin@example.com", "role": "admin"}),
        "super_admin": security.create_access_token(data={"sub": "super@example.com", "role": "super_admin"}),
        "setter": security.create_access_token(data={"sub": "setter@example.com", "role": "setter"}),
        "student": security.create_access_token(data={"sub": "student@example.com", "role": "student"}),
    }
    
    return {role: {"Cookie": f"access_token={token}"} for role, token in tokens.items()}

def test_get_users(client, auth_headers):
    # Test getting all users
    response = client.get("/admin/users", headers=auth_headers["admin"])
    assert response.status_code == 200
    data = response.json()
    # admin, admin2, super, student, setter
    assert len(data) >= 5

def test_ban_user(client, auth_headers, session):
    student = session.query(models.User).filter_by(email="student@example.com").first()
    student_id = student.id

    # Admin bans student
    response = client.patch(f"/admin/users/{student_id}/ban", json={"is_banned": True}, headers=auth_headers["admin"])
    assert response.status_code == 200
    assert response.json()["is_banned"] is True

    # Check login fails for banned user
    login_response = client.post("/auth/login", json={"email": "student@example.com", "password": "password"})
    assert login_response.status_code == 403
    assert login_response.json()["detail"] == "User is banned"

def test_ban_super_admin_fails(client, auth_headers, session):
    super_admin = session.query(models.User).filter_by(email="super@example.com").first()
    super_admin_id = super_admin.id

    response = client.patch(f"/admin/users/{super_admin_id}/ban", json={"is_banned": True}, headers=auth_headers["admin"])
    assert response.status_code == 403
    assert response.json()["detail"] == "Cannot ban super admins"

def test_admin_cannot_ban_admin(client, auth_headers, session):
    admin_2 = session.query(models.User).filter_by(email="admin2@example.com").first()
    admin_2_id = admin_2.id

    response = client.patch(f"/admin/users/{admin_2_id}/ban", json={"is_banned": True}, headers=auth_headers["admin"])
    assert response.status_code == 403
    assert response.json()["detail"] == "Admins cannot ban other admins"

def test_role_update_student_to_setter(client, auth_headers, session):
    student = session.query(models.User).filter_by(email="student@example.com").first()
    student_id = student.id

    # Admin makes student a setter
    response = client.patch(f"/admin/users/{student_id}/role", json={"role": "setter"}, headers=auth_headers["admin"])
    assert response.status_code == 200
    assert response.json()["role"] == "setter"

def test_admin_cannot_promote_to_admin(client, auth_headers, session):
    student = session.query(models.User).filter_by(email="student@example.com").first()
    student_id = student.id

    # Admin attempts to make student an admin
    response = client.patch(f"/admin/users/{student_id}/role", json={"role": "admin"}, headers=auth_headers["admin"])
    assert response.status_code == 403

def test_super_admin_can_promote_to_admin(client, auth_headers, session):
    student = session.query(models.User).filter_by(email="student@example.com").first()
    student_id = student.id

    # Super Admin makes student an admin
    response = client.patch(f"/admin/users/{student_id}/role", json={"role": "admin"}, headers=auth_headers["super_admin"])
    assert response.status_code == 200
    assert response.json()["role"] == "admin"

def test_route_update(client, auth_headers):
    # Setup Zone and Setter - Use SUPER ADMIN for zone creation
    zone_response = client.post("/admin/zones", json={"name": "Testing Zone", "description": "Desc"}, headers=auth_headers["super_admin"])
    assert zone_response.status_code == 201
    zone_id = zone_response.json()["id"]

    setter_response = client.post("/admin/setters", json={"name": "John Doe", "is_active": True}, headers=auth_headers["admin"])
    assert setter_response.status_code == 201
    setter_id = setter_response.json()["id"]

    route_response = client.post("/admin/routes", json={"zone_id": zone_id, "setter_id": setter_id, "color": "Blue", "intended_grade": "V4"}, headers=auth_headers["admin"])
    assert route_response.status_code == 201
    route_id = route_response.json()["id"]

    # Test Patch
    update_response = client.patch(f"/admin/routes/{route_id}", json={"color": "Red", "intended_grade": "V5"}, headers=auth_headers["admin"])
    
    assert update_response.status_code == 200
    assert update_response.json()["color"] == "Red"
    assert update_response.json()["intended_grade"] == "V5"
    assert update_response.json()["zone_id"] == zone_id
    assert update_response.json()["setter_id"] == setter_id

def test_create_and_get_setters(client, auth_headers):
    response = client.post("/admin/setters", json={"name": "Sally Setter", "is_active": True}, headers=auth_headers["admin"])
    assert response.status_code == 201
    assert response.json()["name"] == "Sally Setter"

    response_get = client.get("/admin/setters", headers=auth_headers["admin"])
    assert response_get.status_code == 200
    assert len(response_get.json()) >= 1

# --- Setter Role Route Management Tests ---

def test_setter_canCreateRoute_Normal(client, auth_headers):
    """Setter role should be able to create routes via /admin/routes."""
    # Admin creates the zone (setters can't create zones) - Use SUPER ADMIN
    zone_response = client.post("/admin/zones", json={"name": "Setter Zone", "description": "For setters"}, headers=auth_headers["super_admin"])
    assert zone_response.status_code == 201
    zone_id = zone_response.json()["id"]

    # Setter creates a route
    route_response = client.post("/admin/routes", json={
        "zone_id": zone_id, "color": "Green", "intended_grade": "V3"
    }, headers=auth_headers["setter"])
    assert route_response.status_code == 201
    assert route_response.json()["color"] == "Green"
    assert route_response.json()["intended_grade"] == "V3"

def test_setter_canUpdateRoute_Normal(client, auth_headers):
    """Setter role should be able to update existing routes."""
    # Use SUPER ADMIN
    zone_response = client.post("/admin/zones", json={"name": "Update Zone", "description": "Desc"}, headers=auth_headers["super_admin"])
    assert zone_response.status_code == 201
    zone_id = zone_response.json()["id"]

    # Admin creates a route
    route_response = client.post("/admin/routes", json={
        "zone_id": zone_id, "color": "Red", "intended_grade": "V2"
    }, headers=auth_headers["admin"])
    assert route_response.status_code == 201
    route_id = route_response.json()["id"]

    # Setter updates it
    update_response = client.patch(f"/admin/routes/{route_id}", json={
        "color": "Blue", "intended_grade": "V5"
    }, headers=auth_headers["setter"])
    assert update_response.status_code == 200
    assert update_response.json()["color"] == "Blue"
    assert update_response.json()["intended_grade"] == "V5"

def test_student_cannotCreateRoute_Extraordinary(client, auth_headers):
    """Student role should still be rejected from creating routes."""
    # Use SUPER ADMIN
    zone_response = client.post("/admin/zones", json={"name": "Student Zone", "description": "Desc"}, headers=auth_headers["super_admin"])
    assert zone_response.status_code == 201
    zone_id = zone_response.json()["id"]

    route_response = client.post("/admin/routes", json={
        "zone_id": zone_id, "color": "Red", "intended_grade": "V1"
    }, headers=auth_headers["student"])
    assert route_response.status_code == 403

def test_setter_cannotManageUsers_Extraordinary(client, auth_headers):
    """Setter role should NOT be able to access admin-only endpoints like user management."""
    response = client.get("/admin/users", headers=auth_headers["setter"])
    assert response.status_code == 403

def test_get_users_filtering(client, auth_headers, session):
    # Test filtering by role
    response = client.get("/admin/users?role=student", headers=auth_headers["admin"])
    assert response.status_code == 200
    for user in response.json():
        assert user["role"] == "student"

    # Test filtering by banned status
    # First ban a student
    student = session.query(models.User).filter_by(role="student").first()
    client.patch(f"/admin/users/{student.id}/ban", json={"is_banned": True}, headers=auth_headers["admin"])

    response = client.get("/admin/users?is_banned=true", headers=auth_headers["admin"])
    assert response.status_code == 200
    assert any(user["is_banned"] is True for user in response.json())

    response = client.get("/admin/users?is_banned=false", headers=auth_headers["admin"])
    assert response.status_code == 200
    for user in response.json():
        assert user["is_banned"] is False

def test_get_setters_filtering(client, auth_headers):
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

def test_toggle_setter_active_status(client, auth_headers):
    # Create a setter
    res = client.post("/admin/setters", json={"name": "Toggle Tim", "is_active": True}, headers=auth_headers["admin"])
    assert res.status_code == 201
    setter_id = res.json()["id"]

    # Deactivate
    response = client.patch(f"/admin/setters/{setter_id}", json={"is_active": False}, headers=auth_headers["admin"])
    assert response.status_code == 200
    assert response.json()["is_active"] is False

    # Activate
    response = client.patch(f"/admin/setters/{setter_id}", json={"is_active": True}, headers=auth_headers["admin"])
    assert response.status_code == 200
    assert response.json()["is_active"] is True

