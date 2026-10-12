from fastapi import APIRouter, Depends, Query

from app.api_dependencies import optional_user, user_service
from app.domain.entities.recording import User
from app.schemas.stats import LeaderboardResponse
from app.services.user_service import UserService

router = APIRouter(tags=["leaderboard"])


@router.get("/leaderboard", response_model=LeaderboardResponse)
def leaderboard(
    limit: int = Query(default=20, ge=1, le=100),
    period: str = Query(default="all", pattern="^(all|week|month)$"),
    user: User | None = Depends(optional_user),
    service: UserService = Depends(user_service),
):
    """Ranking among users: points, uploaded seconds and received ratings.

    ``me`` is always present for signed in callers so the profile screen can
    highlight the current user even when they are outside the top list.
    """
    return service.leaderboard(limit=limit, period=period, me=user)
