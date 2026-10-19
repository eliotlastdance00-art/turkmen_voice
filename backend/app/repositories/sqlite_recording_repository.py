from __future__ import annotations

from datetime import datetime
from typing import Any

from app.db.sqlite import connection
from app.domain.entities.recording import Recording, RecordingStatus


_COLUMNS = (
    "id, sentence_id, user_id, device_id, text, normalized_text, language, consent_type,"
    " category, package_id, duration_ms, audio_path, sample_rate, channels, bits_per_sample,"
    " size_bytes, sha256, original_format, status, created_at, reviewed_at, rejection_reason,"
    " community_score, rating_count, verified, report_count"
)


class SqliteRecordingRepository:
    """Persistence for recordings (raw SQL, no ORM — sqlite keeps it tiny)."""

    def save(self, recording: Recording) -> Recording:
        with connection() as db:
            db.execute(
                """INSERT OR REPLACE INTO recordings
                (id, sentence_id, user_id, device_id, text, normalized_text, language, consent_type,
                 category, package_id, duration_ms, audio_path, sample_rate, channels, bits_per_sample,
                 size_bytes, sha256, original_format, status, created_at, reviewed_at, rejection_reason,
                 community_score, rating_count, verified, report_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    recording.id,
                    recording.sentence_id,
                    recording.user_id,
                    recording.device_id,
                    recording.text,
                    recording.normalized_text,
                    recording.language,
                    recording.consent_type,
                    recording.category,
                    recording.package_id,
                    recording.duration_ms,
                    recording.audio_path,
                    recording.sample_rate,
                    recording.channels,
                    recording.bits_per_sample,
                    recording.size_bytes,
                    recording.sha256,
                    recording.original_format,
                    recording.status.value,
                    recording.created_at.isoformat(),
                    recording.reviewed_at.isoformat() if recording.reviewed_at else None,
                    recording.rejection_reason,
                    recording.community_score,
                    recording.rating_count,
                    1 if recording.verified else 0,
                    recording.report_count,
                ),
            )
        return recording

    def get(self, recording_id: str) -> Recording | None:
        with connection() as db:
            row = db.execute(f"SELECT {_COLUMNS} FROM recordings WHERE id = ?", (recording_id,)).fetchone()
        return self._map(row) if row else None

    def find_by_user_sentence(self, user_id: str, sentence_id: str) -> Recording | None:
        """Bir ulanyjynyň şu sözlem üçin iň soňky ýazgysy."""
        if not user_id or not sentence_id:
            return None
        with connection() as db:
            row = db.execute(
                f"SELECT {_COLUMNS} FROM recordings WHERE user_id = ? AND sentence_id = ?"
                " ORDER BY created_at DESC LIMIT 1",
                (user_id, sentence_id),
            ).fetchone()
        return self._map(row) if row else None

    def list(
        self,
        status: RecordingStatus | None = None,
        user_id: str | None = None,
        query: str | None = None,
        limit: int = 500,
        offset: int = 0,
    ) -> list[Recording]:
        sql = f"SELECT {_COLUMNS} FROM recordings"
        clauses: list[str] = []
        params: list[Any] = []
        if status is not None:
            clauses.append("status = ?")
            params.append(status.value)
        if user_id:
            clauses.append("user_id = ?")
            params.append(user_id)
        if query:
            clauses.append("(text LIKE ? OR id LIKE ? OR normalized_text LIKE ?)")
            like = f"%{query}%"
            params.extend([like, like, like])
        if clauses:
            sql += " WHERE " + " AND ".join(clauses)
        sql += " ORDER BY created_at DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])
        with connection() as db:
            rows = db.execute(sql, tuple(params)).fetchall()
        return [self._map(row) for row in rows]

    # ------------------------------------------------------------------ admin
    ADMIN_SORTS = {
        "recent": "r.created_at DESC",
        "oldest": "r.created_at ASC",
        "top": "COALESCE(r.community_score, 0) DESC, r.rating_count DESC",
        "worst": "COALESCE(r.community_score, 9) ASC, r.rating_count DESC",
        "disputed": "r.report_count DESC, r.created_at DESC",
        "random": "RANDOM()",
        "longest": "r.duration_ms DESC",
        "shortest": "r.duration_ms ASC",
    }

    def _admin_where(self, status: RecordingStatus | None, query: str | None) -> tuple[str, list[Any]]:
        clauses: list[str] = []
        params: list[Any] = []
        if status is not None:
            clauses.append("r.status = ?")
            params.append(status.value)
        if query:
            like = f"%{query}%"
            clauses.append(
                "(r.text LIKE ? OR r.normalized_text LIKE ? OR r.id LIKE ?"
                " OR r.sentence_id LIKE ? OR u.display_name LIKE ? OR r.device_id LIKE ?)"
            )
            params.extend([like] * 6)
        return (" WHERE " + " AND ".join(clauses)) if clauses else "", params

    def admin_list(
        self,
        status: RecordingStatus | None = None,
        query: str | None = None,
        sort: str = "recent",
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict]:
        """Admin table rows: recording + speaker + community signals."""
        where, params = self._admin_where(status, query)
        order = self.ADMIN_SORTS.get(sort, self.ADMIN_SORTS["recent"])
        sql = f"""
            SELECT r.id, r.sentence_id, r.user_id, r.device_id, r.text, r.normalized_text,
                   r.category, r.package_id, r.duration_ms, r.sample_rate, r.channels,
                   r.bits_per_sample, r.size_bytes, r.sha256, r.status, r.created_at,
                   r.reviewed_at, r.rejection_reason, r.community_score, r.rating_count,
                   r.verified, r.report_count, r.consent_type,
                   u.display_name AS display_name, u.points AS speaker_points,
                   (SELECT MAX(g.created_at) FROM ratings g WHERE g.recording_id = r.id) AS rated_at,
                   (SELECT COUNT(*) FROM ratings g2 WHERE g2.recording_id = r.id AND g2.matches_text = 0) AS mismatch_count,
                   (SELECT COUNT(*) FROM recordings d WHERE d.sha256 = r.sha256 AND d.sha256 != ''
                        AND d.id != r.id) AS duplicate_count
            FROM recordings r
            LEFT JOIN users u ON u.id = r.user_id
            {where}
            ORDER BY {order}
            LIMIT ? OFFSET ?
        """
        with connection() as db:
            rows = db.execute(sql, tuple(params + [max(1, min(limit, 500)), max(0, offset)])).fetchall()
        return [dict(row) for row in rows]

    def admin_count(self, status: RecordingStatus | None = None, query: str | None = None) -> int:
        where, params = self._admin_where(status, query)
        sql = f"SELECT COUNT(*) AS total FROM recordings r LEFT JOIN users u ON u.id = r.user_id {where}"
        with connection() as db:
            row = db.execute(sql, tuple(params)).fetchone()
        return int(row["total"]) if row else 0

    def community_health(self) -> dict:
        """Aggregate signals used by the admin dashboard and the dataset report."""
        with connection() as db:
            row = db.execute(
                """SELECT
                     SUM(CASE WHEN status = 'approved' AND rating_count > 0
                              AND COALESCE(community_score, 0) >= 4.0 THEN 1 ELSE 0 END) AS healthy,
                     SUM(CASE WHEN rating_count > 0 THEN 1 ELSE 0 END) AS rated,
                     SUM(CASE WHEN status = 'approved' AND rating_count >= 3 THEN 1 ELSE 0 END) AS consensus,
                     COALESCE(SUM(CASE WHEN rating_count > 0 THEN duration_ms ELSE 0 END), 0) AS listened_ms,
                     SUM(CASE WHEN report_count > 0 THEN 1 ELSE 0 END) AS disputed,
                     SUM(CASE WHEN rating_count = 0 AND status = 'pending' THEN 1 ELSE 0 END) AS waiting
                   FROM recordings"""
            ).fetchone()
        return dict(row) if row else {}

    def next_for_rating(self, user_id: str, limit: int = 5) -> list[Recording]:
        """Recordings from *other* speakers that this user has not rated yet.

        Ordering prefers takes the crowd has not verified yet, then the
        oldest ones so every recording eventually gets feedback.
        """
        sql = f"""
            SELECT {_COLUMNS} FROM recordings r
            WHERE r.status = 'pending'
              AND (r.user_id IS NULL OR r.user_id != ?)
              AND NOT EXISTS (SELECT 1 FROM ratings g WHERE g.recording_id = r.id AND g.user_id = ?)
              AND r.duration_ms >= ?
            ORDER BY r.rating_count ASC, r.created_at ASC
            LIMIT ?
        """
        with connection() as db:
            rows = db.execute(
                sql, (user_id, user_id, 400, max(1, min(limit, 20)))
            ).fetchall()
        return [self._map(row) for row in rows]

    def review(self, recording_id: str, status: RecordingStatus, reason: str | None) -> Recording | None:
        from datetime import timezone

        reviewed_at = datetime.now(timezone.utc).isoformat()
        with connection() as db:
            cursor = db.execute(
                "UPDATE recordings SET status = ?, reviewed_at = ?, rejection_reason = ? WHERE id = ?",
                (status.value, reviewed_at, reason, recording_id),
            )
            if cursor.rowcount == 0:
                return None
        return self.get(recording_id)

    def update_community(self, recording_id: str, community_score: float | None, rating_count: int, verified: bool) -> None:
        with connection() as db:
            db.execute(
                "UPDATE recordings SET community_score = ?, rating_count = ?, verified = ? WHERE id = ?",
                (community_score, rating_count, 1 if verified else 0, recording_id),
            )

    def bump_report(self, recording_id: str) -> int:
        with connection() as db:
            db.execute("UPDATE recordings SET report_count = report_count + 1 WHERE id = ?", (recording_id,))
            row = db.execute("SELECT report_count FROM recordings WHERE id = ?", (recording_id,)).fetchone()
        return int(row["report_count"]) if row else 0

    def delete(self, recording_id: str) -> bool:
        with connection() as db:
            cursor = db.execute("DELETE FROM recordings WHERE id = ?", (recording_id,))
            db.execute("DELETE FROM ratings WHERE recording_id = ?", (recording_id,))
            return cursor.rowcount > 0

    def stats(self) -> dict:
        with connection() as db:
            row = db.execute(
                """SELECT
                    COUNT(*) AS total,
                    COALESCE(SUM(duration_ms), 0) AS duration_ms,
                    COALESCE(SUM(CASE WHEN status = 'approved' THEN duration_ms ELSE 0 END), 0) AS approved_duration_ms,
                    COALESCE(SUM(size_bytes), 0) AS bytes,
                    SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved,
                    SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending,
                    SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS rejected,
                    SUM(CASE WHEN verified = 1 THEN 1 ELSE 0 END) AS verified,
                    COUNT(DISTINCT user_id) AS speakers,
                    AVG(community_score) AS avg_community_score,
                    AVG(duration_ms) AS avg_duration_ms
                FROM recordings"""
            ).fetchone()
        return dict(row) if row else {}

    def daily_counts(self, days: int = 14) -> list[dict]:
        with connection() as db:
            rows = db.execute(
                """SELECT substr(created_at, 1, 10) AS day, COUNT(*) AS recordings,
                          COALESCE(SUM(duration_ms), 0) AS duration_ms
                   FROM recordings GROUP BY day ORDER BY day DESC LIMIT ?""",
                (days,),
            ).fetchall()
        return [dict(row) for row in rows]

    def by_speaker(self) -> list[dict]:
        with connection() as db:
            rows = db.execute(
                """SELECT COALESCE(user_id, 'anonymous') AS speaker_id, COUNT(*) AS recordings,
                          COALESCE(SUM(duration_ms), 0) AS duration_ms,
                          AVG(community_score) AS avg_score
                   FROM recordings WHERE status = 'approved'
                   GROUP BY speaker_id ORDER BY recordings DESC"""
            ).fetchall()
        return [dict(row) for row in rows]

    def by_category(self) -> list[dict]:
        with connection() as db:
            rows = db.execute(
                """SELECT category, COUNT(*) AS recordings, COALESCE(SUM(duration_ms), 0) AS duration_ms
                   FROM recordings WHERE status = 'approved' GROUP BY category ORDER BY recordings DESC"""
            ).fetchall()
        return [dict(row) for row in rows]

    def risky_recordings(self) -> list[dict]:
        """Recordings that a Whisper pipeline would likely want to fix."""
        with connection() as db:
            rows = db.execute(
                """SELECT id, text, duration_ms, size_bytes, rating_count, community_score, report_count
                   FROM recordings
                   WHERE status = 'approved'
                     AND (duration_ms < 800 OR duration_ms > 14_000
                          OR rating_count = 0 OR report_count > 0
                          OR (community_score IS NOT NULL AND community_score < 3.0))
                   ORDER BY duration_ms"""
            ).fetchall()
        return [dict(row) for row in rows]

    @staticmethod
    def _map(row) -> Recording:
        return Recording(
            id=row["id"],
            sentence_id=row["sentence_id"],
            user_id=row["user_id"],
            device_id=row["device_id"],
            text=row["text"],
            normalized_text=row["normalized_text"] or row["text"],
            language=row["language"],
            consent_type=row["consent_type"],
            category=row["category"] or "general",
            package_id=row["package_id"] or "",
            duration_ms=row["duration_ms"],
            audio_path=row["audio_path"],
            sample_rate=row["sample_rate"] or 16_000,
            channels=row["channels"] or 1,
            bits_per_sample=row["bits_per_sample"] or 16,
            size_bytes=row["size_bytes"] or 0,
            sha256=row["sha256"] or "",
            original_format=row["original_format"] or "wav",
            status=RecordingStatus(row["status"]),
            created_at=datetime.fromisoformat(row["created_at"]),
            reviewed_at=datetime.fromisoformat(row["reviewed_at"]) if row["reviewed_at"] else None,
            rejection_reason=row["rejection_reason"],
            community_score=row["community_score"],
            rating_count=row["rating_count"] or 0,
            verified=bool(row["verified"]),
            report_count=row["report_count"] or 0,
        )
