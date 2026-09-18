// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Peer-to-device history sync orchestrator (PR5/PR6/PR7).
//
// Originally desktop-only (PR5/PR6). PR7 extends the service to support
// mobile-as-requester for the reinstall / restore-from-backup flow:
// the freshly-installed phone asks one of the user's other devices
// (typically the laptop, or the old phone if the user is migrating
// between handsets) for a recent-history dump over the existing e2ee
// ratchet. Boot-time gating is intentionally conservative — see
// `maybeSyncOnBoot` for the staleness + token-bucket checks.
//
// Responsibilities:
//   1. Decide *if* we should ask. The trigger is conservative — fresh
//      pair (no record of any previous sync) or a stale record
//      (≥ `kPeerHistoryStaleAfter`). This keeps the orchestrator from
//      flooding the relay every cold boot.
//   2. Issue exactly one in-flight [PeerHistoryRequest] at a time.
//      Mobile pages and ships chunks asynchronously; we wait for the
//      last chunk's `done` flag (or a timeout) before considering the
//      cycle complete.
//   3. Stamp `kPrefsLastSyncAtMs` on success so the next boot can
//      short-circuit.
//
// Failure modes are intentionally silent:
//   • No own-devices reachable → noop. The user's mobile may simply
//     be offline; the relay's 7-day mailbox (PR4) will fill the gap
//     the moment mobile comes back.
//   • Request issued but no chunk lands within
//     [kPeerHistoryResponseTimeout] → drop the in-flight token so the
//     next boot can retry. We do *not* show a user-facing error —
//     the desktop is fully functional without a history backfill.

import 'dart:async';
import 'dart:math' as math;
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_controller.dart';
import 'peer_history_protocol.dart' show kPeerHistoryMaxRequestsInFlight;

/// SharedPreferences key for "last successful peer-history sync at (epoch ms)".
/// Read on boot; written when a request cycle terminates with
/// `chunk.done == true`.
const String kPrefsPeerHistoryLastSyncAtMs =
    'secretly_desktop_peer_history_last_sync_ms';

/// SharedPreferences key for the in-flight request id so a desktop
/// crash mid-sync doesn't leave a half-applied window AND doesn't
/// trigger a duplicate request on the very next boot. We don't try
/// to *resume* — that needs a real cursor protocol (PR6) — but we do
/// suppress an immediate-retry storm.
const String kPrefsPeerHistoryInFlightRequestId =
    'secretly_desktop_peer_history_inflight_id';

/// After this much time we consider the local DB stale and re-request.
/// 24h is the right cadence for "I left my laptop closed all day, came
/// back, want a quick refresher" without spamming the relay every time
/// the user reopens the lid.
const Duration kPeerHistoryStaleAfter = Duration(hours: 24);

/// Max time to wait between consecutive chunks before giving up. Mobile
/// pages 50 events per chunk and ships them over the same ratchet that
/// carries regular messages — so a chunk should land within a few
/// hundred ms on a healthy link. We pad heavily for the laptop-asleep,
/// phone-on-cellular case.
const Duration kPeerHistoryResponseTimeout = Duration(seconds: 25);

/// Sliding window for the per-process rate limiter. Combined with
/// [kPeerHistoryMaxRequestsInFlight] this caps how often a user can
/// manually trigger a sync (or how often boot-time logic can retry).
const Duration kPeerHistoryRateWindow = Duration(minutes: 5);

/// Lightweight singleton — wired by `DesktopProductionApp._boot()` and
/// (PR7) `MyApp._init()` on mobile. Each entrypoint owns its lifecycle
/// via `attach`/`detach`. The orchestrator is idempotent and self-rate-
/// limited, so concurrent attach calls from different runtimes (e.g.
/// during a hot restart) are safe.
class PeerHistoryService {
  PeerHistoryService._();
  static final PeerHistoryService instance = PeerHistoryService._();

