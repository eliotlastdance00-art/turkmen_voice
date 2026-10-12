from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse

from app.api_dependencies import (
    dataset_service,
    rating_service,
    recording_repository,
    recording_service,
    stats_service,
    user_repository,
    user_service,
)
from app.core.security import admin_guard
from app.domain.entities.recording import RecordingStatus
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository
from app.repositories.sqlite_user_repository import SqliteUserRepository
from app.schemas.recording import RecordingResponse, ReviewRequest, to_response
from app.services.dataset_service import DatasetService
from app.services.rating_service import RatingService
from app.services.recording_service import RecordingService
from app.services.stats_service import StatsService
from app.services.user_service import UserService

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(admin_guard)])


@router.get("/recordings", response_model=list[RecordingResponse])
def list_recordings(
    status: str | None = Query(default=None, pattern="^(pending|approved|rejected)$"),
    q: str | None = None,
    limit: int = Query(default=200, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
    repository: SqliteRecordingRepository = Depends(recording_repository),
):
    parsed = RecordingStatus(status) if status else None
    return [to_response(item) for item in repository.list(parsed, query=q, limit=limit, offset=offset)]


@router.post("/recordings/{recording_id}/review", response_model=RecordingResponse)
def review_recording(
    recording_id: str,
    request: ReviewRequest,
    service: RecordingService = Depends(recording_service),
):
    return to_response(service.review(recording_id, request.approved, request.reason))


@router.delete("/recordings/{recording_id}")
def delete_recording(
    recording_id: str,
    service: RecordingService = Depends(recording_service),
):
    if service.delete(recording_id, admin=True):
        return {"ok": True, "deleted": recording_id}
    raise HTTPException(404, "Recording not found")


@router.get("/stats")
def admin_stats(service: StatsService = Depends(stats_service)):
    return service.admin_overview()


@router.get("/users")
def list_users(
    limit: int = Query(default=50, ge=1, le=200),
    users: SqliteUserRepository = Depends(user_repository),
    service: UserService = Depends(user_service),
):
    board = users.leaderboard(limit=limit)
    return {"count": users.count(), "entries": board, "levels": service.users.levels()}


@router.get("/export.jsonl")
def export_jsonl(service: DatasetService = Depends(dataset_service)):
    return FileResponse(service.export_jsonl(), media_type="application/jsonl", filename="dataset.jsonl")


@router.get("/export.whisper.jsonl")
def export_whisper_jsonl(service: DatasetService = Depends(dataset_service)):
    """Minimal `{"audio", "text", "speaker_id"}` rows for Whisper fine-tuning."""
    return FileResponse(
        service.export_whisper_jsonl(),
        media_type="application/jsonl",
        filename="whisper.jsonl",
    )


@router.get("/export.csv")
def export_csv(service: DatasetService = Depends(dataset_service)):
    return FileResponse(service.export_csv(), media_type="text/csv", filename="dataset.csv")


@router.get("/export.tsv")
def export_tsv(service: DatasetService = Depends(dataset_service)):
    return FileResponse(service.export_tsv(), media_type="text/tab-separated-values", filename="metadata.tsv")


@router.get("/export.zip")
def export_zip(service: DatasetService = Depends(dataset_service)):
    """Wav files + metadata + report in one archive (train locally)."""
    return FileResponse(service.export_zip_bundle(), media_type="application/zip", filename="dataset_bundle.zip")


@router.get("/dataset/report.json")
def dataset_report(service: DatasetService = Depends(dataset_service)):
    return service.report()


@router.get("/dataset/manifest.json")
def dataset_manifest(service: DatasetService = Depends(dataset_service)):
    return service.manifest()


@router.post("/gamification/streak/{user_id}")
def award_streak(
    user_id: str,
    users: SqliteUserRepository = Depends(user_repository),
    service: UserService = Depends(user_service),
):
    """Manual trigger for the streak bonus (also runs from the mobile app)."""
    user = users.get(user_id)
    if user is None:
        raise HTTPException(404, "Ulanyjy tapylmady")
    points = service.award_streak_bonus(user)
    return {"ok": True, "points": points, "streak_days": service.streak(user_id)}


@router.get("/rating-summary/{recording_id}")
def rating_summary(recording_id: str, service: RatingService = Depends(rating_service)):
    return service.summary(recording_id)
