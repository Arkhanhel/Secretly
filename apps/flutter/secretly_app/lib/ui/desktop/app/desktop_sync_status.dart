// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Desktop-only relay connection / backfill status holder.
//
// PR4 (2026-05-19, SPRINT2_AUDIT §16): mobile is always foreground so it
// doesn't need a visible "connecting / syncing" affordance — when the
// phone is unlocked, the relay is healthy. Desktop is different: the app
// is closed and reopened many times a day, the OS suspends the WS during
// sleep, and `flutter run` cold-boots can take 1–3 seconds to reach the
// first WS `Welcome` frame. Without UI feedback the user assumes "broken".
//
// This file does NOT touch [AppController] internals — it observes the
// already-exposed [AppController.relayConnectionChanges] stream and
// exposes a `ValueListenable<DesktopSyncStatus>` for the banner widget.
//
// State machine:
//
//   ┌─────────────┐  WS connects                   ┌─────────────┐
//   │  connecting │ ──────────────────────────▶    │   syncing   │
//   └─────────────┘                                └──────┬──────┘
//          ▲                                              │
//          │ WS drops                                     │ kSyncSettleDelay
//          │                                              ▼
//   ┌─────────────┐                                ┌─────────────┐
//   │ reconnecting│ ◀─────  WS drops  ─────────    │    online   │
//   └─────────────┘                                └─────────────┘
//
// `connecting` is the cold-boot state. After the first WS `connected=true`
// we move through a brief `syncing` window (covers the time it takes the
// HTTP /v1/pending + WS `Welcome → FetchPending` paths to drain a 7-day
// mailbox) before settling on `online`. If the connection later drops we
// switch to `reconnecting` — but never back to `connecting`, because by
// then the user knows the app works.
//
// Mobile is unaffected: this file is only constructed from desktop
// widgets, and the underlying [AppController] streams are read-only.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/app_controller.dart';

/// Coarse relay/backfill phase shown in the desktop UI.
enum DesktopSyncPhase {
  /// Cold-boot — relay client not yet reported a connection.
  connecting,

  /// Connected; HTTP /v1/pending + WS FetchPending are still draining
  /// the per-device mailbox. We sit in this state for
  /// [DesktopSyncStatusController.kSyncSettleDelay] after the first
  /// `connected=true` event so the user sees a non-blank acknowledgement
  /// of "we're catching you up".
  syncing,

  /// Steady state.
  online,

  /// We were online and the WS dropped. Reconnect path is debounced via
  /// `_scheduleRelayReconnectKick` in [AppController].
  reconnecting,
}

/// Immutable snapshot. Compared by value in the controller's `notifyListeners`
/// gate so dependent widgets only rebuild on actual phase transitions.
@immutable
class DesktopSyncStatus {
  const DesktopSyncStatus({
    required this.phase,
    required this.changedAtMs,
  });

  final DesktopSyncPhase phase;

  /// Epoch ms at which we last entered [phase]. Used by the banner to
  /// fade in/out animations and to suppress flicker on reconnect storms.
  final int changedAtMs;

  static const DesktopSyncStatus initial = DesktopSyncStatus(
    phase: DesktopSyncPhase.connecting,
    changedAtMs: 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DesktopSyncStatus &&
          other.phase == phase &&
          other.changedAtMs == changedAtMs);

  @override
  int get hashCode => Object.hash(phase, changedAtMs);

  @override
  String toString() =>
      'DesktopSyncStatus(phase: $phase, changedAtMs: $changedAtMs)';
}

/// Owns the phase transitions. Construct once from
/// [DesktopProductionApp] (or whatever desktop shell wraps the
/// controller), call [dispose] on shutdown.
class DesktopSyncStatusController extends ChangeNotifier
    implements ValueListenable<DesktopSyncStatus> {
  DesktopSyncStatusController({required AppController controller})
      : _controller = controller {
    // Seed from whatever AppController reports right now. The stream
    // listener fires for future changes; this primes the initial state
    // so a controller already connected before we subscribed surfaces as
    // `syncing → online` rather than stuck in `connecting`.
    _value = controller.relayOnline
        ? DesktopSyncStatus(
            phase: DesktopSyncPhase.syncing,
            changedAtMs: DateTime.now().millisecondsSinceEpoch,
          )
        : DesktopSyncStatus.initial;
    _scheduleSettleIfNeeded();
    _sub = controller.relayConnectionChanges.listen(_onRelayConnChanged);
  }

  /// How long the banner sits in [DesktopSyncPhase.syncing] before
  /// fading to `online`. Picked to roughly cover the worst-case 7-day
  /// mailbox drain on a slow connection — the `_pumpTimer` runs every
  /// 1 s and `pumpInbox` pages 500 entries per HTTP round-trip, so
  /// 3 s is enough headroom for a typical 1–2 page backlog while still
  /// feeling snappy on a cold boot with no missed events.
  static const Duration kSyncSettleDelay = Duration(seconds: 3);

  // Held for future peer-to-device history sync (PR5) — when we ask
  // another of the user's own devices for a history dump we'll need to
  // call back into [AppController] to fan out the control message.
  // ignore: unused_field
  final AppController _controller;
  StreamSubscription<bool>? _sub;
  Timer? _settleTimer;
  DesktopSyncStatus _value = DesktopSyncStatus.initial;
  bool _everConnected = false;

  @override
  DesktopSyncStatus get value => _value;

  /// Manually push the banner back into the "syncing" state — called by
  /// the boot-time eager force-pump kicker in `main_desktop.dart` so the
  /// banner reflects the very-first cold-boot backfill cycle even if the
  /// WS happened to connect before this controller was constructed.
  void markSyncing() {
    _set(DesktopSyncPhase.syncing);
    _scheduleSettleIfNeeded();
  }

  void _onRelayConnChanged(bool connected) {
    if (connected) {
      _everConnected = true;
      _set(DesktopSyncPhase.syncing);
      _scheduleSettleIfNeeded();
    } else {
      // We only transition to `reconnecting` if we'd been online before.
      // Otherwise we stay in `connecting` so the cold-boot story stays
      // coherent: first thing the user sees is "Подключение…", not
      // "Переподключение…".
      _set(
        _everConnected
            ? DesktopSyncPhase.reconnecting
            : DesktopSyncPhase.connecting,
      );
      _cancelSettle();
    }
  }

  void _set(DesktopSyncPhase next) {
    if (_value.phase == next) return;
    _value = DesktopSyncStatus(
      phase: next,
      changedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  void _scheduleSettleIfNeeded() {
    if (_value.phase != DesktopSyncPhase.syncing) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(kSyncSettleDelay, () {
      _settleTimer = null;
      if (_value.phase == DesktopSyncPhase.syncing) {
        _set(DesktopSyncPhase.online);
      }
    });
  }

  void _cancelSettle() {
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _cancelSettle();
    super.dispose();
  }
}
