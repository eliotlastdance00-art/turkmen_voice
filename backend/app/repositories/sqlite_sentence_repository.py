from __future__ import annotations


from app.db.sqlite import connection
from app.domain.entities.recording import Rating, Sentence, SentencePackage

_SENTENCE_COLUMNS = "id, text, language, category, package_id, word_count, difficulty"


class SqliteSentenceRepository:
    def list(
        self,
        package_id: str | None = None,
        category: str | None = None,
        limit: int = 500,
        offset: int = 0,
    ) -> list[Sentence]:
        sql = f"SELECT {_SENTENCE_COLUMNS} FROM sentences"
        clauses: list[str] = []
        params: list[object] = []
        if package_id:
            clauses.append("package_id = ?")
            params.append(package_id)
        if category:
            clauses.append("category = ?")
            params.append(category)
        if clauses:
            sql += " WHERE " + " AND ".join(clauses)
        sql += " ORDER BY id LIMIT ? OFFSET ?"
        params.extend([max(1, min(limit, 2000)), max(0, offset)])
        with connection() as db:
            rows = db.execute(sql, tuple(params)).fetchall()
        return [self._map(row) for row in rows]

    def get(self, sentence_id: str) -> Sentence | None:
        with connection() as db:
            row = db.execute(
                f"SELECT {_SENTENCE_COLUMNS} FROM sentences WHERE id = ?", (sentence_id,)
            ).fetchone()
        return self._map(row) if row else None

    def random(self, package_id: str | None = None, exclude: list[str] | None = None) -> Sentence | None:
        sql = f"SELECT {_SENTENCE_COLUMNS} FROM sentences"
        clauses: list[str] = []
        params: list[object] = []
        if package_id:
            clauses.append("package_id = ?")
            params.append(package_id)
        if exclude:
            placeholders = ", ".join("?" for _ in exclude)
            clauses.append(f"id NOT IN ({placeholders})")
            params.extend(exclude)
        if clauses:
            sql += " WHERE " + " AND ".join(clauses)
        sql += " ORDER BY RANDOM() LIMIT 1"
        with connection() as db:
            row = db.execute(sql, tuple(params)).fetchone()
        return self._map(row) if row else None

    def packages(self) -> list[SentencePackage]:
        with connection() as db:
            rows = db.execute(
                """SELECT p.id, p.name, p.description, p.language, p.category,
                          COUNT(s.id) AS sentence_count,
                          (SELECT COUNT(*) FROM recordings r WHERE r.package_id = p.id AND r.status = 'approved') AS approved_recordings
                   FROM packages p LEFT JOIN sentences s ON s.package_id = p.id
                   GROUP BY p.id ORDER BY p.id"""
            ).fetchall()
        return [
            SentencePackage(
                id=row["id"],
                name=row["name"],
                description=row["description"] or "",
                language=row["language"],
                category=row["category"],
                sentence_count=row["sentence_count"] or 0,
                approved_recordings=row["approved_recordings"] or 0,
            )
            for row in rows
        ]

    def count(self) -> int:
        with connection() as db:
            return int(db.execute("SELECT COUNT(*) AS value FROM sentences").fetchone()["value"])

    @staticmethod
    def _map(row) -> Sentence:
        return Sentence(
            id=row["id"],
            text=row["text"],
            language=row["language"],
            category=row["category"],
            package_id=row["package_id"],
            word_count=row["word_count"] or len(row["text"].split()),
            difficulty=row["difficulty"] or 1,
        )
