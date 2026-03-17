import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app

from app.database import Base, get_db, SessionLocal, engine

TestingSessionLocal = SessionLocal

@pytest.fixture(scope="function")
def session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def client(session):
    def override_get_db():
        try:
            yield session
        finally:
            session.close()
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()
@pytest.fixture(scope="function")
def super_admin_cookies(client, session):
    client.post("/auth/register", json={"email": "super@test.com", "password": "pass", "role": "admin"})
    from app import models
    user = session.query(models.User).filter(models.User.email == "super@test.com").first()
    user.role = "super_admin"
    session.commit()
    res = client.post("/auth/login", json={"email": "super@test.com", "password": "pass"})
    return {"access_token": res.cookies.get("access_token")}
