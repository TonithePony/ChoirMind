"""ChoirMind audio analysis service — pitch and rhythm analysis."""

import io
import tempfile
from typing import Any

import librosa
import numpy as np
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from analysis.pitch import analyze_pitch
from analysis.rhythm import analyze_rhythm

app = FastAPI(
    title="ChoirMind Analysis API",
    description="Deep-learning-ready pitch and rhythm analysis for choir rehearsal",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root() -> dict[str, str]:
    return {
        "service": "ChoirMind Analysis API",
        "status": "running",
        "docs": "http://localhost:8000/docs",
        "health": "http://localhost:8000/health",
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "choirmind-analysis"}


@app.post("/analyze")
async def analyze(
    file: UploadFile = File(...),
    tempo: int = Form(120),
    time_signature: str = Form("4/4"),
) -> dict[str, Any]:
    contents = await file.read()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
        tmp.write(contents)
        tmp.flush()
        try:
            y, sr = librosa.load(tmp.name, sr=22050, mono=True)
        except Exception:
            # Try decoding as generic audio via soundfile fallback
            y, sr = librosa.load(io.BytesIO(contents), sr=22050, mono=True)

    pitch_result = analyze_pitch(y, sr)
    rhythm_result = analyze_rhythm(y, sr, tempo=tempo, time_signature=time_signature)

    return {
        "pitch": pitch_result,
        "rhythm": rhythm_result,
        "duration_seconds": float(len(y) / sr),
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
