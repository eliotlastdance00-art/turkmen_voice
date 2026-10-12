from typing import Protocol

from app.domain.entities.recording import Sentence, SentencePackage


class SentenceRepository(Protocol):
    def list(
        self,
        package_id: str | None = None,
        category: str | None = None,
        limit: int = 500,
        offset: int = 0,
    ) -> list[Sentence]: ...

    def get(self, sentence_id: str) -> Sentence | None: ...

    def random(self, package_id: str | None = None, exclude: list[str] | None = None) -> Sentence | None: ...

    def packages(self) -> list[SentencePackage]: ...

    def count(self) -> int: ...
