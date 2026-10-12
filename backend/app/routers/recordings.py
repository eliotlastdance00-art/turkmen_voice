from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse

from app.api_dependencies import (
    current_user,
    optional_user,
    rating_service,
    recording_repository,
    recording_service,
)
from app.core.config import settings
from app.core.security import admin_guard
from app.domain.entities.recording import User
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository
from app.schemas.rating import RatingRequest, RatingResponse, RatingSummary
from app.schemas.recording import RecordingResponse, ReportRequest, to_response
from app.services.rating_service import RatingService
from app.services.recording_service import RecordingService

router = APIRouter(prefix="/recordings", tags=["recordings"])


@router.post("", response_model=RecordingResponse, status_code=201)
async def upload_recording(
    recording_id: str = Form(...),
    sentence_id: str = Form(...),
    text: str = Form(...),
    consent_type: str = Form(...),
    duration_ms: int = Form(...),
    audio_file: UploadFile = File(...),
    language: str = Form("tk"),
    category: str = Form("general"),
    package_id: str = Form(""),
    sample_rate: int | None = Form(None),
    channels: int | None = Form(None),
    bit_depth: int | None = Form(None),
    user: User | None = Depends(optional_user),
    service: RecordingService = Depends(recording_service),
):
    """Upload one take.

    The server normalizes everything to 16 kHz mono PCM16 WAV, measures the
    real duration and stores the sha256, so the dataset stays Whisper-ready
    even if the client writes raw pcm (as the first APK did).
    """
    recording = await service.create(
        recording_id=recording_id,
        sentence_id=sentence_id,
        text=text,
        language=language,
        consent_type=consent_type,
        duration_ms=duration_ms,
        audio_file=audio_file,
        user_id=user.id if user else None,
        device_id=user.device_id if user else None,
        category=category,
        package_id=package_id,
        declared_sample_rate=sample_rate,
        declared_channels=channels,
        declared_bits=bit_depth,
    )
    return to_response(recording, settings.audio_url(recording.id))


@router.get("/{recording_id}", response_model=RecordingResponse)
def get_recording(
    recording_id: str,
    repository: SqliteRecordingRepository = Depends(recording_repository),
):
    recording = repository.get(recording_id)
    if recording is None:
        raise HTTPException(404, "Recording not found")
    return to_response(recording, settings.audio_url(recording.id))


@router.get("/{recording_id}/audio")
def get_audio(
    recording_id: str,
    repository: SqliteRecordingRepository = Depends(recording_repository),
):
    """Public playback endpoint — needed by the community rating screen."""
    recording = repository.get(recording_id)
    if recording is None:
        raise HTTPException(404, "Recording not found")
    return FileResponse(
        recording.audio_path,
        media_type="audio/wav",
        filename=f"{recording.id}.wav",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.delete("/{recording_id}")
def delete_recording(
    recording_id: str,
    user: User = Depends(current_user),
    repository: SqliteRecordingRepository = Depends(recording_repository),
    service: RecordingService = Depends(recording_service),
    x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
):
    """A speaker can delete their own take (privacy requirement of the MVP)."""
    is_admin = False
    if not settings.admin_open and x_admin_token and x_admin_token == settings.admin_token:
        is_admin = True
    if settings.admin_open and settings.admin_token:
        is_admin = x_admin_token == settings.admin_token
    if service.delete(recording_id, user_id=user.id, admin=is_admin):
        return {"ok": True, "deleted": recording_id}
    raise HTTPException(404, "Recording not found")


@router.post("/{recording_id}/ratings", response_model=RatingResponse)
def rate_recording(
    recording_id: str,
    request: RatingRequest,
    user: User = Depends(current_user),
    service: RatingService = Depends(rating_service),
):
    return service.submit(
        user,
        recording_id,
        score=request.score,
        matches_text=request.matches_text,
        comment=request.comment,
        verdict=request.verdict,
    )


@router.get("/{recording_id}/ratings", response_model=RatingSummary)
def recording_ratings(
    recording_id: str,
    service: RatingService = Depends(rating_service),
):
    return service.summary(recording_id)


@router.post("/{recording_id}/report")
def report_recording(
    recording_id: str,
    request: ReportRequest,
    user: User = Depends(current_user),
    service: RatingService = Depends(rating_service),
):
    return service.report(recording_id, request.reason)
