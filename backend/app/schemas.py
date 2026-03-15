from pydantic import BaseModel, EmailStr, ConfigDict, field_validator
from datetime import datetime, date
from typing import Optional, List


# --- User Schemas ---
class UserBase(BaseModel):
    email: EmailStr
    username: str
    role: str = "student"


class UserCreate(UserBase):
    username: Optional[str] = None
    password: str
    date_of_birth: Optional[date] = None

    @field_validator("date_of_birth")
    @classmethod
    def validate_age(cls, v: Optional[date]) -> Optional[date]:
        if v is None:
            return v
        today = date.today()
        age = today.year - v.year - ((today.month, today.day) < (v.month, v.day))
        if age < 13:
            raise ValueError("User must be at least 13 years old to register.")
        return v


class UserUpdate(BaseModel):
    username: str


class UserRoleUpdate(BaseModel):
    role: str


class UserBanUpdate(BaseModel):
    is_banned: bool


class UserResponse(UserBase):
    id: int
    is_banned: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# --- Setter Schemas ---
class SetterBase(BaseModel):
    name: str


class SetterCreate(SetterBase):
    is_active: bool = True


class SetterUpdate(BaseModel):
    name: Optional[str] = None
    is_active: Optional[bool] = None


class SetterResponse(SetterBase):
    id: int
    is_active: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# --- Zone Schemas ---
VALID_ROUTE_TYPES = {"boulder", "top_rope"}


class ZoneBase(BaseModel):
    name: str
    description: Optional[str] = None
    route_type: str = "boulder"

    @field_validator("route_type")
    @classmethod
    def validate_route_type(cls, value: str) -> str:
        if value not in VALID_ROUTE_TYPES:
            raise ValueError(f"route_type must be one of {VALID_ROUTE_TYPES}")
        return value


class ZoneCreate(ZoneBase):
    pass


class ZoneResponse(ZoneBase):
    id: int
    model_config = ConfigDict(from_attributes=True)


# --- Color Schemas ---
class ColorBase(BaseModel):
    name: str
    hex_value: str


class ColorCreate(ColorBase):
    pass


class ColorResponse(ColorBase):
    id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# --- Route Schemas ---
class RouteBase(BaseModel):
    zone_id: int
    color: str
    intended_grade: str
    status: str = "active"
    photo_url: Optional[str] = None


class RouteCreate(RouteBase):
    setter_id: Optional[int] = None
    set_date: Optional[date] = None


class RouteUpdate(BaseModel):
    zone_id: Optional[int] = None
    color: Optional[str] = None
    intended_grade: Optional[str] = None
    setter_id: Optional[int] = None
    status: Optional[str] = None
    set_date: Optional[date] = None


class RouteResponse(RouteBase):
    id: int
    setter_id: Optional[int] = None
    set_date: date
    created_at: datetime
    color_name: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)


class RouteArchive(BaseModel):
    status: str = "archived"


class BulkUploadRowError(BaseModel):
    row: int
    field: Optional[str] = None
    message: str


class BulkUploadResponse(BaseModel):
    total_rows: int
    created_count: int
    error_count: int
    errors: List[BulkUploadRowError] = []


# --- GradeVote Schemas ---
class GradeVoteBase(BaseModel):
    voted_grade: str


class GradeVoteCreate(GradeVoteBase):
    pass


class GradeVoteResponse(GradeVoteBase):
    id: int
    user_id: int
    route_id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# --- Comment Schemas ---
class CommentBase(BaseModel):
    content: str


class CommentCreate(CommentBase):
    pass


class CommentResponse(CommentBase):
    id: int
    user_id: int
    route_id: int
    created_at: datetime
    user: Optional[UserResponse] = None
    model_config = ConfigDict(from_attributes=True)


# --- Route Rating Schemas ---
from pydantic import Field


class RouteRatingBase(BaseModel):
    rating: int = Field(ge=1, le=5)


class RouteRatingCreate(RouteRatingBase):
    pass


class RouteRatingResponse(RouteRatingBase):
    id: int
    user_id: int
    route_id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# --- Ascent Schemas ---
class AscentBase(BaseModel):
    ascent_type: str  # 'lead', 'top_rope', 'boulder'


class AscentCreate(AscentBase):
    pass


class AscentResponse(AscentBase):
    id: int
    user_id: int
    route_id: int
    date: datetime
    model_config = ConfigDict(from_attributes=True)


# --- Combined Responses ---
class RouteSummaryResponse(RouteResponse):
    zone: Optional[ZoneResponse] = None
    setter: Optional[SetterResponse] = None
    model_config = ConfigDict(from_attributes=True)


class RouteDetailResponse(RouteResponse):
    zone: Optional[ZoneResponse] = None
    setter: Optional[SetterResponse] = None
    grade_votes: List[GradeVoteResponse] = []
    comments: List[CommentResponse] = []
    route_ratings: List[RouteRatingResponse] = []
    ascents: List[AscentResponse] = []
    model_config = ConfigDict(from_attributes=True)


# --- Analytics Schemas ---
class GradeCount(BaseModel):
    grade: str
    count: int


class RouteStatusCount(BaseModel):
    active: int
    archived: int


class ZoneCount(BaseModel):
    zone: str
    count: int


class DayCount(BaseModel):
    date: str
    count: int


class RatingCount(BaseModel):
    rating: int
    count: int


class TopRatedRoute(BaseModel):
    route_id: int
    grade: str
    color: str
    avg_rating: float
    rating_count: int


class AnalyticsResponse(BaseModel):
    grade_distribution: List[GradeCount]
    ascents_by_grade: List[GradeCount]
    route_status: RouteStatusCount
    zone_utilization: List[ZoneCount]
    activity_trend: List[DayCount]
    rating_distribution: List[RatingCount]
    top_rated_routes: List[TopRatedRoute]


class Token(BaseModel):
    message: str


class LoginRequest(BaseModel):
    email: str
    password: str
