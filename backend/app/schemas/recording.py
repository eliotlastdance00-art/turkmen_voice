from datetime import datetime

from pydantic import BaseModel, Field


class RecordingResponse(BaseModel):
    id: str
    sentence_id: str
    user_id: str | None = None
    text: str
    normalized_text: str = ""
    language: str = "tk"
    consent_type: str
    category: str = "general"
    package_id: str = ""
    duration_ms: int
    sample_rate: int = 16_000
    channels: int = 1
    bits_per_sample: int = 16
    size_bytes: int = 0
    sha256: str = ""
    status: str
    created_at: datetime
    reviewed_at: datetime | None = None
    rejection_reason: str | None = None
    community_score: float | None = None
    rating_count: int = 0
    verified: bool = False
    report_count: int = 0
    audio_url: str | None = None


class ReviewRequest(BaseModel):
    approved: bool
    reason: str | None = Field(default=None, max_length=500)


class ReportRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=300)


def to_response(recording, audio_url: str | None = None) -> RecordingResponse:
    """Map the domain entity to the API contract (single place, no drift)."""
    return RecordingResponse(
        id=recording.id,
        sentence_id=recording.sentence_id,
        user_id=recording.user_id,
        text=recording.text,
        normalized_text=recording.normalized_text or recording.text,
        language=recording.language,
        consent_type=recording.consent_type,
        category=recording.category,
        package_id=recording.package_id,
        duration_ms=recording.duration_ms,
        sample_rate=recording.sample_rate,
        channels=recording.channels,
        bits_per_sample=recording.bits_per_sample,
        size_bytes=recording.size_bytes,
        sha256=recording.sha256,
        status=recording.status.value if hasattr(recording.status, "value") else str(recording.status),
        created_at=recording.created_at,
        reviewed_at=recording.reviewed_at,
        rejection_reason=recording.rejection_reason,
        community_score=recording.community_score,
        rating_count=recording.rating_count,
        verified=recording.verified,
        report_count=recording.report_count,
        audio_url=audio_url,
    )
