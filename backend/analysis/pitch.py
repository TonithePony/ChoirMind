"""Pitch analysis using librosa pyin estimator."""

from __future__ import annotations

from typing import Any

import librosa
import numpy as np

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def freq_to_note(freq: float) -> tuple[str, float]:
    if freq <= 0 or np.isnan(freq):
        return "—", 0.0
    midi = 69 + 12 * np.log2(freq / 440)
    rounded = round(midi)
    cents = (midi - rounded) * 100
    name = NOTE_NAMES[int(round(rounded)) % 12]
    octave = int(rounded // 12) - 1
    return f"{name}{octave}", float(cents)


def analyze_pitch(y: np.ndarray, sr: int) -> dict[str, Any]:
    f0, voiced_flag, voiced_probs = librosa.pyin(
        y,
        fmin=librosa.note_to_hz("C2"),
        fmax=librosa.note_to_hz("C6"),
        sr=sr,
    )

    frames = []
    hop = len(y) / max(len(f0), 1)
    for i, (freq, voiced) in enumerate(zip(f0, voiced_flag)):
        if voiced and not np.isnan(freq):
            note, cents = freq_to_note(float(freq))
            frames.append(
                {
                    "time": round(i * hop / sr, 3),
                    "frequency": round(float(freq), 2),
                    "note": note,
                    "cents": round(cents, 1),
                    "clarity": round(float(voiced_probs[i]), 3) if voiced_probs is not None else 1.0,
                }
            )

    if not frames:
        return {
            "accuracy": 0.0,
            "avg_cents_deviation": 0.0,
            "stability": 0.0,
            "patterns": [],
            "frame_count": 0,
        }

    cents_vals = [abs(f["cents"]) for f in frames]
    avg_dev = float(np.mean(cents_vals))
    accuracy = float(np.mean([1 if c < 25 else 0 for c in cents_vals]))
    cents_series = [f["cents"] for f in frames]
    stability = float(max(0, 1 - np.std(cents_series) / 50))

    patterns = []
    avg_cents = float(np.mean(cents_series))
    if avg_cents < -12:
        patterns.append(
            {
                "type": "general_flat",
                "description": "Overall intonation runs slightly flat. Check posture and breath support.",
                "severity": "low",
            }
        )
    elif avg_cents > 12:
        patterns.append(
            {
                "type": "general_sharp",
                "description": "Overall intonation runs slightly sharp. Relax the jaw and avoid pushing.",
                "severity": "low",
            }
        )

    return {
        "accuracy": round(accuracy, 3),
        "avg_cents_deviation": round(avg_dev, 1),
        "stability": round(stability, 3),
        "patterns": patterns,
        "frame_count": len(frames),
        "frames": frames[:100],
    }
