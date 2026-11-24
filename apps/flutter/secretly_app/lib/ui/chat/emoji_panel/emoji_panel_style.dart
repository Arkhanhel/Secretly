// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Числа и цвета панели эмодзи — макет «Эмодзи, стикеры, GIF» (2a), объекты
/// `TI` (iPhone) и `TA` (Android) из его скрипта.
///
/// Тёмная тема — ровно цвета макета; светлая выведена из темы приложения (в
/// макете светлой нет). Материал — правило владельца 22.11.2026:
///  * iPhone — жидкое стекло панели (`pBg`, размытие 26 + насыщенность 170 %);
///  * Android — матовое стекло, как прежняя панель (размытие 24 без
///    насыщенности, тонкий кант), а не сплошная плита `TA.pBg`;
///  * «Размытие панелей» выключено — сплошная плита `opaquePanelFill`.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Высота раскрытия панели (`cubic-bezier(.25,1.1,.4,1)` 450 мс).
const Cubic kPanelHeightCurve = Cubic(.25, 1.1, .4, 1);

/// Переезд страниц (`cubic-bezier(.25,1.1,.4,1)` 500 мс).
const Cubic kPanelTrackCurve = Cubic(.25, 1.1, .4, 1);

/// Бегунок разделов (`cubic-bezier(.3,1.35,.5,1)` 450 мс).
const Cubic kPanelSegmentCurve = Cubic(.3, 1.35, .5, 1);

/// Подсветка рейки (`cubic-bezier(.3,1.3,.5,1)` 450 мс).
const Cubic kPanelRailCurve = Cubic(.3, 1.3, .5, 1);

/// Нажатие клеток и кнопок (`cubic-bezier(.3,1.7,.45,1)`).
const Cubic kPanelPressCurve = Cubic(.3, 1.7, .45, 1);

/// Нажатие эмодзи — ×1,3 (`cubic-bezier(.3,1.8,.45,1)` 350 мс).
const Cubic kPanelEmojiPressCurve = Cubic(.3, 1.8, .45, 1);

/// Всплывание окон (`es-pop`, `cubic-bezier(.3,1.6,.5,1)`).
const Cubic kPanelPopCurve = Cubic(.3, 1.6, .5, 1);

/// Меню превью (`cubic-bezier(.3,1.5,.5,1)`).
const Cubic kPanelMenuCurve = Cubic(.3, 1.5, .5, 1);

/// Полёт эмодзи / стикера (`cubic-bezier(.35,.7,.3,1)`).
const Cubic kPanelFlightCurve = Cubic(.35, .7, .3, 1);

@immutable
class EmojiPanelStyle {
  const EmojiPanelStyle({
    required this.ios,
    required this.dark,
    required this.frosted,
    required this.fill,
    required this.fillBottom,
    required this.filter,
    required this.radius,
    required this.edge,
    required this.handle,
    required this.seg,
    required this.segEdge,
    required this.ind,
    required this.indHighlight,
    required this.on,
    required this.off,
    required this.pill,
    required this.muted,
    required this.hdr,
    required this.railInd,
    required this.card,
    required this.primary,
    required this.chipOn,
    required this.chipOnFg,
    required this.overlay,
    required this.overlayFilter,
    required this.menu,
    required this.menuHover,
    required this.toneMark,
    required this.text,
    required this.shimmer,
    required this.danger,
    required this.islandFill,
    required this.islandEdge,
    required this.islandFilter,
    required this.islandShadow,
  });

  /// iPhone — стекло и шрифты Apple; Android — Material 3.
  final bool ios;
  final bool dark;
  final bool frosted;

  /// Подложка панели (сверху и снизу — у Android лёгкий градиент, как у
  /// прежнего листа).
  final Color fill;
  final Color fillBottom;

  /// Размытие фона; `null` — без размытия (настройка выключена).
  final ui.ImageFilter? filter;

  /// Скругление верха: 26 iPhone / 28 Android.
  final double radius;

  /// Кант верха (блик стекла / тонкая линия).
  final Color edge;
  final Color handle;
  final Color seg;
  final Color segEdge;
  final Color ind;
  final Color indHighlight;
  final Color on;
  final Color off;
  final Color pill;
  final Color muted;
  final Color hdr;
  final Color railInd;
  final Color card;
  final Color primary;
  final Color chipOn;
  final Color chipOnFg;

