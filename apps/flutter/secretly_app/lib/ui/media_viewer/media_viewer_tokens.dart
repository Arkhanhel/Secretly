// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Цвета, размеры и движение просмотра медиа и редактора фото — макет
/// «Просмотр медиа» (6a тёмная, 6b светлая), 22.11.2026.
///
/// Значения — из прототипа `MediaViewerPhone.dc.html` (функция `T()`), а не
/// «на глаз». Тема выбирается по яркости темы приложения: тёмная — чёрный фон
/// и тёмное стекло, светлая — фон #F3F5F8, белое стекло и светлые затемнения.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/island_backdrop.dart' show PanelPrefs;

/// Выключатель нового просмотра на телефонах. `false` — прежний
/// `MediaViewerDialog` и прежние окна аватара и галереи профиля (путь отката
/// без новой сборки логики: одна константа).
const bool kMediaViewerV2 = true;

/// Новый просмотр — только iPhone и Android. Компьютер держит свой.
bool get mediaViewerV2Enabled =>
    kMediaViewerV2 &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// С-10 (разбор 22.11.2026): стекло просмотра — по правилу проекта, как у
/// панели ввода (`composer_drops.dart`): iPhone — «жидкое» стекло (размытие
/// и насыщенность 170 %), Android — матовое (размытие 24 без насыщенности).
/// Настройка «Размытие панелей» выключена — острова сплошные на обеих.
/// `false` — как было: стекло без насыщенности только на iPhone (без учёта
/// настройки), на Android сплошные острова.
const bool kMediaViewerGlassRule = true;

/// Размывать ли под островами.
bool get mediaViewerGlass => kMediaViewerGlassRule
    ? PanelPrefs.frostedEnabled.value
    : defaultTargetPlatform == TargetPlatform.iOS;

/// iPhone — «жидкое» стекло, Android — матовое.
bool get mediaViewerLiquidGlass => defaultTargetPlatform == TargetPlatform.iOS;

/// Насыщенность 170 % (как `saturate(170%)` у CSS), веса Rec. 709.
const ColorFilter _kSaturate170 = ColorFilter.matrix(<double>[
  1.55118, -0.50064, -0.05054, 0, 0, //
  -0.14882, 1.19936, -0.05054, 0, 0, //
  -0.14882, -0.50064, 1.64946, 0, 0, //
  0, 0, 0, 1, 0, //
]);

final ui.ImageFilter _kMatteFilter = ui.ImageFilter.blur(
  sigmaX: 24,
  sigmaY: 24,
);

/// Фильтр стекла: [iosSigma] — размытие iPhone (у каждого острова своё по
/// макету); Android — всегда матовое 24.
ui.ImageFilter mediaViewerGlassFilter(double iosSigma) {
  final blur = ui.ImageFilter.blur(sigmaX: iosSigma, sigmaY: iosSigma);
  if (!kMediaViewerGlassRule) return blur;
  if (!mediaViewerLiquidGlass) return _kMatteFilter;
  return ui.ImageFilter.compose(outer: blur, inner: _kSaturate170);
}

/// Перелёт, листание, лента миниатюр: 340 мс, `Cubic(.2,.8,.2,1)`.
const Cubic kMediaFlightCurve = Cubic(.2, .8, .2, 1);
const Duration kMediaFlightDuration = Duration(milliseconds: 340);

/// Анимации рамки кадра и выпрямления в редакторе: 320 мс той же кривой.
const Duration kMediaEditorAnimDuration = Duration(milliseconds: 320);

/// Оформление (показать / скрыть): 220 мс прозрачность, 250 мс сдвиг.
const Duration kMediaChromeFade = Duration(milliseconds: 220);
const Duration kMediaChromeSlide = Duration(milliseconds: 250);

/// Шторки: 260 мс, сдвиг 40 px + прозрачность.
const Duration kMediaSheetDuration = Duration(milliseconds: 260);

/// Восемь цветов рисунка и текста.
const List<Color> kMediaDrawPalette = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFF0E141B),
  Color(0xFFFF5A5F),
  Color(0xFFFFB020),
  Color(0xFFFFE14D),
  Color(0xFF3DD68C),
  Color(0xFF36A3FF),
  Color(0xFFA86BFF),
];

@immutable
class MediaViewerTokens {
  const MediaViewerTokens({
    required this.isDark,
    required this.viewerBg,
    required this.island,
    required this.islandSolid,
    required this.islandShadow,
    required this.islandBorder,
    required this.ink,
    required this.sub,
    required this.scrimTop,
    required this.scrimBottom,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.sheet,
    required this.sheetShadow,
    required this.backdrop,
    required this.chip,
    required this.chipOn,
    required this.chipOnInk,
    required this.track,
    required this.ring,
    required this.editorBg,
    required this.editorInk,
    required this.editorSub,
    required this.cropDim,
    required this.cropHandle,
    required this.cropLine,
    required this.cropGrid,
    required this.toastBg,
    required this.toastInk,
  });

