// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thermal governor for expensive GPU effects (2026-07-19, liquid glass).
///
/// iOS reports `ProcessInfo.thermalState`; when the device runs hot the OS is
/// already throttling the GPU, and a live refraction shader both looks worse
/// (dropped frames) and feeds the heat. [effectsAllowed] flips to false at
/// `serious`/`critical` and back to true when the device cools — surfaces
/// listen and swap to their classic (cheap) material live. Fail-open: if the
/// channel is unavailable (Android, tests, old runner), effects stay allowed
/// and only the compile-time flags gate them.
///
/// The native side (AppDelegate) streams the raw thermal state over
/// [_channelName]: 0 nominal, 1 fair, 2 serious, 3 critical.
class ThermalGuard {
  ThermalGuard._();

  static const String _channelName = 'secretly/thermal_state';
  static const EventChannel _channel = EventChannel(_channelName);

  /// True while GPU-heavy cosmetic effects may run. Never flips on Android or
  /// in tests (no stream → stays true).
  ///
  /// Only `critical` turns this off. A warm-but-working device must NOT lose
  /// the whole look: `onListen` delivers the CURRENT state immediately, so a
  /// phone merely warm from USB builds reports `serious` at launch — gating
  /// this at `serious` once made every glass surface vanish the moment the app
  /// started, because a phone merely warm from USB builds already reports it.
  /// That is now handled by requiring the device to stay cool for a while
  /// before the glass returns (see _applyThermalState), not by serving a
  /// half-quality tier in between.
  static final ValueNotifier<bool> effectsAllowed = ValueNotifier<bool>(true);

  /// Wall-clock ms since the device first reported a cool state while the
  /// glass was off — used to hold the return until it is really settled.
  static int? _coolSince;

  /// How long the device must stay cool before the glass comes back. Without
  /// it a phone hovering on the boundary flips the whole look on and off.
  static const int _cooldownMs = 20 * 1000;

  /// TWO STATES, NO MIDDLE (2026-07-20, owner's call).
  ///
  /// iOS thermalState: 0 nominal, 1 fair, 2 serious, 3 critical.
  ///   nominal / fair → the full liquid glass.
  ///   serious+       → the classic material, i.e. exactly the look the app
  ///                    had before liquid glass and the one Android still
  ///                    ships. It is cheap AND it is finished design, not a
  ///                    degraded stand-in.
  ///
  /// The intermediate tier (glass at reduced quality) is gone. It cost almost
  /// as much — `premium` is what selects the native Impeller path, so dropping
  /// it flattens the effect while still paying for a backdrop read — and it
  /// looked worse than either end. Better an honest switch between two good
  /// looks than a bad one in between.
  static void _applyThermalState(int state) {
    final hot = state >= 2;
    if (hot) {
      _coolSince = null;
      _set(false, state);
      return;
    }
    if (effectsAllowed.value) return; // already on, nothing to do
    final now = DateTime.now().millisecondsSinceEpoch;
    _coolSince ??= now;
    // Drop to classic immediately, but earn the way back: a device on the
    // boundary would otherwise flip the entire look every few seconds.
    if (now - _coolSince! >= _cooldownMs) _set(true, state);
  }

  static void _set(bool allowed, int state) {
    if (effectsAllowed.value == allowed) return;
    effectsAllowed.value = allowed;
    debugPrint('Sly/Diag: event=thermal.effects allowed=$allowed state=$state');
  }

  static StreamSubscription<dynamic>? _sub;

  /// Idempotent; call once early on iOS. Safe anywhere — errors leave the
  /// guard open.
  static void start() {
    if (_sub != null || !Platform.isIOS) return;
    try {
      _sub = _channel.receiveBroadcastStream().listen(
        (raw) {
          final state = raw is int ? raw : int.tryParse('$raw') ?? 0;
          _applyThermalState(state);
        },
        onError: (_) {
          // A broken stream must never disable effects permanently — fail open.
          _coolSince = null;
          effectsAllowed.value = true;
        },
      );
    } catch (_) {
      // Channel missing (old runner) — stay open.
    }
  }
}
