// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ratchet/decrypt_worker.dart';
import 'package:secretly_app/ratchet/double_ratchet_v3.dart';

/// Step Б — moving the ratchet maths onto a worker isolate must change NOTHING
/// about the answer.
///
/// The isolate is an optimisation: it exists so the heaviest computation in the
/// app stops competing with the thread that draws frames. The moment it alters
/// a single byte of resulting state, or blurs an error's text, it stops being
/// an optimisation and becomes a message-loss bug — the state feeds straight
/// back into the ratchet, and the text decides whether a wire is parked or
/// acknowledged away.
///
/// So these tests compare the two paths directly rather than checking the
/// worker "looks right" on its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => DecryptWorker.instance.disposeForTesting());

  /// A live session pair, built by running a real handshake through the pure
  /// ratchet — no hand-assembled state, which would prove nothing about the
  /// values the app actually carries.
  Future<
      ({
        DoubleRatchetStateV3 senderState,
        DoubleRatchetStateV3 receiverState,
        DoubleRatchetV3 dr,
      })> freshPair({int maxSkip = 200}) async {
    final dr = DoubleRatchetV3(maxSkip: maxSkip);
    final x = X25519();
    final spk = await x.newKeyPairFromSeed(
      Uint8List.fromList(List<int>.generate(32, (i) => i + 3)),
    );
    final spkPub = await spk.extractPublicKey();
    final eph = await x.newKeyPairFromSeed(
      Uint8List.fromList(List<int>.generate(32, (i) => 90 + i)),
    );
    final ephPub = await eph.extractPublicKey();
    final rk = Uint8List.fromList(List<int>.generate(32, (i) => 11));

    final sender = await dr.initInitiator(
      peerDeviceId: 'recv-dev',
      rootKey: rk,
      handshakeEphKeyPair: eph,
      recipientSignedPrekeyPub: Uint8List.fromList(spkPub.bytes),
    );
    final receiver = await dr.initResponder(
      peerDeviceId: 'send-dev',
      rootKey: rk,
      recipientSignedPrekeyKeyPair: spk,
      initiatorDhPub: Uint8List.fromList(ephPub.bytes),
    );
    return (senderState: sender, receiverState: receiver, dr: dr);
  }

  test('🔴 the worker ISOLATE actually runs — without this the file is vacuous',
      () async {
    // Every test here would still pass if Isolate.spawn failed and the code
    // quietly fell back to computing in place. That is the difference between
    // proving the worker correct and proving nothing at all, so assert the
    // isolate is genuinely up after a real decrypt.
    final p = await freshPair();
    final enc = await p.dr.encrypt(
      state: p.senderState,
      plaintext: Uint8List.fromList(utf8.encode('are you really there')),
    );
    await DecryptWorker.instance.decrypt(
      ratchet: p.dr,
      state: p.receiverState,
      headerDhPubB64: enc.dhPubB64,
      pn: enc.pn,
      n: enc.n,
      ciphertext: enc.ciphertext,
    );
    expect(
      DecryptWorker.instance.isRunning,
      isTrue,
      reason: 'the decrypt was served in place, so nothing below tests the '
          'isolate boundary at all',
    );
  });

  group('the worker and the in-place path agree exactly', () {
    test('an ordinary in-order message decrypts to identical state and text',
        () async {
      final p = await freshPair();
      final enc = await p.dr.encrypt(
        state: p.senderState,
        plaintext: Uint8List.fromList(utf8.encode('привет из изолята')),
      );

      // In place — what the app did before step Б.
      final direct = await p.dr.decrypt(
        state: p.receiverState,
        headerDhPubB64: enc.dhPubB64,
        pn: enc.pn,
        n: enc.n,
        ciphertext: enc.ciphertext,
      );

      // Through the worker — same inputs, from the same starting state.
      final viaWorker = await DecryptWorker.instance.decrypt(
        ratchet: p.dr,
        state: p.receiverState,
        headerDhPubB64: enc.dhPubB64,
        pn: enc.pn,
        n: enc.n,
        ciphertext: enc.ciphertext,
      );

      expect(viaWorker.plaintext, equals(direct.plaintext));
      expect(utf8.decode(viaWorker.plaintext), 'привет из изолята');
      // The state is what feeds back into the ratchet — a single wrong byte
      // here silently breaks every later message from this peer.
      expect(viaWorker.updated.nr, direct.updated.nr);
      expect(viaWorker.updated.recvChainKey, equals(direct.updated.recvChainKey));
      expect(viaWorker.updated.dhRemotePub, equals(direct.updated.dhRemotePub));
      expect(viaWorker.updated.rootKey, equals(direct.updated.rootKey));
      expect(viaWorker.consumedPreloadedKey, direct.consumedPreloadedKey);
    });

    test('SKIPPED KEYS survive the crossing — order, numbers and bytes',
        () async {
      // The path step А changed, and the one an out-of-order burst exercises.
      // These records are persisted by the caller; losing or reordering them
      // makes the straggler they exist for permanently unopenable.
      final p = await freshPair();
      var sender = p.senderState;
      DoubleRatchetEncryptResultV3? fifth;
      for (var i = 0; i < 5; i++) {
        final e = await p.dr.encrypt(
          state: sender,
          plaintext: Uint8List.fromList(utf8.encode('msg-$i')),
        );
        sender = e.updated;
        if (i == 4) fifth = e;
      }

      // Only the fifth arrives: the receiver must derive keys for 0..3.
      final direct = await p.dr.decrypt(
        state: p.receiverState,
        headerDhPubB64: fifth!.dhPubB64,
        pn: fifth.pn,
        n: fifth.n,
        ciphertext: fifth.ciphertext,
      );
      final viaWorker = await DecryptWorker.instance.decrypt(
        ratchet: p.dr,
        state: p.receiverState,
        headerDhPubB64: fifth.dhPubB64,
        pn: fifth.pn,
        n: fifth.n,
        ciphertext: fifth.ciphertext,
      );

      expect(direct.skippedToStore, isNotEmpty, reason: 'test would be vacuous');
      expect(viaWorker.skippedToStore.length, direct.skippedToStore.length);
      for (var i = 0; i < direct.skippedToStore.length; i++) {
        expect(viaWorker.skippedToStore[i].msgNum,
            direct.skippedToStore[i].msgNum);
        expect(viaWorker.skippedToStore[i].dhPubB64,
            direct.skippedToStore[i].dhPubB64);
        expect(viaWorker.skippedToStore[i].messageKey,
            equals(direct.skippedToStore[i].messageKey));
      }
    });

    test('a preloaded skipped key opens the straggler and is reported consumed',
        () async {
      final p = await freshPair();
      var sender = p.senderState;
      final sent = <DoubleRatchetEncryptResultV3>[];
      for (var i = 0; i < 3; i++) {
        final e = await p.dr.encrypt(
          state: sender,
          plaintext: Uint8List.fromList(utf8.encode('m$i')),
        );
        sender = e.updated;
        sent.add(e);
      }

      // Receive the last one first, keeping the keys it skipped over.
      final ahead = await DecryptWorker.instance.decrypt(
        ratchet: p.dr,
        state: p.receiverState,
        headerDhPubB64: sent[2].dhPubB64,
        pn: sent[2].pn,
        n: sent[2].n,
        ciphertext: sent[2].ciphertext,
      );
      final keyForFirst = ahead.skippedToStore
          .firstWhere((r) => r.msgNum == sent[0].n)
          .messageKey;

      // Now the straggler arrives and must open with that stored key.
      final late = await DecryptWorker.instance.decrypt(
        ratchet: p.dr,
        state: ahead.updated,
        headerDhPubB64: sent[0].dhPubB64,
        pn: sent[0].pn,
        n: sent[0].n,
        ciphertext: sent[0].ciphertext,
        preloadedSkippedKey: keyForFirst,
      );
      expect(utf8.decode(late.plaintext), 'm0');
      expect(
        late.consumedPreloadedKey,
        isTrue,
        reason: 'the caller must be told to retire a single-use key, or the '
            'same ciphertext could be opened twice',
      );
    });
  });

  group('🔴 Н-6: an error keeps its TEXT across the isolate boundary', () {
    test('a corrupt ciphertext still classifies as a PERMANENT failure',
        () async {
      final p = await freshPair();
      final enc = await p.dr.encrypt(
        state: p.senderState,
        plaintext: Uint8List.fromList(utf8.encode('tamper me')),
      );
      final broken = Uint8List.fromList(enc.ciphertext);
      broken[broken.length - 1] ^= 0xFF; // break the AEAD tag

      Object? viaWorker;
      try {
        await DecryptWorker.instance.decrypt(
          ratchet: p.dr,
          state: p.receiverState,
          headerDhPubB64: enc.dhPubB64,
          pn: enc.pn,
          n: enc.n,
          ciphertext: broken,
        );
      } catch (e) {
        viaWorker = e;
      }

      expect(viaWorker, isNotNull, reason: 'a broken tag must not decrypt');
      // The whole point: the verdict must be unchanged by the crossing.
      // Getting this wrong parks a dead wire forever, or acknowledges away a
      // recoverable one.
      expect(
        DeliveredDecryptAckPolicy.isTransientDecryptError(viaWorker!),
        isFalse,
        reason: 'a broken AEAD tag is permanent, not something to retry',
      );
    });

    test('a transient ratchet verdict stays TRANSIENT', () async {
      // "too many skipped messages" is thrown by the skip loop and is the
      // verdict most at risk from a lossy boundary: it is recoverable, so
      // misreading it as permanent destroys the message.
      final p = await freshPair();
      final enc = await p.dr.encrypt(
        state: p.senderState,
        plaintext: Uint8List.fromList(utf8.encode('far future')),
      );

      Object? err;
      try {
        await DecryptWorker.instance.decrypt(
          ratchet: p.dr,
          state: p.receiverState,
          headerDhPubB64: enc.dhPubB64,
          pn: enc.pn,
          // A counter far past maxSkip — the loop must refuse rather than
          // ratchet towards it.
          n: 100000,
          ciphertext: enc.ciphertext,
        );
      } catch (e) {
        err = e;
      }

      expect(err, isNotNull);
      expect(
        DeliveredDecryptAckPolicy.isTransientDecryptError(err!),
        isTrue,
        reason: 'an absurd counter is recoverable — the wire must be PARKED, '
            'and this is exactly the verdict a lossy boundary would erase',
      );
    });

    test('RemoteDecryptError reports the original text verbatim', () {
      // The mechanism the two tests above depend on, stated directly: every
      // classifier matches substrings of toString(), so the wrapper must not
      // add a prefix of its own.
      const original = 'Bad state: session not found';
      expect(RemoteDecryptError(original).toString(), original);
      expect(
        DeliveredDecryptAckPolicy.isTransientDecryptError(RemoteDecryptError(original)),
        isTrue,
      );
    });
  });

  group('a CUSTOMISED ratchet never reaches the worker', () {
    test('REGRESSION: a subclass keeps its behaviour instead of being replaced',
        () async {
      // The worker constructs its own stock DoubleRatchetV3, so an overridden
      // method would vanish without a trace. Silently ignoring an injected
      // ratchet is how a serialization proof turns into a no-op — which is
      // exactly what session_manager_concurrent_decrypt_test caught.
      final dr = _CountingRatchet();
      final x = X25519();
      final spk = await x.newKeyPairFromSeed(
        Uint8List.fromList(List<int>.generate(32, (i) => i + 3)),
      );
      final spkPub = await spk.extractPublicKey();
      final eph = await x.newKeyPairFromSeed(
        Uint8List.fromList(List<int>.generate(32, (i) => 90 + i)),
      );
      final ephPub = await eph.extractPublicKey();
      final rk = Uint8List.fromList(List<int>.generate(32, (i) => 11));
      final sender = await dr.initInitiator(
        peerDeviceId: 'recv-dev',
        rootKey: rk,
        handshakeEphKeyPair: eph,
        recipientSignedPrekeyPub: Uint8List.fromList(spkPub.bytes),
      );
      final receiver = await dr.initResponder(
        peerDeviceId: 'send-dev',
        rootKey: rk,
        recipientSignedPrekeyKeyPair: spk,
        initiatorDhPub: Uint8List.fromList(ephPub.bytes),
      );
      final enc = await dr.encrypt(
        state: sender,
        plaintext: Uint8List.fromList(utf8.encode('mine, not the stock one')),
      );

      final out = await DecryptWorker.instance.decrypt(
        ratchet: dr,
        state: receiver,
        headerDhPubB64: enc.dhPubB64,
        pn: enc.pn,
        n: enc.n,
        ciphertext: enc.ciphertext,
      );

      expect(utf8.decode(out.plaintext), 'mine, not the stock one');
      expect(
        dr.calls,
        1,
        reason: 'the injected ratchet was bypassed — its behaviour was lost',
      );
    });
  });

  group('degradation is always safe', () {
    test('a disposed worker still decrypts, by falling back in place', () async {
      final p = await freshPair();
      final enc = await p.dr.encrypt(
        state: p.senderState,
        plaintext: Uint8List.fromList(utf8.encode('after teardown')),
      );

      // Warm it, then pull it out from under the next call.
      await DecryptWorker.instance.decrypt(
        ratchet: p.dr,
        state: p.receiverState,
        headerDhPubB64: enc.dhPubB64,
        pn: enc.pn,
        n: enc.n,
        ciphertext: enc.ciphertext,
      );
      DecryptWorker.instance.disposeForTesting();

      final after = await DecryptWorker.instance.decrypt(
        ratchet: p.dr,
        state: p.receiverState,
        headerDhPubB64: enc.dhPubB64,
        pn: enc.pn,
        n: enc.n,
        ciphertext: enc.ciphertext,
      );
      expect(utf8.decode(after.plaintext), 'after teardown');
    });

    test('many concurrent decrypts all come back to the RIGHT caller', () async {
      // One worker serves every request, so a mixed-up id would hand caller A
      // caller B's plaintext — silent, catastrophic, and invisible to a
      // single-request test.
      final p = await freshPair();
      var sender = p.senderState;
      final sent = <DoubleRatchetEncryptResultV3>[];
      for (var i = 0; i < 8; i++) {
        final e = await p.dr.encrypt(
          state: sender,
          plaintext: Uint8List.fromList(utf8.encode('parallel-$i')),
        );
        sender = e.updated;
        sent.add(e);
      }

      final results = await Future.wait([
        for (var i = 0; i < sent.length; i++)
          DecryptWorker.instance.decrypt(
            ratchet: p.dr,
            state: p.receiverState,
            headerDhPubB64: sent[i].dhPubB64,
            pn: sent[i].pn,
            n: sent[i].n,
            ciphertext: sent[i].ciphertext,
          ),
      ]);

      for (var i = 0; i < results.length; i++) {
        expect(utf8.decode(results[i].plaintext), 'parallel-$i');
      }
    });
  });
}

/// A ratchet with behaviour of its own. The worker cannot carry it across an
/// isolate boundary, so routing one there would silently run the stock
/// implementation instead.
class _CountingRatchet extends DoubleRatchetV3 {
  _CountingRatchet();
  int calls = 0;

  @override
  Future<DoubleRatchetDecryptResultV3> decrypt({
    required DoubleRatchetStateV3 state,
    required String headerDhPubB64,
    required int pn,
    required int n,
    required List<int> ciphertext,
    Uint8List? preloadedSkippedKey,
    List<int> aad = const <int>[],
  }) {
    calls++;
    return super.decrypt(
      state: state,
      headerDhPubB64: headerDhPubB64,
      pn: pn,
      n: n,
      ciphertext: ciphertext,
      preloadedSkippedKey: preloadedSkippedKey,
      aad: aad,
    );
  }
}