  final bool isDark;
  final Color viewerBg;

  /// Стекло острова (iPhone) и сплошной остров (Android).
  final Color island;
  final Color islandSolid;
  final List<BoxShadow> islandShadow;
  final Color islandBorder;
  final Color ink;
  final Color sub;

  /// Затемнение сверху: 0 %, 55 %, 100 %.
  final List<Color> scrimTop;

  /// Затемнение снизу: 0 %, 50 %, 100 % (снизу вверх).
  final List<Color> scrimBottom;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color sheet;
  final List<BoxShadow> sheetShadow;
  final Color backdrop;
  final Color chip;
  final Color chipOn;
  final Color chipOnInk;
  final Color track;

  /// Обводка текущей миниатюры в ленте.
  final Color ring;
  final Color editorBg;
  final Color editorInk;
  final Color editorSub;
  final Color cropDim;
  final Color cropHandle;
  final Color cropLine;
  final Color cropGrid;
  final Color toastBg;
  final Color toastInk;

  static const double islandBlur = 24;
  static const double sheetBlur = 30;

  static const MediaViewerTokens dark = MediaViewerTokens(
    isDark: true,
    viewerBg: Color(0xFF000000),
    island: Color(0x8520242A), // rgba(32,36,42,.52)
    islandSolid: Color(0xE620242A),
    islandShadow: <BoxShadow>[],
    islandBorder: Color(0x29FFFFFF), // inset .5 rgba(255,255,255,.16)
    ink: Color(0xFFFFFFFF),
    sub: Color(0xB3FFFFFF),
    scrimTop: <Color>[Color(0x9E000000), Color(0x4D000000), Color(0x00000000)],
    scrimBottom: <Color>[
      Color(0xB8000000),
      Color(0x66000000),
      Color(0x00000000),
    ],
    accent: Color(0xFF7FD0FF),
    onAccent: Color(0xFF0B1B28),
    danger: Color(0xFFFF6B6F),
    sheet: Color(0xF21E2228),
    sheetShadow: <BoxShadow>[
      BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 20)),
    ],
    backdrop: Color(0x73000000),
    chip: Color(0x1AFFFFFF),
    chipOn: Color(0xFFFFFFFF),
    chipOnInk: Color(0xFF000000),
    track: Color(0x47FFFFFF),
    ring: Color(0xFFFFFFFF),
    editorBg: Color(0xFF000000),
    editorInk: Color(0xFFFFFFFF),
    editorSub: Color(0x8CFFFFFF),
    cropDim: Color(0xA3000000),
    cropHandle: Color(0xFFFFFFFF),
    cropLine: Color(0xD9FFFFFF),
    cropGrid: Color(0x66FFFFFF),
    toastBg: Color(0xF51E2228),
    toastInk: Color(0xFFFFFFFF),
  );

  static const MediaViewerTokens light = MediaViewerTokens(
    isDark: false,
    viewerBg: Color(0xFFF3F5F8),
    island: Color(0xC2FFFFFF), // rgba(255,255,255,.76)
    islandSolid: Color(0xF5FFFFFF),
    islandShadow: <BoxShadow>[
      BoxShadow(color: Color(0x1A0E141B), blurRadius: 18, offset: Offset(0, 4)),
    ],
    islandBorder: Color(0x140E141B),
    ink: Color(0xFF0E141B),
    sub: Color(0x9E0E141B),
    scrimTop: <Color>[Color(0xF0F3F5F8), Color(0x8CF3F5F8), Color(0x00F3F5F8)],
    scrimBottom: <Color>[
      Color(0xF5F3F5F8),
      Color(0xB3F3F5F8),
      Color(0x00F3F5F8),
    ],
    accent: Color(0xFF1F7AE0),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFD93A40),
    sheet: Color(0xF7FFFFFF),
    sheetShadow: <BoxShadow>[
      BoxShadow(color: Color(0x2E0E141B), blurRadius: 50, offset: Offset(0, 20)),
    ],
    backdrop: Color(0x470E141B),
    chip: Color(0x0F0E141B),
    chipOn: Color(0xFF0E141B),
    chipOnInk: Color(0xFFFFFFFF),
    track: Color(0x290E141B),
    ring: Color(0xFF0E141B),
    editorBg: Color(0xFFF3F5F8),
    editorInk: Color(0xFF0E141B),
    editorSub: Color(0x8C0E141B),
    cropDim: Color(0xD1F3F5F8),
    cropHandle: Color(0xFF0E141B),
    cropLine: Color(0xB30E141B),
    cropGrid: Color(0x590E141B),
    toastBg: Color(0xFF0E141B),
    toastInk: Color(0xFFFFFFFF),
  );

  static MediaViewerTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? light : dark;

  static MediaViewerTokens forBrightness(Brightness b) =>
      b == Brightness.light ? light : dark;

  /// Цвет острова: стекло (размытие включено) или сплошной.
  Color get islandFill => mediaViewerGlass ? island : islandSolid;
}
