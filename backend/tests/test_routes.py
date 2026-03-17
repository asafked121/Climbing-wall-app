import pytest

@pytest.fixture
def admin_cookies(client):
    client.post("/auth/register", json={"email": "admin@test.com", "password": "pass", "role": "admin"})
    res = client.post("/auth/login", json={"email": "admin@test.com", "password": "pass"})
    return {"access_token": res.cookies.get("access_token")}

@pytest.fixture
def student_cookies(client):
    client.post("/auth/register", json={"email": "student@test.com", "password": "pass", "role": "student"})
    res = client.post("/auth/login", json={"email": "student@test.com", "password": "pass"})
    return {"access_token": res.cookies.get("access_token")}

def test_routes_AdminCreate_Normal(client, super_admin_cookies):
    zone_res = client.post("/admin/zones", json={"name": "Cave", "description": "Overhang"}, cookies=super_admin_cookies)
    assert zone_res.status_code == 201
    zone_id = zone_res.json()["id"]
    
    route_res = client.post("/admin/routes", json={"zone_id": zone_id, "color": "red", "intended_grade": "V5"}, cookies=super_admin_cookies)
    assert route_res.status_code == 201
    
def test_routes_StudentFetch_Normal(client, super_admin_cookies, student_cookies):
    zone_res = client.post("/admin/zones", json={"name": "Slab", "description": "Flat"}, cookies=super_admin_cookies)
    assert zone_res.status_code == 201
    zone_id = zone_res.json()["id"]
    client.post("/admin/routes", json={"zone_id": zone_id, "color": "blue", "intended_grade": "V2"}, cookies=super_admin_cookies)
    
    res = client.get("/routes", cookies=student_cookies)
    assert res.status_code == 200
    assert len(res.json()) >= 1

def test_routes_ArchiveFilter_Edge(client, super_admin_cookies, student_cookies):
    zone_res = client.post("/admin/zones", json={"name": "Wall", "description": "Tall"}, cookies=super_admin_cookies)
    assert zone_res.status_code == 201
    zone_id = zone_res.json()["id"]
    route_res = client.post("/admin/routes", json={"zone_id": zone_id, "color": "green", "intended_grade": "V3"}, cookies=super_admin_cookies)
    assert route_res.status_code == 201
    route_id = route_res.json()["id"]
    
    client.patch(f"/admin/routes/{route_id}/archive", json={"status": "archived"}, cookies=super_admin_cookies)
    
    res = client.get("/routes", cookies=student_cookies)
    assert len(res.json()) == 0

def test_routes_StudentCreate_Extraordinary(client, student_cookies):
    zone_res = client.post("/admin/zones", json={"name": "Cave", "description": "Overhang"}, cookies=student_cookies)
    assert zone_res.status_code == 403

def test_zones_Fetch_Normal(client, super_admin_cookies, student_cookies):
    # Arrange
    client.post("/admin/zones", json={"name": "Bouldering", "description": "Short walls"}, cookies=super_admin_cookies)
    
    # Act
    res = client.get("/routes/zones", cookies=student_cookies)
    
    # Assert
    assert res.status_code == 200
    assert len(res.json()) >= 1

def test_routes_AdminCreate_Edge(client, super_admin_cookies):
    # Arrange
    zone_res = client.post("/admin/zones", json={"name": "Speed", "description": "Fast"}, cookies=super_admin_cookies)
    assert zone_res.status_code == 201
    zone_id = zone_res.json()["id"]
    
    # Act - Empty string for color and grade
    route_res = client.post("/admin/routes", json={"zone_id": zone_id, "color": "", "intended_grade": ""}, cookies=super_admin_cookies)
    
    # Assert - Depends on validation. If pydantic allows it, it should 201. If not, 422. 
    # Current models don't have constraints, so it likely succeeds. 
    assert route_res.status_code == 201

def test_routes_AdminCreate_Extraordinary_NonExistentZone(client, super_admin_cookies):
    # Act - Zone 99999 likely doesn't exist
    route_res = client.post("/admin/routes", json={"zone_id": 99999, "color": "white", "intended_grade": "V0"}, cookies=super_admin_cookies)
    
    # Assert
    assert route_res.status_code == 404
    assert route_res.json()["detail"] == "Zone not found"

def test_routes_AdminCreate_Extraordinary_MissingFields(client, super_admin_cookies):
    # Act - Missing required fields
    route_res = client.post("/admin/routes", json={"zone_id": 1}, cookies=super_admin_cookies)
    
    # Assert
    assert route_res.status_code == 422


# --- Top Rope Tests ---

