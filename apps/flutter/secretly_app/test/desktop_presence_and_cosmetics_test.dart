// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/services/desktop_window_activity.dart';

/// D-2 and D-5 — two desktop defects that a human cannot spot by looking at
/// the screen, because both are about what the app does when NOBODY is
/// looking at it.
void main() {
  group('D-2 presence follows window visibility', () {
    /// Mirrors how the app root wires presence: one listener on the
    /// visibility signal, NOT a call inside each window callback. That shape
    /// is the point — the tray icon and tray menu show the window by calling
    /// `windowManager.show()` directly, and window_manager has no "shown"
    /// event, so per-callback wiring would silently miss those paths and leave
    /// the user reported as offline while the window is on screen.
    test('every visibility change reaches the listener', () {
      final activity = DesktopWindowActivity();
      addTearDown(activity.dispose);

      final published = <bool>[];
      void listener() => published.add(activity.visible.value);
      activity.visible.addListener(listener);
      addTearDown(() => activity.visible.removeListener(listener));

      activity.onHidden();
      activity.onShown();
      activity.onHidden();

      expect(published, [false, true, false]);
    });

    test('a repeated state does not re-publish', () {
      final activity = DesktopWindowActivity();
      addTearDown(activity.dispose);

      var notifications = 0;
      void listener() => notifications++;
      activity.visible.addListener(listener);
      addTearDown(() => activity.visible.removeListener(listener));

      activity.onHidden();
      activity.onHidden();
      activity.onHidden();

      expect(notifications, 1,
          reason: 'hiding an already-hidden window must not spam presence');
    });

    test('starts visible — the app launches on screen', () {
      final activity = DesktopWindowActivity();
      addTearDown(activity.dispose);
      expect(activity.visible.value, isTrue);
    });
  });

  group('D-5 animated cosmetics honour the user setting', () {
    setUp(DesktopUiPrefs.resetForTest);

    test('defaults to animating', () {
      expect(DesktopUiPrefs.animatePeerCosmetics.value, isTrue);
    });

    test('mirrors the controller value', () {
      DesktopUiPrefs.syncPeerCosmeticAnim(false);
      expect(DesktopUiPrefs.animatePeerCosmetics.value, isFalse);
      DesktopUiPrefs.syncPeerCosmeticAnim(true);
      expect(DesktopUiPrefs.animatePeerCosmetics.value, isTrue);
    });

    test('an unchanged value notifies nobody', () {
      var notifications = 0;
      void listener() => notifications++;
      DesktopUiPrefs.animatePeerCosmetics.addListener(listener);
      addTearDown(
          () => DesktopUiPrefs.animatePeerCosmetics.removeListener(listener));

      // The app root pushes this on EVERY controller `changed` tick, which is
      // frequent — a no-op write must not cascade into rebuilds.
      DesktopUiPrefs.syncPeerCosmeticAnim(true);
      DesktopUiPrefs.syncPeerCosmeticAnim(true);
      DesktopUiPrefs.syncPeerCosmeticAnim(true);

      expect(notifications, 0);
    });
  });

  group('D-1 the language picker stays hidden until strings are translated',
      () {
    test('the localisation flag is off', () {
      // The desktop tree still carries ~800 hardcoded Russian literals against
      // a handful of l10n lookups. Offering a language picker in that state
      // switches the locale for real but translates almost nothing, which
      // reads as a broken app rather than an untranslated one. Flip this only
      // together with the ARB work (TZ §5).
      expect(kDesktopUiLocalized, isFalse,
          reason: 'flip only when lib/ui/desktop strings are actually in ARB');
    });
  });
}
