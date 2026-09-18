// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local group messages persist typed mentions in encrypted payload', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();
    final crypto = DartCryptoProvider(
      Uint8List.fromList(List<int>.generate(32, (index) => index)),
    );

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
      crypto: crypto,
    );

    try {
      final groupId = await controller.createGroup(
        title: 'Alpha Room',
        memberProfileIds: const <String>['peer-1'],
      );

      try {
        await controller.sendGroupMessage(
          groupId: groupId,
          text: 'Hi @peer-1 and @all',
          mentions: const <MsgMentionV1>[
            MsgMentionV1(
              type: MsgMentionV1.profileType,
              start: 3,
              end: 10,
              profileId: 'peer-1',
            ),
            MsgMentionV1(type: MsgMentionV1.allType, start: 15, end: 19),
          ],
        );
      } catch (_) {
        // Fanout fails because relay/keys/ratchet are not seeded in this test.
        // We only care that the local event with mentions was persisted before
        // the fanout was attempted.
      }

      final rows = await db.listEventsChronological(groupId, limit: 20);
      final messageRows = rows.where((row) {
        final eventId = (row['event_id'] as String?) ?? '';
        return eventId.startsWith('local:grp:');
      }).toList(growable: false);

      expect(messageRows, isNotEmpty);
      expect(messageRows.last['local_state'], 'pending');

      final localCiphertextB64 =
          ((messageRows.last['local_ciphertext_b64'] as String?) ?? '').trim();
      final storedCiphertextB64 = localCiphertextB64.isNotEmpty
          ? localCiphertextB64
          : ((messageRows.last['ciphertext_b64'] as String?) ?? '').trim();
      expect(storedCiphertextB64, isNotEmpty);

      final plainBytes = await crypto.decrypt(base64Decode(storedCiphertextB64));
      final payload = E2ePayloadV1.decode(plainBytes);
      final msg = payload.events.single as MsgEventV1;

      expect(msg.text, 'Hi @peer-1 and @all');
      expect(
        msg.mentions.map((mention) => mention.type).toList(growable: false),
        orderedEquals(const <String>[
          MsgMentionV1.profileType,
          MsgMentionV1.allType,
        ]),
      );
      expect(msg.mentions.first.profileId, 'peer-1');
    } finally {
      await db.close();
    }
  });
}