// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Обновление приложения, скачанного с сайта.
///
/// Тонкая сторона Flutter к `Runner/SparkleBridge.swift`: там живёт и сама
/// проверка, и её окна. Здесь — только один вопрос («настроено ли») и одно
/// действие («проверь сейчас»).
///
/// 🔴 ПОКА НЕ НАСТРОЕНО — ПУНКТА МЕНЮ НЕТ. Обновлятору нужны адрес перечня
/// версий и открытый ключ, которым проверяется подпись пакета; пока их не
/// положили в Info.plist, [configured] остаётся `false`, и «Проверить
/// обновления» в меню не появляется. Пункт, который отвечает «не настроено»,
/// — это обещание, которого некому сдержать, а в меню такие обещания читаются
/// как поломка приложения.
class DesktopUpdateService {
  DesktopUpdateService._();

  static final DesktopUpdateService instance = DesktopUpdateService._();

  static const MethodChannel _channel = MethodChannel('secretly/updates');

  /// Есть ли у приложения рабочая проверка обновлений.
  final ValueNotifier<bool> configured = ValueNotifier<bool>(false);

  /// Почему её нет, если её нет. Для раздела «О программе» и для журнала —
  /// молчаливое «не работает» не даёт ни починить, ни объяснить.
  String? lastError;

  bool _loaded = false;

  /// Только macOS: на Windows установщика ещё нет (A-5), и обновлять нечего.
  static bool get supported => !kIsWeb && Platform.isMacOS;

  Future<void> load() async {
    if (_loaded || !supported) return;
    _loaded = true;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('status');
      configured.value = (res?['configured'] as bool?) ?? false;
      lastError = res?['error'] as String?;
    } catch (e) {
      // Моста нет — значит сборка старая или платформа не та. Это не повод
      // мешать запуску: проверка обновлений просто не предлагается.
      configured.value = false;
      lastError = '$e';
    }
  }

  /// Проверить сейчас. Окна показывает Sparkle — и «новых версий нет», и
  /// предложение поставить найденную.
  Future<void> check() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('check');
    } catch (e) {
      lastError = '$e';
    }
  }
}
