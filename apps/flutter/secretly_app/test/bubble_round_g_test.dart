// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Пузыри (26.11.2026, разбор Г): отклик касаний, «изменено», повтор появления.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _slice(String s, String from, [int len = 3000]) {
  final i = s.indexOf(from);
  expect(i, greaterThanOrEqualTo(0), reason: from);
  return s.substring(i, (i + len).clamp(0, s.length));
}

void main() {
  final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
  final app = File('lib/app/app_controller.dart').readAsStringSync();

  test('🔴 где двойного касания нет, одиночное не ждёт 0,3 с', () {
    expect(chat, isNot(contains('onDoubleTapAction: () {},')));
    expect(chat, isNot(contains('onDoubleTapAction:\n                                                            () {},')));
    final w = _slice(chat, 'class _SelectableEventWrapperState');
    expect(w, contains('widget.onDoubleTap == null'));
    // Опрос, событие, карточки, соло-эмодзи — без двойного касания.
    final main = _slice(chat, 'onDoubleTapAction:\n                                                        isSoloEmoji ||', 600);
    expect(main, contains('? null'));
  });

  test('🔴 правленое сообщение помечено «изменено»', () {
    expect(app, contains('Future<Set<String>> editedPayloadIds(String convoId)'));
    final apply = _slice(app, 'Future<bool> _applyMessageEditLocal({', 9000);
    expect(apply, contains('await _markMessageEdited(cleanedConvoId, cleanedPayloadEventId);'));
    expect(chat, contains('edited: editedPayloadIds.contains(item.event.payloadEventId),'));
    expect(chat, contains('edited: entry.edited,'));
    expect(_slice(chat, 'Widget _sentMetaRow(BuildContext context)', 600),
        contains("ru: 'изменено'"));
  });

  test('🔴 выйти и вернуться — пузырь не вылетает заново', () {
    expect(chat, contains('static final Set<String> _seenEventIdsGlobal = _CappedSeenSet(4000);'));
  });
}
