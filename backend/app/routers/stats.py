from fastapi import APIRouter, Depends

from app.api_dependencies import (
    current_user,
    rating_repository,
    stats_service,
    user_repository,
    user_service,
)
from app.domain.entities.recording import User, level_for_points
from app.repositories.sqlite_rating_repository import SqliteRatingRepository
from app.repositories.sqlite_user_repository import SqliteUserRepository
from app.schemas.stats import MeStatsResponse, OverviewResponse
from app.services.stats_service import StatsService
from app.services.user_service import UserService

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get("/overview", response_model=OverviewResponse)
def overview(service: StatsService = Depends(stats_service)):
    """Public corpus statistics — used by the home screen."""
    return service.overview()


@router.get("/me", response_model=MeStatsResponse)
def my_stats(
    user: User = Depends(current_user),
    users: SqliteUserRepository = Depends(user_repository),
    ratings: SqliteRatingRepository = Depends(rating_repository),
    service: UserService = Depends(user_service),
):
    profile = service.profile(user)
    return {
        "user_id": user.id,
        "display_name": user.display_name,
        "points": user.points,
        "level": level_for_points(user.points),
        "rank": profile["rank"],
        "streak_days": profile["streak_days"],
        "daily": users.daily_stats(user.id, days=14),
    }
