from datetime import datetime

from pydantic import BaseModel, Field


class RatingQueueItem(BaseModel):
    recording_id: str
    sentence_id: str
    text: str
    audio_url: str
    duration_ms: int
    category: str = "general"
    created_at: datetime
    speaker_name: str = "Anonim"
    speaker_avatar_seed: int = 0
    community_score: float | None = None
    rating_count: int = 0


class RatingRequest(BaseModel):
    score: int = Field(ge=1, le=5, description="1..5 ýyldyz")
    matches_text: bool = Field(default=True, description="Aýdylan ses sözleme gabat gelýärmi")
    comment: str | None = Field(default=None, max_length=400)
    verdict: str | None = Field(default=None, pattern="^(good|ok|bad)$")


class RatingResponse(BaseModel):
    ok: bool = True
    rating_id: str
    recording_id: str
    community_score: float | None = None
    avg_score: float | None = None
    rating_count: int = 0
    points_awarded: int = 0
    total_points: int = 0
    auto_approved: bool = False
    status: str = "pending"


class RatingComment(BaseModel):
    id: str
    score: int
    matches_text: bool
    comment: str | None = None
    created_at: datetime


class RatingSummary(BaseModel):
    recording_id: str
    community_score: float | None = None
    rating_count: int = 0
    average_score: float | None = None
    mismatch_count: int = 0
    verified: bool = False
    comments: list[RatingComment] = []
