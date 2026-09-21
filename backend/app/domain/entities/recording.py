from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class RecordingStatus(StrEnum):
    PENDING = 'pending'
    APPROVED = 'approved'
    REJECTED = 'rejected'


@dataclass(frozen=True)
class Recording:
    id: str
    sentence_id: str
    text: str
    language: str
    consent_type: str
    duration_ms: int
    audio_path: str
    status: RecordingStatus
    created_at: datetime
    reviewed_at: datetime | None = None
    rejection_reason: str | None = None
