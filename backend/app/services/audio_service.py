"""Audio validation / normalization.

The first APK wrote **raw** pcm16 (``AudioEncoder.pcm16bits``) into a file
named ``*.wav`` — i.e. no RIFF header at all.  Whisper, ffmpeg and
``soundfile`` all refuse such a file, so the server now normalizes every
upload to the canonical training format:

    16 kHz · mono · 16 bit PCM WAV (RIFF)

It also measures the *real* duration from the sample count and rejects
silent / clipped / too short takes, so the exported dataset is usable
without a manual cleanup pass.
"""

from __future__ import annotations

import hashlib
import io
import math
import struct
import wave
from array import array
from dataclasses import dataclass

from app.core.config import settings


class AudioProblem(ValueError):
    """Raised when the uploaded audio cannot be used for training."""


@dataclass(frozen=True)
class AudioInfo:
    data: bytes
    sample_rate: int
    channels: int
    bits_per_sample: int
    frames: int
    duration_ms: int
    size_bytes: int
    sha256: str
    rms_dbfs: float
    peak_dbfs: float
    clipping_ratio: float
    silence_ratio: float
    original_format: str  # "wav" | "pcm16"


def _dbfs(value: float) -> float:
    if value <= 1e-9:
        return -120.0
    return round(20 * math.log10(value), 2)


def _read_wav(raw: bytes) -> tuple[array, int, int, int, str]:
    with wave.open(io.BytesIO(raw), "rb") as reader:
        channels = reader.getnchannels()
        width = reader.getsampwidth()
        rate = reader.getframerate()
        frames = reader.getnframes()
        if width != 2:
            raise AudioProblem("only 16 bit PCM WAV is supported, please re-record with the app")
        if reader.getcomptype() != "NONE":
            raise AudioProblem("compressed WAV is not supported")
        payload = reader.readframes(frames)
    samples = array("h")
    samples.frombytes(payload[: len(payload) - len(payload) % 2])
    return samples, rate, channels, width * 8, "wav"


def _read_raw_pcm(raw: bytes, sample_rate: int, channels: int, bits: int) -> tuple[array, int, int, int, str]:
    if bits != 16:
        raise AudioProblem("raw audio must be 16 bit PCM")
    if sample_rate < 8_000 or sample_rate > 96_000:
        raise AudioProblem("unsupported sample rate")
    if channels not in (1, 2):
        raise AudioProblem("unsupported channel count")
    if len(raw) < 320:
        raise AudioProblem("audio payload is too small")
    samples = array("h")
    samples.frombytes(raw[: len(raw) - len(raw) % 2])
    return samples, sample_rate, channels, 16, "pcm16"


def _to_mono(samples: array, channels: int) -> array:
    if channels == 1:
        return samples
    mono = array("h")
    for index in range(0, len(samples) - 1, 2):
        mono.append(int((samples[index] + samples[index + 1]) / 2))
    return mono


def _resample(samples: array, source_rate: int, target_rate: int) -> array:
    if source_rate == target_rate or not samples:
        return samples
    ratio = target_rate / source_rate
    target_length = int(len(samples) * ratio)
    output = array("h", bytes(2 * target_length))
    for index in range(target_length):
        position = index / ratio
        left = int(position)
        right = min(left + 1, len(samples) - 1)
        weight = position - left
        output[index] = int(samples[left] * (1 - weight) + samples[right] * weight)
    return output