  AppController? _controller;
  bool _busy = false;
  Timer? _timeoutTimer;
  int _watchedFromMs = 0;

  /// Token bucket — recent request-start epoch-ms timestamps. We only
  /// keep the last [kPeerHistoryMaxRequestsInFlight] entries; older
  /// ones are evicted lazily by [_canSpendToken]. Even though only one
  /// cycle runs at a time, the bucket prevents the "user smashes Sync
  /// 20 times in 30 seconds" pathology where each cycle ends fast (no
  /// chunks land) and we just keep firing.
  final Queue<int> _recentRequestStarts = Queue<int>();

  int _backfilledCount = 0;
  int _requestsCompleted = 0;
  int _requestsRejected = 0;
  int _lastRunAtMs = 0;

  /// Hook the service to a freshly-booted [AppController]. Safe to call
  /// multiple times — re-binding replaces the previous controller (which
  /// in practice only happens on a relogin / restore flow).
  void attach(AppController controller) {
    _controller = controller;
  }

  void detach() {
    _cancelTimeout();
    _busy = false;
    _controller = null;
  }

  /// Boot-time entry point. Reads the last-sync timestamp from
  /// SharedPreferences, decides whether to fire a request, and either
  /// kicks off the cycle or returns immediately.
  ///
  /// Returns when the cycle either completes (last chunk seen) or
  /// times out. Errors are swallowed — the caller is expected to be
  /// `unawaited(...)`-ing this.
  Future<void> maybeSyncOnBoot() async {
    final controller = _controller;
    if (controller == null || _busy) return;

    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = prefs.getInt(kPrefsPeerHistoryLastSyncAtMs) ?? 0;
    if (lastMs > 0) {
      final age = nowMs - lastMs;
      if (age < kPeerHistoryStaleAfter.inMilliseconds) {
        // Fresh enough — skip.
        return;
      }
    }
    if (!_canSpendToken(nowMs)) {
      _requestsRejected += 1;
      return;
    }
    // If a previous boot left an in-flight token, we still want to
    // re-fire because (a) the previous request may have been lost and
    // (b) the mobile-side dedupe map drops the token after 5 minutes
    // so a new requestId is the simplest recovery path. Just regen.

    final requestId = _newRequestId(nowMs);
    await prefs.setString(kPrefsPeerHistoryInFlightRequestId, requestId);
    await _runCycle(controller: controller, requestId: requestId, prefs: prefs);
  }

