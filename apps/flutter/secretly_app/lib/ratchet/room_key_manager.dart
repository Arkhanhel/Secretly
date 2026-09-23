// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';

import '../storage/app_db.dart';
import 'room_key_chain.dart';
import 'room_message_signature.dart';

/// Rotation and chain bookkeeping for the room sender key.
///
/// Sits between [RoomKeyChain] (pure crypto) and [AppDb] (pure storage) and
/// owns the decisions neither of them can make alone: WHEN to rotate, and which
/// key a message may be sealed under. No network, no app state — the send path
/// is wired in фаза 3.
///
/// The rule this class exists to enforce (§6.4): **if the membership changed,
/// a message cannot be sent under the old generation.** Not "should not" —
/// [prepareSend] rotates first and there is no way to obtain a stale slot, so
/// a caller that forgets cannot leak the room to someone who left.
class RoomKeyManager {
  RoomKeyManager(this.db);

  final AppDb db;

  /// Hygiene bounds (§6.5). A generation that lives forever widens the window
  /// a seized device can read.
  static const int maxGenerationAgeMs = 7 * 24 * 60 * 60 * 1000;
  static const int maxGenerationMessages = 2000;

  /// Why [prepareSend] produced a fresh generation. Surfaced for diagnostics —
  /// a rotation nobody can explain is how the earlier session bugs stayed
  /// invisible for weeks.
  static const String rotateReasonFirstUse = 'first_use';
  static const String rotateReasonMembership = 'membership';
  static const String rotateReasonAge = 'age';
  static const String rotateReasonExhausted = 'exhausted';
  /// К-1 (17.09.2026): поколение выдано без ключа подписи (до обновления).
  /// Сменить его — единственный способ начать подписывать сообщения.
  static const String rotateReasonUnsigned = 'unsigned';

  /// Membership as a canonical string. Sorted and de-duplicated so the same
  /// members in a different order do NOT read as a change — otherwise every
  /// sync would rotate and re-broadcast keys for nothing.
  static List<String> canonicalMembers(Iterable<String> deviceIds) {
    final set = <String>{};
    for (final raw in deviceIds) {
      final id = raw.trim();
      // A comma would corrupt the stored CSV and silently merge two members
      // into one entry, which reads as "membership unchanged".
      if (id.isEmpty || id.contains(',')) continue;
      set.add(id);
    }
    final out = set.toList()..sort();
    return out;
  }

  /// The slot a message may be sealed into. Holds the NEXT chain link so the
  /// caller can advance it in the same transaction as the message it wrote —
  /// invariant И-2.
  ///
  /// Obtaining a slot does NOT advance anything. Nothing is durable until
  /// [commitSend], so a crash between the two leaves the chain untouched and
  /// the message simply unsent.

  /// True when [roomId] must move to a new generation before the next send.
  ///
  /// Deterministic and unilateral by design (§6.2): every sender evaluates the
  /// same condition against the same member list and reaches the same answer,
  /// with nothing to negotiate. That matters because each sender owns their own
  /// chain — if only one rotated when a member left, the departed member would
  /// keep reading everyone else.
  Future<String?> rotationReason({
    required String roomId,
    required List<String> members,
    required int nowMs,
    DatabaseExecutor? txn,
  }) async {
    final row = await db.roomSendKeyGet(roomId: roomId, txn: txn);
    if (row == null) return rotateReasonFirstUse;

    final snapshot = await db.roomMemberSnapshotGet(roomId: roomId, txn: txn);
    if (!_sameMembers(snapshot, members)) return rotateReasonMembership;

    final createdAtMs = (row['created_at_ms'] as num?)?.toInt() ?? 0;
    if (createdAtMs > 0 && nowMs - createdAtMs > maxGenerationAgeMs) {
      return rotateReasonAge;
    }
    final counter = (row['counter'] as num?)?.toInt() ?? 0;
    if (counter >= maxGenerationMessages) return rotateReasonExhausted;
    final seed = _blob(row['signing_seed']);
    if (seed == null || seed.length != RoomMessageSignature.seedLen) {
      return rotateReasonUnsigned;
    }
    return null;
  }

