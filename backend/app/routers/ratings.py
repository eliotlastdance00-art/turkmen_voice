from fastapi import APIRouter, Depends, Query

from app.api_dependencies import current_user, rating_service
from app.domain.entities.recording import User
from app.schemas.rating import RatingQueueItem
from app.services.rating_service import RatingService

router = APIRouter(prefix="/ratings", tags=["ratings"])


@router.get("/queue", response_model=list[RatingQueueItem])
def rating_queue(
    limit: int = Query(default=5, ge=1, le=20),
    user: User = Depends(current_user),
    service: RatingService = Depends(rating_service),
):
    """Next takes from other speakers this user should listen to."""
    return service.queue(user.id, limit=limit)
