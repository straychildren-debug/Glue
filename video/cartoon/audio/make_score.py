"""Музыка и звуки мультика «Держись!» (74 с), синтез без внешних файлов — детерминированно.

Тайминг событий — по сценам в ../scenes (начала сцен: 0, 7.5, 14.5, 27.5, 38.5, 53.5, 61.5, 66.5).
Запуск: python make_score.py → score.wav рядом.
"""

from pathlib import Path
import wave

import numpy as np

RATE = 44100
DURATION = 74.0
out = np.zeros((int(DURATION * RATE), 2), dtype=np.float32)
rng = np.random.default_rng(2026)


def hz(note: float) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def place(sig: np.ndarray, at: float, pan: float = 0.0, gain: float = 1.0) -> None:
    start = int(round(at * RATE))
    if start >= len(out) or len(sig) == 0:
        return
    end = min(len(out), start + len(sig))
    s = sig[: end - start] * gain
    left, right = (1 - max(0.0, pan)), (1 + min(0.0, pan))
    out[start:end, 0] += s * left
    out[start:end, 1] += s * right


def tt(length: float) -> np.ndarray:
    return np.arange(int(length * RATE), dtype=np.float32) / RATE


# ── Инструменты.
def bell(note, length=1.4, vol=0.1):
    t = tt(length); f = hz(note)
    env = (1 - np.exp(-t * 80)) * np.exp(-t * 2.8)
    return (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2.01 * f * t) + 0.12 * np.sin(2 * np.pi * 3.97 * f * t)) * env * vol


def pluck(note, length=0.6, vol=0.12):
    f = hz(note); n = int(RATE / f); buf = rng.uniform(-1, 1, n).astype(np.float32)
    total = int(length * RATE); res = np.zeros(total, dtype=np.float32)
    for i in range(total):
        res[i] = buf[i % n]
        buf[i % n] = 0.5 * (buf[i % n] + buf[(i + 1) % n]) * 0.996
    return res * vol


def pad(notes, length, vol=0.06, attack=0.6, release=0.9):
    t = tt(length)
    env = np.minimum(1, t / attack) * np.minimum(1, np.maximum(0, (length - t) / release))
    s = np.zeros_like(t)
    for n in notes:
        f = hz(n)
        s += np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 0.25 * t)) + 0.25 * np.sin(2 * np.pi * 2 * f * t)
    return s / len(notes) * env * vol


def bass(note, length=0.4, vol=0.16):
    t = tt(length); f = hz(note)
    env = (1 - np.exp(-t * 120)) * np.exp(-t * 5)
    return (np.sin(2 * np.pi * f * t) + 0.3 * np.sign(np.sin(2 * np.pi * f * t)) * 0.4) * env * vol


def brass(notes, length=0.9, vol=0.08):
    t = tt(length); env = np.minimum(1, t / 0.06) * np.exp(-t * 1.2)
    s = np.zeros_like(t)
    for n in notes:
        f = hz(n); ph = 2 * np.pi * f * t
        s += sum(np.sin(k * ph) / k for k in range(1, 7))
    return s / len(notes) * env * vol


def noise(length, color=60):
    n = rng.standard_normal(int(length * RATE)).astype(np.float32)
    return np.convolve(n, np.ones(color, dtype=np.float32) / color, mode="same")


def whoosh(length=0.9, vol=0.3, rise=True):
    s = noise(length, 40); t = tt(length)
    env = np.sin(np.pi * np.minimum(1, t / length)) ** 2
    return s * env * vol * 3


def kick(vol=0.35):
    t = tt(0.3); f = 120 * np.exp(-t * 18) + 40
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 14) * vol


def snare(vol=0.12):
    t = tt(0.18)
    return noise(0.18, 3) * np.exp(-t * 26) * vol * 2


def pop(vol=0.25, pitch=900):
    t = tt(0.12); f = pitch * np.exp(-t * 18)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 40) * vol


