"""End-to-end smoke test against a running (or deployed) backend.

    python scripts/smoke_test.py --base-url https://turkmen-ses-api.onrender.com/api/v1
    python scripts/smoke_test.py --base-url http://localhost:8000/api/v1 --admin-token secret

It exercises exactly the calls the Flutter app makes, so a green run means
"the phone can talk to this server".
"""

from __future__ import annotations

import argparse
import io
import json
import sys
import uuid
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.services.audio_service import silent_wav, wav_to_raw_pcm  # noqa: E402

PASS, FAIL = "✔", "✘"
results: list[tuple[bool, str, str]] = []


def check(condition: bool, title: str, detail: str = "") -> None:
    results.append((bool(condition), title, detail))
    print(f"{PASS if condition else FAIL} {title}" + (f" — {detail}" if detail and not condition else ""))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8000/api/v1")
    parser.add_argument("--admin-token", default="")
    parser.add_argument("--timeout", type=float, default=60)
    args = parser.parse_args()

    base = args.base_url.rstrip("/")
    admin = {"X-Admin-Token": args.admin_token} if args.admin_token else {}
    client = httpx.Client(base_url=base, timeout=args.timeout)
    print(f"→ {base}\n")

    # health -----------------------------------------------------------------
    health = client.get("/health")
    check(health.status_code == 200 and health.json().get("ok"), "health", health.text[:200])
    ready = client.get("/health/ready")
    if ready.status_code == 200:
        check(ready.json().get("writable") is True, "storage is writable", ready.text[:200])

    # sentences --------------------------------------------------------------
    packages = client.get("/sentences/packages").json()
    check(len(packages) > 0, f"sentence packages ({len(packages)})")
    sentences = client.get("/sentences", params={"limit": 5}).json()
    check(len(sentences) > 0, "sentence list", json.dumps(sentences)[:200])
    sentence = sentences[0]

    # user -------------------------------------------------------------------
    device_id = f"smoke-{uuid.uuid4().hex[:12]}"
    registered = client.post("/users/register", json={"device_id": device_id, "display_name": "Smoke Test"})
    check(registered.status_code == 200, "user register", registered.text[:300])
    account = registered.json()
    auth = {"Authorization": f"Bearer {account['token']}"}

    # upload (both formats: proper wav and what the first APK produced) ------
    for label, payload in (("wav", silent_wav(1300)), ("raw pcm16 (old APK)", wav_to_raw_pcm(silent_wav(1300)))):
        response = client.post(
            "/recordings",
            headers=auth,
            data={
                "recording_id": f"smoke-{uuid.uuid4().hex[:10]}",
                "sentence_id": sentence["id"],
                "text": sentence["text"],
                "language": "tk",
                "consent_type": "dataset",
                "duration_ms": 1300,
                "category": sentence.get("category", "general"),
                "package_id": sentence.get("package_id", ""),
                "sample_rate": 16000,
                "channels": 1,
                "bit_depth": 16,
            },
            files={"audio_file": ("take.wav", io.BytesIO(payload), "audio/wav")},
        )
        body = response.json() if response.headers.get("content-type", "").startswith("application/json") else {}
        check(response.status_code == 201, f"upload {label}", response.text[:300])
        if response.status_code == 201:
            recording_id = body["id"]
            audio = client.get(f"/recordings/{recording_id}/audio")
            check(audio.status_code == 200 and audio.content[:4] == b"RIFF", f"audio playback ({label})")
            check(body["sample_rate"] == 16000 and body["channels"] == 1, f"normalized format ({label})")

    # ratings ----------------------------------------------------------------
    other_device = f"smoke-{uuid.uuid4().hex[:12]}"
    other = client.post("/users/register", json={"device_id": other_device, "display_name": "Rater"}).json()
    other_auth = {"Authorization": f"Bearer {other['token']}"}
    queue = client.get("/ratings/queue", params={"limit": 5}, headers=other_auth)
    check(queue.status_code == 200, "rating queue", queue.text[:300])
    items = queue.json() if queue.status_code == 200 else []
    target = next((item for item in items if item["recording_id"] == recording_id), None)
    if target is None:
        check(bool(items), "rating queue has takes from other speakers", json.dumps(items)[:200])
        target = items[0] if items else None
    if target:
        rated = client.post(
            f"/recordings/{target['recording_id']}/ratings",
            headers=other_auth,
            json={"score": 5, "matches_text": True, "comment": "Smoke test"},
        )
        check(rated.status_code == 200, "submit rating", rated.text[:300])
        if rated.status_code == 200:
            check(rated.json()["points_awarded"] >= 2, "rater receives points", rated.text[:200])

    # profile / leaderboard / stats -----------------------------------------
    me = client.get("/users/me", headers=auth)
    check(me.status_code == 200 and me.json()["user"]["stats"]["recordings"] >= 1, "profile stats", me.text[:300])
    board = client.get("/leaderboard", params={"limit": 5})
    check(board.status_code == 200 and len(board.json()["entries"]) > 0, "leaderboard", board.text[:300])
    overview = client.get("/stats/overview")
    check(overview.status_code == 200 and overview.json()["recordings_total"] > 0, "corpus stats", overview.text[:300])

    # admin ------------------------------------------------------------------
    if args.admin_token:
        admin_list = client.get("/admin/recordings", headers=admin)
        check(admin_list.status_code == 200, "admin list", admin_list.text[:300])
        whisper = client.get("/admin/export.whisper.jsonl", headers=admin)
        check(whisper.status_code == 200, "whisper export", whisper.text[:300])
        report = client.get("/admin/dataset/report.json", headers=admin)
        check(report.status_code == 200 and "totals" in report.json(), "dataset report", report.text[:300])

    failed = [item for item in results if not item[0]]
    print(f"\n{len(results) - len(failed)}/{len(results)} barlag üstünlikli")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
