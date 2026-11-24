// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 22.11.2026 (жалоба владельца): на iPhone при открытии меню реакций
// страница чата под ним уползала влево — меню открывалось как новая
// страница, и переход iOS сдвигал предыдущую.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/animations/page_transitions.dart';
import 'package:secretly_app/ui/chat/reaction_fx.dart';

void main() {
  testWidgets('меню реакций не сдвигает страницу под собой (iPhone)', (t) async {
    final pageKey = GlobalKey();
    late BuildContext pageCtx;
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: const SizedBox(),
    ));
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    // Наша страница (как у чата), а не стандартная: ошибка была в её
    // canTransitionTo.
    nav.push(SecretlyPageRoute<void>(
      builder: (context) {
        pageCtx = context;
        return Scaffold(key: pageKey, body: const Center(child: Text('чат')));
      },
    ));
    await t.pumpAndSettle();
    final before = t.getTopLeft(find.text('чат'));
    showReactionMenu<void>(
      context: pageCtx,
      bubble: const Rect.fromLTWH(20, 300, 200, 60),
      blur: false,
      builder: (_) => const SizedBox(),
    );
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 30));
    }
    expect(t.getTopLeft(find.text('чат')), before);
    nav.pop();
    await t.pumpAndSettle();
  });

  testWidgets('прозрачное окно поверх (как просмотр медиа) — страница стоит, '
      'непрозрачная — уезжает', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: const SizedBox(),
    ));
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.push(SecretlyPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('чат'))),
    ));
    await t.pumpAndSettle();
    final before = t.getTopLeft(find.text('чат'));
    nav.push(PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => const SizedBox(),
    ));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('чат')), before);
    nav.pop();
    await t.pumpAndSettle();
    // Обычный переход на другой экран по-прежнему сдвигает страницу.
    nav.push(SecretlyPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('профиль'))),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(
      t.getTopLeft(find.text('чат', skipOffstage: false)).dx,
      lessThan(before.dx),
    );
    await t.pumpAndSettle();
  });
}
