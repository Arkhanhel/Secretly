// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

/// Tests for the two read queries that drive the sender-side session-convergence
/// backstop (TZ §20 pillar 1): detect a 1:1 session that silently desynced by
/// spotting my messages that go relay-ACKed ('sent') but never earn an
/// end-to-end 'delivered' receipt, while confirming the peer is alive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> put(
    AppDb db, {
    required String id,
    required String convo,
    required String senderDev,
    required int atMs,
    required String state,
  }) =>
      db.insertEvent(
        eventId: id,
        convoId: convo,
        type: 'msg',
        senderDeviceId: senderDev,
        ciphertextB64: 'x',
        createdAtMs: atMs,
        localState: state,
      );

  test(
    'convoIdsWithUndeliveredSends flags only 1:1 convos with >=minCount stuck '
    'sends older than the cutoff; excludes delivered/fresh/groups/requests',
    () async {
      final db = await AppDb.openForTesting();
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = now - 5 * 60 * 1000; // clearly older than the 90s cutoff
      final fresh = now - 10 * 1000; // younger than the cutoff

      // peerA: two stuck 'sent' → FLAGGED.
      await put(db, id: 'a1', convo: 'peerA', senderDev: 'me', atMs: old, state: 'sent');
      await put(db, id: 'a2', convo: 'peerA', senderDev: 'me', atMs: old, state: 'sent');
      // peerB: one stuck 'sent' + one already 'delivered' → below minCount → NOT flagged.
      await put(db, id: 'b1', convo: 'peerB', senderDev: 'me', atMs: old, state: 'sent');
      await put(db, id: 'b2', convo: 'peerB', senderDev: 'me', atMs: old, state: 'delivered');
      // peerC: two 'sent' but too fresh → NOT flagged (delivery still has time).
      await put(db, id: 'c1', convo: 'peerC', senderDev: 'me', atMs: fresh, state: 'sent');
      await put(db, id: 'c2', convo: 'peerC', senderDev: 'me', atMs: fresh, state: 'sent');
      // group + request convos with stuck sends → excluded by prefix.
      await put(db, id: 'g1', convo: 'group:room1', senderDev: 'me', atMs: old, state: 'sent');
      await put(db, id: 'g2', convo: 'group:room1', senderDev: 'me', atMs: old, state: 'sent');
      await put(db, id: 'r1', convo: 'req:peerX', senderDev: 'me', atMs: old, state: 'sent');
      await put(db, id: 'r2', convo: 'req:peerX', senderDev: 'me', atMs: old, state: 'sent');

      final flagged = await db.convoIdsWithUndeliveredSends(
        stuckBeforeMs: now - 90 * 1000,
        minCount: 2,
      );

      expect(flagged, contains('peerA'));
      expect(flagged, isNot(contains('peerB')));
      expect(flagged, isNot(contains('peerC')));
      expect(flagged, isNot(contains('group:room1')));
      expect(flagged, isNot(contains('req:peerX')));

      await db.close();
    },
  );

  test(
    'a SINGLE stuck send is flagged at the shipped minCount — one undelivered '
    'message must still heal (it used to need two, so a lone message was never '
    'repaired: no rekey, no resend, silence forever)',
    () async {
      final db = await AppDb.openForTesting();
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = now - 5 * 60 * 1000;

      // Exactly ONE stuck send — the "I wrote you once and you never got it" case.
      await put(db, id: 'only1', convo: 'peerA', senderDev: 'me', atMs: old, state: 'sent');
      // A peer whose lone send is already delivered must NOT be flagged.
      await put(db, id: 'ok1', convo: 'peerB', senderDev: 'me', atMs: old, state: 'delivered');
      // Still-fresh lone send: delivery has not had its chance yet.
      await put(db, id: 'fresh1', convo: 'peerC', senderDev: 'me', atMs: now - 10 * 1000, state: 'sent');

      final flagged = await db.convoIdsWithUndeliveredSends(
        stuckBeforeMs: now - 90 * 1000,
        minCount: AppController.senderConvergenceMinStuckForTesting,
      );

      expect(AppController.senderConvergenceMinStuckForTesting, 1);
      expect(flagged, contains('peerA'));
      expect(flagged, isNot(contains('peerB')));
      expect(flagged, isNot(contains('peerC')));

      await db.close();
    },
  );

  test('latestInboundAtMs returns the newest inbound and ignores my sends', () async {
    final db = await AppDb.openForTesting();
    await put(db, id: 'i1', convo: 'peerA', senderDev: 'peer', atMs: 1000, state: 'received');
    await put(db, id: 'i2', convo: 'peerA', senderDev: 'peer', atMs: 5000, state: 'received');
    // My own outbound in the same convo must NOT count as inbound.
    await put(db, id: 'o1', convo: 'peerA', senderDev: 'me', atMs: 9999, state: 'sent');

    expect(await db.latestInboundAtMs('peerA'), 5000);
    expect(await db.latestInboundAtMs('peerWithNothing'), 0);

    await db.close();
  });

  test(
      'undeliveredDirectSentEvents returns stuck sent 1:1 msg events oldest-first; '
      'excludes delivered + still-fresh (drives auto-resend)', () async {
    final db = await AppDb.openForTesting();
    final now = DateTime.now().millisecondsSinceEpoch;
    final old = now - 5 * 60 * 1000;
    final older = now - 6 * 60 * 1000;
    final fresh = now - 10 * 1000;

    await put(db, id: 's1', convo: 'peerA', senderDev: 'me', atMs: old, state: 'sent');
    await put(db, id: 's0', convo: 'peerA', senderDev: 'me', atMs: older, state: 'sent');
    // Already confirmed → must NOT be re-sent.
    await put(db, id: 'sd', convo: 'peerA', senderDev: 'me', atMs: old, state: 'delivered');
    // Still fresh → delivery still has time; not yet.
    await put(db, id: 'sf', convo: 'peerA', senderDev: 'me', atMs: fresh, state: 'sent');

    final ids = (await db.undeliveredDirectSentEvents(
      convoId: 'peerA',
      stuckBeforeMs: now - 90 * 1000,
    ))
        .map((r) => r['event_id'] as String)
        .toList();

    // Oldest first, only the two stuck sends.
    expect(ids, <String>['s0', 's1']);

    await db.close();
  });

  test(
    'a still-held "send later" message never flags its conversation — the '
    'backstop would reset a session that is perfectly fine',
    () async {
      // Field-report class (2026-07-21), on the DETECTOR side this time.
      // `markScheduledDirectUploaded` flips a scheduled message to 'sent' the
      // moment the relay accepts it for HOLDING, while created_at_ms stays at
      // compose time. With minCount = 1 and a 90-second window, one scheduled
      // message therefore made a healthy conversation look desynced, and the
      // backstop answered by force-resetting the peer's session — exactly the
      // needless proactive reset И-4 exists to eliminate. The resend query
      // already guarded against this; the detector did not.
      final db = await AppDb.openForTesting();
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insertEvent(
        eventId: 'sched1',
        convoId: 'peerA',
        type: 'msg',
        senderDeviceId: 'me',
        ciphertextB64: 'x',
        createdAtMs: now - 60 * 60 * 1000,
        localState: 'sent',
        scheduledAtMs: now + 60 * 60 * 1000,
      );
      await db.insertEvent(
        eventId: 'sched2',
        convoId: 'group:team',
        type: 'msg',
        senderDeviceId: 'me',
        ciphertextB64: 'x',
        createdAtMs: now - 60 * 60 * 1000,
        localState: 'sent',
        scheduledAtMs: now + 60 * 60 * 1000,
      );

      final cutoff = now - 90 * 1000;
      expect(
        await db.convoIdsWithUndeliveredSends(
          stuckBeforeMs: cutoff,
          minCount: 1,
        ),
        isEmpty,
      );
      expect(
        await db.roomIdsWithUndeliveredSends(
          stuckBeforeMs: cutoff,
          minCount: 1,
        ),
        isEmpty,
      );

      // Once its time has passed and it is genuinely unacknowledged, it counts
      // like any other message — the guard delays the check, it does not
      // disable it.
      await db.insertEvent(
        eventId: 'due1',
        convoId: 'peerA',
        type: 'msg',
        senderDeviceId: 'me',
        ciphertextB64: 'x',
        createdAtMs: now - 60 * 60 * 1000,
        localState: 'sent',
        scheduledAtMs: now - 10 * 60 * 1000,
      );
      expect(
        await db.convoIdsWithUndeliveredSends(
          stuckBeforeMs: cutoff,
          minCount: 1,
        ),
        contains('peerA'),
      );

      await db.close();
    },
  );
}
