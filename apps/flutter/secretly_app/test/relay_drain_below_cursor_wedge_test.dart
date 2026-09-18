// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';

/// Regression for the OFFLINE-DRAIN DEADLOCK (2026-06-25): a stale reorder-buffer
/// entry BELOW the cursor (re-buffered by a gap-fetch lower-then-restore race
/// while a device was offline) pinned `minBuffered` below `_nextSeq`. The
/// gap-skip self-heal only fires when `minBuffered > _nextSeq`, so it never
/// triggered: the drain bailed on every poll, the cursor stayed frozen, and
/// ZERO messages were delivered even though the relay kept re-offering the
/// backlog (live: pump_inbox_ok count climbed, from_seq frozen, drain_gap
/// next_seq=16 min_buf=15). The fix purges below-cursor entries before the
/// self-heal so the drain can always make forward progress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pumpInbox self-heals a below-cursor poisoned reorder buffer (no wedge)',
      () async {
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();
    final delivered = <String>[];

    final client = MockClient((req) async {
      final path = req.url.path;
      if (req.method == 'GET' && path.contains('/v1/pending')) {
        // The real backlog: seqs 6,7,8 — all AT/ABOVE the cursor (5). Seq 5
        // itself is absent (the boundary the cursor is stuck on).
        return http.Response(
          jsonEncode({
            'items': [
              {'seq': 6, 'msg_id': 'm6', 'ciphertext_b64': 'AA=='},
              {'seq': 7, 'msg_id': 'm7', 'ciphertext_b64': 'AA=='},
              {'seq': 8, 'msg_id': 'm8', 'ciphertext_b64': 'AA=='},
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 200); // /v1/ack etc.
    });

    final relay = RelayClient(
      db: db,
      deviceId: 'self-device',
      selfProfileId: 'self-profile',
      deviceKeys: DeviceKeys.create(),
      wsUrl: Uri.parse('ws://example.test/ws'),
      httpBaseUrl: Uri.parse('https://example.test'),
      httpClient: client,
      identityKeyPairOverride: kp,
      onDelivered: ({required msgId, required ciphertextB64}) async {
        delivered.add(msgId);
        return true;
      },
      loadNextSeq: () async => 5,
      saveNextSeq: (_) async {},
      webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
          throw StateError('no websocket in this test'),
    );

    try {
      await relay.connect(); // seeds _nextSeq=5; WS attempt throws (caught)
    } catch (_) {}

    // Poison the buffer with a stale entry BELOW the cursor (seq 3 < 5). This
    // is the exact condition that wedged the drain before the fix.
    relay.debugSeedReorderEntryForTest(
      seq: 3,
      msgId: 'm3stale',
      ciphertextB64: 'AA==',
    );

    await relay.pumpInbox(force: true);

    // FIX: the below-cursor entry is purged, the gap-skip advances past the
    // missing boundary, and the whole backlog drains.
    expect(delivered, containsAll(<String>['m6', 'm7', 'm8']),
        reason: 'backlog must drain — a below-cursor entry must not wedge it');
    expect(delivered, isNot(contains('m3stale')),
        reason: 'stale below-cursor straggler must not be re-delivered');
    expect(relay.debugNextSeqForTest, greaterThanOrEqualTo(9),
        reason: 'cursor must advance past the drained backlog');
    expect(relay.debugReorderBufferLengthForTest, 0,
        reason: 'reorder buffer must be fully drained');
  });

  test('drain purges below-cursor stragglers and drains buffered backlog',
      () async {
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();
    final delivered = <String>[];

    // Empty pending fetch: the backlog is already buffered (e.g. WS-delivered);
    // the pump only needs to purge the straggler and drain what is held.
    final client = MockClient((req) async => http.Response('{"items":[]}', 200));

    final relay = RelayClient(
      db: db,
      deviceId: 'self-device',
      selfProfileId: 'self-profile',
      deviceKeys: DeviceKeys.create(),
      wsUrl: Uri.parse('ws://example.test/ws'),
      httpBaseUrl: Uri.parse('https://example.test'),
      httpClient: client,
      identityKeyPairOverride: kp,
      onDelivered: ({required msgId, required ciphertextB64}) async {
        delivered.add(msgId);
        return true;
      },
      loadNextSeq: () async => 5,
      saveNextSeq: (_) async {},
      webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
          throw StateError('no websocket in this test'),
    );

    try {
      await relay.connect();
    } catch (_) {}

    // A stale below-cursor straggler (seq 3) plus the real contiguous backlog
    // at/above the cursor (seqs 5,6,7) all sitting in the reorder buffer.
    relay.debugSeedReorderEntryForTest(
        seq: 3, msgId: 'n3stale', ciphertextB64: 'AA==');
    relay.debugSeedReorderEntryForTest(
        seq: 5, msgId: 'n5', ciphertextB64: 'AA==');
    relay.debugSeedReorderEntryForTest(
        seq: 6, msgId: 'n6', ciphertextB64: 'AA==');
    relay.debugSeedReorderEntryForTest(
        seq: 7, msgId: 'n7', ciphertextB64: 'AA==');

    await relay.pumpInbox(force: true);

    expect(delivered, containsAllInOrder(<String>['n5', 'n6', 'n7']),
        reason: 'buffered backlog from the cursor must drain in order');
    expect(delivered, isNot(contains('n3stale')),
        reason: 'stale below-cursor entry must be purged, not delivered');
    expect(relay.debugNextSeqForTest, 8);
    expect(relay.debugReorderBufferLengthForTest, 0,
        reason: 'stale below-cursor entry must be purged, not left to wedge');
  });

  // Regression for the DEEP-SLEEP MESSAGE LOSS (2026-07-14): when a device wakes
  // from deep sleep, a burst of WS-delivered messages fills the reorder buffer
  // with a transient hole (the missing seq's WS deliver was lost on the flaky
  // post-wake socket). The OLD code, after ONE fire-and-forget WS gap-fetch that
  // did not supply the hole, concluded the seq "no longer exists" and SKIPPED it
  // (`_nextSeq = minBuffered`) — but the seq was STILL on the relay (unacked), so
  // the message was permanently lost (the recipient saw the push but no message
  // in the chat). The FIX never advances the cursor on unconfirmed WS state: it
  // escalates to a reliable HTTP pump (the relay's complete MIN-clamped view),
  // which supplies the missing seq and delivers it in order.
  test('WS-drain gap escalates to a reliable HTTP pump instead of skipping a '
      'still-present seq (deep-sleep loss fix)', () async {
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();
    final delivered = <String>[];
    var pendingFetches = 0;

    // The relay STILL holds seq 5 (the hole) — exactly the case the old skip got
    // wrong. A from_seq=5 pump returns the whole contiguous run 5,6,7.
    final client = MockClient((req) async {
      final path = req.url.path;
      if (req.method == 'GET' && path.contains('/v1/pending')) {
        pendingFetches++;
        return http.Response(
          jsonEncode({
            'items': [
              {'seq': 5, 'msg_id': 'g5', 'ciphertext_b64': 'AA=='},
              {'seq': 6, 'msg_id': 'g6', 'ciphertext_b64': 'AA=='},
              {'seq': 7, 'msg_id': 'g7', 'ciphertext_b64': 'AA=='},
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });

    final relay = RelayClient(
      db: db,
      deviceId: 'self-device',
      selfProfileId: 'self-profile',
      deviceKeys: DeviceKeys.create(),
      wsUrl: Uri.parse('ws://example.test/ws'),
      httpBaseUrl: Uri.parse('https://example.test'),
      httpClient: client,
      identityKeyPairOverride: kp,
      onDelivered: ({required msgId, required ciphertextB64}) async {
        delivered.add(msgId);
        return true;
      },
      loadNextSeq: () async => 5,
      saveNextSeq: (_) async {},
      webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
          throw StateError('no websocket in this test'),
    );

    try {
      await relay.connect(); // seeds _nextSeq=5; WS attempt throws (caught)
    } catch (_) {}

    // WS-delivered burst: seqs 6 and 7 are buffered, but the floor (seq 5) is
    // missing — its WS deliver was lost on the post-wake socket.
    relay.debugSeedReorderEntryForTest(seq: 6, msgId: 'g6', ciphertextB64: 'AA==');
    relay.debugSeedReorderEntryForTest(seq: 7, msgId: 'g7', ciphertextB64: 'AA==');
    // Simulate the state AFTER the realtime WS gap-fetch already ran for seq 5
    // and the relay never supplied it (the lost fetchPending). The old code
    // would `gap_skipped from=5 to=6` here and lose g5.
    relay.debugLastGapSeqRequestedForTest = 5;

    await relay.debugDrainForTest();
    // The escalation fires an unawaited HTTP pump; let it complete + re-drain.
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(pendingFetches, greaterThanOrEqualTo(1),
        reason: 'the gap must escalate to a reliable HTTP pump, not skip');
    expect(delivered, contains('g5'),
        reason: 'the still-present seq must be recovered, never skipped/lost');
    expect(delivered, containsAll(<String>['g6', 'g7']),
        reason: 'the rest of the burst drains in order behind the recovered hole');
    expect(relay.debugNextSeqForTest, greaterThanOrEqualTo(8),
        reason: 'cursor advances only after the hole is genuinely delivered');
    expect(relay.debugReorderBufferLengthForTest, 0);
  });

  // Regression for the LIVENESS WATCHDOG: if a drain hangs on an await (stuck
  // DB / keystore / ratchet future), the single-flight lock must NOT stay held
  // forever. After the watchdog window a fresh drain force-releases the lock so
  // a retry (once the underlying issue clears) can make forward progress.
  test('stuck-drain watchdog force-releases the lock so a retry can progress',
      () async {
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();
    final delivered = <String>[];
    var calls = 0;
    final firstHang = Completer<bool>();

    // The relay keeps re-offering seq 5 until it is acked (production behavior).
    final client = MockClient((req) async {
      final path = req.url.path;
      if (req.method == 'GET' && path.contains('/v1/pending')) {
        return http.Response(
          jsonEncode({
            'items': [
              {'seq': 5, 'msg_id': 'w5', 'ciphertext_b64': 'AA=='},
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });

    final relay = RelayClient(
      db: db,
      deviceId: 'self-device',
      selfProfileId: 'self-profile',
      deviceKeys: DeviceKeys.create(),
      wsUrl: Uri.parse('ws://example.test/ws'),
      httpBaseUrl: Uri.parse('https://example.test'),
      httpClient: client,
      identityKeyPairOverride: kp,
      onDelivered: ({required msgId, required ciphertextB64}) async {
        calls++;
        if (calls == 1) return firstHang.future; // first apply hangs
        delivered.add(msgId);
        return true;
      },
      loadNextSeq: () async => 5,
      saveNextSeq: (_) async {},
      webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
          throw StateError('no websocket in this test'),
    );

    try {
      await relay.connect();
    } catch (_) {}
    relay.debugDrainWatchdogMs = 40; // shrink the 30 s window for the test

    // First pump: the drain applies seq 5 -> onDelivered hangs, stranding the
    // _isDraining lock. Do NOT await (it would never return).
    unawaited(relay.pumpInbox(force: true));

    // Past the watchdog window.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    // Second pump: the watchdog force-releases the stranded lock; seq 5 is
    // re-offered and onDelivered (call 2) now succeeds.
    await relay.pumpInbox(force: true);

    expect(delivered, contains('w5'),
        reason:
            'after the watchdog releases the lock, the retry must deliver');
    expect(relay.debugNextSeqForTest, greaterThanOrEqualTo(6));

    if (!firstHang.isCompleted) firstHang.complete(false); // cleanup
  });
}