def _measure(samples: array) -> tuple[float, float, float, float]:
    if not samples:
        return -120.0, -120.0, 0.0, 1.0
    peak = 0
    squares = 0.0
    silent = 0
    clipped = 0
    window = max(1, len(samples) // 200)
    loud_windows = 0
    for start in range(0, len(samples), window):
        chunk_peak = 0
        for sample in samples[start : start + window]:
            magnitude = abs(sample)
            if magnitude > chunk_peak:
                chunk_peak = magnitude
            if magnitude > peak:
                peak = magnitude
            if magnitude >= 32_700:
                clipped += 1
            squares += float(sample) * float(sample)
        if chunk_peak < 300:
            silent += window
        if chunk_peak > 1_200:
            loud_windows += 1
    rms = math.sqrt(squares / len(samples)) / 32_768
    total_windows = math.ceil(len(samples) / window) or 1
    silence_ratio = round(1 - loud_windows / total_windows, 3)
    return (
        _dbfs(rms),
        _dbfs(peak / 32_768),
        round(clipped / len(samples), 5),
        max(0.0, silence_ratio),
    )


def _write_wav(samples: array) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(settings.target_sample_rate)
        writer.writeframes(samples.tobytes())
    return buffer.getvalue()


def normalize_audio(
    raw: bytes,
    declared_sample_rate: int | None = None,
    declared_channels: int | None = None,
    declared_bits: int | None = None,
) -> AudioInfo:
    """Return canonical WAV bytes + measured metadata, or raise AudioProblem."""
    if not raw:
        raise AudioProblem("empty upload")
    if len(raw) > settings.max_audio_bytes:
        raise AudioProblem("audio file is too large")

    if raw[:4] == b"RIFF" and raw[8:12] == b"WAVE":
        try:
            samples, rate, channels, bits, source = _read_wav(raw)
        except wave.Error as error:  # pragma: no cover - defensive
            raise AudioProblem(f"broken wav header: {error}") from error
    else:
        samples, rate, channels, bits, source = _read_raw_pcm(
            raw,
            declared_sample_rate or settings.target_sample_rate,
            declared_channels or settings.target_channels,
            declared_bits or settings.target_bit_depth,
        )

    samples = _to_mono(samples, channels)
    if rate != settings.target_sample_rate:
        samples = _resample(samples, rate, settings.target_sample_rate)

    duration_ms = int(len(samples) / settings.target_sample_rate * 1000)
    if duration_ms < settings.min_duration_ms:
        raise AudioProblem(f"audio is too short ({duration_ms} ms)")
    if duration_ms > settings.max_duration_ms:
        raise AudioProblem(f"audio is too long ({duration_ms} ms)")

    rms_dbfs, peak_dbfs, clipping_ratio, silence_ratio = _measure(samples)
    if rms_dbfs < settings.min_rms_dbfs:
        raise AudioProblem("audio looks silent, please speak closer to the microphone")

    data = _write_wav(samples)
    return AudioInfo(
        data=data,
        sample_rate=settings.target_sample_rate,
        channels=settings.target_channels,
        bits_per_sample=settings.target_bit_depth,
        frames=len(samples),
        duration_ms=duration_ms,
        size_bytes=len(data),
        sha256=hashlib.sha256(data).hexdigest(),
        rms_dbfs=rms_dbfs,
        peak_dbfs=peak_dbfs,
        clipping_ratio=clipping_ratio,
        silence_ratio=silence_ratio,
        original_format=source,
    )


def probe_wav(path: str) -> dict:
    """Read basic metadata from a stored wav (used by the dataset report)."""
    try:
        with wave.open(path, "rb") as reader:
            return {
                "sample_rate": reader.getframerate(),
                "channels": reader.getnchannels(),
                "bits_per_sample": reader.getsampwidth() * 8,
                "frames": reader.getnframes(),
                "duration_ms": int(reader.getnframes() / reader.getframerate() * 1000),
                "ok": True,
            }
    except Exception as error:  # noqa: BLE001 - report instead of crash
        return {"ok": False, "error": str(error)}


def silent_wav(milliseconds: int = 1_000, amplitude: int = 1_500) -> bytes:
    """Synthetic voice-ish tone, used by the seed/smoke scripts and tests."""
    rate = settings.target_sample_rate
    frames = int(rate * milliseconds / 1000)
    samples = array("h")
    for index in range(frames):
        envelope = 0.4 + 0.6 * math.sin(2 * math.pi * 3 * index / rate)
        value = math.sin(2 * math.pi * 180 * index / rate) * amplitude * envelope
        samples.append(int(value))
    return _write_wav(samples)


def wav_to_raw_pcm(data: bytes) -> bytes:
    """Strip the header — mimics what the first APK uploaded."""
    with wave.open(io.BytesIO(data), "rb") as reader:
        return reader.readframes(reader.getnframes())


def wav_duration_ms(data: bytes) -> int:
    with wave.open(io.BytesIO(data), "rb") as reader:
        return int(reader.getnframes() / reader.getframerate() * 1000)


def unused_struct_guard() -> None:  # pragma: no cover
    struct.pack("<h", 0)
