from datetime import datetime
from pydantic import BaseModel, Field


class RecordingResponse(BaseModel):
    id: str
    sentence_id: str
    text: str
    language: str
    consent_type: str
    duration_ms: int
    status: str
    created_at: datetime
    reviewed_at: datetime | None = None
    rejection_reason: str | None = None


class ReviewRequest(BaseModel):
    approved: bool
    reason: str | None = Field(default=None, max_length=500)
