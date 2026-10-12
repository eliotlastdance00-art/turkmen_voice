from __future__ import annotations

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
from app.core.config import settings
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

SORT_CHOICES = "^(recent|oldest|top|worst|disputed|random|longest|shortest)$"


def _admin_item(row: dict, min_ratings: int) -> dict:
    """Map a joined admin row to the JSON the dashboard renders."""
    row = dict(row)
    score = row.get("community_score")
    labels: list[dict] = []

    def label(kind: str, text: str) -> None:
        labels.append({"kind": kind, "text": text})

    if row.get("duplicate_count"):
        label("warn", "gaýtalama")
    if row.get("report_count"):
        label("bad", f"{row['report_count']} şikaýat")
    if row.get("mismatch_count"):
        label("warn", f"tekst gabat gelmeýär ({row['mismatch_count']})")
    if (row.get("rating_count") or 0) == 0:
        label("muted", "baha ýok")
    elif (row.get("rating_count") or 0) < min_ratings:
        label("muted", f"{min_ratings - row['rating_count']} baha gerek")
    if score is not None and score < 3.0:
        label("bad", "pes baha")
    if (row.get("duration_ms") or 0) < 800:
        label("warn", "gysga")
    if (row.get("duration_ms") or 0) > 14_000:
        label("warn", "uzyn")
    if row.get("verified"):
        label("good", "tassiklanan")
    if not row.get("normalized_text"):
        label("warn", "norm ýok")

    return {
        "id": row["id"],
        "sentence_id": row.get("sentence_id"),
        "text": row.get("text"),
        "text_normalized": row.get("normalized_text") or row.get("text"),
        "language": row.get("language") or "tk",
        "category": row.get("category"),
        "package_id": row.get("package_id"),
        "duration_ms": row.get("duration_ms") or 0,
        "sample_rate": row.get("sample_rate") or settings.target_sample_rate,
        "channels": row.get("channels") or settings.target_channels,
        "bits_per_sample": row.get("bits_per_sample") or settings.target_bit_depth,
        "size_bytes": row.get("size_bytes") or 0,
        "sha256": row.get("sha256") or "",
        "status": row.get("status"),
        "consent_type": row.get("consent_type"),
        "created_at": row.get("created_at"),
        "reviewed_at": row.get("reviewed_at"),
        "rated_at": row.get("rated_at"),
        "community_score": score,
        "rating_count": row.get("rating_count") or 0,
        "verified": bool(row.get("verified")),
        "report_count": row.get("report_count") or 0,
        "duplicate_count": row.get("duplicate_count") or 0,
        "user_id": row.get("user_id"),
        "device_id": row.get("device_id"),
        "display_name": row.get("display_name") or "Anonim",
        "speaker_points": row.get("speaker_points") or 0,
        "min_ratings": min_ratings,
        "labels": labels,
        "audio_url": settings.audio_url(row["id"]),
        "rejection_reason": row.get("rejection_reason"),
    }


@router.get("/recordings")
def list_recordings(
    status: str | None = Query(default=None, pattern="^(pending|approved|rejected)$"),
    q: str | None = Query(default=None, max_length=120),
    sort: str = Query(default="recent", pattern=SORT_CHOICES),
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    repository: SqliteRecordingRepository = Depends(recording_repository),
):
    parsed = RecordingStatus(status) if status else None
    min_ratings = settings.auto_approve_min_ratings
    rows = repository.admin_list(parsed, q, sort, limit, offset)
    return {
        "total": repository.admin_count(parsed, q),
        "limit": limit,
        "offset": offset,
        "sort": sort,
        "min_ratings": min_ratings,
        "items": [_admin_item(row, min_ratings) for row in rows],
    }


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


# --------------------------------------------------------------------- exports
# Two URL families are kept alive: the short one (/admin/export.jsonl) used by
# the mobile docs and scripts, and the /admin/export/... one used by the panel.


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


@router.get("/export/whisper.jsonl")
def export_whisper_alias(service: DatasetService = Depends(dataset_service)):
    return FileResponse(service.export_whisper_jsonl(), media_type="application/jsonl", filename="whisper.jsonl")


@router.get("/export/dataset.jsonl")
def export_dataset_alias(service: DatasetService = Depends(dataset_service)):
    return FileResponse(service.export_jsonl(), media_type="application/jsonl", filename="dataset.jsonl")


@router.get("/export/csv")
def export_csv_alias(service: DatasetService = Depends(dataset_service)):
    return FileResponse(service.export_csv(), media_type="text/csv", filename="metadata.csv")


@router.get("/export/tsv")
def export_tsv_alias(service: DatasetService = Depends(dataset_service)):
    return FileResponse(service.export_tsv(), media_type="text/tab-separated-values", filename="manifest.tsv")


@router.get("/export/zip")
def export_zip_alias(service: DatasetService = Depends(dataset_service)):
    return FileResponse(service.export_zip_bundle(), media_type="application/zip", filename="dataset_bundle.zip")


@router.get("/export/report.json")
def export_report(service: DatasetService = Depends(dataset_service)):
    return service.report()


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
