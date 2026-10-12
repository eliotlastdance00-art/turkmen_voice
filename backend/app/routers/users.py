from fastapi import APIRouter, Depends

from app.api_dependencies import current_user, user_service
from app.domain.entities.recording import User
from app.schemas.user import MeResponse, UserProfileResponse, UserRegisterRequest, UserRegisterResponse, UserUpdateRequest
from app.services.user_service import UserService

router = APIRouter(tags=["users"])


@router.post("/users/register", response_model=UserRegisterResponse)
def register(request: UserRegisterRequest, service: UserService = Depends(user_service)):
    """Idempotent anonymous signup: the device id is the identity."""
    existing = service.users.get_by_device(request.device_id.strip())
    user, token = service.register(
        device_id=request.device_id,
        display_name=request.display_name,
        avatar_seed=request.avatar_seed,
        consent_type=request.consent_type,
    )
    return {"user": service.profile(user), "token": token, "created": existing is None}


@router.get("/users/me", response_model=MeResponse)
def me(
    user: User = Depends(current_user),
    service: UserService = Depends(user_service),
):
    service.users.touch(user.id)
    return {"user": service.profile(user), "token": service.token_for(user)}


@router.patch("/users/me", response_model=UserProfileResponse)
def update_me(
    request: UserUpdateRequest,
    user: User = Depends(current_user),
    service: UserService = Depends(user_service),
):
    updated = service.update(user, request.display_name, request.avatar_seed, request.consent_type)
    return service.profile(updated)


@router.get("/users/{user_id}/profile", response_model=UserProfileResponse)
def public_profile(user_id: str, service: UserService = Depends(user_service)):
    return service.public_profile(user_id)
