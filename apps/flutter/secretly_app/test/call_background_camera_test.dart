// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 iPhone: КАМЕРА ПРИ СВЁРНУТОМ ВИДЕОЗВОНКЕ (13.11.2026, Т10).
//
// Свернул видеозвонок на iPhone — iOS отключает приложению камеру, и у
// собеседника застывал последний кадр. Теперь при уходе в фон видеодорожка
// выключается (как кнопкой «камера»), при возврате — включается, если её
// выключили именно мы. Выключенная человеком камера не включается сама.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final calls = File('lib/calls/call_manager.dart').readAsStringSync();
  final screen = File('lib/ui/active_call_screen.dart').readAsStringSync();

  String body(String src, String signature) {
    final at = src.indexOf(signature);
    expect(at, greaterThan(0), reason: signature);
    return src.substring(at, src.indexOf('\n  }\n', at));
  }

  test('уход в фон: только iOS, только живой видеозвонок с включённой камерой', () {
    final b = body(calls, 'Future<void> onAppBackgroundedDuringCall()');
    expect(b.contains('defaultTargetPlatform != TargetPlatform.iOS'), isTrue);
    expect(b.contains('s.isCameraOff'), isTrue);
    expect(b.contains('setVideoEnabled(false)'), isTrue);
    expect(b.contains('_cameraPausedForBackground = true'), isTrue);
  });

  test('возврат: включает только то, что выключили мы', () {
    final b = body(calls, 'Future<void> onAppResumedDuringCall()');
    expect(b.contains('if (!_cameraPausedForBackground) return;'), isTrue);
    expect(b.contains('s.isCameraOff'), isTrue);
    expect(b.contains('setVideoEnabled(true)'), isTrue);
  });

  test('экран звонка зовёт оба шага на нужных состояниях', () {
    final b = body(screen, 'void didChangeAppLifecycleState(AppLifecycleState state)');
    expect(b.contains('AppLifecycleState.resumed'), isTrue);
    expect(b.contains('onAppResumedDuringCall()'), isTrue);
    expect(b.contains('state == AppLifecycleState.paused'), isTrue);
    expect(b.contains('onAppBackgroundedDuringCall()'), isTrue);
  });

  test('🔴 окно PiP из Flutter просится только на iPhone (Android входит сам)', () {
    final b = body(screen, 'void didChangeAppLifecycleState(AppLifecycleState state)');
    final at = b.indexOf('NativePictureInPicture.enter()');
    expect(at, greaterThan(0));
    final before = b.substring(0, at);
    expect(before.lastIndexOf('if (Platform.isIOS)'), greaterThan(0),
        reason: 'на Android просьба на inactive сворачивает развёрнутое окно');
  });
}
