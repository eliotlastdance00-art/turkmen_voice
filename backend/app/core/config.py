"""Application settings.

Everything is driven by environment variables so the same image runs
locally, on Render, Fly.io, Azure or a plain VPS:

    DATA_DIR         where sqlite + audio live (mount a volume here)
    ADMIN_TOKEN      admin panel / admin API token (empty = open dev mode)
    CORS_ORIGINS     comma separated list, default "*"
    PUBLIC_BASE_URL  public url of this service (used in exports)
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


def _env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def _env_float(name: str, default: float) -> float:
    raw = os.getenv(name)
    if not raw:
        return default
    try:
        return float(raw)
    except ValueError:
        return default


def _env_list(name: str, default: tuple[str, ...]) -> tuple[str, ...]:
    raw = os.getenv(name)
    if not raw:
        return default
    return tuple(item.strip() for item in raw.split(",") if item.strip())


@dataclass(frozen=True)
class Settings:
    app_name: str = "Turkmen Ses API"
    version: str = "0.3.0"
    api_prefix: str = "/api/v1"

    # --- storage ---------------------------------------------------------
    data_dir: Path = field(default_factory=lambda: Path(os.getenv("DATA_DIR", "app/data")))
    seed_file: Path = field(default_factory=lambda: Path(os.getenv("SEED_FILE", "app/seed/sentences_seed.json")))

    # --- audio contract (Whisper wants 16 kHz mono pcm16) ----------------
    target_sample_rate: int = _env_int("TARGET_SAMPLE_RATE", 16_000)
    target_channels: int = _env_int("TARGET_CHANNELS", 1)
    target_bit_depth: int = _env_int("TARGET_BIT_DEPTH", 16)
    min_duration_ms: int = _env_int("MIN_DURATION_MS", 500)
    max_duration_ms: int = _env_int("MAX_DURATION_MS", 15_000)
    max_audio_bytes: int = _env_int("MAX_AUDIO_BYTES", 10 * 1024 * 1024)
    min_rms_dbfs: float = _env_float("MIN_RMS_DBFS", -50.0)
    allowed_audio_types: tuple[str, ...] = (
        "audio/wav",
        "audio/x-wav",
        "audio/wave",
        "audio/pcm",
        "application/octet-stream",
    )

    # --- community ratings ----------------------------------------------
    auto_approve_min_ratings: int = _env_int("AUTO_APPROVE_MIN_RATINGS", 3)
    auto_approve_min_score: float = _env_float("AUTO_APPROVE_MIN_SCORE", 4.0)
    max_ratings_per_user_per_recording: int = 1
    ratings_daily_limit: int = _env_int("RATINGS_DAILY_LIMIT", 400)

    # --- auth / cors -----------------------------------------------------
    admin_token: str = os.getenv("ADMIN_TOKEN", "")
    cors_origins: tuple[str, ...] = field(default_factory=lambda: _env_list("CORS_ORIGINS", ("*",)))
    public_base_url: str = os.getenv("PUBLIC_BASE_URL", "")

    # ---------------------------------------------------------------------
    @property
    def database_path(self) -> Path:
        return self.data_dir / "turkmen_ses.db"

    @property
    def audio_directory(self) -> Path:
        return self.data_dir / "audio"

    @property
    def export_directory(self) -> Path:
        return self.data_dir / "exports"

    @property
    def admin_open(self) -> bool:
        """True when no ADMIN_TOKEN is configured (local development only)."""
        return not self.admin_token

    def prepare_directories(self) -> None:
        for directory in (self.data_dir, self.audio_directory, self.export_directory):
            directory.mkdir(parents=True, exist_ok=True)

    def audio_url(self, recording_id: str) -> str:
        path = f"{self.api_prefix}/recordings/{recording_id}/audio"
        return f"{self.public_base_url.rstrip('/')}{path}" if self.public_base_url else path


settings = Settings()
