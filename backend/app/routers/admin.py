from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse
from app.api_dependencies import dataset_service, recording_repository
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository
from app.schemas.recording import RecordingResponse, ReviewRequest
from app.services.dataset_service import DatasetService
from app.domain.entities.recording import RecordingStatus

router = APIRouter(prefix='/admin', tags=['admin'])

@router.get('/recordings', response_model=list[RecordingResponse])
def list_recordings(status: str | None = None, repository: SqliteRecordingRepository = Depends(recording_repository)):
    parsed_status = RecordingStatus(status) if status else None
    return repository.list(parsed_status)

@router.post('/recordings/{recording_id}/review', response_model=RecordingResponse)
def review_recording(recording_id: str, request: ReviewRequest, repository: SqliteRecordingRepository = Depends(recording_repository)):
    from app.services.recording_service import RecordingService
    return RecordingService(repository).review(recording_id, request.approved, request.reason)

@router.get('/export.jsonl')
def export_jsonl(service: DatasetService = Depends(dataset_service)):
    output = service.export_jsonl()
    return FileResponse(output, media_type='application/jsonl', filename='dataset.jsonl')
