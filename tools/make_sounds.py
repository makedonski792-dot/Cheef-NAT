#!/usr/bin/env python3
"""Генератор звуков для игры (без внешних файлов и лицензий).

Запуск:  python3 tools/make_sounds.py
Создаёт WAV-файлы в папке audio/. Каждый звук собирается из простых волн и шума,
поэтому их можно менять прямо здесь: частоты, длительность, громкость.
Чтобы заменить любой звук настоящей записью, просто положи свой audio/<имя>.wav
(формат WAV, 16 бит, моно) с тем же именем.
"""
import math
import os
import random
import struct
import wave

SR = 22050                      # частота дискретизации
rng = random.Random(7)          # фиксированное зерно: звуки получаются одинаковыми
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


# ---------- Строительные блоки ----------

def n_samples(seconds):
    return int(seconds * SR)


def noise(seconds):
    return [rng.uniform(-1.0, 1.0) for _ in range(n_samples(seconds))]


def lowpass(x, a):
    """Убирает высокие частоты (a от 0 до 1: чем меньше, тем глуше)."""
    y = 0.0
    out = []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, a):
    """Убирает низкие частоты, оставляет шипение."""
    return [v - l for v, l in zip(x, lowpass(x, a))]


def tone(freq, seconds, decay, amp=1.0, partials=((1.0, 1.0),)):
    """Звенящий тон, затухающий со временем. partials: (множитель частоты, громкость)."""
    out = []
    for i in range(n_samples(seconds)):
        t = i / SR
        v = 0.0
        for mult, a in partials:
            v += a * math.sin(2 * math.pi * freq * mult * t)
        out.append(amp * v * math.exp(-decay * t))
    return out


def sweep(f0, f1, seconds, decay, amp=1.0):
    """Тон, у которого частота плавно меняется от f0 до f1."""
    out = []
    phase = 0.0
    total = n_samples(seconds)
    for i in range(total):
        t = i / SR
        f = f0 + (f1 - f0) * (i / total)
        phase += 2 * math.pi * f / SR
        out.append(amp * math.sin(phase) * math.exp(-decay * t))
    return out


def envelope(x, decay):
    return [v * math.exp(-decay * i / SR) for i, v in enumerate(x)]


def place(track, sound, start_seconds):
    """Вставляет звук в дорожку с заданного момента (дорожка растёт сама)."""
    start = n_samples(start_seconds)
    need = start + len(sound)
    if len(track) < need:
        track.extend([0.0] * (need - len(track)))
    for i, v in enumerate(sound):
        track[start + i] += v


def add(a, b):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0.0) + (b[i] if i < len(b) else 0.0) for i in range(n)]


def scale(x, k):
    return [v * k for v in x]


def fade_edges(x, ms=4):
    n = min(len(x) // 2, int(SR * ms / 1000))
    for i in range(n):
        k = i / n
        x[i] *= k
        x[-1 - i] *= k
    return x


def make_loop(x, seconds, crossfade=0.25):
    """Делает бесшовную петлю: конец плавно перетекает в начало."""
    d = n_samples(seconds)
    xf = n_samples(crossfade)
    loop = x[:d]
    for i in range(xf):
        w = i / xf
        loop[i] = x[i] * w + x[d + i] * (1.0 - w)
    return loop


def save(name, x, peak=0.8):
    biggest = max(abs(v) for v in x) or 1.0
    k = peak / biggest
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * k)) * 32767)) for v in x))
    print("%-14s %5.2f с  %6.1f КБ" % (name, len(x) / SR, os.path.getsize(path) / 1024))


# ---------- Звуки ----------

def make_chop():
    """Удар ножа по доске: глухой стук и короткий щелчок."""
    thump = sweep(190, 80, 0.14, 38, 0.9)
    click = scale(envelope(highpass(noise(0.14), 0.35), 85), 0.8)
    save("chop", fade_edges(add(thump, click)))


