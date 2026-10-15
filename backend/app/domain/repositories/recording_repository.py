from typing import Protocol

from app.domain.entities.recording import Recording, RecordingStatus


class RecordingRepository(Protocol):
    def save(self, recording: Recording) -> Recording: ...

    def get(self, recording_id: str) -> Recording | None: ...

    def find_by_user_sentence(self, user_id: str, sentence_id: str) -> Recording | None: ...

    def list(
        self,
        status: RecordingStatus | None = None,
        user_id: str | None = None,
        query: str | None = None,
        limit: int = 500,
        offset: int = 0,
    ) -> list[Recording]: ...

    def review(self, recording_id: str, status: RecordingStatus, reason: str | None) -> Recording | None: ...

    def update_community(self, recording_id: str, community_score: float | None, rating_count: int, verified: bool) -> None: ...

    def delete(self, recording_id: str) -> bool: ...

    def stats(self) -> dict: ...
