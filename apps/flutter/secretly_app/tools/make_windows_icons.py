#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
# Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
"""Иконки Windows — программа, трей, установщик — из той же марки, что на Mac.

🔴 ЗАЧЕМ (29.09.2026, владелец: «Иконка приложения почему-то зелёная и
квадратная! Должна быть закруглённая!»). `app_icon.ico` делал удалённый теперь
`tools/generate_launcher_icons.dart` из старого `1.png`: один кадр 256 без
прозрачности на бирюзе #073A3D. Панель задач, «Пуск», установщик и
«Приложения» показывали бирюзовый квадрат, значки трея — тот же квадрат.

ФОРМА. Как в Dock: чёрная подложка-«сквиркл» (суперэллипс с тем же
показателем, что в tool/make_macos_icons.py) и белый знак. Windows, как и
macOS, ничего не скругляет сама — какую картинку отдали, такая и будет, —
поэтому углы прозрачные. Подложка занимает ~94 % холста: полей Apple под тень
здесь не нужно, а с ними иконка выглядит мельче соседних.

Знак берётся с мастера macOS (вариант «A», тот же, что на iPhone): белое на
чёрном, поэтому яркость пикселя и есть покрытие знака.

🔴 МЕЛКИЕ РАЗМЕРЫ. Гребни отпечатка в мастере идут с шагом ~30 точек из 824.
В кадре меньше 64 px шаг меньше двух пикселей, и «S» превращается в серое
пятно. Поэтому в мелких кадрах гребни сливаются в сплошную «S»
(морфологическое закрытие — силуэт отпечатка остаётся тем же), а в 16–24 px
знак ещё и крупнее. Кольцо «облачка» не трогается: оно и так толстое.

ФОРМАТ ICO. Кадры до 128 px — 32-битный BMP с альфой, 256 — PNG: классическая
раскладка, которую понимают и компилятор ресурсов, и LoadImage, и Inno Setup.

ТРЕЙ (assets/desktop/tray/). Те же кадры 16–64; «непрочитанное» — красная
точка в правом верхнем углу с прозрачным зазором, «без звука» — знак серый.

УСТАНОВЩИК (windows/installer/wizard_small_*.png). Картинка в шапке мастера.
Площадь квадратная и зависит от масштаба экрана — по файлу на каждый шаг
из документации Inno Setup 6.6+.

Запуск:  python3 tools/make_windows_icons.py [--preview картинка.png]
"""

from __future__ import annotations

import argparse
import importlib.util
import io
import pathlib
import struct

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent.parent


