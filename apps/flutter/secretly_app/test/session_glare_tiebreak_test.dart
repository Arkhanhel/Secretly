// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';

class _FixedBundleKeysClient extends KeysClient {
  _FixedBundleKeysClient(this._devices)
      : super(baseUrl: Uri.parse('https://example.com'));

  final List<Map<String, Object?>> _devices;

  @override
  Future<List<Map<String, Object?>>> fetchBundle(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async =>
      _devices;
}

Map<String, Object?> _deviceMap(String deviceId, DeviceKeyBundleV1 b) =>
    <String, Object?>{
      'device_id': deviceId,
      'identity_key_pub_b64': b.identityKeyPubB64,
      'signed_prekey_pub_b64': b.signedPrekeyPubB64,
      'signed_prekey_sig_b64': b.signedPrekeySigB64,
      'one_time_prekey': b.oneTimePrekeys.isNotEmpty
          ? b.oneTimePrekeys.first
          : null,
    };

Future<Uint8List> _enc(
  RatchetSessionManagerV3 mgr, {
  required String selfDeviceId,
  required String peerProfileId,
  required String peerDeviceId,
  required String text,
}) =>
    mgr.encryptToPeer(
      selfDeviceId: selfDeviceId,
      peerProfileId: peerProfileId,
      peerDeviceId: peerDeviceId,
      plaintext: Uint8List.fromList(utf8.encode(text)),
    );

Future<String> _dec(
  RatchetSessionManagerV3 mgr, {
  required String selfProfileId,
  required String selfDeviceId,
  required Uint8List wire,
}) async {
  final plain = await mgr.decryptFromWire(
    selfProfileId: selfProfileId,
    selfDeviceId: selfDeviceId,
    wireBytes: wire,
  );
  return utf8.decode(plain);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageState = <String, String>{};

  setUp(() {
    secureStorageState.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final args = Map<Object?, Object?>.from(
        call.arguments as Map<Object?, Object?>? ?? const {},
      );
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : secureStorageState[key];
        case 'write':
          if (key != null) {
            secureStorageState[key] = (args['value'] as String?) ?? '';
          }
          return null;
        case 'delete':
          if (key != null) secureStorageState.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(secureStorageState);
        case 'deleteAll':
          secureStorageState.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  // Builds two cross-connected managers (A and B), each backed by its own DB and
  // holding the other's real prekey bundle, so they can run genuine X3DH.
  Future<
      ({
        RatchetSessionManagerV3 a,
        RatchetSessionManagerV3 b,
        AppDb aDb,
        AppDb bDb,
      })> wire({
    required String aProfile,
    required String aDevice,
    required String bProfile,
    required String bDevice,
  }) async {
    final aDb = await AppDb.openForTesting();
    final bDb = await AppDb.openForTesting();
    final keys = DeviceKeys.create();
    final aBundle = await keys.createOrLoadAndAllocateOtk(
      profileId: aProfile,
      deviceId: aDevice,
      allocateOneTimePrekeys: 8,
    );
    final bBundle = await keys.createOrLoadAndAllocateOtk(
      profileId: bProfile,
      deviceId: bDevice,
      allocateOneTimePrekeys: 8,
    );
    final a = RatchetSessionManagerV3(
      db: aDb,
      deviceKeys: DeviceKeys.create(),
      keysClient: _FixedBundleKeysClient([_deviceMap(bDevice, bBundle)]),
    );
    final b = RatchetSessionManagerV3(
      db: bDb,
      deviceKeys: DeviceKeys.create(),
      keysClient: _FixedBundleKeysClient([_deviceMap(aDevice, aBundle)]),
    );
    return (a: a, b: b, aDb: aDb, bDb: bDb);
  }

  // Full round-trip including the RESPONDER'S FIRST REPLY. This previously
  // broke ("missing recv chain key") because encryptToPeer advertised a stale
  // dh_pub when the responder's first send performed a DH ratchet. The
  // ensureSendChain fix makes the wire header match the ratcheted key.
  test('handshake: messages flow BOTH directions incl. responder first reply',
      () async {
    final w = await wire(
      aProfile: 'Aprof',
      aDevice: 'Adev',
      bProfile: 'Bprof',
      bDevice: 'Bdev',
    );
    try {
      final pA = await _enc(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'hi-B');
      expect(
        await _dec(w.b, selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: pA),
        'hi-B',
      );

      // Responder's FIRST reply (the previously-broken path).
      final mB = await _enc(w.b,
          selfDeviceId: 'Bdev',
          peerProfileId: 'Aprof',
          peerDeviceId: 'Adev',
          text: 'reply-A');
      expect(
        await _dec(w.a, selfProfileId: 'Aprof', selfDeviceId: 'Adev', wire: mB),
        'reply-A',
      );

      // And keep going both ways to make sure the ratchet stays in sync.
      final mA2 = await _enc(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'A-again');
      expect(
        await _dec(w.b, selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: mA2),
        'A-again',
      );
      final mB2 = await _enc(w.b,
          selfDeviceId: 'Bdev',
          peerProfileId: 'Aprof',
          peerDeviceId: 'Adev',
          text: 'B-again');
      expect(
        await _dec(w.a, selfProfileId: 'Aprof', selfDeviceId: 'Adev', wire: mB2),
        'B-again',
      );
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  // THE root-cause test: both peers initiate at the same time (glare). The
  // deterministic tie-break must make BOTH sides converge on the SAME session
  // (identical root key) — that is exactly what prevents the permanent
  // split-brain. We assert convergence on session state (independent of the
  // separate encrypt-send ratchet path).
  test('glare: simultaneous initiation converges on one shared session',
      () async {
    // Two device-id orderings exercise BOTH tie-break branches
    // (local session wins / incoming candidate wins).
    for (final order in const [
      ['Adev-1', 'Bdev-2'],
      ['Bdev-9', 'Adev-3'],
    ]) {
      final aDevice = order[0];
      final bDevice = order[1];
      final w = await wire(
        aProfile: 'Aprof',
        aDevice: aDevice,
        bProfile: 'Bprof',
        bDevice: bDevice,
      );
      try {
        // Both sides initiate before processing the other's prekey.
        final pA = await _enc(w.a,
            selfDeviceId: aDevice,
            peerProfileId: 'Bprof',
            peerDeviceId: bDevice,
            text: 'a-init');
        final pB = await _enc(w.b,
            selfDeviceId: bDevice,
            peerProfileId: 'Aprof',
            peerDeviceId: aDevice,
            text: 'b-init');

        // Each processes the other's prekey (the glare collision). Both still
        // recover the payload regardless of who wins the tie-break.
        expect(
          await _dec(w.a,
              selfProfileId: 'Aprof', selfDeviceId: aDevice, wire: pB),
          'b-init',
        );
        expect(
          await _dec(w.b,
              selfProfileId: 'Bprof', selfDeviceId: bDevice, wire: pA),
          'a-init',
        );

        // Convergence: both primary sessions must now be the SAME session.
        final aRoot =
            (await w.aDb.sessionV3Get(bDevice))?['root_key_b64'] as String?;
        final bRoot =
            (await w.bDb.sessionV3Get(aDevice))?['root_key_b64'] as String?;
        expect(aRoot, isNotNull);
        expect(
          aRoot,
          bRoot,
          reason: 'glare did not converge to one session (order=$order)',
        );
      } finally {
        await w.aDb.close();
        await w.bDb.close();
      }
    }
  });
}