  /// Подложка превью стикера: размытие на iPhone, затемнение на Android.
  final Color overlay;
  final ui.ImageFilter? overlayFilter;
  final Color menu;
  final Color menuHover;

  /// Уголок «есть тон кожи».
  final Color toneMark;

  /// Основной текст поиска.
  final Color text;
  final Color shimmer;
  final Color danger;

  /// Плавающие островки внизу (разделы, «стереть»): своё стекло поверх
  /// сетки — iPhone жидкое (размытие 14 + насыщенность 170 %, как капли поля
  /// ввода), Android матовое (размытие 24). `null` — «Размытие панелей»
  /// выключено, островок на сплошной подложке.
  final Color islandFill;
  final Color islandEdge;
  final ui.ImageFilter? islandFilter;
  final Color islandShadow;

  static final ui.ImageFilter _iosGlass = ui.ImageFilter.compose(
    outer: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
    inner: const ColorFilter.matrix(_saturate170),
  );

  static final ui.ImageFilter _iosIsland = ui.ImageFilter.compose(
    outer: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
    inner: const ColorFilter.matrix(_saturate170),
  );

  static final ui.ImageFilter _androidMatte = ui.ImageFilter.blur(
    sigmaX: 24,
    sigmaY: 24,
  );

  static final ui.ImageFilter _iosOverlay = ui.ImageFilter.compose(
    outer: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
    inner: const ColorFilter.matrix(_saturate150),
  );

