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

/// A1 ZERO-LOSS: a decrypted group message from a sender who is not yet in the
/// local roster (membership-convergence race) must NOT be dropped-and-acked
/// (that would lose it permanently — the relay DELETEs on ack and the ratchet
/// key is consumed so the wire can't be replayed). Instead it is parked as
/// plaintext and re-applied the moment the sender is confirmed a member.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = 'group:zero-loss-1';
  const msgEventId = 'grpmsg-1';
  const senderProfile = 'peer-new';
  const senderDevice = 'peer-new-device';

  String buildGroupControlText() {
    final envelope = <String, Object?>{
      'v': 1,
      'kind': 'message',
      'groupId': groupId,
      'groupTitle': 'Zero Loss Room',
      'msgEventId': msgEventId,
      'text': 'hello from a just-added member',
      'createdAtMs': 5000,
      'memberProfileIds': const <String>[
        'owner-1',
        'peer-existing',
        senderProfile,
      ],
      'senderProfileId': senderProfile,
    };
    return '__secretly_group_msg_v1__:'
        '${base64Url.encode(utf8.encode(jsonEncode(envelope)))}';
  }

  // Authoritative group (state_version > 0) whose local roster does NOT yet
  // include the sender — the exact condition that used to drop-and-lose the
  // frame.
  Future<AppDb> setupAuthoritativeGroupMissingSender() async {
    final db = await AppDb.openForTesting();
    await db.convoEnsureGroup(groupId: groupId, title: 'Zero Loss Room');
    await db.groupSettingsUpsert(
      groupId: groupId,
      ownerProfileId: 'owner-1',
      reactionsMode: 'all',
      allowText: true,
      allowMedia: true,
      allowAddMembers: true,
      allowPinMessages: true,
      allowChangeGroupInfo: true,
      allowChangeTag: true,
      joinApprovalRequired: false,
      slowModeSeconds: 0,
      chatHistoryVisible: true,
      membershipVersion: 1,
      stateVersion: 1,
    );
    await db.groupMemberEnsure(groupId: groupId, memberProfileId: 'owner-1');
    await db.groupMemberEnsure(
      groupId: groupId,
      memberProfileId: 'peer-existing',
    );
    return db;
  }

  AppController buildController(AppDb db) {
    final controller = AppController();
    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
      crypto: DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      ),
    );
    return controller;
  }

  Future<bool> deliverGroupMessage(AppController controller, AppDb db) async {
    final controlText = buildGroupControlText();
    final payload = E2ePayloadV1(
      senderDeviceId: senderDevice,
      createdAtMs: 5000,
      events: [MsgEventV1(eventId: 'wrapper-1', text: controlText)],
    );
    return controller.handleDecryptedInboundPayloadForTesting(
      db: db,
      msgId: 'transport-1',
      ciphertextB64: 'AA==',
      plainBytes: Uint8List.fromList(payload.encode()),
      payload: payload,
      senderDeviceId: senderDevice,
      senderProfileId: senderProfile,
      nowMs: 9000,
    );
  }

  bool hasMessageEvent(List<Map<String, Object?>> rows) =>
      rows.any((r) => r['payload_event_id'] == msgEventId);

  test(
    'non-member group message is parked (not lost) then re-applied on '
    'membership convergence',
    () async {
      final db = await setupAuthoritativeGroupMissingSender();
      final controller = buildController(db);
      try {
        // Deliver from a sender not yet in the roster.
        final handled = await deliverGroupMessage(controller, db);
        expect(handled, isTrue, reason: 'acked — we own the plaintext now');

        // It must be PARKED, never a visible event, never lost.
        expect(
          await db.deferredRoomInboundListForGroup(groupId),
          hasLength(1),
        );
        expect(
          hasMessageEvent(await db.listEvents(groupId, limit: 20)),
          isFalse,
          reason: 'not applied while the sender is not a member',
        );

        // Membership converges: the sender becomes a confirmed member.
        await db.groupMemberEnsure(
          groupId: groupId,
          memberProfileId: senderProfile,
        );
        await controller.flushDeferredRoomInboundForTesting(db, groupId);

        // The frame is now applied and the park entry is cleared.
        expect(await db.deferredRoomInboundListForGroup(groupId), isEmpty);
        expect(
          hasMessageEvent(await db.listEvents(groupId, limit: 20)),
          isTrue,
          reason: 'the parked frame is re-applied on convergence',
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'flush is a no-op while the sender is still not a member (keeps the frame '
    'parked for later)',
    () async {
      final db = await setupAuthoritativeGroupMissingSender();
      final controller = buildController(db);
      try {
        await deliverGroupMessage(controller, db);
        expect(
          await db.deferredRoomInboundListForGroup(groupId),
          hasLength(1),
        );

        // Flush WITHOUT adding the sender — must not apply and must not drop.
        await controller.flushDeferredRoomInboundForTesting(db, groupId);
        expect(
          await db.deferredRoomInboundListForGroup(groupId),
          hasLength(1),
          reason: 'still parked — sender not confirmed',
        );
        expect(
          hasMessageEvent(await db.listEvents(groupId, limit: 20)),
          isFalse,
        );
      } finally {
        await db.close();
      }
    },
  );

  test('parked frame is idempotent on synthetic id and TTL-prunable', () async {
    final db = await AppDb.openForTesting();
    try {
      Future<void> park(int createdAtMs) => db.deferredRoomInboundUpsert(
        syntheticEventId: 'grp:$msgEventId:$senderDevice',
        groupId: groupId,
        senderProfileId: senderProfile,
        senderDeviceId: senderDevice,
        commandText: 'x',
        msgId: 'transport-1',
        ciphertextB64: 'AA==',
        createdAtMs: createdAtMs,
      );

      await park(1000);
      await park(1000); // same synthetic id → still one row (idempotent)
      expect(await db.deferredRoomInboundCountAll(), 1);

      // Nothing older than 500 → no prune.
      expect(await db.deferredRoomInboundPrune(olderThanMs: 500), 0);
      expect(await db.deferredRoomInboundCountAll(), 1);

      // Row created at 1000 is <= 2000 → pruned (never-confirmed sender ages out).
      expect(await db.deferredRoomInboundPrune(olderThanMs: 2000), 1);
      expect(await db.deferredRoomInboundCountAll(), 0);
    } finally {
      await db.close();
    }
  });
}
