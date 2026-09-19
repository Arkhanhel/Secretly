// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desktop-only Touch ID / device-biometric app lock.
///
/// Independent from mobile's [AppSecurityManager] on purpose: persists state
/// under desktop-specific SharedPreferences keys so the published mobile
/// build is untouched. The mobile flow already manages its own lock scopes
/// through [AppSecurityManager] — desktop just needs a thin Touch ID gate
/// on the macOS production build (Touch ID Mac models).
///
/// Lifecycle:
/// - [init] loads the enabled flag + grace-seconds and probes biometric
///   support. If enabled, the app starts locked.
/// - [setWindowFocused] is called by the window manager. When the window
///   loses focus and lock is enabled, a grace timer is started; when it
///   fires, the app transitions to locked. Re-focusing within the grace
///   period cancels the timer.
/// - [requestUnlock] runs the platform biometric prompt. On success, the
///   lock is cleared.
///
/// Build is OS-aware: outside macOS / Windows / Linux the service stays
/// inert (init returns immediately), so the mobile entry point is a no-op
/// even if it ever instantiates this class.
class DesktopAppLockService {
  DesktopAppLockService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  static const String _prefsEnabledKey = 'desktop_app_lock_enabled_v1';
  static const String _prefsGraceKey = 'desktop_app_lock_grace_seconds_v1';
  static const int _defaultGraceSeconds = 60;

  final LocalAuthentication _auth;

  final ValueNotifier<bool> locked = ValueNotifier<bool>(false);
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  final ValueNotifier<int> graceSeconds =
      ValueNotifier<int>(_defaultGraceSeconds);
  final ValueNotifier<bool> biometricSupported = ValueNotifier<bool>(false);

  /// True when the platform authentication service is structurally missing
  /// (no `local_auth` implementation), as opposed to the user simply failing
  /// or cancelling a prompt.
  ///
  /// F-17: this distinction matters because an armed lock plus an absent
  /// authenticator is an unopenable app. [setEnabled] refuses to arm in that
  /// situation; this flag lets the lock screen explain the real cause instead
  /// of repeating a generic "could not verify" forever.
  final ValueNotifier<bool> unlockUnavailable = ValueNotifier<bool>(false);

  SharedPreferences? _prefs;
  Timer? _idleTimer;
  bool _initialized = false;
  bool _unlockInProgress = false;

  bool get _isDesktopOs =>
      !kIsWeb &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  Future<void> init({SharedPreferences? prefs}) async {
    if (!_isDesktopOs || _initialized) return;
    _prefs = prefs ?? await SharedPreferences.getInstance();
    enabled.value = _prefs?.getBool(_prefsEnabledKey) ?? false;
    final storedGrace = _prefs?.getInt(_prefsGraceKey);
    if (storedGrace != null) {
      graceSeconds.value = storedGrace.clamp(0, 3600);
    }
    biometricSupported.value = await _probeBiometricSupport();
    locked.value = enabled.value;
    _initialized = true;
  }

  Future<bool> _probeBiometricSupport() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> refreshBiometricSupport() async {
    if (!_isDesktopOs) return;
    biometricSupported.value = await _probeBiometricSupport();
  }

  /// Arms or disarms the lock. Returns true when the request was applied.
  ///
  /// F-17 (hard-lockout prevention): arming REQUIRES a successful
  /// authentication first. Without that check a user on a machine whose
  /// authentication service is unavailable could switch the lock on and then
  /// never get back in — the app would be bricked with no recourse, because
  /// unlocking is deliberately fail-closed (principle P-3: security features
  /// never fall open). Proving the unlock path works before arming removes the
  /// unopenable state entirely, rather than adding a bypass that would weaken
  /// the lock for everyone.
  ///
  /// Disarming is always allowed — it never needs to be gated.
  /// [armReason] — что система напишет в своём окне подтверждения.
  /// Подпись приходит СНАРУЖИ: служба не знает языка окна, а системное
  /// окно показывается человеку.
  Future<bool> setEnabled(bool value, {required String armReason}) async {
    if (!_isDesktopOs) return false;

    if (!value) {
      enabled.value = false;
      await _prefs?.setBool(_prefsEnabledKey, false);
      _cancelIdleTimer();
      locked.value = false;
      return true;
    }

    // Arming: prove the user can actually get back in.
    final proven = await _authenticate(reason: armReason);
    if (!proven) return false;

    enabled.value = true;
    await _prefs?.setBool(_prefsEnabledKey, true);
    locked.value = true;
    return true;
  }

  Future<void> setGraceSeconds(int seconds) async {
    if (!_isDesktopOs) return;
    final clamped = seconds.clamp(0, 3600);
    graceSeconds.value = clamped;
    await _prefs?.setInt(_prefsGraceKey, clamped);
  }

  void lock() {
    if (!_isDesktopOs || !enabled.value) return;
    _cancelIdleTimer();
    locked.value = true;
  }

  void setWindowFocused(bool focused) {
    if (!_isDesktopOs || !enabled.value) return;
    if (focused) {
      _cancelIdleTimer();
      return;
    }
    if (locked.value) return;
    _scheduleIdleLock();
  }

  void _scheduleIdleLock() {
    _cancelIdleTimer();
    final delay = Duration(seconds: graceSeconds.value);
    if (delay == Duration.zero) {
      locked.value = true;
      return;
    }
    _idleTimer = Timer(delay, () {
      _idleTimer = null;
      if (enabled.value) locked.value = true;
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Runs the OS authentication prompt once.
  ///
  /// `biometricOnly: false` is deliberate: it lets macOS fall back to the
  /// device password, so a Mac without Touch ID can still authenticate.
  /// A [MissingPluginException] means the platform has no authenticator at
  /// all — recorded in [unlockUnavailable] so callers can distinguish
  /// "user declined" from "this machine cannot ever authenticate".
  Future<bool> _authenticate({required String reason}) async {
    if (_unlockInProgress) return false;
    _unlockInProgress = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
      if (ok) unlockUnavailable.value = false;
      return ok;
    } on MissingPluginException {
      unlockUnavailable.value = true;
      return false;
    } on PlatformException {
      // A platform error is a failed attempt, not a missing authenticator —
      // do not mark the machine as permanently unable to authenticate.
      return false;
    } finally {
      _unlockInProgress = false;
    }
  }

  /// Triggers the unlock prompt. Returns true on success.
  /// Safe to call when not enabled (no-op) or already unlocked.
  Future<bool> requestUnlock({required String reason}) async {
    if (!_isDesktopOs) return true;
    if (!enabled.value || !locked.value) return true;
    final ok = await _authenticate(reason: reason);
    if (ok) {
      locked.value = false;
      _cancelIdleTimer();
    }
    return ok;
  }

  void dispose() {
    _cancelIdleTimer();
    locked.dispose();
    enabled.dispose();
    graceSeconds.dispose();
    biometricSupported.dispose();
    unlockUnavailable.dispose();
  }
}
