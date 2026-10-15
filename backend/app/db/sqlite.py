"""SQLite bootstrap, schema migrations and sentence seed loading.

The MVP keeps sqlite on a mounted volume.  The schema is versioned with
``PRAGMA user_version`` and can also heal an *old* MVP database (the one
shipped in the first APK) by adding the missing columns.
"""

from __future__ import annotations

import json
import logging
import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager

from app.core.config import settings

log = logging.getLogger("turkmen_ses.db")

SCHEMA_VERSION = 4


SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    avatar_seed INTEGER NOT NULL DEFAULT 0,
    language TEXT NOT NULL DEFAULT 'tk',
    consent_type TEXT NOT NULL DEFAULT 'dataset',
    points INTEGER NOT NULL DEFAULT 0,
    ratings_given INTEGER NOT NULL DEFAULT 0,
    ratings_received INTEGER NOT NULL DEFAULT 0,
    score_sum INTEGER NOT NULL DEFAULT 0,
    approved_count INTEGER NOT NULL DEFAULT 0,
    blocked INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    last_seen_at TEXT NOT NULL,
    token TEXT
);

CREATE TABLE IF NOT EXISTS packages (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    language TEXT NOT NULL DEFAULT 'tk',
    category TEXT NOT NULL DEFAULT 'general',
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sentences (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    language TEXT NOT NULL DEFAULT 'tk',
    category TEXT NOT NULL DEFAULT 'general',
    package_id TEXT NOT NULL,
    word_count INTEGER NOT NULL DEFAULT 0,
    difficulty INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS recordings (
    id TEXT PRIMARY KEY,
    sentence_id TEXT NOT NULL,
    user_id TEXT,
    device_id TEXT,
    text TEXT NOT NULL,
    normalized_text TEXT NOT NULL DEFAULT '',
    language TEXT NOT NULL DEFAULT 'tk',
    consent_type TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'general',
    package_id TEXT NOT NULL DEFAULT '',
    duration_ms INTEGER NOT NULL,
    audio_path TEXT NOT NULL,
    sample_rate INTEGER NOT NULL DEFAULT 16000,
    channels INTEGER NOT NULL DEFAULT 1,
    bits_per_sample INTEGER NOT NULL DEFAULT 16,
    size_bytes INTEGER NOT NULL DEFAULT 0,
    sha256 TEXT NOT NULL DEFAULT '',
    original_format TEXT NOT NULL DEFAULT 'wav',
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL,
    reviewed_at TEXT,
    rejection_reason TEXT,
    community_score REAL,
    rating_count INTEGER NOT NULL DEFAULT 0,
    verified INTEGER NOT NULL DEFAULT 0,
    report_count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS ratings (
    id TEXT PRIMARY KEY,
    recording_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    score INTEGER NOT NULL,
    matches_text INTEGER NOT NULL DEFAULT 1,
    comment TEXT,
    created_at TEXT NOT NULL,
    UNIQUE (recording_id, user_id)
);

CREATE TABLE IF NOT EXISTS point_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    points INTEGER NOT NULL,
    detail TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS daily_stats (
    user_id TEXT NOT NULL,
    day TEXT NOT NULL,
    seconds INTEGER NOT NULL DEFAULT 0,
    recordings INTEGER NOT NULL DEFAULT 0,
    ratings INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, day)
);

CREATE INDEX IF NOT EXISTS idx_recordings_status ON recordings(status);
CREATE INDEX IF NOT EXISTS idx_recordings_user ON recordings(user_id);
CREATE INDEX IF NOT EXISTS idx_recordings_created ON recordings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ratings_recording ON ratings(recording_id);
CREATE INDEX IF NOT EXISTS idx_ratings_user ON ratings(user_id);
CREATE INDEX IF NOT EXISTS idx_points_user ON point_events(user_id);
"""

# users columns that were added after the first MVP release (old db file)
USER_COLUMN_PATCHES: dict[str, str] = {
    "token": "TEXT",
}

# columns that were added after the first MVP release (old APK / old db file)
RECORDING_COLUMN_PATCHES: dict[str, str] = {
    "user_id": "TEXT",
    "device_id": "TEXT",
    "normalized_text": "TEXT NOT NULL DEFAULT ''",
    "category": "TEXT NOT NULL DEFAULT 'general'",
    "package_id": "TEXT NOT NULL DEFAULT ''",
    "sample_rate": "INTEGER NOT NULL DEFAULT 16000",
    "channels": "INTEGER NOT NULL DEFAULT 1",
    "bits_per_sample": "INTEGER NOT NULL DEFAULT 16",
    "size_bytes": "INTEGER NOT NULL DEFAULT 0",
    "sha256": "TEXT NOT NULL DEFAULT ''",
    "original_format": "TEXT NOT NULL DEFAULT 'wav'",
    "community_score": "REAL",
    "rating_count": "INTEGER NOT NULL DEFAULT 0",
    "verified": "INTEGER NOT NULL DEFAULT 0",
    "report_count": "INTEGER NOT NULL DEFAULT 0",
}


def init_database() -> None:
    settings.prepare_directories()
    with connection() as db:
        db.executescript(SCHEMA)
        _patch_legacy_users(db)
        _patch_legacy_recordings(db)
        _ensure_indexes(db)
        db.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
    seed_library()


def _ensure_indexes(db: sqlite3.Connection) -> None:
    """Indexes that reference columns added by the legacy patches.

    They must run *after* the patches — an old database does not have
    ``users.token`` yet when ``SCHEMA`` is executed.
    """
    db.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_token ON users(token)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_users_device ON users(device_id)")


def _patch_legacy_users(db: sqlite3.Connection) -> None:
    """Old databases were created before ``users.token`` existed."""
    existing = {row[1] for row in db.execute("PRAGMA table_info(users)").fetchall()}
    for column, definition in USER_COLUMN_PATCHES.items():
        if column not in existing:
            log.info("migrating users: adding column %s", column)
            db.execute(f"ALTER TABLE users ADD COLUMN {column} {definition}")


def _patch_legacy_recordings(db: sqlite3.Connection) -> None:
    existing = {row[1] for row in db.execute("PRAGMA table_info(recordings)").fetchall()}
    for column, definition in RECORDING_COLUMN_PATCHES.items():
        if column not in existing:
            log.info("migrating recordings: adding column %s", column)
            db.execute(f"ALTER TABLE recordings ADD COLUMN {column} {definition}")


def seed_library() -> int:
    """Load sentence packages from the seed json file (idempotent)."""
    seed_path = settings.seed_file
    if not seed_path.exists():
        log.warning("seed file %s not found, skipping sentence seed", seed_path)
        return 0

    payload = json.loads(seed_path.read_text(encoding="utf-8"))
    packages = payload.get("packages", [])
    sentences = payload.get("sentences", [])
    if not sentences:
        return 0

    created_at = payload.get("created_at", "2026-01-01T00:00:00+00:00")
    inserted = 0
    with connection() as db:
        for package in packages:
            db.execute(
                "INSERT OR REPLACE INTO packages (id, name, description, language, category, created_at)"
                " VALUES (?, ?, ?, ?, ?, ?)",
                (
                    package["id"],
                    package.get("name", package["id"]),
                    package.get("description", ""),
                    package.get("language", "tk"),
                    package.get("category", "general"),
                    created_at,
                ),
            )
        for sentence in sentences:
            text = sentence["text"].strip()
            cursor = db.execute(
                "INSERT OR IGNORE INTO sentences (id, text, language, category, package_id, word_count, difficulty)"
                " VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    sentence["id"],
                    text,
                    sentence.get("language", "tk"),
                    sentence.get("category", "general"),
                    sentence.get("package_id", "package_001"),
                    len(text.split()),
                    sentence.get("difficulty", 1),
                ),
            )
            inserted += cursor.rowcount if cursor.rowcount and cursor.rowcount > 0 else 0
    if inserted:
        log.info("seeded %s new sentences", inserted)
    return inserted


@contextmanager
def connection() -> Iterator[sqlite3.Connection]:
    db = sqlite3.connect(settings.database_path, timeout=30)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    db.execute("PRAGMA journal_mode = WAL")
    try:
        yield db
        db.commit()
    finally:
        db.close()
