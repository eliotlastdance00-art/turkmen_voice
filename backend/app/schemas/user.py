from datetime import datetime

from pydantic import BaseModel, Field


class UserRegisterRequest(BaseModel):
    device_id: str = Field(min_length=6, max_length=80)
    display_name: str | None = Field(default=None, max_length=24)
    avatar_seed: int | None = Field(default=None, ge=0, le=9999)
    consent_type: str = Field(default="dataset", pattern="^(dataset|internal)$")


class UserUpdateRequest(BaseModel):
    display_name: str | None = Field(default=None, max_length=24)
    avatar_seed: int | None = Field(default=None, ge=0, le=9999)
    consent_type: str | None = Field(default=None, pattern="^(dataset|internal)$")


class LevelResponse(BaseModel):
    index: int
    name: str
    min_points: int
    next_points: int | None = None
    progress: float = 0.0


class BadgeResponse(BaseModel):
    id: str
    name: str
    icon: str
    earned: bool


class UserStatsResponse(BaseModel):
    recordings: int = 0
    approved: int = 0
    pending: int = 0
    rejected: int = 0
    seconds: int = 0
    avg_quality: float | None = None
    ratings_given: int = 0
    ratings_received: int = 0


class UserProfileResponse(BaseModel):
    id: str
    display_name: str
    avatar_seed: int
    language: str = "tk"
    points: int
    level: LevelResponse
    created_at: datetime
    last_seen_at: datetime
    streak_days: int = 0
    rank: int | None = None
    stats: UserStatsResponse
    badges: list[BadgeResponse] = []


class UserRegisterResponse(BaseModel):
    user: UserProfileResponse
    token: str
    created: bool = False


class MeResponse(BaseModel):
    user: UserProfileResponse
    token: str = ""
