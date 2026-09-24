// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common/sqlite_api.dart' show DatabaseExecutor;
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../diagnostics/diag_log.dart';
import '../security/device_keys.dart';
import '../storage/app_db.dart';
import '../transport/keys_client.dart';
import 'decrypt_worker.dart';
import 'double_ratchet_v3.dart';
import 'handshake_signature.dart';
import 'session_v1.dart';
import 'wire_v3.dart';

/// How long after we initiate a fresh session a colliding inbound prekey is
/// treated as a glare (both sides re-established at once) and resolved by the
/// deterministic tie-break. Outside this window the local session is considered
/// established/stale and always yields to the peer's fresh prekey.
///
/// CONVERGENCE FIX (2026-06-25): widened 120 s -> 360 s. In a bidirectional
/// reset-ping war the two sides re-initiate ~90 s–360 s apart (quarantine sweep,
/// silence sweep, escalator cap all sit in that range), so colliding prekeys
/// were arriving OUTSIDE the old 120 s window — the deterministic tie-break
/// below never engaged and each side blindly adopted the other's fresh prekey,
/// diverging again on the very next message (a permanent ping-pong that also
/// dropped real messages, e.g. emoji that "never arrived"). 360 s (>= the 6-min
/// silence threshold and >= the 300 s escalator cap) makes the tie-break fire
/// for the real-world collision spacing so both devices converge on ONE shared
/// ratchet within a single cycle. This changes only WHICH of two real, fully
/// derived sessions becomes primary (deterministic root-key compare, identical
/// on both peers); the loser is archived so stragglers stay decryptable — no key
/// material, handshake, or forward-secrecy property is touched.
const int kGlareWindowMs = 360 * 1000;

/// Э-4 Ш-4: may this build
/// REPEAT its handshake on every message until the peer confirms the session?
///
/// 🔴 STARTS OFF, and the order of rollout is the whole point. Turning this on
/// changes what PEERS receive, so every build in the field must first be able
/// to handle a repeat harmlessly — that is Ш-2, which ships in the same binary
/// but works regardless of this flag. Enabling send before receive has spread
/// is exactly what happened on 1.7.4+416: a build emitted a format its peers
/// could not process, wires were acked, and messages were lost for good.
///
/// Receive is deliberately NOT gated by any flag, mirroring the room sender-key
/// rollout (`app_controller.dart`, `_roomSenderKeyReceiveEnabledEnv`): a build
/// that CAN read a repeat must always read it, whether or not it sends any.
/// Refusing to read can only lose messages; it can never save one.
const bool _kPrekeyUntilConfirmedEnv = bool.fromEnvironment(
  'SECRETLY_PREKEY_UNTIL_CONFIRMED',
);

/// Runtime view of [_kPrekeyUntilConfirmedEnv]. Mutable so the field switch can
/// be flipped without a rebuild once the receiving half has spread, and so
/// tests can exercise both paths.
///
/// ISOLATE SCOPE, deliberately harmless: a top-level global is per-isolate, so
/// flipping this in the foreground does NOT reach the background fetcher. That
/// costs nothing here — the background isolate only ever downloads and decrypts
/// (the И-3 single-writer lease exists to keep it that way), and RECEIVING a
/// repeat is not gated by this flag at all. Only sending is, and sending only
/// happens in the foreground.
bool kPrekeyUntilConfirmedSend = _kPrekeyUntilConfirmedEnv;

/// Э-4 Ш-5 (Р-7): stop repeating the handshake after this long unconfirmed.
///
/// A session toward a device that never answers would otherwise carry a
/// handshake on every message for the rest of the mailbox's life. The audit of
/// 2026-08-01 found 1823 of 1920 registered devices silent for more than three
/// days, so this is the common case, not the exotic one.
///
/// The cost of a repeat is small — measured at +92 bytes of frame — so the cap
/// is generous: it exists to stop the unbounded case, not to ration a scarce
/// resource. Seven days matches the relay's own mailbox TTL: past it, the
/// messages this handshake would have healed are gone from the server anyway.
const int kPrekeyRepeatMaxAgeMs = 7 * 24 * 60 * 60 * 1000;

/// TZ Epic B (2026-07-18): a session wire whose header 'se' (session epoch =
/// creation wall-ms, stamped by the sender) is NEWER than the epoch of every
/// session we hold for that peer. Decrypt failing here means the REKEY IS EN
/// ROUTE (its prekey wire is in the same mailbox) — the caller parks the wire
/// as transient and must NOT NACK it (the cure is already inbound).
class EpochAheadException implements Exception {
  EpochAheadException({
    required this.senderDeviceId,
    required this.wireEpoch,
    required this.localEpoch,
  });

  final String senderDeviceId;
  final int wireEpoch;
  final int localEpoch;

  @override
  String toString() =>
      'EpochAheadException(epoch_ahead: wire=$wireEpoch local=$localEpoch)';
}

/// С-2 (24.09.2026): рукопожатие от устройства, которое уже доказало, что
/// подписывает свои рукопожатия, пришло без подписи или с чужой подписью.
///
/// Наследует [StateError] НАМЕРЕННО: для вызывающего это обычная неудача
/// расшифровки, и карантин, повторы и лечение работают ровно как раньше.
/// Сессия при этом не тронута — отказ случается до X3DH, внутри транзакции,
/// которая откатывается.
class HandshakeAuthRejectedException extends StateError {
  HandshakeAuthRejectedException({
    required this.senderDeviceId,
    required this.outcome,
  }) : super('handshake auth rejected ($outcome) for $senderDeviceId');

  final String senderDeviceId;
  final String outcome;
}

/// С-2: проверка подписи рукопожатия в два шага.
///
/// ДО транзакции расшифровки собираются факты из базы ([_HandshakeAuthVerdict]
/// создаёт [_evaluateHandshakeAuth]): закреплённый ключ, доказан ли он,
/// выключатель. Сама подпись проверяется ВНУТРИ транзакции, в момент первого
/// вида рукопожатия, на уже загруженном SPK ([decide]) — без обращений к базе
/// и без лишнего чтения связки ключей ОС. Повторы до этого шага не доходят.
class _HandshakeAuthVerdict {
  _HandshakeAuthVerdict({
    required this.senderDeviceId,
    required this.signatureB64,
    required this.pinnedCount,
    required this.key,
    required this.proven,
    required this.switchOff,
  });

  final String senderDeviceId;
  final String? signatureB64;
  final int pinnedCount;

  /// Ключ, которым проверять: доказанный (если он среди закреплённых), иначе
  /// единственный закреплённый; `null` — не знаем, чем проверять.
  final String? key;

  /// Устройство уже доказало, что подписывает рукопожатия этим [key].
  final bool proven;

  /// Выключатель с сервера снял отказы (но не проверку и не счёт).
  final bool switchOff;

  /// `ok` · `bad` · `missing` · `unknown_signed` · `unknown_unsigned` ·
  /// `key_conflict` · `eval_error`; к отказу, снятому выключателем,
  /// добавляется `_switch_off`.
  String outcome = 'eval_error';
  bool reject = false;

  /// Закреплённый ключ, которым подпись сошлась (только при `ok`).
  String? provenKey;

  /// Дошла ли расшифровка до первого вида рукопожатия.
  bool reachedFirstSight = false;

  Future<void> decide({
    required PrekeyHeaderV1 pre,
    required String selfDeviceId,
    required List<int> selfSignedPrekeyPub,
  }) async {
    reachedFirstSight = true;
    try {
      var wouldReject = false;
      final k = key;
      final sig = signatureB64;
      if (k == null) {
        outcome = pinnedCount == 0
            ? (sig == null ? 'unknown_unsigned' : 'unknown_signed')
            : 'key_conflict';
      } else if (sig == null) {
        outcome = 'missing';
        wouldReject = proven;
      } else {
        final ok = await HandshakeSignature.verify(
          identityKeyPubB64: k,
          signatureB64: sig,
          message: HandshakeSignature.message(
            senderDeviceId: senderDeviceId,
            recipientDeviceId: selfDeviceId,
            senderEphemeralPub: base64Decode(pre.senderEphemeralPubB64),
            recipientSignedPrekeyPub: selfSignedPrekeyPub,
            signedPrekeyId: pre.recipientSignedPrekeyId,
            oneTimePrekeyId: pre.recipientOneTimePrekeyId,
          ),
        );
        outcome = ok ? 'ok' : 'bad';
        wouldReject = !ok && proven;
        if (ok) provenKey = k;
      }
      if (wouldReject && switchOff) {
        outcome = '${outcome}_switch_off';
        wouldReject = false;
      }
      reject = wouldReject;
    } catch (_) {
      // Сбой самой проверки — не отказ: ошибка в нашем коде не должна стоить
      // доставки.
      outcome = 'eval_error';
      reject = false;
      provenKey = null;
    }
  }
}

