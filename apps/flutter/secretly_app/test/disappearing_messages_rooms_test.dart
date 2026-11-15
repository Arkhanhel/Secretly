// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Исчезающие сообщения в комнатах (ТЗ 22.10.2026). Таймер комнаты —
// зашифрованное состояние: менять его может только владелец или
// администратор, получатель проверяет права сам, а поздняя смена побеждает.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/messages/disappearing_flags.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

DartCryptoProvider _crypto() => DartCryptoProvider(
  Uint8List.fromList(List<int>.generate(32, (index) => index)),
);

Future<bool> _deliverRoomEnvelope(
  AppController controller,
  AppDb db, {
  required String msgId,
  required Map<String, Object?> envelope,
  required String senderDeviceId,
  required String senderProfileId,
  required int createdAtMs,
}) {
  final text = AppController.encodeGroupMessageCommandForTesting(envelope);
  final payload = E2ePayloadV1(
    senderDeviceId: senderDeviceId,
    createdAtMs: createdAtMs,
    events: [MsgEventV1(eventId: 'wrap-$msgId', text: text)],
  );
  return controller.handleDecryptedInboundPayloadForTesting(
    db: db,
    msgId: msgId,
    ciphertextB64: 'AA==',
    plainBytes: Uint8List.fromList(payload.encode()),
    payload: payload,
    senderDeviceId: senderDeviceId,
    senderProfileId: senderProfileId,
    nowMs: createdAtMs + 1000,
  );
}

