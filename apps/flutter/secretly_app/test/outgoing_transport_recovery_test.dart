// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/ratchet/double_ratchet_v3.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:secretly_app/transport/relay_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _StubKeysClient extends KeysClient {
  _StubKeysClient() : super(baseUrl: Uri.parse('https://example.test'));
}

class _RecoveringTransportAppController extends AppController {
  _RecoveringTransportAppController({
    required this.repairedStatuses,
    required this.onEnsureTransportReady,
  });

  final List<KeysDeviceStatus> repairedStatuses;
  final Future<void> Function(
    _RecoveringTransportAppController controller,
    bool includeAttachments,
  )
  onEnsureTransportReady;

  int readyCalls = 0;

  @override
  Future<List<KeysDeviceStatus>> loadRecipientDeviceStatuses(
    String peerProfileId,
  ) async {
    return repairedStatuses;
  }

  @override
  Future<bool> ensureOutgoingTransportReady({
    bool includeAttachments = false,
  }) async {
    readyCalls += 1;
    await onEnsureTransportReady(this, includeAttachments);
    return true;
  }
}

class _RequestNormalizingTransportAppController extends AppController {
  _RequestNormalizingTransportAppController({
    required this.peerProfileId,
    required this.deviceStatuses,
  });

  final String peerProfileId;
  final List<KeysDeviceStatus> deviceStatuses;

  @override
  Future<bool> ensureOutgoingTransportReady({
    bool includeAttachments = false,
  }) async {
    return true;
  }

  @override
  Future<List<KeysDeviceStatus>> loadRecipientDeviceStatuses(
    String requestedPeerProfileId,
  ) async {
    return requestedPeerProfileId == peerProfileId
        ? deviceStatuses
        : const <KeysDeviceStatus>[];
  }
}

