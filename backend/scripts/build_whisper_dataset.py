"""Turn the API export into a local Whisper fine-tuning dataset.

    # 1) get the export from the server
    curl -H "X-Admin-Token: $TOKEN" $API/admin/export.zip -o dataset_bundle.zip
    unzip dataset_bundle.zip -d dataset

    # 2) build train/validation/test splits (speaker independent!)
    python scripts/build_whisper_dataset.py --input dataset --output whisper_dataset

Output layout (HuggingFace ``datasets`` friendly):

    whisper_dataset/
      audio/…                    normalized 16 kHz mono wavs (copied)
      train.jsonl
      validation.jsonl
      test.jsonl
      dataset_info.json
      dataset_card.md            ready to push to the Hub
      validation_report.json     duration / speaker / duplicate checks

Only the python standard library is required; ``datasets``/``soundfile`` are
optional and only used when you push the result.
"""

from __future__ import annotations

import argparse
import json
import random
import shutil
import wave
from collections import Counter, defaultdict
from pathlib import Path

TARGET_SAMPLE_RATE = 16_000


def read_export(input_dir: Path) -> list[dict]:
    rows: list[dict] = []
    for name in ("whisper.jsonl", "export.jsonl", "dataset.jsonl"):
        path = input_dir / name
        if path.exists():
            for line in path.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    rows.append(json.loads(line))
            break
    if not rows:
        raise SystemExit(f"no jsonl export found in {input_dir}")
    return rows


def probe(path: Path) -> dict | None:
    try:
        with wave.open(str(path), "rb") as reader:
            return {
                "sample_rate": reader.getframerate(),
                "channels": reader.getnchannels(),
                "bits": reader.getsampwidth() * 8,
                "duration": round(reader.getnframes() / reader.getframerate(), 3),
                "frames": reader.getnframes(),
            }
    except Exception:  # noqa: BLE001
        return None


def resolve_audio(row: dict, input_dir: Path) -> Path | None:
    candidates = []
    if row.get("audio_path"):
        candidates.append(Path(row["audio_path"]))
    name = Path(str(row.get("audio", ""))).name
    if name:
        candidates.extend([input_dir / "audio" / name, input_dir / name, input_dir.parent / "audio" / name])
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="dataset", help="folder with the unzipped export")
    parser.add_argument("--output", default="whisper_dataset")
    parser.add_argument("--validation-ratio", type=float, default=0.1)
    parser.add_argument("--test-ratio", type=float, default=0.05)
    parser.add_argument("--seed", type=int, default=13)
    parser.add_argument("--copy-audio", action="store_true", default=True)
    parser.add_argument("--min-duration", type=float, default=0.4)
    parser.add_argument("--max-duration", type=float, default=15.2)
    args = parser.parse_args()

    input_dir = Path(args.input)
    output_dir = Path(args.output)
    audio_dir = output_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)

    rows = read_export(input_dir)
    random.seed(args.seed)

    kept: list[dict] = []
    problems: list[dict] = []
    for row in rows:
        source = resolve_audio(row, input_dir)
        if source is None:
            problems.append({"id": row.get("id"), "reason": "audio_missing"})
            continue
        info = probe(source)
        if not info:
            problems.append({"id": row.get("id"), "reason": "unreadable_wav"})
            continue
        if info["sample_rate"] != TARGET_SAMPLE_RATE or info["channels"] != 1 or info["bits"] != 16:
            problems.append({"id": row.get("id"), "reason": "not_16k_mono_pcm16", "info": info})
            continue
        if not (args.min_duration <= info["duration"] <= args.max_duration):
            problems.append({"id": row.get("id"), "reason": "duration_out_of_range", "info": info})
            continue
        text = (row.get("text") or "").strip()
        if len(text) < 2:
            problems.append({"id": row.get("id"), "reason": "empty_text"})
            continue

        target = audio_dir / source.name
        if args.copy_audio and source.resolve() != target.resolve():
            shutil.copy2(source, target)
        kept.append(
            {
                "audio": f"audio/{target.name}",
                "text": text,
                "speaker_id": str(row.get("speaker_id") or "anonymous"),
                "duration": info["duration"],
                "category": row.get("category", "general"),
                "community_score": row.get("community_score"),
            }
        )

    # de-duplicate by sha of text+audio name
    unique: dict[str, dict] = {}
    for row in kept:
        unique.setdefault(f"{row['audio']}|{row['text']}", row)
    duplicates = len(kept) - len(unique)
    kept = list(unique.values())

    # speaker independent split (no speaker leakage between train/val/test)
    by_speaker: dict[str, list[dict]] = defaultdict(list)
    for row in kept:
        by_speaker[row["speaker_id"]].append(row)
    speakers = sorted(by_speaker)
    random.shuffle(speakers)

    total = len(kept) or 1
    test_target = int(total * args.test_ratio)
    validation_target = int(total * args.validation_ratio)
    test_rows: list[dict] = []
    validation_rows: list[dict] = []
    for speaker in speakers:
        rows_for_speaker = by_speaker[speaker]
        if len(test_rows) < test_target and len(speakers) > 2:
            test_rows.extend(rows_for_speaker)
        elif len(validation_rows) < validation_target and len(speakers) > 1:
            validation_rows.extend(rows_for_speaker)
    assigned = {id(row) for row in test_rows + validation_rows}
    train_rows = [row for row in kept if id(row) not in assigned]
    if not validation_rows and train_rows:  # tiny datasets: slice instead of split
        cut = max(1, int(len(train_rows) * 0.1))
        validation_rows = train_rows[:cut]
        train_rows = train_rows[cut:]

    for name, split in (("train", train_rows), ("validation", validation_rows), ("test", test_rows)):
        path = output_dir / f"{name}.jsonl"
        with path.open("w", encoding="utf-8") as file:
            for row in split:
                file.write(json.dumps(row, ensure_ascii=False) + "\n")

    durations = [row["duration"] for row in kept]
    info = {
        "dataset_name": "turkmen_ses",
        "language": "tk",
        "sample_rate": TARGET_SAMPLE_RATE,
        "files": {"train": len(train_rows), "validation": len(validation_rows), "test": len(test_rows)},
        "clips": len(kept),
        "hours": round(sum(durations) / 3600, 3),
        "speakers": len(by_speaker),
        "avg_duration": round(sum(durations) / len(durations), 3) if durations else 0,
        "skipped": len(problems) + duplicates,
    }
    (output_dir / "dataset_info.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    (output_dir / "validation_report.json").write_text(
        json.dumps(
            {
                "problems": problems[:500],
                "problem_counts": dict(Counter(item["reason"] for item in problems)),
                "duplicates_removed": duplicates,
                "info": info,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    (output_dir / "dataset_card.md").write_text(
        "# Türkmen Ses dataset\n\n"
        f"- Dili: Türkmençe (tk)\n- Klipler: {info['clips']}\n- Sagat: {info['hours']}\n"
        f"- Gürleýjiler: {info['speakers']}\n- Format: 16 kHz mono PCM16 WAV\n"
        f"- Bölüniş: train {len(train_rows)} / validation {len(validation_rows)} / test {len(test_rows)}\n\n"
        "`whisper` fine-tuning üçin `whisper_finetune.py` skriptini ulanyň.\n",
        encoding="utf-8",
    )
    print(json.dumps(info, ensure_ascii=False, indent=2))
    if problems:
        print(f"\n{len(problems)} klip taşlandy — jikme-jik: {output_dir / 'validation_report.json'}")


if __name__ == "__main__":
    main()
