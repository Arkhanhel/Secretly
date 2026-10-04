// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/colors.dart';

/// Палитра окна настроек — по макету владельца «Настройки внешнего вида»
/// (29.09.2026).
///
/// 🔴 ПОЧЕМУ У НАСТРОЕК СВОЯ ПАЛИТРА, А НЕ ПАЛИТРА ОКНА.
///
/// Окно переписки — сине-чёрное: там разделение делает свет (рейка темнее
/// списка, список темнее ленты). Настройки открываются ПОВЕРХ всего окна и
/// живут по другим правилам: это страница с длинными списками выбора, и
/// владелец нарисовал её в спокойной серой гамме — боковая колонка на тон
/// темнее страницы, поля ввода ещё темнее, выбранная строка светлее. Числа
/// ниже взяты из макета как есть (`--main`, `--side`, `--ter`…), для обеих
/// схем.
///
/// Акцент своей палитры не имеет: это цвет, который человек выбрал сам, и он
/// приходит из окна ([SettingsScope.appColors]).
@immutable
class SettingsPalette {
  const SettingsPalette({
    required this.dark,
    required this.main,
    required this.side,
    required this.ter,
    required this.card,
    required this.text,
    required this.head,
    required this.muted,
    required this.faint,
    required this.border,
    required this.hover,
    required this.sel,
    required this.danger,
    required this.popover,
  });

  final bool dark;

  /// Страница содержимого.
  final Color main;

  /// Боковая колонка разделов.
  final Color side;

  /// Самый тёмный тон: поле поиска, подложка сегментов, граница колонки.
  final Color ter;

  /// Поверхность карточек со строками настроек.
  final Color card;

  /// Основной текст.
  final Color text;

  /// Заголовки и выбранное.
  final Color head;

  /// Второй тон: подписи групп, заголовки разделов.
  final Color muted;

  /// Третий тон: пояснения, значки без смысла цвета.
  final Color faint;

  /// Разделители разделов.
  final Color border;
  final Color hover;

  /// Выбранная строка, выбранный сегмент, спокойная кнопка.
  final Color sel;

  /// «Выйти» и «Удалить аккаунт» — красный макета.
  final Color danger;

  /// Всплывающие меню и окна поверх страницы.
  final Color popover;

  static const SettingsPalette darkPalette = SettingsPalette(
    dark: true,
    main: Color(0xFF313338),
    side: Color(0xFF2B2D31),
    ter: Color(0xFF1E1F22),
    card: Color(0xFF2B2D31),
    text: Color(0xFFDBDEE1),
    head: Color(0xFFF2F3F5),
    muted: Color(0xFFB5BAC1),
    faint: Color(0xFF949BA4),
    border: Color(0xFF3F4147),
    hover: Color(0xFF35373C),
    sel: Color(0xFF404249),
    danger: Color(0xFFF23F43),
    popover: Color(0xFF2B2D31),
  );

  static const SettingsPalette lightPalette = SettingsPalette(
    dark: false,
    main: Color(0xFFFFFFFF),
    side: Color(0xFFF2F3F5),
    ter: Color(0xFFE3E5E8),
    card: Color(0xFFF2F3F5),
    text: Color(0xFF313338),
    head: Color(0xFF060607),
    muted: Color(0xFF4E5058),
    faint: Color(0xFF5C5E66),
    border: Color(0xFFE1E2E4),
    hover: Color(0xFFE8E9EB),
    sel: Color(0xFFD7D9DC),
    // #F23F43 на белом не держит 4.5:1 для подписи; тот же тон на ступень
    // темнее.
    danger: Color(0xFFDA373C),
    popover: Color(0xFFFFFFFF),
  );

  static SettingsPalette of({required bool dark}) =>
      dark ? darkPalette : lightPalette;

