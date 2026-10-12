from __future__ import annotations

from datetime import datetime

from app.db.sqlite import connection
from app.domain.entities.recording import Rating


class SqliteRatingRepository:
    def add(self, rating: Rating) -> Rating:
        with connection() as db:
            db.execute(
                """INSERT INTO ratings (id, recording_id, user_id, score, matches_text, comment, created_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (
                    rating.id,
                    rating.recording_id,
                    rating.user_id,
                    rating.score,
                    1 if rating.matches_text else 0,
                    rating.comment,
                    rating.created_at.isoformat(),
                ),
            )
        return rating

    def list_for_recording(self, recording_id: str, limit: int = 50) -> list[Rating]:
        with connection() as db:
            rows = db.execute(
                "SELECT * FROM ratings WHERE recording_id = ? ORDER BY created_at DESC LIMIT ?",
                (recording_id, limit),
            ).fetchall()
        return [self._map(row) for row in rows]

    def summary(self, recording_id: str) -> dict:
        with connection() as db:
            row = db.execute(
                """SELECT COUNT(*) AS count, AVG(score) AS average,
                          SUM(CASE WHEN matches_text = 0 THEN 1 ELSE 0 END) AS mismatches
                   FROM ratings WHERE recording_id = ?""",
                (recording_id,),
            ).fetchone()
        return {
            "rating_count": int(row["count"] or 0),
            "average_score": round(row["average"], 2) if row["average"] is not None else None,
            "mismatch_count": int(row["mismatches"] or 0),
        }

    def has_rated(self, recording_id: str, user_id: str) -> bool:
        with connection() as db:
            row = db.execute(
                "SELECT 1 AS value FROM ratings WHERE recording_id = ? AND user_id = ?",
                (recording_id, user_id),
            ).fetchone()
        return row is not None

    def count_today(self, user_id: str) -> int:
        day = datetime.utcnow().strftime("%Y-%m-%d")
        with connection() as db:
            row = db.execute(
                "SELECT COUNT(*) AS value FROM ratings WHERE user_id = ? AND substr(created_at, 1, 10) = ?",
                (user_id, day),
            ).fetchone()
        return int(row["value"] or 0)

    def total(self) -> int:
        with connection() as db:
            return int(db.execute("SELECT COUNT(*) AS value FROM ratings").fetchone()["value"])

    def top_raters(self, limit: int = 20) -> list[dict]:
        with connection() as db:
            rows = db.execute(
                """SELECT user_id, COUNT(*) AS ratings, AVG(score) AS average_score
                   FROM ratings GROUP BY user_id ORDER BY ratings DESC LIMIT ?""",
                (limit,),
            ).fetchall()
        return [dict(row) for row in rows]

    @staticmethod
    def _map(row) -> Rating:
        return Rating(
            id=row["id"],
            recording_id=row["recording_id"],
            user_id=row["user_id"],
            score=row["score"],
            matches_text=bool(row["matches_text"]),
            comment=row["comment"],
            created_at=datetime.fromisoformat(row["created_at"]),
        )
