// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/storage/app_db.dart';

// К-3 v2 (06.10.2026): участник, у которого нет квитанции на моё сообщение
// комнаты, получает повтор ЗАПЕЧАТАННОГО провода — один раз, только то, что
// отправлено после его вступления, и только пока сообщение существует.
// Первая версия (17.09) была выключена на ревью по четырём причинам — каждая
// проверяется здесь.

const _room = 'group:heal';
const _joinedAt = 900000;
const _now = 1000000 + 60 * 60 * 1000;

Future<(AppDb, AppController, List<String>)> _setUp() async {
  final db = await AppDb.openForTesting();
  final controller = AppController()
    ..seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
      crypto: DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (i) => i)),
      ),
    );
  await db.groupMembershipStatesReplace(
    groupId: _room,
    states: [
      (
        profileId: 'owner-1',
        status: 'active',
        role: 'owner',
        sourceLinkId: null,
        tag: null,
        createdAtMs: 1,
        updatedAtMs: 1,
      ),
      (
        profileId: 'peer-1',
        status: 'active',
        role: 'member',
        sourceLinkId: null,
        tag: null,
        createdAtMs: _joinedAt,
        updatedAtMs: _joinedAt,
      ),
    ],
  );
  final sent = <String>[];
  controller.roomResendSenderForTesting = (member, wire) async {
    sent.add('$member:$wire');
  };
  return (db, controller, sent);
}

Future<void> _myMessage(
  AppDb db,
  String id, {
  int at = 1000000,
  bool withWire = true,
}) async {
  await db.insertEvent(
    eventId: 'local-$id',
    convoId: _room,
    type: 'msg',
    senderDeviceId: 'owner-device',
    ciphertextB64: 'AA==',
    createdAtMs: at,
    localState: 'sent',
    payloadEventId: id,
  );
  if (withWire) {
    await db.roomOutboundWirePut(
      payloadEventId: id,
      roomId: _room,
      epoch: 1,
      wireB64: 'wire-$id',
      createdAtMs: at,
    );
  }
}

Future<int> _resend(AppController c) => c.resendMissedRoomMessagesForTesting(
  roomId: _room,
  memberProfileId: 'peer-1',
  stuckBeforeMs: _now,
  nowMs: _now,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 пропуск — один повтор провода; с квитанцией — ничего', () async {
    final (db, controller, sent) = await _setUp();
    addTearDown(db.close);
    await _myMessage(db, 'm-missed');
    await _myMessage(db, 'm-received');
    await db.roomMessageReceiptUpsert(
      payloadEventId: 'm-received',
      readerProfileId: 'peer-1',
      readerDeviceId: 'peer-device',
      status: 'delivered',
      updatedAtMs: 2000,
    );

    expect(await _resend(controller), 1);
    expect(sent, ['peer-1:wire-m-missed']);
    expect(await _resend(controller), 0,
        reason: 'повтор — один раз на пару «сообщение–участник»');
  });

  test('🔴 сообщения до вступления участнику не повторяются', () async {
    final (db, controller, sent) = await _setUp();
    addTearDown(db.close);
    await _myMessage(db, 'before-join', at: _joinedAt - 1);
    expect(await _resend(controller), 0);
    expect(sent, isEmpty);
  });

  test('🔴 окно не забивается: повторённые не занимают предел', () async {
    final (db, controller, sent) = await _setUp();
    addTearDown(db.close);
    for (var i = 0; i < 12; i++) {
      await _myMessage(db, 'm$i', at: 1000000 + i);
    }
    expect(await _resend(controller), 10);
    expect(await _resend(controller), 2,
        reason: 'первая версия здесь навсегда застревала на тех же десяти');
    expect(sent.toSet(), hasLength(12));
  });

  test('без запечатанного провода повторять нечем', () async {
    final (db, controller, sent) = await _setUp();
    addTearDown(db.close);
    await _myMessage(db, 'pairwise-only', withWire: false);
    expect(await _resend(controller), 0);
    expect(sent, isEmpty);
  });

  test('🔴 удалённое не повторяется и его провод стирается', () async {
    final (db, controller, sent) = await _setUp();
    addTearDown(db.close);
    await _myMessage(db, 'gone-for-all');
    await _myMessage(db, 'gone-for-me');
    // «Удалить у всех» — провод стирается сразу.
    await db.roomOutboundWiresDelete(<String>['gone-for-all']);
    expect(await db.roomOutboundWireGet('gone-for-all'), isNull);
    // «Удалить у себя» / исчезающее — событие ушло, провод — на обходе.
    await db.deleteEventsByIds(<String>['local-gone-for-me']);
    await db.roomOutboundPrune(olderThanMs: 0);
    expect(await db.roomOutboundWireGet('gone-for-me'), isNull);
    expect(await _resend(controller), 0);
    expect(sent, isEmpty);
  });

  test('провода старше окна вычищаются', () async {
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    await _myMessage(db, 'old', at: 1);
    await db.roomOutboundPrune(olderThanMs: 10);
    expect(await db.roomOutboundWireGet('old'), isNull);
  });

  group('где это включено', () {
    final ctrl = File('lib/app/app_controller.dart').readAsStringSync();

    test('🔴 открытый конверт больше не хранится', () {
      expect(ctrl.contains('_rememberRoomEnvelope('), isFalse);
      expect(ctrl.contains('roomOutboundEnvelopePut('), isFalse);
      expect(
        RegExp(r'await _rememberRoomWire\(').allMatches(ctrl).length,
        4,
        reason: 'текст, вложение, наклейка, альбом',
      );
    });

    test('остатки первой версии стираются на каждом обходе', () {
      final at = ctrl.indexOf('await db.roomOutboundEnvelopesClear();');
      expect(at, greaterThan(0));
      final before = ctrl.substring(at - 300, at);
      expect(before.contains('if (!roomMissedResendEnabled)'), isFalse);
    });

    test('«удалить у всех» стирает провода при отправке', () {
      final at = ctrl.indexOf('Future<int> _dispatchGroupMessageNow({');
      final body = ctrl.substring(at, at + 1500);
      expect(body.contains('roomOutboundWiresDelete('), isTrue);
    });

    test('повтор идёт сырым проводом через реле, не попарной сессией', () {
      final at = ctrl.indexOf('Future<int> _resendMissedRoomMessages({');
      final end = ctrl.indexOf('Future<int> resendMissedRoomMessagesForTesting(');
      final body = ctrl.substring(at, end);
      expect(body.contains('broadcastRoomWire('), isTrue);
      expect(body.contains('roomKeyRawReadyDevices('), isTrue);
      expect(body.contains('sendControlMessage('), isFalse);
    });
  });
}
