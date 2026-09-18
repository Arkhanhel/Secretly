// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// «Продолжить в теме» — четвёртая кнопка строки наведения.
//
// ◆ В МАКЕТЕ это кнопка `forum` рядом с «Ответить», и подписана она была
// «вынести в тему».
//
// 🔴 ВЫНЕСТИ — НЕЛЬЗЯ, И ЭТО НЕ НЕДОРАБОТКА. Тема лежит ВНУТРИ запечатанного
// payload: переписать её у уже разосланного сообщения не может никто — ни
// отправитель, ни сервер, ни получатель. Кнопка с макетной подписью обещала
// бы то, чего протокол не умеет.
//
// Поэтому переносится не сообщение, а РАЗГОВОР: выбираем ветку, окно
// переключается в неё, и в поле ввода встаёт цитата исходного сообщения.
// Само сообщение остаётся на месте, а цитата ведёт к нему обратно.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

/// Отступ сверху — не украшение теста: строка действий встаёт НАД пузырём, и
/// у самого верха окна ей просто некуда встать.
Widget host(Widget child) => MaterialApp(
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 120),
        child: SizedBox(width: 760, child: child),
      ),
    ),
  ),
);

const _msg = MessageData(
  id: 'm1',
  payloadId: 'p1',
  authorName: 'Игорь',
  text: 'Плюс 40 % к удержанию на второй день',
  time: '14:19',
);

void main() {
  testWidgets('веток нет — кнопки нет', (t) async {
    await t.pumpWidget(host(const MessageBubble(message: _msg)));
    await t.pump();
    expect(find.byIcon(FluentIcons.comment_multiple_24_regular), findsNothing);
  });

  testWidgets('◆ ветки есть — кнопка есть и отдаёт своё место на экране', (
    t,
  ) async {
    Offset? at;
    await t.pumpWidget(
      host(
        MessageBubble(
          message: _msg,
          onContinueInTopic: (pos) => at = pos,
        ),
      ),
    );
    // Строка наведения появляется по наведению — вызываем её мышью.
    final gesture = await t.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(t.getCenter(find.textContaining(_msg.text)));
    await t.pumpAndSettle();

    final btn = find.byIcon(FluentIcons.comment_multiple_24_regular);
    expect(btn, findsOneWidget);
    expect(find.byTooltip('Продолжить в теме'), findsOneWidget);

    await t.tap(btn);
    await t.pump();
    // Меню выбора ветки встаёт у самой кнопки, а не в углу окна.
    expect(at, isNotNull);
    expect(at!.dx, greaterThan(0));
  });

  group('правила', () {
    final bubble = File(
      'lib/ui/desktop/chat/message_bubble.dart',
    ).readAsStringSync();
    final panel = File(
      'lib/ui/desktop/chat/chat_thread_panel.dart',
    ).readAsStringSync();
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();

    test('🔴 подпись обещает ровно то, что происходит', () {
      expect(bubble.contains("tooltip: 'Продолжить в теме'"), isTrue);
      // Макетной подписи в коде нет: она обещала бы невозможное.
      final code = bubble
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
          .join('\n');
      expect(code.contains('Вынести в тему'), isFalse);
      expect(code.contains('вынести в тему'), isFalse);
    });

    test('кнопка стоит рядом с «Ответить», как в макете', () {
      final reply = bubble.indexOf("tooltip: 'Ответить'");
      final forum = bubble.indexOf("tooltip: 'Продолжить в теме'");
      final more = bubble.indexOf("tooltip: 'Ещё',");
      expect(reply, greaterThan(0));
      expect(forum, greaterThan(reply));
      expect(more, greaterThan(forum));
    });

    test('🔴 в личной переписке и в комнате без веток кнопки нет вовсе', () {
      // Пункт, который всегда отвечает отказом, пунктом не является.
      expect(section.contains('onContinueInTopic: _topicsVisible ? _continueInTopic : null,'), isTrue);
      expect(bubble.contains('if (widget.onContinueInTopic != null)'), isTrue);
      expect(panel.contains('widget.onContinueInTopic == null'), isTrue);
    });

    test('работа поделена по месту хранения', () {
      // Темы живут в секции чатов, поле ввода — в панели. Выбор ветки
      // спрашиваем у хозяина, цитату ставит панель.
      expect(
        panel.contains('final Future<bool> Function(Offset globalPosition)? onContinueInTopic;'),
        isTrue,
      );
      expect(panel.contains('_ctx = ComposerContext.reply('), isTrue);
      expect(panel.contains('if (!picked || !mounted) return;'), isTrue);
    });

    test('🔴 ветку не выбрали — ничего не меняется', () {
      expect(section.contains('if (picked == null) return false;'), isTrue);
      // И новую тему могли не завести — тогда продолжать негде.
      expect(section.contains('return mounted && _currentTopicId != before;'), isTrue);
    });

    test('ветку, в которой стоим, выбирать нечего', () {
      expect(section.contains('enabled: _currentTopicId != null,'), isTrue);
      expect(section.contains('enabled: t.id != _currentTopicId,'), isTrue);
    });

    test('«Новая тема…» — только тому, кому комната это позволяет', () {
      expect(section.contains('if (_canManageTopics)'), isTrue);
    });
  });
}
