// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/storage/app_db.dart';

/// 🔴 Э-0 — the lifetime cap on
/// re-sending one message to one device.
///
/// Proven on production 2026-08-01: re-sending an undelivered message had a
/// 90-second debounce and NO lifetime cap, and the debounce map lived in
/// MEMORY, so an app restart reopened the gate immediately. 13 real messages
/// became 504 mailbox rows; one was re-sent 94 times over 30 hours; 298 copies
/// went to a device the relay had evicted days earlier. Every re-send is a new
/// relay message — therefore a new push and a new banner, which is the
/// "notifications for messages I already read" report.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const maxAttempts = 5;
  const maxBonus = 3;

  /// One full re-send: ask, and — if allowed — actually spend it. Mirrors the
  /// caller, where the spend happens only after a wire reaches the outbox.
  Future<bool> attemptResend(
    AppDb db, {
    String eventId = 'ev-1',
    String deviceId = 'dev-A',
    int nowMs = 1000,
  }) async {
    if (!await db.resendBudgetHasRoom(
      eventId: eventId,
      deviceId: deviceId,
      epoch: 0,
      maxAttempts: maxAttempts,
    )) {
      return false;
    }
    await db.resendBudgetConsume(
      eventId: eventId,
      deviceId: deviceId,
      epoch: 0,
      nowMs: nowMs,
    );
    return true;
  }

  test('🔴 the cap stops a message that can never land', () async {
    final db = await AppDb.openForTesting();
    var sent = 0;
    for (var i = 0; i < 40; i++) {
      if (await attemptResend(db, nowMs: 1000 + i)) sent++;
    }
    expect(sent, maxAttempts,
        reason: 'without a cap this is the 94-copy storm');
    await db.close();
  });

  /// 🔴 THE DEFECT THIS API SHAPE EXISTS FOR — found reviewing my own first
  /// version of Э-0.
  ///
  /// The budget was consumed BEFORE the local copy was decrypted and
  /// re-encrypted, and several bail-outs sit between those points: an
  /// unreadable local payload (a content-key hiccup — a failure mode this app
  /// has actually had), the dead-blob gate, an encryption error. A message that
  /// never left the device would have burned its whole budget across a few
  /// sweeps and could never be re-sent again once the local problem cleared.
  test('🔴 an attempt that never left the device costs NOTHING', () async {
    final db = await AppDb.openForTesting();
    // Ten sweeps that all bail after the check (no wire ever enqueued).
    for (var i = 0; i < 10; i++) {
      expect(
        await db.resendBudgetHasRoom(
          eventId: 'ev-1',
          deviceId: 'dev-A',
          epoch: 0,
          maxAttempts: maxAttempts,
        ),
        isTrue,
      );
      // ...and then `continue` — nothing consumed.
    }
    expect(
      await db.resendBudgetUsed(eventId: 'ev-1', deviceId: 'dev-A'),
      0,
      reason: 'budget is for wires that were SENT, never for attempts that '
          'died at home',
    );
    // The full budget must still be available once the local problem clears.
    var sent = 0;
    for (var i = 0; i < 10; i++) {
      if (await attemptResend(db, nowMs: 2000 + i)) sent++;
    }
    expect(sent, maxAttempts);
    await db.close();
  });

  test('🔴 the budget SURVIVES a restart — the in-memory one did not', () async {
    // The exact defect: `_resendUndeliveredAtMs` is a plain map, so relaunching
    // the app let every stuck message start re-sending again from zero. Proving
    // this needs a FILE-backed database opened twice — an in-memory one would
    // pass trivially and prove nothing.
    final dir = await Directory.systemTemp.createTemp('resend_budget');
    final path = p.join(dir.path, 'restart.db');
    try {
      final first = await AppDb.openForTesting(path: path);
      for (var i = 0; i < maxAttempts; i++) {
        expect(await attemptResend(first, nowMs: 1000 + i), isTrue);
      }
      await first.close();

      // Fresh handle on the same file = what a relaunch actually looks like.
      final relaunched = await AppDb.openForTesting(path: path);
      expect(
        await attemptResend(relaunched, nowMs: 9999),
        isFalse,
        reason: 'a restart must not reopen the floodgate',
      );
      await relaunched.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('budgets are independent per device and per event', () async {
    // One of a peer's devices may be dead while another is fine, and a rotated
    // device deserves a fresh start — its human never saw the message at all.
    final db = await AppDb.openForTesting();
    for (var i = 0; i < maxAttempts; i++) {
      await attemptResend(db, nowMs: 1000 + i);
    }
    expect(await attemptResend(db, deviceId: 'dev-B', nowMs: 2000), isTrue,
        reason: 'another device of the same peer has its own budget');
    expect(await attemptResend(db, eventId: 'ev-2', nowMs: 2000), isTrue,
        reason: 'another message has its own budget');
    await db.close();
  });

  test('a NACK buys more attempts, but only up to the bonus cap', () async {
    // A statement from the recipient outranks our own guessing — but a peer
    // stuck in its own loop must not be able to farm unlimited re-sends.
    final db = await AppDb.openForTesting();
    for (var i = 0; i < maxAttempts; i++) {
      await attemptResend(db, nowMs: 1000 + i);
    }
    expect(await attemptResend(db, nowMs: 2000), isFalse);

    // Ten NACKs must not grant ten attempts.
    for (var i = 0; i < 10; i++) {
      await db.resendBudgetGrantBonus(
        eventId: 'ev-1',
        deviceId: 'dev-A',
        epoch: 0,
        maxBonus: maxBonus,
        nowMs: 3000 + i,
      );
    }
    var extra = 0;
    for (var i = 0; i < 10; i++) {
      if (await attemptResend(db, nowMs: 4000 + i)) extra++;
    }
    expect(extra, maxBonus,
        reason: 'the NACK bonus must be bounded, or a looping peer farms us');
    await db.close();
  });

  test('🔴 FAILURE DIRECTION: unable to count => do NOT send', () async {
    // The opposite of the decrypt budget next door, deliberately. There, being
    // unable to count must not park a wire (the risk is LOSING a message).
    // Here the risk is DROWNING one, so silence means stop.
    final db = await AppDb.openForTesting();
    await db.close(); // every storage call now throws
    expect(
      await db.resendBudgetHasRoom(
        eventId: 'ev-1',
        deviceId: 'dev-A',
        epoch: 0,
        maxAttempts: maxAttempts,
      ),
      isFalse,
      reason: 'a storage error must never license an unbounded re-send',
    );
  });

  test('degenerate input cannot license a send', () async {
    final db = await AppDb.openForTesting();
    expect(
      await db.resendBudgetHasRoom(
        eventId: '',
        deviceId: 'dev-A',
        epoch: 0,
        maxAttempts: maxAttempts,
      ),
      isFalse,
    );
    expect(
      await db.resendBudgetHasRoom(
        eventId: 'ev-1',
        deviceId: '   ',
        epoch: 0,
        maxAttempts: maxAttempts,
      ),
      isFalse,
    );
    expect(
      await db.resendBudgetHasRoom(
        eventId: 'ev-1',
        deviceId: 'dev-A',
        epoch: 0,
        maxAttempts: 0,
      ),
      isFalse,
    );
    await db.close();
  });

  test('prune drops budgets older than the relay mailbox TTL', () async {
    final db = await AppDb.openForTesting();
    await attemptResend(db, eventId: 'ev-old', nowMs: 1000);
    expect(
      await db.resendBudgetUsed(eventId: 'ev-old', deviceId: 'dev-A'),
      1,
    );
    await db.resendBudgetPrune(500_000);
    expect(
      await db.resendBudgetUsed(eventId: 'ev-old', deviceId: 'dev-A'),
      0,
      reason: 'a wire the relay has already dropped cannot be re-sent usefully',
    );
    await db.close();
  });
}
