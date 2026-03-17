from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    Date,
    ForeignKey,
    UniqueConstraint,
    Boolean,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    role = Column(
        String, default="student", nullable=False
    )  # 'student', 'setter', 'admin', 'super_admin'
    is_banned = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    grade_votes = relationship(
        "GradeVote", back_populates="user", cascade="all, delete-orphan"
    )
    comments = relationship(
        "Comment", back_populates="user", cascade="all, delete-orphan"
    )
    route_ratings = relationship(
        "RouteRating", back_populates="user", cascade="all, delete-orphan"
    )
    ascents = relationship(
        "Ascent", back_populates="user", cascade="all, delete-orphan"
    )


class Setter(Base):
    __tablename__ = "setters"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, unique=True, index=True, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    routes = relationship("Route", back_populates="setter")


class Zone(Base):
    __tablename__ = "zones"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, nullable=False)
    description = Column(String)
    route_type = Column(
        String, default="boulder", nullable=False
    )  # 'boulder' or 'top_rope'
    allows_lead = Column(Boolean, default=False, nullable=False)

    routes = relationship("Route", back_populates="zone")


class Color(Base):
    __tablename__ = "colors"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, unique=True, index=True, nullable=False)
    hex_value = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Route(Base):
    __tablename__ = "routes"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    setter_id = Column(
        Integer, ForeignKey("setters.id", ondelete="SET NULL"), nullable=True
    )
    zone_id = Column(Integer, ForeignKey("zones.id"))
    color = Column(String, nullable=False)
    intended_grade = Column(String, nullable=False)
    status = Column(String, default="active", nullable=False)  # 'active' or 'archived'
    set_date = Column(Date, server_default=func.current_date(), nullable=False)
    photo_url = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    setter = relationship("Setter", back_populates="routes")
    zone = relationship("Zone", back_populates="routes")
    grade_votes = relationship(
        "GradeVote", back_populates="route", cascade="all, delete-orphan"
    )
    comments = relationship(
        "Comment", back_populates="route", cascade="all, delete-orphan"
    )
    route_ratings = relationship(
        "RouteRating", back_populates="route", cascade="all, delete-orphan"
    )
    ascents = relationship(
        "Ascent", back_populates="route", cascade="all, delete-orphan"
    )


class GradeVote(Base):
    __tablename__ = "grade_votes"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    route_id = Column(Integer, ForeignKey("routes.id", ondelete="CASCADE"))
    voted_grade = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="grade_votes")
    route = relationship("Route", back_populates="grade_votes")

    __table_args__ = (UniqueConstraint("user_id", "route_id", name="_user_route_uc"),)


class Comment(Base):
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    route_id = Column(Integer, ForeignKey("routes.id", ondelete="CASCADE"))
    content = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="comments")
    route = relationship("Route", back_populates="comments")


class RouteRating(Base):
    __tablename__ = "route_ratings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    route_id = Column(Integer, ForeignKey("routes.id", ondelete="CASCADE"))
    rating = Column(Integer, nullable=False)  # e.g. 1 to 5
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="route_ratings")
    route = relationship("Route", back_populates="route_ratings")

    __table_args__ = (
        UniqueConstraint("user_id", "route_id", name="_user_route_rating_uc"),
    )


class Ascent(Base):
    __tablename__ = "ascents"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    route_id = Column(
        Integer, ForeignKey("routes.id", ondelete="CASCADE"), nullable=False
    )
    ascent_type = Column(String, nullable=False)  # 'lead', 'top_rope', 'boulder'
    date = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="ascents")
    route = relationship("Route", back_populates="ascents")