  /// Насыщенность 170 % (как `saturate(170%)` у CSS).
  static const List<double> _saturate170 = <double>[
    1.55118, -0.50064, -0.05054, 0, 0, //
    -0.14882, 1.19936, -0.05054, 0, 0,
    -0.14882, -0.50064, 1.64946, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// Насыщенность 150 %.
  static const List<double> _saturate150 = <double>[
    1.3937, -0.3576, -0.0361, 0, 0, //
    -0.1063, 1.1424, -0.0361, 0, 0,
    -0.1063, -0.3576, 1.4639, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// [solidFill] — `opaquePanelFill(context)` на случай выключенного
  /// размытия.
  static EmojiPanelStyle of(
    BuildContext context, {
    required bool frosted,
    required Color solidFill,
    bool? ios,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final isIos = ios ?? defaultTargetPlatform == TargetPlatform.iOS;
    final danger = dark ? const Color(0xFFFF6B6B) : const Color(0xFFD92D20);
    if (isIos) {
      final fill = !frosted
          ? solidFill
          : dark
          ? const Color(0xCC22262E) // rgba(34,38,46,.80)
          : const Color(0xD1F6F7FA);
      return EmojiPanelStyle(
        ios: true,
        dark: dark,
        frosted: frosted,
        fill: fill,
        fillBottom: fill,
        filter: frosted ? _iosGlass : null,
        radius: 26,
        edge: dark ? const Color(0x38FFFFFF) : const Color(0xE6FFFFFF),
        handle: dark ? const Color(0x47FFFFFF) : const Color(0x33000000),
        seg: dark ? const Color(0x14FFFFFF) : const Color(0x0F000000),
        segEdge: dark ? const Color(0x2EFFFFFF) : const Color(0x0A000000),
        ind: dark ? const Color(0x33FFFFFF) : Colors.white,
        indHighlight: dark ? const Color(0x59FFFFFF) : const Color(0x1A000000),
        on: dark ? Colors.white : cs.onSurface,
        off: dark ? const Color(0xFF9EABB8) : cs.onSurface.withValues(alpha: .5),
        pill: dark ? const Color(0x17FFFFFF) : const Color(0x0F000000),
        muted: dark ? const Color(0xFF9AA6B2) : cs.onSurface.withValues(alpha: .52),
        hdr: dark ? const Color(0xFFD3DCE5) : cs.onSurface.withValues(alpha: .82),
        railInd: dark ? const Color(0x24FFFFFF) : const Color(0x14000000),
        card: dark ? const Color(0x12FFFFFF) : const Color(0x0A000000),
        primary: dark
            ? Color.lerp(cs.primary, Colors.white, .35)!
            : cs.primary,
        chipOn: dark ? const Color(0x38FFFFFF) : cs.onSurface.withValues(alpha: .86),
        chipOnFg: dark ? Colors.white : cs.surface,
        overlay: dark ? const Color(0x6B060A0E) : const Color(0x59EEF1F5),
        overlayFilter: frosted ? _iosOverlay : null,
        menu: dark ? const Color(0xB82C323C) : const Color(0xDBFFFFFF),
        menuHover: dark ? const Color(0x14FFFFFF) : const Color(0x0D000000),
        toneMark: dark ? const Color(0x59FFFFFF) : const Color(0x40000000),
        text: dark ? const Color(0xFFEEF3F8) : cs.onSurface,
        shimmer: dark ? const Color(0x21FFFFFF) : const Color(0x14000000),
        danger: danger,
        islandFill: !frosted
            ? Color.alphaBlend(
                (dark ? Colors.white : Colors.black).withValues(alpha: .06),
                solidFill,
              )
            : dark
            ? const Color(0x9E2C313A)
            : const Color(0xC7FFFFFF),
        islandEdge: dark ? const Color(0x33FFFFFF) : const Color(0x14000000),
        islandFilter: frosted ? _iosIsland : null,
        islandShadow: dark ? const Color(0x47000000) : const Color(0x1F1B2430),
      );
    }
    // Android: матовое стекло прежней панели — подложка темы под размытием
    // 24, тонкий кант сверху; цвета Material 3 из темы.
    final fill = !frosted
        ? solidFill
        : solidFill.withValues(alpha: dark ? .68 : .82);
    final fillBottom = !frosted
        ? solidFill
        : (dark
                  ? Color.alphaBlend(Colors.black.withValues(alpha: .14), solidFill)
                  : Color.alphaBlend(
                      cs.surfaceContainerHighest.withValues(alpha: .55),
                      solidFill,
                    ))
              .withValues(alpha: dark ? .62 : .76);
    return EmojiPanelStyle(
      ios: false,
      dark: dark,
      frosted: frosted,
      fill: fill,
      fillBottom: fillBottom,
      filter: frosted ? _androidMatte : null,
      radius: 28,
      edge: dark ? const Color(0x1AFFFFFF) : const Color(0x8FFFFFFF),
      handle: dark ? const Color(0x47FFFFFF) : cs.onSurface.withValues(alpha: .22),
      seg: dark ? const Color(0x14FFFFFF) : cs.surfaceContainerHighest,
      segEdge: Colors.transparent,
      ind: dark ? const Color(0xFF1F4A66) : cs.secondaryContainer,
      indHighlight: Colors.transparent,
      on: dark ? const Color(0xFFD1E4FF) : cs.onSecondaryContainer,
      off: dark ? const Color(0xFFA9B1BA) : cs.onSurfaceVariant,
      pill: dark ? const Color(0x12FFFFFF) : cs.surfaceContainerHigh,
      muted: dark ? const Color(0xFF9AA4AE) : cs.onSurfaceVariant,
      hdr: dark ? const Color(0xFFC9D2DB) : cs.onSurface.withValues(alpha: .82),
      railInd: dark ? const Color(0xFF2B3A47) : cs.secondaryContainer.withValues(alpha: .7),
      card: dark ? const Color(0x0FFFFFFF) : cs.surfaceContainer,
      primary: dark ? const Color(0xFF9ECAFF) : cs.primary,
      chipOn: dark ? const Color(0xFF1F4A66) : cs.secondaryContainer,
      chipOnFg: dark ? const Color(0xFFD1E4FF) : cs.onSecondaryContainer,
      overlay: dark ? const Color(0xA8000000) : const Color(0x73000000),
      overlayFilter: null,
      menu: dark ? const Color(0xFF252E37) : cs.surfaceContainerHigh,
      menuHover: dark ? const Color(0x14FFFFFF) : const Color(0x0D000000),
      toneMark: dark ? const Color(0x59FFFFFF) : const Color(0x40000000),
      text: dark ? const Color(0xFFEEF3F8) : cs.onSurface,
      shimmer: dark ? const Color(0x21FFFFFF) : const Color(0x14000000),
      danger: danger,
      islandFill: !frosted
          ? Color.alphaBlend(
              (dark ? Colors.white : Colors.black).withValues(alpha: .06),
              solidFill,
            )
          : Color.alphaBlend(
              (dark ? Colors.white : Colors.black).withValues(alpha: .04),
              solidFill,
            ).withValues(alpha: dark ? .74 : .86),
      islandEdge: dark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
      islandFilter: frosted ? _androidMatte : null,
      islandShadow: dark ? const Color(0x40000000) : const Color(0x1A000000),
    );
  }
}
