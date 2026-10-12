from __future__ import annotations

import shutil
from datetime import datetime, timezone

from fastapi import APIRouter

from app.core.config import settings

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict:
    return {
        "ok": True,
        "service": settings.app_name,
        "version": settings.version,
        "time": datetime.now(timezone.utc).isoformat(),
        "admin_protected": not settings.admin_open,
    }


@router.get("/health/ready")
def ready() -> dict:
    """Readiness probe: checks the data dir is writable and disk has room."""
    settings.prepare_directories()
    probe = settings.data_dir / ".write_probe"
    writable = True
    try:
        probe.write_text("ok", encoding="utf-8")
        probe.unlink()
    except OSError:
        writable = False
    usage = shutil.disk_usage(settings.data_dir)
    return {
        "ok": writable,
        "data_dir": str(settings.data_dir),
        "database": str(settings.database_path),
        "writable": writable,
        "free_mb": round(usage.free / 1_048_576, 1),
        "audio_format": {
            "sample_rate": settings.target_sample_rate,
            "channels": settings.target_channels,
            "bits_per_sample": settings.target_bit_depth,
            "min_duration_ms": settings.min_duration_ms,
            "max_duration_ms": settings.max_duration_ms,
        },
    }
