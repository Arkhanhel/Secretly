// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 КАРТОЧКА ССЫЛКИ ПРОХОДИТ ВСЕ ДОРОГИ СООБЩЕНИЯ.
//
// Превью готовит отправитель и кладёт в сообщение (решение владельца
// 16.09.2026). У сообщения несколько дорог, и на части из них оно
// собирается заново из отдельных полей — там карточка терялась бы молча:
//   • комната: по проводу едет не сообщение, а конверт комнаты;
//   • копия своим устройствам: свой конверт;
//   • отложенная отправка: заготовка, из которой сообщение собирается в срок;
//   • правка: сообщение пересобирается с новым текстом.
//
// Попутно закреплена найденная здесь же ошибка: правка сообщения в теме
// теряла тему, и сообщение переезжало в «Общий».

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

const _preview = LinkPreviewV1(
  url: 'https://example.com/post',
  siteName: 'example.com',
  title: 'Заголовок',
  description: 'Описание',
);

final _thumb = Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 74, 70, 73, 70, 0, 1, 1, 0, 0, 1, //
]);

DartCryptoProvider _crypto() => DartCryptoProvider(
  Uint8List.fromList(List<int>.generate(32, (index) => index)),
);

/// Расшифрованное сообщение, как его увидит лента.
Future<MsgEventV1?> _stored(
  AppController controller,
  AppDb db,
  String convoId, {
  required bool Function(Map<String, Object?> row) where,
}) async {
  final rows = await db.listEventsChronological(convoId, limit: 50);
  final row = rows.lastWhere(where, orElse: () => const <String, Object?>{});
  if (row.isEmpty) return null;
  final event = ChatEvent(
    eventId: row['event_id'] as String,
    createdAtMs: (row['created_at_ms'] as num?)?.toInt() ?? 0,
    type: (row['type'] as String?) ?? '',
    ciphertextB64: (row['ciphertext_b64'] as String?) ?? '',
    localCiphertextB64: row['local_ciphertext_b64'] as String?,
    senderDeviceId: (row['sender_device_id'] as String?) ?? '',
    localState: (row['local_state'] as String?) ?? 'received',
    payloadEventId: row['payload_event_id'] as String?,
    scheduledAtMs: (row['scheduled_at_ms'] as num?)?.toInt(),
  );
  final payload = await controller.payloadEventForChatEvent(event);
  return payload is MsgEventV1 ? payload : null;
}

bool _idStarts(Map<String, Object?> row, String prefix) =>
    ((row['event_id'] as String?) ?? '').startsWith(prefix);

