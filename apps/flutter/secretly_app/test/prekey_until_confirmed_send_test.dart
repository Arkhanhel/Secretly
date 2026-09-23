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

/// Э-4 Ш-4/Ш-5: carry the
/// handshake on every message until the peer confirms — the Signal rule.
///
/// Why it matters, measured in the field on 2026-08-02: a session heal whose
/// cure was already sitting in the mailbox took 143 ms; the same heal needing a
/// round trip took 50 seconds. This change makes the first case the norm.
///
/// 🔴 The flag ships OFF. Sending repeats before every peer can RECEIVE them
/// harmlessly (Ш-2, same binary, ungated) is the 1.7.4+416 loss. These tests
/// therefore pin both states of the flag.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageState = <String, String>{};

  setUp(() {
    secureStorageState.clear();
    kPrekeyUntilConfirmedSend = true; // most tests exercise the ON path
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
    kPrekeyUntilConfirmedSend = false; // never leak the flag between tests
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

  Future<Uint8List> aSend(RatchetSessionManagerV3 a, String text) =>
      a.encryptToPeer(
        selfDeviceId: 'Adev',
        peerProfileId: 'Bprof',
        peerDeviceId: 'Bdev',
        plaintext: Uint8List.fromList(utf8.encode(text)),
      );

  Future<String> bOpen(RatchetSessionManagerV3 b, Uint8List wire) async =>
      utf8.decode(await b.decryptFromWire(
        selfProfileId: 'Bprof',
        selfDeviceId: 'Bdev',
        wireBytes: wire,
      ));

  bool isPrekey(Uint8List wire) =>
      RatchetWireV3.tryDecode(wire)!.kind == RatchetWireKindV3.prekey;

  test('every message carries the handshake until the peer confirms', () async {
    final w = await pair();
    try {
      for (var i = 0; i < 4; i++) {
        expect(isPrekey(await aSend(w.a, 'm$i')), isTrue,
            reason: 'message $i dropped the handshake before confirmation');
      }
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('🔴 confirmation stops the repeats', () async {
    // Otherwise every message for the rest of the conversation would carry a
    // handshake nobody needs.
    final w = await pair();
    try {
      final first = await aSend(w.a, 'hi');
      await bOpen(w.b, first);
      final reply = await w.b.encryptToPeer(
        selfDeviceId: 'Bdev',
        peerProfileId: 'Aprof',
        peerDeviceId: 'Adev',
        plaintext: Uint8List.fromList(utf8.encode('hello')),
      );
      await w.a.decryptFromWire(
        selfProfileId: 'Aprof',
        selfDeviceId: 'Adev',
        wireBytes: reply,
      );

      expect(isPrekey(await aSend(w.a, 'after')), isFalse,
          reason: 'the handshake kept riding along after confirmation');
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  /// 🔴 THE WHOLE POINT OF Э-4. The receiver loses its session — a wiped
  /// database, a restore, a corrupted SQLCipher file. Today it can open nothing
  /// we send and recovery needs a round trip. With repeats it heals FROM the
  /// message itself.
  test('🔴 a receiver that LOST its session heals from the next message',
      () async {
    final w = await pair();
    try {
      expect(await bOpen(w.b, await aSend(w.a, 'one')), 'one');

      // B loses its session — everything else about B stays intact.
      await w.bDb.sessionV3Delete('Adev');

      // A has NOT been told anything and has no reason to suspect a problem.
      // Without Э-4 this next wire is a bare ratchet message B cannot open.
      expect(await bOpen(w.b, await aSend(w.a, 'two')), 'two',
          reason: 'the receiver could not heal from the message alone — this '
              'is the round trip Э-4 exists to remove');
      expect(await bOpen(w.b, await aSend(w.a, 'three')), 'three');
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  /// 🔴 The same heal, but with the sender already FAR along its sending chain.
  ///
  /// The repeat re-derives the root from the handshake, while the sender has
  /// been advancing its chain all along. That only works because an unconfirmed
  /// initiator never performs a DH ratchet step — nothing it can receive while
  /// unconfirmed leaves it still repeating. This pins that invariant with a
  /// deep chain rather than trusting the argument.
  test('🔴 a lost session heals even deep into the sending chain', () async {
    final w = await pair();
    try {
      expect(await bOpen(w.b, await aSend(w.a, 'm0')), 'm0');
      // A keeps sending; B receives none of it and then loses the session.
      for (var i = 1; i <= 12; i++) {
        await aSend(w.a, 'm$i');
      }
      await w.bDb.sessionV3Delete('Adev');

      expect(await bOpen(w.b, await aSend(w.a, 'deep')), 'deep',
          reason: 'the handshake no longer matched the advanced chain — the '
              'heal only works while the initiator has done no DH step');
      // And the session must keep working afterwards.
      expect(await bOpen(w.b, await aSend(w.a, 'after')), 'after');
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('repeats do not consume extra one-time prekeys', () async {
    // П-1: the handshake is built ONCE. If each repeat re-fetched a bundle we
    // would burn a one-time prekey per message and drain the server pool.
    final w = await pair();
    try {
      final firstWire = await aSend(w.a, 'm0');
      final firstOtk = RatchetWireV3.tryDecode(firstWire)!.header['otk_id'];
      for (var i = 1; i < 5; i++) {
        final wire = await aSend(w.a, 'm$i');
        expect(RatchetWireV3.tryDecode(wire)!.header['otk_id'], firstOtk,
            reason: 'a repeat rebuilt the handshake and took another OTK');
      }
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('🔴 П-4: repeats do NOT re-arm the glare window', () async {
    // Refreshing the pending marker on every repeat would extend the 6-minute
    // glare window forever and the tie-break would never settle.
    final w = await pair();
    try {
      await aSend(w.a, 'm0');
      final armedAt = (await w.aDb.sessionV3Get('Bdev'))!
          ['initiator_pending_at_ms'] as int;
      for (var i = 1; i < 4; i++) {
        await aSend(w.a, 'm$i');
      }
      expect(
        (await w.aDb.sessionV3Get('Bdev'))!['initiator_pending_at_ms'],
        armedAt,
        reason: 'the glare window was re-armed by a repeat',
      );
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('🔴 Ш-5: an unconfirmed session stops repeating after the cap', () async {
    // 1823 of 1920 registered devices were silent for 3+ days (audit
    // 2026-08-01). Toward those, a repeat on every message forever is the
    // common case, not the exotic one.
    final w = await pair();
    try {
      await aSend(w.a, 'm0');
      expect(isPrekey(await aSend(w.a, 'm1')), isTrue);

      // Age the session past the cap.
      await w.aDb.sessionV3SetInitiatorPendingAt(
        'Bdev',
        DateTime.now().millisecondsSinceEpoch - kPrekeyRepeatMaxAgeMs - 1000,
      );
      expect(isPrekey(await aSend(w.a, 'm2')), isFalse,
          reason: 'the repeat never stops for a peer that never answers');
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('🔴 with the flag OFF the wire is byte-for-byte the old behaviour',
      () async {
    // This is what makes it safe to ship the code before the field is ready.
    kPrekeyUntilConfirmedSend = false;
    final w = await pair();
    try {
      expect(isPrekey(await aSend(w.a, 'm0')), isTrue,
          reason: 'first contact is a prekey with or without Э-4');
      expect(isPrekey(await aSend(w.a, 'm1')), isFalse,
          reason: 'with the flag off, message two must be a plain session wire');
      expect(isPrekey(await aSend(w.a, 'm2')), isFalse);
    } finally {
      await w.aDb.close();
      await w.bDb.close();
    }
  });

  test('a corrupt cached header falls back instead of sending a broken wire',
      () async {
    // A malformed handshake would make the peer fail to derive and reject the
    // message outright — worse than simply not repeating.
    final w = await pair();
    try {
      // B must actually hold the session, or the fallback wire would fail for
      // an unrelated reason (no session at all => epoch-ahead).
      await bOpen(w.b, await aSend(w.a, 'm0'));
      await w.aDb.sessionV3SetHandshake(
        'Bdev',
        pendingPrekeyHeaderJson: 'not json at all',
      );
      final wire = await aSend(w.a, 'm1');
      expect(isPrekey(wire), isFalse,
          reason: 'a broken cache must degrade to the ordinary wire');
      expect(await bOpen(w.b, wire), 'm1',
          reason: 'and that wire must still be openable');
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
