from pydantic import BaseModel


class SentenceResponse(BaseModel):
    id: str
    text: str
    language: str
    category: str
    package_id: str
    word_count: int = 0
    difficulty: int = 1


class SentencePackageResponse(BaseModel):
    id: str
    name: str
    description: str
    language: str
    category: str
    sentence_count: int
    approved_recordings: int = 0
