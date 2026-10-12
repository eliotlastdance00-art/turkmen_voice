"""Community ratings: users rate each other's recordings (Whisper QA loop).

Flow
----
1. ``queue`` hands the user takes from *other* speakers they have not rated.
2. ``submit`` stores the rating, recomputes the community score, awards
   points to the rater and the speaker, and auto-approves takes that the
   crowd considers clear (configurable thresholds).
3. Recordings with an average below 3 stars get flagged for the admin.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import TYPE_CHECKING
from uuid import uuid4

from fastapi import HTTPException

from app.core.config import settings
from app.domain.entities.recording import Rating, Recording, RecordingStatus
from app.repositories.sqlite_rating_repository import SqliteRatingRepository
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository
from app.repositories.sqlite_user_repository import SqliteUserRepository
from app.services import points

if TYPE_CHECKING:  # pragma: no cover
    from app.domain.entities.recording import User

log = logging.getLogger("turkmen_ses.rating")


def _adjust(score: int, matches_text: bool) -> float:
    """A take that does not match the prompt can never score above 2."""
    return float(min(score, 2)) if not matches_text else float(score)


class RatingService:
    def __init__(
        self,
        recordings: SqliteRecordingRepository,
        ratings: SqliteRatingRepository,
        users: SqliteUserRepository,
    ):
        self.recordings = recordings
        self.ratings = ratings
        self.users = users

    # ------------------------------------------------------------------ queue
    def queue(self, user_id: str, limit: int = 5) -> list[dict]:
        items = self.recordings.next_for_rating(user_id, limit=limit)
        result: list[dict] = []
        for recording in items:
            speaker = self.users.get(recording.user_id) if recording.user_id else None
            result.append(
                {
                    "recording_id": recording.id,
                    "sentence_id": recording.sentence_id,
                    "text": recording.text,
                    "audio_url": settings.audio_url(recording.id),
                    "duration_ms": recording.duration_ms,
                    "category": recording.category,
                    "created_at": recording.created_at,
                    "speaker_name": speaker.display_name if speaker else "Anonim",
                    "speaker_avatar_seed": speaker.avatar_seed if speaker else 0,
                    "community_score": recording.community_score,
                    "rating_count": recording.rating_count,
                }
            )
        return result

    # ----------------------------------------------------------------- submit
    def submit(
        self,
        rater: "User",
        recording_id: str,
        score: int,
        matches_text: bool,
        comment: str | None,
        verdict: str | None = None,
    ) -> dict:
        if not 1 <= score <= 5:
            raise HTTPException(422, "score 1..5 aralygynda bolmaly")
        recording = self.recordings.get(recording_id)
        if recording is None:
            raise HTTPException(404, "Recording not found")
        if recording.user_id and recording.user_id == rater.id:
            raise HTTPException(422, "Öz ýazgyňyza baha berip bilmersiňiz")
        if self.ratings.has_rated(recording_id, rater.id):
            raise HTTPException(409, "Siz bu ýazga eýýäm baha berdiňiz")
        if self.ratings.count_today(rater.id) >= settings.ratings_daily_limit:
            raise HTTPException(429, "Günlük baha bermek çägi doldy, ertir dowam ediň")

        normalized_comment = (comment or "").strip()[:400] or None
        rating = self.ratings.add(
            Rating(
                id=f"rating_{uuid4().hex[:12]}",
                recording_id=recording_id,
                user_id=rater.id,
                score=score,
                matches_text=matches_text,
                comment=normalized_comment,
                created_at=datetime.now(timezone.utc),
            )
        )

        summary = self._recompute(recording)

        awarded = points.RATING_GIVEN
        self.users.register_rating_given(rater.id, score)
        if not matches_text and normalized_comment:
            awarded += points.RATING_CAREFUL
        total_points = self.users.add_points(rater.id, awarded, "rating_given", recording_id)

        if recording.user_id:
            self.users.register_rating_received(recording.user_id, score)

        auto_approved = self._maybe_auto_approve(recording, summary)

        return {
            "ok": True,
            "rating_id": rating.id,
            "recording_id": recording_id,
            "community_score": summary["community_score"],
            "rating_count": summary["rating_count"],
            "avg_score": summary["average_score"],
            "points_awarded": awarded,
            "total_points": total_points,
            "auto_approved": auto_approved,
            "status": (self.recordings.get(recording_id) or recording).status.value,
        }

    # ----------------------------------------------------------------- reports
    def report(self, recording_id: str, reason: str | None = None) -> dict:
        if self.recordings.get(recording_id) is None:
            raise HTTPException(404, "Recording not found")
        count = self.recordings.bump_report(recording_id)
        if count >= 3:
            self.recordings.review(
                recording_id,
                RecordingStatus.REJECTED,
                f"Jemgyýetçilik şikaýaty ({count}){(': ' + reason) if reason else ''}",
            )
        return {"ok": True, "report_count": count}

    def summary(self, recording_id: str) -> dict:
        recording = self.recordings.get(recording_id)
        if recording is None:
            raise HTTPException(404, "Recording not found")
        summary = self.ratings.summary(recording_id)
        ratings = self.ratings.list_for_recording(recording_id)
        return {
            "recording_id": recording_id,
            "community_score": recording.community_score,
            "rating_count": summary["rating_count"],
            "average_score": summary["average_score"],
            "mismatch_count": summary["mismatch_count"],
            "verified": recording.verified,
            "comments": [
                {
                    "id": item.id,
                    "score": item.score,
                    "matches_text": item.matches_text,
                    "comment": item.comment,
                    "created_at": item.created_at,
                }
                for item in ratings
                if item.comment
            ],
        }

    # ----------------------------------------------------------------- internals
    def _recompute(self, recording: Recording) -> dict:
        ratings = self.ratings.list_for_recording(recording.id, limit=500)
        if not ratings:
            self.recordings.update_community(recording.id, None, 0, False)
            return {"community_score": None, "rating_count": 0, "average_score": None}
        adjusted = [_adjust(item.score, item.matches_text) for item in ratings]
        community_score = round(sum(adjusted) / len(adjusted), 2)
        verified = (
            len(ratings) >= 3
            and community_score >= 4.5
            and all(item.matches_text for item in ratings)
        )
        self.recordings.update_community(recording.id, community_score, len(ratings), verified)
        return {
            "community_score": community_score,
            "rating_count": len(ratings),
            "average_score": round(sum(item.score for item in ratings) / len(ratings), 2),
        }

    def _maybe_auto_approve(self, recording: Recording, summary: dict) -> bool:
        refreshed = self.recordings.get(recording.id)
        if refreshed is None or refreshed.status is not RecordingStatus.PENDING:
            return False
        if (
            summary["rating_count"] >= settings.auto_approve_min_ratings
            and (summary["community_score"] or 0) >= settings.auto_approve_min_score
        ):
            self.recordings.review(
                recording.id,
                RecordingStatus.APPROVED,
                f"Awtomatik: jemgyýetçilik bahasy {summary['community_score']} "
                f"({summary['rating_count']} baha)",
            )
            if refreshed.user_id:
                self.users.add_points(
                    refreshed.user_id, points.RECORDING_APPROVED, "recording_approved", recording.id
                )
                self.users.register_approval(refreshed.user_id)
                if (summary["community_score"] or 0) >= 4.5:
                    self.users.add_points(
                        refreshed.user_id,
                        points.RECORDING_HIGH_QUALITY,
                        "recording_high_quality",
                        recording.id,
                    )
            log.info("auto-approved %s (score=%s)", recording.id, summary["community_score"])
            return True
        return False
