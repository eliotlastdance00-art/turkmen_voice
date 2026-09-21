from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from app.api_dependencies import recording_repository
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository

router = APIRouter(prefix='/admin/recordings', tags=['admin-audio'])

@router.get('/{recording_id}/audio')
def audio(recording_id: str, repository: SqliteRecordingRepository = Depends(recording_repository)):
    recording = repository.get(recording_id)
    if recording is None:
        raise HTTPException(404, 'Recording not found')
    return FileResponse(recording.audio_path, media_type='audio/wav', filename=f'{recording.id}.wav')
