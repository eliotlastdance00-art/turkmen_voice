from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    app_name: str = 'Turkmen Ses API'
    version: str = '0.2.0'
    database_path: Path = Path('app/data/turkmen_ses.db')
    audio_directory: Path = Path('app/data/audio')
    max_audio_bytes: int = 10 * 1024 * 1024
    max_duration_ms: int = 15_000
    allowed_audio_types: tuple[str, ...] = ('audio/wav', 'audio/x-wav', 'application/octet-stream')

    def prepare_directories(self) -> None:
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self.audio_directory.mkdir(parents=True, exist_ok=True)


settings = Settings()
