"""Seed demo speakers + takes so the rating queue / leaderboard look alive.

    python -m scripts.seed_demo            # 6 speakers, 24 takes, some ratings
    python -m scripts.seed_demo --takes 60

Safe to run against a fresh install; it never deletes real data.
"""

from __future__ import annotations

import argparse
import io
import random
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.core.config import settings  # noqa: E402
from app.db.sqlite import init_database  # noqa: E402
from app.repositories.sqlite_rating_repository import SqliteRatingRepository  # noqa: E402
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository  # noqa: E402
from app.repositories.sqlite_sentence_repository import SqliteSentenceRepository  # noqa: E402
from app.repositories.sqlite_user_repository import SqliteUserRepository  # noqa: E402
from app.services.audio_service import silent_wav  # noqa: E402
from app.services.rating_service import RatingService  # noqa: E402
from app.services.recording_service import RecordingService  # noqa: E402
from app.services.user_service import UserService  # noqa: E402
from uuid import uuid4  # noqa: E402

SPEAKERS = [
    ("Meret", 0),
    ("Aýna", 1),
    ("Begenç", 2),
    ("Gülşat", 3),
    ("Serdar", 4),
    ("Leýla", 5),
]
COMMENTS = ["Arassa aýdylyş", "Gowy okaldy", "Bir az çalt", "Aýdyň eşidilýär", "Dowam et!"]


async def seed(takes: int, ratings_per_take: int) -> None:
    init_database()
    users = SqliteUserRepository()
    recordings = SqliteRecordingRepository()
    ratings = SqliteRatingRepository()
    sentences = SqliteSentenceRepository()
    recording_service = RecordingService(recordings, users)
    rating_service = RatingService(recordings, ratings, users)
    user_service = UserService(users, recordings)

    speakers = []
    for name, seed in SPEAKERS:
        user, _token = user_service.register(device_id=f"demo-{seed}-{uuid4().hex[:8]}", display_name=name, avatar_seed=seed)
        speakers.append(user)

    library = sentences.list(limit=2000)
    random.seed(7)
    created = 0
    for index in range(takes):
        speaker = random.choice(speakers)
        sentence = library[index % len(library)]
        duration = random.choice([900, 1200, 1500, 1900, 2400, 2900])
        info = silent_wav(duration, amplitude=random.randint(1500, 3500))
        audio = io.BytesIO(info)
        recording = await recording_service.create(
            recording_id=f"demo-{uuid4().hex[:12]}",
            sentence_id=sentence.id,
            text=sentence.text,
            language="tk",
            consent_type="dataset",
            duration_ms=duration,
            audio_file=StubUpload(audio.read()),
            user_id=speaker.id,
            device_id=speaker.device_id,
            category=sentence.category,
            package_id=sentence.package_id,
        )
        recordings.save(recording)
        created += 1
        for _ in range(ratings_per_take):
            rater = random.choice([item for item in speakers if item.id != speaker.id])
            if ratings.has_rated(recording.id, rater.id):
                continue
            try:
                rating_service.submit(
                    rater,
                    recording.id,
                    score=random.choice([5, 5, 4, 4, 3]),
                    matches_text=random.random() > 0.15,
                    comment=random.choice(COMMENTS),
                )
            except Exception:  # noqa: BLE001 - demo data, ignore limits
                continue

    # spread the timestamps so the 14 day chart is not a single spike
    with __import__("app.db.sqlite", fromlist=["connection"]).connection() as db:
        db.execute(
            "UPDATE recordings SET created_at = datetime('now', '-' || (abs(random()) % 13) || ' day')"
        )
        db.execute("UPDATE users SET last_seen_at = ?", (datetime.now(timezone.utc).isoformat(),))
    print(f"seeded {len(speakers)} speakers, {created} takes, {ratings.total()} ratings")


class StubUpload:
    """Minimal UploadFile lookalike (the service only needs read())."""

    def __init__(self, data: bytes, content_type: str = "audio/wav"):
        self._data = data
        self.content_type = content_type

    async def read(self) -> bytes:
        return self._data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--takes", type=int, default=24)
    parser.add_argument("--ratings-per-take", type=int, default=3)
    args = parser.parse_args()
    import asyncio

    asyncio.run(seed(args.takes, args.ratings_per_take))
    print("data dir:", settings.data_dir)


if __name__ == "__main__":
    main()
