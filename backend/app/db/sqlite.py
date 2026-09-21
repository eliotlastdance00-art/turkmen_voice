import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager

from app.core.config import settings


def init_database() -> None:
    settings.prepare_directories()
    with connection() as db:
        db.executescript('''
        CREATE TABLE IF NOT EXISTS recordings (
            id TEXT PRIMARY KEY, sentence_id TEXT NOT NULL, text TEXT NOT NULL,
            language TEXT NOT NULL DEFAULT 'tk', consent_type TEXT NOT NULL,
            duration_ms INTEGER NOT NULL, audio_path TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending', created_at TEXT NOT NULL,
            reviewed_at TEXT, rejection_reason TEXT
        );
        CREATE TABLE IF NOT EXISTS sentences (
            id TEXT PRIMARY KEY, text TEXT NOT NULL, language TEXT NOT NULL DEFAULT 'tk',
            category TEXT NOT NULL DEFAULT 'general', package_id TEXT NOT NULL
        );
        ''')
        if db.execute('SELECT COUNT(*) FROM sentences').fetchone()[0] == 0:
            db.executemany('INSERT INTO sentences VALUES (?, ?, ?, ?, ?)', [
                ('sentence_demo_001', 'Men şu gün täze kitap okadym.', 'tk', 'daily', 'package_001'),
                ('sentence_demo_002', 'Howanyň ýagdaýy örän gowy.', 'tk', 'weather', 'package_001'),
                ('sentence_demo_003', 'Türkmen dili biziň medeni mirasymyzdyr.', 'tk', 'general', 'package_001'),
            ])


@contextmanager
def connection() -> Iterator[sqlite3.Connection]:
    db = sqlite3.connect(settings.database_path)
    db.row_factory = sqlite3.Row
    try:
        yield db
        db.commit()
    finally:
        db.close()
