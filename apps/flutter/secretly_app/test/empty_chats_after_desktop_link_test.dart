// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Пустые чаты с id после привязки ПК (28.09.2026).
//
// Жалоба владельца: после привязки телефона к компьютеру появлялись пустые
// чаты, названные id, — «как будто взломали аккаунт». Причина: телефон слал
// данные привязки через sendAttachment на ВРЕМЕННЫЙ профиль экрана QR, и
// приём запроса записывал этот профиль в контакты и заводил чат. Разбор —
// docs/audit/ПУСТЫЕ_ЧАТЫ_ПОСЛЕ_ПРИВЯЗКИ_2026-09-28.md.
//
// Сторожат четыре правки:
//   1. передача без следа в истории не принимает адресата и не заводит чат;
//   2–3. разовая уборка пустых безымянных чатов мёртвых профилей;
//   4. невидимое событие от незнакомца не заводит чат.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';

String _controllerSource() =>
    File('lib/app/app_controller.dart').readAsStringSync();

/// Тело функции от её объявления до следующего объявления на том же отступе.
String _functionBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: 'не найдено: $signature');
  final next = RegExp(
    r'\n  (?:@visibleForTesting\n  )?(?:static )?(?:Future<[^\n]*>|void|bool|String|int) [_a-zA-Z0-9]+\(',
  ).firstMatch(source.substring(start + signature.length));
  final end = next == null ? source.length : start + signature.length + next.start;
  return source.substring(start, end);
}

