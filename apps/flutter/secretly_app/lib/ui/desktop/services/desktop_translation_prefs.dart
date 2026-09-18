// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Направление перевода — ТЕ ЖЕ настройки, что на телефоне.
///
/// 🔴 КЛЮЧИ ОБЩИЕ, И ЭТО ГЛАВНОЕ. На телефоне язык перевода выбирают в
/// «Настройки → Язык → Перевод», и выбор лежит в `SharedPreferences`. Та же
/// база настроек синхронизируется вместе с профилем, поэтому окно обязано
/// читать ИМЕННО эти ключи: завести свои значило бы, что человек выставил язык
/// на телефоне, а компьютер переводит на другой — и никакой подсказки, почему.
///
/// 🔴 «Показывать кнопку перевода» окно НЕ читает намеренно. На телефоне это
/// про место: кнопка висит рядом с каждым пузырём и засоряет ленту, поэтому
/// её включают отдельно. В окне перевод живёт пунктом меню по правой кнопке —
/// он не занимает ни точки, пока его не открыли, и прятать его за настройкой
/// значило бы сделать возможность ненаходимой.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:shared_preferences/shared_preferences.dart';

class DesktopTranslationSettings {
  const DesktopTranslationSettings({required this.target, this.source});

  /// На какой язык переводим. Никогда не пустой.
  final String target;

  /// С какого. `null` — определять по самому сообщению.
  final String? source;
}

class DesktopTranslationPrefs {
  DesktopTranslationPrefs._();

  /// Ключи повторяют `SettingsScreen` телефона дословно.
  static const String kSourceKey = 'settings_language_translate_source_v1';
  static const String kTargetKey = 'settings_language_translate_target_v1';

  static Future<DesktopTranslationSettings> load({
    SharedPreferences? prefsForTest,
    String? fallbackTarget,
  }) async {
    String? rawSource;
    String? rawTarget;
    try {
      final prefs = prefsForTest ?? await SharedPreferences.getInstance();
      rawSource = prefs.getString(kSourceKey);
      rawTarget = prefs.getString(kTargetKey);
    } catch (_) {
      // Настройки недоступны — работаем на умолчаниях, а не отказываем.
    }
    return resolve(
      rawSource: rawSource,
      rawTarget: rawTarget,
      fallbackTarget: fallbackTarget,
    );
  }

  /// Разбор отдельно от чтения — его и стоит проверять.
  static DesktopTranslationSettings resolve({
    String? rawSource,
    String? rawTarget,
    String? fallbackTarget,
  }) {
    final source = (rawSource ?? '').trim().toLowerCase();
    final target = (rawTarget ?? '').trim();
    return DesktopTranslationSettings(
      // Пустой целевой язык означает «на язык приложения» — так же, как на
      // телефоне.
      target: target.isNotEmpty
          ? target
          : (fallbackTarget ?? _deviceLanguage()),
      // 'auto' и пустое — одно и то же: определять по сообщению.
      source: (source.isEmpty || source == 'auto') ? null : source,
    );
  }

  static String _deviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode.trim();
    return code.isEmpty ? 'en' : code;
  }
}
