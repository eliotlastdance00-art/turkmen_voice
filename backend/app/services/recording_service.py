from datetime import datetime, timezone
from pathlib import Path
import uuid
from fastapi import HTTPException, UploadFile

from app.core.config import settings
from app.domain.entities.recording import Recording, RecordingStatus
from app.domain.repositories.recording_repository import RecordingRepository


class RecordingService:
    def __init__(self, repository: RecordingRepository):
        self.repository = repository

    async def create(self, recording_id: str, sentence_id: str, text: str, language: str, consent_type: str, duration_ms: int, audio_file: UploadFile) -> Recording:
        if not text.strip() or duration_ms <= 0 or duration_ms > settings.max_duration_ms:
            raise HTTPException(422, 'Invalid text or duration')
        if audio_file.content_type not in settings.allowed_audio_types:
            raise HTTPException(415, 'Only WAV audio is supported')
        safe_id = ''.join(c for c in recording_id if c.isalnum() or c in '-_')[:100] or str(uuid.uuid4())
        data = await audio_file.read()
        if len(data) > settings.max_audio_bytes:
            raise HTTPException(413, 'Audio file is too large')
        target = settings.audio_directory / f'{safe_id}.wav'
        target.write_bytes(data)
        recording = Recording(id=safe_id, sentence_id=sentence_id, text=text.strip(), language=language, consent_type=consent_type, duration_ms=duration_ms, audio_path=str(target), status=RecordingStatus.PENDING, created_at=datetime.now(timezone.utc))
        return self.repository.save(recording)

    def review(self, recording_id: str, approved: bool, reason: str | None) -> Recording:
        status = RecordingStatus.APPROVED if approved else RecordingStatus.REJECTED
        result = self.repository.review(recording_id, status, reason)
        if result is None:
            raise HTTPException(404, 'Recording not found')
        return result
