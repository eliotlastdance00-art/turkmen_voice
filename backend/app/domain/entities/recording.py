"""Domain entities — pure python, no framework imports."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum


class RecordingStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class RatingVerdict(StrEnum):
    GOOD = "good"
    OK = "ok"
    BAD = "bad"


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
    user_id: str | None = None
    device_id: str | None = None
    normalized_text: str = ""
    category: str = "general"
    package_id: str = ""
    sample_rate: int = 16_000
    channels: int = 1
    bits_per_sample: int = 16
    size_bytes: int = 0
    sha256: str = ""
    original_format: str = "wav"
    reviewed_at: datetime | None = None
    rejection_reason: str | None = None
    community_score: float | None = None
    rating_count: int = 0
    verified: bool = False
    report_count: int = 0


@dataclass(frozen=True)
class Sentence:
    id: str
    text: str
    language: str
    category: str
    package_id: str
    word_count: int = 0
    difficulty: int = 1


@dataclass(frozen=True)
class SentencePackage:
    id: str
    name: str
    description: str
    language: str
    category: str
    sentence_count: int = 0
    approved_recordings: int = 0


@dataclass(frozen=True)
class User:
    id: str
    device_id: str
    display_name: str
    created_at: datetime
    last_seen_at: datetime
    avatar_seed: int = 0
    language: str = "tk"
    consent_type: str = "dataset"
    points: int = 0
    ratings_given: int = 0
    ratings_received: int = 0
    score_sum: int = 0
    approved_count: int = 0
    blocked: bool = False

    @property
    def level_name(self) -> str:
        return level_for_points(self.points)["name"]


@dataclass(frozen=True)
class Rating:
    id: str
    recording_id: str
    user_id: str
    score: int
    matches_text: bool
    created_at: datetime
    comment: str | None = None


@dataclass(frozen=True)
class Level:
    index: int
    name: str
    min_points: int
    next_points: int | None


LEVELS: tuple[tuple[int, str], ...] = (
    (0, "Başlangyç"),
    (50, "Ses ýazyjy"),
    (150, "Usaç"),
    (400, "Ussat"),
    (1000, "Şahyr"),
    (2500, "Türkmen sesiň goragçysy"),
)


def level_for_points(points: int) -> dict:
    index = 0
    for position, (threshold, _name) in enumerate(LEVELS):
        if points >= threshold:
            index = position
    name = LEVELS[index][1]
    next_points = LEVELS[index + 1][0] if index + 1 < len(LEVELS) else None
    span_start = LEVELS[index][0]
    span_end = next_points if next_points else span_start
    progress = 1.0 if next_points is None else max(
        0.0, min(1.0, (points - span_start) / max(1, span_end - span_start))
    )
    return {
        "index": index,
        "name": name,
        "min_points": span_start,
        "next_points": next_points,
        "progress": round(progress, 3),
    }


@dataclass
class DatasetReport:
    totals: dict = field(default_factory=dict)
    durations: dict = field(default_factory=dict)
    quality: dict = field(default_factory=dict)
    speakers: list[dict] = field(default_factory=list)
    categories: list[dict] = field(default_factory=list)
    warnings: list[dict] = field(default_factory=list)
