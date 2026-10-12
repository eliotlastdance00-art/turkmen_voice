from datetime import datetime

from pydantic import BaseModel

from app.schemas.user import LevelResponse


class DailyStat(BaseModel):
    day: str
    recordings: int = 0
    duration_ms: int = 0


class CategoryStat(BaseModel):
    category: str
    recordings: int = 0
    duration_ms: int = 0


class OverviewResponse(BaseModel):
    generated_at: datetime
    recordings_total: int = 0
    approved: int = 0
    pending: int = 0
    rejected: int = 0
    verified: int = 0
    contributors: int = 0
    speakers_with_approved: int = 0
    seconds_total: float = 0
    hours_total: float = 0
    avg_duration_ms: int = 0
    avg_quality: float | None = None
    ratings_total: int = 0
    sentences_total: int = 0
    packages_total: int = 0
    storage_mb: float = 0
    target_hours: float = 10
    progress: float = 0
    daily: list[DailyStat] = []
    top_categories: list[CategoryStat] = []


class LeaderboardEntry(BaseModel):
    rank: int
    user_id: str
    display_name: str
    avatar_seed: int = 0
    points: int = 0
    level_name: str = ""
    level_index: int = 0
    recordings: int = 0
    seconds: int = 0
    avg_score: float | None = None
    ratings_given: int = 0
    ratings_received: int = 0
    is_me: bool = False


class LeaderboardResponse(BaseModel):
    period: str = "all"
    entries: list[LeaderboardEntry] = []
    me: LeaderboardEntry | None = None
    levels: list[dict] = []


class AdminOverview(OverviewResponse):
    by_speaker: list[dict] = []
    top_raters: list[dict] = []
    levels: list[dict] = []


class MeStatsResponse(BaseModel):
    user_id: str
    display_name: str
    points: int
    level: LevelResponse
    rank: int | None = None
    streak_days: int = 0
    daily: list[dict] = []