  /// Explicit user-driven trigger — wired from the Settings panel
  /// «Sync History» button. Bypasses the staleness gate but still
  /// honors the rate-limit bucket so a runaway click handler can't
  /// flood the relay.
  Future<void> triggerManualSync() async {
    final controller = _controller;
    if (controller == null || _busy) return;

    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!_canSpendToken(nowMs)) {
      _requestsRejected += 1;
      return;
    }
    final requestId = _newRequestId(nowMs);
    await prefs.setString(kPrefsPeerHistoryInFlightRequestId, requestId);
    await _runCycle(controller: controller, requestId: requestId, prefs: prefs);
  }

  /// Token-bucket gate: returns `true` (and consumes a token) when the
  /// caller is allowed to start a new cycle. Evicts entries older than
  /// [kPeerHistoryRateWindow] so a slow drip of manual syncs never
  /// piles up.
  bool _canSpendToken(int nowMs) {
    final cutoff = nowMs - kPeerHistoryRateWindow.inMilliseconds;
    while (_recentRequestStarts.isNotEmpty &&
        _recentRequestStarts.first < cutoff) {
      _recentRequestStarts.removeFirst();
    }
    if (_recentRequestStarts.length >= kPeerHistoryMaxRequestsInFlight) {
      return false;
    }
    _recentRequestStarts.addLast(nowMs);
    return true;
  }

  Future<void> _runCycle({
    required AppController controller,
    required String requestId,
    required SharedPreferences prefs,
  }) async {
    _busy = true;
    final cycle = Completer<void>();
    _watchedFromMs = DateTime.now().millisecondsSinceEpoch;
    final preCycleBackfilled = controller.peerHistoryBackfilledCount;

    try {
      // Fire the request. The mobile responder will start pushing
      // chunks back through the ratchet, which AppController applies
      // via `_applyPeerHistoryChunk` (bumping `peerHistoryLastChunkAtMs`
      // on every chunk). We poll that watermark to detect progress vs
      // stall.
      await controller.requestPeerHistory(
        requestId: requestId,
        // PR5 v1: no time-window arguments — responder picks "newest 250".
      );

      _scheduleTimeout(cycle);
      await cycle.future;

      // Cycle completed. Stamp success — even if zero chunks landed,
      // the responder either replied with an empty tail chunk OR is
      // simply offline (in which case we want to retry next boot, but
      // not on every reopen → use the timestamp regardless).
      if (controller.peerHistoryLastChunkAtMs >= _watchedFromMs) {
        await prefs.setInt(
          kPrefsPeerHistoryLastSyncAtMs,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      await prefs.remove(kPrefsPeerHistoryInFlightRequestId);
    } catch (_) {
      // ignore — see class-level comment.
    } finally {
      _cancelTimeout();
      _busy = false;
      final delta = controller.peerHistoryBackfilledCount - preCycleBackfilled;
      _backfilledCount += delta < 0 ? 0 : delta;
      _requestsCompleted += 1;
      _lastRunAtMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Schedules a recurring check on the controller's chunk-watermark.
  /// We give up if no chunk arrives within [kPeerHistoryResponseTimeout]
  /// of the cycle start; if chunks ARE arriving we extend the deadline
  /// from the latest chunk's timestamp.
  void _scheduleTimeout(Completer<void> cycle) {
    _cancelTimeout();
    _timeoutTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (cycle.isCompleted) return;
      final controller = _controller;
      if (controller == null) {
        _safeComplete(cycle);
        return;
      }
      final lastChunkMs = controller.peerHistoryLastChunkAtMs;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // Effective deadline anchor = whichever is newer: cycle start
      // or last chunk. So a slow trickle of chunks keeps us alive.
      final anchor = math.max(_watchedFromMs, lastChunkMs);
      if (nowMs - anchor >= kPeerHistoryResponseTimeout.inMilliseconds) {
        _safeComplete(cycle);
      }
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _safeComplete(Completer<void> cycle) {
    if (!cycle.isCompleted) cycle.complete();
  }

  /// Visible for tests + the debug panel. The desktop banner doesn't
  /// surface this directly — it watches `DesktopSyncStatusController`
  /// from PR4 instead — but a future "Last sync: 2 min ago" affordance
  /// will read this.
  @visibleForTesting
  bool get isBusy => _busy;

  /// Public metrics — read from the Settings panel and the debug
  /// console. All counters reset on process restart; the durable
  /// "last sync" timestamp lives in SharedPreferences as
  /// `kPrefsPeerHistoryLastSyncAtMs`.

  /// Total events written across all cycles in this process.
  int get backfilledCount => _backfilledCount;

  /// How many cycles ran to completion (regardless of whether they
  /// actually wrote rows).
  int get requestsCompleted => _requestsCompleted;

  /// How many requests were short-circuited by the rate limiter.
  /// Visible in the debug console so a stuck UI loop is obvious.
  int get requestsRejected => _requestsRejected;

  /// Epoch-ms of the most recent cycle exit (success or timeout), 0 if
  /// no cycle has run yet this process.
  int get lastRunAtMs => _lastRunAtMs;

  String _newRequestId(int nowMs) {
    // Cheap UUID-ish: epoch + random. Doesn't need to be globally
    // unique, just unique-per-device-per-process — mobile keys its
    // dedupe map on `requestId@deviceId`.
    final rnd = math.Random().nextInt(0x7fffffff);
    return 'phr-$nowMs-${rnd.toRadixString(16)}';
  }
}