  /// Цвет значка раздела: его собственный цвет, подогнанный под колонку.
  ///
  /// 🔴 ВЛАДЕЛЕЦ (29.09.2026): «иконки должны быть сразу все цветные — это
  /// важно». В макете цветной только значок выбранного раздела, остальные
  /// серые. Здесь цветные все, и цвет у каждого свой — тот же, что у раздела
  /// на телефоне ([DIconTint]): человек узнаёт раздел по цвету, не читая.
  ///
  /// Подгоняется только светлота. На тёмной колонке глухой зелёный тонет, на
  /// светлой жёлтый слепит и не читается; тон при этом остаётся своим.
  Color glyph(Color tint, {bool selected = false}) {
    final hsl = HSLColor.fromColor(tint);
    final l = dark
        ? hsl.lightness.clamp(selected ? 0.62 : 0.56, selected ? 0.78 : 0.72)
        : hsl.lightness.clamp(0.30, selected ? 0.42 : 0.46);
    return hsl.withLightness(l.toDouble()).toColor();
  }

  /// Подложка плитки со значком в шапке раздела.
  Color tile(Color tint) => tint.withValues(alpha: dark ? 0.20 : 0.14);
}

/// Палитра настроек и палитра окна — для всего, что внутри настроек.
///
/// [appColors] — палитра ОКНА до подмены: из неё берутся акцент, пузыри и
/// индикаторы для предпросмотра переписки. Внутри настроек `DColors.of`
/// отдаёт уже подменённую палитру (см. [settingsColorSet]).
class SettingsScope extends InheritedWidget {
  const SettingsScope({
    super.key,
    required this.palette,
    required this.appColors,
    required super.child,
  });

  final SettingsPalette palette;
  final DColorSet appColors;

  static SettingsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>();

  /// Палитра настроек; вне настроек — по яркости окна, чтобы виджеты набора
  /// рисовались и в одиночных тестах.
  static SettingsPalette paletteOf(BuildContext context) =>
      maybeOf(context)?.palette ??
      SettingsPalette.of(dark: DColors.of(context).isDark);

  /// Палитра окна (акцент, пузыри); вне настроек — текущая.
  static DColorSet appColorsOf(BuildContext context) =>
      maybeOf(context)?.appColors ?? DColors.of(context);

  /// Обернуть настройки: своя палитра поверх палитры окна.
  static Widget wrap(BuildContext context, {required Widget child}) {
    final app = DColors.of(context);
    final palette = SettingsPalette.of(dark: app.isDark);
    return SettingsScope(
      palette: palette,
      appColors: app,
      child: DColors(colors: settingsColorSet(app, palette), child: child),
    );
  }

  @override
  bool updateShouldNotify(SettingsScope oldWidget) =>
      oldWidget.palette != palette || oldWidget.appColors != appColors;
}

/// Палитра окна, перекрашенная в тона настроек.
///
/// 🔴 ПОДМЕНА ОДНА НА ВСЕ СЕМНАДЦАТЬ РАЗДЕЛОВ. Разделы рисуют себя токенами
/// окна (`c.textPrimary`, `c.chatList`, `c.borderSubtle`…), и если бы каждый
/// переводить на новую гамму руками, половина осталась бы сине-чёрной — ровно
/// то «лоскутное одеяло», от которого макет и уводит. Здесь меняются ТОЛЬКО
/// поверхности, линии и текст; акцент, пузыри, индикаторы, успех и
/// предупреждение остаются цветами окна — это выбор человека, а не гамма
/// страницы.
DColorSet settingsColorSet(DColorSet app, SettingsPalette p) {
  return app.copyWith(
    bg: p.main,
    sidebar: p.side,
    titleBar: p.side,
    chatList: p.card,
    detailsPanel: p.side,
    elevated: p.popover,
    hover: p.hover,
    pressed: p.sel,
    borderHairline: p.border.withValues(alpha: 0.6),
    borderSubtle: p.border,
    borderMenu: p.border,
    borderDivider: p.border,
    textPrimary: p.head,
    textSecondary: p.muted,
    textTertiary: p.faint,
    textDisabled: p.faint.withValues(alpha: 0.72),
    textFaint: p.faint,
    danger: p.danger,
  );
}
