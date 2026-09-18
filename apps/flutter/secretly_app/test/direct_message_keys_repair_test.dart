// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/security/auth_signer.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubKeysClient extends KeysClient {
  _StubKeysClient() : super(baseUrl: Uri.parse('https://example.com'));
}

class _BundleFetchingKeysClient extends KeysClient {
  _BundleFetchingKeysClient({
    required this.devices,
    this.expectedRequesterDeviceId,
    this.expectedProfileId,
    this.identityPublicKey,
  })
    : super(baseUrl: Uri.parse('https://example.com'));

  final List<Map<String, Object?>> devices;
  final String? expectedRequesterDeviceId;
  final String? expectedProfileId;
  final SimplePublicKey? identityPublicKey;

  @override
  Future<List<Map<String, Object?>>> fetchBundle(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    if (expectedRequesterDeviceId != null) {
      expect(profileId, expectedProfileId);
      expect(requesterDeviceId, expectedRequesterDeviceId);
      expect(tsMs, isNotNull);
      expect(nonceB64, isNotNull);
      expect(signatureB64, isNotNull);

      final message = AuthSigner.keysFetchBundleMessage(
        requesterDeviceId: requesterDeviceId!,
        profileId: profileId,
        tsMs: tsMs!,
        nonceB64: nonceB64!,
      );
      final signature = Signature(
        base64Decode(signatureB64!),
        publicKey: identityPublicKey!,
      );
      final isValid = await Ed25519().verify(message, signature: signature);
      expect(isValid, isTrue);
    }
    return devices;
  }
}

class _SignatureCheckingKeysClient extends KeysClient {
  _SignatureCheckingKeysClient({
    required this.expectedRequesterDeviceId,
    required this.identityPublicKey,
  }) : super(baseUrl: Uri.parse('https://example.com'));

  final String expectedRequesterDeviceId;
  final SimplePublicKey identityPublicKey;

  @override
  Future<List<KeysDeviceStatus>> listDeviceStatuses(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    expect(requesterDeviceId, expectedRequesterDeviceId);
    expect(tsMs, isNotNull);
    expect(nonceB64, isNotNull);
    expect(signatureB64, isNotNull);

    final message = AuthSigner.keysListDevicesMessage(
      requesterDeviceId: requesterDeviceId!,
      profileId: profileId,
      tsMs: tsMs!,
      nonceB64: nonceB64!,
    );
    final signature = Signature(
      base64Decode(signatureB64!),
      publicKey: identityPublicKey,
    );
    final isValid = await Ed25519().verify(message, signature: signature);
    expect(isValid, isTrue);

    return const <KeysDeviceStatus>[];
  }
}

class _ChallengeReplayKeysClient extends KeysClient {
  _ChallengeReplayKeysClient({
    required this.profileId,
    required this.deviceId,
  }) : super(baseUrl: Uri.parse('https://example.com'));

  final String profileId;
  final String deviceId;

  int challengeCalls = 0;
  int registerCalls = 0;
  int publishCalls = 0;
  final Set<String> consumedNonces = <String>{};

  @override
  Future<bool> profileExists(String requestedProfileId) async {
    expect(requestedProfileId, profileId);
    return true;
  }

  @override
  Future<DeviceChallenge> deviceChallenge({
    required String profileId,
    required String deviceId,
    required String profileSecretB64,
  }) async {
    expect(profileId, this.profileId);
    expect(deviceId, this.deviceId);
    challengeCalls += 1;
    return DeviceChallenge(
      nonceB64: 'nonce-$challengeCalls',
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
    );
  }

  @override
  Future<bool> registerDeviceProof({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
    KeysDeviceClass deviceClass = KeysDeviceClass.mobile,
    String? deviceLabel,
    String? replacesDeviceId,
  }) async {
    expect(profileId, this.profileId);
    expect(deviceId, this.deviceId);
    registerCalls += 1;

    if (!consumedNonces.add(nonceB64)) {
      return false;
    }
    if (registerCalls == 1) {
      throw StateError('transient register failure after challenge consume');
    }
    return true;
  }

  @override
  Future<bool> publishKeys({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required String signedPrekeyPubB64,
    required String signedPrekeySigB64,
    required List<Map<String, Object?>> oneTimePrekeys,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
    String? accountIdentityPubB64,
    String? deviceCertB64,
  }) async {
    expect(profileId, this.profileId);
    expect(deviceId, this.deviceId);
    publishCalls += 1;
    return true;
  }
}

