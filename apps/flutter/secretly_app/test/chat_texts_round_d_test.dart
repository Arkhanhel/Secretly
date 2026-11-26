// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Тексты и лишняя работа в чате (26.11.2026, разбор Д).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_screen_l10n.dart';

void main() {
  final chat = File('lib/ui/chat_screen.dart').readAsStringSync();

  test('🔴 надписи опросов, событий, тем — на всех языках, не английским', () {
    for (final tag in ['uk', 'es', 'pt', 'pt_BR', 'fr', 'de']) {
      for (final en in ['Poll', 'Going', 'Create event', 'Who read', 'Send now', 'No votes yet']) {
        final out = chatTextForLocale(tag, ru: 'x', en: en);
        expect(out, isNot(en), reason: '$tag: $en');
      }
    }
    expect(chatTextForLocale('pt_BR', ru: 'x', en: 'Poll'), 'Enquete');
    expect(chatTextForLocale('pt', ru: 'x', en: 'Poll'), 'Sondagem');
  });

  test('🔴 «5 голос(ов)», «video звонок» больше нет', () {
    expect(chat, isNot(contains('голос(ов)')));
    expect(chat, isNot(contains('файл(ов)')));
    expect(chat, isNot(contains('video звонок')));
    expect(chat, isNot(contains('voice звонок')));
    expect(chat, contains("_slavicPlural(total, 'голос', 'голоса', 'голосов')"));
  });

  test('даты: календарное «вчера», дата события и «кто прочитал» по языку', () {
    expect(chat, contains('DateTime(now.year, now.month, now.day - 1)'));
    expect(chat, contains('ml.formatMediumDate(dt)'));
    expect(chat, contains("'\${_chatDayLabel(context, reader.readAtMs)}, '"));
  });

  test('🔴 экран комнаты перерисовывается, только если права изменились', () {
    final i = chat.indexOf('Future<void> _refreshRoomPolicyState() async {');
    final body = chat.substring(i, i + 1500);
    expect(body, contains('if (sig == _roomPolicySig) {'));
  });
}