class RatchetSessionManagerV3 {
  RatchetSessionManagerV3({
    required this.db,
    required this.deviceKeys,
    required this.keysClient,
    this.fetchBundleAuthed,
    PrekeyHandshakeV1? handshake,
    DoubleRatchetV3? dr,
  }) : handshake = handshake ?? PrekeyHandshakeV1(),
       dr = dr ?? DoubleRatchetV3();

  final AppDb db;
  final DeviceKeys deviceKeys;
  final KeysClient keysClient;
  final Future<List<Map<String, Object?>>> Function(String profileId)?
  fetchBundleAuthed;
  final PrekeyHandshakeV1 handshake;
  final DoubleRatchetV3 dr;

  /// С-2: ключи личности, которыми это устройство подписывает рукопожатия,
  /// по «профиль/устройство». Кешируется только УДАЧНОЕ чтение: ключ, раз
  /// прочитанный, остаётся в памяти, и минутная недоступность связки ключей
  /// не превращает подписанное устройство в неподписанное.
  final Map<String, SimpleKeyPair> _handshakeSigningKeys =
      <String, SimpleKeyPair>{};

  Future<SimpleKeyPair?> _handshakeSigningKey(
    String? selfProfileId,
    String selfDeviceId,
  ) async {
    final pid = (selfProfileId ?? '').trim();
    final did = selfDeviceId.trim();
    if (pid.isEmpty || did.isEmpty) return null;
    final cacheKey = '$pid/$did';
    final cached = _handshakeSigningKeys[cacheKey];
    if (cached != null) return cached;
    final kp = await deviceKeys.loadIdentityKeyPairIfPresent(
      profileId: pid,
      deviceId: did,
    );
    if (kp != null) _handshakeSigningKeys[cacheKey] = kp;
    return kp;
  }

  /// MESSAGE-LOSS FIX (2026-07-08): per-peer-device serialization of ALL
  /// session-state mutations (encrypt + decrypt). The ratchet session row and
  /// the skipped-key store are read-modify-write: read the session, advance the
  /// ratchet, persist it back. Two inbound messages from the same sender
  /// processed CONCURRENTLY (e.g. the HTTP `/pending` drain and a realtime WS
  /// `Deliver` both draining the same mailbox — observed in prod: one message
  /// acked over BOTH transports within the same second) both read the SAME base
  /// state and the second `_persist` CLOBBERS the first's ratchet advance. The
  /// lost advance makes a neighbouring message permanently undecryptable — the
  /// exact "some messages in a burst silently never arrive" field bug. A send
  /// racing a receive corrupts the shared row the same way. Chaining every op
  /// for one peer device through a single async tail makes each read-advance-
  /// persist atomic without touching any crypto, key material, or wire format.
  final Map<String, Future<void>> _peerOpTail = <String, Future<void>>{};

  /// Run [op] after any in-flight op for [peerDeviceId] completes, and register
  /// it as the new tail so the next op waits for this one. Serializes per peer
  /// device only — different peers still run fully in parallel. An empty key
  /// (malformed wire we cannot attribute) runs unlocked, preserving today's
  /// behaviour for that rare path.
  Future<T> _withPeerLock<T>(
    String peerDeviceId,
    Future<T> Function() op,
  ) async {
    final key = peerDeviceId.trim();
    if (key.isEmpty) return op();
    final prev = _peerOpTail[key] ?? Future<void>.value();
    final gate = Completer<void>();
    _peerOpTail[key] = gate.future;
    try {
      await prev;
    } catch (_) {
      // A prior op's failure is surfaced to ITS own caller; we only need the
      // serialization barrier, so swallow it here and proceed.
    }
    try {
      return await op();
    } finally {
      gate.complete();
      // Drop the map entry only if nobody chained after us, so the map cannot
      // grow unbounded across many one-shot peers.
      if (identical(_peerOpTail[key], gate.future)) {
        _peerOpTail.remove(key);
      }
    }
  }

  Future<Uint8List> encryptToPeer({
    required String selfDeviceId,
    required String peerProfileId,
    required String peerDeviceId,
    required Uint8List plaintext,
    bool forceSpkOnly = false,
    // С-2: профиль этого устройства — по нему читается ключ личности для
    // подписи рукопожатия. Не передан — рукопожатие уходит без подписи, как
    // до С-2 (так и должно быть у старых вызывающих и в тестах без ключей).
    String? selfProfileId,
  }) async {
    // SLOW-DRAIN FIX R9 (2026-07-16): the X3DH bundle fetch is a NETWORK call
    // (authed keys-service round trip, up to the 10s HTTP timeout). It used to
    // run INSIDE the per-peer lock (initiator-create path below), so while a
    // first-send / post-reset handshake sat on a flaky network — repeated by
    // outbox re-kicks — every INBOUND decrypt from that same peer queued
    // behind it, tripped the drain's apply timeout and burned its retry
    // budget. Field case: app open, 63-envelope backlog trickled for ~48 min
    // (delivery-wake audit 2026-07-16, R9). Prefetch the bundle BEFORE taking
    // the lock; the locked body re-checks the session row and uses the
    // prefetched bundle only if it is still needed (a concurrent op may have
    // established the session meanwhile — the prefetch is then discarded).
    _PeerBundleV1? prefetchedBundle;
    if (await db.sessionV3Get(peerDeviceId) == null) {
      prefetchedBundle = await _fetchAndVerifyPeerBundle(
        peerProfileId: peerProfileId,
        peerDeviceId: peerDeviceId,
      );
    }
    // Serialize with any concurrent decrypt/encrypt for the SAME peer so the
    // read-modify-write on the session row stays atomic (see [_withPeerLock]).
    return _withPeerLock(
      peerDeviceId,
      () => _encryptToPeerLocked(
        selfDeviceId: selfDeviceId,
        peerProfileId: peerProfileId,
        peerDeviceId: peerDeviceId,
        plaintext: plaintext,
        forceSpkOnly: forceSpkOnly,
        prefetchedBundle: prefetchedBundle,
        selfProfileId: selfProfileId,
      ),
    );
  }

  /// Test-only window onto the per-peer serialization gate, so regressions of
  /// the "network fetch inside the peer lock" bug (R9) stay catchable without
  /// reaching into private state.
  @visibleForTesting
  Future<T> debugWithPeerLockForTest<T>(
    String peerDeviceId,
    Future<T> Function() op,
  ) => _withPeerLock(peerDeviceId, op);