class _ConcurrentChallengeKeysClient extends KeysClient {
  _ConcurrentChallengeKeysClient({
    required this.profileId,
    required this.deviceId,
  }) : super(baseUrl: Uri.parse('https://example.com'));

  final String profileId;
  final String deviceId;

  int challengeCalls = 0;
  int registerCalls = 0;
  int publishCalls = 0;
  int overlapRejects = 0;
  String? latestNonce;
  bool published = false;

  @override
  Future<bool> profileExists(String requestedProfileId) async {
    expect(requestedProfileId, profileId);
    return true;
  }

  @override
  Future<List<String>> listDevices(
    String requestedProfileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    expect(requestedProfileId, profileId);
    return <String>[deviceId];
  }

  @override
  Future<List<KeysDeviceStatus>> listDeviceStatuses(
    String requestedProfileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    expect(requestedProfileId, profileId);
    return <KeysDeviceStatus>[
      KeysDeviceStatus(deviceId: deviceId, hasBundle: published),
    ];
  }

  @override
  Future<DeviceChallenge> deviceChallenge({
    required String profileId,
    required String deviceId,
    required String profileSecretB64,
  }) async {
    expect(profileId, this.profileId);
    expect(deviceId, this.deviceId);
    challengeCalls += 1;
    latestNonce = 'nonce-$challengeCalls';
    return DeviceChallenge(
      nonceB64: latestNonce!,
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
    );
  }

  @override
  Future<bool> registerDeviceProof({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
    KeysDeviceClass deviceClass = KeysDeviceClass.mobile,
    String? deviceLabel,
    String? replacesDeviceId,
  }) async {
    expect(profileId, this.profileId);
    expect(deviceId, this.deviceId);
    registerCalls += 1;

    if (registerCalls == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    final ok = nonceB64 == latestNonce;
    if (!ok) {
      overlapRejects += 1;
    }
    return ok;
  }

  @override
  Future<bool> publishKeys({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required String signedPrekeyPubB64,
    required String signedPrekeySigB64,
    required List<Map<String, Object?>> oneTimePrekeys,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
    String? accountIdentityPubB64,
    String? deviceCertB64,
  }) async {
    expect(profileId, this.profileId);
    expect(deviceId, this.deviceId);
    publishCalls += 1;
    published = true;
    return true;
  }
}

class _RepairingAppController extends AppController {
  _RepairingAppController({
    required this.initialError,
    required this.repairedStatuses,
  });

  final Object initialError;
  final List<KeysDeviceStatus> repairedStatuses;

  int deviceStatusLoads = 0;
  int repairCalls = 0;

  @override
  Future<List<KeysDeviceStatus>> loadRecipientDeviceStatuses(
    String peerProfileId,
  ) async {
    deviceStatusLoads += 1;
    if (deviceStatusLoads == 1) {
      throw initialError;
    }
    return repairedStatuses;
  }

  @override
  Future<bool> repairMissingCurrentDeviceKeysRegistration() async {
    repairCalls += 1;
    return true;
  }
}

class _BundleFallbackAppController extends AppController {
  _BundleFallbackAppController({required this.initialError});

  final Object initialError;

  int deviceStatusLoads = 0;

