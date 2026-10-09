#!/usr/bin/env python3
"""Regenerate the deterministic, low-level Gravediggers' Camp crackle WAV."""

import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "audio" / "sfx" / "campfire_loop.wav"
RATE = 22_050
SECONDS = 5.0
SEED = 40_731


def main() -> None:
    rng = random.Random(SEED)
    samples = int(RATE * SECONDS)
    low = 0.0
    signal: list[float] = []
    pops: list[tuple[int, float, float]] = []
    for time_s in (0.42, 1.37, 2.91, 4.08):
        pops.append((int(time_s * RATE), rng.uniform(0.18, 0.31), rng.uniform(0.003, 0.008)))
    for index in range(samples):
        low = low * 0.982 + rng.uniform(-1.0, 1.0) * 0.018
        value = low * 0.23 + rng.uniform(-1.0, 1.0) * 0.035
        for center, amplitude, width in pops:
            elapsed = (index - center) / RATE
            if abs(elapsed) < 0.04:
                value += amplitude * math.exp(-abs(elapsed) / width) * (1.0 if elapsed >= 0.0 else -0.2)
        signal.append(value)

    peak = max(abs(value) for value in signal) or 1.0
    gain = 0.52 / peak
    # A short zero-ended fade keeps the repeat seam click-free on every player.
    fade_samples = int(RATE * 0.12)
    for index in range(fade_samples):
        phase = index / max(1, fade_samples - 1)
        fade_in = math.sin(phase * math.pi * 0.5) ** 2
        fade_out = math.cos(phase * math.pi * 0.5) ** 2
        signal[index] *= fade_in
        signal[-fade_samples + index] *= fade_out

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b"".join(
            struct.pack("<h", max(-32768, min(32767, round(value * gain * 32767))))
            for value in signal
        ))
    print(f"Wrote {OUTPUT} ({samples} frames, {RATE} Hz mono, seed {SEED})")


if __name__ == "__main__":
    main()
