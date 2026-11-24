#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
"""Контур буквы S из логотипа для обложек «Отпечаток S» и «Светлячки».

Макет «Profile Motion» (22.11.2026) берёт S из картинки логотипа без
пузыря. Читать картинку на телефоне незачем: здесь один раз обводим гребни
буквы (белые штрихи) и пишем контуры в lib/ui/profile/s_mark_shape.dart.

Как: штрихи — связные области ярких точек; кольцо пузыря с хвостом — самая
большая область, её отбрасываем. Каждый штрих обводим «бегущими квадратами»
по яркости 128 (с дробной точностью) и упрощаем (Дуглас — Пекер, 0,35 px).
Координаты — в долях большей стороны буквы, центр рамки буквы в нуле.

Запуск: python3 tool/gen_profile_s_mark.py "assets/Logo 512.png"
"""
import sys

from PIL import Image

ISO = 128.0
TOL = 0.35


def components(px, w, h, th):
    seen = [[0] * w for _ in range(h)]
    out = []
    for y in range(h):
        for x in range(w):
            if px[x, y] > th and not seen[y][x]:
                st = [(x, y)]
                seen[y][x] = 1
                pts = []
                while st:
                    a, b = st.pop()
                    pts.append((a, b))
                    for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        c, d = a + da, b + db
                        if 0 <= c < w and 0 <= d < h and not seen[d][c] \
                                and px[c, d] > th:
                            seen[d][c] = 1
                            st.append((c, d))
                out.append(pts)
    return out


def contours(field, w, h):
    """Бегущие квадраты: замкнутые контуры уровня ISO."""
    def v(x, y):
        if 0 <= x < w and 0 <= y < h:
            return field[y][x]
        return 0.0

    def lerp(p, q, a, b):
        t = (ISO - a) / (b - a)
        return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)

    segs = {}
    for y in range(-1, h):
        for x in range(-1, w):
            a, b = v(x, y), v(x + 1, y)
            c, d = v(x + 1, y + 1), v(x, y + 1)
            idx = (a > ISO) | ((b > ISO) << 1) | ((c > ISO) << 2) | \
                ((d > ISO) << 3)
            if idx in (0, 15):
                continue
            top = lambda: ('h', x, y, lerp((x, y), (x + 1, y), a, b))
            right = lambda: ('v', x + 1, y, lerp((x + 1, y), (x + 1, y + 1), b, c))
            bottom = lambda: ('h', x, y + 1, lerp((x, y + 1), (x + 1, y + 1), d, c))
            left = lambda: ('v', x, y, lerp((x, y), (x, y + 1), a, d))
            table = {
                1: [(left, top)], 2: [(top, right)], 3: [(left, right)],
                4: [(right, bottom)], 5: [(left, top), (right, bottom)],
                6: [(top, bottom)], 7: [(left, bottom)], 8: [(bottom, left)],
                9: [(bottom, top)], 10: [(top, left), (bottom, right)],
                11: [(bottom, right)], 12: [(right, left)], 13: [(right, top)],
                14: [(top, left)],
            }
            for e0, e1 in table[idx]:
                p, q = e0(), e1()
                segs[p[:3]] = (q[:3], p[3])
    loops = []
    used = set()
    for start in list(k for k in segs if k[0] != 'pt'):
        if start in used:
            continue
        loop = []
        cur = start
        while cur not in used and cur in segs:
            used.add(cur)
            nxt, pt = segs[cur]
            loop.append(pt)
            cur = nxt
        if len(loop) > 8:
            loops.append(loop)
    return loops