Map<String, Object?> _envelope({
  required String groupId,
  required String msgEventId,
  required String text,
  required int createdAtMs,
  required String senderProfileId,
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'v': 1,
  'kind': 'message',
  'groupId': groupId,
  'groupTitle': 'Alpha',
  'msgEventId': msgEventId,
  'text': text,
  'createdAtMs': createdAtMs,
  'memberProfileIds': <String>['owner-1', 'peer-1'],
  'senderProfileId': senderProfileId,
  'senderName': 'Peer',
  ...extra,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('secretly-disappear-room-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (_) async {
          return tempDir.path;
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  late AppController controller;
  late AppDb db;

  setUp(() async {
    controller = AppController();
    db = await AppDb.openForTesting();
    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
      crypto: _crypto(),
    );
    controller.controlMessageSenderForTesting = (to, text) async {};
  });

  tearDown(() => db.close());

  Future<String> room() => controller.createGroup(
    title: 'Alpha',
    memberProfileIds: const <String>['peer-1'],
  );

  test('🔴 флаг закрыт: в комнате ни пункта, ни срока', () async {
    final gid = await room();
    expect(await controller.disappearingVisibleForRoom(gid), isFalse);
    await expectLater(
      controller.setRoomDisappearSeconds(groupId: gid, seconds: 600),
      throwsStateError,
    );
  });

  test('владелец включает таймер: срок уходит в сообщения комнаты', () async {
    controller.disappearingFlagsForTesting = const DisappearingFlags(
      sendEnabled: true,
      sendShare: 100,
    );
    final gid = await room();
    expect(await controller.disappearingVisibleForRoom(gid), isTrue);
    expect(await controller.canManageRoomDisappearing(gid), isTrue);
    await controller.setRoomDisappearSeconds(groupId: gid, seconds: 600);
    expect(await controller.getRoomDisappearSeconds(gid), 600);
    expect(await controller.effectiveRoomDisappearSeconds(gid), 600);
    try {
      await controller.sendGroupMessage(groupId: gid, text: 'привет');
    } catch (_) {
      // Реле в тесте нет — важна местная запись.
    }
    final rows = await db.listEventsChronological(gid, limit: 50);
    // 🔴 Отправка в комнату перезаписывает строку беседы (REPLACE) — таймер
    // обязан это пережить.
    expect(await controller.effectiveRoomDisappearSeconds(gid), 600);
    final own = rows.lastWhere(
      (r) => ((r['event_id'] as String?) ?? '').startsWith('local:grp:') &&
          r['disappear_seconds'] != null,
      orElse: () => const <String, Object?>{},
    );
    expect(own['disappear_seconds'], 600);
    expect(own['expires_at_ms'], isNotNull);
  });

  test('🔴 команда таймера от обычного участника не применяется', () async {
    controller.disappearingFlagsForTesting = const DisappearingFlags(
      sendEnabled: true,
      sendShare: 100,
    );
    final gid = await room();
    await _deliverRoomEnvelope(
      controller,
      db,
      msgId: 'r-1',
      envelope: _envelope(
        groupId: gid,
        msgEventId: 'm-1',
        text: buildConvoTimerCommand(convoId: gid, seconds: 30, setAtMs: 5000),
        createdAtMs: 5000,
        senderProfileId: 'peer-1',
      ),
      senderDeviceId: 'peer-device',
      senderProfileId: 'peer-1',
      createdAtMs: 5000,
    );
    expect(await controller.getRoomDisappearSeconds(gid), isNull);
  });

  test('администратор: команда применяется, старая — нет', () async {
    controller.disappearingFlagsForTesting = const DisappearingFlags(
      sendEnabled: true,
      sendShare: 100,
    );
    final gid = await room();
    await db.groupMembershipStateUpsert(
      groupId: gid,
      profileId: 'peer-1',
      status: RoomMembershipStatus.active.value,
      role: RoomMemberRole.admin.value,
      createdAtMs: 1000,
      updatedAtMs: 1000,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _deliverRoomEnvelope(
      controller,
      db,
      msgId: 'r-2',
      envelope: _envelope(
        groupId: gid,
        msgEventId: 'm-2',
        text: buildConvoTimerCommand(convoId: gid, seconds: 3600, setAtMs: now),
        createdAtMs: now,
        senderProfileId: 'peer-1',
      ),
      senderDeviceId: 'peer-device',
      senderProfileId: 'peer-1',
      createdAtMs: now,
    );
    expect(await controller.getRoomDisappearSeconds(gid), 3600);
    final notices = (await db.listEventsChronological(gid, limit: 50))
        .where(
          (r) => ((r['event_id'] as String?) ?? '').startsWith(
            'local:disappear:$gid:',
          ),
        )
        .toList();
    expect(notices, hasLength(1));

    // Команда, выпущенная РАНЬШЕ, проигрывает поздней.
    await _deliverRoomEnvelope(
      controller,
      db,
      msgId: 'r-3',
      envelope: _envelope(
        groupId: gid,
        msgEventId: 'm-3',
        text: buildConvoTimerCommand(
          convoId: gid,
          seconds: 30,
          setAtMs: now - 60000,
        ),
        createdAtMs: now + 10,
        senderProfileId: 'peer-1',
      ),
      senderDeviceId: 'peer-device',
      senderProfileId: 'peer-1',
      createdAtMs: now + 10,
    );
    expect(await controller.getRoomDisappearSeconds(gid), 3600);

    // Состояние в обычном сообщении администратора (так таймер узнают
    // новые участники): более позднее «выключено» применяется.
    await _deliverRoomEnvelope(
      controller,
      db,
      msgId: 'r-4',
      envelope: _envelope(
        groupId: gid,
        msgEventId: 'm-4',
        text: 'обычный текст',
        createdAtMs: now + 20,
        senderProfileId: 'peer-1',
        extra: <String, Object?>{'dt': 0, 'dtAt': now + 20},
      ),
      senderDeviceId: 'peer-device',
      senderProfileId: 'peer-1',
      createdAtMs: now + 20,
    );
    expect(await controller.getRoomDisappearSeconds(gid), isNull);
  });

  test('команда для другой комнаты не применяется', () async {
    controller.disappearingFlagsForTesting = const DisappearingFlags(
      sendEnabled: true,
      sendShare: 100,
    );
    final gid = await room();
    await db.groupMembershipStateUpsert(
      groupId: gid,
      profileId: 'peer-1',
      status: RoomMembershipStatus.active.value,
      role: RoomMemberRole.admin.value,
      createdAtMs: 1000,
      updatedAtMs: 1000,
    );
    await _deliverRoomEnvelope(
      controller,
      db,
      msgId: 'r-5',
      envelope: _envelope(
        groupId: gid,
        msgEventId: 'm-5',
        text: buildConvoTimerCommand(
          convoId: 'group:other',
          seconds: 30,
          setAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        senderProfileId: 'peer-1',
      ),
      senderDeviceId: 'peer-device',
      senderProfileId: 'peer-1',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    expect(await controller.getRoomDisappearSeconds(gid), isNull);
  });

  test('уборка оставляет отметку «исчезло» для цитаты', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insertEvent(
      eventId: 'gone-row',
      convoId: 'peer-1',
      type: 'msg',
      senderDeviceId: 'owner-device',
      ciphertextB64: 'AA==',
      createdAtMs: now - 5000,
      localState: 'sent',
      payloadEventId: 'gone-payload',
      disappearSeconds: 1,
      expiresAtMs: now - 1000,
    );
    expect(await controller.runDisappearingSweep(), 1);
    expect(
      await controller.disappearedPayloadIds('peer-1'),
      contains('gone-payload'),
    );
  });
}
