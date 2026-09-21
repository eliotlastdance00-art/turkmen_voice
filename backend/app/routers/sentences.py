from fastapi import APIRouter, Depends
from app.api_dependencies import sentence_repository
from app.repositories.sqlite_sentence_repository import SqliteSentenceRepository
from app.schemas.sentence import SentenceResponse

router = APIRouter(prefix='/sentences', tags=['sentences'])

@router.get('', response_model=list[SentenceResponse])
def list_sentences(package_id: str | None = None, repository: SqliteSentenceRepository = Depends(sentence_repository)):
    return repository.list(package_id)
