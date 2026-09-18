// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ratchet/double_ratchet_v3.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:secretly_app/transport/relay_client.dart';
import 'package:secretly_app/ui/chat_screen.dart'
    show resolveChatMarkReadPeerProfileId;

RelayClient _buildRelayClient({
  required AppDb db,
  required SimpleKeyPair identityKeyPair,
  required MockClient httpClient,
  required Uri? httpBaseUrl,
  String selfProfileId = 'self-profile',
  String deviceId = 'device-self',
}) {
  return RelayClient(
    db: db,
    deviceId: deviceId,
    selfProfileId: selfProfileId,
    deviceKeys: DeviceKeys.create(),
    wsUrl: Uri.parse('ws://example.test/ws'),
    httpBaseUrl: httpBaseUrl,
    httpClient: httpClient,
    identityKeyPairOverride: identityKeyPair,
    onDelivered: ({required msgId, required ciphertextB64}) async => true,
    loadNextSeq: () async => 1,
    saveNextSeq: (_) async {},
  );
}

RatchetSessionManagerV3 _buildRatchetManager({required AppDb db}) {
  return RatchetSessionManagerV3(
    db: db,
    deviceKeys: DeviceKeys.create(),
    keysClient: KeysClient(baseUrl: Uri.parse('https://example.test')),
  );
}

