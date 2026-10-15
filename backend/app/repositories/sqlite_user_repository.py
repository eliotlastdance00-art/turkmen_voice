from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from app.db.sqlite import connection
from app.domain.entities.recording import LEVELS, User, level_for_points

_COLUMNS = (
    "id, device_id, display_name, avatar_seed, language, consent_type, points, ratings_given,"
    " ratings_received, score_sum, approved_count, blocked, created_at, last_seen_at, token"
)


class SqliteUserRepository:
    def get(self, user_id: str) -> User | None:
        with connection() as db:
            row = db.execute(f"SELECT {_COLUMNS} FROM users WHERE id = ?", (user_id,)).fetchone()
        return self._map(row) if row else None

    def get_by_device(self, device_id: str) -> User | None:
        with connection() as db:
            row = db.execute(f"SELECT {_COLUMNS} FROM users WHERE device_id = ?", (device_id,)).fetchone()
        return self._map(row) if row else None

    def get_by_token(self, token: str) -> User | None:
        """Look the account up by its stored token (the real login path)."""
        cleaned = (token or "").strip()
        if not cleaned:
            return None
        with connection() as db:
            row = db.execute(f"SELECT {_COLUMNS} FROM users WHERE token = ?", (cleaned,)).fetchone()
        return self._map(row) if row else None

    def set_token(self, user_id: str, token: str) -> User | None:
        with connection() as db:
            db.execute("UPDATE users SET token = ? WHERE id = ?", (token, user_id))
        return self.get(user_id)

    def create(
        self,
        device_id: str,
        display_name: str,
        avatar_seed: int,
        consent_type: str = "dataset",
        token: str | None = None,
    ) -> User:
        now = datetime.now(timezone.utc)
        user_id = f"user_{uuid4().hex[:10]}"
        with connection() as db:
            db.execute(
                """INSERT INTO users (id, device_id, display_name, avatar_seed, language, consent_type,
                                      points, created_at, last_seen_at, token)
                   VALUES (?, ?, ?, ?, 'tk', ?, 0, ?, ?, ?)""",
                (
                    user_id,
                    device_id,
                    display_name,
                    avatar_seed,
                    consent_type,
                    now.isoformat(),
                    now.isoformat(),
                    token,
                ),
            )
        created = self.get(user_id)
        assert created is not None
        return created

    def update_profile(
        self,
        user_id: str,
        display_name: str | None = None,
        avatar_seed: int | None = None,
        consent_type: str | None = None,
    ) -> User | None:
        fields: list[str] = []
        params: list[object] = []
        if display_name is not None:
            fields.append("display_name = ?")
            params.append(display_name)
        if avatar_seed is not None:
            fields.append("avatar_seed = ?")
            params.append(avatar_seed)
        if consent_type is not None:
            fields.append("consent_type = ?")
            params.append(consent_type)
        if not fields:
            return self.get(user_id)
        params.append(user_id)
        with connection() as db:
            db.execute(f"UPDATE users SET {', '.join(fields)} WHERE id = ?", tuple(params))
        return self.get(user_id)

    def touch(self, user_id: str) -> None:
        with connection() as db:
            db.execute("UPDATE users SET last_seen_at = ? WHERE id = ?", (datetime.now(timezone.utc).isoformat(), user_id))

    def add_points(self, user_id: str, points: int, kind: str, detail: str = "") -> int:
        if points == 0:
            return 0
        with connection() as db:
            db.execute(
                """INSERT INTO point_events (user_id, kind, points, detail, created_at)
                   VALUES (?, ?, ?, ?, ?)""",
                (user_id, kind, points, detail, datetime.now(timezone.utc).isoformat()),
            )
            db.execute("UPDATE users SET points = MAX(0, points + ?) WHERE id = ?", (points, user_id))
            row = db.execute("SELECT points FROM users WHERE id = ?", (user_id,)).fetchone()
        return int(row["points"]) if row else 0

    def register_rating_given(self, user_id: str, score: int) -> None:
        with connection() as db:
            db.execute(
                "UPDATE users SET ratings_given = ratings_given + 1 WHERE id = ?",
                (user_id,),
            )
            self._bump_daily(db, user_id, ratings=1)

    def register_recording(self, user_id: str, duration_ms: int) -> None:
        with connection() as db:
            self._bump_daily(db, user_id, recordings=1, seconds=int(duration_ms / 1000))

    def register_rating_received(self, user_id: str, score: int) -> None:
        if not user_id:
            return
        with connection() as db:
            db.execute(
                "UPDATE users SET ratings_received = ratings_received + 1, score_sum = score_sum + ? WHERE id = ?",
                (score, user_id),
            )

    def register_approval(self, user_id: str | None) -> None:
        if not user_id:
            return
        with connection() as db:
            db.execute("UPDATE users SET approved_count = approved_count + 1 WHERE id = ?", (user_id,))

    def daily_stats(self, user_id: str, days: int = 7) -> list[dict]:
        with connection() as db:
            rows = db.execute(
                """SELECT day, seconds, recordings, ratings FROM daily_stats
                   WHERE user_id = ? ORDER BY day DESC LIMIT ?""",
                (user_id, days),
            ).fetchall()
        return [dict(row) for row in rows]

    def active_days(self, user_id: str, limit: int = 60) -> list[str]:
        with connection() as db:
            rows = db.execute(
                """SELECT day FROM daily_stats
                   WHERE user_id = ? AND (recordings > 0 OR ratings > 0)
                   ORDER BY day DESC LIMIT ?""",
                (user_id, limit),
            ).fetchall()
        return [row["day"] for row in rows]

    def leaderboard(self, limit: int = 20, period_days: int | None = None) -> list[dict]:
        """All-time or rolling-window ranking.

        Period ranking uses ``daily_stats`` so users who just started still
        appear without a separate aggregation table.
        """
        with connection() as db:
            if period_days is None:
                rows = db.execute(
                    """SELECT u.id AS user_id, u.display_name, u.avatar_seed, u.points,
                              u.approved_count, u.ratings_given, u.ratings_received,
                              (SELECT COUNT(*) FROM recordings r WHERE r.user_id = u.id) AS recordings,
                              (SELECT COALESCE(SUM(seconds), 0) FROM daily_stats d WHERE d.user_id = u.id) AS seconds,
                              CASE WHEN u.ratings_received > 0
                                   THEN ROUND(CAST(u.score_sum AS REAL) / u.ratings_received, 2) END AS avg_score
                       FROM users u
                       WHERE u.blocked = 0
                       ORDER BY u.points DESC, recordings DESC
                       LIMIT ?""",
                    (max(1, min(limit, 100)),),
                ).fetchall()
            else:
                rows = db.execute(
                    """SELECT u.id AS user_id, u.display_name, u.avatar_seed,
                              COALESCE(SUM((d.recordings * 2) + (d.ratings * 2) + d.seconds / 10), 0) AS points,
                              u.approved_count, u.ratings_given, u.ratings_received,
                              (SELECT COUNT(*) FROM recordings r WHERE r.user_id = u.id) AS recordings,
                              COALESCE(SUM(d.seconds), 0) AS seconds,
                              CASE WHEN u.ratings_received > 0
                                   THEN ROUND(CAST(u.score_sum AS REAL) / u.ratings_received, 2) END AS avg_score
                       FROM users u LEFT JOIN daily_stats d ON d.user_id = u.id
                       WHERE u.blocked = 0 AND (d.day IS NULL OR d.day >= date('now', ?))
                       GROUP BY u.id
                       ORDER BY points DESC, seconds DESC
                       LIMIT ?""",
                    (f"-{int(period_days)} day", max(1, min(limit, 100))),
                ).fetchall()
        result: list[dict] = []
        for index, row in enumerate(rows):
            level = level_for_points(int(row["points"] or 0))
            result.append(
                {
                    "rank": index + 1,
                    "user_id": row["user_id"],
                    "display_name": row["display_name"],
                    "avatar_seed": row["avatar_seed"] or 0,
                    "points": int(row["points"] or 0),
                    "level_name": level["name"],
                    "level_index": level["index"],
                    "recordings": int(row["recordings"] or 0),
                    "seconds": int(row["seconds"] or 0),
                    "avg_score": row["avg_score"],
                    "ratings_given": int(row["ratings_given"] or 0),
                    "ratings_received": int(row["ratings_received"] or 0),
                }
            )
        return result

    def rank_of(self, user_id: str) -> int | None:
        board = self.leaderboard(limit=100)
        for entry in board:
            if entry["user_id"] == user_id:
                return entry["rank"]
        return None

    def count(self) -> int:
        with connection() as db:
            return int(db.execute("SELECT COUNT(*) AS value FROM users").fetchone()["value"])

    def levels(self) -> list[dict]:
        return [{"index": index, "name": name, "min_points": points} for index, (points, name) in enumerate(LEVELS)]

    @staticmethod
    def _bump_daily(db, user_id: str, recordings: int = 0, seconds: int = 0, ratings: int = 0) -> None:
        day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        db.execute(
            """INSERT INTO daily_stats (user_id, day, seconds, recordings, ratings)
               VALUES (?, ?, ?, ?, ?)
               ON CONFLICT(user_id, day) DO UPDATE SET
                 seconds = seconds + excluded.seconds,
                 recordings = recordings + excluded.recordings,
                 ratings = ratings + excluded.ratings""",
            (user_id, day, seconds, recordings, ratings),
        )

    @staticmethod
    def _map(row) -> User:
        return User(
            id=row["id"],
            device_id=row["device_id"],
            display_name=row["display_name"],
            avatar_seed=row["avatar_seed"] or 0,
            language=row["language"] or "tk",
            consent_type=row["consent_type"] or "dataset",
            points=row["points"] or 0,
            ratings_given=row["ratings_given"] or 0,
            ratings_received=row["ratings_received"] or 0,
            score_sum=row["score_sum"] or 0,
            approved_count=row["approved_count"] or 0,
            blocked=bool(row["blocked"]),
            token=row["token"] or "",
            created_at=datetime.fromisoformat(row["created_at"]),
            last_seen_at=datetime.fromisoformat(row["last_seen_at"]),
        )
