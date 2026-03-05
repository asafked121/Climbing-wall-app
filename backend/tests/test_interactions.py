import pytest

@pytest.fixture
def setup_data(client):
    client.post("/auth/register", json={"email": "admin@test.com", "password": "pass", "role": "admin"})
    client.post("/auth/login", json={"email": "admin@test.com", "password": "pass"})
    
    zone_res = client.post("/admin/zones", json={"name": "Cave"})
    zone_id = zone_res.json()["id"]
    route_res = client.post("/admin/routes", json={"zone_id": zone_id, "color": "red", "intended_grade": "V4"})
    route_id = route_res.json()["id"]
    
    client.post("/auth/logout")
    client.post("/auth/register", json={"email": "student@test.com", "password": "pass", "role": "student"})
    client.post("/auth/login", json={"email": "student@test.com", "password": "pass"})
    return client, route_id

def test_vote_Normal(setup_data):
    client, route_id = setup_data
    res = client.post(f"/routes/{route_id}/votes", json={"voted_grade": "V3"})
    assert res.status_code == 201
    assert res.json()["voted_grade"] == "V3"

def test_vote_Update_Edge(setup_data):
    client, route_id = setup_data
    client.post(f"/routes/{route_id}/votes", json={"voted_grade": "V4"})
    res = client.post(f"/routes/{route_id}/votes", json={"voted_grade": "V5"})
    assert res.status_code == 201
    assert res.json()["voted_grade"] == "V5"
    
    route_details = client.get(f"/routes/{route_id}")
    assert len(route_details.json()["grade_votes"]) == 1

def test_vote_InvalidRoute_Extraordinary(setup_data):
    client, _ = setup_data
    res = client.post("/routes/999/votes", json={"voted_grade": "V3"})
    assert res.status_code == 404

def test_comment_Normal(setup_data):
    client, route_id = setup_data
    res = client.post(f"/routes/{route_id}/comments", json={"content": "Crux is at the top"})
    assert res.status_code == 201

def test_comment_Empty_Extraordinary(setup_data):
    client, route_id = setup_data
    res = client.post(f"/routes/{route_id}/comments", json={})
    assert res.status_code == 422

def test_rating_Normal(setup_data):
    client, route_id = setup_data
    res = client.post(f"/routes/{route_id}/ratings", json={"rating": 5})
    assert res.status_code == 201
    assert res.json()["rating"] == 5

def test_rating_Update_Edge(setup_data):
    client, route_id = setup_data
    client.post(f"/routes/{route_id}/ratings", json={"rating": 4})
    res = client.post(f"/routes/{route_id}/ratings", json={"rating": 3})
    assert res.status_code == 201
    assert res.json()["rating"] == 3
    
    route_details = client.get(f"/routes/{route_id}")
    assert len(route_details.json()["route_ratings"]) == 1

def test_rating_OutOfBounds_Extraordinary(setup_data):
    client, route_id = setup_data
    # Test rating > 5 (Pydantic validation should block it)
    res = client.post(f"/routes/{route_id}/ratings", json={"rating": 6})
    assert res.status_code == 422
    
    # Test rating < 1
    res = client.post(f"/routes/{route_id}/ratings", json={"rating": 0})
    assert res.status_code == 422


# --- Guest Restriction Tests ---

@pytest.fixture
def guest_setup(client, session):
    """Creates a route as admin, then registers a user and sets their role to 'guest' directly in the DB."""
    client.post("/auth/register", json={"email": "admin2@test.com", "password": "pass", "role": "admin"})
    client.post("/auth/login", json={"email": "admin2@test.com", "password": "pass"})

    zone_res = client.post("/admin/zones", json={"name": "Guest Zone"})
    zone_id = zone_res.json()["id"]
    route_res = client.post("/admin/routes", json={"zone_id": zone_id, "color": "blue", "intended_grade": "V2"})
    route_id = route_res.json()["id"]

    # Log an ascent as admin so we can test delete later
    ascent_res = client.post(f"/routes/{route_id}/ascents", json={"ascent_type": "boulder"})
    ascent_id = ascent_res.json()["id"]

    client.post("/auth/logout")
    # Register as student (guest role not accepted by register endpoint), then patch to guest in DB
    client.post("/auth/register", json={"email": "guest@test.com", "password": "pass", "role": "student"})
    from app import models
    guest_user = session.query(models.User).filter(models.User.email == "guest@test.com").first()
    guest_user.role = "guest"
    session.commit()

    client.post("/auth/login", json={"email": "guest@test.com", "password": "pass"})
    return client, route_id, ascent_id


def test_guest_submitAscent_returns403(guest_setup):
    client, route_id, _ = guest_setup
    res = client.post(f"/routes/{route_id}/ascents", json={"ascent_type": "boulder"})
    assert res.status_code == 403
    assert "Guests" in res.json()["detail"]


def test_guest_deleteAscent_returns403(guest_setup):
    client, _, ascent_id = guest_setup
    res = client.delete(f"/routes/ascents/{ascent_id}")
    assert res.status_code == 403
    assert "Guests" in res.json()["detail"]


def test_guest_submitVote_returns403(guest_setup):
    client, route_id, _ = guest_setup
    res = client.post(f"/routes/{route_id}/votes", json={"voted_grade": "V3"})
    assert res.status_code == 403


def test_guest_postComment_returns403(guest_setup):
    client, route_id, _ = guest_setup
    res = client.post(f"/routes/{route_id}/comments", json={"content": "Nice route"})
    assert res.status_code == 403


def test_guest_submitRating_returns403(guest_setup):
    client, route_id, _ = guest_setup
    res = client.post(f"/routes/{route_id}/ratings", json={"rating": 4})
    assert res.status_code == 403