  static bool _sameMembers(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Installs a fresh generation: new epoch, new random chain, counter back to
  /// zero, membership recorded, and every delivery record dropped so the new
  /// key is owed to everyone.
  ///
  /// One transaction (§6.3). A half-applied rotation — new chain stored but the
  /// snapshot still holding the old membership — would rotate again on the very
  /// next send, forever.
  Future<void> rotate({
    required String roomId,
    required List<String> members,
    required int nowMs,
    DatabaseExecutor? txn,
  }) async {
    Future<void> apply(DatabaseExecutor t) async {
      final previous = await db.roomSendKeyGet(roomId: roomId, txn: t);
      final nextEpoch = ((previous?['epoch'] as num?)?.toInt() ?? 0) + 1;
      await db.roomSendKeyPut(
        roomId: roomId,
        epoch: nextEpoch,
        chainKey: RoomKeyChain.randomKey(),
        counter: 0,
        createdAtMs: nowMs,
        signingSeed: RoomMessageSignature.newSeed(),
        txn: t,
      );
      await db.roomKeyDeliveryClear(roomId: roomId, txn: t);
      await db.roomMemberSnapshotPut(
        roomId: roomId,
        deviceIds: members,
        updatedAtMs: nowMs,
        txn: t,
      );
    }

    if (txn != null) {
      await apply(txn);
    } else {
      await db.runInTransaction(apply);
    }
  }

  /// The key the next room message may be sealed under, rotating first when the
  /// membership (or hygiene) demands it.
  ///
  /// Returns [RoomSendBlocked] while any current member is still owed this
  /// generation's key. That is §6.4, and it is not a nicety: the chain only
  /// ratchets FORWARD, so a member handed the key after a message went out can
  /// never read that message — not late, never. Queuing the message costs a
  /// delay; sending it costs the message.
  ///
  /// There is deliberately no way to ask for "the current key without
  /// rotating", and no way to reach the key material without going past the
  /// blocked case: a caller holding a stale slot is exactly how a departed
  /// member keeps reading.
  Future<RoomSendOutcome> prepareSend({
    required String roomId,
    required String myDeviceId,
    required Iterable<String> memberDeviceIds,
    required int nowMs,
    DatabaseExecutor? txn,
  }) async {
    final members = canonicalMembers(memberDeviceIds);
    final reason = await rotationReason(
      roomId: roomId,
      members: members,
      nowMs: nowMs,
      txn: txn,
    );
    if (reason != null) {
      await rotate(roomId: roomId, members: members, nowMs: nowMs, txn: txn);
    }

    final row = await db.roomSendKeyGet(roomId: roomId, txn: txn);
    if (row == null) {
      // Only reachable if the row vanished between rotate() and this read.
      throw StateError('room send key missing after rotation: $roomId');
    }

    // Everyone except me: I do not deliver my own key to the device that
    // generated it. My OTHER devices are ordinary recipients and stay in.
    final awaiting = await recipientsMissingKey(
      roomId: roomId,
      memberDeviceIds: members.where((d) => d != myDeviceId),
      txn: txn,
    );
    if (awaiting.isNotEmpty) {
      return RoomSendBlocked(
        roomId: roomId,
        epoch: (row['epoch'] as num?)?.toInt() ?? 0,
        awaitingKey: awaiting,
        rotatedReason: reason,
      );
    }
    final chainKey = _blob(row['chain_key']);
    if (chainKey == null || chainKey.length != RoomKeyChain.keyLen) {
      throw StateError('room send key is corrupt: $roomId');
    }
    final epoch = (row['epoch'] as num?)?.toInt() ?? 0;
    final counter = (row['counter'] as num?)?.toInt() ?? 0;
    final stepped = await RoomKeyChain.step(chainKey: chainKey, roomId: roomId);
    final seed = _blob(row['signing_seed']);
    return RoomSendReady(
      RoomSendSlot._(
        roomId: roomId,
        senderDeviceId: myDeviceId,
        epoch: epoch,
        counter: counter,
        messageKey: stepped.messageKey,
        nextChainKey: stepped.nextChainKey,
        rotatedReason: reason,
        signingSeed: (seed != null && seed.length == RoomMessageSignature.seedLen)
            ? seed
            : null,
      ),
    );
  }

  /// Advances the sending chain past [slot]. Pass the same [txn] the message
  /// was written in (И-2): if the message commits and this does not, the next
  /// send reuses the position — two different messages under one key, which
  /// destroys the AEAD's guarantees.
  ///
  /// Returns false when a rotation overtook this slot, which makes the whole
  /// send stale; the caller must not treat it as sent.
  Future<bool> commitSend({
    required RoomSendSlot slot,
    DatabaseExecutor? txn,
  }) => db.roomSendKeyAdvance(
    roomId: slot.roomId,
    epoch: slot.epoch,
    nextChainKey: slot.nextChainKey,
    nextCounter: slot.counter + 1,
    txn: txn,
  );

  /// The devices that still owe the current generation of my key — everyone
  /// whose recorded epoch is behind, plus everyone with no record at all.
  ///
  /// Compares against MY current epoch rather than a stored "pending" list, so
  /// a delivery attempt lost to a crash simply shows up again.
  Future<List<String>> recipientsMissingKey({
    required String roomId,
    required Iterable<String> memberDeviceIds,
    DatabaseExecutor? txn,
  }) async {
    final row = await db.roomSendKeyGet(roomId: roomId, txn: txn);
    if (row == null) return const <String>[];
    final epoch = (row['epoch'] as num?)?.toInt() ?? 0;
    final out = <String>[];
    for (final device in canonicalMembers(memberDeviceIds)) {
      // 🔴 CONFIRMED, not merely delivered (F-ROOMSK-3/4, after the 1.7.4+416
      // field loss). "Delivered" only ever meant "we put it in the outbox", so
      // the author started sealing messages under a key the member might never
      // have received — and, worse, might not even be able to PARSE.
      //
      // A `gkeyack` can only be produced by a build that understands the
      // sender-key wire. So requiring it does double duty: it proves the key
      // arrived AND that the member can read what we are about to seal. A
      // member on an older build simply never acks, `prepareSend` stays
      // blocked, and the room keeps using the pairwise fanout — which every
      // build in existence can read. That is the coexistence guarantee: the
      // sender key can now only ever be an optimisation, never a way to lose
      // somebody's messages.
      final got = await db.roomKeyConfirmedEpoch(
        roomId: roomId,
        peerDeviceId: device,
        txn: txn,
      );
      if (got == null || got < epoch) out.add(device);
    }
    return out;
  }

  /// The key material to hand [_] — the CURRENT position, never zero.
  ///
  /// A member who joins mid-generation must not be able to derive keys for
  /// messages sent before they arrived, and handing over the chain at counter 0
  /// would let them read the room's entire history since the last rotation.
  Future<RoomKeyGrant?> keyGrantFor({
    required String roomId,
    DatabaseExecutor? txn,
  }) async {
    final row = await db.roomSendKeyGet(roomId: roomId, txn: txn);
    if (row == null) return null;
    final chainKey = _blob(row['chain_key']);
    if (chainKey == null) return null;
    final seed = _blob(row['signing_seed']);
    return RoomKeyGrant(
      roomId: roomId,
      epoch: (row['epoch'] as num?)?.toInt() ?? 0,
      counter: (row['counter'] as num?)?.toInt() ?? 0,
      chainKey: chainKey,
      signingPub: (seed != null && seed.length == RoomMessageSignature.seedLen)
          ? await RoomMessageSignature.publicKeyForSeed(seed)
          : null,
    );
  }

  /// Stores a peer's key. Idempotent (§11.6): re-issuing the same generation is
  /// a no-op, so the author may re-send freely — which is what makes `gkeyreq`
  /// recovery safe.
  ///
  /// A LATER grant for a generation already in progress is ignored: it would
  /// rewind the receiving chain and orphan the skipped keys held for messages
  /// still in flight.
  Future<bool> acceptKeyGrant({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required int counter,
    required Uint8List chainKey,
    required int nowMs,
    Uint8List? signingPub,
    DatabaseExecutor? txn,
  }) async {
    if (chainKey.length != RoomKeyChain.keyLen) return false;
    if (signingPub != null &&
        signingPub.length != RoomMessageSignature.publicKeyLen) {
      return false;
    }
    final existing = await db.roomRecvKeyGet(
      roomId: roomId,
      senderDeviceId: senderDeviceId,
      epoch: epoch,
      txn: txn,
    );
    if (existing != null) return false;
    await db.roomRecvKeyPut(
      roomId: roomId,
      senderDeviceId: senderDeviceId,
      epoch: epoch,
      chainKey: chainKey,
      counter: counter,
      updatedAtMs: nowMs,
      signingPub: signingPub,
      txn: txn,
    );
    return true;
  }

  /// The key that opens an incoming message, or null when this device cannot
  /// (yet) read it — a missing generation, a counter too far ahead, or a
  /// position the chain already consumed.
  ///
  /// Null is never an error to swallow: the caller parks the wire and asks the
  /// author for the key (`gkeyreq`).
  Future<RoomRecvSlot?> openInbound({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required int counter,
    DatabaseExecutor? txn,
  }) async {
    // A straggler whose position the chain already passed.
    final parked = await db.roomSkippedKeyGet(
      roomId: roomId,
      senderDeviceId: senderDeviceId,
      epoch: epoch,
      counter: counter,
      txn: txn,
    );
    // К-1: the author's signing key for this generation, if it sent one.
    final keyRow = await db.roomRecvKeyGet(
      roomId: roomId,
      senderDeviceId: senderDeviceId,
      epoch: epoch,
      txn: txn,
    );
    final signingPub = _blob(keyRow?['signing_pub']);
    if (parked != null) {
      return RoomRecvSlot._(
        signingPub: signingPub,
        roomId: roomId,
        senderDeviceId: senderDeviceId,
        epoch: epoch,
        counter: counter,
        messageKey: parked,
        fromSkipped: true,
        nextChainKey: null,
        skipped: const <int, Uint8List>{},
      );
    }

    final row = keyRow;
    if (row == null) return null;
    final chainKey = _blob(row['chain_key']);
    if (chainKey == null || chainKey.length != RoomKeyChain.keyLen) return null;
    final at = (row['counter'] as num?)?.toInt() ?? 0;

    // Behind the chain with no parked key means the position was already used
    // and its key destroyed — a REPLAY. Forward secrecy is what refuses it:
    // there is no way to re-derive a consumed key, so a replayed message can
    // never open twice. (§11.4)
    if (counter < at) return null;

    final advanced = await RoomKeyChain.advanceTo(
      chainKey: chainKey,
      roomId: roomId,
      fromCounter: at,
      toCounter: counter,
    );
    // Null here is the DoS guard: a wire claiming an absurd counter must not be
    // allowed to burn CPU ratcheting towards it.
    if (advanced == null) return null;

    return RoomRecvSlot._(
      signingPub: signingPub,
      roomId: roomId,
      senderDeviceId: senderDeviceId,
      epoch: epoch,
      counter: counter,
      messageKey: advanced.messageKey,
      fromSkipped: false,
      nextChainKey: advanced.nextChainKey,
      skipped: advanced.skipped,
    );
  }

  /// Позиция уже открыта (или её ключ уничтожен): это копия прочитанного
  /// сообщения, а не сообщение без ключа. Ключа для неё не будет никогда —
  /// такую копию не паркуют и ключ у автора не просят.
  Future<bool> isSpentPosition({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required int counter,
  }) async {
    final row = await db.roomRecvKeyGet(
      roomId: roomId,
      senderDeviceId: senderDeviceId,
      epoch: epoch,
    );
    if (row == null) return false;
    final at = (row['counter'] as num?)?.toInt() ?? 0;
    if (counter >= at) return false;
    final parked = await db.roomSkippedKeyGet(
      roomId: roomId,
      senderDeviceId: senderDeviceId,
      epoch: epoch,
      counter: counter,
    );
    return parked == null;
  }

  /// Makes an inbound message durable: consumes the key it used and stores the
  /// keys for positions jumped over.
  ///
  /// Call ONLY after the tag verified. Consuming first would let anyone destroy
  /// a legitimate key by posting one corrupt ciphertext at that position —
  /// message loss on demand.
  Future<void> commitInbound({
    required RoomRecvSlot slot,
    required int nowMs,
    DatabaseExecutor? txn,
  }) async {
    if (slot.fromSkipped) {
      // Single use: deleting it is what stops the same ciphertext opening twice.
      await db.roomSkippedKeyDelete(
        roomId: slot.roomId,
        senderDeviceId: slot.senderDeviceId,
        epoch: slot.epoch,
        counter: slot.counter,
        txn: txn,
      );
      return;
    }
    for (final entry in slot.skipped.entries) {
      await db.roomSkippedKeyPut(
        roomId: slot.roomId,
        senderDeviceId: slot.senderDeviceId,
        epoch: slot.epoch,
        counter: entry.key,
        messageKey: entry.value,
        createdAtMs: nowMs,
        txn: txn,
      );
    }
    // Advance in place: a full rewrite would drop the author's signing key.
    await db.roomRecvKeyAdvance(
      roomId: slot.roomId,
      senderDeviceId: slot.senderDeviceId,
      epoch: slot.epoch,
      chainKey: slot.nextChainKey!,
      counter: slot.counter + 1,
      updatedAtMs: nowMs,
      txn: txn,
    );
  }

  static Uint8List? _blob(Object? raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }
}

/// The answer to "may I send into this room right now?".
///
/// Sealed so the blocked case cannot be skipped: reaching the key material
/// requires handling it, which is what stops a message going out under a
/// generation some member has not been given.
sealed class RoomSendOutcome {
  const RoomSendOutcome();
}

class RoomSendReady extends RoomSendOutcome {
  const RoomSendReady(this.slot);

