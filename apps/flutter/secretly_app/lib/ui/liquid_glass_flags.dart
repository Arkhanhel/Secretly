// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Telegram-style "liquid glass" bottom navigation bar — iOS ONLY.
///
/// [kLiquidGlassNavBar] is the master KILL-SWITCH. Flip it to `false` for an
/// INSTANT rollback to the classic BackdropFilter bar — nothing else needs to
/// change (main.dart skips the shader init/wrap, and the shell renders the
/// original bar). Android never enters the glass path regardless of the flag
/// (owner's decision, spike V4): every gate is `kLiquidGlassNavBar &&
/// Platform.isIOS`.
///
/// Runtime safety net on top of the flag: [ThermalGuard] drops the shell back
/// to the classic bar live while the device reports a serious/critical thermal
/// state, and returns to glass when it cools. The classic bar is kept
/// byte-identical, so both switches are visually safe.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'thermal_guard.dart';
import 'widgets/frosted_header_island.dart';

/// When true (iOS only), the bottom nav bar uses the `liquid_glass_widgets`
/// shader glass and the app is wrapped with the adaptive-quality scope
/// (benchmarks the device at startup and steps quality down on weaker GPUs).
/// false = classic bar everywhere.
const bool kLiquidGlassNavBar = true;

/// THE glass recipe — the LENS dialed in BY THE OWNER on the on-device
/// playground (2026-07-19, build 334): thickness 47 / refraction 1.95 /
/// chromatic 0.40 / saturation 1.33, edge light pulled to near-zero (the
/// "ободки/блики" were the shader's own rim light) and NO specular-stroke
/// painters. Only the TINT changes with theme:
///   dark  → grey plate (glassColor 0x4D414141), the owner-approved nav bar;
///   light → ~55% white lightening (0x8CFFFFFF) so the black icons/labels the
///           light theme paints on top stay legible over any wallpaper.
LiquidGlassSettings secretlyIslandGlass(Brightness brightness) {
  const lens = (
    visibility: 0.39,
    thickness: 47.0,
    blur: 4.1,
    chromaticAberration: 0.15,
    refractiveIndex: 1.95,
    lightIntensity: 0.06,
    ambientStrength: 0.0,
    glowIntensity: 0.0,
    saturation: 1.33,
  );
  return LiquidGlassSettings(
    visibility: lens.visibility,
    thickness: lens.thickness,
    blur: lens.blur,
    chromaticAberration: lens.chromaticAberration,
    refractiveIndex: lens.refractiveIndex,
    lightIntensity: lens.lightIntensity,
    ambientStrength: lens.ambientStrength,
    glowIntensity: lens.glowIntensity,
    saturation: lens.saturation,
    lightAngle: 128 * math.pi / 180,
    glassColor: brightness == Brightness.dark
        ? const Color(0x4D414141)
        : const Color(0x8CFFFFFF),
  );
}

/// The nav-bar's floating selection lens WITHOUT refraction — the same grey oval
/// (identical tint / blur / size) but light passes straight through it
/// (refractiveIndex 1.0, no chromatic split), so it can no longer bend the left
/// edge of a long label like «Контакты» / «Настройки» when it sits still on a
/// tab. The full [secretlyIslandGlass] lens is used only WHILE the pill is
/// sliding between tabs; at rest the bar swaps to this flat one (Telegram-style).
LiquidGlassSettings secretlyIslandLensFlat(Brightness brightness) {
  final refractive = secretlyIslandGlass(brightness);
  return LiquidGlassSettings(
    visibility: refractive.visibility,
    thickness: refractive.thickness,
    blur: refractive.blur,
    // The three things that let the pill mark the glyphs even when it is NOT
    // magnifying: chromatic split, refraction, AND the shader's own rim light.
    // The live lens keeps a faint rim (0.06); at rest that rim still painted the
    // edge of a letter touching the pill white (field report: «н» half-white over
    // purple labels). Pull ALL of them to zero so the flat oval is inert — just
    // the grey tint and the background blur, nothing that touches the glyphs.
    chromaticAberration: 0.0,
    refractiveIndex: 1.0,
    lightIntensity: 0.0,
    ambientStrength: 0.0,
    glowIntensity: 0.0,
    saturation: refractive.saturation,
    lightAngle: refractive.lightAngle,
    glassColor: refractive.glassColor,
  );
}

/// User-facing on/off switch for the liquid glass, persisted across launches.
///
/// The kill-switch [kLiquidGlassNavBar] is a compile-time decision for the
/// whole build; this is the per-person one. Some people prefer the plain
/// material, and on a device that runs hot it is a real remedy rather than a
/// preference — so it belongs in Settings, not in a rebuild.
///
/// Runtime, not `const`, on purpose: the geometry follows the look. The two
/// bars have different footprints (see [bottomBarFootprint]), so a switch that
/// only changed the material would leave every FAB and reserved inset sized for
/// the other one.
class GlassPrefs {
  const GlassPrefs._();

  static const String _prefsKey = 'liquid_glass_enabled_v1';

  /// Listened to at the app root, so flipping it rebuilds everything at once
  /// instead of leaving half the screen on the old material.
  ///
  /// Default OFF (2026-07-23, owner's call): the shader glass is the biggest GPU
  /// cost in the app and made the chat run hot on real devices. It is a premium
  /// look people can opt INTO in Settings; the plain matte bar ships by default
  /// so the app stays cool out of the box. A person who already turned it ON
  /// (an explicit `true` in prefs) keeps it — only the untouched default flips.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static Future<void> load(SharedPreferences prefs) async {
    enabled.value = prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    if (enabled.value == value) return;
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // The live value already applied; persistence is best-effort.
    }
  }
}

/// Footprint of the bottom navigation bar, measured from the screen bottom.
///
/// The two bars sit differently: the classic bar fills `viewPadding.bottom +
/// 84`, while the glass pill is 64 tall and floats OVER the home indicator, so
/// it ignores the inset entirely. Anything positioned above the bar has to
/// account for that or the gap silently differs per platform.
double bottomBarFootprint(BuildContext context) =>
    (liquidGlassIslandsEnabled && ThermalGuard.effectsAllowed.value)
    ? 84.0
    : MediaQuery.of(context).viewPadding.bottom + 84.0;

/// Gap between the top of the bottom bar and a floating action button.
///
/// ONE constant for both platforms (2026-07-20): the iOS FAB used a hardcoded
/// 88 from the screen bottom, which left a different gap than Android's and
/// read as misplaced. Expressing it as footprint + gap makes the two match by
/// construction — tune the look here, once, instead of per screen.
const double kFabGapAboveBottomBar = 28.0;

/// Bottom offset for a floating action button that must clear the nav bar.
double fabBottomOffsetFor(BuildContext context) =>
    bottomBarFootprint(context) + kFabGapAboveBottomBar;