def make_sizzle():
    """Шкворчание на сковороде: шипение и случайные брызги. Бесшовная петля 2 секунды."""
    d = 2.0
    xf = 0.25
    total = noise(d + xf)
    hiss = highpass(total, 0.42)
    # Медленно «дышащая» громкость шипения
    wob = lowpass([rng.uniform(0.5, 1.0) for _ in hiss], 0.0008)
    hiss = [h * (0.55 + 0.9 * w) for h, w in zip(hiss, wob)]
    track = scale(hiss, 0.5)
    # Брызги: короткие щелчки
    t = 0.0
    while t < d + xf - 0.05:
        pop = scale(envelope(highpass(noise(0.03), 0.25), 140), rng.uniform(0.5, 1.5))
        place(track, pop, t)
        t += rng.uniform(0.02, 0.09)
    save("sizzle", make_loop(track, d, xf), 0.7)


def make_pickup():
    save("pickup", fade_edges(sweep(520, 980, 0.09, 22, 0.8)))


def make_drop():
    low = sweep(320, 140, 0.11, 26, 0.9)
    tap = scale(envelope(highpass(noise(0.11), 0.4), 120), 0.35)
    save("drop", fade_edges(add(low, tap)))


def make_add():
    """Продукт добавлен в блюдо: два бодрых тона вверх."""
    track = []
    place(track, tone(660, 0.18, 14, 0.8, ((1, 1), (2, 0.25))), 0.0)
    place(track, tone(990, 0.22, 12, 0.8, ((1, 1), (2, 0.25))), 0.08)
    save("add", fade_edges(track))


def make_reject():
    """Нельзя: два коротких низких «бзз»."""
    track = []
    for start in (0.0, 0.11):
        buzz = [math.copysign(1.0, math.sin(2 * math.pi * 130 * i / SR)) * math.exp(-18 * i / SR) * 0.5
                for i in range(n_samples(0.09))]
        place(track, lowpass(buzz, 0.25), start)
    save("reject", fade_edges(track))


def make_done():
    """Готово: мягкий колокольчик."""
    save("done", fade_edges(tone(880, 0.7, 6, 0.8, ((1, 1), (2, 0.4), (3, 0.2), (4.1, 0.08)))))


def make_alarm():
    """Скоро сгорит: два тревожных сигнала."""
    track = []
    for start in (0.0, 0.22):
        beep = tone(1050, 0.13, 6, 0.7, ((1, 1), (3, 0.25), (5, 0.1)))
        place(track, beep, start)
    save("alarm", fade_edges(track))


def make_burnt():
    """Сгорело: падающий низкий тон и треск."""
    low = sweep(230, 70, 0.55, 5, 0.8)
    crackle = scale(envelope(highpass(noise(0.55), 0.3), 6), 0.4)
    save("burnt", fade_edges(add(low, crackle)))


def make_serve_bell():
    """Звонок раздачи: яркое «динь» с эхом."""
    bell = tone(1568, 1.5, 3.2, 0.7, ((1, 1), (1.5, 0.6), (2.0, 0.45), (2.76, 0.25), (4.07, 0.12)))
    track = []
    place(track, bell, 0.0)
    place(track, scale(bell, 0.35), 0.14)
    save("serve_bell", fade_edges(track))


def make_success():
    """Заказ выполнен: бодрое арпеджио вверх."""
    track = []
    for i, f in enumerate((523, 659, 784, 1047)):
        place(track, tone(f, 0.5, 5, 0.7, ((1, 1), (2, 0.3), (3, 0.12))), i * 0.14)
    place(track, tone(1319, 0.9, 3.5, 0.6, ((1, 1), (2, 0.3))), 0.58)
    save("success", fade_edges(track))


def make_fail():
    """Время вышло: опускающиеся грустные тона."""
    track = []
    for i, f in enumerate((392, 330, 262)):
        wave_ = [(2 * ((f * t / SR) % 1.0) - 1.0) * math.exp(-3.2 * t / SR)
                 for t in range(n_samples(0.45))]
        place(track, lowpass(wave_, 0.12), i * 0.22)
    save("fail", fade_edges(track), 0.7)


if __name__ == "__main__":
    make_chop()
    make_sizzle()
    make_pickup()
    make_drop()
    make_add()
    make_reject()
    make_done()
    make_alarm()
    make_burnt()
    make_serve_bell()
    make_success()
    make_fail()
