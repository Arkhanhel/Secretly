// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Недавние эмодзи и выбранные тона кожи панели — на устройстве, отдельно для
/// каждого профиля (как недавние эмодзи ПК, `DesktopEmojiRecents`).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract final class EmojiPanelPrefs {
  static const int maxRecents = 32;

  static String _recentsKey(String profile) =>
      'mobile_emoji_panel_recents_v1:$profile';
  static String _tonesKey(String profile) =>
      'mobile_emoji_panel_tones_v1:$profile';

  /// Уже открытые настройки — чтобы панель показала недавние и тона сразу, в
  /// первом кадре, а не «моргнула» ими во втором (24.11.2026).
  static SharedPreferences? _opened;

  static Future<void> warmUp() async {
    try {
      _opened = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static List<String>? recentsNow(String profile) =>
      _opened?.getStringList(_recentsKey(profile));

  static Map<String, String>? tonesNow(String profile) {
    final p = _opened;
    return p == null ? null : _parseTones(p.getString(_tonesKey(profile)));
  }

  static Map<String, String> _parseTones(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return <String, String>{
        for (final e in decoded.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  static Future<List<String>> loadRecents(String profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentsKey(profile)) ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<void> saveRecents(String profile, List<String> recents) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _recentsKey(profile),
        recents.take(maxRecents).toList(growable: false),
      );
    } catch (_) {}
  }

  /// Основа эмодзи → выбранный вариант тона.
  static Future<Map<String, String>> loadTones(String profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _parseTones(prefs.getString(_tonesKey(profile)));
    } catch (_) {
      return <String, String>{};
    }
  }

  static Future<void> saveTones(String profile, Map<String, String> tones) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tonesKey(profile), jsonEncode(tones));
    } catch (_) {}
  }

  /// Новые недавние: [picked] (свежие первыми) поверх [current], без
  /// повторов.
  static List<String> merge(List<String> picked, List<String> current) {
    final out = <String>[];
    final seen = <String>{};
    for (final e in [...picked, ...current]) {
      if (seen.add(e)) out.add(e);
      if (out.length >= maxRecents) break;
    }
    return out;
  }
}