def boing(vol=0.22, f0=520, f1=160, length=0.45):
    t = tt(length); f = f1 + (f0 - f1) * np.exp(-t * 7) + 30 * np.sin(2 * np.pi * 14 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 6) * vol


def whistle_up(length=0.6, vol=0.08):
    t = tt(length); f = 700 + 1400 * (t / length)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.sin(np.pi * t / length) * vol


def bang(vol=0.35):
    t = tt(1.0)
    return (noise(1.0, 8) * 2 * np.exp(-t * 7) + np.sin(2 * np.pi * 60 * t) * np.exp(-t * 10)) * vol


def wail(length=1.2, vol=0.1, f0=380, f1=620):
    t = tt(length); f = f0 + (f1 - f0) * np.sin(np.pi * t / length) + 18 * np.sin(2 * np.pi * 6 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.sin(np.pi * t / length) * vol


def chirp(vol=0.05):
    t = tt(0.12); f = 3200 + 1800 * np.sin(np.pi * t / 0.12)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.sin(np.pi * t / 0.12) * vol


def thud(vol=0.35):
    t = tt(0.35)
    return np.sin(2 * np.pi * (70 * t + 20 * t * t)) * np.exp(-t * 12) * vol + noise(0.35, 30) * np.exp(-t * 20) * vol


def laugh(vol=0.07):
    s = np.zeros(int(0.9 * RATE), dtype=np.float32)
    for k in range(5):
        seg_ = wail(0.14, vol, 520 - k * 30, 600 - k * 30)
        st = int(k * 0.16 * RATE); s[st: st + len(seg_)] += seg_
    return s


# ── Музыка по сценам.
BEAT = 60 / 112
def melody(notes, start, step, inst=bell, vol=0.1, pan_alt=0.25, length=1.2):
    for i, n in enumerate(notes):
        if n is not None:
            place(inst(n, length, vol), start + i * step, pan=(-1) ** i * pan_alt)


# 1. Царство (0–7.5): светлая тема, до мажор.
place(pad((48, 55, 64, 67), 7.6, 0.05, attack=1.2), 0)
melody([72, 76, 79, 76, 77, 74, 72, None, 74, 76, 79, 84], 0.4, BEAT * 0.75, vol=0.075)
place(whoosh(2.4, 0.18), 0.2)
place(boing(0.25), 3.6)
place(bell(91, 1.6, 0.06), 4.45, 0.3); place(bell(96, 1.6, 0.04), 4.6, -0.3)
for k in range(4): place(pop(0.08, 1400 + k * 200), 5.1 + k * 0.19)
place(whoosh(1.4, 0.16), 6.2)

# 2. Праздник (7.5–14.5): весёлый марш, «умпа».
s2 = 7.5
for i in range(int(7 / BEAT * 2)):
    tb = s2 + i * BEAT / 2
    if tb > 14.4: break
    place(bass([48, 55, 53, 55][(i // 2) % 4] - 12, 0.3, 0.14) if i % 2 == 0 else pluck([64, 67, 65, 67][(i // 2) % 4], 0.25, 0.06), tb)
    if i % 4 == 2: place(snare(0.08), tb)
melody([72, 74, 76, 79, 76, 74, 72, 76, 79, 81, 79, 76, 77, 79, 84], s2 + 0.2, BEAT * 0.5, vol=0.07, length=0.8)
place(brass((60, 64, 67, 72), 1.2, 0.09), s2 + 2.4)
place(brass((65, 69, 72, 77), 1.4, 0.1), s2 + 3.2)
BOOM = s2 + 4.0
for x in (-0.6, 0.6): place(bang(0.18), BOOM, x)
for k in range(10): place(pop(0.06, 1200 + 300 * (k % 4)), BOOM + 0.05 + k * 0.06, (-1) ** k * 0.5)
place(noise(1.3, 12) * np.exp(-tt(1.3) * 2) * 0.25, BOOM + 0.05)  # толпа «ура»
for t0, t1, pan in ((3.95, 4.55, -0.4), (4.1, 4.85, 0.0), (4.3, 5.0, 0.4), (4.8, 5.6, -0.2), (5.6, 6.7, 0.0)):
    place(whistle_up(t1 - t0, 0.05), s2 + t0, pan)
    place(bang(0.22), s2 + t1, pan)
    for k in range(6): place(pop(0.03, 2400 + k * 300), s2 + t1 + 0.1 + k * 0.07, pan)

# 3. Руины (14.5–27.5): грустный минор, далёкие хлопки, нарастающая тревога, «у-у-у».
s3 = 14.5
place(pad((45, 52, 57, 60), 8.6, 0.06, attack=1.5), s3)
melody([69, 72, 71, 67, None, 69, 64, None, 65, 64, 62, 60], s3 + 1.0, BEAT * 1.1, vol=0.07, length=1.8)
for k in range(9): place(pop(0.02, 1800), s3 + 0.3 + k * 0.95, 0.6)
place(wail(1.0, 0.05, 330, 290), s3 + 5.6, -0.4)   # вздох
place(wail(0.9, 0.05, 440, 380), s3 + 7.1, 0.2)
place(pad((44, 51, 56, 62), 4.8, 0.07, attack=0.5), s3 + 8.4)
for k in range(10): place(bass(40 + (k % 2), 0.25, 0.12), s3 + 8.5 + k * 0.28)
place(brass((56, 62, 65), 0.8, 0.07), s3 + 9.0)
for k in range(3): place(wail(1.2, 0.08, 360 + k * 60, 620 + k * 80), s3 + 11.2 + k * 0.08, (k - 1) * 0.5)
place(whoosh(1.6, 0.3), s3 + 11.5)

# 4. Налёт (27.5–38.5): ночной праздник → саспенс → похищение → звон короны.
s4 = 27.5
melody([72, 76, 79, 76, 74, 72], s4 + 0.1, BEAT * 0.5, vol=0.05, length=0.7)
place(noise(1.2, 120) * np.sin(np.pi * tt(1.2) / 1.2) * 0.6, s4 + 1.3)          # порыв ветра
place(whoosh(1.6, 0.4), s4 + 2.05, 0.4); place(whoosh(1.4, 0.3), s4 + 2.2, -0.2)
for k, tl in enumerate((2.45, 2.6, 2.75, 2.9, 3.05, 3.2, 3.35)): place(pop(0.1, 300), s4 + tl, -0.7 + k * 0.23)
for k in range(5): place(wail(0.35, 0.05, 700 + k * 40, 900 + k * 30), s4 + 2.35 + k * 0.08, (-1) ** k * 0.5)
for i in range(16): place(bass(38 + (i % 4 == 3) * 3, 0.22, 0.13), s4 + 2.6 + i * BEAT / 2)
place(pad((43, 50, 53, 58), 4.0, 0.06, attack=0.3), s4 + 2.6)
place(thud(0.3), s4 + 4.05)
place(wail(0.5, 0.06, 620, 760), s4 + 4.3)
place(whoosh(2.0, 0.3), s4 + 6.4)
place(laugh(0.08), s4 + 7.3, 0.3)
place(bell(96, 2.6, 0.12), s4 + 7.94); place(bell(91, 2.4, 0.08), s4 + 7.96); place(pop(0.12, 2600), s4 + 7.94)
place(pad((57, 64, 69, 72), 3.0, 0.045, attack=1.0), s4 + 8.0)
place(bell(84, 2.0, 0.05), s4 + 9.4, 0.3)

# 5. Утро (38.5–53.5): рассвет, птицы, находка, героическая тема.
s5 = 38.5
place(pad((53, 60, 64, 69), 8.0, 0.05, attack=2.0), s5)
for k in range(10): place(chirp(0.04), s5 + 0.8 + k * 0.33 + (k % 3) * 0.05, (-1) ** k * 0.6)
for tl in (3.6, 4.25, 4.5, 4.75): place(boing(0.12, 480, 220, 0.35), s5 + tl + 0.55)
place(bell(84, 1.2, 0.05), s5 + 4.3)
place(pad((52, 57, 60, 64), 3.2, 0.05), s5 + 5.8)
place(pop(0.08, 1200), s5 + 8.3)
place(brass((55, 60, 64, 67), 1.6, 0.1), s5 + 8.8)
place(pad((48, 55, 60, 64, 67), 6.0, 0.06, attack=0.4), s5 + 8.8)
melody([67, 72, 76, 79, 77, 76, 74, 72, 74, 76, 79, 84], s5 + 9.0, BEAT * 0.6, vol=0.07, length=1.0)
place(brass((60, 64, 67, 72), 1.4, 0.11), s5 + 13.8)
for k in range(4): place(boing(0.1, 520, 260, 0.3), s5 + 13.85 + k * 0.05)

# 6. Карта (53.5–61.5): любопытная тема, свиток, точки пути, блеск замка.
s6 = 53.5
melody([76, None, 79, 77, 76, None, 74, 76, 72], s6 + 0.2, BEAT * 0.5, inst=pluck, vol=0.1, length=0.5)
place(whoosh(0.7, 0.18), s6 + 1.0)
place(pad((50, 57, 62, 65), 7.6, 0.05, attack=0.8), s6 + 0.3)
for k, tl in enumerate(np.linspace(4.3, 7.0, 7)): place(bell(72 + [0, 2, 4, 7, 9, 12, 14][k], 0.8, 0.07), s6 + tl, (k - 3) * 0.15)
for k in range(28): place(pop(0.025, 1600), s6 + 4.3 + k * 0.095)
place(bell(96, 1.8, 0.08), s6 + 7.0); place(whoosh(0.9, 0.2), s6 + 7.2)

# 7. Дорога (61.5–66.5): бодрый бег.
s7 = 61.5
for i in range(int(5 / BEAT * 2)):
    tb = s7 + i * BEAT / 2
    if tb > 66.4: break
    place(kick(0.18) if i % 2 == 0 else snare(0.06), tb)
    place(bass([48, 48, 53, 55][(i // 2) % 4] - 12, 0.25, 0.12), tb)
    place(pop(0.025, 500), tb + 0.05, (-1) ** i * 0.4)  # топот
melody([72, 76, 79, 84, 79, 76, 79, 84, 88], s7 + 0.4, BEAT * 0.5, vol=0.08, length=0.9)
place(whoosh(1.4, 0.15), s7 + 3.6)

# 8. Мост (66.5–74): финал и название.
s8 = 66.5
place(pad((48, 55, 64, 67, 72), 7.5, 0.06, attack=1.0), s8)
melody([72, 74, 76, 79, None, 77, 76, 74, 72], s8 + 0.3, BEAT * 0.75, vol=0.07, length=1.2)
for i in range(8): place(pluck(72 + [0, 2, 4, 5, 7, 9, 11, 12][i], 0.5, 0.12), s8 + 3.3 + i * 0.09 + 0.4, (i - 3.5) * 0.15)
place(brass((48, 55, 60, 64, 67, 72), 2.8, 0.12), s8 + 4.3)
place(bell(84, 3.0, 0.08), s8 + 4.3); place(bell(91, 3.0, 0.05), s8 + 4.35)

peak = float(np.max(np.abs(out)))
out *= 0.85 / max(0.85, peak)
path = Path(__file__).with_name("score.wav")
with wave.open(str(path), "wb") as f:
    f.setnchannels(2); f.setsampwidth(2); f.setframerate(RATE)
    f.writeframes((np.clip(out, -1, 1) * 32767).astype("<i2").tobytes())
print(f"{path.name}: {DURATION:.0f} с, пик до нормировки {peak:.2f}")