  Future<Uint8List> _encryptToPeerLocked({
    required String selfDeviceId,
    required String peerProfileId,
    required String peerDeviceId,
    required Uint8List plaintext,
    bool forceSpkOnly = false,
    _PeerBundleV1? prefetchedBundle,
    String? selfProfileId,
  }) async {
    final existing = await db.sessionV3Get(peerDeviceId);
    // С-2: читается ДО транзакции ниже (связка ключей ОС, не база) и один раз
    // на отправку: им подписывается рукопожатие и по нему же ставится метка
    // `hsv` в обычном проводе — оба признака говорят одно и то же.
    final signingKey = await _handshakeSigningKey(selfProfileId, selfDeviceId);

    if (existing == null) {
      // Normally supplied by the pre-lock prefetch above. The in-lock fetch
      // remains only for the rare race where the session row existed at
      // prefetch time but was deleted (session reset) before the lock was
      // acquired.
      final bundle = prefetchedBundle ??
          await _fetchAndVerifyPeerBundle(
            peerProfileId: peerProfileId,
            peerDeviceId: peerDeviceId,
          );

      // SESSION-HEAL CONVERGENCE (2026-07-14, TZ §20 pillar 3): a session-reset
      // handshake MUST be SPK-only — never advertise a one-time prekey. The
      // responder that receives our reset prekey has to load the matching OTK
      // keypair to accept it (session_v1 responderAccept), but after a desync
      // that OTK is very often already consumed/rotated/lost → responderAccept
      // HARD-THROWS ("missing one-time prekey") → the peer can never adopt our
      // reset → the session is deadlocked forever (the "reset never converges"
      // wedge; live-observed as endless secretbox decrypt_fail with no heal).
      // Dropping DH2 (X3DH without the OTK) is a valid, slightly-weaker key
      // agreement that both sides can ALWAYS complete; the double ratchet
      // restores forward secrecy on the next message. Normal first-contact
      // sends keep using the OTK for full X3DH.
      final useOtk = !forceSpkOnly;
      final init = await handshake.initiatorCreate(
        selfDeviceId: selfDeviceId,
        peerDeviceId: peerDeviceId,
        recipientSignedPrekeyPubB64: bundle.signedPrekeyPubB64,
        recipientSignedPrekeyId: 1,
        recipientOneTimePrekeyPubB64:
            useOtk ? bundle.oneTimePrekeyPubB64 : null,
        recipientOneTimePrekeyId: useOtk ? bundle.oneTimePrekeyId : null,
      );

      var s = await dr.initInitiator(
        peerDeviceId: peerDeviceId,
        rootKey: init.session.rootKey,
        handshakeEphKeyPair: init.ephKeyPair,
        recipientSignedPrekeyPub: Uint8List.fromList(
          base64Decode(bundle.signedPrekeyPubB64),
        ),
      );

      // TZ Epic B: session epoch = creation wall-ms. Strictly increasing
      // across re-keys from the same device, so the receiver can order
      // sessions without any shared counter.
      final sessionEpochMs = DateTime.now().millisecondsSinceEpoch;

      // С-2 (24.09.2026): подпись рукопожатия ключом личности. Входит в
      // [handshakePart] — ту самую часть, что кешируется для повтора Ш-4, —
      // иначе повтор ушёл бы без подписи. Стоит сразу после полей X3DH и ДО
      // полей ратчета: байты заголовка — это AAD, а повтор собирает их из кеша
      // плюс перештампованные dh/pn/n/se в этом же порядке.
      String? handshakeSigB64;
      if (signingKey != null) {
        try {
          handshakeSigB64 = await HandshakeSignature.sign(
            identityKeyPair: signingKey,
            message: HandshakeSignature.message(
              senderDeviceId: selfDeviceId,
              recipientDeviceId: peerDeviceId,
              senderEphemeralPub:
                  base64Decode(init.header.senderEphemeralPubB64),
              recipientSignedPrekeyPub:
                  base64Decode(bundle.signedPrekeyPubB64),
              signedPrekeyId: init.header.recipientSignedPrekeyId,
              oneTimePrekeyId: init.header.recipientOneTimePrekeyId,
            ),
          );
        } catch (e) {
          // Без подписи — как до С-2. Получатель, который знает, что это
          // устройство подписывает, такое отвергнет; поэтому это событие.
          handshakeSigB64 = null;
          DiagLog.event('hs', 'sign_failed', <String, Object?>{
            'reason': e.runtimeType.toString(),
          });
        }
      }
      final handshakePart = <String, Object?>{
        ...init.header.toJson(),
        if (handshakeSigB64 != null)
          HandshakeSignature.headerField: handshakeSigB64,
      };
      final headerMap = <String, Object?>{
        ...handshakePart,
        'dh_pub_b64': base64Encode(s.dhSelfPub),
        'pn': s.pn,
        'n': s.ns,
        'se': sessionEpochMs,
      };
      final headerBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(headerMap)),
      );

      final enc = await dr.encrypt(
        state: s,
        plaintext: plaintext,
        aad: headerBytes,
      );
      s = enc.updated;
      // Э-4 Ш-3 + Р-6: the session state, the glare marker, the epoch and the
      // handshake now commit as ONE unit. They were four separate writes, so a
      // crash between them could leave a session whose handshake we advertise
      // but do not hold — or a cached header with no session behind it.
      await db.runInTransaction((txn) async {
        await _persist(s, txn: txn);
        // Mark this as a fresh, not-yet-confirmed initiator session so a
        // colliding inbound prekey within the glare window can be resolved
        // deterministically instead of blindly overwriting it (which is what
        // diverges peers).
        await db.sessionV3SetInitiatorPendingAt(
          peerDeviceId,
          DateTime.now().millisecondsSinceEpoch,
          txn: txn,
        );
        await db.sessionV3SetEpoch(peerDeviceId, sessionEpochMs, txn: txn);
        // Э-4 Ш-3: remember this handshake so Ш-4 can repeat it until the peer
        // confirms. WRITTEN ONLY — nothing reads it yet, by design: the
        // receiving half (Ш-2) has to reach the field before anyone starts
        // sending repeats. The other order is the 1.7.4+416 loss.
        //
        // 🔴 CACHED EXACTLY AS BUILT — the TZ's П-1 asked for an SPK-only cache
        // even when first contact used a one-time prekey, and that is
        // cryptographically impossible: `otk_id` in the header is what tells
        // the receiver whether to mix DH2 (session_v1.dart:304). An SPK-only
        // copy of an OTK-derived handshake would make the receiver derive a
        // DIFFERENT root and open nothing. The header must be the one that
        // actually produced this root.
        //
        // Consequence, deliberately accepted: a repeat of an OTK handshake
        // cannot be adopted by a peer that has ALSO lost its key material
        // (responderAccept hard-throws on the missing OTK). That case is not
        // made worse — it throws, gets quarantined, NACKs, and heals through
        // the existing SPK-only reset ping, exactly as it does today. The
        // alternative — making every first contact SPK-only — would quietly
        // weaken the forward secrecy of every new conversation to buy a rarer
        // case, which is a far worse trade.
        await db.sessionV3SetHandshake(
          peerDeviceId,
          baseKeyB64: init.header.senderEphemeralPubB64.trim(),
          pendingPrekeyHeaderJson: jsonEncode(handshakePart),
          txn: txn,
        );
      });

