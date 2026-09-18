// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Стрелки «назад» и «вперёд» в шапке окна: в макете они есть, и они настоящие.
//
// 🔴 Мёртвая кнопка хуже отсутствующей. Нарисовать стрелки и не связать их ни
// с чем — значит научить человека не верить шапке. Поэтому история проверяется
// так же, как проверялась бы история браузера: ветвление, повтор, потолок и
// удалённая переписка.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart' show Conversation;
import 'package:secretly_app/ui/desktop/services/desktop_nav_history.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart'
    show DesktopSection;

Conversation convo(String id) => Conversation(
      convoId: id,
      peerProfileId: 'p-$id',
      title: id,
      avatarPath: null,
      lastEventAtMs: 1,
      pinnedAtMs: null,
      muted: false,
      archivedAtMs: null,
      autoDeleteSeconds: null,
      emoji: null,
    );

DesktopNavEntry entry(String id, [DesktopSection s = DesktopSection.chats]) =>
    DesktopNavEntry(section: s, convo: convo(id));

void main() {
  test('пустая история никуда не ведёт', () {
    final h = DesktopNavHistory();
    expect(h.canBack, isFalse);
    expect(h.canForward, isFalse);
    expect(h.back(), isNull);
    expect(h.forward(), isNull);
    expect(h.current, isNull);
  });

  test('первый чат — ещё не шаг: назад идти некуда', () {
    final h = DesktopNavHistory()..visit(entry('a'));
    expect(h.current?.convoId, 'a');
    expect(h.canBack, isFalse, reason: 'назад из первого чата — в пустоту');
  });

  test('назад и вперёд ходят по пути', () {
    final h = DesktopNavHistory()
      ..visit(entry('a'))
      ..visit(entry('b'))
      ..visit(entry('c'));
    expect(h.canBack, isTrue);
    expect(h.back()?.convoId, 'b');
    expect(h.back()?.convoId, 'a');
    expect(h.canBack, isFalse);
    expect(h.forward()?.convoId, 'b');
    expect(h.forward()?.convoId, 'c');
    expect(h.canForward, isFalse);
  });

  test('🔴 повторное открытие того же чата шага не делает', () {
    final h = DesktopNavHistory()
      ..visit(entry('a'))
      ..visit(entry('b'))
      ..visit(entry('b'));
    expect(h.entries.length, 2, reason: 'иначе «назад» упирается в саму себя');
    expect(h.back()?.convoId, 'a');
  });

  test('🔴 новый чат после «назад» обрезает ветку вперёд', () {
    final h = DesktopNavHistory()
      ..visit(entry('a'))
      ..visit(entry('b'))
      ..visit(entry('c'));
    h.back(); // на b
    h.visit(entry('d'));
    expect(h.entries.map((e) => e.convoId), <String>['a', 'b', 'd']);
    expect(h.canForward, isFalse);
    expect(h.back()?.convoId, 'b');
  });

  test('раздел запоминается вместе с чатом', () {
    final h = DesktopNavHistory()
      ..visit(entry('a'))
      ..visit(entry('r1', DesktopSection.rooms));
    expect(h.back()?.section, DesktopSection.chats);
    expect(h.forward()?.section, DesktopSection.rooms);
  });

  test('путь не растёт бесконечно', () {
    final h = DesktopNavHistory();
    for (var i = 0; i < 80; i++) {
      h.visit(entry('c$i'));
    }
    expect(h.entries.length, lessThanOrEqualTo(30));
    expect(h.current?.convoId, 'c79', reason: 'последний открытый — текущий');
  });

  test('🔴 забытая переписка исчезает из пути целиком', () {
    final h = DesktopNavHistory()
      ..visit(entry('a'))
      ..visit(entry('b'))
      ..visit(entry('c'));
    h.forget('b');
    expect(h.entries.map((e) => e.convoId), <String>['a', 'c']);
    expect(h.current?.convoId, 'c');
    expect(h.back()?.convoId, 'a');
  });

  test('забыли текущую — курсор остаётся внутри пути', () {
    final h = DesktopNavHistory()
      ..visit(entry('a'))
      ..visit(entry('b'));
    h.forget('b');
    expect(h.current?.convoId, 'a');
    expect(h.canForward, isFalse);
    expect(h.canBack, isFalse);
  });

  test('шаг по истории оповещает слушателей — стрелки гаснут сами', () {
    final h = DesktopNavHistory()
      ..visit(entry('a'))
      ..visit(entry('b'));
    var ticks = 0;
    h.addListener(() => ticks++);
    h.back();
    h.forward();
    expect(ticks, 2);
  });
}
