// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/double_ratchet_v3.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/ratchet/session_v1.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';

/// Э-4 Ш-2 / П-2 (редакция 2):
/// the RECEIVER must recognise a repeated handshake and decrypt against the
/// session it already holds.
///
/// 🔴 Д-1, REPRODUCED AGAINST THIS EXACT CODE BEFORE THE FIX. The prekey branch
/// unconditionally re-ran responderAccept → initResponder → _persist, and
/// `initResponder` returns `sendChainKey: null`, `ns: 0` and a root rolled back
/// to the handshake value. So a repeat ERASED the receiver's own ratchet
/// progress: after it had replied once, its next reply rode a root the sender
/// had already advanced past, and the sender could never open it again. The
/// reverse direction died permanently and silently — the same class of defect
/// as 1.7.4+416.
///
/// The sender is SIMULATED here on purpose: production cannot send repeats yet
/// (that is Ш-4). The risk lives on the receiver, so the receiver must be the
/// real, unmodified `RatchetSessionManagerV3`.
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

  /// A sender that behaves the way Ш-4 will: build the handshake ONCE, keep its
  /// X3DH part, and re-stamp only the ratchet fields on every message.
  Future<
      ({
        Future<Uint8List> Function(String text) send,
        Future<String> Function(Uint8List wire) open,
      })> simulatedSender({
    required DeviceKeyBundleV1 peerBundle,
    required String selfDeviceId,
    required String peerDeviceId,
    bool withOtk = false,
  }) async {
    final handshake = PrekeyHandshakeV1();
    final dr = DoubleRatchetV3();
    final init = await handshake.initiatorCreate(
      selfDeviceId: selfDeviceId,
      peerDeviceId: peerDeviceId,
      recipientSignedPrekeyPubB64: peerBundle.signedPrekeyPubB64,
      recipientSignedPrekeyId: 1,
      recipientOneTimePrekeyPubB64: withOtk
          ? peerBundle.oneTimePrekeys.first['prekey_pub_b64'] as String
          : null,
      recipientOneTimePrekeyId:
          withOtk ? peerBundle.oneTimePrekeys.first['prekey_id'] as int : null,
    );
    // П-1: the X3DH part is built once and reused verbatim.
    final cachedHandshake = init.header.toJson();
    var s = await dr.initInitiator(
      peerDeviceId: peerDeviceId,
      rootKey: init.session.rootKey,
      handshakeEphKeyPair: init.ephKeyPair,
      recipientSignedPrekeyPub:
          Uint8List.fromList(base64Decode(peerBundle.signedPrekeyPubB64)),
    );
    final se = DateTime.now().millisecondsSinceEpoch;

    Future<Uint8List> send(String text) async {
      // Only the RATCHET fields are re-stamped; a verbatim repeat would send
      // n=0 forever and fail the MAC on every message after the first.
      final headerMap = <String, Object?>{
        ...cachedHandshake,
        'dh_pub_b64': base64Encode(s.dhSelfPub),
        'pn': s.pn,
        'n': s.ns,
        'se': se,
      };
      final headerBytes =
          Uint8List.fromList(utf8.encode(jsonEncode(headerMap)));
      final enc = await dr.encrypt(
        state: s,
        plaintext: Uint8List.fromList(utf8.encode(text)),
        aad: headerBytes,
      );
      s = enc.updated;
      return RatchetWireV3.encodePrekey(
        header: headerMap,
        ratchetCiphertext: enc.ciphertext,
      );
    }

    Future<String> open(Uint8List wire) async {
      final d = RatchetWireV3.tryDecode(wire)!;
      final dec = await dr.decrypt(
        state: s,
        headerDhPubB64: d.header['dh_pub_b64'] as String,
        pn: (d.header['pn'] as num).toInt(),
        n: (d.header['n'] as num).toInt(),
        ciphertext: d.ciphertext,
        aad: d.headerBytes,
      );
      s = dec.updated;
      return utf8.decode(dec.plaintext);
    }

    return (send: send, open: open);
  }

  Future<({AppDb db, RatchetSessionManagerV3 mgr, DeviceKeyBundleV1 bundle})>
      receiver() async {
    final db = await AppDb.openForTesting();
    final bundle = await DeviceKeys.create().createOrLoadAndAllocateOtk(
      profileId: 'Bprof',
      deviceId: 'Bdev',
      allocateOneTimePrekeys: 8,
    );
    final mgr = RatchetSessionManagerV3(
      db: db,
      deviceKeys: DeviceKeys.create(),
      keysClient: _NoBundleKeysClient(),
    );
    return (db: db, mgr: mgr, bundle: bundle);
  }

  Future<String> deliver(RatchetSessionManagerV3 mgr, Uint8List wire) async =>
      utf8.decode(await mgr.decryptFromWire(
        selfProfileId: 'Bprof',
        selfDeviceId: 'Bdev',
        wireBytes: wire,
      ));

  test('🔴 Д-1: a repeat must NOT destroy the receiver\'s own send chain',
      () async {
    final r = await receiver();
    final a = await simulatedSender(
      peerBundle: r.bundle,
      selfDeviceId: 'Adev',
      peerDeviceId: 'Bdev',
    );

    expect(await deliver(r.mgr, await a.send('m1')), 'm1');
    final afterFirst = await r.db.sessionV3Get('Adev');
    expect(afterFirst!['handshake_base_pub_b64'], isNotNull,
        reason: 'the receiver must remember WHICH handshake made this session');

    // B replies: this is what gives it a send chain and advances its root.
    final reply1 = await r.mgr.encryptToPeer(
      selfDeviceId: 'Bdev',
      peerProfileId: 'Aprof',
      peerDeviceId: 'Adev',
      plaintext: Uint8List.fromList(utf8.encode('r1')),
    );
    final afterReply = await r.db.sessionV3Get('Adev');
    final rootAfterReply = afterReply!['root_key_b64'] as String;
    expect(afterReply['send_chain_key_b64'], isNotNull);

    // A sends again under the SAME handshake — it has not seen the reply yet.
    // This is the ordinary "two messages in a row while the peer answers" case.
    expect(await deliver(r.mgr, await a.send('m2')), 'm2');

    final afterRepeat = await r.db.sessionV3Get('Adev');
    expect(afterRepeat!['root_key_b64'], rootAfterReply,
        reason: 'the root rolled back — the repeat re-initialised the session');
    expect(afterRepeat['send_chain_key_b64'], isNotNull,
        reason: "the repeat destroyed the receiver's send chain (Д-1)");

    // The proof that matters: the reverse direction still works.
    expect(await a.open(reply1), 'r1');
    final reply2 = await r.mgr.encryptToPeer(
      selfDeviceId: 'Bdev',
      peerProfileId: 'Aprof',
      peerDeviceId: 'Adev',
      plaintext: Uint8List.fromList(utf8.encode('r2')),
    );
    expect(await a.open(reply2), 'r2',
        reason: 'THE REVERSE DIRECTION IS DEAD — this is Д-1 in full');

    await r.db.close();
  });

  test('🔴 Р-1: repeats must not resurrect consumed message keys', () async {
    // A naive repeat re-derives and re-stores skipped keys 0..k-2 on every
    // message: keys that were spent and deleted come BACK into the database,
    // which is a forward-secrecy regression on top of the O(k²) writes.
    final r = await receiver();
    final a = await simulatedSender(
      peerBundle: r.bundle,
      selfDeviceId: 'Adev',
      peerDeviceId: 'Bdev',
    );
    for (var i = 1; i <= 6; i++) {
      expect(await deliver(r.mgr, await a.send('m$i')), 'm$i');
    }
    final skipped = await r.db.rawQueryForTesting(
      'SELECT COUNT(*) c FROM skipped_message_keys',
    );
    expect((skipped.first['c'] as num).toInt(), 0,
        reason: 'consumed message keys came back into the database');
    await r.db.close();
  });

  test('🔴 Р-3: repeats must not push an archive row each time', () async {
    // The archive keeps only the last 8 sessions. If every repeat pushed one,
    // eight messages would evict every genuinely useful straggler session.
    final r = await receiver();
    final a = await simulatedSender(
      peerBundle: r.bundle,
      selfDeviceId: 'Adev',
      peerDeviceId: 'Bdev',
    );
    for (var i = 1; i <= 6; i++) {
      await deliver(r.mgr, await a.send('m$i'));
    }
    final archived = await r.db.sessionV3ArchiveList('Adev');
    expect(archived, isEmpty,
        reason: 'a repeat is not a new session and must not archive anything');
    await r.db.close();
  });

  test('🔴 Д-2: a repeat opens even after the receiver LOSES its key material',
      () async {
    // The target scenario. A repeat must be decryptable from the live session
    // alone — no keychain, no signed prekey, no one-time prekey. If the branch
    // ever reached responderAccept here it would hard-throw on the missing OTK,
    // which is exactly the poison Д-2 describes.
    final r = await receiver();
    final a = await simulatedSender(
      peerBundle: r.bundle,
      selfDeviceId: 'Adev',
      peerDeviceId: 'Bdev',
      withOtk: true, // first contact may legitimately carry an OTK
    );
    expect(await deliver(r.mgr, await a.send('m1')), 'm1');

    secureStorageState.clear(); // keychain miss / restore — a real field mode

    expect(await deliver(r.mgr, await a.send('m2')), 'm2',
        reason: 'the repeat needed key material it should never have touched');
    await r.db.close();
  });

  test('a genuinely NEW handshake is still adopted (no false matching)', () async {
    // The guard must not swallow real re-keys: a different base key means a
    // different handshake, and that has to go down the full X3DH path.
    final r = await receiver();
    final a1 = await simulatedSender(
      peerBundle: r.bundle,
      selfDeviceId: 'Adev',
      peerDeviceId: 'Bdev',
    );
    expect(await deliver(r.mgr, await a1.send('first')), 'first');
    final base1 =
        (await r.db.sessionV3Get('Adev'))!['handshake_base_pub_b64'] as String;

    // The peer resets and starts over: a brand-new ephemeral, new session.
    final a2 = await simulatedSender(
      peerBundle: r.bundle,
      selfDeviceId: 'Adev',
      peerDeviceId: 'Bdev',
    );
    expect(await deliver(r.mgr, await a2.send('after-reset')), 'after-reset');
    final base2 =
        (await r.db.sessionV3Get('Adev'))!['handshake_base_pub_b64'] as String;

    expect(base2, isNot(base1),
        reason: 'a real re-key must replace the session, not be mistaken for '
            'a repeat');
    // ...and the OLD session must still be reachable for stragglers (Р-4).
    final archived = await r.db.sessionV3ArchiveList('Adev');
    expect(archived, isNotEmpty);
    expect(archived.first['handshake_base_pub_b64'], base1,
        reason: 'the archived session must carry its own base key, or a late '
            'repeat of it would fall through to X3DH and overwrite the newer '
            'session');
    await r.db.close();
  });

  test('🔴 Р-4: a LATE repeat of the old handshake does not clobber the new',
      () async {
    final r = await receiver();
    final a1 = await simulatedSender(
      peerBundle: r.bundle,
      selfDeviceId: 'Adev',
      peerDeviceId: 'Bdev',
    );
    expect(await deliver(r.mgr, await a1.send('old-1')), 'old-1');
    // A straggler from the OLD handshake, produced before the reset but
    // arriving after it.
    final straggler = await a1.send('old-2');

    final a2 = await simulatedSender(
      peerBundle: r.bundle,
      selfDeviceId: 'Adev',
      peerDeviceId: 'Bdev',
    );
    expect(await deliver(r.mgr, await a2.send('new-1')), 'new-1');
    final newBase =
        (await r.db.sessionV3Get('Adev'))!['handshake_base_pub_b64'] as String;

    // The straggler must be readable AND must leave the new session alone.
    expect(await deliver(r.mgr, straggler), 'old-2');
    final after = await r.db.sessionV3Get('Adev');
    expect(after!['handshake_base_pub_b64'], newBase,
        reason: 'a late repeat of the OLD handshake overwrote the NEW session');
    expect(await deliver(r.mgr, await a2.send('new-2')), 'new-2',
        reason: 'the new session must keep working after the straggler');
    await r.db.close();
  });
}

class _NoBundleKeysClient extends KeysClient {
  _NoBundleKeysClient() : super(baseUrl: Uri.parse('https://example.com'));
  @override
  Future<List<Map<String, Object?>>> fetchBundle(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async =>
      const [];
}