def _macos_tool():
    """Геометрию и форму берём у генератора macOS, чтобы они не разошлись."""
    path = HERE / "tool/make_macos_icons.py"
    spec = importlib.util.spec_from_file_location("make_macos_icons", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_MAC = _macos_tool()
SOURCE = _MAC.OUT_DIR / "app_icon_1024.png"
CANVAS = _MAC.CANVAS          # холст мастера macOS
BODY = _MAC.BODY              # подложка на нём по сетке Apple
SQUIRCLE_N = _MAC.SQUIRCLE_N  # та же форма, что в Dock

APP_ICON = HERE / "windows/runner/resources/app_icon.ico"
TRAY_DIR = HERE / "assets/desktop/tray"
WIZARD_DIR = HERE / "windows/installer"

APP_SIZES = (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)
TRAY_SIZES = (16, 20, 24, 32, 40, 48, 64)
# Площадь картинки в шапке мастера Inno Setup 6.6+ на 100…250 %.
WIZARD_SIZES = (58, 77, 97, 116, 124, 143, 159)

SS = 8                   # рисуем крупнее во столько раз, потом уменьшаем
MARGIN = 0.03            # поле с каждой стороны: подложка ~94 % холста
FULL_DETAIL_FROM = 64    # с этого размера гребни различимы (шаг ≥ 2 px)
SMALL_MAX = 24           # до этого размера знак крупнее
SMALL_GLYPH_SCALE = 1.15

WHITE = (255, 255, 255)
MUTED = (0x8E, 0x8E, 0x93)
RED = (0xFF, 0x3B, 0x30)
BADGE = 0.38             # диаметр точки непрочитанного от стороны значка


def load_glyph() -> Image.Image:
    """Знак с мастера как маска покрытия (L) на поле подложки BODY×BODY."""
    art = Image.open(SOURCE).convert("RGBA")
    if art.size != (CANVAS, CANVAS):
        raise SystemExit(f"мастер не {CANVAS}×{CANVAS}: {SOURCE}")
    m = (CANVAS - BODY) // 2
    # Яркость годится как покрытие только на чёрной подложке. Сменится марка
    # на цветную — лучше упасть, чем тихо собрать иконку из мусора.
    r, g, b, a = art.getpixel((m + BODY // 16, CANVAS // 2))
    if a < 250 or max(r, g, b) > 24:
        raise SystemExit(f"подложка мастера не чёрная: {(r, g, b, a)}")
    black = Image.new("RGBA", art.size, (0, 0, 0, 255))
    flat = Image.alpha_composite(black, art).convert("L")
    return flat.crop((m, m, m + BODY, m + BODY))


def _binary(im: Image.Image) -> Image.Image:
    return im.point(lambda v: 255 if v >= 128 else 0)


def _close(im: Image.Image, r: int) -> Image.Image:
    k = 2 * r + 1
    return im.filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.MinFilter(k))


def _open(im: Image.Image, r: int) -> Image.Image:
    k = 2 * r + 1
    return im.filter(ImageFilter.MinFilter(k)).filter(ImageFilter.MaxFilter(k))


def bold_glyph(glyph: Image.Image) -> Image.Image:
    """Знак для мелких кадров: гребни «S» слиты в одну сплошную букву.

    Кольцо «облачка» вместе с хвостиком — одна связная область, гребни —
    отдельные. Заливкой от левого края кольца отделяем кольцо, чтобы закрытие
    не залепило вырез между кольцом и хвостиком.
    """
    bw = _binary(glyph)
    mid = BODY // 2
    x = next((x for x in range(BODY) if bw.getpixel((x, mid)) == 255), None)
    if x is None:
        raise SystemExit("на средней строке мастера нет знака")
    tagged = bw.copy()
    ImageDraw.floodfill(tagged, (x, mid), 128, thresh=0)
    ring = tagged.point(lambda v: 255 if v == 128 else 0)
    ridges = tagged.point(lambda v: 255 if v == 255 else 0)
    if ridges.getbbox() is None:
        raise SystemExit("в мастере не нашлось гребней «S» внутри кольца")

    # Морфология на половинном разрешении: для кадров до 58 px его с запасом.
    # Щели между гребнями здесь ~7 px — закрытие r=6 их заливает; открытие
    # r=10 и размытие срезают ступеньки от концов гребней разной длины.
    work = BODY // 2
    s = _binary(ridges.resize((work, work), Image.LANCZOS))
    s = _open(_close(s, 6), 10)
    s = _binary(s.filter(ImageFilter.GaussianBlur(5)))
    ring = _binary(ring.resize((work, work), Image.LANCZOS))
    return ImageChops.lighter(ring, s)


def squircle(size: int) -> Image.Image:
    """Маска сквиркла |x|^n + |y|^n <= 1 — строками, а не по пикселю.

    Сглаживание края даёт итоговое уменьшение в SS раз.
    """
    mask = Image.new("L", (size, size), 0)
    half = size / 2.0
    for y in range(size):
        ny = abs((y + 0.5 - half) / half) ** SQUIRCLE_N
        if ny >= 1.0:
            continue
        dx = (1.0 - ny) ** (1.0 / SQUIRCLE_N) * half
        x0, x1 = round(half - dx), round(half + dx)
        if x1 > x0:
            mask.paste(255, (x0, y, x1, y + 1))
    return mask


def render(size: int, glyphs: dict, ink=WHITE, badge: bool = False) -> Image.Image:
    """Один кадр size×size, RGBA, углы прозрачные."""
    margin = round(size * MARGIN)
    plate = size - 2 * margin
    pb = plate * SS
    art = glyphs["full"] if size >= FULL_DETAIL_FROM else glyphs["bold"]
    scale = SMALL_GLYPH_SCALE if size <= SMALL_MAX else 1.0
    gs = round(pb * scale)
    off = (pb - gs) // 2

    plate_mask = squircle(pb)
    ink_mask = Image.new("L", (pb, pb), 0)
    ink_mask.paste(art.resize((gs, gs), Image.LANCZOS), (off, off))
    ink_mask = ImageChops.multiply(ink_mask, plate_mask)

    tile = Image.new("RGBA", (pb, pb), (0, 0, 0, 0))
    tile.paste((0, 0, 0, 255), (0, 0), plate_mask)
    tile.paste(ink + (255,), (0, 0), ink_mask)
    canvas = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    canvas.paste(tile, (margin * SS, margin * SS))
    if badge:
        _badge(canvas, size)
    return canvas.resize((size, size), Image.LANCZOS)


def _badge(canvas: Image.Image, size: int) -> None:
    """Красная точка в правом верхнем углу, отделённая прозрачным зазором."""
    d = round(size * BADGE) * SS
    gap = max(1, round(size / 32)) * SS
    right = canvas.width
    cut = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(cut).ellipse(
        (right - d - gap, -gap, right + gap - 1, d + gap - 1), fill=255)
    canvas.paste((0, 0, 0, 0), (0, 0), cut)
    dot = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(dot).ellipse((right - d, 0, right - 1, d - 1), fill=255)
    canvas.paste(RED + (255,), (0, 0), dot)


def _dib(im: Image.Image) -> bytes:
    """Кадр ICO как 32-битный BMP: BGRA снизу вверх и маска AND."""
    w, h = im.size
    r, g, b, a = im.split()
    xor = Image.merge("RGBA", (b, g, r, a)).transpose(Image.FLIP_TOP_BOTTOM).tobytes()
    alpha = a.transpose(Image.FLIP_TOP_BOTTOM).tobytes()
    stride = (w + 31) // 32 * 4
    mask = bytearray(stride * h)
    for y in range(h):
        for x in range(w):
            if alpha[y * w + x] < 128:
                mask[y * stride + x // 8] |= 0x80 >> (x % 8)
    header = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0,
                         len(xor) + len(mask), 0, 0, 0, 0)
    return header + xor + bytes(mask)


def _png(im: Image.Image) -> bytes:
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def write_ico(path: pathlib.Path, frames: list) -> None:
    blobs = [_png(im) if im.width >= 256 else _dib(im) for im in frames]
    out = bytearray(struct.pack("<HHH", 0, 1, len(frames)))
    offset = 6 + 16 * len(frames)
    for im, blob in zip(frames, blobs):
        out += struct.pack("<BBBBHHII", im.width % 256, im.height % 256, 0, 0,
                           1, 32, len(blob), offset)
        offset += len(blob)
    for blob in blobs:
        out += blob
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(out))

    # Сверка: файл читается обратно и кадры совпадают с нарисованными.
    ico = Image.open(path).ico
    for im in frames:
        back = ico.getimage(im.size).convert("RGBA")
        if ImageChops.difference(back, im).getbbox() is not None:
            raise SystemExit(f"{path.name}: кадр {im.width} не совпал после записи")
    print(f"  {path.relative_to(HERE)}: {', '.join(str(im.width) for im in frames)}")


def build() -> None:
    glyph = load_glyph()
    glyphs = {"full": glyph, "bold": bold_glyph(glyph)}

    write_ico(APP_ICON, [render(s, glyphs) for s in APP_SIZES])
    write_ico(TRAY_DIR / "tray.ico", [render(s, glyphs) for s in TRAY_SIZES])
    write_ico(TRAY_DIR / "tray_unread.ico",
              [render(s, glyphs, badge=True) for s in TRAY_SIZES])
    write_ico(TRAY_DIR / "tray_muted.ico",
              [render(s, glyphs, ink=MUTED) for s in TRAY_SIZES])

    for s in WIZARD_SIZES:
        out = WIZARD_DIR / f"wizard_small_{s}.png"
        render(s, glyphs).save(out, "PNG", optimize=True)
        print(f"  {out.relative_to(HERE)}: {s}x{s}")


def _ico_frames(path: pathlib.Path) -> list:
    ico = Image.open(path).ico
    return [ico.getimage(s).convert("RGBA") for s in sorted(ico.sizes())]


def preview(out: pathlib.Path) -> None:
    """Лист для глаза: все кадры 1:1 и мелкие ×4 на светлом и тёмном фоне."""
    icons = [_ico_frames(APP_ICON)] + [
        _ico_frames(TRAY_DIR / n)
        for n in ("tray.ico", "tray_unread.ico", "tray_muted.ico")
    ]
    wizard = [Image.open(WIZARD_DIR / f"wizard_small_{s}.png").convert("RGBA")
              for s in WIZARD_SIZES]
    zoom = [[im.resize((im.width * 4, im.height * 4), Image.NEAREST)
             for im in frames if im.width <= 32] for frames in icons]
    rows = icons + [wizard] + zoom
    gap = 12
    band = max(sum(im.width + gap for im in row) for row in rows) + gap
    height = sum(max(im.height for im in row) + gap for row in rows) + gap
    sheet = Image.new("RGBA", (band * 2, height), (0, 0, 0, 255))
    for i, bg in enumerate(((0xF3, 0xF3, 0xF3, 255), (0x20, 0x20, 0x20, 255))):
        left = i * band
        sheet.paste(Image.new("RGBA", (band, height), bg), (left, 0))
        y = gap
        for row in rows:
            x = left + gap
            for im in row:
                sheet.alpha_composite(im, (x, y))
                x += im.width + gap
            y += max(im.height for im in row) + gap
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"  лист для проверки: {out}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=pathlib.Path,
                        help="куда положить лист со всеми кадрами для проверки глазами")
    args = parser.parse_args()
    if not SOURCE.exists():
        raise SystemExit(f"нет мастера марки: {SOURCE}")
    build()
    if args.preview:
        preview(args.preview)


if __name__ == "__main__":
    main()
