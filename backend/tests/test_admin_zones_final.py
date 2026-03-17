
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.dependencies import get_db, get_current_super_admin
from app.models import Base, User, Zone, Route
from app.database import engine

from app.dependencies import get_current_super_admin
from app.models import User, Zone, Route

def test_zone_crud_super_admin(client, super_admin_cookies):
    # Create (Use top_rope so we can test allows_lead toggle)
    response = client.post("/admin/zones", json={
        "name": "New Zone",
        "description": "Test Description",
        "route_type": "top_rope",
        "allows_lead": False
    }, cookies=super_admin_cookies)
    assert response.status_code == 201
    zone_id = response.json()["id"]
    
    # Update (Rename)
    response = client.patch(f"/admin/zones/{zone_id}", json={"name": "Renamed Zone", "allows_lead": True}, cookies=super_admin_cookies)
    assert response.status_code == 200
    assert response.json()["name"] == "Renamed Zone"
    assert response.json()["allows_lead"] == True
    
    # Delete (Safe Delete)
    response = client.delete(f"/admin/zones/{zone_id}", cookies=super_admin_cookies)
    assert response.status_code == 204
    
    # Verify deleted
    response = client.get("/routes/zones")
    assert not any(z["id"] == zone_id for z in response.json())

def test_zone_delete_with_routes(client, session, super_admin_cookies):
    # Create zone
    zone = Zone(name="Safe Zone", route_type="boulder")
    session.add(zone)
    session.commit()
    session.refresh(zone)
    
    # Add route to zone
    route = Route(zone_id=zone.id, color="Red", intended_grade="V3", status="active")
    session.add(route)
    session.commit()
    
    # Try to delete zone
    response = client.delete(f"/admin/zones/{zone.id}", cookies=super_admin_cookies)
    assert response.status_code == 400
    assert "associated routes" in response.json()["detail"]

def test_zone_lead_restriction_validation(client, super_admin_cookies):
    # Try to create boulder zone with lead enabled
    response = client.post("/admin/zones", json={
        "name": "Illegal Zone",
        "route_type": "boulder",
        "allows_lead": True
    }, cookies=super_admin_cookies)
    assert response.status_code == 422
    assert "Lead climbing can only be enabled" in response.json()["detail"][0]["msg"]
