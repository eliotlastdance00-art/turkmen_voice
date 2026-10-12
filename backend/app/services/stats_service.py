"""Aggregate statistics for the home screen and the admin dashboard."""

from __future__ import annotations

from datetime import datetime, timezone

from app.repositories.sqlite_rating_repository import SqliteRatingRepository
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository
from app.repositories.sqlite_sentence_repository import SqliteSentenceRepository
from app.repositories.sqlite_user_repository import SqliteUserRepository


class StatsService:
    def __init__(
        self,
        recordings: SqliteRecordingRepository,
        users: SqliteUserRepository,
        ratings: SqliteRatingRepository,
        sentences: SqliteSentenceRepository,
    ):
        self.recordings = recordings
        self.users = users
        self.ratings = ratings
        self.sentences = sentences

    def overview(self) -> dict:
        stats = self.recordings.stats()
        total_duration_ms = int(stats.get("duration_ms") or 0)
        approved = int(stats.get("approved") or 0)
        pending = int(stats.get("pending") or 0)
        return {
            "generated_at": datetime.now(timezone.utc),
            "recordings_total": int(stats.get("total") or 0),
            "approved": approved,
            "pending": pending,
            "rejected": int(stats.get("rejected") or 0),
            "verified": int(stats.get("verified") or 0),
            "contributors": self.users.count(),
            "speakers_with_approved": int(stats.get("speakers") or 0),
            "seconds_total": round(total_duration_ms / 1000, 1),
            "hours_total": round(total_duration_ms / 3_600_000, 2),
            "avg_duration_ms": int(stats.get("avg_duration_ms") or 0),
            "avg_quality": round(stats["avg_community_score"], 2) if stats.get("avg_community_score") else None,
            "ratings_total": self.ratings.total(),
            "sentences_total": self.sentences.count(),
            "packages_total": len(self.sentences.packages()),
            "storage_mb": round(int(stats.get("bytes") or 0) / 1_048_576, 2),
            "target_hours": 10.0,
            "progress": round(min(1.0, (total_duration_ms / 3_600_000) / 10.0), 4),
            "daily": self.recordings.daily_counts(days=14),
            "top_categories": self.recordings.by_category()[:6],
        }

    def admin_overview(self) -> dict:
        overview = self.overview()
        overview["by_speaker"] = self.recordings.by_speaker()[:20]
        overview["top_raters"] = self.ratings.top_raters(limit=10)
        overview["levels"] = self.users.levels()
        return overview
