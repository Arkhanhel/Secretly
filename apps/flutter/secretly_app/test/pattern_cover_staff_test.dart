// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Третья волна обложек-узоров (макет «Covers», 23.11.2026): десять для
// сотрудников и десять новогодних. Рисуются без ошибок в обеих темах при
// натяжении, прокрутке и раскрытии; ничего не рисуют, когда фото раскрыто;
// укладываются в бюджет вызовов и времени. `SECRETLY_SHOTS=папка` — снимки
// (покой, натяжение, прокрутка) с настоящего кода.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/profile/pattern_cover.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];

const List<PatternCoverStyle> _staff = [
  PatternCoverStyle.champagne,
  PatternCoverStyle.gems,
  PatternCoverStyle.perfume,
  PatternCoverStyle.macarons,
  PatternCoverStyle.watches,
  PatternCoverStyle.movement,
  PatternCoverStyle.armillary,
  PatternCoverStyle.cards,
  PatternCoverStyle.gifts,
];

const List<PatternCoverStyle> _newYear = [
  PatternCoverStyle.ornaments,
  PatternCoverStyle.snowflakes,
  PatternCoverStyle.snowman,
  PatternCoverStyle.tangerines,
  PatternCoverStyle.gingerbread,
  PatternCoverStyle.sparkler,
  PatternCoverStyle.bells,
  PatternCoverStyle.cocoa,
  PatternCoverStyle.tree,
  PatternCoverStyle.snowglobe,
];

const List<PatternCoverStyle> _all = [..._staff, ..._newYear];

const List<PatternCoverInput> _inputs = [
  PatternCoverInput(avatarCenterY: 111, fadeY: 260),
  PatternCoverInput(pull: 90, avatarCenterY: 142, fadeY: 345),
  PatternCoverInput(pull: 200, avatarCenterY: 180, fadeY: 450),
  PatternCoverInput(collapse: 0.5, avatarCenterY: 60, fadeY: 200),
  PatternCoverInput(expanded: 0.4, avatarCenterY: 150, fadeY: 400),
];

const List<double> _times = [0, 0.016, 3.3, 40, 400];

/// Холст-счётчик: сколько вызовов рисования за кадр.
class _CountCanvas implements Canvas {
  int draws = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName.toString().contains('draw')) draws++;
    return null;
  }
}

PatternCoverPainter _painter(
  PatternCoverStyle style,
  Brightness b,
  PatternCoverInput input,
  double t, [
  List<double>? bands,
]) => PatternCoverPainter(
  style: style,
  input: input,
  bands: bands ?? List<double>.filled(6, PatternCoverBands.target(input)),
  time: t,
  ink: patternCoverInk(b),
  inkStrength: patternCoverInkStrength(b),
);

int _countDraws(PatternCoverPainter p) {
  final c = _CountCanvas();
  p.paint(c, const Size(390, 460));
  return c.draws;
}

Color _page(Brightness b) =>
    b == Brightness.dark ? const Color(0xFF151E27) : const Color(0xFFF1F4F7);

