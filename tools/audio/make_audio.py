#!/usr/bin/env python3
"""Generates every sound effect and music track in the game from scratch.

    python3 tools/audio/make_audio.py            # writes audio/sfx/*.wav and audio/music/*.ogg

Nothing is sampled: instruments are synthesized (additive and subtractive
synths, a small drum kit, FFT filters and a convolution reverb), so the output
is fully reproducible (fixed random seed) and has no third-party assets.
Needs numpy, and ffmpeg (with libvorbis) for the music.

Music: every realm has two loops at the same tempo and length that play
together: "calm" (pads, bells, melody) and "drums" (percussion and pulse). The
game fades the drums in as the night gets dangerous; "boss" is a third shared
layer for boss fights. Loops are rendered with their reverb tail wrapped back
to the start, so they repeat seamlessly.
"""

import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
RNG = np.random.default_rng(1337)
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")

BPM = 100.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
LOOP_BARS = 16
LOOP = BAR * LOOP_BARS


# --- basics ------------------------------------------------------------------

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def note(name):
    """'A4' -> Hz. Sharps only (C#, D#...)."""
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    semis = names[pitch] + (octave - 4) * 12 - 9
    return 440.0 * 2 ** (semis / 12.0)


def env(n, a=0.005, d=0.1, s=0.6, r=0.2, sustain_time=None):
    """ADSR envelope of n samples (times in seconds)."""
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    if sustain_time is None:
        s_n = max(n - a_n - d_n - r_n, 0)
    else:
        s_n = max(int(sustain_time * SR), 0)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1), endpoint=False),
        np.linspace(1, s, max(d_n, 1), endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def exp_env(n, decay):
    return np.exp(-np.arange(n) / SR / decay)


def saw(freq, t, phase=0.0):
    # Band-limited saw by additive synthesis (harmonics below Nyquist).
    out = np.zeros_like(t)
    f = np.asarray(freq)
    top = int(min(40, (SR / 2.2) / max(float(np.max(f)), 1.0)))
    for k in range(1, max(top, 1) + 1):
        out += np.sin(2 * np.pi * k * f * t + phase * k) / k
    return out * 0.6


def square(freq, t):
    out = np.zeros_like(t)
    top = int(min(30, (SR / 2.2) / freq))
    for k in range(1, top + 1, 2):
        out += np.sin(2 * np.pi * k * freq * t) / k
    return out * 0.8


def noise(n):
    return RNG.uniform(-1, 1, n)


def fft_filter(x, lo=None, hi=None, peaks=None):
    """Zero-phase filtering in the frequency domain: highpass at `lo`, lowpass
    at `hi` (soft, roughly 12 dB/oct), plus optional resonant `peaks` as
    [(freq, gain, width)]."""
    n = len(x)
    size = 1 << int(np.ceil(np.log2(max(n, 2))))
    spec = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1 / SR)
    resp = np.ones_like(f)
    if hi:
        resp *= 1 / (1 + (f / hi) ** 4) ** 0.5
    if lo:
        resp *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 4) ** 0.5
    if peaks:
        for pf, gain, width in peaks:
            resp += gain * np.exp(-((f - pf) / width) ** 2)
    return np.fft.irfft(spec * resp, size)[:n]


def convolve(x, ir):
    size = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    return y[: len(x) + len(ir) - 1]


def reverb_ir(length=2.5, decay=0.6, bright=4000.0, seed=0):
    rng = np.random.default_rng(seed)
    n = int(length * SR)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / SR / decay)
    ir = fft_filter(ir, lo=150, hi=bright)
    ir[: int(0.01 * SR)] *= np.linspace(0, 1, int(0.01 * SR))
    return ir / np.sqrt(np.sum(ir ** 2))


