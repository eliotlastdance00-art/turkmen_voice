from typing import Protocol
from app.domain.entities.sentence import Sentence


class SentenceRepository(Protocol):
    def list(self, package_id: str | None = None) -> list[Sentence]: ...
