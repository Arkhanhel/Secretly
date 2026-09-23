#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
# Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
"""Иконка приложения для macOS из той же марки, что на телефоне.

🔴 ЗАЧЕМ ЭТО ВООБЩЕ ПОНАДОБИЛОСЬ. В `macos/Runner/Assets.xcassets` лежали
СТАНДАРТНЫЕ ИКОНКИ FLUTTER — синяя галка из шаблона `flutter create`. Их никто
не заменил, и выпуск 1.8.51, уже выложенный и заверенный, показывает в Dock,
в Finder и в образе диска чужой логотип.

🔴 ПОЧЕМУ НЕЛЬЗЯ ПРОСТО СКОПИРОВАТЬ ТЕЛЕФОННУЮ. У iOS и macOS РАЗНАЯ форма
иконки. Телефонная — квадрат во всё поле: маску скруглённых углов накладывает
сама система. macOS ничего не накладывает: приложение отдаёт готовую картинку,
и если отдать квадрат, он и будет квадратом — единственным острым углом в Dock,
где всё остальное скруглено.

Поэтому здесь марка вписывается в «сквиркл» — суперэллипс, а не окружность в
углах: именно такую форму Apple использует с Big Sur, и обычное скругление рядом
с системными иконками читается как чуть другая, «не своя» форма.

Пропорции из сетки Apple: на поле 1024 тело иконки 824×824 по центру, то есть
по 100 точек полей с каждой стороны. Поля не пустая трата места: в них живёт
тень, и без них иконка выглядит крупнее соседних.

Запуск:  python3 tool/make_macos_icons.py
"""

from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent.parent
SOURCE = HERE / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
OUT_DIR = HERE / "macos/Runner/Assets.xcassets/AppIcon.appiconset"

CANVAS = 1024
BODY = 824               # тело иконки по сетке Apple
SQUIRCLE_N = 5.0         # показатель суперэллипса: 2 — круг, ∞ — квадрат
SS = 4                   # во сколько раз рисуем крупнее ради гладкого края

SIZES = [16, 32, 64, 128, 256, 512, 1024]


def squircle_mask(size: int, n: float) -> Image.Image:
    """Маска сквиркла: |x|^n + |y|^n <= 1."""
    big = size * SS
    mask = Image.new("L", (big, big), 0)
    px = mask.load()
    half = big / 2.0
    for y in range(big):
        # Нормируем в [-1, 1] по центру пикселя.
        ny = abs((y + 0.5 - half) / half) ** n
        if ny > 1.0:
            continue
        # Решаем |x|^n <= 1 - |y|^n относительно x — по строке, а не по точке:
        # попиксельный перебор на 4096×4096 считался бы минутами.
        nx = (1.0 - ny) ** (1.0 / n)
        dx = nx * half
        x0 = max(0, int(half - dx))
        x1 = min(big, int(half + dx))
        for x in range(x0, x1):
            px[x, y] = 255
    return mask.resize((size, size), Image.LANCZOS)


def build_master() -> Image.Image:
    art = Image.open(SOURCE).convert("RGBA").resize((BODY, BODY), Image.LANCZOS)
    mask = squircle_mask(BODY, SQUIRCLE_N)
    art.putalpha(mask)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))

    # 🔴 Тень ПОД телом, а не вокруг: у системных иконок свет падает сверху, и
    # тень уходит вниз. Без неё иконка выглядит наклейкой, приклеенной к Dock.
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 90), (100, 100 + 10), mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    canvas = Image.alpha_composite(canvas, shadow)

    top = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    top.paste(art, (100, 100), art)
    return Image.alpha_composite(canvas, top)


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"нет исходной марки: {SOURCE}")
    master = build_master()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for s in SIZES:
        img = master if s == CANVAS else master.resize((s, s), Image.LANCZOS)
        out = OUT_DIR / f"app_icon_{s}.png"
        img.save(out, "PNG")
        print(f"  {out.name}: {s}x{s}")


if __name__ == "__main__":
    main()
