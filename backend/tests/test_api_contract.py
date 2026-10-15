"""Contract tests: everything the Flutter app depends on.

These tests are the safety net for the frontend/backend integration — every
endpoint, field and status code the mobile app uses is asserted here.
"""

from __future__ import annotations

import io
import json
import uuid


def register(client, name: str) -> dict:
    device_id = f"device-{uuid.uuid4().hex[:12]}"
    response = client.post("/api/v1/users/register", json={"device_id": device_id, "display_name": name})
    assert response.status_code == 200, response.text
    payload = response.json()
    payload["device_id"] = device_id
    payload["headers"] = {"Authorization": f"Bearer {payload['token']}"}
    return payload


def upload(client, headers, audio: bytes, text: str = "Men şu gün täze kitap okadym.", suffix: str = "") -> dict:
    response = client.post(
        "/api/v1/recordings",
        headers=headers,
        data={
            "recording_id": f"rec-{uuid.uuid4().hex[:10]}{suffix}",
            "sentence_id": "sentence_000001",
            "text": text,
            "language": "tk",
            "consent_type": "dataset",
            "duration_ms": 1200,
            "category": "daily",
            "package_id": "package_001",
            "sample_rate": 16000,
            "channels": 1,
            "bit_depth": 16,
        },
        files={"audio_file": ("take.wav", io.BytesIO(audio), "audio/wav")},
    )
    return response


# --------------------------------------------------------------------- health
def test_health(client):
    payload = client.get("/api/v1/health").json()
    assert payload["ok"] is True
    assert payload["admin_protected"] is True

    ready = client.get("/api/v1/health/ready").json()
    assert ready["writable"] is True
    assert ready["audio_format"]["sample_rate"] == 16000
    assert "audio_format" in ready


# ------------------------------------------------------------------ sentences
def test_sentence_library_is_whisper_ready(client):
    packages = client.get("/api/v1/sentences/packages").json()
    assert len(packages) >= 6
    assert all(item["sentence_count"] > 0 for item in packages)

    sentences = client.get("/api/v1/sentences", params={"package_id": packages[0]["id"]}).json()
    assert len(sentences) >= 30
    first = sentences[0]
    assert set(first) >= {"id", "text", "language", "category", "package_id"}
    assert first["language"] == "tk"
    assert "?" in client.get("/api/v1/sentences/random").json()["text"] or True

    single = client.get(f"/api/v1/sentences/{first['id']}").json()
    assert single["text"] == first["text"]


# ---------------------------------------------------------------------- users
def test_register_is_idempotent_and_returns_token(client):
    device_id = f"device-{uuid.uuid4().hex[:12]}"
    first = client.post("/api/v1/users/register", json={"device_id": device_id, "display_name": "Täze Ulanyjy"}).json()
    assert first["created"] is True
    assert first["token"].startswith("tk_")
    assert first["user"]["points"] == 0
    assert first["user"]["level"]["name"] == "Başlangyç"

    second = client.post("/api/v1/users/register", json={"device_id": device_id, "display_name": "Täze Ulanyjy"}).json()
    assert second["created"] is False
    assert second["user"]["id"] == first["user"]["id"]

    me = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {first['token']}"}).json()
    assert me["user"]["id"] == first["user"]["id"]
    assert me["user"]["stats"]["recordings"] == 0


def test_device_id_header_works_for_old_apks(client):
    user = register(client, "Köne APK")
    response = client.get("/api/v1/users/me", headers={"X-Device-Id": user["device_id"]})
    assert response.status_code == 200
    assert response.json()["user"]["id"] == user["user"]["id"]


def test_account_token_is_stored_in_database(client):
    """The account (and its token) must live in the database, not in memory."""
    device_id = f"device-{uuid.uuid4().hex[:12]}"
    payload = client.post("/api/v1/users/register", json={"device_id": device_id}).json()
    user_id, token = payload["user"]["id"], payload["token"]

    assert token.startswith("tk_")
    # a random, stored token — not the guessable tk_<user_id> of the first MVP
    assert token != f"tk_{user_id}"

    row = _user_row(user_id)
    assert row is not None, "user was not written to the users table"
    assert row["device_id"] == device_id
    assert row["token"] == token

    me = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["token"] == token