def test_routes_TopRopeCreate_Normal(client, super_admin_cookies):
    # Arrange - Create a top rope zone
    zone_res = client.post("/admin/zones", json={"name": "Rope 1", "description": "Top rope station 1", "route_type": "top_rope"}, cookies=super_admin_cookies)
    assert zone_res.status_code == 201
    zone_id = zone_res.json()["id"]
    assert zone_res.json()["route_type"] == "top_rope"
    
    # Act - Create route with valid YDS grade
    route_res = client.post("/admin/routes", json={"zone_id": zone_id, "color": "red", "intended_grade": "5.10a"}, cookies=super_admin_cookies)
    
    # Assert
    assert route_res.status_code == 201
    assert route_res.json()["intended_grade"] == "5.10a"


def test_routes_TopRopeInvalidGrade_Extraordinary(client, super_admin_cookies):
    # Arrange - Create a top rope zone
    zone_res = client.post("/admin/zones", json={"name": "Rope 2", "description": "Station 2", "route_type": "top_rope"}, cookies=super_admin_cookies)
    assert zone_res.status_code == 201
    zone_id = zone_res.json()["id"]
    
    # Act - Try creating route with a boulder grade on a top rope zone
    route_res = client.post("/admin/routes", json={"zone_id": zone_id, "color": "blue", "intended_grade": "V5"}, cookies=super_admin_cookies)
    
    # Assert
    assert route_res.status_code == 400
    assert "not valid for zone type" in route_res.json()["detail"]


def test_routes_BoulderInvalidGrade_Extraordinary(client, super_admin_cookies):
    # Arrange - Create a boulder zone
    zone_res = client.post("/admin/zones", json={"name": "Wall B", "description": "Boulder", "route_type": "boulder"}, cookies=super_admin_cookies)
    assert zone_res.status_code == 201
    zone_id = zone_res.json()["id"]
    
    # Act - Try creating route with a YDS grade on a boulder zone
    route_res = client.post("/admin/routes", json={"zone_id": zone_id, "color": "green", "intended_grade": "5.10a"}, cookies=super_admin_cookies)
    
    # Assert
    assert route_res.status_code == 400
    assert "not valid for zone type" in route_res.json()["detail"]


def test_routes_GradesEndpoint_Normal(client, super_admin_cookies, student_cookies):
    # Arrange - Create both zone types
    boulder_zone = client.post("/admin/zones", json={"name": "Boulder Z", "description": "Boulder zone", "route_type": "boulder"}, cookies=super_admin_cookies)
    assert boulder_zone.status_code == 201
    top_rope_zone = client.post("/admin/zones", json={"name": "Rope Z", "description": "Top rope zone", "route_type": "top_rope"}, cookies=super_admin_cookies)
    assert top_rope_zone.status_code == 201
    boulder_zone_id = boulder_zone.json()["id"]
    top_rope_zone_id = top_rope_zone.json()["id"]
    
    # Act & Assert - Boulder grades
    res_boulder = client.get(f"/routes/grades?zone_id={boulder_zone_id}", cookies=student_cookies)
    assert res_boulder.status_code == 200
    assert "V0" in res_boulder.json()
    assert "5.10a" not in res_boulder.json()
    
    # Act & Assert - Top rope grades
    res_rope = client.get(f"/routes/grades?zone_id={top_rope_zone_id}", cookies=student_cookies)
    assert res_rope.status_code == 200
    assert "5.10a" in res_rope.json()
    assert "V0" not in res_rope.json()


def test_routes_RouteTypeFilter_Normal(client, super_admin_cookies, student_cookies):
    # Arrange - Create one route in each zone type
    boulder_zone = client.post("/admin/zones", json={"name": "Left Wall", "description": "Boulder", "route_type": "boulder"}, cookies=super_admin_cookies)
    assert boulder_zone.status_code == 201
    rope_zone = client.post("/admin/zones", json={"name": "Rope 3", "description": "Top rope", "route_type": "top_rope"}, cookies=super_admin_cookies)
    assert rope_zone.status_code == 201
    
    client.post("/admin/routes", json={"zone_id": boulder_zone.json()["id"], "color": "red", "intended_grade": "V3"}, cookies=super_admin_cookies)
    client.post("/admin/routes", json={"zone_id": rope_zone.json()["id"], "color": "blue", "intended_grade": "5.9"}, cookies=super_admin_cookies)
    
    # Act & Assert - Filter by boulder
    res_boulder = client.get("/routes?route_type=boulder", cookies=student_cookies)
    assert res_boulder.status_code == 200
    boulder_grades = [r["intended_grade"] for r in res_boulder.json()]
    assert "V3" in boulder_grades
    assert "5.9" not in boulder_grades
    
    # Act & Assert - Filter by top_rope
    res_rope = client.get("/routes?route_type=top_rope", cookies=student_cookies)
    assert res_rope.status_code == 200
    rope_grades = [r["intended_grade"] for r in res_rope.json()]
    assert "5.9" in rope_grades
    assert "V3" not in rope_grades
