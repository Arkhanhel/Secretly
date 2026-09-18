// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Windowed-burst gate for undecryptable-wire NACKs (Fix 1a, 2026-07-24).
///
/// WHY THIS EXISTS — field trace 2026-07-24 (docs/BUG_AUDIT.md §"offline→online
/// ratchet desync"): after an offline→online cycle a peer accumulates a BACKLOG
/// of undecryptable wires. The old gate emitted exactly ONE NACK per peer device
/// per [windowMs] (10 min), on the premise that "one NACK makes the sender
/// re-send EVERYTHING undelivered". That premise stopped holding on 2026-07-23,
/// when the sender's recovery was narrowed to re-send the SPECIFIC msg_id each
/// NACK names (a message the peer already marked delivered/read but can no
/// longer decrypt is invisible to the blanket "re-send all `sent`" sweep). So a
/// backlog of N dead wires needs N NACKs — and the one-per-window gate starved
/// every wire but the first. The live trace showed the smoking gun: 33
/// `recovery.declined reason=device_gate` and 0 NACKs actually emitted in five
/// minutes → the backlog never recovered ("не все, и долго").
///
/// This gate instead allows up to [burstPerWindow] DISTINCT-msg_id NACKs per
/// device per [windowMs], so a multi-message backlog recovers inside a single
/// window instead of one wire per 10 minutes. The anti-storm intent of the
/// original gate is preserved by the ceiling: the sender's per-device
/// re-entrancy guard (`_resendUndeliveredInFlight`) collapses overlapping
/// blanket sweeps and the reset-ping is separately device-debounced, so even at
/// the ceiling a burst is bounded to [burstPerWindow] targeted re-encrypts plus
/// at most one blanket sweep and one reset ping.
///
/// Token accounting: [hasRoom] only REPORTS whether the current window has a
/// free slot (rolling the window over when [windowMs] has elapsed). A slot is
/// spent by [consume] — which the caller invokes ONLY after it has confirmed a
/// genuinely fresh NACK (i.e. the quarantine row was claimed for the first time
/// in the 24 h re-claim window). This is what keeps the replay sweep — which
/// re-walks the SAME parked rows every run — from burning the whole burst on
/// rows it already NACKed: an already-claimed row never reaches [consume].
class NackBurstGate {
  NackBurstGate({required this.windowMs, required this.burstPerWindow})
    : assert(windowMs > 0),
      assert(burstPerWindow > 0);

  /// Length of the rolling window in milliseconds.
  final int windowMs;

  /// Maximum number of NACKs emitted to a single device within one window.
  final int burstPerWindow;

  final Map<String, int> _windowStartMsByDevice = <String, int>{};
  final Map<String, int> _countInWindowByDevice = <String, int>{};

  /// True iff [dev] has a free slot right now: no window has opened yet, the
  /// open window has elapsed, or it is open with fewer than [burstPerWindow]
  /// slots spent. Side-effect FREE — probing never spends or rolls anything
  /// (the replay sweep probes the same backlog every run); [consume] is what
  /// opens/rolls the window and spends a slot.
  bool hasRoom(String dev, int nowMs) {
    final windowStart = _windowStartMsByDevice[dev];
    if (windowStart == null) return true; // no NACK to this device yet
    if (nowMs - windowStart >= windowMs) return true; // window elapsed
    return (_countInWindowByDevice[dev] ?? 0) < burstPerWindow;
  }

  /// Spend one slot for [dev], anchoring a fresh window at [nowMs] if none is
  /// open or the open one has elapsed. Call exactly once per NACK actually
  /// emitted, after [hasRoom] returned true and the wire was confirmed fresh.
  /// Bounds its own memory so a peer cycling device ids can't grow the maps
  /// without limit.
  void consume(String dev, int nowMs) {
    final windowStart = _windowStartMsByDevice[dev];
    if (windowStart == null || nowMs - windowStart >= windowMs) {
      // Open a fresh window anchored at this NACK.
      _windowStartMsByDevice[dev] = nowMs;
      _countInWindowByDevice[dev] = 1;
    } else {
      _countInWindowByDevice[dev] = (_countInWindowByDevice[dev] ?? 0) + 1;
    }
    if (_windowStartMsByDevice.length > 256) {
      final cutoff = nowMs - 10 * windowMs;
      _windowStartMsByDevice.removeWhere((_, ts) => ts < cutoff);
      _countInWindowByDevice.removeWhere(
        (dev, _) => !_windowStartMsByDevice.containsKey(dev),
      );
    }
  }

  /// Test-only: how many slots [dev] has spent in its current window.
  int debugCountFor(String dev) => _countInWindowByDevice[dev] ?? 0;
}
