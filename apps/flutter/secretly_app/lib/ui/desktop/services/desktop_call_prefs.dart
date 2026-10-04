// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// НАСТРОЙКИ ЗВОНКОВ ПК, У КОТОРЫХ НЕТ ПАРЫ НА ТЕЛЕФОНЕ (30.09.2026):
/// зеркалить ли своё видео и громкость мелодии входящего.
///
/// Отдельно от `DesktopUiPrefs`, и не ради порядка: тот файл одновременно
/// правят несколько работ, а эти настройки касаются только звонков.
/// Ключи свои, `desktop_…`: на телефон они не едут — камера у стола и
/// камера в кармане разные, и громкость ПК не должна менять телефон.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class DesktopCallPrefs {
  static const String _kMirrorSelf = 'desktop_call_mirror_self_v1';
  static const String _kRingtoneVolume = 'desktop_call_ringtone_volume_v1';

  /// Своё видео — зеркально, как в зеркале. По умолчанию да: так показывают
  /// себя почти все программы звонков, и именно так человек привык видеть
  /// своё лицо. Касается ТОЛЬКО своего экрана: собеседник видит как есть.
  static final ValueNotifier<bool> mirrorSelfView = ValueNotifier<bool>(true);

  /// Громкость мелодии входящего звонка, 0…1. По умолчанию полная — как
  /// было до настройки. Ноль — без звука: о звонке скажет только окно.
  static final ValueNotifier<double> ringtoneVolume = ValueNotifier<double>(
    1.0,
  );

  /// Шаг громкости — 5 %: мельче ухо не различает, а круглые числа проще
  /// запомнить.
  static const int ringtoneVolumeSteps = 20;

  static double normalizeVolume(double? raw) {
    if (raw == null || !raw.isFinite) return 1.0;
    final clamped = raw.clamp(0.0, 1.0);
    return (clamped * ringtoneVolumeSteps).round() / ringtoneVolumeSteps;
  }

  static bool _loaded = false;

  /// Прочитать сохранённое. Повторный вызов ничего не делает.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      mirrorSelfView.value = prefs.getBool(_kMirrorSelf) ?? true;
      ringtoneVolume.value = normalizeVolume(prefs.getDouble(_kRingtoneVolume));
    } catch (_) {
      // Умолчания уже стоят — сбой настроек не должен мешать запуску.
    }
  }

  static Future<void> setMirrorSelfView(bool value) async {
    mirrorSelfView.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMirrorSelf, value);
    } catch (_) {
      // Уже применено в памяти; не переживёт перезапуск — и только.
    }
  }

  static Future<void> setRingtoneVolume(double value) async {
    final v = normalizeVolume(value);
    ringtoneVolume.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kRingtoneVolume, v);
    } catch (_) {
      // Уже применено в памяти; не переживёт перезапуск — и только.
    }
  }

  @visibleForTesting
  static void resetForTest() {
    mirrorSelfView.value = true;
    ringtoneVolume.value = 1.0;
    _loaded = false;
  }
}
