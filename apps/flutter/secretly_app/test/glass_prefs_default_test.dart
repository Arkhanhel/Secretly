// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secretly_app/ui/liquid_glass_flags.dart';

// 2026-07-23: liquid glass shipped OFF by default (the shader ran the chat hot).
// 2026-11-24 (owner, 1.9): ON by default on iPhone, measured by the heat log;
// thermal levels step the glass down (fair → balanced, serious → edge,
// critical → flat). Android stays matte by default — glass is iPhone-only.
// An explicit choice in Settings always wins over the default.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => GlassPrefs.debugDefaultIsIos = null);

  test('iPhone: a fresh install gets glass ON', () async {
    GlassPrefs.debugDefaultIsIos = true;
    SharedPreferences.setMockInitialValues({});
    await GlassPrefs.load(await SharedPreferences.getInstance());
    expect(GlassPrefs.enabled.value, isTrue);
  });

  test('🔴 Android: a fresh install stays matte (glass is iPhone-only)', () async {
    GlassPrefs.debugDefaultIsIos = false;
    SharedPreferences.setMockInitialValues({});
    await GlassPrefs.load(await SharedPreferences.getInstance());
    expect(GlassPrefs.enabled.value, isFalse);
  });

  test('iPhone: a person who turned glass OFF keeps it off', () async {
    GlassPrefs.debugDefaultIsIos = true;
    SharedPreferences.setMockInitialValues({'liquid_glass_enabled_v1': false});
    await GlassPrefs.load(await SharedPreferences.getInstance());
    expect(GlassPrefs.enabled.value, isFalse,
        reason: 'an explicit opt-out must survive the new default');
  });

  test('a person who turned glass ON keeps it across load', () async {
    GlassPrefs.debugDefaultIsIos = false;
    SharedPreferences.setMockInitialValues({'liquid_glass_enabled_v1': true});
    await GlassPrefs.load(await SharedPreferences.getInstance());
    expect(GlassPrefs.enabled.value, isTrue);
  });

  test('setEnabled persists and flips the live value', () async {
    GlassPrefs.debugDefaultIsIos = false;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GlassPrefs.load(prefs);
    expect(GlassPrefs.enabled.value, isFalse);
    await GlassPrefs.setEnabled(true);
    expect(GlassPrefs.enabled.value, isTrue);
    expect(prefs.getBool('liquid_glass_enabled_v1'), isTrue);
  });
}
