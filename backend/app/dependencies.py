from fastapi import Depends, HTTPException, status, Request
from jose import jwt, JWTError
from sqlalchemy.orm import Session
from app.database import get_db
from app.config import settings
from app import models


def get_token_from_cookie(request: Request) -> str:
    token = request.cookies.get("access_token")
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )
    if token.startswith("Bearer "):
        token = token.split(" ")[1]
    return token


def get_current_user(
    token: str = Depends(get_token_from_cookie), db: Session = Depends(get_db)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
    )
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        email: str | None = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    if user.is_banned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="User is banned"
        )
    return user


def get_optional_token_from_cookie(request: Request) -> str | None:
    token = request.cookies.get("access_token")
    if not token:
        return None
    if token.startswith("Bearer "):
        token = token.split(" ")[1]
    return token


def get_optional_current_user(
    token: str | None = Depends(get_optional_token_from_cookie),
    db: Session = Depends(get_db),
):
    if not token:
        return None
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        email: str | None = payload.get("sub")
        if email is None:
            return None
    except JWTError:
        return None

    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None or user.is_banned:
        return None
    return user


def get_current_active_user(current_user: models.User = Depends(get_current_user)):
    """Rejects guest-role users from performing write actions."""
    if current_user.role == "guest":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Guests cannot perform this action",
        )
    return current_user


def get_current_admin(current_user: models.User = Depends(get_current_user)):
    if current_user.role not in ["admin", "super_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )
    return current_user


def get_current_setter_or_admin(current_user: models.User = Depends(get_current_user)):
    if current_user.role not in ["setter", "admin", "super_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Setter or admin permissions required",
        )
    return current_user


def get_current_super_admin(current_user: models.User = Depends(get_current_user)):
    if current_user.role != "super_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Super admin permissions required",
        )
    return current_user
