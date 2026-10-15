"""Dependency wiring: routers never build services themselves."""

from __future__ import annotations

from fastapi import Depends, Header, HTTPException, status

from app.core.security import bearer_token, legacy_user_id
from app.domain.entities.recording import User
from app.repositories.sqlite_rating_repository import SqliteRatingRepository
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository
from app.repositories.sqlite_sentence_repository import SqliteSentenceRepository
from app.repositories.sqlite_user_repository import SqliteUserRepository
from app.services.dataset_service import DatasetService
from app.services.rating_service import RatingService
from app.services.recording_service import RecordingService
from app.services.stats_service import StatsService
from app.services.user_service import UserService


# --------------------------------------------------------------- repositories
def recording_repository() -> SqliteRecordingRepository:
    return SqliteRecordingRepository()


def sentence_repository() -> SqliteSentenceRepository:
    return SqliteSentenceRepository()


def user_repository() -> SqliteUserRepository:
    return SqliteUserRepository()


def rating_repository() -> SqliteRatingRepository:
    return SqliteRatingRepository()


# ------------------------------------------------------------------- services
def recording_service(
    recordings: SqliteRecordingRepository = Depends(recording_repository),
    users: SqliteUserRepository = Depends(user_repository),
) -> RecordingService:
    return RecordingService(recordings, users)


def user_service(
    users: SqliteUserRepository = Depends(user_repository),
    recordings: SqliteRecordingRepository = Depends(recording_repository),
) -> UserService:
    return UserService(users, recordings)


def rating_service(
    recordings: SqliteRecordingRepository = Depends(recording_repository),
    ratings: SqliteRatingRepository = Depends(rating_repository),
    users: SqliteUserRepository = Depends(user_repository),
) -> RatingService:
    return RatingService(recordings, ratings, users)


def dataset_service(recordings: SqliteRecordingRepository = Depends(recording_repository)) -> DatasetService:
    return DatasetService(recordings)


def stats_service(
    recordings: SqliteRecordingRepository = Depends(recording_repository),
    users: SqliteUserRepository = Depends(user_repository),
    ratings: SqliteRatingRepository = Depends(rating_repository),
    sentences: SqliteSentenceRepository = Depends(sentence_repository),
) -> StatsService:
    return StatsService(recordings, users, ratings, sentences)


# ------------------------------------------------------------------ identities
def optional_user(
    authorization: str | None = Header(default=None),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
    users: SqliteUserRepository = Depends(user_repository),
) -> User | None:
    """Resolve the caller from the bearer token or the raw device id.

    Three ways in, in this order:
    1. the stored account token (current app),
    2. ``tk_<user_id>`` (first APK — still supported),
    3. the ``X-Device-Id`` header (re-registers automatically).
    """
    token = bearer_token(authorization)
    if token:
        user = users.get_by_token(token)
        if user is None:
            user = users.get(legacy_user_id(token))
        if user is not None:
            return user
    if x_device_id:
        return users.get_by_device(x_device_id.strip())
    return None


def current_user(user: User | None = Depends(optional_user)) -> User:
    if user is None:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "Ilki bilen hasabyňyzy dörediň (POST /api/v1/users/register)",
        )
    if user.blocked:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Bu hasap bloklanan")
    return user
