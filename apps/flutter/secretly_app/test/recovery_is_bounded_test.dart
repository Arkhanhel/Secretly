// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// STAGE 5 of TZ_INVARIANTS_2026-07-20 — the composition test.
///
/// Every rate limiter on the recovery path is justified on its own. On
/// 2026-07-20 they composed into "never": a live capture showed 18 inbound
/// wires re-failing about once a second with zero NACKs, zero session resets
/// and zero quarantine writes. Nothing was broken; everything had simply
/// declined.
///
/// Unit tests could not catch that, because each guard passed its own test.
/// What was missing is a test of the GUARANTEE: while a peer stays broken, a
/// repair attempt must keep being possible — with an upper bound measured in
/// minutes, not in days.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDb db;

  setUp(() async => db = await AppDb.openForTesting());
  tearDown(() async => db.close());

  Future<void> park(String msgId, int nowMs) => db.inboxQuarantineUpsert(
    msgId: msgId,
    senderDeviceId: 'peer-device',
    ciphertextB64: 'AA==',
    nowMs: nowMs,
  );

  test('a parked wire can be reported the first time', () async {
    const t0 = 1784500000000;
    await park('m1', t0);
    expect(
      await db.inboxQuarantineClaimNack(msgId: 'm1', nowMs: t0),
      isTrue,
    );
  });

  test('an immediate second report is refused — no storm', () async {
    const t0 = 1784500000000;
    await park('m1', t0);
    await db.inboxQuarantineClaimNack(msgId: 'm1', nowMs: t0);

    expect(
      await db.inboxQuarantineClaimNack(msgId: 'm1', nowMs: t0 + 1000),
      isFalse,
      reason: 'a wire must not be re-reported seconds later',
    );
  });

  test('RECOVERY IS BOUNDED: a still-stuck wire is reportable again', () async {
    // A real wall-clock base: `nacked_at_ms = 0` is the "never claimed"
    // sentinel, so claiming at epoch 0 would look unclaimed forever.
    const t0 = 1784500000000;
    await park('m1', t0);
    await db.inboxQuarantineClaimNack(msgId: 'm1', nowMs: t0);

    // The bound. Before this change the answer was 24 hours, which — together
    // with the per-device gate — is why a stuck conversation stayed stuck all
    // day. Anything beyond this is a conversation the user has given up on.
    const boundMs = 10 * 60 * 1000;

    expect(
      await db.inboxQuarantineClaimNack(msgId: 'm1', nowMs: t0 + boundMs - 1000),
      isFalse,
      reason: 'still inside the window',
    );
    expect(
      await db.inboxQuarantineClaimNack(msgId: 'm1', nowMs: t0 + boundMs),
      isTrue,
      reason:
          'a wire that is STILL undecryptable must earn another report, or '
          'recovery never happens at all',
    );
  });

  test('a whole backlog stays reportable, not just the first wire', () async {
    // The live incident had 18 parked wires. Each must remain independently
    // claimable — one wire monopolising the path is how the rest went silent.
    const t0 = 1784500000000;
    for (var i = 0; i < 18; i++) {
      await park('m$i', t0);
    }
    for (var i = 0; i < 18; i++) {
      expect(
        await db.inboxQuarantineClaimNack(msgId: 'm$i', nowMs: t0),
        isTrue,
        reason: 'wire $i must be claimable on its own merits',
      );
    }
  });
}