def simplify(pts, tol):
    if len(pts) < 3:
        return pts

    def dp(a, b):
        (x0, y0), (x1, y1) = pts[a], pts[b]
        dx, dy = x1 - x0, y1 - y0
        n = (dx * dx + dy * dy) ** 0.5 or 1e-9
        best, bi = 0.0, -1
        for i in range(a + 1, b):
            x, y = pts[i]
            dd = abs(dy * x - dx * y + x1 * y0 - y1 * x0) / n
            if dd > best:
                best, bi = dd, i
        if best > tol:
            return dp(a, bi)[:-1] + dp(bi, b)
        return [pts[a], pts[b]]

    # Замкнутый контур: делим пополам на самой дальней от начала точке.
    far = max(range(len(pts)),
              key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
    ring = pts + [pts[0]]
    sys.setrecursionlimit(10000)
    out = dp(0, far)[:-1] + [p for p in _dp_tail(ring, far, tol)]
    return out


def _dp_tail(ring, far, tol):
    sub = ring[far:]
    if len(sub) < 3:
        return sub[:-1]
    res = simplify_open(sub, tol)
    return res[:-1]


def simplify_open(pts, tol):
    def dp(a, b):
        (x0, y0), (x1, y1) = pts[a], pts[b]
        dx, dy = x1 - x0, y1 - y0
        n = (dx * dx + dy * dy) ** 0.5 or 1e-9
        best, bi = 0.0, -1
        for i in range(a + 1, b):
            x, y = pts[i]
            dd = abs(dy * x - dx * y + x1 * y0 - y1 * x0) / n
            if dd > best:
                best, bi = dd, i
        if best > tol:
            return dp(a, bi)[:-1] + dp(bi, b)
        return [pts[a], pts[b]]
    return dp(0, len(pts) - 1)


def main(src, dst):
    im = Image.open(src).convert('L')
    w, h = im.size
    px = im.load()
    comps = components(px, w, h, 110)
    comps.sort(key=len, reverse=True)
    strokes = comps[1:]  # самая большая — кольцо пузыря с хвостом
    keep = set()
    for c in strokes:
        if len(c) < 200:
            continue
        for p in c:
            keep.add(p)
    # Поле яркости только у штрихов буквы (+2 px вокруг для краёв).
    near = set()
    for (x, y) in keep:
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                near.add((x + dx, y + dy))
    xs = [p[0] for p in keep]
    ys = [p[1] for p in keep]
    x0, x1, y0, y1 = min(xs) - 3, max(xs) + 3, min(ys) - 3, max(ys) + 3
    fw, fh = x1 - x0 + 1, y1 - y0 + 1
    field = [[(float(px[x0 + i, y0 + j]) if (x0 + i, y0 + j) in near else 0.0)
              for i in range(fw)] for j in range(fh)]
    loops = contours(field, fw, fh)
    allx = [p[0] for l in loops for p in l]
    ally = [p[1] for l in loops for p in l]
    bx0, bx1, by0, by1 = min(allx), max(allx), min(ally), max(ally)
    span = max(bx1 - bx0, by1 - by0)
    mx, my = (bx0 + bx1) / 2, (by0 + by1) / 2
    out = []
    for l in loops:
        s = simplify(l, TOL)
        out.append([((x - mx) / span, (y - my) / span) for (x, y) in s])
    aspect = (bx1 - bx0) / (by1 - by0)
    total = sum(len(l) for l in out)
    with open(dst, 'w') as f:
        f.write('// SPDX-License-Identifier: AGPL-3.0-only\n')
        f.write('// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi\n')
        f.write('// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.\n\n')
        f.write('// СГЕНЕРИРОВАНО tool/gen_profile_s_mark.py — руками не править.\n')
        f.write('// Буква S логотипа (гребни отпечатка, без пузыря): %d контуров,\n' % len(out))
        f.write('// %d точек. Координаты — доли большей стороны, центр в нуле.\n\n' % total)
        f.write('/// Ширина буквы к высоте.\n')
        f.write('const double kSMarkAspect = %.5f;\n\n' % aspect)
        f.write('/// Контуры штрихов: x0, y0, x1, y1, … (замкнутые).\n')
        f.write('const List<List<double>> kSMarkContours = [\n')
        for l in out:
            f.write('  [\n')
            flat = []
            for (x, y) in l:
                flat.append('%.4f' % x)
                flat.append('%.4f' % y)
            for i in range(0, len(flat), 8):
                f.write('    ' + ', '.join(flat[i:i + 8]) + ',\n')
            f.write('  ],\n')
        f.write('];\n')
    print('contours', len(out), 'points', total, 'aspect', round(aspect, 4))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'assets/Logo 512.png',
         sys.argv[2] if len(sys.argv) > 2 else 'lib/ui/profile/s_mark_shape.dart')
