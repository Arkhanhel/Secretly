// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ratchet/room_key_chain.dart';

/// Unrepresentability tests for the room sender key
/// (docs/TZ_ROOM_SENDER_KEY_2026-07-29.md §11).
///
/// These are not "does it round-trip" tests. Each one pins a property that must
/// be IMPOSSIBLE to violate, because the failure mode is a departed member
/// reading the room or a message being lost — the two outcomes this design
/// exists to prevent.
void main() {
  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

  Future<({String nonceB64, String ciphertextB64})> seal({
    required Uint8List key,
    required String text,
    required String roomId,
    required String sender,
    required int epoch,
    required int counter,
  }) => RoomKeyChain.encrypt(
    messageKey: key,
    plaintext: bytes(text),
    aad: RoomKeyChain.aad(
      roomId: roomId,
      senderDeviceId: sender,
      epoch: epoch,
      counter: counter,
    ),
  );

  test('round trip: a message sealed to a position opens at that position', () async {
    final chain = RoomKeyChain.randomKey();
    final s = await RoomKeyChain.step(chainKey: chain, roomId: 'group:r1');
    final box = await seal(
      key: s.messageKey,
      text: 'привет комната',
      roomId: 'group:r1',
      sender: 'devA',
      epoch: 1,
      counter: 0,
    );
    final plain = await RoomKeyChain.decrypt(
      messageKey: s.messageKey,
      nonceB64: box.nonceB64,
      ciphertextB64: box.ciphertextB64,
      aad: RoomKeyChain.aad(
        roomId: 'group:r1',
        senderDeviceId: 'devA',
        epoch: 1,
        counter: 0,
      ),
    );
    expect(utf8.decode(plain!), 'привет комната');
  });

  test(
    'forward secrecy: the next chain link cannot open the previous message',
    () async {
      // This is what makes a seized device unable to read the room's past.
      final chain = RoomKeyChain.randomKey();
      final first = await RoomKeyChain.step(chainKey: chain, roomId: 'group:r1');
      final box = await seal(
        key: first.messageKey,
        text: 'старое',
        roomId: 'group:r1',
        sender: 'devA',
        epoch: 1,
        counter: 0,
      );
      final next = await RoomKeyChain.step(
        chainKey: first.nextChainKey,
        roomId: 'group:r1',
      );
      final opened = await RoomKeyChain.decrypt(
        messageKey: next.messageKey,
        nonceB64: box.nonceB64,
        ciphertextB64: box.ciphertextB64,
        aad: RoomKeyChain.aad(
          roomId: 'group:r1',
          senderDeviceId: 'devA',
          epoch: 1,
          counter: 0,
        ),
      );
      expect(opened, isNull);
    },
  );

  test(
    'a NEW generation cannot open the old one — this is what removes a '
    'departed member',
    () async {
      // Rotation replaces the chain with fresh randomness. If an old ciphertext
      // could still be opened under the new generation, rotating on departure
      // would be theatre.
      final oldChain = RoomKeyChain.randomKey();
      final oldStep = await RoomKeyChain.step(chainKey: oldChain, roomId: 'group:r1');
      final box = await seal(
        key: oldStep.messageKey,
        text: 'до ротации',
        roomId: 'group:r1',
        sender: 'devA',
        epoch: 1,
        counter: 0,
      );

      final newChain = RoomKeyChain.randomKey();
      final newStep = await RoomKeyChain.step(chainKey: newChain, roomId: 'group:r1');
      final opened = await RoomKeyChain.decrypt(
        messageKey: newStep.messageKey,
        nonceB64: box.nonceB64,
        ciphertextB64: box.ciphertextB64,
        aad: RoomKeyChain.aad(
          roomId: 'group:r1',
          senderDeviceId: 'devA',
          epoch: 2,
          counter: 0,
        ),
      );
      expect(opened, isNull);
    },
  );

  test('a ciphertext cannot be replayed into another room', () async {
    final chain = RoomKeyChain.randomKey();
    final s = await RoomKeyChain.step(chainKey: chain, roomId: 'group:r1');
    final box = await seal(
      key: s.messageKey,
      text: 'секрет комнаты 1',
      roomId: 'group:r1',
      sender: 'devA',
      epoch: 1,
      counter: 0,
    );
    // Same key, everything else identical, only the room differs.
    final opened = await RoomKeyChain.decrypt(
      messageKey: s.messageKey,
      nonceB64: box.nonceB64,
      ciphertextB64: box.ciphertextB64,
      aad: RoomKeyChain.aad(
        roomId: 'group:r2',
        senderDeviceId: 'devA',
        epoch: 1,
        counter: 0,
      ),
    );
    expect(opened, isNull);
  });

  test('a ciphertext cannot be attributed to another sender or position', () async {
    final chain = RoomKeyChain.randomKey();
    final s = await RoomKeyChain.step(chainKey: chain, roomId: 'group:r1');
    final box = await seal(
      key: s.messageKey,
      text: 'от devA',
      roomId: 'group:r1',
      sender: 'devA',
      epoch: 1,
      counter: 7,
    );
    for (final wrong in [
      RoomKeyChain.aad(roomId: 'group:r1', senderDeviceId: 'devB', epoch: 1, counter: 7),
      RoomKeyChain.aad(roomId: 'group:r1', senderDeviceId: 'devA', epoch: 9, counter: 7),
      RoomKeyChain.aad(roomId: 'group:r1', senderDeviceId: 'devA', epoch: 1, counter: 8),
    ]) {
      expect(
        await RoomKeyChain.decrypt(
          messageKey: s.messageKey,
          nonceB64: box.nonceB64,
          ciphertextB64: box.ciphertextB64,
          aad: wrong,
        ),
        isNull,
      );
    }
  });

  test(
    'out of order: a jump forward keeps the skipped keys, so the stragglers '
    'still open later',
    () async {
      final chain = RoomKeyChain.randomKey();
      // Sender is at 0 and produces 0..3; receiver sees #3 first.
      var senderChain = chain;
      final sealed = <int, ({String nonceB64, String ciphertextB64})>{};
      for (var i = 0; i < 4; i++) {
        final s = await RoomKeyChain.step(chainKey: senderChain, roomId: 'group:r1');
        sealed[i] = await seal(
          key: s.messageKey,
          text: 'msg $i',
          roomId: 'group:r1',
          sender: 'devA',
          epoch: 1,
          counter: i,
        );
        senderChain = s.nextChainKey;
      }

      final jump = await RoomKeyChain.advanceTo(
        chainKey: chain,
        roomId: 'group:r1',
        fromCounter: 0,
        toCounter: 3,
      );
      expect(jump, isNotNull);

      // The message that actually arrived opens.
      final got3 = await RoomKeyChain.decrypt(
        messageKey: jump!.messageKey,
        nonceB64: sealed[3]!.nonceB64,
        ciphertextB64: sealed[3]!.ciphertextB64,
        aad: RoomKeyChain.aad(
          roomId: 'group:r1',
          senderDeviceId: 'devA',
          epoch: 1,
          counter: 3,
        ),
      );
      expect(utf8.decode(got3!), 'msg 3');

      // And the ones we jumped over are still readable when they turn up.
      for (final i in [0, 1, 2]) {
        final k = jump.skipped[i];
        expect(k, isNotNull, reason: 'skipped key $i must be retained');
        final got = await RoomKeyChain.decrypt(
          messageKey: k!,
          nonceB64: sealed[i]!.nonceB64,
          ciphertextB64: sealed[i]!.ciphertextB64,
          aad: RoomKeyChain.aad(
            roomId: 'group:r1',
            senderDeviceId: 'devA',
            epoch: 1,
            counter: i,
          ),
        );
        expect(utf8.decode(got!), 'msg $i');
      }
    },
  );

  test(
    'an absurd counter is refused instead of spinning the CPU (cheap DoS)',
    () async {
      final chain = RoomKeyChain.randomKey();
      expect(
        await RoomKeyChain.advanceTo(
          chainKey: chain,
          roomId: 'group:r1',
          fromCounter: 0,
          toCounter: RoomKeyChain.maxSkip + 1,
        ),
        isNull,
      );
      // Going backwards is nonsense too — the caller must use a skipped key.
      expect(
        await RoomKeyChain.advanceTo(
          chainKey: chain,
          roomId: 'group:r1',
          fromCounter: 5,
          toCounter: 4,
        ),
        isNull,
      );
    },
  );

  test('the same chain in a different room yields different keys', () async {
    // The room id is the HKDF salt, so one chain leaked into another room is
    // not usable there even if the bytes are identical.
    final chain = RoomKeyChain.randomKey();
    final a = await RoomKeyChain.step(chainKey: chain, roomId: 'group:r1');
    final b = await RoomKeyChain.step(chainKey: chain, roomId: 'group:r2');
    expect(a.messageKey, isNot(equals(b.messageKey)));
    expect(a.nextChainKey, isNot(equals(b.nextChainKey)));
  });

  test('tampered ciphertext never opens', () async {
    final chain = RoomKeyChain.randomKey();
    final s = await RoomKeyChain.step(chainKey: chain, roomId: 'group:r1');
    final box = await seal(
      key: s.messageKey,
      text: 'целостность',
      roomId: 'group:r1',
      sender: 'devA',
      epoch: 1,
      counter: 0,
    );
    final raw = base64Decode(box.ciphertextB64);
    raw[0] ^= 0xFF;
    expect(
      await RoomKeyChain.decrypt(
        messageKey: s.messageKey,
        nonceB64: box.nonceB64,
        ciphertextB64: base64Encode(raw),
        aad: RoomKeyChain.aad(
          roomId: 'group:r1',
          senderDeviceId: 'devA',
          epoch: 1,
          counter: 0,
        ),
      ),
      isNull,
    );
  });
}