/// Обложка 390×460 как на экране: свой фон, узор, аватар.
Widget _cover(PatternCoverStyle style, Brightness b, PatternCoverInput input) {
  return SizedBox(
    width: 390,
    height: 460,
    child: PatternCoverBackdrop(
      tint: patternCoverOwnTint(style, b)!,
      ownTint: true,
      background: _page(b),
      avatarCenterY: input.avatarCenterY,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _painter(style, b, input, 6.3)),
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

void main() {
  test('дописаны в конец перечисления, прежние на местах, id ↔ узор', () {
    final names = PatternCoverStyle.values.map((s) => s.name).toList();
    expect(names.sublist(0, 22), [
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
      'fireflies',
      'smark',
      'soda',
      'burgers',
      'planes',
      'balloons',
      'coffee',
      'donuts',
      'icecream',
      'popcorn',
      'suits',
    ]);
    expect(PatternCoverStyle.values.sublist(22), _all);
    for (final s in _all) {
      final id = patternCoverId(s);
      expect(patternCoverStyleFromId(id), s, reason: id);
      expect(RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(id), isTrue, reason: id);
    }
  });

  test('наборы для каталога: по десять, в порядке макета, не пересекаются', () {
    expect(kStaffPatternCoverStyles.toList(), _staff);
    expect(kNewYearPatternCoverStyles.toList(), _newYear);
    expect(
      kStaffPatternCoverStyles.intersection(kNewYearPatternCoverStyles),
      isEmpty,
    );
  });

  test('свой фон: у новых — из макета, у прежних — нет (как было)', () {
    for (final s in PatternCoverStyle.values) {
      for (final b in Brightness.values) {
        final own = patternCoverOwnTint(s, b);
        if (_all.contains(s)) {
          expect(own, isNotNull, reason: '$s/$b');
        } else {
          expect(own, isNull, reason: '$s/$b');
        }
      }
    }
    expect(
      patternCoverOwnTint(PatternCoverStyle.champagne, Brightness.dark),
      const Color(0xFF1D2C29),
    );
    expect(
      patternCoverOwnTint(PatternCoverStyle.snowglobe, Brightness.light),
      const Color(0xFFE3E8F2),
    );
  });

  test(
    'каждый рисуется в обеих темах при любом движении; раскрыто — пусто',
    () {
      for (final s in _all) {
        for (final b in Brightness.values) {
          for (final input in _inputs) {
            for (final t in _times) {
              // Настоящий холст: без исключений.
              final rec = ui.PictureRecorder();
              _painter(s, b, input, t).paint(Canvas(rec), const Size(390, 460));
              rec.endRecording().dispose();
            }
            expect(
              _countDraws(_painter(s, b, input, 6.3)),
              greaterThan(0),
              reason: '$s/$b/${input.pull}/${input.collapse}',
            );
          }
          // Пружины в движении: полосы разные (натяжение, внешние отстают).
          expect(
            () => _countDraws(
              _painter(
                s,
                b,
                const PatternCoverInput(pull: 150, avatarCenterY: 160),
                2,
                const [1.6, 1.5, 1.35, 1.2, 1.1, 1.02],
              ),
            ),
            returnsNormally,
          );
          expect(
            _countDraws(
              _painter(s, b, const PatternCoverInput(expanded: 1), 3),
            ),
            0,
            reason: '$s/$b раскрыто',
          );
          expect(
            _countDraws(
              _painter(s, b, const PatternCoverInput(collapse: 1), 3),
            ),
            0,
            reason: '$s/$b прокручено',
          );
        }
      }
    },
  );

  test('бюджет вызовов рисования за кадр', () {
    // Сторож от разрастания: самая тяжёлая обложка (ёлочки) — ~770 вызовов
    // (23.11.2026), лёгкие линии механизма — ~85.
    for (final s in _all) {
      var most = 0;
      for (final b in Brightness.values) {
        for (final t in const [0.5, 2.0, 5.5]) {
          final n = _countDraws(
            _painter(s, b, const PatternCoverInput(avatarCenterY: 111), t),
          );
          if (n > most) most = n;
        }
      }
      expect(most, lessThan(950), reason: '$s: $most вызовов за кадр');
    }
  });

  test('60 кадров самой тяжёлой обложки — в пределах бюджета', () {
    // Прогрев (статичные контуры строятся один раз).
    for (final s in _all) {
      final rec = ui.PictureRecorder();
      _painter(
        s,
        Brightness.dark,
        const PatternCoverInput(),
        0,
      ).paint(Canvas(rec), const Size(390, 460));
      rec.endRecording().dispose();
    }
    var worst = 0;
    PatternCoverStyle? worstStyle;
    for (final s in _all) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        final rec = ui.PictureRecorder();
        _painter(
          s,
          Brightness.dark,
          const PatternCoverInput(),
          i / 60,
        ).paint(Canvas(rec), const Size(390, 460));
        rec.endRecording().dispose();
      }
      sw.stop();
      if (sw.elapsedMicroseconds > worst) {
        worst = sw.elapsedMicroseconds;
        worstStyle = s;
      }
    }
    // Щедрый бюджет для отладочной VM: сейчас худшая ~0,6 мс на кадр
    // (≈ 40 мс на 60 кадров); на устройстве (AOT) в разы быстрее.
    expect(worst, lessThan(800000), reason: '$worstStyle: $worst мкс');
  });

  testWidgets('свой фон: подложка рисуется; прежняя — без изменений', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 460);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final own in const [true, false]) {
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PatternCoverBackdrop(
            tint: const Color(0xFF1D2C29),
            ownTint: own,
            background: const Color(0xFF151E27),
            avatarCenterY: 111,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('снимки (SECRETLY_SHOTS)', (t) async {
    final dir = _shots;
    if (dir == null || dir.isEmpty) return;
    t.view.physicalSize = const Size(390 * 3, 460 * 2);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    for (final style in _all) {
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
          '$dir/staff_${style.name}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
