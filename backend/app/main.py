from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.database import engine
from app.routers import auth, admin, climbing_routes, interactions, analytics

import os
import sys

from sqlalchemy import inspect


# Intelligent Database Setup
def initialize_database():
    import sys
    if "pytest" in sys.modules:
        from app.database import Base, engine
        import app.models  # ensure models are registered
        Base.metadata.create_all(bind=engine)
        return

    inspector = inspect(engine)
    # If users table exists but alembic doesn't, stamp it to prevent recreation errors
    if inspector.has_table("users") and not inspector.has_table("alembic_version"):
        print(
            "Existing database detected without Alembic tracking. Stamping as head..."
        )
        os.system("cd backend && alembic stamp head")

    # Automatically apply any pending migrations
    print("Applying pending database migrations...")
    os.system("cd backend && alembic upgrade head")


initialize_database()

from contextlib import asynccontextmanager
from app.database import SessionLocal
from app.models import Color, User
from app.security import get_password_hash


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Seed Colors
    db = SessionLocal()
    default_colors = [
        {"name": "Red", "hex_value": "#ff3b30"},
        {"name": "Blue", "hex_value": "#007aff"},
        {"name": "Green", "hex_value": "#34c759"},
        {"name": "Yellow", "hex_value": "#ffcc00"},
        {"name": "Purple", "hex_value": "#af52de"},
        {"name": "Orange", "hex_value": "#ff9500"},
        {"name": "Pink", "hex_value": "#ff2d55"},
        {"name": "Black", "hex_value": "#000000"},
        {"name": "White", "hex_value": "#ffffff"},
    ]
    for color_data in default_colors:
        if not db.query(Color).filter(Color.name == color_data["name"]).first():
            db.add(Color(**color_data))

    # Seed Super Admin
    admin_email = os.getenv("SUPER_ADMIN_EMAIL", "admin@example.com")
    admin_username = os.getenv("SUPER_ADMIN_USERNAME", "admin")
    admin_password = os.getenv("SUPER_ADMIN_PASSWORD", "admin")

    # Check if the designated super admin currently exists by email
    existing_admin = db.query(User).filter(User.email == admin_email).first()

    if existing_admin:
        # Upgrade existing user to super_admin if they aren't already
        if existing_admin.role != "super_admin":
            existing_admin.role = "super_admin"
            db.add(existing_admin)
    else:
        # Create the super admin if they don't exist at all
        super_admin = User(
            email=admin_email,
            username=admin_username,
            password_hash=get_password_hash(admin_password),
            role="super_admin",
        )
        db.add(super_admin)

    db.commit()
    db.close()
    yield


app = FastAPI(title="Climbing Wall MVP API", lifespan=lifespan)

# Setup CORS Origins
FRONTEND_URL = os.getenv(
    "FRONTEND_URL", "http://localhost:5173,http://localhost:80,http://frontend:80"
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=FRONTEND_URL,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(climbing_routes.router)
app.include_router(interactions.router)
app.include_router(analytics.router)

PHOTO_DIR = os.getenv("PHOTO_DIR", "/app/photos")
if "pytest" not in sys.modules:
    os.makedirs(PHOTO_DIR, exist_ok=True)
    app.mount("/photos", StaticFiles(directory=PHOTO_DIR), name="photos")


@app.get("/")
def read_root():
    return {"message": "Welcome to Climbing Wall MVP API"}
