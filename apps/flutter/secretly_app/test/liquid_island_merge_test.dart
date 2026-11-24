// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Островки под шапкой сливаются в одну пластину «жидко» (23.11.2026).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/frosted_header_island.dart';

LiquidIslandRow _row(String id) => LiquidIslandRow(
  id: id,
  height: 38,
  child: Text(id, key: ValueKey('t-$id')),
);

Widget _host(List<String> ids, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Align(
      alignment: Alignment.topCenter,
      child: LiquidIslandRows(
        rows: [for (final id in ids) _row(id)],
        seamColor: Colors.white24,
      ),
    ),
  ),
);

double _h(WidgetTester t) => t.getSize(find.byType(LiquidIslandRows)).height;

void main() {
  testWidgets('строка вытекает и втягивается, пластина растёт и сжимается', (
    t,
  ) async {
    await t.pumpWidget(_host(['pinned']));
    expect(_h(t), 38);

    await t.pumpWidget(_host(['pinned', 'call']));
    await t.pump(const Duration(milliseconds: 60));
    final mid = _h(t);
    expect(mid, greaterThan(38));
    expect(mid, lessThan(38 + 0.5 + 38));
    await t.pumpAndSettle();
    expect(_h(t), 38 + 0.5 + 38);

    // Ушедшая строка втягивается, а не пропадает сразу.
    await t.pumpWidget(_host(['call']));
    await t.pump(const Duration(milliseconds: 60));
    expect(find.byKey(const ValueKey('t-pinned')), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('t-pinned')), findsNothing);
    expect(_h(t), 38);
  });

  testWidgets('порядок держит вызывающий: новая — на своё место', (t) async {
    await t.pumpWidget(_host(['pinned', 'room_call']));
    await t.pumpWidget(_host(['pinned', 'player', 'room_call']));
    await t.pumpAndSettle();
    final y = {
      for (final id in ['pinned', 'player', 'room_call'])
        id: t.getTopLeft(find.byKey(ValueKey('t-$id'))).dy,
    };
    expect(y['pinned']!, lessThan(y['player']!));
    expect(y['player']!, lessThan(y['room_call']!));
  });

  testWidgets('строка вернулась, пока уходила, — остаётся', (t) async {
    await t.pumpWidget(_host(['a', 'b']));
    await t.pumpWidget(_host(['a']));
    await t.pump(const Duration(milliseconds: 40));
    await t.pumpWidget(_host(['a', 'b']));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('t-b')), findsOneWidget);
    expect(_h(t), 38 + 0.5 + 38);
  });

  testWidgets('«уменьшить движение» — сразу, без анимации', (t) async {
    await t.pumpWidget(_host(['a'], reduceMotion: true));
    await t.pumpWidget(_host(['a', 'b'], reduceMotion: true));
    await t.pump();
    expect(_h(t), 38 + 0.5 + 38);
    await t.pumpWidget(_host(['b'], reduceMotion: true));
    await t.pump();
    expect(find.byKey(const ValueKey('t-a')), findsNothing);
  });

  test('🔴 в чате звонки — строки той же пластины, не капсулы в теле', () {
    final s = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(s.contains('const bool _kCallIslandsInHeader = true;'), isTrue);
    for (final id in ['pinned', 'player', 'call', 'room_call']) {
      expect(s.contains("id: '$id',"), isTrue, reason: id);
    }
    expect(s.contains('child: LiquidIslandRows('), isTrue);
    // Высота шапки считается по тем же строкам, что и рисуются.
    expect(
      s.contains('final strips = _secondaryIslandRows().length;'),
      isTrue,
    );
  });

  test('🔴 на главном и в Комнатах — одна пластина с жидкими строками', () {
    final s = File('lib/ui/shared_audio_controls.dart').readAsStringSync();
    expect(s.contains('rowIds: ids,'), isTrue);
    final g = File('lib/ui/widgets/frosted_header_island.dart')
        .readAsStringSync();
    expect(g.contains('const bool kLiquidIslandMerge = true;'), isTrue);
  });
}
