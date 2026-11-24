// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Полёт реакции из меню (23.11.2026, владелец: «на пузыре с медиа нет нашей
// анимации», «реакция как будто дублируется — на 💯 их две»).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/reaction_fx.dart';

const _fxId = 'evt9|💯';

Widget _app(GlobalKey chatKey) => MaterialApp(
  home: Scaffold(
    key: chatKey,
    body: Align(
      alignment: const Alignment(-0.5, 0.4),
      child: ReactionChipFxScope(
        fxId: _fxId,
        ringColor: Colors.blue,
        child: const ReactionGlyphFxScope(
          fxId: _fxId,
          child: SizedBox(width: 18, height: 18),
        ),
      ),
    ),
  ),
);

Widget _flyer(String e, double size, bool play) =>
    SizedBox(key: const ValueKey('flyer'), width: size, height: size);

/// Открыть «меню» (прозрачное окно поверх чата), запустить полёт из его
/// контекста или из контекста чата и закрыть меню через 480 мс — как
/// в чате.
Future<void> _flyFromMenu(WidgetTester t, {required bool chatContext}) async {
  final chatKey = GlobalKey();
  await t.pumpWidget(_app(chatKey));
  late BuildContext menuCtx;
  Navigator.of(chatKey.currentContext!).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (c, _, _) {
        menuCtx = c;
        return const SizedBox.expand();
      },
    ),
  );
  await t.pumpAndSettle();
  launchReactionFlight(
    context: chatContext ? chatKey.currentContext! : menuCtx,
    emoji: '💯',
    start: const Rect.fromLTWH(60, 300, 34, 34),
    bubble: null,
    fxId: _fxId,
    haptics: false,
    emojiBuilder: _flyer,
  );
  await t.pump(); // первый кадр — часы полёта пошли
  await t.pump(const Duration(milliseconds: 480));
  Navigator.of(menuCtx).pop();
}

void main() {
  tearDown(() => ReactionFxRegistry.instance.clear(_fxId));

  testWidgets('с контекстом меню полёт обрывался до посадки (причина)', (
    t,
  ) async {
    await _flyFromMenu(t, chatContext: false);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('flyer')), findsNothing);
    expect(ReactionFxRegistry.instance.of(_fxId), isNull);
  });

  testWidgets('🔴 с контекстом чата — долетает, садится в чип, остаётся один', (
    t,
  ) async {
    await _flyFromMenu(t, chatContext: true);
    await t.pump(const Duration(milliseconds: 100));
    // Меню закрыто — эмодзи ещё летит.
    expect(find.byKey(const ValueKey('flyer')), findsOneWidget);
    await t.pump(const Duration(milliseconds: 800));
    await t.pump(const Duration(milliseconds: 800));
    await t.pump(const Duration(milliseconds: 100));
    expect(ReactionFxRegistry.instance.of(_fxId), ReactionChipFx.landed);
    // Сел — большого больше нет (раньше висел над знаком чипа, пока доигрывал
    // эффект, — «две реакции»).
    await t.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const ValueKey('flyer')), findsNothing);
    await t.pump(const Duration(seconds: 4));
  });

  test('чат запускает полёт из меню в своём контексте', () {
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    final i = src.indexOf('void pick(String e) {');
    expect(i, greaterThan(0));
    final body = src.substring(i, i + 2400);
    expect(body.contains('launchReactionFlight('), isTrue);
    expect(body.contains('context: this.context,'), isTrue);
  });
}
