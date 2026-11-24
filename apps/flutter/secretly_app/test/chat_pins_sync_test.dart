// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Закреплённые (21.11.2026, жалоба: «у собеседников то показываются, то нет;
// после удаления аккаунта и восстановления не восстанавливаются»).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  group('команда списка', () {
    test('ревизия и чат едут в команде; старая команда — без них', () {
      final text = buildPinSyncCommand(
        const [PinnedRef(eventId: 'p1', previewText: 'Привет', pinnedAtMs: 5)],
        revision: 1700,
        convoId: 'PEER-1',
      );
      final cmd = parsePinSyncCommand(text)!;
      expect(cmd.pins.single.eventId, 'p1');
      expect(cmd.revision, 1700);
      expect(cmd.convoId, 'PEER-1');
      expect(cmd.freshnessMs(99), 1700);
      // Старые сборки шлют без ревизии — свежесть по времени сообщения.
      final legacy = parsePinSyncCommand(
        buildPinSyncCommand(const [PinnedRef(eventId: 'p2')]),
      )!;
      expect(legacy.revision, 0);
      expect(legacy.convoId, '');
      expect(legacy.freshnessMs(99), 99);
      // Прячется у всех, в том числе у старых сборок (общее правило).
      expect(isHiddenMessageControlText(text), isTrue);
    });

    test('хранимый вид — тот же JSON, что писал экран; новые сверху', () {
      final raw = encodeStoredChatPins(const [
        PinnedRef(eventId: 'a', previewText: 'A', pinnedAtMs: 1),
        PinnedRef(eventId: 'b', previewText: 'B', pinnedAtMs: 3),
      ]);
      expect(raw.contains('"eventId":"a"'), isTrue);
      final back = decodeStoredChatPins(
        '[{"eventId":"a","previewText":"A","pinnedAtMs":1},'
        '{"eventId":"b","previewText":"B","pinnedAtMs":3},'
        '{"eventId":"a","previewText":"dup","pinnedAtMs":9}]',
      );
      expect(back.map((p) => p.eventId), ['b', 'a']);
      expect(decodeStoredChatPins('мусор'), isEmpty);
      expect(decodeStoredChatPins(null), isEmpty);
    });
  });

  group('повтор', () {
    const now = 10 * 60 * 1000 * 100;
    bool resend({
      int revision = 5,
      int sentRevision = 5,
      int sentAtMs = now - 1000,
      bool partial = false,
      String key = 'k',
      String sentKey = 'k',
    }) => shouldResendChatPins(
      nowMs: now,
      revision: revision,
      sentRevision: sentRevision,
      sentAtMs: sentAtMs,
      sentPartially: partial,
      recipientsKey: key,
      sentRecipientsKey: sentKey,
    );

    test('ничего не менялось — не повторяем', () {
      expect(resend(), isFalse);
      expect(resend(revision: 0), isFalse);
    });

    test('у собеседника новое устройство (восстановление) — повторяем', () {
      expect(resend(key: 'new-device'), isTrue);
    });

    test('список новее отправленного или не отправлялся — повторяем', () {
      expect(resend(revision: 6), isTrue);
      expect(resend(sentAtMs: 0), isTrue);
    });

    test('не дошло — повтор не раньше чем через 10 минут', () {
      expect(resend(partial: true), isFalse);
      expect(
        resend(
          partial: true,
          sentAtMs: now - kChatPinsResendAfterPartial.inMilliseconds,
        ),
        isTrue,
      );
    });
  });

  group('🔴 провода', () {
    final c = _src('lib/app/app_controller.dart');
    final s = _src('lib/ui/chat_screen.dart');

    test('личный чат: список уходит собеседнику и своим устройствам', () {
      final at = c.indexOf('Future<void> _sendChatPinsCommand(');
      final body = c.substring(at, at + 3000);
      expect(body.contains('sendControlMessage('), isTrue);
      expect(body.contains('queueIfNoDevices: true'), isTrue);
      expect(body.contains('_sendSelfMirrorControl(command)'), isTrue);
      // В комнате «писать нельзя» и медленный режим список не держат.
      expect(body.contains('gateAction: RoomAction.pinMessage'), isTrue);
      // Ошибка не глотается молча.
      expect(body.contains("DiagLog.event('pins', 'send_failed'"), isTrue);
    });

    test('приём — сразу при получении, в личном чате и в комнате', () {
      expect(c.contains('final pinCmd = parsePinSyncCommand(msgEvent.text);'), isTrue);
      expect(
        RegExp(r'isPinSyncCommandText\(bodyText\)').hasMatch(c),
        isTrue,
      );
      final at = c.indexOf('Future<bool> _adoptInboundChatPins(');
      final body = c.substring(at, at + 800);
      expect(body.contains('command.freshnessMs(atMs)'), isTrue);
      expect(body.contains('await chatPinsRevision(convoId)'), isTrue);
    });

    test('экран: правка рассылается всегда, ревизия хранится, есть повтор', () {
      expect(s.contains('if (_isGroupChat) {\n        await _broadcastSharedPins'), isFalse);
      expect(s.contains('final revision = await _broadcastSharedPins('), isTrue);
      expect(s.contains('widget.controller.maybeResendChatPins(convoId)'), isTrue);
      expect(s.contains('unawaited(_reloadPinsIfNewer());'), isTrue);
      expect(s.contains('command.freshnessMs(item.event.createdAtMs)'), isTrue);
    });

    test('список закреплённых едет в копию (ключ не в запрете)', () {
      final prefs = _src('lib/security/safe_backup_prefs.dart');
      expect(prefs.contains("'chat_pin"), isFalse);
    });
  });
}
