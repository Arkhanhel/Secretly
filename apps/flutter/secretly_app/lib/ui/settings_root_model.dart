// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Строки главного экрана настроек — одним списком данных.
///
/// Раньше каждая строка была виджетом прямо в разметке экрана. Теперь экран
/// сначала собирает СПИСОК (знак, подпись, что делать по нажатию), а рисуют
/// его два оформления: прежнее (Android, компьютерная сборка телефона) и
/// iPhone по макету Liquid Glass. Так строка не может появиться в одном
/// оформлении и потеряться в другом, а поиск по настройкам на iPhone ищет
/// ровно по тем же строкам, что видны на экране.
library;

import 'package:flutter/widgets.dart';

import 'settings_icons/settings_glyphs.dart';

@immutable
class SettingsRootRow {
  const SettingsRootRow({
    required this.id,
    required this.glyph,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.trailing,
  });

  /// Постоянное имя строки — для тестов и для поиска.
  final String id;
  final SettingsGlyph glyph;
  final String title;

  /// Пояснение под заголовком (Android) — на iPhone участвует только в
  /// поиске: iOS пишет в строке одно название.
  final String? subtitle;

  /// Текущее значение справа (iPhone), например язык.
  final String? value;

  /// Значок состояния справа: точка поддержки, предупреждение надёжности.
  final Widget? trailing;
  final VoidCallback onTap;

  /// Совпадает ли строка с запросом поиска: по названию, пояснению и
  /// значению, без учёта регистра и «ё».
  bool matches(String query) {
    final q = normalizeSettingsQuery(query);
    if (q.isEmpty) return true;
    for (final text in <String?>[title, subtitle, value]) {
      if (text != null && normalizeSettingsQuery(text).contains(q)) {
        return true;
      }
    }
    return false;
  }
}

@immutable
class SettingsRootGroup {
  const SettingsRootGroup({required this.title, required this.rows});

  final String title;
  final List<SettingsRootRow> rows;
}

String normalizeSettingsQuery(String s) =>
    s.trim().toLowerCase().replaceAll('ё', 'е');

/// Название языка интерфейса — на самом этом языке («Русский», «English»),
/// как его ищет человек в списке.
String settingsLanguageDisplayName(Locale locale) {
  final lang = locale.languageCode.toLowerCase();
  final country = locale.countryCode?.toUpperCase();
  switch (lang) {
    case 'de':
      return 'Deutsch';
    case 'es':
      return 'Español';
    case 'fr':
      return 'Français';
    case 'pt':
      return country == 'BR' ? 'Português (Brasil)' : 'Português';
    case 'ru':
      return 'Русский';
    case 'uk':
      return 'Українська';
    default:
      return 'English';
  }
}
