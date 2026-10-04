// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ФАЙЛЫ ИЗ ОКНА ОТПРАВКИ ПРИ СМЕНЕ ЧАТА (01.10.2026).
//
// Чат сменили, пока окно отправки было открыто. Нажатое «Отправить» уходит в
// ту переписку, из которой окно открыли; закрытое сменой чата окно говорит,
// что файлы не ушли. Раньше первый же `setState` на снятом хосте бросал
// исключение, и файлы пропадали молча.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final section = File(
    'lib/ui/desktop/app/desktop_chats_section.dart',
  ).readAsStringSync();
  final panel = File(
    'lib/ui/desktop/chat/chat_thread_panel.dart',
  ).readAsStringSync();

  String body(String src, String head, String end) {
    final start = src.indexOf(head);
    expect(start, greaterThan(0), reason: head);
    return src.substring(start, src.indexOf(end, start));
  }

  test('цель читается на входе, состояние — только у живого хоста', () {
    final send = body(
      section,
      'Future<void> _sendMedia(',
      '  void _cancelUpload(',
    );
    expect(send.contains('final convoId = _convoId;'), isTrue);
    expect(send.contains('convoId: convoId,'), isTrue);
    expect(send.contains('topicId: topicId,'), isTrue);
    expect(
      send.contains('if (mounted) setState(() => _sendError = null);'),
      isTrue,
    );
    expect(
      RegExp(r'^\s+setState\(', multiLine: true).hasMatch(send),
      isFalse,
      reason: 'каждый setState здесь обязан стоять за `mounted`',
    );
  });

  test('снятая панель: отправленное уходит, закрытое — объявлено', () {
    final open = body(
      panel,
      'Future<void> _openSendDialog(',
      '  /// Гифка из панели',
    );
    final gone = open.substring(
      open.indexOf('if (!mounted) {'),
      open.indexOf('if (outcome is SendMediaResult) {\n        _consumeReply'),
    );
    expect(gone.contains('await send(outcome, replyToPayloadEventId: reply);'),
        isTrue);
    expect(gone.contains('strings.desktopSendMediaDroppedOnSwitch'), isTrue);
    expect(open.contains('Overlay.maybeOf(context, rootOverlay: true)'), isTrue);
  });
}