void main() {
  group('4. какие входящие события видны в личном чате', () {
    test('обычный текст виден', () {
      expect(
        AppController.inboundEventIsVisibleMessage(
          MsgEventV1(eventId: 'e1', text: 'привет'),
        ),
        isTrue,
      );
    });

    test('скрытая служебная строка не видна', () {
      expect(
        AppController.inboundEventIsVisibleMessage(
          MsgEventV1(
            eventId: 'e2',
            text: '${kSecretlyHiddenCommandPrefix}profile_sync:{}',
          ),
        ),
        isFalse,
      );
    });

    test('команда удаления у всех не видна', () {
      expect(
        AppController.inboundEventIsVisibleMessage(
          MsgEventV1(eventId: 'e3', text: '${kDeleteForAllCommandPrefix}abc'),
        ),
        isFalse,
      );
    });

    test('системное событие не видно', () {
      expect(
        AppController.inboundEventIsVisibleMessage(
          SystemEventV1(eventId: 'e4', text: 'ключ сменился'),
        ),
        isFalse,
      );
    });

    test('событие неизвестного типа от более новой сборки не видно', () {
      expect(
        AppController.inboundEventIsVisibleMessage(
          UnknownEventV1(raw: const {'kind': 'future_kind'}),
        ),
        isFalse,
      );
      expect(AppController.inboundEventIsVisibleMessage(null), isFalse);
    });
  });

  group('2–3. уборка пустых безымянных чатов', () {
    late AppDb db;
    const own = 'SELF-PROFILE';

    Future<void> event(String convo, String type, String id) =>
        db.insertEvent(
          eventId: id,
          convoId: convo,
          type: type,
          senderDeviceId: 'dev-x',
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
        );

    setUp(() async {
      db = await AppDb.openForTesting();
      // Временный профиль привязки: принят в контакты без имени, чат пуст.
      await db.requestAccept(profileId: 'TEMP-LINK');
      // Контакт с именем, которое дал сам человек.
      await db.convoEnsure1to1(peerProfileId: 'NAMED');
      await db.contactUpsert(
        profileId: 'NAMED',
        displayName: 'Мама',
        displayNameIsCustom: true,
      );
      // Собеседник с ником из профиля.
      await db.convoEnsure1to1(peerProfileId: 'NICK');
      // Тестовая база не «лечит» столбцы profile_meta, поэтому ник — напрямую.
      await db.rawInsertForTesting(
        'INSERT INTO profile_meta (profile_id, nickname, updated_at_ms) VALUES (?, ?, ?)',
        ['NICK', 'Аня', 1000],
      );
      // Была переписка — чат не пустой.
      await db.convoEnsure1to1(peerProfileId: 'TALKED');
      await event('TALKED', 'msg', 'm1');
      // Только невидимая служебная запись.
      await db.convoEnsure1to1(peerProfileId: 'SYSONLY');
      await event('SYSONLY', 'sys', 's1');
      // Свой чат («Избранное»).
      await db.convoEnsure1to1(peerProfileId: own);
      // Беседа по неопознанному устройству.
      await db.convoEnsure1to1(peerProfileId: 'dev:abc');
    });

    tearDown(() async => db.close());

    Future<Set<String>> candidates() async => (await db
            .emptyNamelessDirectChatIds(
              ownProfileId: own,
              createdBeforeMs: DateTime.now().millisecondsSinceEpoch + 60000,
            ))
        .toSet();

    test('находит только пустые безымянные чаты', () async {
      expect(await candidates(), {'TEMP-LINK', 'SYSONLY', 'dev:abc'});
    });

    test('свежие чаты моложе порога не трогает', () async {
      final ids = await db.emptyNamelessDirectChatIds(
        ownProfileId: own,
        createdBeforeMs: 0,
      );
      expect(ids, isEmpty);
    });

    test('удаляет чат временного профиля вместе с контактом', () async {
      expect(await db.contactGet('TEMP-LINK'), isNotNull);
      expect(await db.removeEmptyDirectChat('TEMP-LINK'), isTrue);
      expect(await db.convoGet('TEMP-LINK'), isNull);
      expect(await db.contactGet('TEMP-LINK'), isNull);
    });

    test('чат с перепиской удалить нельзя', () async {
      expect(await db.removeEmptyDirectChat('TALKED'), isFalse);
      expect(await db.convoGet('TALKED'), isNotNull);
    });

    test('если настоящее сообщение пришло между поиском и удалением — чат остаётся',
        () async {
      expect(await candidates(), contains('SYSONLY'));
      await event('SYSONLY', 'msg', 'm2');
      expect(await db.removeEmptyDirectChat('SYSONLY'), isFalse);
      expect(await db.convoGet('SYSONLY'), isNotNull);
    });

    test('имя, данное человеком, не стирается', () async {
      await db.removeEmptyDirectChat('NAMED');
      final contact = await db.contactGet('NAMED');
      expect(contact, isNotNull);
    });
  });

  group('сторожа исходника', () {
    test('1. данные привязки ПК не принимают адресата и не заводят чат', () {
      final body = _functionBody(
        _controllerSource(),
        'Future<String> sendAttachment({',
      );
      final gate = body.indexOf('if (includeInLocalHistory) {\n      final readyForDirectChat =');
      final accept = body.indexOf('_ensureDirectConversationReadyForOutgoing(');
      expect(gate, isNonNegative,
          reason: 'приём адресата должен стоять под includeInLocalHistory');
      expect(accept, greaterThan(gate),
          reason: 'приём адресата вызван до проверки includeInLocalHistory');
    });

    test('4. невидимое от незнакомца отбрасывается ДО приёма запроса', () {
      final body = _functionBody(
        _controllerSource(),
        'Future<bool> _handleDecryptedInboundPayload({',
      );
      final drop = body.indexOf("'drop_invisible_from_unknown'");
      final promote = body.indexOf('await db.requestAccept(profileId: spid);');
      expect(drop, isNonNegative);
      expect(promote, greaterThan(drop));
    });

    test('2–3. уборка идёт из обслуживания и сверяется с сервером', () {
      final source = _controllerSource();
      final maintenance = _functionBody(
        source,
        'Future<void> _runConversationMaintenance(AppDb db) async {',
      );
      expect(maintenance, contains('_cleanupDeadEmptyDirectChatsOnce(db)'));
      final cleanup = _functionBody(
        source,
        'Future<void> _cleanupDeadEmptyDirectChatsOnce(AppDb db) async {',
      );
      expect(cleanup, contains('loadRecipientDeviceStatuses(convoId)).isEmpty'));
      expect(cleanup, contains('KeysPolicyFailureCode.profileNotFound'));
      expect(cleanup, contains('deferred++'));
    });
  });
}