Future<void> _persistRatchetState({
  required AppDb db,
  required DoubleRatchetStateV3 state,
}) {
  return db.sessionV3Upsert(
    peerDeviceId: state.peerDeviceId,
    rootKeyB64: base64Encode(state.rootKey),
    dhSelfSeedB64: base64Encode(state.dhSelfSeed),
    dhSelfPubB64: base64Encode(state.dhSelfPub),
    dhRemotePubB64: state.dhRemotePub == null
        ? null
        : base64Encode(state.dhRemotePub!),
    sendChainKeyB64: state.sendChainKey == null
        ? null
        : base64Encode(state.sendChainKey!),
    recvChainKeyB64: state.recvChainKey == null
        ? null
        : base64Encode(state.recvChainKey!),
    ns: state.ns,
    nr: state.nr,
    pn: state.pn,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'group chat mark-read target falls back to convoId when peerProfileIdForSend is absent',
    () {
      expect(
        resolveChatMarkReadPeerProfileId(
          convoId: 'group:alpha',
          peerProfileIdForSend: null,
        ),
        'group:alpha',
      );
      expect(
        resolveChatMarkReadPeerProfileId(
          convoId: 'peer-alpha',
          peerProfileIdForSend: 'peer-alpha',
        ),
        'peer-alpha',
      );
      expect(
        resolveChatMarkReadPeerProfileId(
          convoId: 'peer-alpha',
          peerProfileIdForSend: '   ',
        ),
        isNull,
      );
    },
  );

  test(
    'markChatRead marks room events read locally without transport and includes rows without payload refs',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'self-profile',
        deviceId: 'device-self',
      );

      try {
        const convoId = 'group:alpha';
        await db.insertEvent(
          eventId: 'room-event-1',
          convoId: convoId,
          type: 'msg',
          senderDeviceId: 'device-peer-1',
          ciphertextB64: 'cipher-1',
          createdAtMs: 1,
          payloadEventId: 'payload-1',
        );
        await db.insertEvent(
          eventId: 'room-event-2',
          convoId: convoId,
          type: 'msg',
          senderDeviceId: 'device-peer-2',
          ciphertextB64: 'cipher-2',
          createdAtMs: 2,
        );

        await controller.markChatRead(peerProfileId: convoId);

        final rows = await db.listEventsChronological(convoId, limit: 10);
        expect(rows, hasLength(2));
        for (final row in rows) {
          expect((row['read_at_ms'] as num?)?.toInt(), isNotNull);
        }
      } finally {
        await db.close();
      }
    },
  );

  test(
    'acceptRequest promotes request history and queues read receipts',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'self-profile',
        deviceId: 'device-self',
      );

      try {
        await db.requestUpsert(profileId: 'peer-1', status: 'pending');
        await db.convoEnsureRequest(peerProfileId: 'peer-1');
        await db.insertEvent(
          eventId: 'msg-request-1',
          convoId: 'req:peer-1',
          type: 'msg',
          senderDeviceId: 'device-peer-1',
          ciphertextB64: 'cipher-request-1',
          createdAtMs: 10,
          payloadEventId: 'payload-request-1',
        );

        await controller.acceptRequest('req:peer-1');

        expect(await db.requestStatus('peer-1'), isNull);
        expect(await db.contactGet('peer-1'), isNotNull);
        expect(await db.convoGet('req:peer-1'), isNull);

        final rows = await db.listEventsChronological('peer-1', limit: 10);
        expect(rows, hasLength(1));
        expect((rows.single['read_at_ms'] as num?)?.toInt(), isNotNull);

        final pendingReceipts = await db.pendingReceiptList(limit: 10);
        expect(pendingReceipts, hasLength(1));
        expect(pendingReceipts.single.peerDeviceId, 'device-peer-1');
        expect(pendingReceipts.single.peerProfileId, 'peer-1');
        expect(pendingReceipts.single.payloadEventId, 'payload-request-1');
        expect(pendingReceipts.single.status, MessageReceiptState.read);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'room receipt dispatch planning batches by sender and skips unresolved or self targets',
    () {
      final targets = planRoomReadReceiptDispatchTargets(
        unreadRows: const <Map<String, Object?>>[
          {
            'sender_device_id': 'device-peer-1',
            'created_at_ms': 20,
            'payload_event_id': 'payload-2',
          },
          {
            'sender_device_id': 'device-peer-1',
            'created_at_ms': 10,
            'payload_event_id': 'payload-1',
          },
          {
            'sender_device_id': 'device-peer-2',
            'created_at_ms': 30,
            'payload_event_id': 'payload-3',
          },
          {
            'sender_device_id': 'device-self',
            'created_at_ms': 40,
            'payload_event_id': 'payload-self',
          },
          {
            'sender_device_id': 'device-unknown',
            'created_at_ms': 50,
            'payload_event_id': 'payload-4',
          },
          {
            'sender_device_id': 'device-peer-3',
            'created_at_ms': 60,
            'payload_event_id': null,
          },
        ],
        senderProfileIdByDeviceId: const <String, String?>{
          'device-peer-1': 'peer-1',
          'device-peer-2': 'self-profile',
          'device-self': 'self-profile',
          'device-unknown': null,
          'device-peer-3': 'peer-3',
        },
        selfProfileId: 'self-profile',
        isOwnDeviceId: (senderDeviceId) => senderDeviceId == 'device-self',
      );

      expect(targets, hasLength(1));
      expect(targets.single.peerProfileId, 'peer-1');
      expect(targets.single.peerDeviceId, 'device-peer-1');
      expect(
        targets.single.payloadEventIds,
        orderedEquals(const <String>['payload-1', 'payload-2']),
      );
    },
  );

  test('unread helpers include room events without payload refs', () async {
    final db = await AppDb.openForTesting();

    try {
      const convoId = 'group:beta';
      await db.insertEvent(
        eventId: 'room-unread-1',
        convoId: convoId,
        type: 'msg',
        senderDeviceId: 'device-peer-1',
        ciphertextB64: 'cipher-1',
        createdAtMs: 1,
        payloadEventId: 'payload-1',
      );
      await db.insertEvent(
        eventId: 'room-unread-2',
        convoId: convoId,
        type: 'msg',
        senderDeviceId: 'device-peer-2',
        ciphertextB64: 'cipher-2',
        createdAtMs: 2,
      );
      await db.insertEvent(
        eventId: 'room-own-event',
        convoId: convoId,
        type: 'msg',
        senderDeviceId: 'device-self',
        ciphertextB64: 'cipher-self',
        createdAtMs: 3,
      );

      expect(
        await db.countUnreadForConvo(
          convoId: convoId,
          selfDeviceId: 'device-self',
        ),
        2,
      );
      expect(
        await db.countUnreadForConvos(
          convoIds: const <String>[convoId],
          selfDeviceId: 'device-self',
        ),
        <String, int>{convoId: 2},
      );

      final latest = await db.latestUnreadIncomingForConvo(
        convoId: convoId,
        selfDeviceId: 'device-self',
      );
      expect(latest, isNotNull);
      expect(latest!.senderDeviceId, 'device-peer-2');
      expect(latest.payloadEventId, isEmpty);
    } finally {
      await db.close();
    }
  });

  test('unread helpers exclude additional known own device ids', () async {
    final db = await AppDb.openForTesting();

    try {
      const convoId = 'peer-alpha';
      await db.insertEvent(
        eventId: 'peer-unread-1',
        convoId: convoId,
        type: 'msg',
        senderDeviceId: 'device-peer-1',
        ciphertextB64: 'cipher-peer',
        createdAtMs: 1,
        payloadEventId: 'payload-peer-1',
      );
      await db.insertEvent(
        eventId: 'own-mirror-1',
        convoId: convoId,
        type: 'msg',
        senderDeviceId: 'device-self-2',
        ciphertextB64: 'cipher-own',
        createdAtMs: 2,
        payloadEventId: 'payload-own-1',
      );

      expect(
        await db.countUnreadForConvo(
          convoId: convoId,
          selfDeviceId: 'device-self-1',
          excludedSenderDeviceIds: const <String>['device-self-2'],
        ),
        1,
      );
      expect(
        await db.countUnreadForConvos(
          convoIds: const <String>[convoId],
          selfDeviceId: 'device-self-1',
          excludedSenderDeviceIds: const <String>['device-self-2'],
        ),
        <String, int>{convoId: 1},
      );

      final unreadRows = await db.listUnreadIncomingForConvo(
        convoId: convoId,
        selfDeviceId: 'device-self-1',
        excludedSenderDeviceIds: const <String>['device-self-2'],
      );
      expect(unreadRows, hasLength(1));
      expect(unreadRows.single['sender_device_id'], 'device-peer-1');

      final latest = await db.latestUnreadIncomingForConvo(
        convoId: convoId,
        selfDeviceId: 'device-self-1',
        excludedSenderDeviceIds: const <String>['device-self-2'],
      );
      expect(latest, isNotNull);
      expect(latest!.senderDeviceId, 'device-peer-1');
    } finally {
      await db.close();
    }
  });

  test(
    'controller unread count excludes events from known own devices',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'self-profile',
        deviceId: 'device-self-1',
      );
      controller.seedKnownOwnDeviceIdsForTesting(const <String>[
        'device-self-2',
      ]);

      try {
        await db.insertEvent(
          eventId: 'peer-unread-2',
          convoId: 'peer-alpha',
          type: 'msg',
          senderDeviceId: 'device-peer-1',
          ciphertextB64: 'cipher-peer-2',
          createdAtMs: 1,
        );
        await db.insertEvent(
          eventId: 'own-mirror-2',
          convoId: 'peer-alpha',
          type: 'msg',
          senderDeviceId: 'device-self-2',
          ciphertextB64: 'cipher-own-2',
          createdAtMs: 2,
        );

        expect(await controller.unreadCountForConvo('peer-alpha'), 1);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'inbound room receipts persist ledger rows and keep highest receipt status',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'self-profile',
        deviceId: 'device-self',
      );

      try {
        await db.deviceProfileUpsert(
          deviceId: 'device-peer-1',
          profileId: 'peer-1',
        );
        await db.insertEvent(
          eventId: 'local-room-outgoing',
          convoId: 'group:alpha',
          type: 'msg',
          senderDeviceId: 'device-self',
          ciphertextB64: 'cipher-local',
          createdAtMs: 1,
          localState: MessageLocalState.sent,
          payloadEventId: 'payload-local',
        );

        final readPayload = E2ePayloadV1(
          senderDeviceId: 'device-peer-1',
          createdAtMs: 10,
          events: [
            ReceiptEventV1(
              eventId: 'receipt-read-1',
              refEventId: 'payload-local',
              status: MessageReceiptState.read,
            ),
          ],
        );

        final handledRead = await controller
            .handleDecryptedInboundPayloadForTesting(
              db: db,
              msgId: 'receipt-msg-read',
              ciphertextB64: 'cipher-rcpt-read',
              plainBytes: Uint8List.fromList(readPayload.encode()),
              payload: readPayload,
              senderDeviceId: 'device-peer-1',
              nowMs: 10,
            );

        expect(handledRead, isTrue);

        final rowsAfterRead = await db.listEventsChronological(
          'group:alpha',
          limit: 10,
        );
        expect(rowsAfterRead.single['local_state'], MessageLocalState.read);

        final receiptRowsAfterRead = await db.roomMessageReceiptList(
          'payload-local',
        );
        expect(receiptRowsAfterRead, hasLength(1));
        expect(receiptRowsAfterRead.single.readerProfileId, 'peer-1');
        expect(receiptRowsAfterRead.single.readerDeviceId, 'device-peer-1');
        expect(receiptRowsAfterRead.single.status, MessageReceiptState.read);

        final deliveredPayload = E2ePayloadV1(
          senderDeviceId: 'device-peer-1',
          createdAtMs: 11,
          events: [
            ReceiptEventV1(
              eventId: 'receipt-delivered-1',
              refEventId: 'payload-local',
              status: MessageReceiptState.delivered,
            ),
          ],
        );

        final handledDelivered = await controller
            .handleDecryptedInboundPayloadForTesting(
              db: db,
              msgId: 'receipt-msg-delivered',
              ciphertextB64: 'cipher-rcpt-delivered',
              plainBytes: Uint8List.fromList(deliveredPayload.encode()),
              payload: deliveredPayload,
              senderDeviceId: 'device-peer-1',
              nowMs: 11,
            );

        expect(handledDelivered, isTrue);

        final rowsAfterDelivered = await db.listEventsChronological(
          'group:alpha',
          limit: 10,
        );
        expect(
          rowsAfterDelivered.single['local_state'],
          MessageLocalState.read,
        );

        final summary = await db.roomMessageReceiptSummary('payload-local');
        expect(summary.deliveredCount, 1);
        expect(summary.readCount, 1);
        expect(
          summary.deliveredByProfileIds,
          orderedEquals(const <String>['peer-1']),
        );
        expect(
          summary.readByProfileIds,
          orderedEquals(const <String>['peer-1']),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'room read receipts queue while disconnected and flush after reconnect',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final peerDb = await AppDb.openForTesting();
      final relayIdentityKeyPair = await Ed25519().newKeyPair();
      final senderRatchet = _buildRatchetManager(db: db);
      final peerRatchet = _buildRatchetManager(db: peerDb);
      final ratchet = DoubleRatchetV3();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'self-profile',
        deviceId: 'device-self',
        ratchetV3: senderRatchet,
      );

      final offlineRelay = _buildRelayClient(
        db: db,
        identityKeyPair: relayIdentityKeyPair,
        httpClient: MockClient((request) async {
          throw StateError('offline relay should not send HTTP');
        }),
        httpBaseUrl: null,
      );
      controller.seedRelayRuntimeForTesting(
        relay: offlineRelay,
        relayOnline: false,
      );

      try {
        await db.deviceProfileUpsert(
          deviceId: 'device-peer-1',
          profileId: 'peer-1',
        );

        final senderSeed = Uint8List.fromList(
          List<int>.generate(32, (index) => index + 1),
        );
        final peerSeed = Uint8List.fromList(
          List<int>.generate(32, (index) => index + 101),
        );
        final rootKey = Uint8List.fromList(
          List<int>.generate(32, (index) => 200 + index),
        );
        final senderKeyPair = await X25519().newKeyPairFromSeed(senderSeed);
        final peerKeyPair = await X25519().newKeyPairFromSeed(peerSeed);
        final peerPub = await peerKeyPair.extractPublicKey();

        final senderState = await ratchet.initInitiator(
          peerDeviceId: 'device-peer-1',
          rootKey: rootKey,
          handshakeEphKeyPair: senderKeyPair,
          recipientSignedPrekeyPub: Uint8List.fromList(peerPub.bytes),
        );
        await _persistRatchetState(db: db, state: senderState);

        final peerState = await ratchet.initResponder(
          peerDeviceId: 'device-self',
          rootKey: rootKey,
          recipientSignedPrekeyKeyPair: peerKeyPair,
          initiatorDhPub: senderState.dhSelfPub,
        );
        await _persistRatchetState(db: peerDb, state: peerState);

        await db.insertEvent(
          eventId: 'room-offline-1',
          convoId: 'group:alpha',
          type: 'msg',
          senderDeviceId: 'device-peer-1',
          ciphertextB64: 'cipher-1',
          createdAtMs: 1,
          payloadEventId: 'payload-1',
        );
        await db.insertEvent(
          eventId: 'room-offline-2',
          convoId: 'group:alpha',
          type: 'msg',
          senderDeviceId: 'device-peer-1',
          ciphertextB64: 'cipher-2',
          createdAtMs: 2,
          payloadEventId: 'payload-2',
        );

        await controller.markChatRead(peerProfileId: 'group:alpha');

        final localRows = await db.listEventsChronological(
          'group:alpha',
          limit: 10,
        );
        expect(localRows, hasLength(2));
        for (final row in localRows) {
          expect((row['read_at_ms'] as num?)?.toInt(), isNotNull);
        }

        final queuedCounts = await controller.outboxStateCounts();
        expect(queuedCounts[OutboxSendState.pending], 1);

        final queuedRows = await db.outboxDue(limit: 10);
        expect(queuedRows, hasLength(1));
        expect(queuedRows.single['to_device_id'], 'device-peer-1');
        expect(queuedRows.single['state'], OutboxSendState.pending);

        final queuedPayload = E2ePayloadV1.decode(
          await peerRatchet.decryptFromWire(
            selfProfileId: 'peer-1',
            selfDeviceId: 'device-peer-1',
            wireBytes: base64Decode(
              queuedRows.single['ciphertext_b64'] as String,
            ),
          ),
        );
        expect(queuedPayload.senderDeviceId, 'device-self');

        final receiptEvents = queuedPayload.events
            .whereType<ReceiptEventV1>()
            .toList(growable: false);
        expect(receiptEvents, hasLength(2));
        expect(
          receiptEvents
              .map((event) => event.refEventId)
              .toList(growable: false),
          orderedEquals(const <String>['payload-1', 'payload-2']),
        );
        expect(receiptEvents.map((event) => event.status).toSet(), <String>{
          MessageReceiptState.read,
        });

        var sendRequests = 0;
        final onlineRelay = _buildRelayClient(
          db: db,
          identityKeyPair: relayIdentityKeyPair,
          httpClient: MockClient((request) async {
            sendRequests += 1;
            expect(request.method, 'POST');
            expect(request.url.path, '/v1/send');
            return http.Response('{}', 200);
          }),
          httpBaseUrl: Uri.parse('https://example.test'),
        );
        controller.seedRelayRuntimeForTesting(
          relay: onlineRelay,
          relayOnline: true,
        );

        await controller.forceOutboxPump();

        final finalCounts = await controller.outboxStateCounts();
        expect(finalCounts[OutboxSendState.sent], 1);
        expect(await db.outboxDue(limit: 10), isEmpty);
        expect(sendRequests, 1);
      } finally {
        await peerDb.close();
        await db.close();
      }
    },
  );

  test(
    'markChatRead persists pending receipts until ratchet runtime becomes available',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final peerDb = await AppDb.openForTesting();
      final relayIdentityKeyPair = await Ed25519().newKeyPair();
      final senderRatchet = _buildRatchetManager(db: db);
      final peerRatchet = _buildRatchetManager(db: peerDb);
      final ratchet = DoubleRatchetV3();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'self-profile',
        deviceId: 'device-self',
      );

      try {
        await db.insertEvent(
          eventId: 'direct-read-1',
          convoId: 'peer-1',
          type: 'msg',
          senderDeviceId: 'device-peer-1',
          ciphertextB64: 'cipher-1',
          createdAtMs: 1,
          payloadEventId: 'payload-read-1',
        );
        await db.insertEvent(
          eventId: 'direct-read-2',
          convoId: 'peer-1',
          type: 'msg',
          senderDeviceId: 'device-peer-1',
          ciphertextB64: 'cipher-2',
          createdAtMs: 2,
          payloadEventId: 'payload-read-2',
        );

        await controller.markChatRead(peerProfileId: 'peer-1');

        expect(await db.pendingReceiptCount(), 2);
        expect(await db.outboxDue(limit: 10), isEmpty);

        final senderSeed = Uint8List.fromList(
          List<int>.generate(32, (index) => index + 11),
        );
        final peerSeed = Uint8List.fromList(
          List<int>.generate(32, (index) => index + 111),
        );
        final rootKey = Uint8List.fromList(
          List<int>.generate(32, (index) => 210 + index),
        );
        final senderKeyPair = await X25519().newKeyPairFromSeed(senderSeed);
        final peerKeyPair = await X25519().newKeyPairFromSeed(peerSeed);
        final peerPub = await peerKeyPair.extractPublicKey();

        final senderState = await ratchet.initInitiator(
          peerDeviceId: 'device-peer-1',
          rootKey: rootKey,
          handshakeEphKeyPair: senderKeyPair,
          recipientSignedPrekeyPub: Uint8List.fromList(peerPub.bytes),
        );
        await _persistRatchetState(db: db, state: senderState);

        final peerState = await ratchet.initResponder(
          peerDeviceId: 'device-self',
          rootKey: rootKey,
          recipientSignedPrekeyKeyPair: peerKeyPair,
          initiatorDhPub: senderState.dhSelfPub,
        );
        await _persistRatchetState(db: peerDb, state: peerState);

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'self-profile',
          deviceId: 'device-self',
          ratchetV3: senderRatchet,
        );
        controller.seedRelayRuntimeForTesting(
          relay: _buildRelayClient(
            db: db,
            identityKeyPair: relayIdentityKeyPair,
            httpClient: MockClient((request) async {
              throw StateError('offline relay should not send HTTP');
            }),
            httpBaseUrl: null,
          ),
          relayOnline: false,
        );

        await controller.forceOutboxPump();

        expect(await db.pendingReceiptCount(), 0);
        final queuedRows = await db.outboxDue(limit: 10);
        expect(queuedRows, hasLength(1));

        final queuedPayload = E2ePayloadV1.decode(
          await peerRatchet.decryptFromWire(
            selfProfileId: 'peer-1',
            selfDeviceId: 'device-peer-1',
            wireBytes: base64Decode(
              queuedRows.single['ciphertext_b64'] as String,
            ),
          ),
        );
        final receiptEvents = queuedPayload.events
            .whereType<ReceiptEventV1>()
            .toList(growable: false);
        expect(receiptEvents, hasLength(2));
        expect(
          receiptEvents
              .map((event) => event.refEventId)
              .toList(growable: false),
          orderedEquals(const <String>['payload-read-1', 'payload-read-2']),
        );
        expect(receiptEvents.map((event) => event.status).toSet(), <String>{
          MessageReceiptState.read,
        });
      } finally {
        await peerDb.close();
        await db.close();
      }
    },
  );

  test('delivered receipts persist until runtime is restored', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();
    final peerDb = await AppDb.openForTesting();
    final relayIdentityKeyPair = await Ed25519().newKeyPair();
    final senderRatchet = _buildRatchetManager(db: db);
    final peerRatchet = _buildRatchetManager(db: peerDb);
    final ratchet = DoubleRatchetV3();

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'self-profile',
      deviceId: 'device-self',
    );

    try {
      await db.contactUpsert(profileId: 'peer-1', displayName: 'Peer 1');
      await db.deviceProfileUpsert(
        deviceId: 'device-peer-1',
        profileId: 'peer-1',
      );

      final inboundPayload = E2ePayloadV1(
        senderDeviceId: 'device-peer-1',
        createdAtMs: 10,
        events: [MsgEventV1(eventId: 'payload-delivered-1', text: 'hello')],
      );

      final handled = await controller.handleDecryptedInboundPayloadForTesting(
        db: db,
        msgId: 'msg-delivered-1',
        ciphertextB64: 'cipher-delivered-1',
        plainBytes: Uint8List.fromList(inboundPayload.encode()),
        payload: inboundPayload,
        senderDeviceId: 'device-peer-1',
        senderProfileId: 'peer-1',
        nowMs: 10,
      );

      expect(handled, isTrue);
      expect(await db.pendingReceiptCount(), 1);
      expect(await db.outboxDue(limit: 10), isEmpty);

      final senderSeed = Uint8List.fromList(
        List<int>.generate(32, (index) => index + 21),
      );
      final peerSeed = Uint8List.fromList(
        List<int>.generate(32, (index) => index + 121),
      );
      final rootKey = Uint8List.fromList(
        List<int>.generate(32, (index) => 220 + index),
      );
      final senderKeyPair = await X25519().newKeyPairFromSeed(senderSeed);
      final peerKeyPair = await X25519().newKeyPairFromSeed(peerSeed);
      final peerPub = await peerKeyPair.extractPublicKey();

      final senderState = await ratchet.initInitiator(
        peerDeviceId: 'device-peer-1',
        rootKey: rootKey,
        handshakeEphKeyPair: senderKeyPair,
        recipientSignedPrekeyPub: Uint8List.fromList(peerPub.bytes),
      );
      await _persistRatchetState(db: db, state: senderState);

      final peerState = await ratchet.initResponder(
        peerDeviceId: 'device-self',
        rootKey: rootKey,
        recipientSignedPrekeyKeyPair: peerKeyPair,
        initiatorDhPub: senderState.dhSelfPub,
      );
      await _persistRatchetState(db: peerDb, state: peerState);

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'self-profile',
        deviceId: 'device-self',
        ratchetV3: senderRatchet,
      );
      controller.seedRelayRuntimeForTesting(
        relay: _buildRelayClient(
          db: db,
          identityKeyPair: relayIdentityKeyPair,
          httpClient: MockClient((request) async {
            throw StateError('offline relay should not send HTTP');
          }),
          httpBaseUrl: null,
        ),
        relayOnline: false,
      );

      await controller.forceOutboxPump();

      expect(await db.pendingReceiptCount(), 0);
      final queuedRows = await db.outboxDue(limit: 10);
      expect(queuedRows, hasLength(1));

      final queuedPayload = E2ePayloadV1.decode(
        await peerRatchet.decryptFromWire(
          selfProfileId: 'peer-1',
          selfDeviceId: 'device-peer-1',
          wireBytes: base64Decode(
            queuedRows.single['ciphertext_b64'] as String,
          ),
        ),
      );
      final receiptEvents = queuedPayload.events
          .whereType<ReceiptEventV1>()
          .toList(growable: false);
      expect(receiptEvents, hasLength(1));
      expect(receiptEvents.single.refEventId, 'payload-delivered-1');
      expect(receiptEvents.single.status, MessageReceiptState.delivered);
    } finally {
      await peerDb.close();
      await db.close();
    }
  });
}
