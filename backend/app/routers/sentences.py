from fastapi import APIRouter, Depends, HTTPException, Query

from app.api_dependencies import sentence_repository
from app.repositories.sqlite_sentence_repository import SqliteSentenceRepository
from app.schemas.sentence import SentencePackageResponse, SentenceResponse

router = APIRouter(prefix="/sentences", tags=["sentences"])


@router.get("", response_model=list[SentenceResponse])
def list_sentences(
    package_id: str | None = None,
    category: str | None = None,
    limit: int = Query(default=500, ge=1, le=2000),
    offset: int = Query(default=0, ge=0),
    repository: SqliteSentenceRepository = Depends(sentence_repository),
):
    return repository.list(package_id, category, limit, offset)


@router.get("/packages", response_model=list[SentencePackageResponse])
def list_packages(repository: SqliteSentenceRepository = Depends(sentence_repository)):
    return repository.packages()


@router.get("/random", response_model=SentenceResponse)
def random_sentence(
    package_id: str | None = None,
    exclude: str | None = Query(default=None, description="Comma separated sentence ids already recorded"),
    repository: SqliteSentenceRepository = Depends(sentence_repository),
):
    exclude_ids = [item for item in (exclude or "").split(",") if item][:200]
    sentence = repository.random(package_id, exclude_ids or None)
    if sentence is None:
        raise HTTPException(404, "Sözlem tapylmady")
    return sentence


@router.get("/{sentence_id}", response_model=SentenceResponse)
def get_sentence(sentence_id: str, repository: SqliteSentenceRepository = Depends(sentence_repository)):
    sentence = repository.get(sentence_id)
    if sentence is None:
        raise HTTPException(404, "Sözlem tapylmady")
    return sentence