  final RoomSendSlot slot;
}

/// Someone in the room has not been handed this generation's key yet. Deliver
/// to [awaitingKey], mark delivery, then ask again — the message waits in the
/// queue meanwhile (§6.4).
class RoomSendBlocked extends RoomSendOutcome {
  const RoomSendBlocked({
    required this.roomId,
    required this.epoch,
    required this.awaitingKey,
    required this.rotatedReason,
  });

  final String roomId;
  final int epoch;
  final List<String> awaitingKey;

  /// Non-null when this call also rotated — the usual reason a send is blocked.
  final String? rotatedReason;
}

/// A reserved position on my sending chain. Nothing is durable until
/// [RoomKeyManager.commitSend].
class RoomSendSlot {
  const RoomSendSlot._({
    required this.roomId,
    required this.senderDeviceId,
    required this.epoch,
    required this.counter,
    required this.messageKey,
    required this.nextChainKey,
    required this.rotatedReason,
    required this.signingSeed,
  });

  /// К-1: секрет подписи этого поколения (null — поколение без подписи).
  final Uint8List? signingSeed;

  final String roomId;

  /// My own device id. Carried here rather than left to the caller so the AAD
  /// that seals a message and the AAD a receiver rebuilds cannot disagree — a
  /// mismatch is an unopenable message with no visible cause.
  final String senderDeviceId;

