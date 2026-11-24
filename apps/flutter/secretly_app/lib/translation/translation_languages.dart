// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Языки переводчика на телефоне (Google ML Kit, 59 языков) — один список на
// «Настройки → Язык» и на настройку перевода в чате (22.11.2026, Т-4).
// Без ML Kit: файл можно ввозить и в облегчённой сборке.

import 'package:flutter/foundation.dart';

@immutable
class TranslationLanguage {
  const TranslationLanguage(this.code, this.name, this.flag);

  /// BCP-47 код, как его понимает ML Kit.
  final String code;

  /// Самоназвание языка.
  final String name;

  /// Флаг-эмодзи (для эсперанто — звезда).
  final String flag;

  /// Подпись «флаг  название», как в настройках.
  String get label => '$flag  $name';
}

/// 16 популярных — наверху списка, в том же порядке, что всегда был в
/// настройках.
const List<TranslationLanguage> kPopularTranslationLanguages =
    <TranslationLanguage>[
      TranslationLanguage('en', 'English', '🇬🇧'),
      TranslationLanguage('ru', 'Русский', '🇷🇺'),
      TranslationLanguage('uk', 'Українська', '🇺🇦'),
      TranslationLanguage('es', 'Español', '🇪🇸'),
      TranslationLanguage('pt', 'Português', '🇵🇹'),
      TranslationLanguage('fr', 'Français', '🇫🇷'),
      TranslationLanguage('de', 'Deutsch', '🇩🇪'),
      TranslationLanguage('it', 'Italiano', '🇮🇹'),
      TranslationLanguage('pl', 'Polski', '🇵🇱'),
      TranslationLanguage('tr', 'Türkçe', '🇹🇷'),
      TranslationLanguage('nl', 'Nederlands', '🇳🇱'),
      TranslationLanguage('zh', '中文', '🇨🇳'),
      TranslationLanguage('ja', '日本語', '🇯🇵'),
      TranslationLanguage('ko', '한국어', '🇰🇷'),
      TranslationLanguage('ar', 'العربية', '🇸🇦'),
      TranslationLanguage('hi', 'हिन्दी', '🇮🇳'),
    ];

/// Остальные 43 языка ML Kit, по алфавиту кода.
const List<TranslationLanguage> kOtherTranslationLanguages =
    <TranslationLanguage>[
      TranslationLanguage('af', 'Afrikaans', '🇿🇦'),
      TranslationLanguage('be', 'Беларуская', '🇧🇾'),
      TranslationLanguage('bg', 'Български', '🇧🇬'),
      TranslationLanguage('bn', 'বাংলা', '🇧🇩'),
      TranslationLanguage('ca', 'Català', '🇦🇩'),
      TranslationLanguage('cs', 'Čeština', '🇨🇿'),
      TranslationLanguage('cy', 'Cymraeg', '🏴'),
      TranslationLanguage('da', 'Dansk', '🇩🇰'),
      TranslationLanguage('el', 'Ελληνικά', '🇬🇷'),
      TranslationLanguage('eo', 'Esperanto', '⭐'),
      TranslationLanguage('et', 'Eesti', '🇪🇪'),
      TranslationLanguage('fa', 'فارسی', '🇮🇷'),
      TranslationLanguage('fi', 'Suomi', '🇫🇮'),
      TranslationLanguage('ga', 'Gaeilge', '🇮🇪'),
      TranslationLanguage('gl', 'Galego', '🇪🇸'),
      TranslationLanguage('gu', 'ગુજરાતી', '🇮🇳'),
      TranslationLanguage('he', 'עברית', '🇮🇱'),
      TranslationLanguage('hr', 'Hrvatski', '🇭🇷'),
      TranslationLanguage('ht', 'Kreyòl ayisyen', '🇭🇹'),
      TranslationLanguage('hu', 'Magyar', '🇭🇺'),
      TranslationLanguage('id', 'Bahasa Indonesia', '🇮🇩'),
      TranslationLanguage('is', 'Íslenska', '🇮🇸'),
      TranslationLanguage('ka', 'ქართული', '🇬🇪'),
      TranslationLanguage('kn', 'ಕನ್ನಡ', '🇮🇳'),
      TranslationLanguage('lt', 'Lietuvių', '🇱🇹'),
      TranslationLanguage('lv', 'Latviešu', '🇱🇻'),
      TranslationLanguage('mk', 'Македонски', '🇲🇰'),
      TranslationLanguage('mr', 'मराठी', '🇮🇳'),
      TranslationLanguage('ms', 'Bahasa Melayu', '🇲🇾'),
      TranslationLanguage('mt', 'Malti', '🇲🇹'),
      TranslationLanguage('no', 'Norsk', '🇳🇴'),
      TranslationLanguage('ro', 'Română', '🇷🇴'),
      TranslationLanguage('sk', 'Slovenčina', '🇸🇰'),
      TranslationLanguage('sl', 'Slovenščina', '🇸🇮'),
      TranslationLanguage('sq', 'Shqip', '🇦🇱'),
      TranslationLanguage('sv', 'Svenska', '🇸🇪'),
      TranslationLanguage('sw', 'Kiswahili', '🇰🇪'),
      TranslationLanguage('ta', 'தமிழ்', '🇮🇳'),
      TranslationLanguage('te', 'తెలుగు', '🇮🇳'),
      TranslationLanguage('th', 'ไทย', '🇹🇭'),
      TranslationLanguage('tl', 'Tagalog', '🇵🇭'),
      TranslationLanguage('ur', 'اردو', '🇵🇰'),
      TranslationLanguage('vi', 'Tiếng Việt', '🇻🇳'),
    ];

/// Все 59 языков: сначала популярные, потом остальные.
const List<TranslationLanguage> kAllTranslationLanguages =
    <TranslationLanguage>[
      ...kPopularTranslationLanguages,
      ...kOtherTranslationLanguages,
    ];

/// Язык по коду или null.
TranslationLanguage? translationLanguageByCode(String code) {
  final c = code.trim().toLowerCase();
  if (c.isEmpty) return null;
  for (final l in kAllTranslationLanguages) {
    if (l.code == c) return l;
  }
  return null;
}

/// Подпись языка «флаг  название»; неизвестный код — как есть.
String translationLanguageLabel(String code) =>
    translationLanguageByCode(code)?.label ?? code;