def add(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def mix(*parts):
    """Sums signals of different lengths (shorter ones are padded)."""
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def write_wav(path, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def write_stereo_wav(path, left, right):
    left = np.clip(left, -1, 1)
    right = np.clip(right, -1, 1)
    inter = np.empty(len(left) * 2)
    inter[0::2] = left
    inter[1::2] = right
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((inter * 32767).astype("<i2").tobytes())


# --- instruments ---------------------------------------------------------------

def tone_pad(freqs, dur, bright=1400.0, attack=1.2, release=1.5, detune=0.006):
    t = t_axis(dur + release)
    out = np.zeros_like(t)
    for f in freqs:
        for d in (-detune, 0.0, detune):
            out += saw(f * (1 + d), t, RNG.uniform(0, 6.28))
    out = fft_filter(out, lo=60, hi=bright)
    return out * env(len(t), attack, 0.5, 0.8, release, sustain_time=dur - attack - 0.5) / max(len(freqs), 1) * 0.5


def choir(freqs, dur, vowel="ah", attack=0.8, release=1.2):
    formants = {"ah": [(750, 3.0, 120), (1200, 2.0, 140), (2600, 1.2, 200)],
                "oo": [(350, 3.0, 90), (700, 1.5, 120), (2400, 0.6, 200)]}[vowel]
    t = t_axis(dur + release)
    out = np.zeros_like(t)
    for f in freqs:
        for k in range(3):
            vib = 1 + 0.004 * np.sin(2 * np.pi * (4.5 + k * 0.4) * t + k)
            out += saw(f * (1 + (k - 1) * 0.004) * vib, t, k * 2.0)
    out = fft_filter(out, lo=120, hi=3500, peaks=formants)
    return out * env(len(t), attack, 0.4, 0.85, release, sustain_time=dur - attack - 0.4) / max(len(freqs), 1) * 0.12


def bell(freq, dur=3.0, decay=1.2, bright=1.0):
    t = t_axis(dur)
    parts = [(1.0, 1.0), (2.76, 0.5 * bright), (5.4, 0.25 * bright), (8.93, 0.12 * bright), (0.5, 0.3)]
    out = np.zeros_like(t)
    for ratio, amp in parts:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (decay / ratio ** 0.6))
    return out * env(len(t), 0.002, 0.05, 1.0, 0.05) * 0.3


def pluck(freq, dur=1.2, decay=0.5, bright=6000):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k in range(1, 12):
        out += np.sin(2 * np.pi * freq * k * t) * np.exp(-t * k / (decay * 3)) / k
    return fft_filter(out, hi=bright) * env(len(t), 0.002, 0.1, 1.0, 0.05) * 0.4


def bass(freq, dur, grit=0.0):
    t = t_axis(dur)
    out = np.sin(2 * np.pi * freq * t) + 0.5 * fft_filter(saw(freq, t), hi=600)
    if grit:
        out = soft_clip(out * (1 + grit * 3), 2.0)
    return out * env(len(t), 0.005, 0.15, 0.7, 0.08) * 0.45


def kick(dur=0.6, f0=110.0, f1=42.0, punch=1.0):
    t = t_axis(dur)
    freq = f1 + (f0 - f1) * np.exp(-t / 0.05)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    out = np.sin(phase) * np.exp(-t / 0.25)
    click = fft_filter(noise(len(t)), lo=1500) * np.exp(-t / 0.004) * 0.3 * punch
    return (out + click) * 0.9


def taiko(dur=1.0, f=70.0):
    t = t_axis(dur)
    freq = f * (1 + 0.6 * np.exp(-t / 0.03))
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t / 0.35)
    skin = fft_filter(noise(len(t)), lo=80, hi=900) * np.exp(-t / 0.08) * 0.8
    return soft_clip(body + skin, 1.5) * 0.9


def snare(dur=0.35, tone=190.0):
    t = t_axis(dur)
    n = fft_filter(noise(len(t)), lo=1200, hi=9000) * np.exp(-t / 0.09)
    body = np.sin(2 * np.pi * tone * t) * np.exp(-t / 0.05)
    return (n * 0.7 + body * 0.5) * 0.8


def hat(dur=0.08, decay=0.02):
    t = t_axis(dur)
    return fft_filter(noise(len(t)), lo=7000) * np.exp(-t / decay) * 0.35


