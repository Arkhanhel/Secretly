// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 СЕРИЯ СООБЩЕНИЙ В КОМНАТЕ — ПО ПРАВИЛУ ТЕЛЕФОНА.
//
// Указание владельца 16.09.2026 со скриншотом телеграма: «изучи полностью
// визуальную часть телеграм и сделай у нас так же». В телеграме и на телефоне
// (`showGroupAvatar` / `isFirstInSeries` в `chat_screen`) серия сообщений
// одного человека открывается ИМЕНЕМ сверху и закрывается ПОРТРЕТОМ снизу.
//
// ЧТО БЫЛО НЕ ТАК.
//   1. Портрет стоял у ПЕРВОГО сообщения серии — над пузырями, которые ниже.
//   2. Серию рвали 60 секунд: два ответа с разницей в две минуты на телефоне —
//      одна серия, а на компьютере были две, с повтором имени и портрета.
//   3. Серию собирали по ИМЕНИ, и два разных «Участника» склеивались в одного.

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/avatar.dart';

const _t0 = 1757700000000;

MessageData _msg(
  String id,
  String text, {
  String author = 'Пётр',
  String seed = 'dev-petr',
  int atMs = _t0,
  bool isSelf = false,
}) => MessageData(
  id: id,
  payloadId: id,
  authorName: author,
  authorSeed: seed,
  text: text,
  time: '12:00',
  timestampMs: atMs,
  isSelf: isSelf,
);

Future<void> _pump(WidgetTester tester, List<MessageData> messages) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: ChatThreadPanel(
            header: const ChatHeader(name: 'Комната'),
            isDirect: false,
            messages: messages,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// Портрет в ленте — у каждого пузыря свой; шапка комнаты тоже рисует
/// портрет, поэтому считаем только те, что внутри пузырей.
Finder _bubbleAvatars() => find.descendant(
  of: find.byType(MessageBubble),
  matching: find.byType(Avatar),
);

MessageBubble _bubbleOf(WidgetTester tester, String text) => tester.widget(
  find.ancestor(
    of: find.textContaining(text),
    matching: find.byType(MessageBubble),
  ).first,
);

void main() {
  testWidgets('🔴 портрет — у ПОСЛЕДНЕГО сообщения серии, имя — у первого', (
    tester,
  ) async {
    await _pump(tester, [
      _msg('m1', 'первое', atMs: _t0),
      // Две минуты спустя — на телефоне это всё ещё та же серия.
      _msg('m2', 'второе', atMs: _t0 + 2 * 60 * 1000),
      _msg('m3', 'третье', atMs: _t0 + 3 * 60 * 1000),
    ]);

    expect(_bubbleOf(tester, 'первое').showAvatar, isFalse);
    expect(_bubbleOf(tester, 'второе').showAvatar, isFalse);
    expect(_bubbleOf(tester, 'третье').showAvatar, isTrue);
    expect(_bubbleAvatars(), findsOneWidget);

    // Портрет стоит на уровне нижнего пузыря, а не верхнего.
    final avatar = tester.getRect(_bubbleAvatars());
    final last = tester.getRect(find.textContaining('третье'));
    final first = tester.getRect(find.textContaining('первое'));
    expect(avatar.center.dy, greaterThan(first.bottom));
    expect(avatar.bottom, greaterThan(last.top));

    // Имя — один раз, над первым пузырём.
    expect(_bubbleOf(tester, 'первое').message.continuation, isFalse);
    expect(_bubbleOf(tester, 'второе').message.continuation, isTrue);
    expect(_bubbleOf(tester, 'третье').message.continuation, isTrue);
  });

  testWidgets('чужое сообщение между ними рвёт серию', (tester) async {
    await _pump(tester, [
      _msg('m1', 'Пётр раз'),
      _msg('m2', 'Анна тут', author: 'Анна', seed: 'dev-anna', atMs: _t0 + 1),
      _msg('m3', 'Пётр два', atMs: _t0 + 2),
    ]);
    expect(_bubbleOf(tester, 'Пётр раз').showAvatar, isTrue);
    expect(_bubbleOf(tester, 'Анна тут').showAvatar, isTrue);
    expect(_bubbleOf(tester, 'Пётр два').showAvatar, isTrue);
    expect(_bubbleOf(tester, 'Пётр два').message.continuation, isFalse);
  });

  testWidgets('🔴 два разных «Участника» — две серии, а не одна', (tester) async {
    // Имя одинаковое, устройства разные: это разные люди, чьи профили ещё не
    // подгрузились. По имени они склеивались в одного.
    await _pump(tester, [
      _msg('m1', 'от первого', author: 'Участник', seed: 'dev-1'),
      _msg('m2', 'от второго', author: 'Участник', seed: 'dev-2', atMs: _t0 + 1),
    ]);
    expect(_bubbleOf(tester, 'от первого').showAvatar, isTrue);
    expect(_bubbleOf(tester, 'от второго').message.continuation, isFalse);
  });

  testWidgets('граница дня рвёт серию', (tester) async {
    await _pump(tester, [
      _msg('m1', 'вчерашнее', atMs: _t0),
      _msg('m2', 'сегодняшнее', atMs: _t0 + 24 * 60 * 60 * 1000),
    ]);
    expect(_bubbleOf(tester, 'вчерашнее').showAvatar, isTrue);
    expect(_bubbleOf(tester, 'сегодняшнее').message.continuation, isFalse);
  });

  testWidgets('в личном чате портрета нет вовсе', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: ChatThreadPanel(
              header: const ChatHeader(name: 'Пётр'),
              isDirect: true,
              messages: [_msg('m1', 'привет')],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(_bubbleAvatars(), findsNothing);
  });
}
