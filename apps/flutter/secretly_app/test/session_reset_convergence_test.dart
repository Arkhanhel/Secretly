// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';

// Convergence test for the E2EE session-reset deadlock fix.
//
// Live bug: when A's Double Ratchet session toward B has DIVERGED from B's
// session toward A, A correctly detects it cannot decrypt B and fires a
// "session-reset ping". In the buggy recovery paths that ping was encrypted on
// the EXISTING (diverged) session, so B — equally diverged — could not decrypt
// it, quarantined it, and never adopted a new session ⇒ permanent deadlock.
//
// The fix forces every reset-ping to be a FRESH X3DH INITIAL (prekey) wire by
// deleting the local session before encrypting. The receiver always adopts a
// valid fresh prekey (outside the glare window) and can decrypt it WITHOUT any
// prior session, then replies on the new session so the original sender
// converges too. These tests verify that round-trip at the crypto layer (the
// exact guarantee that AppController._encryptToPeerSerialized(forceFreshPrekey:
// true) provides), plus the negative case proving the fix is load-bearing.

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

// NB: NO one-time prekey — every handshake rides the signed prekey + a fresh
// random ephemeral, so each post-delete encryptToPeer produces a genuinely
// distinct session deterministically (no OTK exhaustion across re-handshakes).
Map<String, Object?> _deviceMap(String deviceId, DeviceKeyBundleV1 b) =>
    <String, Object?>{
      'device_id': deviceId,
      'identity_key_pub_b64': b.identityKeyPubB64,
      'signed_prekey_pub_b64': b.signedPrekeyPubB64,
      'signed_prekey_sig_b64': b.signedPrekeySigB64,
      'one_time_prekey': null,
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

RatchetWireKindV3 _kind(Uint8List wire) {
  final decoded = RatchetWireV3.tryDecode(wire);
  expect(decoded, isNotNull, reason: 'wire did not decode as v1.3 ratchet');
  return decoded!.kind;
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

  // Two cross-connected managers (A and B), each with its own DB + the other's
  // real prekey bundle, so they run genuine X3DH.
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

  const aProfile = 'Aprof';
  const aDevice = 'Adev';
  const bProfile = 'Bprof';
  const bDevice = 'Bdev';

  // Drives A and B into a genuinely DIVERGED state (A's session ≠ B's session):
  //   1. A→B handshake establishes shared session S1 on both sides.
  //   2. A re-initialises (its row deleted) and encrypts S2's prekey, but that
  //      prekey is DROPPED (never delivered to B). A now holds S2; B still S1.
  // Result: A-encrypted wires are S2 (B can't decrypt, B has S1) and
  // B-encrypted wires are S1 (A can't decrypt, A has S2) — the live deadlock.
  Future<void> diverge(
    ({
      RatchetSessionManagerV3 a,
      RatchetSessionManagerV3 b,
      AppDb aDb,
      AppDb bDb,
    }) w,
  ) async {
    final p1 = await _enc(w.a,
        selfDeviceId: aDevice,
        peerProfileId: bProfile,
        peerDeviceId: bDevice,
        text: 'establish-S1');
    expect(_kind(p1), RatchetWireKindV3.prekey);
    expect(
      await _dec(w.b, selfProfileId: bProfile, selfDeviceId: bDevice, wire: p1),
      'establish-S1',
    );

    // A re-inits toward B -> S2 prekey, but it is DROPPED (never decrypted by B).
    await w.aDb.sessionV3Delete(bDevice);
    final droppedS2 = await _enc(w.a,
        selfDeviceId: aDevice,
        peerProfileId: bProfile,
        peerDeviceId: bDevice,
        text: 'lost-S2-prekey');
    expect(_kind(droppedS2), RatchetWireKindV3.prekey);
    // (intentionally NOT delivered to B)

    // Sanity: the sessions are now diverged (different roots).
    final aRoot = (await w.aDb.sessionV3Get(bDevice))?['root_key_b64'];
    final bRoot = (await w.bDb.sessionV3Get(aDevice))?['root_key_b64'];
    expect(aRoot, isNotNull);
    expect(bRoot, isNotNull);
    expect(aRoot, isNot(equals(bRoot)),
        reason: 'precondition failed: sessions are not diverged');
  }

  test(
      'diverged A<->B: A reset (fresh X3DH initial) -> B adopts+decrypts+replies '
      '-> A decrypts the reply (full round-trip convergence)', () async {
    final w = await wire(
      aProfile: aProfile,
      aDevice: aDevice,
      bProfile: bProfile,
      bDevice: bDevice,
    );
    try {
      await diverge(w);

      // Confirm the deadlock: a B->A message under the OLD (S1) session cannot
      // be decrypted by A (whose live session is S2).
      final bStuck = await _enc(w.b,
          selfDeviceId: bDevice,
          peerProfileId: aProfile,
          peerDeviceId: aDevice,
          text: 'B-msg-A-cannot-read');
      await expectLater(
        _dec(w.a, selfProfileId: aProfile, selfDeviceId: aDevice, wire: bStuck),
        throwsA(isA<Object>()),
        reason: 'precondition: A must be unable to decrypt B pre-reset',
      );

      // ── THE FIX ──────────────────────────────────────────────────────────
      // A resets: delete the local (diverged) session, then encrypt the
      // reset-ping. This is exactly what _encryptToPeerSerialized(
      // forceFreshPrekey: true) does. The wire MUST be a fresh X3DH PREKEY.
      await w.aDb.sessionV3Delete(bDevice);
      final resetPing = await _enc(w.a,
          selfDeviceId: aDevice,
          peerProfileId: bProfile,
          peerDeviceId: bDevice,
          text: '');
      expect(_kind(resetPing), RatchetWireKindV3.prekey,
          reason: 'reset-ping must be a fresh X3DH initial, not a session wire');

      // B receives the fresh prekey while it STILL HOLDS the diverged S1
      // session. It must ADOPT the new session and decrypt WITHOUT relying on
      // the old session (the whole point of a reset).
      expect(
        await _dec(w.b,
            selfProfileId: bProfile, selfDeviceId: bDevice, wire: resetPing),
        '',
      );

      // Convergence so far: B's primary session now matches A's fresh session.
      final aRootNew = (await w.aDb.sessionV3Get(bDevice))?['root_key_b64'];
      final bRootNew = (await w.bDb.sessionV3Get(aDevice))?['root_key_b64'];
      expect(aRootNew, isNotNull);
      expect(aRootNew, bRootNew,
          reason: 'B did not adopt A\'s fresh reset session');

      // B replies ON THE NEW SESSION (a normal `session` wire — what the
      // reciprocal confirm-ping / B's next organic send does). A MUST decrypt
      // it: the reverse direction has healed.
      final bReply = await _enc(w.b,
          selfDeviceId: bDevice,
          peerProfileId: aProfile,
          peerDeviceId: aDevice,
          text: 'reply-on-new-session');
      expect(_kind(bReply), RatchetWireKindV3.session);
      expect(
        await _dec(w.a,
            selfProfileId: aProfile, selfDeviceId: aDevice, wire: bReply),
        'reply-on-new-session',
      );

      // And both directions keep flowing on the converged session.
      final aAgain = await _enc(w.a,
          selfDeviceId: aDevice,
          peerProfileId: bProfile,
          peerDeviceId: bDevice,
          text: 'A-after-converge');
      expect(
        await _dec(w.b,
            selfProfileId: bProfile, selfDeviceId: bDevice, wire: aAgain),
        'A-after-converge',
      );
      final bAgain = await _enc(w.b,
          selfDeviceId: bDevice,
          peerProfileId: aProfile,
          peerDeviceId: aDevice,
          text: 'B-after-converge');
      expect(
        await _dec(w.a,
            selfProfileId: aProfile, selfDeviceId: aDevice, wire: bAgain),
        'B-after-converge',
      );
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  // The fix is load-bearing: WITHOUT deleting the diverged session first (the
  // old buggy recovery paths), A's reset-ping is a SESSION wire on the dead
  // session, which the equally-diverged B cannot decrypt — reproducing the
  // permanent deadlock.
  test('negative: reset-ping on the diverged session is undecryptable by B',
      () async {
    final w = await wire(
      aProfile: aProfile,
      aDevice: aDevice,
      bProfile: bProfile,
      bDevice: bDevice,
    );
    try {
      await diverge(w);

      // OLD behaviour: encrypt WITHOUT deleting the session -> SESSION wire.
      final badPing = await _enc(w.a,
          selfDeviceId: aDevice,
          peerProfileId: bProfile,
          peerDeviceId: bDevice,
          text: '');
      expect(_kind(badPing), RatchetWireKindV3.session,
          reason: 'without the fix the ping rides the existing session');

      await expectLater(
        _dec(w.b, selfProfileId: bProfile, selfDeviceId: bDevice, wire: badPing),
        throwsA(isA<Object>()),
        reason:
            'a session-wire reset is undecryptable by a diverged receiver — '
            'this is the deadlock the fix removes',
      );
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });
}