Future<bool> _deliver(
  AppController controller,
  AppDb db, {
  required String msgId,
  required MsgEventV1 event,
  required String senderDeviceId,
  required String senderProfileId,
  int createdAtMs = 5000,
}) {
  final payload = E2ePayloadV1(
    senderDeviceId: senderDeviceId,
    createdAtMs: createdAtMs,
    events: [event],
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('secretly-link-preview-');
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
  });

  tearDown(() => db.close());

  Future<String> room() => controller.createGroup(
    title: 'Alpha Room',
    memberProfileIds: const <String>['peer-1'],
  );

  Future<void> sendToRoom(
    String groupId,
    String text, {
    LinkPreviewV1? preview,
    String? topicId,
    int? scheduledAtMs,
  }) async {
    try {
      await controller.sendGroupMessage(
        groupId: groupId,
        text: text,
        linkPreview: preview,
        topicId: topicId,
        scheduledAtMs: scheduledAtMs,
      );
    } catch (_) {
      // Реле в тесте нет — рассылка падает. Важна местная запись, которая
      // делается до рассылки.
    }
  }

  test('🔴 сообщение в комнату хранит карточку', () async {
    final groupId = await room();
    await sendToRoom(groupId, 'смотри https://example.com/post', preview: _preview);
    final msg = await _stored(
      controller,
      db,
      groupId,
      where: (r) => _idStarts(r, 'local:grp:'),
    );
    expect(msg, isNotNull);
    expect(msg!.linkPreview?.url, 'https://example.com/post');
    expect(msg.linkPreview?.title, 'Заголовок');
  });

  test('🔴 карточка от другой ссылки не уходит вовсе', () async {
    final groupId = await room();
    await sendToRoom(groupId, 'смотри https://bank.example/login', preview: _preview);
    final msg = await _stored(
      controller,
      db,
      groupId,
      where: (r) => _idStarts(r, 'local:grp:'),
    );
    expect(msg, isNotNull);
    expect(msg!.linkPreview, isNull);
  });

  test('🔴 отложенное сообщение в комнату хранит карточку до срока', () async {
    final groupId = await room();
    final later = DateTime.now().millisecondsSinceEpoch + 3600 * 1000;
    await sendToRoom(
      groupId,
      'https://example.com/post',
      preview: _preview,
      scheduledAtMs: later,
    );
    final msg = await _stored(
      controller,
      db,
      groupId,
      where: (r) => _idStarts(r, 'local:grpsched:'),
    );
    expect(msg, isNotNull);
    expect(msg!.linkPreview?.url, 'https://example.com/post');
  });

  test('🔴 правка сохраняет и тему, и карточку', () async {
    final groupId = await room();
    await sendToRoom(
      groupId,
      'было https://example.com/post',
      preview: _preview,
      topicId: 'topic-7',
    );
    final before = await _stored(
      controller,
      db,
      groupId,
      where: (r) => _idStarts(r, 'local:grp:'),
    );
    expect(before?.topicId, 'topic-7');

    final changed = await controller.editTextMessage(
      convoId: groupId,
      payloadEventId: before!.eventId,
      text: 'стало https://example.com/post',
    );
    expect(changed, isTrue);

    final after = await _stored(
      controller,
      db,
      groupId,
      where: (r) => _idStarts(r, 'local:grp:'),
    );
    expect(after?.text, 'стало https://example.com/post');
    expect(after?.topicId, 'topic-7', reason: 'сообщение уехало из темы');
    expect(after?.linkPreview?.url, 'https://example.com/post');
  });

  test('🔴 правка сохраняет упоминания', () async {
    // Компьютер правил сообщение без разметки, и «@Игорь» терял подсветку,
    // значок и уведомление — в том числе на телефоне, куда правка зеркалится.
    final groupId = await room();
    await sendToRoom(groupId, 'привет @Игорь');
    final before = await _stored(
      controller,
      db,
      groupId,
      where: (r) => _idStarts(r, 'local:grp:'),
    );
    expect(before, isNotNull);

    final changed = await controller.editTextMessage(
      convoId: groupId,
      payloadEventId: before!.eventId,
      text: 'снова @Игорь',
      mentions: <MsgMentionV1>[
        const MsgMentionV1(
          type: MsgMentionV1.profileType,
          profileId: 'igor-1',
          start: 6,
          end: 12,
        ),
      ],
    );
    expect(changed, isTrue);

    final after = await _stored(
      controller,
      db,
      groupId,
      where: (r) => _idStarts(r, 'local:grp:'),
    );
    expect(after?.text, 'снова @Игорь');
    expect(after?.mentions.length, 1, reason: 'упоминание пропало при правке');
    expect(after?.mentions.first.profileId, 'igor-1');
    expect(
      after!.text.substring(
        after.mentions.first.start,
        after.mentions.first.end,
      ),
      '@Игорь',
    );
  });

  test('🔴 входящее в комнату: карточка из конверта доходит до ленты', () async {
    await _deliver(
      controller,
      db,
      msgId: 'transport-snapshot',
      senderDeviceId: 'owner-device-2',
      senderProfileId: 'owner-1',
      createdAtMs: 3000,
      event: MsgEventV1(
        eventId: 'evt-snapshot',
        text: AppController.encodeRoomInviteCommandForTesting(
          <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:alpha',
            'groupTitle': 'Alpha Room',
            'ownerProfileId': 'owner-1',
            'stateVersion': 3,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[],
          },
        ),
      ),
    );

    final envelope = AppController.encodeGroupMessageCommandForTesting(
      <String, Object?>{
        'v': 1,
        'groupId': 'group:alpha',
        'groupTitle': 'Alpha Room',
        'kind': 'message',
        'msgEventId': 'group-msg-1',
        'text': 'вот https://example.com/post',
        'createdAtMs': 5000,
        'memberProfileIds': const <String>['owner-1', 'peer-1'],
        'senderProfileId': 'peer-1',
        'linkPreview': LinkPreviewV1(
          url: _preview.url,
          siteName: _preview.siteName,
          title: _preview.title,
          thumbnail: _thumb,
        ).toJson(),
      },
    );
    expect(
      await _deliver(
        controller,
        db,
        msgId: 'transport-msg-1',
        senderDeviceId: 'peer-device',
        senderProfileId: 'peer-1',
        event: MsgEventV1(eventId: 'wrap-1', text: envelope),
      ),
      isTrue,
    );

    final msg = await _stored(
      controller,
      db,
      'group:alpha',
      where: (r) => r['payload_event_id'] == 'group-msg-1',
    );
    expect(msg, isNotNull, reason: 'сообщение комнаты не сохранилось');
    expect(msg!.text, 'вот https://example.com/post');
    expect(msg.linkPreview?.title, 'Заголовок');
    expect(msg.linkPreview?.thumbnail, _thumb);
  });

  test('входящее в личку: карточка сохраняется как пришла', () async {
    await db.contactUpsert(profileId: 'peer-1', displayName: 'Пётр');
    expect(
      await _deliver(
        controller,
        db,
        msgId: 'transport-dm-1',
        senderDeviceId: 'peer-device',
        senderProfileId: 'peer-1',
        event: MsgEventV1(
          eventId: 'dm-1',
          text: 'https://example.com/post',
          linkPreview: _preview,
        ),
      ),
      isTrue,
    );
    final msg = await _stored(
      controller,
      db,
      'peer-1',
      where: (r) => r['payload_event_id'] == 'dm-1',
    );
    expect(msg?.linkPreview?.url, 'https://example.com/post');
  });

  test('🔴 копия со своего устройства приходит с карточкой', () async {
    controller.seedKnownOwnDeviceIdsForTesting(const ['owner-device-2']);
    final cmd =
        '__secretly_self_mirror_msg_v1__:'
        '${base64Url.encode(utf8.encode(jsonEncode(<String, Object?>{
          'kind': 'msg',
          'convoId': 'peer-1',
          'msgEventId': 'mirror-1',
          'text': 'https://example.com/post',
          'replyToPayloadEventId': null,
          'createdAtMs': 5000,
          'linkPreview': _preview.toJson(),
        })))}';
    await _deliver(
      controller,
      db,
      msgId: 'transport-mirror-1',
      senderDeviceId: 'owner-device-2',
      senderProfileId: 'owner-1',
      event: MsgEventV1(eventId: 'wrap-mirror-1', text: cmd),
    );
    final msg = await _stored(
      controller,
      db,
      'peer-1',
      where: (r) => r['payload_event_id'] == 'mirror-1',
    );
    expect(msg, isNotNull, reason: 'копия не сохранилась');
    expect(msg!.linkPreview?.title, 'Заголовок');
  });

  test('копия от прежней версии (без карточки) принимается как раньше', () async {
    controller.seedKnownOwnDeviceIdsForTesting(const ['owner-device-2']);
    final cmd =
        '__secretly_self_mirror_msg_v1__:'
        '${base64Url.encode(utf8.encode(jsonEncode(<String, Object?>{
          'kind': 'msg',
          'convoId': 'peer-1',
          'msgEventId': 'mirror-2',
          'text': 'https://example.com/post',
          'createdAtMs': 5000,
        })))}';
    await _deliver(
      controller,
      db,
      msgId: 'transport-mirror-2',
      senderDeviceId: 'owner-device-2',
      senderProfileId: 'owner-1',
      event: MsgEventV1(eventId: 'wrap-mirror-2', text: cmd),
    );
    final msg = await _stored(
      controller,
      db,
      'peer-1',
      where: (r) => r['payload_event_id'] == 'mirror-2',
    );
    expect(msg?.text, 'https://example.com/post');
    expect(msg?.linkPreview, isNull);
  });

  test('🔴 пути отправки передают карточку дальше (по исходнику)', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();
    String body(String signature) {
      final start = src.indexOf(signature);
      expect(start, isNot(-1), reason: signature);
      final open = src.indexOf(') async {', start);
      final end = src.indexOf('\n  }\n', open);
      return src.substring(start, end);
    }

    // Отложенная личка: в срок сообщение собирается из заготовки.
    expect(
      body('  Future<void> _fireScheduledDirectMessage({'),
      contains('linkPreview: msgEvent.linkPreview'),
    );
    // Отложенная комната и повтор неудачной отправки в комнату.
    expect(
      body('  Future<void> _fireScheduledGroupMessage({'),
      contains('linkPreview: msgEvent.linkPreview'),
    );
    expect(
      body('  Future<void> _retryOutgoingGroupEventSend({'),
      contains('linkPreview: textEvent.linkPreview'),
    );
    // Личка: и собеседнику, и своим устройствам, и в отложенную заготовку.
    final send = body('  Future<void> sendMessage({');
    expect(
      'linkPreview: outgoingPreview'.allMatches(send).length,
      4,
      reason: 'себе, отложенно, собеседнику, своим устройствам',
    );
    final sched = body('  Future<void> _scheduleDirectMessage({');
    expect('linkPreview: linkPreview'.allMatches(sched).length, 2);
    // Конверты комнаты — сейчас и отложенно.
    expect(
      body('  Future<void> _dispatchGroupMessageNow({'),
      contains("'linkPreview': linkPreview.toJson()"),
    );
    expect(
      body('  Future<void> _scheduleGroupMessage({'),
      contains("'linkPreview': linkPreview.toJson()"),
    );
    expect(
      body('  Future<void> _mirrorTextMessageToOwnDevices({'),
      contains("'linkPreview': linkPreview.toJson()"),
    );
  });
}
