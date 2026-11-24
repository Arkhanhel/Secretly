// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// М4: переходы экранов. iPhone — пружина (открытие, закрытие, свайп назад
// закрывает и возвращает), Android — 150 мс со сдвигом 48 dp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/animations/page_transitions.dart';

final _nav = GlobalKey<NavigatorState>();

Widget _app() => MaterialApp(
  navigatorKey: _nav,
  home: const Scaffold(body: Center(child: Text('home'))),
);

void _push() => _nav.currentState!.push(
  SecretlyPageRoute<void>(
    builder: (_) => const Scaffold(body: Center(child: Text('page'))),
  ),
);

void main() {
  testWidgets('iPhone: открытие и закрытие доходят до конца', (t) async {
    await t.pumpWidget(_app());
    _push();
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    // Пружина быстрая: к 0,1 с страница уже заметно въехала.
    final x = t.getTopLeft(find.text('page')).dx;
    expect(x, lessThan(t.getTopLeft(find.text('home')).dx + 400));
    await t.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
    expect(find.text('home', skipOffstage: false), findsOneWidget);
    _nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(find.text('page'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iPhone: свайп от края закрывает, короткий — возвращает', (
    t,
  ) async {
    await t.pumpWidget(_app());
    _push();
    await t.pumpAndSettle();
    // Короткий медленный свайп — страница возвращается.
    var g = await t.startGesture(const Offset(5, 300));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(6, 0));
      await t.pump(const Duration(milliseconds: 30));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
    expect(t.getTopLeft(find.byType(Scaffold).last).dx, 0);
    // Длинный быстрый — закрывает.
    g = await t.startGesture(const Offset(5, 300));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(40, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(find.text('page'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: 150 мс, нижний экран на месте', (t) async {
    await t.pumpWidget(_app());
    final homeX = t.getTopLeft(find.text('home')).dx;
    _push();
    await t.pump();
    await t.pump(const Duration(milliseconds: 75));
    expect(t.getTopLeft(find.text('home')).dx, homeX);
    await t.pump(const Duration(milliseconds: 80));
    await t.pump();
    expect(find.text('page'), findsOneWidget);
    _nav.currentState!.pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 160));
    await t.pump();
    expect(find.text('page'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
