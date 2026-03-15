from fastapi import APIRouter, Depends, HTTPException, status, Response
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
import uuid
from app import models, schemas, security, dependencies
from app.database import get_db

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register",
    response_model=schemas.UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):
    hashed_password = security.get_password_hash(user.password)

    # Generate default username if not provided
    final_username = user.username
    if not final_username:
        email_prefix = user.email.split("@")[0]
        random_suffix = str(uuid.uuid4())[:6]
        final_username = f"{email_prefix}_{random_suffix}"

    db_user = models.User(
        email=user.email,
        username=final_username,
        password_hash=hashed_password,
        role=user.role if user.role in ["student", "admin"] else "student",
    )
    try:
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        return db_user
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Email already registered")


@router.post("/login")
def login(
    request: schemas.LoginRequest, response: Response, db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.email == request.email).first()
    if not user or not security.verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if user.is_banned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is banned",
        )

    access_token = security.create_access_token(
        data={"sub": user.email, "role": user.role}
    )

    response.set_cookie(
        key="access_token",
        value=f"Bearer {access_token}",
        httponly=True,
        secure=False,
        samesite="lax",
        max_age=60 * 60 * 24 * 7,
    )

    return {"message": "Login successful"}


@router.post("/logout")
def logout(response: Response):
    response.delete_cookie("access_token")
    return {"message": "Logged out successfully"}


@router.get("/me", response_model=schemas.UserResponse)
def get_me(current_user: models.User = Depends(dependencies.get_current_user)):
    return current_user


@router.patch("/me/username", response_model=schemas.UserResponse)
def update_username(
    user_update: schemas.UserUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user),
):
    # Check if the desired username already exists
    existing_user = (
        db.query(models.User)
        .filter(
            models.User.username == user_update.username,
            models.User.id != current_user.id,
        )
        .first()
    )
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Username already taken"
        )

    current_user.username = user_update.username
    try:
        db.commit()
        db.refresh(current_user)
        return current_user
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Username already taken"
        )
