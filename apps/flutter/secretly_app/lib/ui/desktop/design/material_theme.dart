// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ТЕМА MATERIAL ДЛЯ ОКНА ПК — ИЗ ТОЙ ЖЕ ПАЛИТРЫ, ЧТО И НАШИ ОКНА.
///
/// 🔴 ЗАЧЕМ (28.09.2026). Раньше `ThemeData` задавала только яркость и
/// акцент, а всё остальное Material брал из своих умолчаний: диалоги, выбор
/// даты и времени, выпадающие списки, подсказки и плашки снизу рисовались в
/// чужом виде — радиус 28 у диалога, 4 у меню, светлая подсказка в тёмной
/// теме, тёмный текст плашки на тёмном фоне. Рядом с нашими окнами (радиус
/// 10–14, тонкая рамка) это выглядело как два разных приложения.
///
/// Здесь каждая поверхность Material получает цвет, рамку и радиус из
/// [DColorSet] — тех же значений, что у [DesktopDialog], [DesktopPopover] и
/// [ContextMenu]. Телефонная тема этим файлом не затрагивается.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Собирает [ThemeData] окна ПК из палитры [c].
ThemeData desktopMaterialTheme(DColorSet c, {required bool dark}) {
  final brightness = dark ? Brightness.dark : Brightness.light;
  final base = ColorScheme.fromSeed(
    seedColor: c.accentPrimary,
    brightness: brightness,
  );
  // Поверхности Material (`surface`, `surfaceContainer*`) — это наши
  // поднятые окна. Иначе, например, `AlertDialog` возьмёт
  // `surfaceContainerHigh` из сгенерированной схемы, а не наш цвет.
  final scheme = base.copyWith(
    primary: c.accentPrimary,
    surface: c.elevated,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerLowest: c.elevated,
    surfaceContainerLow: c.elevated,
    surfaceContainer: c.elevated,
    surfaceContainerHigh: c.elevated,
    surfaceContainerHighest: c.elevated,
    surfaceTint: Colors.transparent,
    outline: c.borderSubtle,
    outlineVariant: c.borderDivider,
    error: c.danger,
    // Плашка снизу в M3 берёт «обратную» поверхность. У нас плашки такие же
    // поднятые окна, как всё остальное.
    inverseSurface: c.elevated,
    onInverseSurface: c.textPrimary,
    inversePrimary: c.accentPrimary,
  );

  final menuShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(DRadii.md),
    side: BorderSide(color: c.borderMenu),
  );
  final windowShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(DRadii.lg),
    side: BorderSide(color: c.borderMenu),
  );
  final body = DType.body.copyWith(color: c.textPrimary);
  final menuStyle = MenuStyle(
    backgroundColor: WidgetStatePropertyAll(c.elevated),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(menuShape),
    elevation: const WidgetStatePropertyAll(8),
  );

  return ThemeData(
    brightness: brightness,
    fontFamily: DType.family,
    // 🔴 Эмодзи Windows — Noto, как на телефоне (30.09.2026, Э1). Отсюда
    // запасной шрифт получает текст без своего семейства: плитки сетки
    // эмодзи, фишки реакций, знак на месте незагруженной анимации, поле
    // ввода. На macOS здесь `null` — как и было. Почему только темы мало —
    // см. `emoji_font.dart`.
    fontFamilyFallback: DType.emojiFallback,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.elevated,
    cardColor: c.elevated,
    dividerColor: c.borderDivider,
    hoverColor: c.hover,
    splashFactory: NoSplash.splashFactory,
    dialogTheme: DialogThemeData(
      backgroundColor: c.elevated,
      surfaceTintColor: Colors.transparent,
      shape: windowShape,
      titleTextStyle: DType.title.copyWith(color: c.textPrimary),
      contentTextStyle: body,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.elevated,
      surfaceTintColor: Colors.transparent,
      shape: menuShape,
      textStyle: body,
      labelTextStyle: WidgetStatePropertyAll(body),
    ),
    menuTheme: MenuThemeData(style: menuStyle),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: menuStyle,
      textStyle: body,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      textStyle: DType.caption.copyWith(
        color: c.textPrimary,
        decoration: TextDecoration.none,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.m,
        vertical: DSpace.xs,
      ),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(DRadii.sm),
        border: Border.all(color: c.borderSubtle),
        boxShadow: DShadows.popover,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.elevated,
      contentTextStyle: body,
      actionTextColor: c.accentPrimary,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: menuShape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.elevated,
      modalBackgroundColor: c.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DRadii.lg),
        ),
        side: BorderSide(color: c.borderMenu),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.elevated,
      surfaceTintColor: Colors.transparent,
      shape: windowShape,
      headerForegroundColor: c.textPrimary,
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : c.textPrimary,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? c.accentPrimary
            : Colors.transparent,
      ),
      todayBorder: BorderSide(color: c.accentPrimary),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: c.elevated,
      shape: windowShape,
      dialBackgroundColor: c.hover,
      hourMinuteTextColor: c.textPrimary,
      dialTextColor: c.textPrimary,
      entryModeIconColor: c.textSecondary,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accentPrimary,
      selectionColor: c.selected,
      selectionHandleColor: c.accentPrimary,
    ),
  );
}

/// Стиль текста по умолчанию над навигатором — с запасным шрифтом эмодзи
/// (Windows, 30.09.2026, Э1). Ставится в `builder` обоих `MaterialApp` ПК.
///
/// Тема доходит только до текста под `Material`. Где его нет — например,
/// экран звонка в отдельном окне ОС, — стиль по умолчанию остаётся
/// Flutter-овским, и текст без своего списка запасных шрифтов уходил бы в
/// Segoe. На macOS возвращается сам [child], без лишнего слоя.
Widget desktopEmojiTextFallback(Widget child) {
  final fallback = DType.emojiFallback;
  if (fallback == null) return child;
  return DefaultTextStyle.merge(
    style: TextStyle(fontFamilyFallback: fallback),
    child: child,
  );
}