      await _pruneSkipped();
      return RatchetWireV3.encodePrekey(
        header: headerMap,
        ratchetCiphertext: enc.ciphertext,
      );
    }

    var s = _stateFromRow(peerDeviceId, existing);
    // Perform the DH ratchet-send step NOW (if this session has no sending
    // chain yet — e.g. a responder's first reply) so the header below carries
    // the FINAL dh_pub/pn/n. Without this, encrypt() ratchets internally and we
    // would advertise a stale dh_pub, making the message undecryptable for the
    // peer (a one-direction break after each session establishment).
    s = await dr.ensureSendChain(s);
    // TZ Epic B: advertise the epoch of the session this wire rides on. 0 /
    // absent for legacy rows (pre-migration) — receivers then skip the gate.
    final rowEpoch = (existing['epoch'] as num?)?.toInt() ?? 0;

    // ─── Э-4 Ш-4: repeat the handshake until the peer has confirmed ──────────
    //
    // The Signal rule. Today a handshake rides along only when WE have no
    // session; from the second message on we send a bare ratchet wire. So a
    // peer that lost ITS session — a wiped database, a restore, a corrupted
    // SQLCipher file — can open nothing we send, and recovery needs a full
    // round trip (park, NACK, reset ping, re-handshake). Repeating the
    // handshake until they confirm makes every message self-sufficient: such a
    // peer heals FROM the message, with no round trip at all. Measured live on
    // 2026-08-02: a heal with the cure already in the mailbox took 143 ms, the
    // same heal needing the round trip took 50 seconds.
    //
    // "Confirmed" is `initiator_pending_at_ms == 0`, which is cleared in exactly
    // one place — when the peer sends under our session (the only real proof
    // they adopted it). Every session that exists today reads 0, so this branch
    // simply never fires for them (Р-10).
    final pendingAtMs =
        (existing['initiator_pending_at_ms'] as num?)?.toInt() ?? 0;
    final cachedHandshakeJson =
        (existing['pending_prekey_header_json'] as String?)?.trim() ?? '';
    // Ш-5 (Р-7): a peer that never confirms must not be handed a handshake
    // forever. Past the cap we fall back to the ordinary wire — and say so,
    // because a silent cut-off reads exactly like "everything is covered".
    final repeatAgeMs = DateTime.now().millisecondsSinceEpoch - pendingAtMs;
    final repeatExpired =
        pendingAtMs > 0 && repeatAgeMs > kPrekeyRepeatMaxAgeMs;
    if (repeatExpired && cachedHandshakeJson.isNotEmpty) {
      DiagLog.event('send', 'prekey_repeat_capped', {
        'dev': DiagLog.pfx(peerDeviceId),
        'age_ms': repeatAgeMs,
      });
    }
    if (kPrekeyUntilConfirmedSend &&
        pendingAtMs > 0 &&
        !repeatExpired &&
        cachedHandshakeJson.isNotEmpty) {
      Map<String, Object?>? cachedHandshake;
      try {
        final parsed = jsonDecode(cachedHandshakeJson);
        if (parsed is Map<String, dynamic>) {
          cachedHandshake = Map<String, Object?>.from(parsed);
        }
      } catch (_) {
        // Unreadable cache: fall through to the ordinary wire. A malformed
        // header would be far worse than a missing repeat — the peer would
        // fail to derive and reject the message outright.
        cachedHandshake = null;
      }
      if (cachedHandshake != null && cachedHandshake.isNotEmpty) {
        // 🔴 ONLY the X3DH part is reused. The prekey header in this codebase
        // is a MERGED map — handshake fields plus the ratchet's own
        // dh_pub/pn/n — and every byte of it is the AEAD's AAD. The receiver
        // reads pn/n from this same header, so a verbatim repeat would claim
        // n=0 on the fifth message and fail the MAC on every one of them. The
        // ratchet fields are therefore re-stamped fresh each time; the key
        // ORDER is preserved because it decides the AAD bytes.
        final repeatHeader = <String, Object?>{
          ...cachedHandshake,
          'dh_pub_b64': base64Encode(s.dhSelfPub),
          'pn': s.pn,
          'n': s.ns,
          if (rowEpoch > 0) 'se': rowEpoch,
        };
        final repeatHeaderBytes = Uint8List.fromList(
          utf8.encode(jsonEncode(repeatHeader)),
        );
        final repeatEnc = await dr.encrypt(
          state: s,
          plaintext: plaintext,
          aad: repeatHeaderBytes,
        );
        s = repeatEnc.updated;
        await _persist(s);
        // The pending marker is NOT re-armed here (П-4). It records when we
        // first initiated; refreshing it on every repeat would extend the glare
        // window indefinitely and the tie-break would never settle.
        await _pruneSkipped();
        return RatchetWireV3.encodePrekey(
          header: repeatHeader,
          ratchetCiphertext: repeatEnc.ciphertext,
        );
      }
    }

    // С-2: метка «подписываю рукопожатия» — только если ключ личности на
    // самом деле прочитан. Устройство, которое не может подписать, не должно
    // её ставить: получатель по ней начинает отвергать неподписанное.
    final hsv = signingKey != null ? HandshakeSignature.capabilityVersion : null;
    final headerMap = <String, Object?>{
      'sender_device_id': selfDeviceId,
      'dh_pub_b64': base64Encode(s.dhSelfPub),
      'pn': s.pn,
      'n': s.ns,
      if (rowEpoch > 0) 'se': rowEpoch,
      if (hsv != null) HandshakeSignature.capabilityField: hsv,
    };
    final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(headerMap)));

    final enc = await dr.encrypt(
      state: s,
      plaintext: plaintext,
      aad: headerBytes,
    );
    s = enc.updated;
    await _persist(s);

    await _pruneSkipped();
    return RatchetWireV3.encodeSession(
      senderDeviceId: selfDeviceId,
      dhPubB64: headerMap['dh_pub_b64'] as String,
      pn: headerMap['pn'] as int,
      n: headerMap['n'] as int,
      ratchetCiphertext: enc.ciphertext,
      se: rowEpoch > 0 ? rowEpoch : null,
      hsv: hsv,
    );
  }

  /// [onPlaintextBeforeCommit], when provided, is awaited with the freshly
  /// decrypted plaintext (and the sender device id) INSIDE the per-peer lock,
  /// immediately BEFORE the advanced Double Ratchet state is persisted. This is
  /// the zero-loss hook: the caller durably journals the plaintext so that if
  /// the process dies in the post-decrypt gap, the message key that was just
  /// consumed is not lost with it — the journaled plaintext is recoverable even
  /// though the ciphertext becomes permanently undecryptable on redelivery. If
  /// the hook throws, the ratchet is NOT advanced (we rethrow before persist),
  /// so the same wire simply re-decrypts cleanly on the next delivery.
  Future<Uint8List> decryptFromWire({
    required String selfProfileId,
    required String selfDeviceId,
    required Uint8List wireBytes,
    Future<void> Function(
      Uint8List plaintext,
      String? senderDeviceId,
      DatabaseExecutor txn,
    )?
    onPlaintextBeforeCommit,
  }) {
    // Attribute this wire to a peer device up front (cheap header parse) so we
    // can serialize per peer. The locked body re-decodes; tryDecode is a pure
    // parse, so the double call is free and keeps the body byte-identical.
    String lockKey = '';
    try {
      final decoded = RatchetWireV3.tryDecode(wireBytes);
      if (decoded != null) {
        lockKey = decoded.kind == RatchetWireKindV3.prekey
            ? PrekeyHeaderV1.fromJson(decoded.header).senderDeviceId
            : ((decoded.header['sender_device_id'] as String?) ?? '');
      }
    } catch (_) {
      lockKey = '';
    }
    return _withPeerLock(
      lockKey,
      () => _decryptFromWireWithHandshakeAuth(
        selfProfileId: selfProfileId,
        selfDeviceId: selfDeviceId,
        wireBytes: wireBytes,
        onPlaintextBeforeCommit: onPlaintextBeforeCommit,
      ),
    );
  }

  /// С-2 (24.09.2026): обёртка вокруг [_decryptFromWireLocked].
  ///
  /// Всё, что касается базы, — ДО и ПОСЛЕ транзакции расшифровки, никогда
  /// внутри: вспомогательные методы идут через живой дескриптор и внутри
  /// открытой транзакции встали бы в взаимоблокировку. Внутри транзакции —
  /// только одно решение по готовому итогу ([_HandshakeAuthVerdict.reject]).
  Future<Uint8List> _decryptFromWireWithHandshakeAuth({
    required String selfProfileId,
    required String selfDeviceId,
    required Uint8List wireBytes,
    Future<void> Function(
      Uint8List plaintext,
      String? senderDeviceId,
      DatabaseExecutor txn,
    )?
    onPlaintextBeforeCommit,
  }) async {
    final decoded = RatchetWireV3.tryDecode(wireBytes);
    _HandshakeAuthVerdict? verdict;
    if (decoded != null && decoded.kind == RatchetWireKindV3.prekey) {
      verdict = await _evaluateHandshakeAuth(header: decoded.header);
    }
    try {
      final plain = await _decryptFromWireLocked(
        selfProfileId: selfProfileId,
        selfDeviceId: selfDeviceId,
        wireBytes: wireBytes,
        onPlaintextBeforeCommit: onPlaintextBeforeCommit,
        handshakeAuth: verdict,
      );
      await _rememberHandshakeSigner(decoded, verdict);
      return plain;
    } finally {
      if (verdict != null && verdict.reachedFirstSight) {
        DiagLog.event('hs', 'auth', <String, Object?>{
          'peer': DiagLog.pfx(verdict.senderDeviceId),
          'outcome': verdict.outcome,
          'rejected': verdict.reject,
        });
        await db.localKvCounterInc('hs_auth.${verdict.outcome}');
        if (verdict.reject) await db.localKvCounterInc('hs_auth.rejected');
      }
    }
  }

  /// Факты для проверки подписи рукопожатия — ДО транзакции расшифровки.
  ///
  /// Отказ будет только если устройство уже доказало, что подписывает (признак
  /// привязан к закреплённому ключу), а это рукопожатие без подписи или с
  /// подписью, которая не сходится. Всё остальное принимается, как до С-2, и
  /// только считается: незнакомое устройство, старая сборка, расхождение
  /// ключей. Любая ошибка здесь — `null`, то есть никакой проверки: сбой в
  /// нашем коде не должен стоить доставки.
  Future<_HandshakeAuthVerdict?> _evaluateHandshakeAuth({
    required Map<String, dynamic> header,
  }) async {
    try {
      final pre = PrekeyHeaderV1.fromJson(header);
      final sender = pre.senderDeviceId.trim();
      if (sender.isEmpty) return null;
      final sigRaw = header[HandshakeSignature.headerField];
      final sig = sigRaw is String && sigRaw.trim().isNotEmpty
          ? sigRaw.trim()
          : null;
      final pinned = await db.contactDeviceIdentityKeys(sender);
      final capable = (await db.handshakeSigCapableKey(sender))?.trim() ?? '';
      final String? key = capable.isNotEmpty && pinned.contains(capable)
          ? capable
          : (pinned.length == 1 ? pinned.single : null);
      final proven = capable.isNotEmpty && key != null && capable == key;
      // Выключатель с сервера (подписанный блок `handshake_auth`) читается
      // только для доказанных устройств — отказ возможен лишь у них — и здесь,
      // а не в памяти приложения, чтобы действовать и в фоновом изоляте.
      final switchOff = proven &&
          (await db.localKvGet(AppDb.kvHandshakeAuthEnforceDisabled)) == '1';
      return _HandshakeAuthVerdict(
        senderDeviceId: sender,
        signatureB64: sig,
        pinnedCount: pinned.length,
        key: key,
        proven: proven,
        switchOff: switchOff,
      );
    } catch (_) {
      return null;
    }
  }

  /// Когда устройство проверено последний раз на метку `hsv`: запись признака —
  /// обращение к базе, и делать его на каждое сообщение незачем.
  final Map<String, int> _hsvCheckedAtMs = <String, int>{};
  static const int _hsvRecheckMs = 10 * 60 * 1000;

  /// После УДАЧНОЙ расшифровки: запомнить, что устройство подписывает.
  ///
  /// Два доказательства:
  ///  * рукопожатие с верной подписью закреплённым ключом;
  ///  * обычное сообщение с меткой `hsv` — метка внутри AAD, её не подделать
  ///    и не снять, не сломав сообщение.
  /// Признак привязывается к закреплённому ключу. Без единственного
  /// закреплённого ключа ничего не пишется. Ошибки глотаются: это учёт, а не
  /// доставка.
  Future<void> _rememberHandshakeSigner(
    RatchetWireDecodedV3? decoded,
    _HandshakeAuthVerdict? verdict,
  ) async {
    try {
      if (verdict != null &&
          verdict.reachedFirstSight &&
          verdict.provenKey != null) {
        await db.handshakeSigCapableSet(
          verdict.senderDeviceId,
          verdict.provenKey!,
        );
        return;
      }
      if (decoded == null || decoded.kind != RatchetWireKindV3.session) return;
      final hsv = decoded.header[HandshakeSignature.capabilityField];
      if (hsv is! num || hsv.toInt() < HandshakeSignature.capabilityVersion) {
        return;
      }
      final sender =
          ((decoded.header['sender_device_id'] as String?) ?? '').trim();
      if (sender.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = _hsvCheckedAtMs[sender];
      if (last != null && now - last < _hsvRecheckMs) return;
      _hsvCheckedAtMs[sender] = now;
      final pinned = await db.contactDeviceIdentityKeys(sender);
      if (pinned.length != 1) return;
      final current = (await db.handshakeSigCapableKey(sender))?.trim() ?? '';
      if (current == pinned.single) return;
      await db.handshakeSigCapableSet(sender, pinned.single);
      DiagLog.event('hs', 'signer_marked', <String, Object?>{
        'peer': DiagLog.pfx(sender),
      });
    } catch (_) {
      // учёт не имеет права стоить доставки
    }
  }

  Future<Uint8List> _decryptFromWireLocked({
    required String selfProfileId,
    required String selfDeviceId,
    required Uint8List wireBytes,
    Future<void> Function(
      Uint8List plaintext,
      String? senderDeviceId,
      DatabaseExecutor txn,
    )?
    onPlaintextBeforeCommit,
    _HandshakeAuthVerdict? handshakeAuth,
  }) async {
    final decoded = RatchetWireV3.tryDecode(wireBytes);
    if (decoded == null) {
      throw StateError('not a v1.3 ratchet wire message');
    }

    // И-2 (TZ_I2_ATOMICITY_2026-07-21): the WHOLE apply of one wire — the
    // skipped-key mutations dr.decrypt performs mid-stream (before its AEAD
    // verify), the ratchet advance, the archive bookkeeping and the journaled
    // plaintext — commits or rolls back as ONE unit. A crash anywhere leaves
    // sessions_v3 unadvanced, so the relay's redelivery re-decrypts cleanly;
    // a FAILED decrypt now also rolls back its orphan skipped keys (they used
    // to leak, and a corrupted wire could burn a legit stored key). Every db
    // call in here MUST go through [txn] — a stray call on the live handle
    // would deadlock behind the open transaction. Crypto CPU and (on the
    // prekey path) keychain reads run inside the transaction by design:
    // milliseconds, and correctness beats overlap here.
    return db.runInTransaction<Uint8List>((txn) async {
    // Durably capture the plaintext BEFORE the ratchet advance is persisted.
    // Called on every success path immediately before `_persist`/`_persistArchive`.
    Future<void> journalBeforeCommit(
      Uint8List plaintext,
      String? senderDeviceId,
    ) async {
      if (onPlaintextBeforeCommit != null) {
        await onPlaintextBeforeCommit(plaintext, senderDeviceId, txn);
      }
    }

    // Per-wire skipped-key callbacks bound to THIS transaction (the instance
    // methods they replace wrote straight to the live handle and escaped the
    // rollback).
    Future<void> storeSkippedTxn({
      required String peerDeviceId,
      required String dhPubB64,
      required int msgNum,
      required Uint8List messageKey,
    }) => db.skippedKeyUpsert(
      peerDeviceId: peerDeviceId,
      dhPubB64: dhPubB64,
      msgNum: msgNum,
      mkB64: base64Encode(messageKey),
      txn: txn,
    );
    Future<Uint8List?> loadSkippedTxn({
      required String peerDeviceId,
      required String dhPubB64,
      required int msgNum,
    }) async {
      final row = await db.skippedKeyGet(
        peerDeviceId: peerDeviceId,
        dhPubB64: dhPubB64,
        msgNum: msgNum,
        txn: txn,
      );
      if (row == null) return null;
      final mkB64 = row['mk_b64'] as String?;
      if (mkB64 == null || mkB64.isEmpty) return null;
      return Uint8List.fromList(base64Decode(mkB64));
    }
    Future<void> deleteSkippedTxn({
      required String peerDeviceId,
      required String dhPubB64,
      required int msgNum,
    }) => db.skippedKeyDelete(
      peerDeviceId: peerDeviceId,
      dhPubB64: dhPubB64,
      msgNum: msgNum,
      txn: txn,
    );
    /// Runs one decrypt against the now-PURE ratchet, doing the database work
    /// on this side of the call.
    ///
    /// The ratchet used to reach into the database itself through callbacks.
    /// It no longer can (and must not: that is what pinned the maths to the UI
    /// isolate). So the order here is deliberate and load-bearing:
    ///
    ///   1. read the ONE skipped key that could apply;
    ///   2. compute — pure, no I/O, safe to move off this isolate later;
    ///   3. apply what came back, INSIDE this same transaction.
    ///
    /// Step 3 all-or-nothing is a small improvement on the old behaviour: keys
    /// used to be written one by one as the loop ran, so a failure part-way
    /// left a partial set behind.
    Future<DoubleRatchetDecryptResultV3> decryptWithSkippedTxn({
      required DoubleRatchetStateV3 state,
      required String headerDhPubB64,
      required int pn,
      required int n,
      required List<int> ciphertext,
      required List<int> aad,
    }) async {
      final preloaded = await loadSkippedTxn(
        peerDeviceId: state.peerDeviceId,
        dhPubB64: headerDhPubB64,
        msgNum: n,
      );
      // Step Б: the maths runs on a worker isolate when one is available, and
      // in place otherwise — same inputs, same result either way. The caller
      // keeps every byte of state and every database write, so the transaction
      // this sits inside is unaffected.
      //
      // We are INSIDE an open transaction here (Н-5). That is why the worker
      // must never touch the database: a query from there would wait on a lock
      // this isolate holds, and neither would ever finish.
      final dec = await DecryptWorker.instance.decrypt(
        ratchet: dr,
        state: state,
        headerDhPubB64: headerDhPubB64,
        pn: pn,
        n: n,
        ciphertext: ciphertext,
        preloadedSkippedKey: preloaded,
        aad: aad,
      );
      if (dec.consumedPreloadedKey) {
        // Single-use: leaving it would let the same ciphertext open twice.
        await deleteSkippedTxn(
          peerDeviceId: state.peerDeviceId,
          dhPubB64: headerDhPubB64,
          msgNum: n,
        );
      }
      for (final rec in dec.skippedToStore) {
        await storeSkippedTxn(
          peerDeviceId: state.peerDeviceId,
          dhPubB64: rec.dhPubB64,
          msgNum: rec.msgNum,
          messageKey: rec.messageKey,
        );
      }
      return dec;
    }


    switch (decoded.kind) {
      case RatchetWireKindV3.prekey:
        final header = decoded.header;
        final pre = PrekeyHeaderV1.fromJson(header);

        // ─── Э-4 Ш-2 / П-2: is this a REPEAT of a handshake we already hold? ──
        //
        // 🔴 THE DEFECT THIS EXISTS FOR (Д-1, reproduced against this very
        // code). The branch below unconditionally re-runs responderAccept →
        // initResponder → _persist. `initResponder` returns a state with
        // `sendChainKey: null`, `ns: 0` and the root rolled back to the
        // handshake value — so a repeated prekey ERASES the receiver's own
        // ratchet progress. Measured: after the receiver had replied once, a
        // repeat rolled its root back, its next reply rode a root the sender
        // had already advanced past, and the sender could never open it again.
        // The reverse direction dies permanently, silently. Same class as
        // 1.7.4+416.
        //
        // The identity to match on is the handshake BASE KEY (the initiator's
        // ephemeral public key). The root key cannot serve: it is rewritten on
        // every DH step, so it is a moving target, not an identity (Д-3).
        //
        // Matching a repeat, we decrypt against the session we ALREADY have,
        // exactly as if this were a session wire — the prekey header bytes are
        // still the AAD, because that is what the sender signed the ciphertext
        // against. No X3DH, no keychain read, no one-time prekey, no archive
        // push, no glare tie-break. Those are all first-sight-only work.
        final wireBaseKey = pre.senderEphemeralPubB64.trim();
        if (wireBaseKey.isNotEmpty) {
          final liveRow = await db.sessionV3Get(pre.senderDeviceId, txn: txn);
          final liveBase =
              (liveRow?['handshake_base_pub_b64'] as String?)?.trim() ?? '';
          if (liveRow != null && liveBase.isNotEmpty && liveBase == wireBaseKey) {
            var s = _stateFromRow(pre.senderDeviceId, liveRow);
            final dec = await decryptWithSkippedTxn(
              state: s,
              headerDhPubB64:
                  (header['dh_pub_b64'] as String?) ?? pre.senderEphemeralPubB64,
              pn: (header['pn'] as num?)?.toInt() ?? 0,
              n: (header['n'] as num?)?.toInt() ?? 0,
              ciphertext: decoded.ciphertext,
              aad: decoded.headerBytes,
            );
            s = dec.updated;
            await journalBeforeCommit(dec.plaintext, pre.senderDeviceId);
            await _persist(s, txn: txn);
            // The peer is still sending under this handshake, which means it
            // has NOT yet seen our confirmation — so the pending marker stays
            // exactly as it is. Clearing it here would be a lie about the
            // peer's state; it is cleared only by a SESSION wire (line ~645),
            // which is the actual proof that they adopted us.
            await _pruneSkipped(txn: txn);
            return dec.plaintext;
          }

          // Р-4: the repeat may belong to an OLDER handshake that a newer one
          // has already replaced. Its session is in the archive. Decrypting
          // there keeps the straggler readable AND — the point — stops it from
          // falling through to X3DH below, where it would overwrite the NEWER
          // live session with a stale one.
          final archivedRows = await db.sessionV3ArchiveList(
            pre.senderDeviceId,
            txn: txn,
          );
          for (final arow in archivedRows) {
            final aBase =
                (arow['handshake_base_pub_b64'] as String?)?.trim() ?? '';
            if (aBase.isEmpty || aBase != wireBaseKey) continue;
            final aid = (arow['id'] as num?)?.toInt();
            if (aid == null) continue;
            try {
              var s = _stateFromRow(pre.senderDeviceId, arow);
              final dec = await decryptWithSkippedTxn(
                state: s,
                headerDhPubB64: (header['dh_pub_b64'] as String?) ??
                    pre.senderEphemeralPubB64,
                pn: (header['pn'] as num?)?.toInt() ?? 0,
                n: (header['n'] as num?)?.toInt() ?? 0,
                ciphertext: decoded.ciphertext,
                aad: decoded.headerBytes,
              );
              s = dec.updated;
              await journalBeforeCommit(dec.plaintext, pre.senderDeviceId);
              await _persistArchive(aid, s, txn: txn);
              await _pruneSkipped(txn: txn);
              return dec.plaintext;
            } catch (_) {
              // Not this one — keep looking, then fall through to first-sight.
            }
          }
        }
        // ─── First sight of this handshake: today's path, unchanged ──────────

        final spk = await deviceKeys.loadSignedPrekeyKeyPair(
          profileId: selfProfileId,
          deviceId: selfDeviceId,
        );

        // С-2 (24.09.2026): здесь и только здесь решается подлинность
        // начинающего. Повтор живой сессии и архивный повтор выше уже вернулись:
        // их рукопожатие было принято раньше. Проверка — на уже загруженном
        // SPK, без обращений к базе. Отказ — до X3DH и до любой записи;
        // транзакция откатывается, живая сессия не тронута.
        if (handshakeAuth != null) {
          await handshakeAuth.decide(
            pre: pre,
            selfDeviceId: selfDeviceId,
            selfSignedPrekeyPub: (await spk.extractPublicKey()).bytes,
          );
          if (handshakeAuth.reject) {
            throw HandshakeAuthRejectedException(
              senderDeviceId: handshakeAuth.senderDeviceId,
              outcome: handshakeAuth.outcome,
            );
          }
        }
        SimpleKeyPair? otk;
        if (pre.recipientOneTimePrekeyId != null) {
          otk = await deviceKeys.loadOneTimePrekeyKeyPair(
            profileId: selfProfileId,
            deviceId: selfDeviceId,
            prekeyId: pre.recipientOneTimePrekeyId!,
          );
        }

        // Derive the shared root key (X3DH-like). We ignore v1.2 chain keys.
        final v12 = await handshake.responderAccept(
          selfDeviceId: selfDeviceId,
          peerDeviceId: pre.senderDeviceId,
          header: pre,
          recipientSignedPrekeyKeyPair: spk,
          recipientOneTimePrekeyKeyPair: otk,
        );

        // The SKS2 prekey header carries both:
        // - sender_eph_pub_b64 (handshake ephemeral, used above for X3DH)
        // - dh_pub_b64 (Double Ratchet DHs public key)
        // In our current v1.3 design they are expected to match, but prefer dh_pub_b64
        // to be resilient to future changes.
        final initiatorDhPubB64 =
            (header['dh_pub_b64'] as String?) ?? pre.senderEphemeralPubB64;

        var s = await dr.initResponder(
          peerDeviceId: pre.senderDeviceId,
          rootKey: v12.rootKey,
          recipientSignedPrekeyKeyPair: spk,
          initiatorDhPub: Uint8List.fromList(base64Decode(initiatorDhPubB64)),
        );

        final dhPubB64 =
            (header['dh_pub_b64'] as String?) ?? pre.senderEphemeralPubB64;
        final pn = (header['pn'] as num?)?.toInt() ?? 0;
        final n = (header['n'] as num?)?.toInt() ?? 0;

        final dec = await decryptWithSkippedTxn(
          state: s,
          headerDhPubB64: dhPubB64,
          pn: pn,
          n: n,
          ciphertext: decoded.ciphertext,
          aad: decoded.headerBytes,
        );
        s = dec.updated;

        // Glare tie-break: if we ALSO just initiated our own session toward
        // this peer (both sides re-established at once), both peers must
        // converge on ONE session deterministically — otherwise each adopts
        // the other's and they diverge permanently. The session id is the
        // shared root key (identical on initiator and responder), so both
        // peers compute the same comparison and pick the SAME winner.
        //
        // We only tie-break inside a short glare window after our own
        // initiation; an established (or stale) local session always yields to
        // the peer's fresh prekey (a legitimate one-sided re-key).
        final candidateRootB64 = base64Encode(s.rootKey);
        var adoptCandidate = true;
        final existing = await db.sessionV3Get(pre.senderDeviceId, txn: txn);
        if (existing != null) {
          final pendingAtMs =
              (existing['initiator_pending_at_ms'] as num?)?.toInt() ?? 0;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final inGlareWindow =
              pendingAtMs > 0 && (nowMs - pendingAtMs) < kGlareWindowMs;
          if (inGlareWindow) {
            final existingRootB64 = (existing['root_key_b64'] as String?) ?? '';
            // Keep the session with the smaller id; adopt the candidate only if
            // it wins (or is the same session being re-keyed).
            adoptCandidate = candidateRootB64.compareTo(existingRootB64) <= 0;
          }
        }

        // Zero-loss: journal the plaintext before we durably advance/replace the
        // ratchet (either branch below persists state derived from the consumed
        // message key). See [onPlaintextBeforeCommit].
        await journalBeforeCommit(dec.plaintext, pre.senderDeviceId);
        if (adoptCandidate) {
          // Preserve the session this prekey is about to overwrite so any
          // straggler still encrypted under it stays decryptable via the
          // candidate-session fallback below.
          await archiveCurrentSession(
            pre.senderDeviceId,
            replacementRootKeyB64: candidateRootB64,
            txn: txn,
          );
          await _persist(s, txn: txn);
          // Э-4 Ш-2: remember WHICH handshake produced this session, so a
          // repeat of it is recognised next time instead of re-initialising
          // the session and destroying our own send chain (Д-1). Written in
          // this same transaction as the state it describes (Р-6): a base key
          // without its session, or a session without its base key, is a
          // half-truth the repeat check would act on.
          //
          // Э-4 Ш-3: and DROP our own cached header in the same breath. Adopting
          // the peer's handshake REPLACED the initiator session we had toward
          // them, so a header cached for that session now advertises something
          // that no longer exists — Ш-4 would repeat a dead handshake forever.
          await db.sessionV3SetHandshake(
            pre.senderDeviceId,
            baseKeyB64: pre.senderEphemeralPubB64.trim(),
            clearPendingHeader: true,
            txn: txn,
          );
          // We are now the responder on this (shared) session — established.
          await db.sessionV3SetInitiatorPendingAt(
            pre.senderDeviceId,
            0,
            txn: txn,
          );
          // TZ Epic B: adopt the initiator's session epoch so both sides
          // advertise the SAME 'se' for this shared session.
          final adoptedSe = (header['se'] as num?)?.toInt() ?? 0;
          if (adoptedSe > 0) {
            await db.sessionV3SetEpoch(pre.senderDeviceId, adoptedSe, txn: txn);
          }
        } else {
          // Glare and WE win: keep our initiator session as primary, but
          // archive the peer's candidate so stragglers under it still decrypt.
          await _archiveSessionState(
            s,
            handshakeBasePubB64: pre.senderEphemeralPubB64.trim(),
            txn: txn,
          );
        }
        await _pruneSkipped(txn: txn);
        return dec.plaintext;

      case RatchetWireKindV3.session:
        final header = decoded.header;
        final senderDeviceId = header['sender_device_id'] as String?;
        final dhPubB64 = header['dh_pub_b64'] as String?;
        final pn = (header['pn'] as num?)?.toInt();
        final n = (header['n'] as num?)?.toInt();
        if (senderDeviceId == null || senderDeviceId.isEmpty) {
          throw StateError('missing sender_device_id');
        }
        if (dhPubB64 == null || dhPubB64.isEmpty) {
          throw StateError('missing dh_pub_b64');
        }
        if (pn == null || n == null) {
          throw StateError('missing pn/n');
        }

        // 1) Primary (live) session — unchanged happy path.
        final row = await db.sessionV3Get(senderDeviceId, txn: txn);
        Object? primaryError;
        if (row != null) {
          try {
            var s = _stateFromRow(senderDeviceId, row);
            final dec = await decryptWithSkippedTxn(
              state: s,
              headerDhPubB64: dhPubB64,
              pn: pn,
              n: n,
              ciphertext: decoded.ciphertext,
              aad: decoded.headerBytes,
            );
            s = dec.updated;
            await journalBeforeCommit(dec.plaintext, senderDeviceId);
            await _persist(s, txn: txn);
            // The peer just sent under our primary session — it is confirmed
            // established, so clear any pending-initiator glare marker.
            await db.sessionV3SetInitiatorPendingAt(senderDeviceId, 0, txn: txn);
            // Э-4 Ш-3: CONFIRMED means we stop repeating the handshake, so the
            // cached header dies here — in the same transaction, next to the
            // marker it belongs to. A header that outlives its confirmation
            // would be attached to every future message forever.
            await db.sessionV3SetHandshake(
              senderDeviceId,
              clearPendingHeader: true,
              txn: txn,
            );
            await _pruneSkipped(txn: txn);
            return dec.plaintext;
          } catch (e) {
            // Fall through to candidate (archived) sessions below.
            primaryError = e;
          }
        }

        // 2) Candidate (archived) sessions — strictly a recovery fallback for a
        //    session that an inbound prekey overwrote (or a reset deleted).
        //    This NEVER runs on the happy path above; if it is buggy the worst
        //    case is the same as before (the message stays undecryptable).
        final archived = await db.sessionV3ArchiveList(
          senderDeviceId,
          // И-4d: use the raised default (8) so the straggler fallback tries as
          // many prior sessions as we now retain (was hard-capped at 3).
          txn: txn,
        );
        for (final arow in archived) {
          final aid = (arow['id'] as num?)?.toInt();
          if (aid == null) continue;
          try {
            var s = _stateFromRow(senderDeviceId, arow);
            final dec = await decryptWithSkippedTxn(
              state: s,
              headerDhPubB64: dhPubB64,
              pn: pn,
              n: n,
              ciphertext: decoded.ciphertext,
              aad: decoded.headerBytes,
            );
            s = dec.updated;
            await journalBeforeCommit(dec.plaintext, senderDeviceId);
            await _persistArchive(aid, s, txn: txn);
            await _pruneSkipped(txn: txn);
            return dec.plaintext;
          } catch (_) {
            // try the next candidate session
          }
        }

        // 3) Nothing decrypted. TZ Epic B: if the wire advertises a session
        //    epoch NEWER than everything we hold for this peer, the rekey is
        //    still en route — classify it so the caller parks the wire as
        //    transient WITHOUT a NACK (the prekey in the same mailbox is the
        //    cure). Checked ONLY here — every successful decrypt path above
        //    (primary + archived candidates) ran first, byte-for-byte as
        //    before, so glare stragglers keep their archive fallback.
        final wireEpoch = (header['se'] as num?)?.toInt() ?? 0;
        if (wireEpoch > 0) {
          final localEpoch = row == null
              ? 0
              : ((row['epoch'] as num?)?.toInt() ?? 0);
          if (wireEpoch > localEpoch) {
            throw EpochAheadException(
              senderDeviceId: senderDeviceId,
              wireEpoch: wireEpoch,
              localEpoch: localEpoch,
            );
          }
        }
        //    Preserve the original error semantics so the caller's quarantine /
        //    reset behaviour is unchanged.
        if (row == null && archived.isEmpty) {
          throw StateError(
            'no v1.3 session for sender_device_id=$senderDeviceId',
          );
        }
        throw primaryError ??
            StateError(
              'session decrypt failed for sender_device_id=$senderDeviceId',
            );
    }
    });
  }

  /// И-3 (TZ_I3_SINGLE_WRITER_2026-07-21): reset a peer's session UNDER the
  /// per-peer lock, so it serializes against any concurrent decrypt/encrypt for
  /// the same peer. The controller used to call `db.sessionV3Delete` directly
  /// (outside this lock) from the decrypt-failure handler and the forced-prekey
  /// path — a same-peer inbound decrypt draining on another transport could
  /// then interleave with the delete, wiping a just-advanced session and
  /// forcing a spurious reset. Routing archive+delete through `_withPeerLock`
  /// makes that race unrepresentable (the invariant), not merely unlikely.
  ///
  /// [archiveFirst] preserves the about-to-be-deleted session in the candidate
  /// archive so stragglers encrypted under it stay decryptable via the fallback
  /// path after the re-handshake. Best-effort: never throws into the caller.
  Future<void> resetSessionForPeer(
    String peerDeviceId, {
    bool archiveFirst = true,
  }) async {
    final key = peerDeviceId.trim();
    if (key.isEmpty) return;
    await _withPeerLock(key, () async {
      if (archiveFirst) {
        await archiveCurrentSession(key);
      }
      try {
        // И-4c: when we archived first, KEEP the skipped keys so a straggler
        // under the archived old chain still decrypts from the fallback; only a
        // non-archiving delete keeps the legacy wipe.
        await db.sessionV3Delete(key, pruneSkippedKeys: !archiveFirst);
      } catch (_) {
        // ignore — session may not exist; reset is best-effort
      }
    });
  }

  /// Copy the current live session for [peerDeviceId] into the candidate
  /// archive so inbound stragglers encrypted under it remain decryptable after
  /// it is overwritten (by an incoming prekey) or deleted (by a reset). No-op
  /// when there is no live session, or when it is the same session that is
  /// about to replace it ([replacementRootKeyB64] matches). Best-effort:
  /// archiving must never break the primary flow.
  Future<void> archiveCurrentSession(
    String peerDeviceId, {
    String? replacementRootKeyB64,
    DatabaseExecutor? txn,
  }) async {
    try {
      final row = await db.sessionV3Get(peerDeviceId, txn: txn);
      if (row == null) return;
      final oldRoot = row['root_key_b64'] as String?;
      if (oldRoot == null || oldRoot.isEmpty) return;
      if (replacementRootKeyB64 != null && oldRoot == replacementRootKeyB64) {
        return;
      }
      await db.sessionV3ArchivePush(
        peerDeviceId: peerDeviceId,
        rootKeyB64: oldRoot,
        dhSelfSeedB64: row['dh_self_seed_b64'] as String,
        dhSelfPubB64: row['dh_self_pub_b64'] as String,
        dhRemotePubB64: row['dh_remote_pub_b64'] as String?,
        sendChainKeyB64: row['send_chain_key_b64'] as String?,
        recvChainKeyB64: row['recv_chain_key_b64'] as String?,
        ns: (row['ns'] as num).toInt(),
        nr: (row['nr'] as num).toInt(),
        pn: (row['pn'] as num).toInt(),
        // Э-4 Р-4: the base key travels WITH the session. Without it a late
        // repeat of this handshake would miss the archive, fall through to
        // X3DH and overwrite whatever NEWER session replaced this one.
        handshakeBasePubB64: row['handshake_base_pub_b64'] as String?,
        txn: txn,
      );
    } catch (_) {
      // best-effort; never let archiving break decryption/reset
    }
  }

  // Push an explicit session state into the candidate archive (used when a
  // glare tie-break keeps our own session and we still want to be able to
  // decrypt stragglers that arrive under the peer's losing session).
  Future<void> _archiveSessionState(
    DoubleRatchetStateV3 s, {
    /// Э-4 Р-4: the handshake this candidate came from, so a later repeat of
    /// it still finds a session here instead of re-running X3DH.
    String? handshakeBasePubB64,
    DatabaseExecutor? txn,
  }) async {
    try {
      await db.sessionV3ArchivePush(
        peerDeviceId: s.peerDeviceId,
        rootKeyB64: base64Encode(s.rootKey),
        dhSelfSeedB64: base64Encode(s.dhSelfSeed),
        dhSelfPubB64: base64Encode(s.dhSelfPub),
        dhRemotePubB64: s.dhRemotePub == null
            ? null
            : base64Encode(s.dhRemotePub!),
        sendChainKeyB64: s.sendChainKey == null
            ? null
            : base64Encode(s.sendChainKey!),
        recvChainKeyB64: s.recvChainKey == null
            ? null
            : base64Encode(s.recvChainKey!),
        ns: s.ns,
        nr: s.nr,
        pn: s.pn,
        handshakeBasePubB64: handshakeBasePubB64,
        txn: txn,
      );
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _persistArchive(
    int id,
    DoubleRatchetStateV3 s, {
    DatabaseExecutor? txn,
  }) async {
    await db.sessionV3ArchiveUpdate(
      id: id,
      dhSelfSeedB64: base64Encode(s.dhSelfSeed),
      dhSelfPubB64: base64Encode(s.dhSelfPub),
      dhRemotePubB64: s.dhRemotePub == null
          ? null
          : base64Encode(s.dhRemotePub!),
      sendChainKeyB64: s.sendChainKey == null
          ? null
          : base64Encode(s.sendChainKey!),
      recvChainKeyB64: s.recvChainKey == null
          ? null
          : base64Encode(s.recvChainKey!),
      ns: s.ns,
      nr: s.nr,
      pn: s.pn,
      txn: txn,
    );
  }

  Future<void> _pruneSkipped({DatabaseExecutor? txn}) async {
    // Best-effort pruning to keep DB bounded. Keep 7 days of skipped keys.
    try {
      final cutoff =
          DateTime.now().millisecondsSinceEpoch - 7 * 24 * 60 * 60 * 1000;
      await db.skippedKeysPrune(olderThanMs: cutoff, txn: txn);
      // Room sender-key stragglers share this horizon and this sweep. Wired
      // here while the store is still EMPTY (nothing writes room keys until
      // фаза 3): an unpruned key store is both a disk leak and a widening
      // window for a seized device, and a prune that has to be remembered
      // later is a prune that does not happen.
      await db.roomSkippedKeysPrune(olderThanMs: cutoff, txn: txn);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _persist(
    DoubleRatchetStateV3 s, {
    DatabaseExecutor? txn,
  }) async {
    await db.sessionV3Upsert(
      peerDeviceId: s.peerDeviceId,
      rootKeyB64: base64Encode(s.rootKey),
      dhSelfSeedB64: base64Encode(s.dhSelfSeed),
      dhSelfPubB64: base64Encode(s.dhSelfPub),
      dhRemotePubB64: s.dhRemotePub == null
          ? null
          : base64Encode(s.dhRemotePub!),
      sendChainKeyB64: s.sendChainKey == null
          ? null
          : base64Encode(s.sendChainKey!),
      recvChainKeyB64: s.recvChainKey == null
          ? null
          : base64Encode(s.recvChainKey!),
      ns: s.ns,
      nr: s.nr,
      pn: s.pn,
      txn: txn,
    );
  }

  DoubleRatchetStateV3 _stateFromRow(
    String peerDeviceId,
    Map<String, Object?> row,
  ) {
    final root = Uint8List.fromList(
      base64Decode(row['root_key_b64'] as String),
    );
    final dhSeed = Uint8List.fromList(
      base64Decode(row['dh_self_seed_b64'] as String),
    );
    final dhPub = Uint8List.fromList(
      base64Decode(row['dh_self_pub_b64'] as String),
    );

    final remoteB64 = row['dh_remote_pub_b64'] as String?;
    final sendCkB64 = row['send_chain_key_b64'] as String?;
    final recvCkB64 = row['recv_chain_key_b64'] as String?;

    return DoubleRatchetStateV3(
      peerDeviceId: peerDeviceId,
      rootKey: root,
      dhSelfSeed: dhSeed,
      dhSelfPub: dhPub,
      dhRemotePub: (remoteB64 == null || remoteB64.isEmpty)
          ? null
          : Uint8List.fromList(base64Decode(remoteB64)),
      sendChainKey: (sendCkB64 == null || sendCkB64.isEmpty)
          ? null
          : Uint8List.fromList(base64Decode(sendCkB64)),
      recvChainKey: (recvCkB64 == null || recvCkB64.isEmpty)
          ? null
          : Uint8List.fromList(base64Decode(recvCkB64)),
      ns: (row['ns'] as num).toInt(),
      nr: (row['nr'] as num).toInt(),
      pn: (row['pn'] as num).toInt(),
    );
  }

  Future<_PeerBundleV1> _fetchAndVerifyPeerBundle({
    required String peerProfileId,
    required String peerDeviceId,
  }) async {
    final devices = await (fetchBundleAuthed != null
        ? fetchBundleAuthed!(peerProfileId)
        : keysClient.fetchBundle(peerProfileId));

    final match = devices
        .where((d) => d['device_id'] == peerDeviceId)
        .toList(growable: false);
    if (match.isEmpty) {
      throw StateError('peer device not found in bundle: $peerDeviceId');
    }

    final d = match.first;
    final identityB64 = d['identity_key_pub_b64'] as String?;
    final spkB64 = d['signed_prekey_pub_b64'] as String?;
    final spkSigB64 = d['signed_prekey_sig_b64'] as String?;
    final otk = d['one_time_prekey'];

    if (identityB64 == null || spkB64 == null || spkSigB64 == null) {
      throw StateError('bundle missing required fields');
    }

    // Verify signed prekey signature.
    final identityPub = SimplePublicKey(
      base64Decode(identityB64),
      type: KeyPairType.ed25519,
    );
    final spkBytes = base64Decode(spkB64);
    final sigBytes = base64Decode(spkSigB64);

    final ed = Ed25519();
    final sig = Signature(sigBytes, publicKey: identityPub);
    final ok = await ed.verify(spkBytes, signature: sig);
    if (!ok) {
      throw StateError('signed prekey signature verification failed');
    }

    await db.contactDeviceUpsert(
      profileId: peerProfileId,
      deviceId: peerDeviceId,
      identityKeyPubB64: identityB64,
      signedPrekeyPubB64: spkB64,
      signedPrekeySigB64: spkSigB64,
    );

    int? otkId;
    String? otkPubB64;
    if (otk is Map) {
      final prekeyId = otk['prekey_id'];
      if (prekeyId is num) otkId = prekeyId.toInt();
      final pub = otk['prekey_pub_b64'];
      if (pub is String) otkPubB64 = pub;
    }

    return _PeerBundleV1(
      deviceId: peerDeviceId,
      identityKeyPubB64: identityB64,
      signedPrekeyPubB64: spkB64,
      signedPrekeySigB64: spkSigB64,
      oneTimePrekeyId: otkId,
      oneTimePrekeyPubB64: otkPubB64,
    );
  }
}

class _PeerBundleV1 {
  const _PeerBundleV1({
    required this.deviceId,
    required this.identityKeyPubB64,
    required this.signedPrekeyPubB64,
    required this.signedPrekeySigB64,
    required this.oneTimePrekeyId,
    required this.oneTimePrekeyPubB64,
  });

  final String deviceId;
  final String identityKeyPubB64;
  final String signedPrekeyPubB64;
  final String signedPrekeySigB64;
  final int? oneTimePrekeyId;
  final String? oneTimePrekeyPubB64;
}
