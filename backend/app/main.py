from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.database import engine, Base
from app.routers import auth, admin, climbing_routes, interactions, analytics

import os

# Create database tables
Base.metadata.create_all(bind=engine)

from contextlib import asynccontextmanager
from app.database import SessionLocal
from app.models import Color

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
    db.commit()
    db.close()
    yield

app = FastAPI(title="Climbing Wall MVP API", lifespan=lifespan)

# Setup CORS Origins
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:5173,http://localhost:80,http://frontend:80").split(",")

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

os.makedirs("data/photos", exist_ok=True)
app.mount("/photos", StaticFiles(directory="data/photos"), name="photos")

@app.get("/")
def read_root():
    return {"message": "Welcome to Climbing Wall MVP API"}
