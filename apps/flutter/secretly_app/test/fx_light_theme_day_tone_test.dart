// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Светлая тема: рамки, обложки, фоны страниц (дизайн 24.11.2026).
// «Дневной тон» включается только на время рисования в светлой теме;
// ночные обложки остаются тёмными и уходят в страницу коротким переходом.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/live_covers.dart';
import 'package:secretly_app/ui/premium/live_frames.dart';
import 'package:secretly_app/ui/premium/profile_fx.dart';

/// Сколько непрозрачных точек кадра заметно окрашены (размах каналов > 40).
Future<int> _coloredPixels(LiveFramePainter p) async {
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec), const Size(200, 200));
  final img = await rec.endRecording().toImage(200, 200);
  final px = (await img.toByteData())!.buffer.asUint8List();
  img.dispose();
  var n = 0;
  for (var i = 0; i < px.length; i += 4) {
    if (px[i + 3] < 40) continue;
    final r = px[i], g = px[i + 1], b = px[i + 2];
    final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
    if (mx - mn > 40) n++;
  }
  return n;
}

void main() {
  test('🔴 дневной тон: только внутри рисования, вложение и сбой безопасны', () {
    expect(kFxDayTone, isTrue);
    expect(fxDayActive, isFalse);
    paintFxDay(true, () {
      expect(fxDayActive, isTrue);
      paintFxDay(false, () => expect(fxDayActive, isFalse));
      expect(fxDayActive, isTrue);
    });
    expect(fxDayActive, isFalse);
    expect(
      () => paintFxDay(true, () => throw StateError('x')),
      throwsStateError,
    );
    expect(fxDayActive, isFalse);
  });

  test('слой насыщенности сохраняет серые (сумма строки матрицы = 1)', () {
    const s = kFxDaySaturation, lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final r = (1 - s) * lr, g = (1 - s) * lg, b = (1 - s) * lb;
    expect(r + s + g + b, closeTo(1, 1e-9));
    expect(fxDayLayerPaint.colorFilter, isNotNull);
  });

  test('13 ночных сцен; живые обложки узнаются по id', () {
    expect(ProfileCoverStyle.values.where((s) => s.isNightScene).length, 13);
    expect(coverIsNightScene('space'), isTrue);
    expect(coverIsNightScene('storm'), isTrue);
    expect(coverIsNightScene('snow'), isFalse);
    expect(coverIsNightScene(null), isFalse);
    expect(coverIsNightScene('no_such_cover'), isFalse);
  });

  test('переход обложки: ночная в светлой теме — 24 pt, иначе как было', () {
    expect(coverBottomFadeHeight(Brightness.light, 'space'), 24);
    expect(coverBottomFadeHeight(Brightness.dark, 'space'), 56);
    expect(coverBottomFadeHeight(Brightness.light, 'snow'), 56);
    expect(coverBottomFadeHeight(Brightness.light, null), 56);
  });

  testWidgets('рамка в светлой теме рисует цветное свечение', (t) async {
    await t.runAsync(() async {
      debugSeedProfileFxRandom(2411);
      final sim = createOwnFrameSim('aurora')!..settle();
      const light = FramePalette(false, Colors.white);
      expect(
        await _coloredPixels(LiveFramePainter(sim: sim, palette: light)),
        greaterThan(500),
      );
      expect(fxDayActive, isFalse);
      sim.dispose();
    });
  });

  test('🔴 подключено: рамки, обложки и профиль идут через дневной тон', () {
    String r(String p) => File(p).readAsStringSync();
    expect(r('lib/ui/premium/live_frames.dart'), contains('paintFxDay(true'));
    expect(
      r('lib/ui/premium/profile_fx/frames/avatar_frame.dart'),
      contains('paintFxDay(day'),
    );
    expect(
      r('lib/ui/premium/profile_fx/covers/profile_cover.dart'),
      contains('!widget.style.isNightScene'),
    );
    expect(
      r('lib/ui/profile_screen.dart'),
      contains('coverId: defaultCover && kSPrintDefaultCover'),
    );
    final contact = r('lib/ui/contact_details_screen.dart');
    expect(contact, contains('coverId: vm.coverId'));
    // Над тёмной обложкой собеседника часы и значки — светлые.
    expect(contact, contains('systemOverlayStyle: _coverLightStatusBar'));
    expect(contact, contains('_coverLightStatusBar = liveCoverText;'));
    // 🔴 Белое имя — только на ночной сцене: на дневной обложке в светлой
    // теме (сакура, снег) белое имя пропадало.
    expect(contact, contains('(coverIsNightScene(vm.coverId) ||'));
    expect(
      r('lib/ui/profile_screen.dart'),
      contains('return coverIsNightScene(c.myCoverId) ||'),
    );
    // 🔴 Значок «Копировать» у ID — цвет самой кнопки (был чёрным на синей
    // кнопке в светлой теме), как «Поделиться» рядом.
    final own = r('lib/ui/profile_screen.dart');
    expect(own, contains('final ink = IconTheme.of(btn).color;'));
    expect(own, isNot(contains('.onSecondaryContainer,\n                                        BlendMode.srcIn')));
    // 🔴 Страница «Рамки и обложки» в светлой теме светлая (владелец,
    // 24.11.2026): тёмная витрина только в тёмной теме, без пыли на свету.
    final picker = r('lib/ui/profile_cosmetics_screen.dart');
    expect(picker, contains('if (_cxLight(context)) {\n      return StreamBuilder'));
    expect(picker, contains('if (!_cxLight(context)) ...const ['));
    expect(picker, contains('_cxLight(context) ? Colors.white : const Color(0xFF15171E)'));
  });
}