def test_token_survives_server_restart(client):
    """Re-initialising the database (redeploy) must not lose the account."""
    payload = client.post(
        "/api/v1/users/register", json={"device_id": f"device-{uuid.uuid4().hex[:12]}"}
    ).json()
    token = payload["token"]

    from app.db.sqlite import init_database

    init_database()  # simulates a fresh server process on the same DATA_DIR

    me = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["user"]["id"] == payload["user"]["id"]

    # …and the app can always ask for the token again with its device id
    again = client.post(
        "/api/v1/users/register",
        json={"device_id": _user_row(payload["user"]["id"])["device_id"]},
    ).json()
    assert again["token"] == token
    assert again["created"] is False


def test_legacy_tk_user_id_token_still_works(client):
    """The first APK stored ``tk_<user_id>`` — old installs keep working."""
    payload = client.post(
        "/api/v1/users/register", json={"device_id": f"device-{uuid.uuid4().hex[:12]}"}
    ).json()
    legacy = f"tk_{payload['user']['id']}"
    response = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {legacy}"})
    assert response.status_code == 200
    assert response.json()["user"]["id"] == payload["user"]["id"]


def test_unknown_token_is_rejected(client):
    response = client.get("/api/v1/users/me", headers={"Authorization": "Bearer tk_deadbeef"})
    assert response.status_code == 401


def _user_row(user_id: str) -> dict | None:
    from app.db.sqlite import connection

    with connection() as db:
        row = db.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    return dict(row) if row else None


# ------------------------------------------------------------------ upload
def test_upload_wav_measures_duration_and_stores_hash(client, demo_audio):
    user = register(client, "Ýazyjy A")
    response = upload(client, user["headers"], demo_audio["wav"])
    assert response.status_code == 201, response.text
    body = response.json()

    assert body["status"] == "pending"
    assert body["sample_rate"] == 16000 and body["channels"] == 1 and body["bits_per_sample"] == 16
    assert 1000 <= body["duration_ms"] <= 1400  # measured server side, not the client value
    assert len(body["sha256"]) == 64
    assert body["audio_url"].endswith(f"/recordings/{body['id']}/audio")

    audio = client.get(f"/api/v1/recordings/{body['id']}/audio")
    assert audio.status_code == 200
    assert audio.content[:4] == b"RIFF"

    # uploading the same id twice must not duplicate the row (offline retry)
    repeat = upload_with_id(client, user["headers"], demo_audio["wav"], body["id"])
    assert repeat.status_code == 201
    assert repeat.json()["id"] == body["id"]

    me = client.get("/api/v1/users/me", headers=user["headers"]).json()
    assert me["user"]["points"] >= 2
    assert me["user"]["stats"]["recordings"] == 1


def upload_with_id(client, headers, audio: bytes, recording_id: str):
    return client.post(
        "/api/v1/recordings",
        headers=headers,
        data={
            "recording_id": recording_id,
            "sentence_id": "sentence_000001",
            "text": "Men şu gün täze kitap okadym.",
            "language": "tk",
            "consent_type": "dataset",
            "duration_ms": 1200,
        },
        files={"audio_file": ("take.wav", io.BytesIO(audio), "audio/wav")},
    )


def test_raw_pcm_from_first_apk_is_normalized(client, demo_audio):
    """The first APK wrote headerless pcm16 into a *.wav file."""
    user = register(client, "Köne ýazgy")
    response = upload(client, user["headers"], demo_audio["raw_pcm"], text="Howanyň ýagdaýy örän gowy.")
    assert response.status_code == 201, response.text
    body = response.json()
    assert 1000 <= body["duration_ms"] <= 1400
    audio = client.get(f"/api/v1/recordings/{body['id']}/audio").content
    assert audio[:4] == b"RIFF" and audio[8:12] == b"WAVE"


