"""Deterministic original storybook score and sound cues for the 70-second comic intro."""

from pathlib import Path
import wave

import numpy as np


RATE = 44100
DURATION = 70
audio = np.zeros((DURATION * RATE, 2), dtype=np.float32)
rng = np.random.default_rng(18)


def hz(note: int) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def add(signal: np.ndarray, at: float, pan: float = 0) -> None:
    start = max(0, round(at * RATE))
    end = min(len(audio), start + len(signal))
    if end <= start:
        return
    pan = float(np.clip(pan, -1, 1))
    audio[start:end, 0] += signal[:end - start] * (1 - max(0, pan))
    audio[start:end, 1] += signal[:end - start] * (1 + min(0, pan))


def bell(note: int, at: float, length: float = 1.5, volume: float = 0.12, pan: float = 0) -> None:
    t = np.arange(round(length * RATE), dtype=np.float32) / RATE
    f = hz(note)
    env = (1 - np.exp(-t * 65)) * np.exp(-t * 2.6)
    tone = np.sin(2 * np.pi * f * t) + 0.34 * np.sin(2 * np.pi * 2.01 * f * t)
    tone += 0.12 * np.sin(2 * np.pi * 3.95 * f * t)
    add((tone * env * volume).astype(np.float32), at, pan)


def pad(notes: tuple[int, ...], at: float, length: float, volume: float) -> None:
    t = np.arange(round(length * RATE), dtype=np.float32) / RATE
    env = np.minimum(1, t / 0.6) * np.minimum(1, (length - t) / 0.8)
    tone = np.zeros_like(t)
    for note in notes:
        f = hz(note)
        tone += (np.sin(2 * np.pi * f * t) + 0.14 * np.sin(2 * np.pi * 2 * f * t)) / len(notes)
    add((tone * env * volume).astype(np.float32), at)


def whoosh(at: float, length: float = 0.8, volume: float = 0.12, pan: float = 0) -> None:
    n = round(length * RATE)
    noise = rng.standard_normal(n).astype(np.float32)
    smooth = np.convolve(noise, np.ones(100, dtype=np.float32) / 100, mode="same")
    t = np.arange(n, dtype=np.float32) / RATE
    env = np.sin(np.pi * np.minimum(1, t / length)) ** 2
    add(smooth * env * volume, at, pan)


for chord, at, length, volume in [
    ((48, 52, 55), 0, 12, .14),
    ((45, 48, 52), 12, 5, .08),
    ((43, 47, 50), 17, 5, .09),
    ((40, 43, 47), 22, 8, .15),
    ((38, 42, 45), 30, 7, .12),
    ((50, 53, 57), 37, 7, .06),
    ((53, 57, 60), 44, 8, .12),
    ((48, 52, 55), 52, 10, .14),
    ((48, 52, 55, 60), 62, 8, .20),
]:
    pad(chord, at, length, volume)

for i, note in enumerate((72, 76, 79, 76, 74, 72, 67, 72)):
    bell(note, .4 + i * .78, 1.4, .085, (-1) ** i * .25)
for i, note in enumerate((65, 69, 72, 77, 72, 69, 72, 79)):
    bell(note, 7.2 + i * .58, .9, .095, (-1) ** i * .35)
for i, note in enumerate((69, 72, 64, 68, 71, 64, 62, 59)):
    bell(note, 12.3 + i * 1.2, 1.4, .052, (-1) ** i * .3)
for i, note in enumerate((64, 59, 55, 52, 50, 52, 55)):
    bell(note, 22.3 + i * 1.6, 1.8, .072)
for i, note in enumerate((65, 69, 72, 74, 76, 79, 76, 72)):
    bell(note, 39.0 + i * 1.28, 1.4, .09, (-1) ** i * .25)
for i, note in enumerate((72, 76, 79, 84, 79, 76, 72, 79, 84, 88, 84, 79)):
    bell(note, 52.2 + i * 1.35, 1.6, .12, (-1) ** i * .3)

# Story cues: festivities, ghost flight, crown strike, then a bright final flourish.
for at, pan in ((7.3, -.6), (8.4, .5), (9.7, -.2), (10.6, .4)):
    bell(91, at, .55, .035, pan)
for at, pan in ((22.1, .7), (22.45, .2), (23.1, -.3), (27.0, .5), (32.0, -.5)):
    whoosh(at, .9, .28, pan)
bell(60, 33.2, 2.3, .18)
bell(84, 33.3, 2.4, .12)
for note, at in ((72, 63.2), (79, 63.42), (84, 63.62), (88, 63.82)):
    bell(note, at, 2.2, .17)

# Light balloon pops and page flips. Each visual cue has a matching sound.
for at in (7.2, 8.7, 12.1, 13.9, 17.3, 18.5, 22.6, 27.3, 28.9,
           32.4, 37.2, 42.1, 43.5, 47.3, 48.7, 50.1, 52.4, 57.4):
    bell(79, at, .16, .028)
for at in (21.7, 36.7, 51.7):
    whoosh(at, .56, .11)

peak = float(np.max(np.abs(audio)))
audio *= .82 / max(.82, peak)
out = Path(__file__).with_name("comic_score.wav")
with wave.open(str(out), "wb") as file:
    file.setnchannels(2)
    file.setsampwidth(2)
    file.setframerate(RATE)
    file.writeframes((audio * 32767).astype("<i2").tobytes())
print(f"Created {out.name}: {DURATION}s, stereo 44.1 kHz, peak={peak:.3f}")
