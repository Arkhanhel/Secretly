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

/// Э-4 Ш-3: the sender caches
/// the handshake it will repeat until the peer confirms.
///
/// WRITE ONLY at this step — nothing reads the cache yet. Repeating starts in
/// Ш-4, behind a flag, and only once the RECEIVING half (Ш-2) has reached the
/// field. The other order is the 1.7.4+416 loss, where a build began emitting a
/// format its peers could not handle and messages died.
///
/// So what these tests pin is the cache's LIFECYCLE: it appears when a session
/// is initiated, and it dies at every point the session stops being ours to
/// repeat. A header that outlives its session would be attached to every future
/// message forever.
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

  Map<String, Object?> deviceMap(String deviceId, DeviceKeyBundleV1 b) =>
      <String, Object?>{
        'device_id': deviceId,
        'identity_key_pub_b64': b.identityKeyPubB64,
        'signed_prekey_pub_b64': b.signedPrekeyPubB64,
        'signed_prekey_sig_b64': b.signedPrekeySigB64,
        'one_time_prekey':
            b.oneTimePrekeys.isNotEmpty ? b.oneTimePrekeys.first : null,
      };

  /// Two managers, each with a real database and the other's real bundle, so
  /// they run genuine X3DH against each other.
  Future<
      ({
        RatchetSessionManagerV3 a,
        RatchetSessionManagerV3 b,
        AppDb aDb,
        AppDb bDb,
      })> pair() async {
    final aDb = await AppDb.openForTesting();
    final bDb = await AppDb.openForTesting();
    final keys = DeviceKeys.create();
    final aBundle = await keys.createOrLoadAndAllocateOtk(
      profileId: 'Aprof',
      deviceId: 'Adev',
      allocateOneTimePrekeys: 8,
    );
    final bBundle = await keys.createOrLoadAndAllocateOtk(
      profileId: 'Bprof',
      deviceId: 'Bdev',
      allocateOneTimePrekeys: 8,
    );
    return (
      a: RatchetSessionManagerV3(
        db: aDb,
        deviceKeys: DeviceKeys.create(),
        keysClient: _FixedBundleKeysClient([deviceMap('Bdev', bBundle)]),
      ),
      b: RatchetSessionManagerV3(
        db: bDb,
        deviceKeys: DeviceKeys.create(),
        keysClient: _FixedBundleKeysClient([deviceMap('Adev', aBundle)]),
      ),
      aDb: aDb,
      bDb: bDb,
    );
  }

  Future<Uint8List> send(
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

  test('initiating a session caches its handshake and base key', () async {
    final w = await pair();
    try {
      await send(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'hi');

      final row = await w.aDb.sessionV3Get('Bdev');
      final cached = row!['pending_prekey_header_json'] as String?;
      expect(cached, isNotNull, reason: 'Ш-4 will have nothing to repeat');
      expect(row['handshake_base_pub_b64'], isNotNull);

      // 🔴 The cache must be the header that ACTUALLY derived this root. The
      // receiver reads `otk_id` to decide whether to mix DH2, so a doctored
      // copy would make it derive a different root and open nothing.
      final decoded = jsonDecode(cached!) as Map<String, dynamic>;
      expect(decoded['sender_eph_pub_b64'], row['handshake_base_pub_b64'],
          reason: 'the cached header and the base key must describe ONE '
              'handshake');
      expect(decoded['sender_device_id'], 'Adev');
      expect(decoded.containsKey('spk_id'), isTrue);
      // Ratchet fields must NOT be cached: they are re-stamped per message.
      // A verbatim repeat would send n=0 forever and fail every MAC.
      expect(decoded.containsKey('n'), isFalse);
      expect(decoded.containsKey('pn'), isFalse);
      expect(decoded.containsKey('dh_pub_b64'), isFalse);
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('🔴 confirmation DROPS the cached header', () async {
    // Confirmation is the peer replying on our session. From that moment the
    // handshake must never ride along again.
    final w = await pair();
    try {
      final first = await send(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'hi');
      expect(
        (await w.aDb.sessionV3Get('Bdev'))!['pending_prekey_header_json'],
        isNotNull,
      );

      // B adopts and replies; A applies that reply = confirmation.
      await w.b.decryptFromWire(
        selfProfileId: 'Bprof',
        selfDeviceId: 'Bdev',
        wireBytes: first,
      );
      final reply = await send(w.b,
          selfDeviceId: 'Bdev',
          peerProfileId: 'Aprof',
          peerDeviceId: 'Adev',
          text: 'hello back');
      await w.a.decryptFromWire(
        selfProfileId: 'Aprof',
        selfDeviceId: 'Adev',
        wireBytes: reply,
      );

      final row = await w.aDb.sessionV3Get('Bdev');
      expect(row!['pending_prekey_header_json'], isNull,
          reason: 'a header that outlives confirmation rides every future '
              'message forever');
      expect(row['initiator_pending_at_ms'], 0,
          reason: 'the marker and the header must fall together');
      expect(row['handshake_base_pub_b64'], isNotNull,
          reason: 'the base key identifies the session for its whole life and '
              'must survive confirmation');
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('🔴 adopting the PEER\'s handshake drops our own cached header',
      () async {
    // Both sides initiate at once (glare). When we adopt theirs, the session we
    // had cached a header for is gone — repeating it would advertise a
    // handshake that no longer exists.
    final w = await pair();
    try {
      await send(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'from A');
      expect(
        (await w.aDb.sessionV3Get('Bdev'))!['pending_prekey_header_json'],
        isNotNull,
      );

      // B initiates independently; A receives that prekey.
      final fromB = await send(w.b,
          selfDeviceId: 'Bdev',
          peerProfileId: 'Aprof',
          peerDeviceId: 'Adev',
          text: 'from B');
      await w.a.decryptFromWire(
        selfProfileId: 'Aprof',
        selfDeviceId: 'Adev',
        wireBytes: fromB,
      );

      final row = await w.aDb.sessionV3Get('Bdev');
      // Either A adopted B's session (header must be gone) or A won the glare
      // tie-break and kept its own (header still valid). Both are correct; what
      // must never happen is a header describing a session we no longer hold.
      final base = row!['handshake_base_pub_b64'] as String?;
      final cached = row['pending_prekey_header_json'] as String?;
      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        expect(decoded['sender_eph_pub_b64'], base,
            reason: 'the cached header describes a session we do not hold');
      }
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('the cache survives ordinary ratchet advances', () async {
    // Every message rewrites the session row. If the upsert did not carry the
    // cache forward, the second message would already have lost it.
    final w = await pair();
    try {
      for (var i = 0; i < 5; i++) {
        await send(w.a,
            selfDeviceId: 'Adev',
            peerProfileId: 'Bprof',
            peerDeviceId: 'Bdev',
            text: 'm$i');
      }
      final row = await w.aDb.sessionV3Get('Bdev');
      expect(row!['pending_prekey_header_json'], isNotNull,
          reason: 'a ratchet advance erased the cached handshake');
      expect(row['ns'], greaterThan(1), reason: 'the ratchet did advance');
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('Ш-3 changes nothing on the wire yet', () async {
    // The whole point of shipping this separately: the cache is written, but no
    // message carries a repeat. Message two must still be an ordinary session
    // wire, exactly as before Э-4.
    final w = await pair();
    try {
      final first = await send(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'one');
      final second = await send(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'two');
      expect(first[4], 1, reason: 'the first wire is a prekey (kind byte 1)');
      expect(second[4], 0,
          reason: 'message two must still be a plain session wire until Ш-4 '
              'is switched on');
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });
}

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