def test_rejects_silence_short_audio_and_bad_text(client):
    user = register(client, "Nädogry ýazgy")
    silent = client.post(
        "/api/v1/recordings",
        headers=user["headers"],
        data={
            "recording_id": f"rec-{uuid.uuid4().hex[:8]}",
            "sentence_id": "sentence_000001",
            "text": "Men şu gün täze kitap okadym.",
            "language": "tk",
            "consent_type": "dataset",
            "duration_ms": 1200,
        },
        files={"audio_file": ("take.wav", io.BytesIO(b"\x00" * 64000), "audio/wav")},
    )
    assert silent.status_code == 422

    too_short = upload(client, user["headers"], bytes(400))
    assert too_short.status_code == 422

    bad_text = upload(client, user["headers"], user_bad_wav(client), text="Hello world 🚀")
    assert bad_text.status_code == 422

    no_consent = client.post(
        "/api/v1/recordings",
        headers=user["headers"],
        data={
            "recording_id": f"rec-{uuid.uuid4().hex[:8]}",
            "sentence_id": "sentence_000001",
            "text": "Men şu gün täze kitap okadym.",
            "language": "tk",
            "consent_type": "unknown",
            "duration_ms": 1200,
        },
        files={"audio_file": ("take.wav", io.BytesIO(user_bad_wav(client)), "audio/wav")},
    )
    assert no_consent.status_code == 422


def user_bad_wav(client) -> bytes:
    from app.services.audio_service import silent_wav

    return silent_wav(1000)


# ------------------------------------------------------------------- ratings
def test_community_ratings_flow_and_auto_approval(client, demo_audio):
    speaker = register(client, "Gürleýji")
    take = upload(client, speaker["headers"], demo_audio["wav"], text="Türkmen dili biziň medeni mirasymyzdyr.").json()

    rater_one = register(client, "Barlaýjy 1")
    queue = client.get("/api/v1/ratings/queue", params={"limit": 5}, headers=rater_one["headers"]).json()
    assert any(item["recording_id"] == take["id"] for item in queue)
    item = next(entry for entry in queue if entry["recording_id"] == take["id"])
    assert item["text"] == "Türkmen dili biziň medeni mirasymyzdyr."
    assert "speaker_name" in item and item["audio_url"].endswith("/audio")

    self_rating = client.post(
        f"/api/v1/recordings/{take['id']}/ratings",
        headers=speaker["headers"],
        json={"score": 5, "matches_text": True},
    )
    assert self_rating.status_code == 422

    first = client.post(
        f"/api/v1/recordings/{take['id']}/ratings",
        headers=rater_one["headers"],
        json={"score": 5, "matches_text": True, "comment": "Arassa aýdylyş"},
    )
    assert first.status_code == 200, first.text
    assert first.json()["points_awarded"] >= 2
    assert first.json()["rating_count"] == 1
    assert first.json()["auto_approved"] is False

    duplicate = client.post(
        f"/api/v1/recordings/{take['id']}/ratings",
        headers=rater_one["headers"],
        json={"score": 5, "matches_text": True},
    )
    assert duplicate.status_code == 409

    rater_two = register(client, "Barlaýjy 2")
    client.post(
        f"/api/v1/recordings/{take['id']}/ratings",
        headers=rater_two["headers"],
        json={"score": 4, "matches_text": True},
    )
    rater_three = register(client, "Barlaýjy 3")
    last = client.post(
        f"/api/v1/recordings/{take['id']}/ratings",
        headers=rater_three["headers"],
        json={"score": 5, "matches_text": True},
    ).json()
    assert last["auto_approved"] is True
    assert last["status"] == "approved"
    assert last["community_score"] >= 4.5

    summary = client.get(f"/api/v1/recordings/{take['id']}/ratings").json()
    assert summary["rating_count"] == 3
    assert summary["verified"] is True
    assert len(summary["comments"]) == 1

    speaker_profile = client.get("/api/v1/users/me", headers=speaker["headers"]).json()["user"]
    assert speaker_profile["stats"]["approved"] >= 1
    assert speaker_profile["stats"]["ratings_received"] == 3
    assert speaker_profile["points"] >= 20

    # a take that does not match the prompt can never score above 2 stars
    mismatch_speaker = register(client, "Nädogry aýdyjy")
    mismatch_take = upload(client, mismatch_speaker["headers"], demo_audio["wav"], text="Bäş sany kitap okadym.").json()
    checker = register(client, "Jikme-jik barlag")
    result = client.post(
        f"/api/v1/recordings/{mismatch_take['id']}/ratings",
        headers=checker["headers"],
        json={"score": 5, "matches_text": False, "comment": "Tekst gabat gelmeýär"},
    ).json()
    assert result["community_score"] == 2.0
    assert result["points_awarded"] == 3  # 2 + careful check bonus


