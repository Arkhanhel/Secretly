// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

/// Phase 1 of docs/TZ_ROOM_SENDER_KEY_2026-07-29.md — the room-side convergence
/// backstop.
///
/// Context: the 1:1 backstop's detector explicitly filters out `group:`
/// conversations, so a room member whose session diverged had no automatic
/// repair whatsoever. `roomIdsWithUndeliveredSends` is the room detector; these
/// tests pin the two properties that make enabling it safe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> put(
    AppDb db, {
    required String id,
    required String convo,
    required String senderDev,
    required int atMs,
    required String state,
  }) => db.insertEvent(
    eventId: id,
    convoId: convo,
    type: 'msg',
    senderDeviceId: senderDev,
    ciphertextB64: 'x',
    createdAtMs: atMs,
    localState: state,
  );

  test(
    'finds rooms whose messages nobody acknowledged, and ONLY rooms',
    () async {
      final db = await AppDb.openForTesting();
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = now - 5 * 60 * 1000;
      final fresh = now - 10 * 1000;

      // A room where the send is stuck → must be flagged.
      await put(db, id: 'r1', convo: 'group:broken', senderDev: 'me', atMs: old, state: 'sent');
      // A 1:1 chat that is equally stuck → belongs to the OTHER backstop and
      // must NOT show up here, or both would repair the same peer at once.
      await put(db, id: 'd1', convo: 'peerA', senderDev: 'me', atMs: old, state: 'sent');
      // Contact requests stay out of both.
      await put(db, id: 'q1', convo: 'req:peerX', senderDev: 'me', atMs: old, state: 'sent');
      // Too fresh: delivery has not had its chance yet.
      await put(db, id: 'r2', convo: 'group:young', senderDev: 'me', atMs: fresh, state: 'sent');

      final flagged = await db.roomIdsWithUndeliveredSends(
        stuckBeforeMs: now - 90 * 1000,
        minCount: 1,
      );

      expect(flagged, contains('group:broken'));
      expect(flagged, isNot(contains('peerA')));
      expect(flagged, isNot(contains('req:peerX')));
      expect(flagged, isNot(contains('group:young')));

      await db.close();
    },
  );

  test(
    'a room that reached SOMEONE is never flagged — this is what stops a '
    'resend storm in a partially-delivered room',
    () async {
      final db = await AppDb.openForTesting();
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = now - 5 * 60 * 1000;

      // A room message flips to 'delivered' as soon as the FIRST member
      // acknowledges. So a room where delivery is merely INCOMPLETE (9 of 10
      // members missed it) looks identical to a healthy one here, and the
      // backstop stays silent. That is deliberate: this detector must never
      // mistake partial delivery for a broken room and re-key everyone in a
      // loop. Finding the missing 9 needs per-member receipts — a later step.
      await put(db, id: 'ok1', convo: 'group:partial', senderDev: 'me', atMs: old, state: 'delivered');
      await put(db, id: 'ok2', convo: 'group:read', senderDev: 'me', atMs: old, state: 'read');

      final flagged = await db.roomIdsWithUndeliveredSends(
        stuckBeforeMs: now - 90 * 1000,
        minCount: 1,
      );

      expect(flagged, isEmpty);

      await db.close();
    },
  );

  test(
    'per-member: finds what ONE member never acknowledged, even when the room '
    'already reads delivered because someone else did',
    () async {
      final db = await AppDb.openForTesting();
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = now - 5 * 60 * 1000;

      // My room message. Another member acked it, so local_state is
      // 'delivered' and the room-level detector is blind to it.
      await db.insertEvent(
        eventId: 'm1',
        convoId: 'group:team',
        type: 'msg',
        senderDeviceId: 'my-dev',
        ciphertextB64: 'x',
        createdAtMs: old,
        localState: 'delivered',
        payloadEventId: 'p1',
      );
      await db.roomMessageReceiptUpsert(
        payloadEventId: 'p1',
        readerProfileId: 'alice',
        readerDeviceId: 'alice-dev',
        status: 'delivered',
        updatedAtMs: old,
      );

      // Alice acked → nothing owed to her.
      final owedAlice = await db.roomSendsMissingReceiptFrom(
        roomId: 'group:team',
        readerProfileId: 'alice',
        senderDeviceId: 'my-dev',
        stuckBeforeMs: now - 90 * 1000,
      );
      expect(owedAlice, isEmpty);

      // Bob never did → the message is owed to him and must be repairable.
      final owedBob = await db.roomSendsMissingReceiptFrom(
        roomId: 'group:team',
        readerProfileId: 'bob',
        senderDeviceId: 'my-dev',
        stuckBeforeMs: now - 90 * 1000,
      );
      expect(owedBob.map((r) => r['payload_event_id']), contains('p1'));

      await db.close();
    },
  );

  test(
    'a still-held "send later" message is NEVER treated as owed — it would be '
    'released early (field report 2026-07-21)',
    () async {
      final db = await AppDb.openForTesting();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Composed long ago, scheduled for the FUTURE: the relay is still holding
      // it. Matching on created_at_ms alone would call it stuck and push it out
      // immediately — the exact bug that sent a 6:25 message at 6:10.
      await db.insertEvent(
        eventId: 'sched1',
        convoId: 'group:team',
        type: 'msg',
        senderDeviceId: 'my-dev',
        ciphertextB64: 'x',
        createdAtMs: now - 60 * 60 * 1000,
        localState: 'sent',
        payloadEventId: 'ps1',
        scheduledAtMs: now + 60 * 60 * 1000,
      );

      final owed = await db.roomSendsMissingReceiptFrom(
        roomId: 'group:team',
        readerProfileId: 'bob',
        senderDeviceId: 'my-dev',
        stuckBeforeMs: now - 90 * 1000,
      );
      expect(owed, isEmpty);

      await db.close();
    },
  );

  group('room convergence flag', () {
    tearDown(() {
      AppController.roomConvergenceBackstopEnabled = true;
    });

    test('ships ON — without it a diverged member never recovers', () {
      // A backstop that never runs is not a fix. Rooms are the one place with
      // no fallback: a partial fanout leaves a specific member with nothing
      // while the message reads as sent, and the send path never retries them.
      //
      // What the backstop restores is the SESSION, so every future room
      // message reaches that member again. The messages already lost stay lost
      // until the room wire itself is replayable — see the replay guard below.
      expect(AppController.roomConvergenceBackstopEnabled, isTrue);
    });

    test('can still be switched off', () {
      // Two independent brakes: this flag (--dart-define at build time) and
      // `convergenceResendEnabled` from the signed remote config, which turns
      // it off in the field with no rebuild.
      AppController.roomConvergenceBackstopEnabled = false;
      expect(AppController.roomConvergenceBackstopEnabled, isFalse);
    });
  });

  group('room repair must never replay a room message as a private one', () {
    // 🔴 A room member receives a `__secretly_group_msg_v1__:` control envelope
    // carrying the room id, the roster and the sender identity. My LOCAL copy
    // of that same message is the bare text. The convergence repair re-sends
    // the local copy — correct for 1:1, where the two are the same bytes.
    //
    // For a room they are not: the member would get a plain message with no
    // group command, `_parseGroupMessageCommand` would return null, and the
    // receive path files it under `convoId = <sender profile id>` — the room's
    // message appears as a PRIVATE message from its author. Wrong conversation,
    // wrong audience, silently. The session re-key still runs and is the actual
    // cure; only the content replay is withheld until the room wire itself is
    // replayable (sender key, фаза 3).

    test('a 1:1 conversation may be replayed — the copy IS the peer wire', () {
      expect(AppController.canReplayLocalCopyToPeer('peerA'), isTrue);
      expect(AppController.canReplayLocalCopyToPeer('req:peerA'), isTrue);
      expect(AppController.canReplayLocalCopyToPeer('dev:abc'), isTrue);
    });

    test('a room may NOT be replayed', () {
      expect(AppController.canReplayLocalCopyToPeer('group:team'), isFalse);
      // Whitespace must not smuggle a room past the check.
      expect(AppController.canReplayLocalCopyToPeer('  group:team'), isFalse);
    });
  });
}
