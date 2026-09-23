// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Sender-key chain for a room (фаза 2).
///
/// Today a room message is encrypted SEPARATELY for every device of every
/// member: N×M ratchet steps per message, which is what burns the sender's CPU
/// and battery and puts a hard ceiling on room size. With a sender key the
/// author encrypts ONCE; the key itself travels to each member exactly once per
/// generation over the existing pairwise channel.
///
/// This file is the crypto only — no database, no network, no app state — so it
/// can be reasoned about and tested in isolation. Wiring lives in later phases;
/// nothing calls this yet.
///
/// Design notes that matter:
///  * The chain ratchets FORWARD on every message and the previous link is
///    dropped, so a device seized later cannot decrypt earlier room traffic.
///  * The AAD binds every ciphertext to `roomId|senderDeviceId|epoch|counter`.
///    A ciphertext therefore cannot be replayed into another room, another
///    generation, or another position — the tag simply fails.
///  * Each SENDER owns their own chain. There is no single shared room key, so
///    "rotate on membership change" means every member rotates their own chain
///    (see the TZ §6) — this class only provides the primitive.
class RoomKeyChain {
  const RoomKeyChain._();

  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _aead = Xchacha20.poly1305Aead();
  static final _rng = Random.secure();

  static const int keyLen = 32;
  static const int nonceLen = 24;

  /// Hard cap on how far the receiver will ratchet forward to reach an
  /// out-of-order message. Mirrors the pairwise `maxSkip`: without it a wire
  /// claiming `counter = 2^31` would spin the CPU forever — a cheap denial of
  /// service from anyone who can post to the room.
  static const int maxSkip = 200;

  static Uint8List randomKey() => _randomBytes(keyLen);

  static Uint8List _randomBytes(int n) {
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  /// The message key for the current link, and the next chain link.
  ///
  /// Two different `info` strings off the same secret: the value used to
  /// encrypt is never the value kept for the next step, so learning one message
  /// key tells you nothing about the chain.
  static Future<({Uint8List messageKey, Uint8List nextChainKey})> step({
    required Uint8List chainKey,
    required String roomId,
  }) async {
    final salt = utf8.encode(roomId);
    final messageKey = await _derive(chainKey, salt, 'secretly/room/msg/v1');
    final nextChainKey = await _derive(
      chainKey,
      salt,
      'secretly/room/chain/v1',
    );
    return (messageKey: messageKey, nextChainKey: nextChainKey);
  }

  static Future<Uint8List> _derive(
    Uint8List ikm,
    List<int> salt,
    String info,
  ) async {
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: salt,
      info: utf8.encode(info),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Binds a ciphertext to its exact place. Any mismatch fails the tag, which
  /// is what makes cross-room and cross-generation replay impossible.
  static Uint8List aad({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required int counter,
  }) => Uint8List.fromList(
    utf8.encode('$roomId|$senderDeviceId|$epoch|$counter'),
  );

  /// Encrypts [plaintext] under [messageKey]. Returns the nonce and the
  /// ciphertext-with-tag, base64 for the wire.
  static Future<({String nonceB64, String ciphertextB64})> encrypt({
    required Uint8List messageKey,
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    final nonce = _randomBytes(nonceLen);
    final box = await _aead.encrypt(
      plaintext,
      secretKey: SecretKey(messageKey),
      nonce: nonce,
      aad: aad,
    );
    final joined = Uint8List(box.cipherText.length + box.mac.bytes.length)
      ..setRange(0, box.cipherText.length, box.cipherText)
      ..setRange(
        box.cipherText.length,
        box.cipherText.length + box.mac.bytes.length,
        box.mac.bytes,
      );
    return (nonceB64: base64Encode(nonce), ciphertextB64: base64Encode(joined));
  }

  /// Decrypts, or returns null when the wire is malformed or the tag fails —
  /// callers treat null as "not for this key" and park the wire rather than
  /// throwing into the inbound path.
  static Future<Uint8List?> decrypt({
    required Uint8List messageKey,
    required String nonceB64,
    required String ciphertextB64,
    required Uint8List aad,
  }) async {
    try {
      final nonce = base64Decode(nonceB64);
      final joined = base64Decode(ciphertextB64);
      if (nonce.length != nonceLen || joined.length < 16) return null;
      final macStart = joined.length - 16;
      final plain = await _aead.decrypt(
        SecretBox(
          joined.sublist(0, macStart),
          nonce: nonce,
          mac: Mac(joined.sublist(macStart)),
        ),
        secretKey: SecretKey(messageKey),
        aad: aad,
      );
      return Uint8List.fromList(plain);
    } catch (_) {
      return null;
    }
  }

  /// Ratchets from [fromCounter] to [toCounter], returning the message key for
  /// the target and every key skipped on the way (so an out-of-order wire that
  /// arrives later can still be read).
  ///
  /// Returns null when the jump exceeds [maxSkip] — a wire claiming an absurd
  /// counter must not be allowed to burn CPU.
  static Future<
    ({
      Uint8List messageKey,
      Uint8List nextChainKey,
      Map<int, Uint8List> skipped,
    })?
  >
  advanceTo({
    required Uint8List chainKey,
    required String roomId,
    required int fromCounter,
    required int toCounter,
  }) async {
    if (toCounter < fromCounter) return null;
    if (toCounter - fromCounter > maxSkip) return null;
    var key = chainKey;
    final skipped = <int, Uint8List>{};
    for (var i = fromCounter; i < toCounter; i++) {
      final s = await step(chainKey: key, roomId: roomId);
      skipped[i] = s.messageKey;
      key = s.nextChainKey;
    }
    final target = await step(chainKey: key, roomId: roomId);
    return (
      messageKey: target.messageKey,
      nextChainKey: target.nextChainKey,
      skipped: skipped,
    );
  }
}
