// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Исчезающие сообщения — шаг 3 ТЗ 22.10.2026: включение таймера, команда
// собеседнику, приём команды, общая точка срока исходящих и уборка. Главное
// свойство, которое здесь сторожится: при закрытом флаге сервера НИЧЕГО не
// меняется — ни срок в сообщениях, ни команды, ни пункт в настройках.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/messages/disappearing_flags.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _me = 'me-profile';
const _peer = 'peer-profile';

Future<(AppController, AppDb, List<(String, String)>, Directory)> _setUp() async {
  FlutterSecureStorage.setMockInitialValues(<String, String>{});
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final dir = await Directory.systemTemp.createTemp('secretly_disappear_');
  final db = await AppDb.openForTesting(path: '${dir.path}/d.db');
  final controller = AppController()
    ..seedRoomRuntimeForTesting(
      db: db,
      profileId: _me,
      deviceId: 'me-device',
      crypto: DartCryptoProvider(Uint8List(32)),
    );
  final sent = <(String, String)>[];
  controller.controlMessageSenderForTesting = (to, text) async {
    sent.add((to, text));
  };
  await db.convoEnsure1to1(peerProfileId: _peer);
  return (controller, db, sent, dir);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 флаг закрыт: ни пункта, ни срока, ни команды', () async {
    final (c, db, sent, dir) = await _setUp();
    try {
      // Таймер в базе есть (скажем, собеседник включил), но флаг закрыт.
      await db.convoSetDisappearSeconds(convoId: _peer, disappearSeconds: 300);
      expect(c.disappearingSendEnabled, isFalse);
      expect(await c.disappearingVisibleForConvo(_peer), isFalse);
      expect(await c.outgoingDisappearSecondsForTesting(_peer), isNull);
      await expectLater(
        c.setChatDisappearSeconds(convoId: _peer, seconds: 60),
        throwsStateError,
      );
      await _settle();
      expect(sent, isEmpty);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('флаг открыт: включение ставит таймер, заметку и шлёт команду', () async {
    final (c, db, sent, dir) = await _setUp();
    try {
      c.disappearingFlagsForTesting = const DisappearingFlags(
        sendEnabled: true,
        sendShare: 100,
        minBuild: 660,
      );
      expect(await c.disappearingVisibleForConvo(_peer), isTrue);
      await c.setChatDisappearSeconds(convoId: _peer, seconds: 300);
      await _settle();
      expect(await c.getChatDisappearSeconds(_peer), 300);
      expect(await c.outgoingDisappearSecondsForTesting(_peer), 300);
      final toPeer = sent.where((s) => s.$1 == _peer).toList();
      expect(toPeer, hasLength(1));
      final cmd = parseConvoTimerCommand(toPeer.single.$2)!;
      // В 1:1 команда адресована профилю собеседника — для него это «мой».
      expect(cmd.convoId, _peer);
      expect(cmd.seconds, 300);
      final events = await db.listEvents(_peer, limit: 10);
      expect(
        events.where((e) => (e['event_id'] as String).startsWith(
              'local:disappear:$_peer:',
            )),
        hasLength(1),
      );
      // Повтор того же значения — ничего нового.
      sent.clear();
      await c.setChatDisappearSeconds(convoId: _peer, seconds: 300);
      await _settle();
      expect(sent, isEmpty);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('срок зажимается в пределы конфига; выключение — null', () async {
    final (c, db, _, dir) = await _setUp();
    try {
      c.disappearingFlagsForTesting = const DisappearingFlags(
        sendEnabled: true,
        sendShare: 100,
        customMaxS: 3600,
      );
      await c.setChatDisappearSeconds(convoId: _peer, seconds: 5);
      expect(await c.getChatDisappearSeconds(_peer), DisappearingFlags.customMinS);
      await c.setChatDisappearSeconds(convoId: _peer, seconds: 99999);
      expect(await c.getChatDisappearSeconds(_peer), 3600);
      await c.setChatDisappearSeconds(convoId: _peer, seconds: null);
      expect(await c.getChatDisappearSeconds(_peer), isNull);
      expect(await c.outgoingDisappearSecondsForTesting(_peer), isNull);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('вне доли: включить нельзя, но уже включённый виден и меняется', () async {
    final (c, db, _, dir) = await _setUp();
    try {
      // Доля 0 — этот профиль не в доле, глобальный флаг открыт.
      c.disappearingFlagsForTesting = const DisappearingFlags(
        sendEnabled: true,
        sendShare: 0,
      );
      expect(await c.disappearingVisibleForConvo(_peer), isFalse);
      await expectLater(
        c.setChatDisappearSeconds(convoId: _peer, seconds: 60),
        throwsStateError,
      );
      // Собеседник включил таймер — у меня он должен работать в обе стороны.
      await db.convoSetDisappearSeconds(convoId: _peer, disappearSeconds: 120);
      expect(await c.disappearingVisibleForConvo(_peer), isTrue);
      expect(await c.outgoingDisappearSecondsForTesting(_peer), 120);
      await c.setChatDisappearSeconds(convoId: _peer, seconds: null);
      expect(await c.getChatDisappearSeconds(_peer), isNull);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('«Избранное», комнаты, заявки — таймер не ставится', () async {
    final (c, db, _, dir) = await _setUp();
    try {
      c.disappearingFlagsForTesting = const DisappearingFlags(
        sendEnabled: true,
        sendShare: 100,
      );
      expect(c.canSetDisappearingForConvo(_me), isFalse);
      expect(c.canSetDisappearingForConvo('group:abc'), isFalse);
      expect(c.canSetDisappearingForConvo('req:$_peer'), isFalse);
      expect(c.canSetDisappearingForConvo(_peer), isTrue);
      expect(await c.outgoingDisappearSecondsForTesting('group:abc'), isNull);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('входящая команда собеседника ставит таймер его чата', () async {
    final (c, db, _, dir) = await _setUp();
    try {
      final text = buildConvoTimerCommand(
        convoId: _me,
        seconds: 3600,
        setAtMs: 1000,
      );
      final payload = E2ePayloadV1(
        senderDeviceId: 'peer-device',
        createdAtMs: 1000,
        events: [MsgEventV1(eventId: 'evt-timer', text: text)],
      );
      final bytes = Uint8List.fromList(payload.encode());
      final handled = await c.handleDecryptedInboundPayloadForTesting(
        db: db,
        msgId: 'relay-1',
        ciphertextB64: 'AA==',
        plainBytes: bytes,
        payload: payload,
        senderDeviceId: 'peer-device',
        senderProfileId: _peer,
      );
      expect(handled, isTrue);
      expect(await c.getChatDisappearSeconds(_peer), 3600);
      final events = await db.listEvents(_peer, limit: 10);
      // Видимого сообщения с текстом команды нет, есть только заметка.
      expect(events.where((e) => e['type'] == 'msg'), isEmpty);
      expect(events.where((e) => e['type'] == 'sys'), hasLength(1));

      // Не мне адресованная — не применяется.
      final foreign = buildConvoTimerCommand(
        convoId: 'someone-else',
        seconds: 60,
        setAtMs: 2000,
      );
      final p2 = E2ePayloadV1(
        senderDeviceId: 'peer-device',
        createdAtMs: 2000,
        events: [MsgEventV1(eventId: 'evt-timer-2', text: foreign)],
      );
      await c.handleDecryptedInboundPayloadForTesting(
        db: db,
        msgId: 'relay-2',
        ciphertextB64: 'AA==',
        plainBytes: Uint8List.fromList(p2.encode()),
        payload: p2,
        senderDeviceId: 'peer-device',
        senderProfileId: _peer,
      );
      expect(await c.getChatDisappearSeconds(_peer), 3600);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('уборка удаляет истёкшее; выключатель удаления держит сроки', () async {
    final (c, db, _, dir) = await _setUp();
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      Future<void> put(String id, int expiresAt) => db.insertEvent(
        eventId: id,
        convoId: _peer,
        type: 'msg',
        senderDeviceId: 'me-device',
        ciphertextB64: 'AA==',
        createdAtMs: now - 10000,
        localState: 'sent',
        disappearSeconds: 5,
        expiresAtMs: expiresAt,
      );
      await put('old', now - 1000);
      await put('fresh', now + 60 * 60 * 1000);

      c.disappearingFlagsForTesting = const DisappearingFlags(
        expireEnabled: false,
      );
      expect(await c.runDisappearingSweep(), 0);
      expect(await db.eventGet('old'), isNotNull);

      c.disappearingFlagsForTesting = DisappearingFlags.defaults;
      expect(await c.runDisappearingSweep(), 1);
      expect(await db.eventGet('old'), isNull);
      expect(await db.eventGet('fresh'), isNotNull);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
}