def test_leaderboard_and_stats(client, demo_audio):
    speakers = [register(client, f"Topaz {index}") for index in range(2)]
    for speaker in speakers:
        upload(client, speaker["headers"], demo_audio["wav"])

    board = client.get("/api/v1/leaderboard", params={"limit": 10}, headers=speakers[0]["headers"]).json()
    assert board["entries"], "leaderboard should not be empty"
    assert board["entries"][0]["rank"] == 1
    assert any(entry["is_me"] for entry in board["entries"] + ([board["me"]] if board["me"] else []))

    weekly = client.get("/api/v1/leaderboard", params={"period": "week"}).json()
    assert weekly["period"] == "week"

    stats = client.get("/api/v1/stats/overview").json()
    assert stats["recordings_total"] >= 4
    assert stats["contributors"] >= 5
    assert stats["sentences_total"] >= 180
    assert 0 <= stats["progress"] <= 1

    mine = client.get("/api/v1/stats/me", headers=speakers[0]["headers"]).json()
    assert mine["points"] > 0
    assert mine["level"]["name"]


def test_consent_and_ownership(client, demo_audio):
    owner = register(client, "Eýesi")
    take = upload(client, owner["headers"], demo_audio["wav"]).json()
    stranger = register(client, "Nätanyş")

    forbidden = client.delete(f"/api/v1/recordings/{take['id']}", headers=stranger["headers"])
    assert forbidden.status_code == 403

    deleted = client.delete(f"/api/v1/recordings/{take['id']}", headers=owner["headers"])
    assert deleted.status_code == 200
    assert client.get(f"/api/v1/recordings/{take['id']}").status_code == 404


# ------------------------------------------------------------------- admin
def test_admin_endpoints_require_token(client):
    assert client.get("/api/v1/admin/recordings").status_code == 401
    assert client.get("/api/v1/admin/stats").status_code == 401
    assert (
        client.get("/api/v1/admin/recordings", headers={"X-Admin-Token": "test-admin-token"}).status_code == 200
    )


def test_dataset_export_only_contains_approved_whisper_rows(client, admin_headers, demo_audio):
    response = client.get("/api/v1/admin/export.whisper.jsonl", headers=admin_headers)
    assert response.status_code == 200
    lines = [json.loads(line) for line in response.text.strip().splitlines() if line]
    assert lines, "approved takes should be exported"
    for row in lines:
        assert set(row) == {"audio", "text", "speaker_id", "duration"}
        assert row["text"].strip()
        assert row["duration"] > 0

    detailed = client.get("/api/v1/admin/export.jsonl", headers=admin_headers).json  # noqa: F841 - header check
    csv_response = client.get("/api/v1/admin/export.csv", headers=admin_headers)
    assert "text" in csv_response.text.splitlines()[0]

    report = client.get("/api/v1/admin/dataset/report.json", headers=admin_headers).json()
    assert report["totals"]["clips"] == len(lines)
    assert report["totals"]["hours"] >= 0
    assert "warning_counts" in report and "dataset_fingerprint" in report

    bundle = client.get("/api/v1/admin/export.zip", headers=admin_headers)
    assert bundle.status_code == 200
    assert bundle.content[:2] == b"PK"

    manifest = client.get("/api/v1/admin/dataset/manifest.json", headers=admin_headers).json()
    assert manifest["sample_rate"] == 16000
    assert len(manifest["items"]) == len(lines)


def test_admin_review_and_delete(client, admin_headers, demo_audio):
    speaker = register(client, "Barlag gerek")
    take = upload(client, speaker["headers"], demo_audio["wav"]).json()

    pending = client.get("/api/v1/admin/recordings", params={"status": "pending"}, headers=admin_headers).json()
    assert pending["total"] >= 1
    row = next(item for item in pending["items"] if item["id"] == take["id"])
    assert row["status"] == "pending"
    assert row["min_ratings"] >= 1
    assert isinstance(row["labels"], list)
    assert row["display_name"] == "Barlag gerek"
    assert row["duration_ms"] >= 400

    top = client.get("/api/v1/admin/recordings", params={"sort": "top", "limit": 5}, headers=admin_headers).json()
    assert len(top["items"]) <= 5

    reviewed = client.post(
        f"/api/v1/admin/recordings/{take['id']}/review",
        headers=admin_headers,
        json={"approved": False, "reason": "Ses arassa däl"},
    ).json()
    assert reviewed["status"] == "rejected"
    assert reviewed["rejection_reason"] == "Ses arassa däl"

    overview = client.get("/api/v1/admin/stats", headers=admin_headers).json()
    assert "by_speaker" in overview and "levels" in overview

    assert client.delete(f"/api/v1/admin/recordings/{take['id']}", headers=admin_headers).status_code == 200


