// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Лента (26.11.2026, разбор В): поиск, цитаты, темы, ссылки, «прочитали».

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_message_mentions.dart';

String _slice(String s, String from, [int len = 4000]) {
  final i = s.indexOf(from);
  expect(i, greaterThanOrEqualTo(0), reason: from);
  return s.substring(i, (i + len).clamp(0, s.length));
}

String _plain(List<InlineSpan> spans) =>
    spans.map((s) => s.toPlainText()).join();

void main() {
  final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
  final app = File('lib/app/app_controller.dart').readAsStringSync();

  const fb =
      'https://www.facebook.com/x/posts/1?__cft__[0]=AZW&__tn__=%2CO%2CP-R';

  test('🔴 предпросмотр: ссылка с __ остаётся целой, разметка вокруг снимается', () {
    expect(stripChatFormattingMarkers('смотри $fb'), 'смотри $fb');
    expect(stripChatFormattingMarkers('**важно** $fb __тут__'), 'важно $fb тут');
  });

  testWidgets('🔴 в пузыре ссылка с __ — целая и одна, без курсива', (t) async {
    late List<InlineSpan> spans;
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        spans = buildChatMessageTextSpans(
          context: context,
          text: 'ссылка $fb и __курсив__',
          mentions: const [],
          baseStyle: const TextStyle(),
          isOutgoing: false,
          selfProfileId: 'me',
          currentUserCanReceiveAdminMentions: false,
          onLinkTap: (_) {},
        );
        return const SizedBox();
      }),
    ));
    // Ссылка — одна целая вставка; хвост адреса не вылез текстом, курсив
    // снят только с «курсива».
    expect(_plain(spans), 'ссылка \uFFFC и курсив');
  });

  test('🔴 поиск в чате: вся история, без служебного и удалённого, с подписями', () {
    final s = _slice(app, 'Future<List<ChatSearchHit>> searchChatMatches({', 5000);
    expect(s, contains('limit: scanLimit'));
    expect(s, contains('authorizeDeleteForAll(convoId, commands)'));
    expect(s, contains('isHiddenMessageControlText(raw)'));
    expect(s, contains('payload.caption'));
    expect(s, contains('visibleMessageText(raw)'));
    expect(chat, contains('scanLimit: 4000,'));
    // С самого свежего совпадения; Enter — к более старому.
    expect(chat, contains('_currentSearchHitIndex = hits.length - 1;'));
    expect(chat, contains('onSubmitted: (_) => _prevSearchHit(),'));
  });

  test('🔴 ответ на сообщение вне окна получает цитату из базы', () {
    expect(chat, contains('final missingReplyIds = <String>{'));
    expect(chat, contains('widget.controller.chatEventForPayloadId('));
    expect(app, contains('Future<ChatEvent?> chatEventForPayloadId('));
  });

  test('🔴 тема со старыми сообщениями дорастает окно сама', () {
    final g = _slice(chat, '_timelineLoadLimit < _topicGrowCeiling) {', 900);
    expect(g, contains('_timelineLoadLimit += _timelineLoadLimitStep;'));
    expect(chat, contains('static const int _topicGrowCeiling = 2000;'));
  });

  test('🔴 «прочитали: N» в комнате обновляется', () {
    final sig = _slice(chat, 'Future<List<_TimelineEntry>> _timelineEntriesFutureFor(', 2500);
    expect(sig, contains('widget.controller.roomReceiptsVersion'));
    final db = File('lib/storage/app_db.dart').readAsStringSync();
    expect(_slice(db, 'Future<void> roomMessageReceiptUpsert({', 2500),
        contains('roomReceiptsSeq++;'));
  });
}
