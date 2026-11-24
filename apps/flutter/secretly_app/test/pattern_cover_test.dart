// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Живые обложки-узоры профиля (макет «Profile Motion»). `SECRETLY_SHOTS=папка`
// — снимок всех десяти в тёмной и светлой теме.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/profile/pattern_cover.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

Widget _cover(PatternCoverStyle style, Brightness b, PatternCoverInput input,
    {double t = 3}) {
  final bg = b == Brightness.dark
      ? const Color(0xFF151E27)
      : const Color(0xFFF1F4F7);
  return SizedBox(
    width: 195,
    height: 230,
    child: FittedBox(
      child: SizedBox(
        width: 390,
        height: 460,
        child: PatternCoverBackdrop(
          tint: patternCoverTint(const Color(0xFF7C6CF3), b),
          background: bg,
          avatarCenterY: input.avatarCenterY,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: PatternCoverPainter(
                  style: style,
                  input: input,
                  bands: List<double>.filled(
                    6,
                    PatternCoverBands.target(input),
                  ),
                  time: t,
                  ink: patternCoverInk(b),
                  inkStrength: patternCoverInkStrength(b),
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.52),
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('идентификатор обложки ↔ узор', () {
    for (final s in PatternCoverStyle.values) {
      expect(patternCoverStyleFromId(patternCoverId(s)), s);
    }
    expect(patternCoverStyleFromId('space'), isNull);
    expect(patternCoverStyleFromId('pattern_nope'), isNull);
    expect(patternCoverStyleFromId(null), isNull);
  });

  test('полосы: натяжение раздвигает, прокрутка стягивает, внешние отстают',
      () {
    final bands = PatternCoverBands();
    const pulled = PatternCoverInput(pull: 120);
    bands.step(1 / 60, PatternCoverBands.target(pulled));
    // Через кадр ближняя полоса ушла дальше дальней — «запаздывание».
    expect(bands.x[0] - 1, greaterThan(bands.x[5] - 1));
    for (var i = 0; i < 240; i++) {
      bands.step(1 / 60, PatternCoverBands.target(pulled));
    }
    expect(bands.x[0], closeTo(PatternCoverBands.target(pulled), 0.02));
    expect(
      PatternCoverBands.target(const PatternCoverInput(collapse: 1)),
      closeTo(0.2, 1e-9),
    );
    expect(profileRubber(0, 520), 0);
    expect(profileRubber(10000, 520), lessThan(520));
  });

  testWidgets('все десять рисуются в обеих темах (снимок)', (t) async {
    t.view.physicalSize = const Size(1000, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const rest = PatternCoverInput(avatarCenterY: 111, fadeY: 260);
    await t.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: RepaintBoundary(
            key: _shotKey,
            child: Wrap(
              children: [
                for (final b in Brightness.values)
                  for (final s in PatternCoverStyle.values)
                    _cover(s, b, rest),
              ],
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    // Натяжение, прокрутка, раскрытие — без ошибок.
    for (final input in const [
      PatternCoverInput(pull: 200, avatarCenterY: 180, fadeY: 400),
      PatternCoverInput(collapse: 0.7, avatarCenterY: 40, fadeY: 200),
      PatternCoverInput(expanded: 0.5),
    ]) {
      await t.pumpWidget(
        MaterialApp(
          home: Wrap(
            children: [
              for (final s in PatternCoverStyle.values)
                _cover(s, Brightness.dark, input),
            ],
          ),
        ),
      );
      expect(t.takeException(), isNull);
    }
    final dir = _shots;
    if (dir != null && dir.isNotEmpty) {
      await t.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: RepaintBoundary(
              key: _shotKey,
              child: Wrap(
                children: [
                  for (final b in Brightness.values)
                    for (final s in PatternCoverStyle.values)
                      _cover(s, b, rest),
                ],
              ),
            ),
          ),
        ),
      );
      await t.runAsync(() async {
        final rb =
            _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await rb.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/pattern_covers.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
