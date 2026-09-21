from datetime import datetime
from app.db.sqlite import connection
from app.domain.entities.recording import Recording, RecordingStatus


class SqliteRecordingRepository:
    def save(self, recording: Recording) -> Recording:
        with connection() as db:
            db.execute('''INSERT OR REPLACE INTO recordings
                (id, sentence_id, text, language, consent_type, duration_ms, audio_path, status, created_at, reviewed_at, rejection_reason)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', (
                recording.id, recording.sentence_id, recording.text, recording.language,
                recording.consent_type, recording.duration_ms, recording.audio_path,
                recording.status.value, recording.created_at.isoformat(),
                recording.reviewed_at.isoformat() if recording.reviewed_at else None,
                recording.rejection_reason,
            ))
        return recording

    def get(self, recording_id: str) -> Recording | None:
        with connection() as db:
            row = db.execute('SELECT * FROM recordings WHERE id = ?', (recording_id,)).fetchone()
        return self._map(row) if row else None

    def list(self, status: RecordingStatus | None = None) -> list[Recording]:
        query, params = 'SELECT * FROM recordings', ()
        if status:
            query += ' WHERE status = ?'
            params = (status.value,)
        query += ' ORDER BY created_at DESC'
        with connection() as db:
            rows = db.execute(query, params).fetchall()
        return [self._map(row) for row in rows]

    def review(self, recording_id: str, status: RecordingStatus, reason: str | None) -> Recording | None:
        reviewed_at = datetime.now().astimezone()
        with connection() as db:
            result = db.execute('UPDATE recordings SET status = ?, reviewed_at = ?, rejection_reason = ? WHERE id = ?', (status.value, reviewed_at.isoformat(), reason, recording_id))
            if result.rowcount == 0:
                return None
        return self.get(recording_id)

    @staticmethod
    def _map(row) -> Recording:
        return Recording(id=row['id'], sentence_id=row['sentence_id'], text=row['text'], language=row['language'], consent_type=row['consent_type'], duration_ms=row['duration_ms'], audio_path=row['audio_path'], status=RecordingStatus(row['status']), created_at=datetime.fromisoformat(row['created_at']), reviewed_at=datetime.fromisoformat(row['reviewed_at']) if row['reviewed_at'] else None, rejection_reason=row['rejection_reason'])
