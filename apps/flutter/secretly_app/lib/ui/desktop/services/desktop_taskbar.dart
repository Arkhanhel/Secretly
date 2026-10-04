// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../design/typography.dart';

/// Непрочитанные поверх кнопки на панели задач и мигание кнопки — Windows,
/// как у Telegram (29.09.2026).
///
/// macOS показывает число на значке в Dock своим мостом (`DockBadgeBridge`);
/// здесь — то же для Windows. Значок рисуется тут, шрифтом приложения, а
/// раннер (`taskbar_badge.cpp`) ставит готовые пиксели поверх кнопки окна.
abstract final class DesktopTaskbar {
  static const MethodChannel _channel = MethodChannel('secretly/taskbar');

  /// Сторона значка в пикселях: Windows ужимает его до 16 точек сама.
  static const int badgeSide = 32;

  static String? _shown;

  /// Число непрочитанных; 0 — значка нет. [muted] — серый, как у трея.
  static Future<void> setUnread(
    int count, {
    bool muted = false,
    required String description,
  }) async {
    if (!Platform.isWindows) return;
    final key = count <= 0 ? '' : '${badgeLabel(count)}|$muted';
    if (key == _shown) return;
    _shown = key;
    try {
      if (count <= 0) {
        await _channel.invokeMethod<void>('clearBadge');
        return;
      }
      final rgba = await renderBadge(count, muted: muted);
      if (rgba == null) return;
      await _channel.invokeMethod<void>('setBadge', <String, Object?>{
        'rgba': rgba,
        'width': badgeSide,
        'height': badgeSide,
        'description': description,
      });
    } catch (_) {
      // Значок — удобство: без него приложение работает как раньше.
      _shown = null;
    }
  }

  /// Мигнуть кнопкой окна: пришло сообщение, а окно не впереди.
  static Future<void> flash() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('flash');
    } catch (_) {}
  }

  /// «99+» — дальше считать глазами бессмысленно, как у трея и списка.
  static String badgeLabel(int count) => count > 99 ? '99+' : '$count';

  /// Красный кружок с белым числом (серый — «без звука»), RGBA без
  /// домножения на прозрачность — такой ждёт значок Windows.
  static Future<Uint8List?> renderBadge(int count, {bool muted = false}) async {
    final side = badgeSide.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..isAntiAlias = true
      ..color = muted ? const Color(0xFF8E8E93) : const Color(0xFFFF3B30);
    canvas.drawCircle(ui.Offset(side / 2, side / 2), side / 2, paint);
    final label = badgeLabel(count);
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: DType.family,
          fontWeight: FontWeight.w800,
          fontSize: label.length >= 3 ? 12 : (label.length == 2 ? 16 : 19),
          color: const Color(0xFFFFFFFF),
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      ui.Offset((side - painter.width) / 2, (side - painter.height) / 2),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(badgeSide, badgeSide);
    picture.dispose();
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  static void debugReset() => _shown = null;
}
