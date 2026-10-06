#!/usr/bin/env python3
"""Генератор вариантов рисунков для магазина: полы, стены, столы и костюмы повара.

Запуск:  python3 tools/make_art.py
Создаёт SVG в art/kitchen/. Основные рисунки (floor_tile, wall_tile, counter, chef)
лежат отдельно и считаются «классическими»; здесь делаются их цветные варианты.
Чтобы добавить новый вариант, допиши строку в нужный словарь и запусти скрипт.
"""
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "kitchen")

# ---------- Полы: (светлая плитка, тёмная плитка, швы) ----------
FLOORS = {
    "blue": ("#e6eefb", "#cfe0f5", "#b9cfe9"),
    "terracotta": ("#ebbc9c", "#dca07b", "#c98a66"),
    "dark": ("#4d4747", "#3b3636", "#6a6262"),
    "gold": ("#f7e8bb", "#efd68f", "#d9be72"),
}

# ---------- Стены: (кирпич, швы, блик) ----------
WALLS = {
    "dark": ("#4b2d1d", "#2e1a10", "#68422b"),
    "white": ("#ece7df", "#bdb6aa", "#ffffff"),
    "blue": ("#35618f", "#1f3d5e", "#4f80b3"),
    "green": ("#42795a", "#274a37", "#5f9c78"),
}

# ---------- Столы: (основа, светлый верх, тёмный низ, линии досок, контур) ----------
COUNTERS = {
    "oak": ("#e0c28a", "#f3ddb0", "#b8985f", "#cfae72", "#7a5a2a"),
    "marble": ("#e8e8ec", "#f9f9fb", "#b5b5be", "#cfcfd8", "#6b6b78"),
    "steel": ("#aeb7c2", "#d3dae3", "#7e8896", "#97a1ae", "#4a5563"),
    "granite": ("#3d3f46", "#585b64", "#25272c", "#4c4f58", "#14151a"),
}

# ---------- Костюмы: (китель, контур кителя, колпак, контур колпака, платок, контур платка) ----------
COSTUMES = {
    "red": ("#d94b4b", "#8f2020", "#ffffff", "#b6c0cc", "#1f2937", "#0b0f16"),
    "blue": ("#4a79c9", "#26467f", "#ffffff", "#b6c0cc", "#facc15", "#a37d00"),
    "black": ("#2b2d33", "#0f1014", "#2b2d33", "#0f1014", "#f8fafc", "#8a97a8"),
    "gold": ("#f2c14e", "#a87a00", "#fff4cc", "#d9b44a", "#dc2626", "#8f1515"),
}


def write(name, text):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".svg")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print("создан", name)


def floor(name, light, dark, grout):
    write("floor_" + name, f"""<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80">
  <rect width="80" height="80" fill="{light}"/>
  <rect width="40" height="40" fill="{dark}"/>
  <rect x="40" y="40" width="40" height="40" fill="{dark}"/>
  <path d="M40 0V80M0 40H80" stroke="{grout}" stroke-width="1.5"/>
</svg>
""")


def wall(name, base, line, high):
    write("wall_" + name, f"""<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">
  <rect width="40" height="40" fill="{base}"/>
  <path d="M0 0H40M0 20H40M20 0V20M0 20V40M40 20V40" stroke="{line}" stroke-width="2"/>
  <path d="M2 2H18M22 2H38M2 22H38" stroke="{high}" stroke-width="1.5" opacity="0.7"/>
</svg>
""")


def counter(name, base, top, bottom, plank, outline):
    write("counter_" + name, f"""<svg xmlns="http://www.w3.org/2000/svg" width="160" height="70" viewBox="0 0 160 70">
  <rect width="160" height="70" fill="{base}"/>
  <rect width="160" height="6" fill="{top}"/>
  <rect y="62" width="160" height="8" fill="{bottom}"/>
  <path d="M0 24H160M0 44H160" stroke="{plank}" stroke-width="2"/>
  <path d="M50 6V24M110 24V44M30 44V62M130 6V24" stroke="{plank}" stroke-width="2"/>
  <path d="M0 0H160M0 70H160" stroke="{outline}" stroke-width="2"/>
</svg>
""")


def costume(name, coat, coat_line, hat, hat_line, scarf, scarf_line):
    write("chef_" + name, f"""<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <!-- Повар, вид сверху, смотрит вправо. Цвета костюма меняются -->
  <ellipse cx="30" cy="32" rx="14" ry="24" fill="{coat}" stroke="{coat_line}" stroke-width="2.5"/>
  <circle cx="46" cy="16" r="6" fill="#f3c9a0" stroke="#b9805a" stroke-width="2"/>
  <circle cx="46" cy="48" r="6" fill="#f3c9a0" stroke="#b9805a" stroke-width="2"/>
  <path d="M44 24 L54 32 L44 40 Z" fill="{scarf}" stroke="{scarf_line}" stroke-width="2" stroke-linejoin="round"/>
  <g fill="{hat}" stroke="{hat_line}" stroke-width="2">
    <circle cx="22" cy="32" r="8"/>
    <circle cx="26" cy="23" r="8"/>
    <circle cx="26" cy="41" r="8"/>
    <circle cx="35" cy="26" r="8"/>
    <circle cx="35" cy="38" r="8"/>
  </g>
  <circle cx="30" cy="32" r="9" fill="{hat}"/>
  <path d="M24 32 H36 M30 26 V38" stroke="{hat_line}" stroke-width="2" stroke-linecap="round" opacity="0.6"/>
</svg>
""")


if __name__ == "__main__":
    for key, colors in FLOORS.items():
        floor(key, *colors)
    for key, colors in WALLS.items():
        wall(key, *colors)
    for key, colors in COUNTERS.items():
        counter(key, *colors)
    for key, colors in COSTUMES.items():
        costume(key, *colors)
