"""Sözlem goraghanasynyň hili: türkmen elipbiýi, uzynlyk, gaýtalanma.

Whisper üçin niýetlenen tekst barlaglary (serwer tarapy bilen birmeňzeş).
Şu testler ýalňyş harp (rus harpy, san), ortaça uzynlykdan çykan sözlem,
gaýtalanýan sözlem we sorag belgisiz sorag ýaly ýalňyşlyklary tutýar.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from app.services.text_service import TURKMEN_LETTERS, is_likely_duplicate, normalize_text, validate_transcript

ROOT = Path(__file__).resolve().parents[2]
SEED = ROOT / "backend" / "app" / "seed" / "sentences_seed.json"

# Bir ýazgy iň köp 15 sekunt; 15 sekuntda ~200 harp aýdyp bolýar.
MAX_CHARS = 200
MAX_WORDS = 22
MIN_WORDS = 2

QUESTION_WORDS = (
    "näme",
    "nähili",
    "haçan",
    "nirede",
    "nireden",
    "näçe",
    "nädip",
    "haýsy",
    "haýsysy",
    "kim",
    "barmy",
    "my",
    "mi",
)


@pytest.fixture(scope="module")
def seed() -> dict:
    return json.loads(SEED.read_text(encoding="utf-8"))


def test_every_sentence_matches_the_server_text_rules(seed):
    """Serweriň `validate_transcript` barlagyndan geçmeli."""
    for sentence in seed["sentences"]:
        text = validate_transcript(sentence["text"])  # TextProblem goýberýär
        assert text == sentence["text"], f"{sentence['id']}: tekst normalizasiýadan geçmedi"


def test_no_digits_foreign_letters_or_double_spaces(seed):
    # Uly harplar elipbiýiň kiçi görnüşine deň (Whisper üçin hem şeýle).
    allowed = set(f"0-9{TURKMEN_LETTERS}") | set(".,!?;:()«»\"' -–—")
    for sentence in seed["sentences"]:
        text = sentence["text"]
        bad = {char for char in text.lower() if char not in allowed}
        assert not bad, f"{sentence['id']}: rugsat berilmeýän nyşan(lar): {sorted(bad)}"
        assert not re.search(r"\d", text), f"{sentence['id']}: sanlar söz bilen ýazylmaly"
        assert "  " not in text and text.strip() == text, f"{sentence['id']}: boşluk näsaz"
        assert not re.search(r"\s+[,.!?;:]", text), f"{sentence['id']}: nyşandan öň boşluk bar"


def test_length_fits_the_15_second_window(seed):
    for sentence in seed["sentences"]:
        text = sentence["text"]
        words = len(text.split())
        assert len(text) <= MAX_CHARS, f"{sentence['id']}: {len(text)} harp — 15 sekuntda okap bolmaz"
        assert MIN_WORDS <= words <= MAX_WORDS, f"{sentence['id']}: {words} söz"
        assert sentence.get("word_count", words) == words, f"{sentence['id']}: word_count nädogry"
        assert text.endswith((".", "?", "!")), f"{sentence['id']}: nokat ýok"


def test_questions_end_with_a_question_mark(seed):
    particle = re.compile(r"\b(" + "|".join(QUESTION_WORDS) + r")\b", re.IGNORECASE)
    for sentence in seed["sentences"]:
        text = sentence["text"]
        looks_like_question = particle.search(text) is not None or re.search(r"(my|mi)\?$", text)
        if looks_like_question:
            assert text.endswith("?"), f"{sentence['id']}: sorag sözlemi '?' bilen gutarmaly"


def test_no_duplicate_sentences(seed):
    seen: dict[str, str] = {}
    for sentence in seed["sentences"]:
        key = normalize_text(sentence["text"]).lower()
        if key in seen:
            assert not is_likely_duplicate(seen[key], sentence["text"]), (
                f"{sentence['id']} we {seen[key]} birmeňzeş"
            )
        seen.setdefault(key, sentence["id"])

    # umumy barlag: jübütleýin meňzeşlik ýok
    texts = [(item["id"], item["text"]) for item in seed["sentences"]]
    for index, (sid_a, text_a) in enumerate(texts):
        for sid_b, text_b in texts[index + 1 :]:
            assert not is_likely_duplicate(text_a, text_b), f"{sid_a} ≈ {sid_b}"


def test_ids_categories_and_packages_are_consistent(seed):
    ids = [item["id"] for item in seed["sentences"]]
    assert ids == sorted(ids) and len(set(ids)) == len(ids)

    packages = {package["id"]: package for package in seed["packages"]}
    for sentence in seed["sentences"]:
        package = packages[sentence["package_id"]]
        assert sentence["category"] == package["category"], f"{sentence['id']}: kategoriýa gabat gelmeýär"
        assert sentence["difficulty"] in (1, 2, 3)


def test_packages_are_not_empty_and_sizes_match(seed):
    counts: dict[str, int] = {}
    for sentence in seed["sentences"]:
        counts[sentence["package_id"]] = counts.get(sentence["package_id"], 0) + 1
    for package in seed["packages"]:
        assert counts.get(package["id"], 0) >= 30, f"{package['id']}: sözlem az"
        assert package["name"] and package["description"]
