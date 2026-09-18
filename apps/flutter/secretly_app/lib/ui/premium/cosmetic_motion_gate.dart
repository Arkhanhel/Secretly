// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Telegram-style motion gate: cosmetic frame animations HOLD their current
/// texture while a list is flinging. Screens report ballistic scroll activity
/// (ScrollUpdateNotification with dragDetails == null) via
/// [noteBallisticScroll]; the frame-atlas ticker skips publishing new textures
/// until ~120 ms after the last report. Time-based → no per-scrollable state,
/// self-healing, auto-resumes. Finger-drags (slow browsing) keep animating —
/// only flings freeze, where the eye can't track the ring anyway and every
/// saved blit goes to scroll frames.
class CosmeticMotionGate {
  CosmeticMotionGate._();

  static const Duration _holdAfterBallistic = Duration(milliseconds: 120);
  static Duration _lastBallistic = Duration.zero - _holdAfterBallistic;

  /// Cheap enough to call for every scroll notification.
  static void noteBallisticScroll() {
    _lastBallistic = _now();
  }

  static bool get holdAnimations =>
      _now() - _lastBallistic < _holdAfterBallistic;

  static Duration _now() =>
      Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
}
