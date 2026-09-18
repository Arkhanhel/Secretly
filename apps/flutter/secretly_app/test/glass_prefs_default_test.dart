// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secretly_app/ui/liquid_glass_flags.dart';

// 2026-07-23: liquid glass ships OFF by default (matte bar) — the shader is the
// app's biggest GPU cost and ran the chat hot. Someone who explicitly turned it
// ON keeps it; only the untouched default is matte. These pin that so a future
// edit does not quietly re-enable glass for everyone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh install defaults to matte (glass OFF)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GlassPrefs.load(prefs);
    expect(GlassPrefs.enabled.value, isFalse,
        reason: 'no stored preference must mean matte, not glass');
  });

  test('a person who turned glass ON keeps it across load', () async {
    SharedPreferences.setMockInitialValues(
        {'liquid_glass_enabled_v1': true});
    final prefs = await SharedPreferences.getInstance();
    await GlassPrefs.load(prefs);
    expect(GlassPrefs.enabled.value, isTrue,
        reason: 'an explicit opt-in must survive the new default');
  });

  test('setEnabled persists and flips the live value', () async {
    // Start from a known matte state (load resets the static notifier) so the
    // flip below actually changes the value — setEnabled is a no-op when the
    // value already matches, and the static notifier leaks between tests.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GlassPrefs.load(prefs);
    expect(GlassPrefs.enabled.value, isFalse);

    await GlassPrefs.setEnabled(true);
    expect(GlassPrefs.enabled.value, isTrue);
    expect(prefs.getBool('liquid_glass_enabled_v1'), isTrue);
  });
}
