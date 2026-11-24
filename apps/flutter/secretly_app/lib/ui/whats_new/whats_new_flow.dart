// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «Встречайте Secretly 1.9»: приветствие, мини-демо и пометки пером
/// (макет «Whats New 1.9», 24.11.2026).
///
/// Показ — один раз на человека: после обновления — при первом открытии
/// главного экрана, новому человеку — когда главный экран уже виден. Потом
/// «Что нового» открывается из настроек. Пометки пером появляются на своих
/// экранах, даже если человек нажал «Позже».
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'whats_new_sheet.dart';

/// Выключатель всего сценария: `false` — ни окна, ни пометок.
const bool kWhatsNew19 = true;

/// Пометки пером на экранах.
const bool kPenMarks = true;

const String _kSeenKey = 'whats_new_19_seen_v1';

/// Общее состояние сценария на время работы приложения.
abstract final class WhatsNew19 {
  /// Включается только настоящим запуском приложения (`main`): в тестах
  /// окно и пометки не всплывают поверх проверяемых экранов.
  static bool enabledForThisRun = false;

  /// Окно приветствия на экране — пометки ждут, пока его закроют.
  static final ValueNotifier<bool> sheetOpen = ValueNotifier<bool>(false);

  /// Окно в этой сессии уже было (или его видели раньше) — можно
  /// показывать пометки пером.
  static final ValueNotifier<bool> tourSettled = ValueNotifier<bool>(false);

  /// Только телефоны: на компьютере свой сценарий (не в этом выпуске).
  static bool get active =>
      kWhatsNew19 &&
      enabledForThisRun &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Граница главного экрана: с неё снимается подложка окна.
  static final GlobalKey captureKey = GlobalKey(debugLabel: 'whats_new_capture');
}

/// Показывает приветствие, если человек его ещё не видел. Возвращает
/// `true`, если окно было показано.
Future<bool> maybeShowWhatsNew19(BuildContext context) async {
  if (!WhatsNew19.active) return false;
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return false;
  }
  if (prefs.getBool(_kSeenKey) == true) {
    WhatsNew19.tourSettled.value = true;
    return false;
  }
  if (!context.mounted) return false;
  // Отмечается сразу: окно не должно всплыть второй раз, даже если
  // приложение закроют, пока оно открыто.
  await prefs.setBool(_kSeenKey, true);
  if (!context.mounted) return false;
  await showWhatsNew19(context);
  return true;
}

/// Открывает окно (из настроек — сразу на мини-демо).
Future<void> showWhatsNew19(
  BuildContext context, {
  bool startWithDemo = false,
}) async {
  if (WhatsNew19.sheetOpen.value) return;
  final backdrop = await _captureBackdrop(context);
  if (!context.mounted) {
    backdrop?.dispose();
    return;
  }
  WhatsNew19.sheetOpen.value = true;
  try {
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => WhatsNewSheet(
          backdrop: backdrop,
          startWithDemo: startWithDemo,
        ),
      ),
    );
  } finally {
    backdrop?.dispose();
    WhatsNew19.sheetOpen.value = false;
    WhatsNew19.tourSettled.value = true;
  }
}

/// Подложка — снимок главного экрана, размытый ОДИН раз (σ 20), а не
/// `BackdropFilter` в каждом кадре (спецификация, раздел G). Не вышло —
/// `null`, окно ляжет на простое затемнение.
Future<ui.Image?> _captureBackdrop(BuildContext context) async {
  final background = Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 1);
  try {
    final boundary = WhatsNew19.captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
      debugPrint('whats_new: no capture boundary (${boundary.runtimeType})');
      return null;
    }
    const scale = 0.5;
    // Сразу после кадра: на главном экране всё время что-то живёт (рамки,
    // стекло), и посреди кадра граница «грязная» — снимок не снять.
    await WidgetsBinding.instance.endOfFrame;
    if (boundary.debugNeedsPaint) await WidgetsBinding.instance.endOfFrame;
    final shot = await boundary.toImage(pixelRatio: scale);
    final w = shot.width, h = shot.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Фон страницы рисуется выше этой границы — без него снимок
    // прозрачный, и сквозь размытие видно живой экран.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = background,
    );
    canvas.drawImage(
      shot,
      Offset.zero,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: 20 * scale,
          sigmaY: 20 * scale,
          tileMode: TileMode.clamp,
        ),
    );
    final baked = await recorder.endRecording().toImage(w, h);
    shot.dispose();
    return baked;
  } catch (e) {
    debugPrint('whats_new: backdrop capture failed: $e');
    return null;
  }
}
