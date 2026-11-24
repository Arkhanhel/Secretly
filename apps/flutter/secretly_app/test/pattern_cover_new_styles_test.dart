// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Вторая волна обложек-узоров (макет «Profile Motion», 22.11.2026):
// светлячки, буква S, газировка, бургеры, самолётики, шарики, кофе, пончики,
// мороженое, попкорн, масти. `SECRETLY_SHOTS=папка` — снимки в тёмной и
// светлой теме (покой, натяжение, прокрутка) с настоящего кода.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/cosmetic_catalog.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:secretly_app/ui/profile/pattern_cover.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];

const List<PatternCoverStyle> _newStyles = [
  PatternCoverStyle.fireflies,
  PatternCoverStyle.smark,
  PatternCoverStyle.soda,
  PatternCoverStyle.burgers,
  PatternCoverStyle.planes,
  PatternCoverStyle.balloons,
  PatternCoverStyle.coffee,
  PatternCoverStyle.donuts,
  PatternCoverStyle.icecream,
  PatternCoverStyle.popcorn,
  PatternCoverStyle.suits,
];

Color _page(Brightness b) =>
    b == Brightness.dark ? const Color(0xFF151E27) : const Color(0xFFF1F4F7);

/// Обложка 390×460, как на экране профиля: подложка, узор, аватар.
Widget _cover(
  PatternCoverStyle style,
  Brightness b,
  PatternCoverInput input, {
  double t = 6,
}) {
  return SizedBox(
    width: 390,
    height: 460,
    child: PatternCoverBackdrop(
      tint: patternCoverTint(const Color(0xFF7C6CF3), b),
      background: _page(b),
      avatarCenterY: input.avatarCenterY,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: PatternCoverPainter(
              style: style,
              input: input,
              bands: List<double>.filled(6, PatternCoverBands.target(input)),
              time: t,
              ink: patternCoverInk(b),
              inkStrength: patternCoverInkStrength(b),
            ),
          ),
          if (input.expanded < 0.5)
            Positioned(
              left: 195 - 56,
              top: input.avatarCenterY - 56,
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
  );
}

const List<PatternCoverInput> _inputs = [
  PatternCoverInput(avatarCenterY: 111, fadeY: 260),
  PatternCoverInput(pull: 90, avatarCenterY: 142, fadeY: 345),
  PatternCoverInput(pull: 200, avatarCenterY: 180, fadeY: 450),
  PatternCoverInput(collapse: 0.5, avatarCenterY: 60, fadeY: 200),
  PatternCoverInput(collapse: 1, avatarCenterY: 20, fadeY: 120),
  PatternCoverInput(expanded: 0.4, avatarCenterY: 150, fadeY: 400),
  PatternCoverInput(expanded: 1),
];

void main() {
  test('новые узоры дописаны в конец перечисления, id ↔ узор', () {
    final names = PatternCoverStyle.values.map((s) => s.name).toList();
    // Прежние одиннадцать — на своих местах.
    expect(names.sublist(0, 11), [
      'orbits',
      'monogram',
      'bubbles',
      'constellation',
      'ripples',
      'rays',
      'halftone',
      'spiral',
      'rain',
      'honeycomb',
      'fingerprint',
    ]);
    // Третья волна (23.11.2026) дописана после второй.
    expect(PatternCoverStyle.values.sublist(11, 22), _newStyles);
    for (final s in PatternCoverStyle.values) {
      final id = patternCoverId(s);
      expect(patternCoverStyleFromId(id), s, reason: id);
      expect(patternCoverStyleFromId(' $id '), s, reason: id);
      expect(RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(id), isTrue, reason: id);
    }
    expect(patternCoverStyleFromId('pattern_unknown'), isNull);
  });

  test('каталог: все новые есть, бесплатные, с именами', () {
    final ids = kPatternProfileCovers.map((c) => c.id).toSet();
    for (final s in _newStyles) {
      final id = patternCoverId(s);
      expect(ids, contains(id));
      expect(coverById(id), isNotNull, reason: id);
      expect(kFreeProfileCoverIds, contains(id), reason: id);
      final c = coverById(id)!;
      expect(c.nameRu.trim(), isNotEmpty);
      expect(c.nameEn.trim(), isNotEmpty);
    }
    expect(kPatternProfileCovers.first.id, 'pattern_fingerprint');
    // Третья серия (команда и Новый год, 23.11.2026) — в своих списках.
    expect(
      kPatternProfileCovers,
      hasLength(
        PatternCoverStyle.values.length -
            kStaffPatternCoverStyles.length -
            kNewYearPatternCoverStyles.length,
      ),
    );
  });

  testWidgets('каждый новый узор рисуется в обеих темах при любом движении', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 460);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final style in _newStyles) {
      for (final b in Brightness.values) {
        for (final input in _inputs) {
          // Несколько моментов времени: самолётики шагают, пузырьки и шарики
          // уходят на новый круг.
          for (final time in const [0.0, 0.016, 3.0, 40.0, 400.0]) {
            await t.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: _cover(style, b, input, t: time),
              ),
            );
            expect(t.takeException(), isNull, reason: '$style/$b/$time');
          }
        }
      }
    }
  });

  testWidgets('снимки (SECRETLY_SHOTS)', (t) async {
    final dir = _shots;
    if (dir == null || dir.isEmpty) return;
    t.view.physicalSize = const Size(390 * 3, 460 * 2);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    for (final style in _newStyles) {
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final b in Brightness.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final input in const [
                        PatternCoverInput(avatarCenterY: 111, fadeY: 260),
                        PatternCoverInput(
                          pull: 120,
                          avatarCenterY: 153,
                          fadeY: 374,
                        ),
                        PatternCoverInput(
                          collapse: 0.4,
                          avatarCenterY: 80,
                          fadeY: 220,
                        ),
                      ])
                        _cover(style, b, input),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
      await t.runAsync(() async {
        final rb =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await rb.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$dir/pattern_${style.name}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
