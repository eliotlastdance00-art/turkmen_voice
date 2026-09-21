from app.db.sqlite import connection
from app.domain.entities.sentence import Sentence


class SqliteSentenceRepository:
    def list(self, package_id: str | None = None) -> list[Sentence]:
        query, params = 'SELECT * FROM sentences', ()
        if package_id:
            query += ' WHERE package_id = ?'
            params = (package_id,)
        query += ' ORDER BY id'
        with connection() as db:
            rows = db.execute(query, params).fetchall()
        return [Sentence(id=row['id'], text=row['text'], language=row['language'], category=row['category'], package_id=row['package_id']) for row in rows]
