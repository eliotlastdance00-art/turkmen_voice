import json
from pathlib import Path
from app.domain.repositories.recording_repository import RecordingRepository
from app.domain.entities.recording import RecordingStatus


class DatasetService:
    def __init__(self, repository: RecordingRepository, output_dir: Path):
        self.repository = repository
        self.output_dir = output_dir

    def export_jsonl(self) -> Path:
        output = self.output_dir / 'dataset.jsonl'
        with output.open('w', encoding='utf-8') as file:
            for recording in self.repository.list(RecordingStatus.APPROVED):
                file.write(json.dumps({'audio': recording.audio_path, 'text': recording.text, 'language': recording.language}, ensure_ascii=False) + '\n')
        return output
