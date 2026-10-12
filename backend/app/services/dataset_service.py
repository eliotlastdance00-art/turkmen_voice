"""Dataset export, shaped for Whisper fine-tuning.

Exports
-------
* ``export.jsonl``      HuggingFace ``datasets`` friendly rows
                        (``{"audio": ..., "text": ..., "speaker_id": ...}``)
* ``export.csv``        spreadsheet / manual review
* ``report.json``       quality report: duration histogram, per speaker
                        coverage, duplicate / silence warnings
* ``whisper_manifest``  input for ``scripts/build_whisper_dataset.py``

Only **approved** recordings are exported, so a model never trains on a
take that the community or the admin rejected.
"""

from __future__ import annotations

import csv
import hashlib
import io
import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

from app.core.config import settings
from app.domain.entities.recording import Recording, RecordingStatus
from app.domain.repositories.recording_repository import RecordingRepository
from app.services.audio_service import probe_wav
from app.services.text_service import speaking_rate_words_per_minute, word_count


class DatasetService:
    def __init__(self, repository: RecordingRepository, output_dir: Path | None = None):
        self.repository = repository
        self.output_dir = output_dir or settings.export_directory
        self.output_dir.mkdir(parents=True, exist_ok=True)

    # --------------------------------------------------------------- helpers
    def _approved(self, include_ids: list[str] | None = None) -> list[Recording]:
        recordings = self.repository.list(RecordingStatus.APPROVED, limit=100_000)
        if include_ids:
            wanted = set(include_ids)
            recordings = [item for item in recordings if item.id in wanted]
        return recordings

    def _row(self, recording: Recording, audio_prefix: str = "audio") -> dict:
        return {
            "id": recording.id,
            "audio": f"{audio_prefix}/{Path(recording.audio_path).name}",
            "audio_path": recording.audio_path,
            "text": recording.text,
            "normalized_text": recording.normalized_text or recording.text,
            "language": recording.language,
            "speaker_id": recording.user_id or recording.device_id or "anonymous",
            "duration_ms": recording.duration_ms,
            "duration": round(recording.duration_ms / 1000, 3),
            "sample_rate": recording.sample_rate,
            "channels": recording.channels,
            "bits_per_sample": recording.bits_per_sample,
            "sha256": recording.sha256,
            "category": recording.category,
            "package_id": recording.package_id,
            "consent_type": recording.consent_type,
            "community_score": recording.community_score,
            "rating_count": recording.rating_count,
            "verified": recording.verified,
            "words_per_minute": speaking_rate_words_per_minute(recording.text, recording.duration_ms),
            "created_at": recording.created_at.isoformat(),
        }

    # --------------------------------------------------------------- exports
    def export_jsonl(self, filename: str = "export.jsonl", audio_prefix: str = "audio") -> Path:
        output = self.output_dir / filename
        with output.open("w", encoding="utf-8") as file:
            for recording in self._approved():
                file.write(json.dumps(self._row(recording, audio_prefix), ensure_ascii=False) + "\n")
        return output

    def export_whisper_jsonl(self, filename: str = "whisper.jsonl") -> Path:
        """Minimal schema expected by `datasets.load_dataset('json', ...)`."""
        output = self.output_dir / filename
        with output.open("w", encoding="utf-8") as file:
            for recording in self._approved():
                file.write(
                    json.dumps(
                        {
                            "audio": recording.audio_path,
                            "text": recording.text,
                            "speaker_id": recording.user_id or "anonymous",
                            "duration": round(recording.duration_ms / 1000, 3),
                        },
                        ensure_ascii=False,
                    )
                    + "\n"
                )
        return output

    def export_csv(self, filename: str = "export.csv") -> Path:
        output = self.output_dir / filename
        rows = [self._row(recording) for recording in self._approved()]
        fieldnames = list(rows[0].keys()) if rows else ["id", "audio", "text", "language"]
        with output.open("w", encoding="utf-8", newline="") as file:
            writer = csv.DictWriter(file, fieldnames=fieldnames)
            writer.writeheader()
            for row in rows:
                writer.writerow(row)
        return output

    def export_tsv(self, filename: str = "metadata.tsv") -> Path:
        """Common Voice style metadata (path \t sentence \t up_votes \t down_votes)."""
        output = self.output_dir / filename
        with output.open("w", encoding="utf-8", newline="") as file:
            writer = csv.writer(file, delimiter="\t")
            writer.writerow(["path", "sentence_id", "sentence", "up_votes", "down_votes", "duration_ms", "speaker_id"])
            for recording in self._approved():
                writer.writerow(
                    [
                        recording.audio_path,
                        recording.sentence_id,
                        recording.text,
                        recording.rating_count,
                        0,
                        recording.duration_ms,
                        recording.user_id or "anonymous",
                    ]
                )
        return output

    def export_zip_bundle(self, filename: str = "dataset_bundle.zip") -> Path:
        """jsonl + csv + tsv + the wav files, in one archive for local training."""
        import zipfile

        jsonl = self.export_jsonl()
        csv_path = self.export_csv()
        tsv_path = self.export_tsv()
        report = self.report()
        output = self.output_dir / filename
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in (jsonl, csv_path, tsv_path):
                archive.write(path, path.name)
            archive.writestr("report.json", json.dumps(report, ensure_ascii=False, indent=2))
            for recording in self._approved():
                audio = Path(recording.audio_path)
                if audio.exists():
                    archive.write(audio, f"audio/{audio.name}")
        return output

    # --------------------------------------------------------------- report
    def report(self) -> dict:
        recordings = self._approved()
        durations = [item.duration_ms for item in recordings]
        buckets = Counter()
        for value in durations:
            if value < 1_000:
                buckets["<1s"] += 1
            elif value < 3_000:
                buckets["1-3s"] += 1
            elif value < 6_000:
                buckets["3-6s"] += 1
            elif value < 10_000:
                buckets["6-10s"] += 1
            else:
                buckets["10-15s"] += 1

        per_speaker: dict[str, dict] = defaultdict(lambda: {"recordings": 0, "duration_ms": 0, "scores": []})
        hashes: dict[str, list[str]] = defaultdict(list)
        text_counter: Counter[str] = Counter()
        warnings: list[dict] = []

        for recording in recordings:
            speaker = recording.user_id or recording.device_id or "anonymous"
            entry = per_speaker[speaker]
            entry["recordings"] += 1
            entry["duration_ms"] += recording.duration_ms
            if recording.community_score is not None:
                entry["scores"].append(recording.community_score)
            if recording.sha256:
                hashes[recording.sha256].append(recording.id)
            text_counter[recording.normalized_text or recording.text] += 1

            if recording.duration_ms < settings.min_duration_ms:
                warnings.append({"id": recording.id, "type": "too_short", "value": recording.duration_ms})
            if recording.rating_count == 0:
                warnings.append({"id": recording.id, "type": "unrated"})
            if recording.community_score is not None and recording.community_score < 3.0:
                warnings.append({"id": recording.id, "type": "low_score", "value": recording.community_score})
            if recording.report_count:
                warnings.append({"id": recording.id, "type": "reported", "value": recording.report_count})
            probe = probe_wav(recording.audio_path)
            if not probe.get("ok"):
                warnings.append({"id": recording.id, "type": "unreadable_audio", "value": probe.get("error")})
            elif probe.get("sample_rate") != settings.target_sample_rate or probe.get("channels") != 1:
                warnings.append({"id": recording.id, "type": "wrong_format", "value": probe})

        duplicates = [{"sha256": key, "ids": value} for key, value in hashes.items() if len(value) > 1]
        repeated_prompts = [
            {"text": text, "recordings": count}
            for text, count in text_counter.most_common(10)
            if count > 1
        ]

        speakers = [
            {
                "speaker_id": speaker,
                "recordings": entry["recordings"],
                "seconds": round(entry["duration_ms"] / 1000, 1),
                "avg_score": round(sum(entry["scores"]) / len(entry["scores"]), 2) if entry["scores"] else None,
            }
            for speaker, entry in sorted(per_speaker.items(), key=lambda item: -item[1]["recordings"])
        ]

        total_ms = sum(durations)
        return {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "language": "tk",
            "totals": {
                "clips": len(recordings),
                "seconds": round(total_ms / 1000, 1),
                "hours": round(total_ms / 3_600_000, 3),
                "speakers": len(per_speaker),
                "unique_prompts": len(text_counter),
                "avg_duration_ms": int(total_ms / len(durations)) if durations else 0,
                "avg_words_per_clip": round(
                    sum(word_count(item.text) for item in recordings) / len(recordings), 2
                ) if recordings else 0,
            },
            "durations": dict(sorted(buckets.items())),
            "quality": {
                "rated": len([item for item in recordings if item.rating_count > 0]),
                "verified": len([item for item in recordings if item.verified]),
                "avg_community_score": round(
                    sum(item.community_score for item in recordings if item.community_score is not None)
                    / max(1, len([item for item in recordings if item.community_score is not None])),
                    2,
                ) if any(item.community_score is not None for item in recordings) else None,
            },
            "speakers": speakers[:50],
            "categories": self.repository.by_category(),
            "duplicates": duplicates[:50],
            "repeated_prompts": repeated_prompts,
            "warnings": warnings[:500],
            "warning_counts": dict(Counter(item["type"] for item in warnings)),
            "dataset_fingerprint": hashlib.sha256(
                "".join(sorted(item.sha256 or item.id for item in recordings)).encode()
            ).hexdigest()[:16],
        }

    def write_report(self, filename: str = "report.json") -> Path:
        output = self.output_dir / filename
        output.write_text(json.dumps(self.report(), ensure_ascii=False, indent=2), encoding="utf-8")
        return output

    def manifest(self) -> dict:
        return {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "language": "tk",
            "sample_rate": settings.target_sample_rate,
            "channels": settings.target_channels,
            "items": [self._row(item) for item in self._approved()],
        }

    def manifest_bytes(self) -> bytes:
        return json.dumps(self.manifest(), ensure_ascii=False).encode("utf-8")

    def report_bytes(self) -> bytes:
        return io.BytesIO(json.dumps(self.report(), ensure_ascii=False, indent=2).encode("utf-8")).getvalue()
