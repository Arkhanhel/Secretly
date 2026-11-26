// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 25.11.2026: копирование пересланного клало в буфер служебную запись —
// «набор букв и цифр» с номерами чата и автора внутри.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart';

String _fwd(String text, {String name = 'Женя', String? cid}) =>
    buildForwardCommand(
      authorName: name,
      text: text,
      authorProfileId: 'pid-$name',
      sourceConvoId: cid,
    );

void main() {
  test('🔴 пересланное копируется текстом, без обёртки', () {
    expect(visibleMessageText(_fwd('Разработка\n•Заметки')), 'Разработка\n•Заметки');
    expect(visibleMessageText('обычный текст'), 'обычный текст');
  });

  test('🔴 пересланное пересланного разворачивается до исходного', () {
    final twice = _fwd(_fwd('суть', name: 'Женя', cid: 'чужой'), name: 'Юрий', cid: 'свой');
    final c = parseForwardCommand(twice)!;
    expect(c.text, 'суть');
    expect(c.authorName, 'Женя');
    expect(c.authorProfileId, 'pid-Женя');
    expect(c.sourceConvoId, 'свой', reason: 'внутренний чат — чужого устройства');
    expect(visibleMessageText(twice), 'суть');
  });

  test('опрос и событие — словами', () {
    final poll = buildPollCommand(
      pollId: 'p',
      question: 'Куда?',
      options: ['Горы', 'Озеро'],
      multiple: false,
      anonymous: false,
    );
    expect(visibleMessageText(poll), '📊 Куда?\n• Горы\n• Озеро');
    final event = buildEventCommand(
      eventId: 'e',
      title: 'Поход',
      startMs: DateTime(2026, 11, 28, 7, 30).millisecondsSinceEpoch,
      location: 'Парковка',
    );
    expect(visibleMessageText(event), '📅 Поход\n28.11.2026 · 07:30\nПарковка');
  });

  test('🔴 вставленная служебная запись не становится командой', () {
    expect(composerSafeText(_fwd('привет')), 'привет');
    expect(composerSafeText('обычный'), 'обычный');
    final evil = '${kDeleteForAllCommandPrefix}abc';
    final safe = composerSafeText(evil);
    expect(isDeleteForAllCommandText(safe), isFalse);
    expect(isHiddenMessageControlText(safe), isFalse);
    expect(safe, contains(evil));
    final nested = _fwd(evil);
    expect(isDeleteForAllCommandText(composerSafeText(nested)), isFalse);
  });

  test('сырая запись не уходит в буфер, выгрузку и правку', () {
    final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
    final from = chat.indexOf('Future<void> _copyEventsToClipboard');
    final copy = chat.substring(from, chat.indexOf('Clipboard.setData', from));
    expect(copy, contains('visibleMessageText(payload.text)'));
    expect(copy, isNot(contains('text = payload.text;')));
    final e = chat.indexOf('Future<void> _startEdit');
    expect(
      chat.substring(e, e + 700),
      contains('startsWith(kSecretlyHiddenCommandPrefix)'),
    );
    final app = File('lib/app/app_controller.dart').readAsStringSync();
    expect(app, contains('visibleMessageText(await decryptPlainAsync(e))'));
    // Запись действительно читаема любым — потому её и нельзя показывать.
    final raw = _fwd('т', cid: 'c').substring(kForwardCommandPrefix.length);
    expect(utf8.decode(base64Url.decode(raw)), contains('"cid":"c"'));
  });
}