  @override
  Future<List<KeysDeviceStatus>> loadRecipientDeviceStatuses(
    String peerProfileId,
  ) async {
    deviceStatusLoads += 1;
    throw initialError;
  }
}

Future<Map<String, Object?>> _signedBundleDevice({
  required String deviceId,
  required SimpleKeyPair identityKeyPair,
  required List<int> signedPrekeyPubBytes,
}) async {
  final identityPublicKey = await identityKeyPair.extractPublicKey();
  final signatureB64 = await AuthSigner.signEd25519B64(
    identityKeyPair: identityKeyPair,
    message: Uint8List.fromList(signedPrekeyPubBytes),
  );
  return <String, Object?>{
    'device_id': deviceId,
    'identity_key_pub_b64': base64Encode(identityPublicKey.bytes),
    'signed_prekey_pub_b64': base64Encode(signedPrekeyPubBytes),
    'signed_prekey_sig_b64': signatureB64,
    'one_time_prekey': <String, Object?>{
      'prekey_id': 1,
      'prekey_pub_b64': base64Encode(List<int>.filled(32, 9)),
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStorageState = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
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
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  const repairedStatuses = <KeysDeviceStatus>[
    KeysDeviceStatus(
      deviceId: 'peer-device-1',
      hasBundle: true,
      identityKeyPubB64: 'identity-key',
      signedPrekeyPubB64: 'signed-prekey',
      signedPrekeySigB64: 'signed-prekey-signature',
    ),
  ];

  for (final scenario in <({String name, String errorText})>[
    (
      name: 'unknown requester device',
      errorText: 'listDeviceStatuses failed: 401 unknown requester device',
    ),
    (
      name: 'requester device missing identity key',
      errorText:
          'listDeviceStatuses failed: 401 requester device missing identity key',
    ),
    (
      name: 'bad signature',
      errorText: 'listDeviceStatuses failed: 401 bad signature',
    ),
  ]) {
    test(
      'refreshContactDevices retries after ${scenario.name} repair',
      () async {
        final controller = _RepairingAppController(
          initialError: StateError(scenario.errorText),
          repairedStatuses: repairedStatuses,
        );
        final db = await AppDb.openForTesting();

        try {
          controller.seedRoomRuntimeForTesting(
            db: db,
            profileId: 'self-profile',
            deviceId: 'self-device',
          );
          controller.seedKeysRuntimeForTesting(keys: _StubKeysClient());

          await controller.refreshContactDevices('peer-profile-1');

          final rows = await db.contactDevicesList('peer-profile-1');
          expect(controller.repairCalls, 1);
          expect(controller.deviceStatusLoads, 2);
          expect(rows, hasLength(1));
          expect(rows.single['device_id'], 'peer-device-1');
        } finally {
          await db.close();
        }
      },
    );
  }

  test('loadRecipientDeviceStatuses signs with the sent ts and nonce', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();

    try {
      const selfProfileId = 'self-profile';
      const selfDeviceId = 'self-device';
      final deviceKeys = DeviceKeys.create();
      final identityKeyPair = await deviceKeys.loadIdentityKeyPair(
        profileId: selfProfileId,
        deviceId: selfDeviceId,
      );
      final identityPublicKey = await identityKeyPair.extractPublicKey();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: selfProfileId,
        deviceId: selfDeviceId,
      );
      controller.seedKeysRuntimeForTesting(
        keys: _SignatureCheckingKeysClient(
          expectedRequesterDeviceId: selfDeviceId,
          identityPublicKey: identityPublicKey,
        ),
      );

      final statuses = await controller.loadRecipientDeviceStatuses(
        'peer-profile-1',
      );

      expect(statuses, isEmpty);
    } finally {
      await db.close();
    }
  });

  test(
    'ensureKeysSetup retries register proof with a fresh challenge after transient failure',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final prefs = await SharedPreferences.getInstance();
      const profileId = 'profile-register-retry-1';
      const deviceId = 'device-register-retry-1';
      const profileSecret = 'c2VjcmV0';
      final keys = _ChallengeReplayKeysClient(
        profileId: profileId,
        deviceId: deviceId,
      );

      try {
        await prefs.setString('profile_id', profileId);
        await prefs.setString('device_id', deviceId);
        secureStorageState['secretly/profile_secret_v1_b64/$profileId'] =
            profileSecret;

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: profileId,
          deviceId: deviceId,
        );
        controller.seedKeysRuntimeForTesting(keys: keys, prefs: prefs);

        final ready = await controller.ensureKeysSetupForTesting(
          prefs: prefs,
          keys: keys,
        );

        expect(ready, isTrue);
        expect(keys.challengeCalls, 2);
        expect(keys.registerCalls, 2);
        expect(keys.publishCalls, 1);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'ensureKeysSetup serializes concurrent challenge-bound repairs for one device',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final prefs = await SharedPreferences.getInstance();
      const profileId = 'profile-concurrent-repair-1';
      const deviceId = 'device-concurrent-repair-1';
      const profileSecret = 'c2VjcmV0';
      final keys = _ConcurrentChallengeKeysClient(
        profileId: profileId,
        deviceId: deviceId,
      );

      try {
        await prefs.setString('profile_id', profileId);
        await prefs.setString('device_id', deviceId);
        secureStorageState['secretly/profile_secret_v1_b64/$profileId'] =
            profileSecret;

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: profileId,
          deviceId: deviceId,
        );
        controller.seedKeysRuntimeForTesting(keys: keys, prefs: prefs);

        final results = await Future.wait(<Future<bool>>[
          controller.ensureKeysSetupForTesting(prefs: prefs, keys: keys),
          controller.ensureKeysSetupForTesting(prefs: prefs, keys: keys),
        ]);

        expect(results, everyElement(isTrue));
        expect(keys.challengeCalls, 2);
        expect(keys.registerCalls, 2);
        expect(keys.publishCalls, 1);
        expect(keys.overlapRejects, 0);
      } finally {
        await db.close();
      }
    },
  );

  test('refreshContactDevices falls back to fetchBundle on peer lookup auth failure', () async {
    final controller = _BundleFallbackAppController(
      initialError: StateError('listDevices failed: 403 forbidden'),
    );
    final db = await AppDb.openForTesting();

    try {
      const selfProfileId = 'self-profile';
      const selfDeviceId = 'self-device';
      final deviceKeys = DeviceKeys.create();
      final identityKeyPair = await deviceKeys.loadIdentityKeyPair(
        profileId: selfProfileId,
        deviceId: selfDeviceId,
      );
      final identityPublicKey = await identityKeyPair.extractPublicKey();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: selfProfileId,
        deviceId: selfDeviceId,
      );
      controller.seedKeysRuntimeForTesting(
        keys: _BundleFetchingKeysClient(
          expectedRequesterDeviceId: selfDeviceId,
          expectedProfileId: 'peer-profile-1',
          identityPublicKey: identityPublicKey,
          devices: const <Map<String, Object?>>[
            <String, Object?>{
              'device_id': 'peer-device-fallback-1',
              'identity_key_pub_b64': 'identity-key-fallback',
              'signed_prekey_pub_b64': 'signed-prekey-fallback',
              'signed_prekey_sig_b64': 'signed-prekey-signature-fallback',
            },
          ],
        ),
      );

      await controller.refreshContactDevices('peer-profile-1');

      final rows = await db.contactDevicesList('peer-profile-1');
      expect(controller.deviceStatusLoads, 1);
      expect(rows, hasLength(1));
      expect(rows.single['device_id'], 'peer-device-fallback-1');
    } finally {
      await db.close();
    }
  });

  test('ratchet v3 pins first peer identity and rejects later identity drift', () async {
    final db = await AppDb.openForTesting();
    const peerProfileId = 'peer-profile-1';
    const peerDeviceId = 'peer-device-1';
    final initialIdentity = await Ed25519().newKeyPair();
    final rotatedIdentity = await Ed25519().newKeyPair();
    final devices = <Map<String, Object?>>[
      await _signedBundleDevice(
        deviceId: peerDeviceId,
        identityKeyPair: initialIdentity,
        signedPrekeyPubBytes: List<int>.generate(32, (index) => index + 1),
      ),
    ];
    final manager = RatchetSessionManagerV3(
      db: db,
      deviceKeys: DeviceKeys.create(),
      keysClient: _BundleFetchingKeysClient(devices: devices),
    );

    try {
      await manager.encryptToPeer(
        selfDeviceId: 'self-device',
        peerProfileId: peerProfileId,
        peerDeviceId: peerDeviceId,
        plaintext: Uint8List.fromList(<int>[1, 2, 3]),
      );

      final pinnedRows = await db.contactDevicesList(peerProfileId);
      expect(pinnedRows, hasLength(1));
      expect(pinnedRows.single['device_id'], peerDeviceId);

      await db.sessionV3Delete(peerDeviceId);
      devices
        ..clear()
        ..add(
          await _signedBundleDevice(
            deviceId: peerDeviceId,
            identityKeyPair: rotatedIdentity,
            signedPrekeyPubBytes: List<int>.generate(32, (index) => index + 41),
          ),
        );

      await expectLater(
        manager.encryptToPeer(
          selfDeviceId: 'self-device',
          peerProfileId: peerProfileId,
          peerDeviceId: peerDeviceId,
          plaintext: Uint8List.fromList(<int>[4, 5, 6]),
        ),
        throwsStateError,
      );

      final rowsAfterDrift = await db.contactDevicesList(peerProfileId);
      expect(rowsAfterDrift, hasLength(1));
      expect(
        rowsAfterDrift.single['identity_key_pub_b64'],
        pinnedRows.single['identity_key_pub_b64'],
      );
    } finally {
      await db.close();
    }
  });
}