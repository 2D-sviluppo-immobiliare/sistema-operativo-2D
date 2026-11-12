#!/usr/bin/env python3
"""
Generatore del suono di avvio di 2D OS.

Produce brand/sounds/2d-boot.wav: un breve accordo elettronico discreto,
senza dipendenze esterne (solo libreria standard).

Uso:
    python3 brand/generate-sounds.py
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent / "sounds"
SAMPLE_RATE = 44100
DURATION = 1.10  # secondi

# Accordo ascendente: la5, mi6, la6 (A5 / E6 / A6)
NOTES = [
    (880.00, 0.00, 0.55, 0.55),
    (1318.51, 0.10, 0.45, 0.40),
    (1760.00, 0.20, 0.35, 0.30),
]
BASE_FREQ = 220.00  # basso di supporto, molto discreto


def envelope(t: float, start: float, dur: float, attack: float = 0.012) -> float:
    """Inviluppo: attacco rapido, decadimento esponenziale."""
    if t < start or t > start + dur:
        return 0.0
    e = t - start
    a = min(1.0, e / attack) if attack > 0 else 1.0
    decay = math.exp(-3.2 * (e / dur))
    return a * decay


def sample(t: float) -> float:
    value = 0.0
    for freq, start, dur, amp in NOTES:
        env = envelope(t, start, dur)
        if env > 0.0:
            value += amp * env * math.sin(2 * math.pi * freq * t)
    env_base = envelope(t, 0.0, 0.6)
    if env_base > 0.0:
        value += 0.18 * env_base * math.sin(2 * math.pi * BASE_FREQ * t)
    # dissolvenza finale per evitare click
    tail = min(1.0, max(0.0, (DURATION - t) / 0.08))
    return value * 0.42 * tail


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / "2d-boot.wav"
    frames = int(SAMPLE_RATE * DURATION)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        data = bytearray()
        for i in range(frames):
            value = max(-1.0, min(1.0, sample(i / SAMPLE_RATE)))
            data += struct.pack("<h", int(value * 32767))
        w.writeframes(bytes(data))
    print(f"{path.relative_to(path.parent.parent.parent)}  {path.stat().st_size} byte")


if __name__ == "__main__":
    main()