RelayClient _buildRelayClient({
  required AppDb db,
  required SimpleKeyPair identityKeyPair,
  required MockClient httpClient,
  required Uri? httpBaseUrl,
  required String selfProfileId,
  required String deviceId,
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

  final secureStorageState = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    secureStorageState.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
          final arguments = Map<Object?, Object?>.from(
            call.arguments as Map<Object?, Object?>? ?? const {},
          );
          final key = arguments['key'] as String?;
          switch (call.method) {
            case 'read':
              return key == null ? null : secureStorageState[key];
            case 'write':
              if (key != null) {
                secureStorageState[key] = (arguments['value'] as String?) ?? '';
              }
              return null;
            case 'delete':
              if (key != null) {
                secureStorageState.remove(key);
              }
              return null;
            case 'deleteAll':
              secureStorageState.clear();
              return null;
            case 'containsKey':
              return key != null && secureStorageState.containsKey(key);
            case 'readAll':
              return Map<String, String>.from(secureStorageState);
          }
          return null;
        });
  });

  tearDown(() {
    secureStorageState.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  test(
    'sendMessage recovers missing runtime before queuing outgoing delivery',
    () async {
      const selfProfileId = 'self-profile';
      const selfDeviceId = 'device-self';
      const peerProfileId = 'peer-profile';
      const peerDeviceId = 'peer-device-1';

      final db = await AppDb.openForTesting();
      final prefs = await SharedPreferences.getInstance();
      final controller = _RecoveringTransportAppController(
        repairedStatuses: const <KeysDeviceStatus>[
          KeysDeviceStatus(
            deviceId: peerDeviceId,
            hasBundle: true,
            identityKeyPubB64: 'identity-key',
            signedPrekeyPubB64: 'signed-prekey',
            signedPrekeySigB64: 'signed-prekey-signature',
          ),
        ],
        onEnsureTransportReady: (controller, _) async {
          final relayIdentityKeyPair = await Ed25519().newKeyPair();
          final ratchetManager = _buildRatchetManager(db: db);
          final relay = _buildRelayClient(
            db: db,
            identityKeyPair: relayIdentityKeyPair,
            httpClient: MockClient((request) async {
              throw StateError('offline relay should not send HTTP');
            }),
            httpBaseUrl: null,
            selfProfileId: selfProfileId,
            deviceId: selfDeviceId,
          );

          controller.seedRoomRuntimeForTesting(
            db: db,
            profileId: selfProfileId,
            deviceId: selfDeviceId,
            crypto: DartCryptoProvider(
              Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
            ),
            ratchetV3: ratchetManager,
          );
          controller.seedKeysRuntimeForTesting(
            keys: _StubKeysClient(),
            prefs: prefs,
          );
          controller.seedRelayRuntimeForTesting(
            relay: relay,
            relayOnline: false,
          );

          final ratchet = DoubleRatchetV3();
          final senderSeed = Uint8List.fromList(
            List<int>.generate(32, (index) => index + 10),
          );
          final peerSeed = Uint8List.fromList(
            List<int>.generate(32, (index) => index + 90),
          );
          final rootKey = Uint8List.fromList(
            List<int>.generate(32, (index) => index + 150),
          );
          final senderKeyPair = await X25519().newKeyPairFromSeed(senderSeed);
          final peerKeyPair = await X25519().newKeyPairFromSeed(peerSeed);
          final peerPub = await peerKeyPair.extractPublicKey();
          final senderState = await ratchet.initInitiator(
            peerDeviceId: peerDeviceId,
            rootKey: rootKey,
            handshakeEphKeyPair: senderKeyPair,
            recipientSignedPrekeyPub: Uint8List.fromList(peerPub.bytes),
          );
          await _persistRatchetState(db: db, state: senderState);
        },
      );

      try {
        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: selfProfileId,
          deviceId: selfDeviceId,
          crypto: DartCryptoProvider(
            Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
          ),
        );
        controller.seedKeysRuntimeForTesting(
          keys: _StubKeysClient(),
          prefs: prefs,
        );

        await controller.sendMessage(
          peerProfileId: peerProfileId,
          text: 'hello from recovered runtime',
        );

        expect(controller.readyCalls, 1);

        final rows = await db.listEventsChronological(peerProfileId, limit: 10);
        expect(rows, hasLength(1));
        final localEventId = rows.single['event_id'] as String;
        expect(localEventId, startsWith('local:'));
        expect(rows.single['local_state'], MessageLocalState.pending);
        expect(await db.outboxCountForEventRef(localEventId), 1);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'sendMessage normalizes request conversation ids before fanout',
    () async {
      const selfProfileId = 'self-profile';
      const selfDeviceId = 'device-self';
      const peerProfileId = 'peer-profile';
      const peerDeviceId = 'device-peer';

      final controller = _RequestNormalizingTransportAppController(
        peerProfileId: peerProfileId,
        deviceStatuses: const <KeysDeviceStatus>[
          KeysDeviceStatus(
            deviceId: peerDeviceId,
            hasBundle: true,
            identityKeyPubB64: 'identity-key',
            signedPrekeyPubB64: 'signed-prekey',
            signedPrekeySigB64: 'signed-prekey-sig',
          ),
        ],
      );
      final db = await AppDb.openForTesting();
      final prefs = await SharedPreferences.getInstance();
      final relayIdentityKeyPair = await Ed25519().newKeyPair();
      final ratchetManager = _buildRatchetManager(db: db);
      final relay = _buildRelayClient(
        db: db,
        identityKeyPair: relayIdentityKeyPair,
        httpClient: MockClient((request) async {
          throw StateError('offline relay should not send HTTP');
        }),
        httpBaseUrl: null,
        selfProfileId: selfProfileId,
        deviceId: selfDeviceId,
      );

      try {
        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: selfProfileId,
          deviceId: selfDeviceId,
          crypto: DartCryptoProvider(
            Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
          ),
          ratchetV3: ratchetManager,
        );
        controller.seedKeysRuntimeForTesting(
          keys: _StubKeysClient(),
          prefs: prefs,
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: false);

        await db.requestUpsert(profileId: peerProfileId, status: 'pending');
        await db.convoEnsureRequest(peerProfileId: peerProfileId);

        final ratchet = DoubleRatchetV3();
        final senderSeed = Uint8List.fromList(
          List<int>.generate(32, (index) => index + 31),
        );
        final peerSeed = Uint8List.fromList(
          List<int>.generate(32, (index) => index + 131),
        );
        final rootKey = Uint8List.fromList(
          List<int>.generate(32, (index) => index + 41),
        );
        final senderKeyPair = await X25519().newKeyPairFromSeed(senderSeed);
        final peerKeyPair = await X25519().newKeyPairFromSeed(peerSeed);
        final peerPub = await peerKeyPair.extractPublicKey();
        final senderState = await ratchet.initInitiator(
          peerDeviceId: peerDeviceId,
          rootKey: rootKey,
          handshakeEphKeyPair: senderKeyPair,
          recipientSignedPrekeyPub: Uint8List.fromList(peerPub.bytes),
        );
        await _persistRatchetState(db: db, state: senderState);

        await controller.sendMessage(
          peerProfileId: 'req:$peerProfileId',
          text: 'reply after accept',
        );

        expect(await db.requestStatus(peerProfileId), isNull);
        expect(await db.contactGet(peerProfileId), isNotNull);
        expect(await db.contactGet('req:$peerProfileId'), isNull);
        expect(await db.convoGet('req:$peerProfileId'), isNull);

        final directRows = await db.listEventsChronological(
          peerProfileId,
          limit: 10,
        );
        expect(directRows, hasLength(1));
        expect(directRows.single['convo_id'], peerProfileId);

        final outboxRows = await db.outboxDue(limit: 10);
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single['to_device_id'], peerDeviceId);
        expect(outboxRows.single['convo_id'], peerProfileId);
      } finally {
        await db.close();
      }
    },
  );
}
