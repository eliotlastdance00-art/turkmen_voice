from app.core.config import settings
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository
from app.repositories.sqlite_sentence_repository import SqliteSentenceRepository
from app.services.dataset_service import DatasetService
from app.services.recording_service import RecordingService


def recording_service() -> RecordingService:
    return RecordingService(SqliteRecordingRepository())


def recording_repository() -> SqliteRecordingRepository:
    return SqliteRecordingRepository()


def sentence_repository() -> SqliteSentenceRepository:
    return SqliteSentenceRepository()


def dataset_service() -> DatasetService:
    return DatasetService(SqliteRecordingRepository(), settings.database_path.parent)
