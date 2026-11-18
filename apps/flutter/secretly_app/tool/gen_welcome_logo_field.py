#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
"""Точки логотипа для фона приветственных экранов.

Фон «логотип из частиц» (макет «Secretly Kit», 17.11.2026) раскладывает
частицы по форме знака. Считать форму из картинки при каждом запуске телефона
незачем: делаем это один раз здесь и кладём готовые точки в маленький файл.

Формат assets/welcome/logo_field.bin — подряд тройки int16 (little-endian):
x, y — координата точки в долях большей стороны знака, центр в нуле,
       умножено на 32767 (то есть диапазон примерно −0,5…0,5);
w    — «яркость» точки 0…32767 (чем ближе к середине штриха, тем больше).

Запуск: python3 tool/gen_welcome_logo_field.py "assets/Logo 512.png"
"""
import random
import struct
import sys

from PIL import Image

COUNT = 3600
SIDE = 560


def main(src: str, dst: str) -> None:
    img = Image.open(src).convert('RGB')
    k = SIDE / max(img.width, img.height)
    img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    w, h = img.size
    px = img.load()
    lum = [[0.0] * w for _ in range(h)]
    hist = [0] * 256
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            l = 0.2126 * r + 0.7152 * g + 0.0722 * b
            lum[y][x] = l
            hist[int(l)] += 1
    acc, med = 0, 0
    for v in range(256):
        acc += hist[v]
        if acc >= w * h / 2:
            med = v
            break
    dark_fig = med > 140
    th_hi = min(210, med + 24)
    th_lo = max(60, med - 26)
    pts = []
    min_x = min_y = 10 ** 9
    max_x = max_y = -10 ** 9
    for y in range(h):
        for x in range(w):
            l = lum[y][x]
            wt = 0.0
            if dark_fig:
                if l < th_lo:
                    wt = ((th_lo - l) / (th_lo or 1)) ** 0.7
            elif l > th_hi:
                wt = ((l - th_hi) / ((255 - th_hi) or 1)) ** 0.85
            if wt > 0.002:
                pts.append((x, y, wt))
                min_x, max_x = min(min_x, x), max(max_x, x)
                min_y, max_y = min(min_y, y), max(max_y, y)
    cx, cy = (min_x + max_x) / 2, (min_y + max_y) / 2
    inv = 1 / (max(max_x - min_x, max_y - min_y) or 1)
    rnd = random.Random(20261117)
    weights = [p[2] for p in pts]
    out = bytearray()
    for p in rnd.choices(pts, weights=weights, k=COUNT):
        jx = (rnd.random() + rnd.random() - 1) * 1.8
        jy = (rnd.random() + rnd.random() - 1) * 1.8
        nx = (p[0] + jx - cx) * inv
        ny = (p[1] + jy - cy) * inv
        out += struct.pack('<hhh', round(nx * 32767), round(ny * 32767),
                           round(min(1.0, p[2]) * 32767))
    with open(dst, 'wb') as f:
        f.write(out)
    print(f'{dst}: {COUNT} точек, {len(out)} байт (тёмный знак: {dark_fig})')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'assets/Logo 512.png',
         sys.argv[2] if len(sys.argv) > 2 else 'assets/welcome/logo_field.bin')
