// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/storage/app_db.dart';

// К-3 (17.09.2026): участник, у которого нет квитанции на моё сообщение
// комнаты, получает повтор ТОГО ЖЕ конверта — один раз.

String _envelope(String msgEventId) =>
    '__secretly_group_msg_v1__:'
    '${base64Url.encode(utf8.encode(jsonEncode({
      'v': 1,
      'kind': 'message',
      'groupId': 'group:heal',
      'msgEventId': msgEventId,
      'text': 'привет',
    })))}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // К-3 выключен в выпуске (ревью 17.09); здесь проверяется сам механизм.
  setUp(() => AppController.roomMissedResendEnabled = true);
  tearDown(() => AppController.roomMissedResendEnabled = false);

  test('🔴 пропуск — один повтор того же конверта; с квитанцией — ничего',
      () async {
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    final controller = AppController()
      ..seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: DartCryptoProvider(
          Uint8List.fromList(List<int>.generate(32, (i) => i)),
        ),
      );
    final sent = <String>[];
    controller.roomResendSenderForTesting = (member, envelope) async {
      sent.add('$member:$envelope');
    };
    for (final id in const ['m-missed', 'm-received']) {
      await db.insertEvent(
        eventId: 'local-$id',
        convoId: 'group:heal',
        type: 'msg',
        senderDeviceId: 'owner-device',
        ciphertextB64: 'AA==',
        createdAtMs: 1000,
        localState: 'sent',
        payloadEventId: id,
      );
      await controller.rememberRoomEnvelopeForTesting(
        'group:heal',
        _envelope(id),
      );
    }
    await db.roomMessageReceiptUpsert(
      payloadEventId: 'm-received',
      readerProfileId: 'peer-1',
      readerDeviceId: 'peer-device',
      status: 'delivered',
      updatedAtMs: 2000,
    );

    final first = await controller.resendMissedRoomMessagesForTesting(
      roomId: 'group:heal',
      memberProfileId: 'peer-1',
      stuckBeforeMs: 5000,
    );
    expect(first, 1);
    expect(sent, ['peer-1:${_envelope('m-missed')}']);

    final again = await controller.resendMissedRoomMessagesForTesting(
      roomId: 'group:heal',
      memberProfileId: 'peer-1',
      stuckBeforeMs: 5000,
    );
    expect(again, 0, reason: 'повтор — один раз на пару «сообщение–участник»');
  });

  test('старые конверты вычищаются', () async {
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    await db.roomOutboundEnvelopePut(
      payloadEventId: 'old',
      roomId: 'group:heal',
      envelope: _envelope('old'),
      createdAtMs: 1,
    );
    await db.roomOutboundPrune(olderThanMs: 10);
    expect(await db.roomOutboundEnvelopeGet('old'), isNull);
  });
}
