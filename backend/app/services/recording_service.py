from __future__ import annotations

import logging
from datetime import datetime, timezone
from pathlib import Path

from fastapi import HTTPException, UploadFile

from app.core.config import settings
from app.domain.entities.recording import Recording, RecordingStatus
from app.domain.repositories.recording_repository import RecordingRepository
from app.services import points
from app.services.audio_service import AudioProblem, normalize_audio
from app.services.text_service import TextProblem, normalize_text, validate_transcript

log = logging.getLogger("turkmen_ses.recording")


class RecordingService:
    """Use-case: accept a take, store canonical 16 kHz mono wav + metadata."""

    def __init__(self, repository: RecordingRepository, user_repository=None, audio_root: Path | None = None):
        self.repository = repository
        self.user_repository = user_repository
        self.audio_root = audio_root or settings.audio_directory

    async def create(
        self,
        recording_id: str,
        sentence_id: str,
        text: str,
        language: str,
        consent_type: str,
        duration_ms: int,
        audio_file: UploadFile,
        user_id: str | None = None,
        device_id: str | None = None,
        category: str = "general",
        package_id: str = "",
        declared_sample_rate: int | None = None,
        declared_channels: int | None = None,
        declared_bits: int | None = None,
    ) -> Recording:
        if consent_type not in {"dataset", "internal"}:
            raise HTTPException(422, "consent_type must be 'dataset' or 'internal'")

        try:
            clean_text = validate_transcript(text)
        except TextProblem as error:
            raise HTTPException(422, f"Text barlagy şowsuz: {error}") from error

        if audio_file.content_type not in settings.allowed_audio_types:
            raise HTTPException(415, "Diňe WAV/PCM ses kabul edilýär")

        raw = await audio_file.read()
        try:
            audio = normalize_audio(raw, declared_sample_rate, declared_channels, declared_bits)
        except AudioProblem as error:
            raise HTTPException(422, f"Ses barlagy şowsuz: {error}") from error

        safe_id = "".join(char for char in recording_id if char.isalnum() or char in "-_")[:100]
        if not safe_id:
            raise HTTPException(422, "recording_id nädogry")

        existing = self.repository.get(safe_id)
        if existing is not None:
            # idempotent upload: the mobile queue may retry after a timeout
            log.info("duplicate upload for %s, returning stored recording", safe_id)
            return existing

        # Bir ulanyjy bir sözlemi diňe bir gezek ýazýar (telefon şol sanawy
        # özi hem süzýär; bu — serwer tarapdaky howpsuzlyk).
        if user_id:
            previous = self.repository.find_by_user_sentence(user_id, sentence_id)
            if previous is not None and previous.status is not RecordingStatus.REJECTED:
                raise HTTPException(
                    409,
                    "Bu sözlem eýýäm ýazylan. Täzeden ýazga almak üçin öňki ýazgyňyzy pozmaly "
                    "(«Ýazgylar» bölümi) ýa-da başga sözlem saýlaň.",
                )

        shard = (user_id or device_id or "anon")[:2].lower().replace("/", "_") or "an"
        target_dir = self.audio_root / shard
        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / f"{safe_id}.wav"
        target.write_bytes(audio.data)

        recording = Recording(
            id=safe_id,
            sentence_id=sentence_id,
            user_id=user_id,
            device_id=device_id,
            text=clean_text,
            normalized_text=normalize_text(clean_text),
            language=language or "tk",
            consent_type=consent_type,
            category=category or "general",
            package_id=package_id or "",
            duration_ms=audio.duration_ms,
            audio_path=str(target),
            sample_rate=audio.sample_rate,
            channels=audio.channels,
            bits_per_sample=audio.bits_per_sample,
            size_bytes=audio.size_bytes,
            sha256=audio.sha256,
            original_format=audio.original_format,
            status=RecordingStatus.PENDING,
            created_at=datetime.now(timezone.utc),
        )
        saved = self.repository.save(recording)

        if self.user_repository is not None and user_id:
            self.user_repository.add_points(user_id, points.RECORDING_UPLOADED, "recording_uploaded", safe_id)
            self.user_repository.register_recording(user_id, audio.duration_ms)
            self.user_repository.touch(user_id)
        return saved

    def review(self, recording_id: str, approved: bool, reason: str | None) -> Recording:
        status = RecordingStatus.APPROVED if approved else RecordingStatus.REJECTED
        previous = self.repository.get(recording_id)
        result = self.repository.review(recording_id, status, reason)
        if result is None:
            raise HTTPException(404, "Recording not found")
        if previous is not None and previous.status is not status and self.user_repository is not None:
            if approved and previous.user_id:
                self.user_repository.add_points(
                    previous.user_id, points.RECORDING_APPROVED, "recording_approved", recording_id
                )
                self.user_repository.register_approval(previous.user_id)
            elif not approved and previous.status is RecordingStatus.APPROVED and previous.user_id:
                self.user_repository.add_points(
                    previous.user_id, -points.RECORDING_APPROVED, "recording_reverted", recording_id
                )
        return result

    def delete(self, recording_id: str, user_id: str | None = None, admin: bool = False) -> bool:
        recording = self.repository.get(recording_id)
        if recording is None:
            return False
        if not admin and (user_id is None or recording.user_id != user_id):
            raise HTTPException(403, "Bu ýazgy size degişli däl")
        path = Path(recording.audio_path)
        if path.exists():
            try:
                path.unlink()
            except OSError as error:  # pragma: no cover - best effort
                log.warning("could not delete audio %s: %s", path, error)
        return self.repository.delete(recording_id)
