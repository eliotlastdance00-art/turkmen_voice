from fastapi import APIRouter, Depends, File, Form, UploadFile
from app.api_dependencies import recording_service
from app.schemas.recording import RecordingResponse
from app.services.recording_service import RecordingService

router = APIRouter(prefix='/recordings', tags=['recordings'])

@router.post('', response_model=RecordingResponse)
async def upload_recording(recording_id: str = Form(...), sentence_id: str = Form(...), text: str = Form(...), language: str = Form('tk'), consent_type: str = Form(...), duration_ms: int = Form(...), audio_file: UploadFile = File(...), service: RecordingService = Depends(recording_service)):
    return await service.create(recording_id, sentence_id, text, language, consent_type, duration_ms, audio_file)