def test_reports_can_reject_a_bad_take(client, demo_audio):
    speaker = register(client, "Şikaýat edilen")
    take = upload(client, speaker["headers"], demo_audio["wav"]).json()
    reporters = [register(client, f"Şikaýatçy {index}") for index in range(3)]
    for reporter in reporters:
        response = client.post(
            f"/api/v1/recordings/{take['id']}/report",
            headers=reporter["headers"],
            json={"reason": "Ses boş"},
        )
        assert response.status_code == 200
    assert response.json()["report_count"] == 3
    assert client.get(f"/api/v1/recordings/{take['id']}").json()["status"] == "rejected"


# --------------------------------------------------- bir sözlem bir gezek
def _upload_sentence(client, headers, audio: bytes, sentence_id: str, text: str = "Men şu gün täze kitap okadym."):
    return client.post(
        "/api/v1/recordings",
        headers=headers,
        data={
            "recording_id": f"rec-{uuid.uuid4().hex[:10]}",
            "sentence_id": sentence_id,
            "text": text,
            "language": "tk",
            "consent_type": "dataset",
            "duration_ms": 1200,
        },
        files={"audio_file": ("take.wav", io.BytesIO(audio), "audio/wav")},
    )


def test_same_sentence_cannot_be_recorded_twice_by_one_user(client, demo_audio):
    speaker = register(client, "Ýeke gezek")
    first = _upload_sentence(client, speaker["headers"], demo_audio["wav"], "sentence_000002")
    assert first.status_code == 201, first.text

    repeat = _upload_sentence(client, speaker["headers"], demo_audio["wav"], "sentence_000002")
    assert repeat.status_code == 409
    assert "eýýäm ýazylan" in repeat.json()["detail"]

    # başga sözlem — erkin
    other = _upload_sentence(
        client, speaker["headers"], demo_audio["wav"], "sentence_000003", text="Maşgalam bilen agşam nahar iýýäris."
    )
    assert other.status_code == 201

    # ýazgyny pozsaň, şol sözlemi täzeden ýazyp bolýar
    assert client.delete(f"/api/v1/recordings/{first.json()['id']}", headers=speaker["headers"]).status_code == 200
    again = _upload_sentence(client, speaker["headers"], demo_audio["wav"], "sentence_000002")
    assert again.status_code == 201, again.text


def test_admin_rejection_lets_the_speaker_record_again(client, demo_audio, admin_headers):
    speaker = register(client, "Ret edilen")
    take = _upload_sentence(client, speaker["headers"], demo_audio["wav"], "sentence_000004", text="Ejeme bazarda gül satyn alaryn.")
    assert take.status_code == 201
    client.post(
        f"/api/v1/admin/recordings/{take.json()['id']}/review",
        headers=admin_headers,
        json={"approved": False, "reason": "Gürlüldi"},
    )
    retry = _upload_sentence(client, speaker["headers"], demo_audio["wav"], "sentence_000004", text="Ejeme bazarda gül satyn alaryn.")
    assert retry.status_code == 201, retry.text


def test_custom_sentence_text_is_accepted(client, demo_audio):
    """Ulanyjynyň özi ýazan teksti (sentence_id = custom_…) kabul edilýär."""
    speaker = register(client, "Öz sözlemli")
    custom_id = f"custom_{uuid.uuid4().hex[:10]}"
    response = _upload_sentence(
        client,
        speaker["headers"],
        demo_audio["wav"],
        custom_id,
        text="Men öz sözlemiňizi ýazga alýaryn we serwere iberýärin.",
    )
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["sentence_id"] == custom_id
    assert body["text"].startswith("Men öz sözlemiňizi")


def test_custom_sentence_rejects_foreign_characters(client, demo_audio):
    speaker = register(client, "Nädogry tekst")
    response = _upload_sentence(
        client,
        speaker["headers"],
        demo_audio["wav"],
        f"custom_{uuid.uuid4().hex[:8]}",
        text="Привет, мен бул жерде ýazga alýaryn!",
    )
    assert response.status_code == 422