def shaker(dur=0.12):
    t = t_axis(dur)
    return fft_filter(noise(len(t)), lo=4000, hi=12000) * env(len(t), 0.02, 0.03, 0.5, 0.06) * 0.25


def gong(dur=4.0, f=90.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp in [(1, 1), (1.47, 0.6), (2.09, 0.4), (2.56, 0.3), (3.3, 0.2), (4.1, 0.15)]:
        out += amp * np.sin(2 * np.pi * f * ratio * t + RNG.uniform(0, 6)) * np.exp(-t / (2.0 / ratio ** 0.5))
    out += fft_filter(noise(len(t)), lo=200, hi=3000) * np.exp(-t / 0.3) * 0.3
    return out * env(len(t), 0.01, 0.1, 1.0, 0.2) * 0.35


# --- music ----------------------------------------------------------------------

def chord(root, kind):
    steps = {"m": [0, 3, 7], "M": [0, 4, 7], "m7": [0, 3, 7, 10], "M7": [0, 4, 7, 11], "sus": [0, 5, 7], "5": [0, 7, 12]}[kind]
    base = note(root)
    return [base * 2 ** (s / 12) for s in steps]


def finish_loop(buf, loop_len, wet_ir=None, wet=0.35):
    """Adds reverb and wraps the tail past `loop_len` back to the start."""
    if wet_ir is not None:
        rev = convolve(buf, wet_ir)
        full = np.zeros(max(len(rev), len(buf)))
        full[: len(buf)] += buf * (1 - wet * 0.5)
        full[: len(rev)] += rev * wet
    else:
        full = buf
    n = int(loop_len * SR)
    out = full[:n].copy()
    tail = full[n:]
    while len(tail) > 0:
        k = min(len(tail), n)
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


def stereo_spread(x, delay=0.012, width=0.25):
    """A cheap stereo image: one side slightly delayed and filtered."""
    d = int(delay * SR)
    right = np.concatenate([np.zeros(d), x[:-d]]) if d > 0 else x.copy()
    right = (1 - width) * x + width * fft_filter(right, hi=6000)
    left = (1 - width) * x + width * fft_filter(x, lo=200)
    return left, right


def render_realm(name, progression, scale_notes, style):
    n = int((LOOP + 6.0) * SR)
    calm = np.zeros(n)
    drums = np.zeros(n)
    rng = np.random.default_rng(hash(name) % 2 ** 32)
    for bar in range(LOOP_BARS):
        root, kind = progression[bar % len(progression)]
        at = bar * BAR
        freqs = chord(root, kind)
        if style == "graveyard":
            add(calm, choir(freqs, BAR * 0.98, "ah"), at)
            add(calm, tone_pad([f / 2 for f in freqs[:2]], BAR, bright=700) * 0.6, at)
            # Music-box melody: sparse bells on chord and scale tones.
            for k in range(4):
                if rng.random() < 0.55:
                    f = rng.choice(scale_notes) * 2
                    add(calm, bell(f, 3.0, 1.4) * 0.5, at + k * BEAT + rng.choice([0, BEAT / 2]))
            add(calm, bass(freqs[0] / 2, BAR * 0.9) * 0.6, at)
            # Drums: slow toms on 1 and 3, a heartbeat kick, shakers.
            add(drums, taiko(1.0, 65) * 0.8, at)
            add(drums, taiko(1.0, 80) * 0.5, at + 2 * BEAT)
            add(drums, kick(0.5, 90, 40) * 0.5, at + 2.5 * BEAT)
            for k in range(8):
                add(drums, shaker() * (0.6 if k % 2 else 0.35), at + k * BEAT / 2)
            if bar % 4 == 3:
                for k in range(4):
                    add(drums, taiko(0.6, 95 - k * 8) * 0.45, at + 3 * BEAT + k * BEAT / 4)
        elif style == "frozen":
            add(calm, tone_pad(freqs + [freqs[0] * 2], BAR * 0.98, bright=2600, attack=1.8) * 0.8, at)
            add(calm, choir([freqs[0], freqs[2]], BAR * 0.95, "oo") * 0.8, at)
            # Glassy arpeggio of bells, high and fast.
            arp = sorted(freqs) * 2
            for k in range(8):
                f = arp[k % len(arp)] * (4 if k % 4 else 2)
                add(calm, bell(f, 2.0, 0.8, bright=1.6) * 0.28, at + k * BEAT / 2)
            wind = fft_filter(noise(int(BAR * SR)), lo=300, hi=1200 + 600 * np.sin(bar)) * 0.03
            add(calm, wind * env(len(wind), 1.0, 0.5, 1.0, 1.0), at)
            add(calm, bass(freqs[0] / 2, BAR * 0.9) * 0.5, at)
            add(drums, kick(0.6, 80, 38) * 0.7, at)
            add(drums, kick(0.6, 80, 38) * 0.45, at + 0.5 * BEAT)
            add(drums, kick(0.6, 80, 38) * 0.6, at + 2 * BEAT)
            for k in range(16):
                if k % 4 == 2 or rng.random() < 0.3:
                    add(drums, hat(0.06, 0.012) * 0.7, at + k * BEAT / 4)
            add(drums, snare(0.4, 220) * 0.35, at + 3 * BEAT)
        else:  # ember
            add(calm, tone_pad([freqs[0], freqs[1]], BAR * 0.98, bright=900, attack=0.6) * 0.8, at)
            add(calm, choir([freqs[0] * 2, freqs[2] * 2], BAR * 0.9, "ah") * 0.7, at)
            # Low brass-like stabs.
            for k in (0, 1.5, 3):
                t = t_axis(0.5)
                stab = fft_filter(saw(freqs[0], t) + saw(freqs[2], t), hi=1100) * env(len(t), 0.02, 0.15, 0.5, 0.2) * 0.3
                add(calm, soft_clip(stab, 1.5), at + k * BEAT)
            # Driving distorted bass ostinato.
            for k in range(8):
                f = freqs[0] / 2 * (2 if k in (3, 7) else 1)
                add(drums, bass(f, BEAT / 2 * 0.9, grit=0.6) * 0.5, at + k * BEAT / 2)
            for k in range(4):
                add(drums, taiko(0.9, 60 if k % 2 == 0 else 75) * (0.9 if k == 0 else 0.6), at + k * BEAT)
            add(drums, taiko(0.5, 110) * 0.4, at + 3.5 * BEAT)
            add(drums, taiko(0.5, 110) * 0.4, at + 3.75 * BEAT)
            for k in range(8):
                add(drums, hat(0.05, 0.015) * 0.5, at + k * BEAT / 2 + BEAT / 4)
    hall = reverb_ir(3.2, 0.9, 5000, seed=1)
    room = reverb_ir(1.2, 0.3, 7000, seed=2)
    calm = finish_loop(calm, LOOP, hall, 0.45)
    drums = finish_loop(drums, LOOP, room, 0.2)
    return normalize(calm, 0.7), normalize(drums, 0.75)


def render_boss():
    n = int((LOOP + 4.0) * SR)
    buf = np.zeros(n)
    for bar in range(LOOP_BARS):
        at = bar * BAR
        # War drums in a driving pattern, choir stabs on the downbeats.
        for k in range(8):
            add(buf, taiko(0.7, 55 if k % 2 == 0 else 72) * (1.0 if k % 4 == 0 else 0.6), at + k * BEAT / 2)
        add(buf, snare(0.4, 160) * 0.6, at + BEAT)
        add(buf, snare(0.4, 160) * 0.6, at + 3 * BEAT)
        stab_root = note("D3") if bar % 4 < 2 else note("A#2")
        add(buf, choir([stab_root, stab_root * 1.5, stab_root * 2], BEAT * 0.8, "ah", attack=0.02, release=0.3) * 1.6, at)
        if bar % 2 == 1:
            add(buf, choir([stab_root * 1.19, stab_root * 1.78], BEAT * 0.5, "ah", attack=0.02, release=0.3) * 1.4, at + 2.5 * BEAT)
        for k in range(16):
            add(buf, hat(0.04, 0.01) * 0.4, at + k * BEAT / 4)
    buf = finish_loop(buf, LOOP, reverb_ir(1.5, 0.4, 6000, seed=3), 0.25)
    return normalize(soft_clip(buf * 1.2, 1.2), 0.75)


def render_victory():
    dur = 7.0
    buf = np.zeros(int(dur * SR))
    seq = ["D4", "F#4", "A4", "D5"]
    for i, nm in enumerate(seq):
        add(buf, bell(note(nm) * 2, 4.0, 1.6) * 0.8, i * 0.18)
        add(buf, pluck(note(nm), 1.5) * 0.6, i * 0.18)
    add(buf, choir(chord("D4", "M") + [note("D5")], 4.0, "ah", attack=0.3, release=2.0) * 2.0, 0.75)
    add(buf, tone_pad(chord("D3", "M"), 4.0, bright=2000, attack=0.4) * 1.2, 0.75)
    add(buf, gong(5.0, 110) * 0.5, 0.75)
    return normalize(finish_loop(np.concatenate([buf, np.zeros(SR * 3)]), dur + 3, reverb_ir(3.0, 0.9, 6000, 4), 0.4)[: int(dur * SR)])


def render_defeat():
    dur = 5.0
    buf = np.zeros(int(dur * SR))
    for i, nm in enumerate(["D4", "C4", "A#3", "A3"]):
        add(buf, choir([note(nm), note(nm) * 1.19], 1.2, "oo", attack=0.1, release=1.0) * 1.5, i * 0.6)
    add(buf, gong(4.0, 60), 1.8)
    add(buf, taiko(1.5, 45), 1.8)
    return normalize(buf)


# --- sound effects -------------------------------------------------------------

def sfx():
    s = {}

    def sweep(f0, f1, dur, shape=np.sin):
        t = t_axis(dur)
        freq = f1 + (f0 - f1) * np.exp(-t / (dur / 4))
        return shape(2 * np.pi * np.cumsum(freq) / SR)

    t = t_axis(0.25)
    s["bolt_cast"] = fft_filter(sweep(1800, 500, 0.25) * np.exp(-t / 0.06) + noise(len(t)) * np.exp(-t / 0.03) * 0.3, lo=300, hi=7000) * 0.6
    t = t_axis(0.15)
    s["bolt_hit"] = (fft_filter(noise(len(t)), lo=300, hi=3500) * np.exp(-t / 0.025) + np.sin(2 * np.pi * 220 * t) * np.exp(-t / 0.03) * 0.5)
    for i, (f, d) in enumerate([(160, 0.18), (120, 0.22), (200, 0.16)]):
        t = t_axis(0.35)
        squelch = fft_filter(noise(len(t)), lo=150, hi=1800 - i * 300) * np.exp(-t / d / 2)
        thud = np.sin(2 * np.pi * np.cumsum(f * (1 + np.exp(-t / 0.02))) / SR) * np.exp(-t / d)
        s["kill_%d" % i] = soft_clip(squelch * 0.6 + thud * 0.8, 1.5)
    t = t_axis(0.9)
    s["elite_kill"] = soft_clip(mix(kick(0.9, 160, 45), fft_filter(noise(len(t)), lo=200, hi=5000) * np.exp(-t / 0.2) * 0.5), 1.3) * 0.9
    s["elite_kill"] += np.concatenate([np.zeros(int(0.05 * SR)), bell(note("A5"), 0.85, 0.4)])[: len(s["elite_kill"])]
    s["gem"] = bell(note("E6"), 0.5, 0.15, bright=0.6) * 1.2
    t = t_axis(0.9)
    ghost = sum(np.sin(2 * np.pi * f * t * (1 + 0.01 * np.sin(2 * np.pi * 6 * t))) for f in (note("B5"), note("F#6")))
    s["soul"] = mix(ghost * env(len(t), 0.05, 0.2, 0.4, 0.6) * 0.4, bell(note("B6"), 0.9, 0.3) * 0.5)
    t = t_axis(1.2)
    s["loot"] = mix(bell(note("C5") * 2, 1.2, 0.5) * 0.5, np.concatenate([np.zeros(int(0.08 * SR)), bell(note("G5") * 2, 1.12, 0.5) * 0.4]))
    t = t_axis(3.0)
    leg = choir(chord("D4", "M") + [note("A4") * 2], 1.6, "ah", 0.1, 1.2) * 2.5
    leg = np.concatenate([leg, np.zeros(max(0, len(t) - len(leg)))])[: len(t)]
    for i, nm in enumerate(["D5", "F#5", "A5", "D6"]):
        b = bell(note(nm), 2.5, 1.0) * 0.6
        start = int(i * 0.09 * SR)
        leg[start:start + len(b)] += b[: len(leg) - start]
    s["legendary"] = leg
    t = t_axis(0.3)
    s["pickup"] = mix(pluck(note("A5"), 0.3, 0.1), np.concatenate([np.zeros(int(0.06 * SR)), pluck(note("E6"), 0.24, 0.08)]))
    lv = np.zeros(int(1.6 * SR))
    for i, nm in enumerate(["C5", "E5", "G5", "C6"]):
        add(lv, mix(bell(note(nm), 1.4, 0.8) * 0.7, pluck(note(nm) / 2, 1.0, 0.3) * 0.5), i * 0.07)
    add(lv, choir(chord("C4", "M"), 0.8, "ah", 0.05, 0.6) * 1.5, 0.28)
    s["levelup"] = lv
    t = t_axis(0.08)
    s["ui_hover"] = np.sin(2 * np.pi * 1400 * t) * np.exp(-t / 0.015) * 0.3
    t = t_axis(0.2)
    s["ui_click"] = mix(pluck(note("E5"), 0.2, 0.06), np.sin(2 * np.pi * 300 * t) * np.exp(-t / 0.02) * 0.4)
    pick = np.zeros(int(0.8 * SR))
    add(pick, bell(note("A5"), 0.7, 0.4), 0.0)
    add(pick, bell(note("E6"), 0.7, 0.4) * 0.7, 0.06)
    add(pick, fft_filter(noise(int(0.4 * SR)), lo=2000) * exp_env(int(0.4 * SR), 0.08) * 0.3, 0.0)
    s["card_pick"] = pick
    t = t_axis(0.35)
    swoosh = fft_filter(noise(len(t)), lo=400, hi=4000) * np.sin(np.pi * np.linspace(0, 1, len(t))) ** 2
    s["dash"] = swoosh * 0.9 + sweep(500, 1400, 0.35) * np.exp(-t / 0.1) * 0.15
    t = t_axis(0.3)
    s["hurt"] = soft_clip(np.sin(2 * np.pi * np.cumsum(140 * (1 + 0.5 * np.exp(-t / 0.03))) / SR) * np.exp(-t / 0.08) + fft_filter(noise(len(t)), hi=1200) * np.exp(-t / 0.05) * 0.6, 2)
    t = t_axis(0.5)
    crackle = noise(len(t)) * (RNG.random(len(t)) < 0.08)
    s["lightning"] = soft_clip(fft_filter(crackle * 3 + noise(len(t)) * 0.4, lo=800, hi=9000) * np.exp(-t / 0.12) + sweep(3000, 200, 0.5) * np.exp(-t / 0.05) * 0.3, 1.5)
    t = t_axis(1.2)
    s["nova"] = soft_clip(mix(kick(1.2, 140, 35) * 0.8, fft_filter(noise(len(t)), lo=200, hi=3000) * np.exp(-t / 0.25) * 0.6, sweep(200, 1200, 1.2) * np.exp(-t / 0.3) * 0.2), 1.3)
    t = t_axis(0.2)
    s["blade"] = fft_filter(noise(len(t)), lo=2500, hi=9000) * np.sin(np.pi * np.linspace(0, 1, len(t))) * 0.6
    t = t_axis(0.8)
    shards = np.zeros(len(t))
    for k in range(12):
        add(shards, bell(RNG.uniform(2500, 6000), 0.4, 0.06, 1.5) * RNG.uniform(0.3, 0.8), RNG.uniform(0, 0.15))
    s["shatter"] = mix(shards, fft_filter(noise(len(t)), lo=3000) * np.exp(-t / 0.05) * 0.5)
    t = t_axis(0.7)
    s["melt"] = fft_filter(noise(len(t)), lo=2000, hi=8000) * env(len(t), 0.01, 0.1, 0.6, 0.5) * 0.6 + sweep(300, 900, 0.7) * np.exp(-t / 0.2) * 0.2
    t = t_axis(1.0)
    s["overload"] = soft_clip(mix(kick(1.0, 180, 40), fft_filter(noise(len(t)), lo=100, hi=6000) * np.exp(-t / 0.3) * 0.9), 2.0)
    t = t_axis(0.5)
    s["ignite"] = fft_filter(noise(len(t)), lo=200, hi=2500) * env(len(t), 0.03, 0.1, 0.5, 0.3) * 0.8
    t = t_axis(2.2)
    growl = saw(70 * (1 + 0.1 * np.sin(2 * np.pi * 7 * t)) * (1 + 0.3 * np.exp(-t / 0.5)), t) + saw(105, t) * 0.5
    s["boss_roar"] = soft_clip(fft_filter(growl, lo=50, hi=1600, peaks=[(500, 2, 150), (900, 1.5, 200)]) * env(len(t), 0.15, 0.3, 0.8, 1.2) + fft_filter(noise(len(t)), lo=200, hi=2000) * env(len(t), 0.2, 0.3, 0.5, 1.0) * 0.3, 2.0)
    t = t_axis(1.6)
    s["slam"] = soft_clip(mix(kick(1.6, 90, 30, 2.0) * 1.2, fft_filter(noise(len(t)), lo=40, hi=800) * np.exp(-t / 0.35) * 0.9), 2.5)
    t = t_axis(1.1)
    s["telegraph"] = np.sin(2 * np.pi * 220 * t) * np.sin(2 * np.pi * 9 * t) ** 2 * np.linspace(0.2, 1.0, len(t)) * 0.35
    t = t_axis(1.4)
    s["meteor"] = soft_clip(mix(kick(1.4, 120, 30, 2), fft_filter(noise(len(t)), lo=100, hi=4000) * np.exp(-t / 0.4) * 1.0), 2.2)
    t = t_axis(0.9)
    s["ice_impact"] = mix(s["shatter"] * 0.8, kick(0.9, 200, 60) * 0.5)
    t = t_axis(1.0)
    s["grave"] = soft_clip(mix(fft_filter(noise(len(t)), lo=60, hi=900) * env(len(t), 0.02, 0.2, 0.5, 0.6), taiko(1.0, 50) * 0.7), 1.5)
    t = t_axis(1.6)
    rise = sweep(200, 700, 1.6) * env(len(t), 0.3, 0.3, 0.7, 0.8) * 0.3
    s["minion_raise"] = mix(rise, choir([note("B3"), note("F#4")], 1.0, "oo", 0.4, 0.6) * 1.8, bell(note("B5"), 1.6, 0.8) * 0.4)
    t = t_axis(0.6)
    s["minion_death"] = sweep(600, 150, 0.6) * env(len(t), 0.01, 0.1, 0.5, 0.4) * 0.4 + fft_filter(noise(len(t)), lo=1000, hi=5000) * np.exp(-t / 0.1) * 0.3
    chest = np.zeros(int(1.2 * SR))
    add(chest, kick(0.4, 150, 80) * 0.5, 0.0)
    add(chest, fft_filter(noise(int(0.3 * SR)), lo=500, hi=3000) * exp_env(int(0.3 * SR), 0.1) * 0.4, 0.0)
    for i, nm in enumerate(["G5", "B5", "D6", "G6"]):
        add(chest, bell(note(nm), 1.0, 0.5) * 0.5, 0.15 + i * 0.06)
    s["chest"] = chest
    t = t_axis(1.0)
    s["shrine_charge"] = sum(np.sin(2 * np.pi * f * t) for f in (note("A3"), note("E4"), note("A4"))) * np.sin(np.pi * np.linspace(0, 1, len(t))) * 0.25
    shrine = np.zeros(int(2.0 * SR))
    add(shrine, choir(chord("A4", "M"), 1.0, "ah", 0.05, 0.9) * 2.5, 0.0)
    for i, nm in enumerate(["A5", "C#6", "E6", "A6"]):
        add(shrine, bell(note(nm), 1.5, 0.8) * 0.5, i * 0.05)
    s["shrine_done"] = shrine
    gob = np.zeros(int(0.9 * SR))
    for i in range(5):
        tt = t_axis(0.1)
        f = 600 + 120 * ((i * 3) % 5)
        add(gob, square(f, tt) * env(len(tt), 0.005, 0.03, 0.5, 0.04) * 0.25, i * 0.13)
    s["goblin"] = fft_filter(gob, hi=4000)
    heal = np.zeros(int(1.0 * SR))
    for i, nm in enumerate(["E5", "G#5", "B5"]):
        add(heal, bell(note(nm), 0.9, 0.5) * 0.5, i * 0.07)
    s["heal"] = heal
    t = t_axis(2.5)
    horn = fft_filter(saw(note("D2"), t) + saw(note("A2"), t) * 0.7, hi=900, peaks=[(400, 1.5, 120)]) * env(len(t), 0.3, 0.4, 0.8, 1.2) * 0.6
    s["boss_arrive"] = soft_clip(mix(horn, taiko(2.5, 50) * 0.8), 1.5)
    t = t_axis(0.5)
    s["reroll"] = mix(pluck(note("C5"), 0.5, 0.12) * 0.5, pluck(note("E5"), 0.5, 0.12) * 0.5, fft_filter(noise(len(t)), lo=3000) * np.exp(-t / 0.05) * 0.3)
    s["victory"] = render_victory()
    s["defeat"] = render_defeat()
    return s


def main():
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    room = reverb_ir(0.8, 0.18, 7000, seed=9)
    for name, x in sfx().items():
        x = np.asarray(x, dtype=float)
        if name not in ("victory", "defeat"):
            wet = convolve(x, room)[: len(x) + int(0.3 * SR)]
            dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
            x = dry + wet * 0.12
            fade = int(0.01 * SR)
            x[-fade:] *= np.linspace(1, 0, fade)
        write_wav(os.path.join(SFX_DIR, name + ".wav"), normalize(x, 0.85))
        print("sfx", name, "%.2fs" % (len(x) / SR))

    realms = {
        "graveyard": ([("D3", "m"), ("A#2", "M"), ("G2", "m"), ("A2", "M")], [note(n) for n in ["D4", "E4", "F4", "A4", "A#4", "C5"]]),
        "frozen": ([("A2", "m7"), ("F2", "M7"), ("D3", "m7"), ("E2", "sus")], [note(n) for n in ["A4", "C5", "E5", "G5"]]),
        "ember": ([("E2", "5"), ("F2", "5"), ("E2", "5"), ("D2", "5")], [note(n) for n in ["E4", "F4", "G4", "B4"]]),
    }
    tracks = {}
    for name, (prog, scale) in realms.items():
        calm, drums = render_realm(name, prog, scale, name)
        tracks[name + "_calm"] = calm
        tracks[name + "_drums"] = drums
    tracks["boss"] = render_boss()
    for name, x in tracks.items():
        wav = os.path.join(MUSIC_DIR, name + ".tmp.wav")
        left, right = stereo_spread(x)
        write_stereo_wav(wav, left, right)
        ogg = os.path.join(MUSIC_DIR, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
        os.remove(wav)
        print("music", name, "%.1fs" % (len(x) / SR))


if __name__ == "__main__":
    sys.exit(main())
