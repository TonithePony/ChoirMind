"""Rhythm and timing analysis."""

from __future__ import annotations

from typing import Any

import librosa
import numpy as np


def analyze_rhythm(
    y: np.ndarray,
    sr: int,
    tempo: int = 120,
    time_signature: str = "4/4",
) -> dict[str, Any]:
    onset_frames = librosa.onset.onset_detect(y=y, sr=sr, units="time")
    beat_duration = 60.0 / tempo

    deviations = []
    early = 0
    late = 0
    events = []

    for onset in onset_frames:
        nearest_beat = round(onset / beat_duration) * beat_duration
        dev_ms = (onset - nearest_beat) * 1000
        deviations.append(abs(dev_ms))
        if dev_ms < -50:
            early += 1
        if dev_ms > 50:
            late += 1
        events.append(
            {
                "time": round(float(onset), 3),
                "expected": round(float(nearest_beat), 3),
                "deviation_ms": round(float(dev_ms), 1),
            }
        )

    intervals = np.diff(onset_frames) if len(onset_frames) > 1 else np.array([beat_duration])
    tempo_stability = float(max(0, 1 - np.std(intervals) / beat_duration)) if len(intervals) > 0 else 1.0
    avg_dev = float(np.mean(deviations)) if deviations else 0.0
    rhythm_score = float(max(0, min(1, (1 - avg_dev / 200) * 0.6 + tempo_stability * 0.4)))

    issues = []
    n = max(len(onset_frames), 1)
    if early > n * 0.2:
        issues.append(
            {
                "type": "early",
                "description": "Several notes start before the beat. Count silently before entering.",
                "severity": "medium" if early <= n * 0.35 else "high",
            }
        )
    if late > n * 0.2:
        issues.append(
            {
                "type": "late",
                "description": "Delayed attacks detected. Anticipate the beat and breathe earlier.",
                "severity": "medium" if late <= n * 0.35 else "high",
            }
        )
    if tempo_stability < 0.7:
        issues.append(
            {
                "type": "tempo_drift",
                "description": "Tempo fluctuates. Practice with a metronome at a slower tempo.",
                "severity": "medium" if tempo_stability >= 0.5 else "high",
            }
        )

    return {
        "rhythm_score": round(rhythm_score, 3),
        "tempo_stability": round(tempo_stability, 3),
        "avg_deviation_ms": round(avg_dev, 1),
        "early_entrances": early,
        "late_entrances": late,
        "issues": issues,
        "events": events[:50],
    }
