from fastapi import APIRouter
from app.core.config import settings

router = APIRouter(tags=['health'])

@router.get('/health')
def health() -> dict:
    return {'ok': True, 'service': settings.app_name, 'version': settings.version}
