"""Tests for the manage.py CLI promote/demote super-admin functions."""

import pytest
from app.database import Base, get_db
from app import models, security
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Re-use the same test database pattern as test_admin_detailed.py
SQLALCHEMY_DATABASE_URL = "sqlite:///./test_admin.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Import the CLI script (no .py extension) using importlib
import importlib.util
import importlib.machinery
import os

_wall_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "wall")
_wall_path = os.path.abspath(_wall_path)
_loader = importlib.machinery.SourceFileLoader("wall", _wall_path)
_spec = importlib.util.spec_from_loader("wall", _loader, origin=_wall_path)
manage_module = importlib.util.module_from_spec(_spec)
_loader.exec_module(manage_module)


@pytest.fixture(autouse=True)
def setup_db(monkeypatch):
    """Create tables, seed users, and patch SessionLocal for each test."""
    Base.metadata.create_all(bind=engine)

    # Patch manage module's SessionLocal to use the test DB
    monkeypatch.setattr(manage_module, "SessionLocal", TestingSessionLocal)

    db = TestingSessionLocal()
    hashed = security.get_password_hash("password")
    db.add(models.User(email="student@test.com", username="student_cli", password_hash=hashed, role="student", is_banned=False))
    db.add(models.User(email="admin@test.com", username="admin_cli", password_hash=hashed, role="admin", is_banned=False))
    db.add(models.User(email="super@test.com", username="super_cli", password_hash=hashed, role="super_admin", is_banned=False))
    db.commit()
    db.close()

    yield

    Base.metadata.drop_all(bind=engine)


# --- Normal Cases ---

def test_promoteStudent_toSuperAdmin_Normal():
    """Promoting a student to super_admin succeeds."""
    manage_module.promote_super_admin("student@test.com")

    db = TestingSessionLocal()
    user = db.query(models.User).filter_by(email="student@test.com").first()
    assert user.role == "super_admin"
    db.close()


def test_demoteSuperAdmin_toStudent_Normal():
    """Demoting a super_admin back to student succeeds."""
    manage_module.demote_super_admin("super@test.com")

    db = TestingSessionLocal()
    user = db.query(models.User).filter_by(email="super@test.com").first()
    assert user.role == "student"
    db.close()


# --- Edge Cases ---

def test_promoteAlreadySuperAdmin_Edge():
    """Promoting someone who is already super_admin is a no-op (no crash)."""
    # Should not raise; prints informational message
    manage_module.promote_super_admin("super@test.com")

    db = TestingSessionLocal()
    user = db.query(models.User).filter_by(email="super@test.com").first()
    assert user.role == "super_admin"
    db.close()


def test_demoteNonSuperAdmin_Edge():
    """Demoting a user who is not super_admin should exit with error."""
    with pytest.raises(SystemExit) as exc_info:
        manage_module.demote_super_admin("student@test.com")
    assert exc_info.value.code == 1


# --- Extraordinary Cases ---

def test_promoteNonExistentEmail_Extraordinary():
    """Promoting a non-existent email should exit with error."""
    with pytest.raises(SystemExit) as exc_info:
        manage_module.promote_super_admin("nobody@test.com")
    assert exc_info.value.code == 1


def test_demoteNonExistentEmail_Extraordinary():
    """Demoting a non-existent email should exit with error."""
    with pytest.raises(SystemExit) as exc_info:
        manage_module.demote_super_admin("nobody@test.com")
    assert exc_info.value.code == 1


def test_promoteAdmin_toSuperAdmin_Normal():
    """Promoting an admin to super_admin succeeds."""
    manage_module.promote_super_admin("admin@test.com")

    db = TestingSessionLocal()
    user = db.query(models.User).filter_by(email="admin@test.com").first()
    assert user.role == "super_admin"
    db.close()