  final int epoch;
  final int counter;
  final Uint8List messageKey;
  final Uint8List nextChainKey;

  /// Non-null when this send triggered a rotation, naming why.
  final String? rotatedReason;

  Uint8List get aad => RoomKeyChain.aad(
    roomId: roomId,
    senderDeviceId: senderDeviceId,
    epoch: epoch,
    counter: counter,
  );

  /// Redacted: this object holds a message key.
  @override
  String toString() =>
      'RoomSendSlot($roomId, epoch=$epoch, counter=$counter, key=<redacted>)';
}

/// A key handed to a peer.
class RoomKeyGrant {
  const RoomKeyGrant({
    required this.roomId,
    required this.epoch,
    required this.counter,
    required this.chainKey,
    this.signingPub,
  });

  final String roomId;
  final int epoch;
  final int counter;
  final Uint8List chainKey;

  /// К-1: открытый ключ подписи поколения — едет в `gkey`.
  final Uint8List? signingPub;

  /// Redacted: this object IS the room secret.
  @override
  String toString() =>
      'RoomKeyGrant($roomId, epoch=$epoch, counter=$counter, key=<redacted>)';
}

/// A key that opens one inbound message. Nothing is durable until
/// [RoomKeyManager.commitInbound], which must run only after the tag verified.
class RoomRecvSlot {
  const RoomRecvSlot._({
    required this.roomId,
    required this.senderDeviceId,
    required this.epoch,
    required this.counter,
    required this.messageKey,
    required this.fromSkipped,
    required this.nextChainKey,
    required this.skipped,
    required this.signingPub,
  });

  /// К-1: открытый ключ подписи автора для этого поколения. Есть — подпись
  /// сообщения обязательна; нет — поколение выдано сборкой без подписи.
  final Uint8List? signingPub;

  final String roomId;
  final String senderDeviceId;
  final int epoch;
  final int counter;
  final Uint8List messageKey;

  /// True when the key came from the parked-straggler store rather than by
  /// ratcheting — commit then CONSUMES it instead of advancing the chain.
  final bool fromSkipped;

  final Uint8List? nextChainKey;
  final Map<int, Uint8List> skipped;

  Uint8List get aad => RoomKeyChain.aad(
    roomId: roomId,
    senderDeviceId: senderDeviceId,
    epoch: epoch,
    counter: counter,
  );

  @override
  String toString() =>
      'RoomRecvSlot($roomId, from=$senderDeviceId, epoch=$epoch, '
      'counter=$counter, key=<redacted>)';
}
