import os
import sys
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
os.chdir(ROOT)

TMPDIR = tempfile.mkdtemp(prefix="turkmen_ses_test_")
os.environ["DATA_DIR"] = TMPDIR
os.environ["ADMIN_TOKEN"] = "test-admin-token"
os.environ["PUBLIC_BASE_URL"] = "http://testserver/api/v1"
os.environ["AUTO_APPROVE_MIN_RATINGS"] = "3"
os.environ["AUTO_APPROVE_MIN_SCORE"] = "4.0"

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


@pytest.fixture(scope="session")
def client():
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="session")
def admin_headers():
    return {"X-Admin-Token": "test-admin-token"}


@pytest.fixture(scope="session")
def demo_audio():
    from app.services.audio_service import silent_wav, wav_to_raw_pcm

    wav = silent_wav(1200)
    return {"wav": wav, "raw_pcm": wav_to_raw_pcm(wav)}
