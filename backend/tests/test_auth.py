import pytest

def test_register_Normal_Success(client):
    response = client.post(
        "/auth/register",
        json={"email": "student@test.com", "password": "password123", "role": "student"}
    )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "student@test.com"
    assert "id" in data

def test_register_Edge_AdminRole(client):
    response = client.post(
        "/auth/register",
        json={"email": "admin@test.com", "password": "password123", "role": "admin"}
    )
    assert response.status_code == 201
    data = response.json()
    assert data["role"] == "admin"

def test_register_Extraordinary_DuplicateEmail(client):
    client.post(
        "/auth/register",
        json={"email": "duplicate@test.com", "password": "password123"}
    )
    response = client.post(
        "/auth/register",
        json={"email": "duplicate@test.com", "password": "newpassword"}
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "Email already registered"

def test_login_Normal_Success(client):
    client.post(
        "/auth/register",
        json={"email": "login@test.com", "password": "password123"}
    )
    response = client.post(
        "/auth/login",
        json={"email": "login@test.com", "password": "password123"}
    )
    assert response.status_code == 200
    # verify cookie is set
    assert "access_token" in response.cookies

def test_login_Extraordinary_WrongPassword(client):
    client.post(
        "/auth/register",
        json={"email": "wrongpass@test.com", "password": "password123"}
    )
    response = client.post(
        "/auth/login",
        json={"email": "wrongpass@test.com", "password": "wrongpassword"}
    )
    assert response.status_code == 401
    assert "Incorrect email or password" in response.json()["detail"]

def test_login_Extraordinary_MissingFields(client):
    response = client.post(
        "/auth/login",
        json={"email": "missing@test.com"} # Missing password
    )
    assert response.status_code == 422 # FastAPI validation error

def test_register_Normal_WithValidDOB(client):
    response = client.post(
        "/auth/register",
        json={"email": "older@test.com", "password": "password123", "date_of_birth": "1990-01-01"}
    )
    assert response.status_code == 201

def test_register_Edge_Barely13(client):
    from datetime import date
    from dateutil.relativedelta import relativedelta
    today = date.today()
    thirteen_years_ago = (today - relativedelta(years=13)).strftime("%Y-%m-%d")
    
    response = client.post(
        "/auth/register",
        json={"email": "barely13@test.com", "password": "password123", "date_of_birth": thirteen_years_ago}
    )
    assert response.status_code == 201

def test_register_Extraordinary_Under13(client):
    response = client.post(
        "/auth/register",
        json={"email": "young@test.com", "password": "password123", "date_of_birth": "2020-01-01"}
    )
    assert response.status_code == 422
    assert "User must be at least 13 years old to register." in response.json()["detail"][0]["msg"]
