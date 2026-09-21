from dataclasses import dataclass


@dataclass(frozen=True)
class Sentence:
    id: str
    text: str
    language: str
    category: str
    package_id: str
