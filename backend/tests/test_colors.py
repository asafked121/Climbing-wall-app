import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models import Color

def test_public_get_colors(client: TestClient, db: Session):
    # Ensure there's a color
    db.add(Color(name="TestColor", hex_value="#123456"))
    db.commit()

    response = client.get("/routes/colors")
    assert response.status_code == 200
    colors = response.json()
    assert isinstance(colors, list)
    assert any(c["name"] == "TestColor" for c in colors)

def test_admin_create_color(client: TestClient, admin_token_headers: dict, db: Session):
    color_data = {
        "name": "Neon Pink",
        "hex_value": "#FF1493"
    }
    response = client.post("/admin/colors", json=color_data, headers=admin_token_headers)
    assert response.status_code == 201
    
    data = response.json()
    assert data["name"] == "Neon Pink"
    assert data["hex_value"] == "#FF1493"
    assert "id" in data
    
    # Clean up
    db_color = db.query(Color).filter(Color.name == "Neon Pink").first()
    if db_color:
        db.delete(db_color)
        db.commit()

def test_student_cannot_create_color(client: TestClient, student_token_headers: dict):
    color_data = {
        "name": "Should Fail",
        "hex_value": "#000000"
    }
    response = client.post("/admin/colors", json=color_data, headers=student_token_headers)
    assert response.status_code == 403 # Forbidden

def test_admin_delete_color(client: TestClient, admin_token_headers: dict, db: Session):
    # Create the color first
    db_color = Color(name="ToDelete", hex_value="#000000")
    db.add(db_color)
    db.commit()
    db.refresh(db_color)
    color_id = db_color.id
    
    response = client.delete(f"/admin/colors/{color_id}", headers=admin_token_headers)
    assert response.status_code == 204
    
    # Ensure it's deleted
    assert db.query(Color).filter(Color.id == color_id).first() is None
