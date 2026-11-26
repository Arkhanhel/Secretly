// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Меню «Secretly»: «Поддержать» с бьющимся сердцем (25.11.2026).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/heart_beat_icon.dart';

void main() {
  testWidgets('сердце бьётся; «уменьшить движение» — стоит', (t) async {
    Widget host(bool still) => MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: const Center(child: HeartBeatIcon(size: 20)),
    );
    await t.pumpWidget(host(false));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpWidget(host(true));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    await t.pumpWidget(const SizedBox());
  });

  test('🔴 на iPhone входа нет (App Review 3.1.1) — и в меню, и в настройках '
      'один ответ', () {
    final settings = File('lib/ui/settings_screen.dart').readAsStringSync();
    final chats = File('lib/ui/chats_screen.dart').readAsStringSync();
    expect(settings, contains('bool get donateEntryAvailable => !Platform.isIOS;'));
    expect(settings, contains('if (donateEntryAvailable)'));
    expect(chats, contains('if (donateEntryAvailable)'));
  });

  test('контур не пустой и внутри своего квадрата', () async {
    final b = HeartBeatPainter.heart(const Size.square(20)).getBounds();
    expect(b.width, greaterThan(16));
    expect(const Rect.fromLTWH(0, 0, 20, 20).contains(b.center), isTrue);
    final out = Platform.environment['HEART_PNG'];
    if (out == null) return;
    final r = ui.PictureRecorder();
    final c = Canvas(r)..drawColor(const Color(0xFF26262A), BlendMode.src);
    c.scale(8);
    for (var i = 0; i < 6; i++) {
      c.save();
      c.translate(8 + i * 34.0, 8);
      c.drawCircle(const Offset(10, 10), 17, Paint()..color = const Color(0x55202633));
      HeartBeatPainter(AlwaysStoppedAnimation(const [0.0, 0.08, 0.12, 0.22, 0.34, 0.6][i]))
          .paint(c, const Size.square(20));
      c.restore();
    }
    final img = await r.endRecording().toImage(1680, 288);
    final d = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(d!.buffer.asUint8List());
  });
}
