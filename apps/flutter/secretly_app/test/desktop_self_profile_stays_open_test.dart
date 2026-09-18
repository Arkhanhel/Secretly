// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Своя страница профиля не закрывается САМА.
//
// 🔴 ЧТО БЫЛО СЛОМАНО.
//
// Правая панель переключается с моего профиля обратно на переписку, когда
// человек открывает ДРУГОЙ чат. Слушатель для этого висел на складе выбора и
// срабатывал на ЛЮБОЕ оповещение — а склад оповещает и тогда, когда переписка
// та же, но обновился её снимок (`refresh` уведомляет всегда, это его работа).
//
// Список чатов перечитывается сам, раз в тридцать секунд, чтобы «вчера» не
// протухало. Значит своя страница профиля закрывалась без единого действия
// человека, в среднем через полминуты после открытия, — и тем вернее, чем
// активнее переписка. Тот же дефект ломал переход «Настройки → Профиль»:
// настройки закрывались, секция перечитывала список, склад оповещал — и
// профиль, открытый мгновение назад, закрывался в том же кадре.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart' show Conversation;
import 'package:secretly_app/ui/desktop/chat/details/desktop_selection_store.dart';

Conversation convo(String id, {int at = 1}) => Conversation(
      convoId: id,
      peerProfileId: 'p-$id',
      title: id,
      avatarPath: null,
      lastEventAtMs: at,
      pinnedAtMs: null,
      muted: false,
      archivedAtMs: null,
      autoDeleteSeconds: null,
      emoji: null,
    );

void main() {
  group('склад выбора: контракт оповещений', () {
    test('select молчит, когда переписка та же', () {
      final store = DesktopChatSelectionStore();
      var ticks = 0;
      store
        ..select(convo('a'))
        ..addListener(() => ticks++)
        ..select(convo('a', at: 999));
      expect(ticks, 0, reason: 'тот же чат — не событие выбора');
    });

    test('🔴 refresh оповещает ВСЕГДА — на это и наступили', () {
      final store = DesktopChatSelectionStore();
      store.select(convo('a'));
      var ticks = 0;
      store.addListener(() => ticks++);
      store.refresh(convo('a', at: 999));
      expect(
        ticks,
        1,
        reason:
            'контракт намеренный: панель обязана перерисоваться, когда у '
            'открытого чата обновился снимок. Слушателям поэтому нельзя '
            'считать оповещение сменой выбора',
      );
    });

    test('select оповещает, когда чат ДРУГОЙ', () {
      final store = DesktopChatSelectionStore();
      store.select(convo('a'));
      var ticks = 0;
      store.addListener(() => ticks++);
      store.select(convo('b'));
      expect(ticks, 1);
    });
  });

  test('🔴 профиль закрывается по СМЕНЕ выбора, а не по оповещению', () {
    final src = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    final i = src.indexOf('void _dropSelfProfileOnSelection()');
    expect(i, greaterThan(0));
    final body = src.substring(i, i + 700);
    expect(
      body.contains('if (next == _lastSelectionId) return;'),
      isTrue,
      reason:
          'без этой проверки перечитывание списка раз в тридцать секунд '
          'закрывает открытую страницу профиля само',
    );
    expect(
      body.contains('_lastSelectionId = next;'),
      isTrue,
      reason: 'запомнить новый выбор обязательно, иначе проверка сработает раз',
    );
  });
}
