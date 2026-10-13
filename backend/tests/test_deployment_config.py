"""Deploy kontrakt barlaglary (FastAPI Cloud + Docker).

Bu testler kod üýtgände deployyň bozulmazlygyny barlaýar:
  * `pyproject.toml`-daky FastAPI Cloud entrypoint hakykatdan import bolýar,
  * `pyproject.toml` (Cloud) we `requirements.txt` (Docker) wersiýalary deň,
  * `DATA_DIR` işleýän bukjadan garaşsyz (cwd-dan) dogry tapylýar,
  * admin panel we `/` salgysy Cloud-da hem işleýär,
  * TrustedHost nädogry Host bilen islegi ret edýär (public_base_url goýlan ýagdaýda).
"""

from __future__ import annotations

import importlib
import tomllib
from pathlib import Path

from fastapi import FastAPI

BACKEND_ROOT = Path(__file__).resolve().parents[1]


def _pyproject() -> dict:
    return tomllib.loads((BACKEND_ROOT / "pyproject.toml").read_text(encoding="utf-8"))


def test_fastapi_cloud_entrypoint_resolves() -> None:
    entrypoint = _pyproject()["tool"]["fastapi"]["entrypoint"]
    module_path, _, attribute = entrypoint.partition(":")

    module = importlib.import_module(module_path)
    assert isinstance(getattr(module, attribute), FastAPI)


def test_cloud_and_docker_requirements_stay_in_sync() -> None:
    project_deps = {dep.split(";")[0].strip() for dep in _pyproject()["project"]["dependencies"]}
    docker_deps = {
        line.split("#")[0].strip()
        for line in (BACKEND_ROOT / "requirements.txt").read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    }

    def pin(requirements: set[str], package: str) -> str | None:
        for item in requirements:
            name, _, version = item.partition("==")
            if name.split("[")[0].strip() == package:
                return version.strip() or None
        return None

    for package in ("fastapi", "python-multipart"):
        cloud, docker = pin(project_deps, package), pin(docker_deps, package)
        assert cloud, f"pyproject.toml-da {package} ýok"
        assert cloud == docker, f"{package}: pyproject={cloud} requirements={docker}"


def test_python_version_is_supported_by_cloud() -> None:
    requires_python = _pyproject()["project"]["requires-python"]
    assert requires_python.startswith(">=3.1"), requires_python


def test_data_dir_is_absolute_and_writable(client) -> None:
    from app.core.config import settings

    assert settings.data_dir.is_absolute(), "DATA_DIR cwd-a bagly bolmaly däl"

    response = client.get("/api/v1/health/ready")
    assert response.status_code == 200
    payload = response.json()
    assert payload["ok"] is True
    assert payload["writable"] is True


def test_defaults_point_into_the_repo_not_the_cwd(monkeypatch) -> None:
    from app.core import config

    monkeypatch.delenv("DATA_DIR", raising=False)
    monkeypatch.delenv("SEED_FILE", raising=False)
    fresh = config.Settings()

    assert fresh.data_dir == config.BACKEND_ROOT / "app" / "data"
    assert fresh.seed_file == config.BACKEND_ROOT / "app" / "seed" / "sentences_seed.json"
    assert fresh.seed_file.exists(), "sözlem seed faýly bulmaly (birinji işlände göçürilýär)"


def test_admin_panel_is_served(client) -> None:
    assert client.get("/admin/").status_code == 200

    root = client.get("/", follow_redirects=False)
    assert root.status_code in (302, 307)
    assert root.headers["location"] == "/admin/"


def test_health_reports_admin_protection(client) -> None:
    payload = client.get("/api/v1/health").json()
    assert payload["ok"] is True
    assert payload["admin_protected"] is True


def test_unknown_host_is_rejected_when_public_url_is_set(client) -> None:
    # conftest PUBLIC_BASE_URL=http://testserver/api/v1 goýýar.
    assert client.get("/api/v1/health").status_code == 200
    assert client.get("/api/v1/health", headers={"Host": "evil.example"}).status_code == 400
