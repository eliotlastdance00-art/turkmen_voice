from pydantic import BaseModel


class SentenceResponse(BaseModel):
    id: str
    text: str
    language: str
    category: str
    package_id: str
