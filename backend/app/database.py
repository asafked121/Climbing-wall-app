import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import sessionmaker

# Resolve to the project's data directory for local runs
# database.py is at backend/app/database.py, so we go up 3 levels to the root
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOCAL_DB_PATH = os.path.join(BASE_DIR, "data", "climbing_wall.db")
DEFAULT_DB_URL = f"sqlite:///{LOCAL_DB_PATH}"

import sys

# Use environment variable if provided, else use local dev DB path
if "pytest" in sys.modules:
    from sqlalchemy.pool import StaticPool
    SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
    engine = create_engine(
        SQLALCHEMY_DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
else:
    SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", DEFAULT_DB_URL)
    engine = create_engine(
        SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
    )
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
