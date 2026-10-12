"""Text helpers tuned for the Turkmen alphabet used by Whisper training."""

from __future__ import annotations

import re
import unicodedata

# Turkmen latin alphabet (1993+): 30 letters.
TURKMEN_LETTERS = "aäbçdeňfghijžklmnöoprsştuüwýyz"

_PUNCT = r".,!?;:()«»\"'\-–—"
_ALLOWED_RE = re.compile(rf"^[0-9{re.escape(TURKMEN_LETTERS)}{re.escape(_PUNCT)}\s]+$")
_WHITESPACE_RE = re.compile(r"\s+")
_QUOTES = {"“": '"', "”": '"', "„": '"', "‘": "'", "’": "'", "`": "'"}
_SPACE_BEFORE_PUNCT = re.compile(r"\s+([,.!?;:])")


class TextProblem(ValueError):
    """Raised when a transcript cannot be used as a Whisper target."""


def normalize_text(text: str) -> str:
    """Normalize a transcript without destroying punctuation Whisper needs."""
    value = unicodedata.normalize("NFC", text)
    for source, target in _QUOTES.items():
        value = value.replace(source, target)
    value = value.replace("\u00a0", " ").replace("\u200b", "")
    value = _SPACE_BEFORE_PUNCT.sub(r"\1", value)
    value = _WHITESPACE_RE.sub(" ", value)
    return value.strip()


def validate_transcript(text: str, min_chars: int = 2, max_chars: int = 320) -> str:
    """Return the normalized transcript or raise TextProblem."""
    normalized = normalize_text(text)
    if len(normalized) < min_chars:
        raise TextProblem("transcript is too short")
    if len(normalized) > max_chars:
        raise TextProblem("transcript is too long")
    lowered = normalized.lower().replace("ý", "y")
    if not _ALLOWED_RE.match(lowered):
        bad = sorted({char for char in lowered if not re.match(rf"[0-9{re.escape(TURKMEN_LETTERS)}{re.escape(_PUNCT)}\s]", char)})
        raise TextProblem(f"unsupported characters: {' '.join(bad)}")
    if not re.search(rf"[{re.escape(TURKMEN_LETTERS)}]", lowered):
        raise TextProblem("transcript has no letters")
    return normalized


def word_count(text: str) -> int:
    return len([word for word in _WHITESPACE_RE.split(text) if word.strip(".,!?;:")])


def is_likely_duplicate(first: str, second: str) -> bool:
    """Cheap near-duplicate check used to warn about repeated takes."""
    clean = lambda value: re.sub(rf"[^{re.escape(TURKMEN_LETTERS)}]", "", value.lower())  # noqa: E731
    a, b = clean(first), clean(second)
    if not a or not b:
        return False
    if a == b:
        return True
    shorter, longer = (a, b) if len(a) <= len(b) else (b, a)
    if len(shorter) < 8:
        return False
    return shorter in longer[: len(shorter) + 3]


def speaking_rate_words_per_minute(text: str, duration_ms: int) -> float:
    if duration_ms <= 0:
        return 0.0
    return round(word_count(text) / (duration_ms / 60_000), 1)
