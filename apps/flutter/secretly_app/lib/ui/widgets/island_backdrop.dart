// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui';

import 'package:flutter/material.dart';

/// VIBRANCY TEST (2026-07-17): saturation boost applied to the backdrop
/// together with the blur — the iOS "vibrancy" recipe. Content refracted
/// through the header islands (chat bubbles, covers, wallpapers) reads
/// noticeably juicier instead of washing out toward gray.
///
/// ROLLBACK SWITCH: set to 1.0 and the filter degrades to the exact plain
/// blur used before (the compose branch is skipped entirely) — or revert the
/// commit. 1.8 — верхняя граница Apple; 1.45 ≈ Apple's system-material vibrancy range (1.4–1.8).
///
/// Cost: the color matrix is a per-pixel linear transform fused into the SAME
/// backdrop pass as the blur — the blur itself dominates; measured overhead is
/// a few percent of an already-paid effect, no extra saveLayers.
const double kIslandBackdropSaturation = 1.8;

/// Blur (+ optional saturation) filter for the frosted header islands.
ImageFilter islandBackdropFilter({
  required double sigmaX,
  required double sigmaY,
}) {
  final blur = ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY);
  if (kIslandBackdropSaturation == 1.0) return blur;
  return ImageFilter.compose(
    outer: blur,
    inner: ColorFilter.matrix(
      _saturationMatrix(kIslandBackdropSaturation),
    ),
  );
}

/// Standard luminance-preserving saturation matrix (Rec. 709 weights) —
/// s = 1 is identity, s > 1 boosts saturation.
List<double> _saturationMatrix(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final inv = 1 - s;
  final r = inv * lr, g = inv * lg, b = inv * lb;
  return <double>[
    r + s, g, b, 0, 0, //
    r, g + s, b, 0, 0, //
    r, g, b + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

// ── Frosted panels OFF: an OPAQUE plate, not a see-through one ─────────────
//
// 🔴 FIELD REPORT (2026-08-01): turning "Frosted panels" off made the chat
// panels VANISH — you could see the wallpaper and the messages straight
// through them.
//
// The cause is that every island's fill was tuned to sit ON TOP OF a blur. In
// dark mode it is white at alpha 0.015–0.13 — enough to take the dirtiness off
// a blurred backdrop, and visually nothing at all on its own. Remove the blur
// and you remove the panel.
//
// So the switch cannot simply skip the BackdropFilter. When it is off the
// island has to paint a SOLID plate instead: a dark neutral carrying a hint of
// the active theme, or plain white in light mode. That is also the cheapest
// possible surface — one opaque rect, no backdrop capture, no shader — which
// is the whole point of the setting.

/// Whether island surfaces may blur what is behind them.
///
/// A [ValueNotifier] rather than a controller field, mirroring [GlassPrefs]:
/// islands live all over the widget tree and most of them never see the
/// AppController. The app root listens and rebuilds everything at once, so the
/// screen can never be left half blurred and half flat.
class PanelPrefs {
  const PanelPrefs._();

  /// Kept in step with `AppController.frostedPanelsEnabled`, which owns the
  /// persisted value. Default ON so the look is unchanged until asked.
  static final ValueNotifier<bool> frostedEnabled = ValueNotifier<bool>(true);
}

/// The base plate for dark mode when the blur is off.
///
/// Owner-picked neutral. Tweak THIS constant to retune the shade — every
/// island reads it.
const Color kOpaquePanelDarkBase = Color(0xFF232323);

/// How much of the active theme bleeds into the dark plate — "a light tint of
/// the chosen theme", not a coloured panel.
const double kOpaquePanelTint = 0.06;

/// The solid fill an island paints when [PanelPrefs.frostedEnabled] is false.
///
/// Light mode is plain white on purpose: anything translucent there greys the
/// text underneath and reads as a rendering fault rather than a design.
Color opaquePanelFill(BuildContext context) {
  final theme = Theme.of(context);
  if (theme.brightness != Brightness.dark) return Colors.white;
  return Color.alphaBlend(
    theme.colorScheme.primary.withValues(alpha: kOpaquePanelTint),
    kOpaquePanelDarkBase,
  );
}

/// Wraps [child] in the island backdrop blur, or — when the setting is off —
/// paints [child] over a solid plate instead.
///
/// One place decides, so a new island cannot forget the off-state and go
/// invisible. [grouped] uses `BackdropFilter.grouped` for islands that share a
/// single glass layer.
Widget islandSurface({
  required BuildContext context,
  required double sigma,
  required Widget child,
  bool grouped = false,
}) {
  if (!PanelPrefs.frostedEnabled.value) {
    return ColoredBox(color: opaquePanelFill(context), child: child);
  }
  final filter = islandBackdropFilter(sigmaX: sigma, sigmaY: sigma);
  return grouped
      ? BackdropFilter.grouped(filter: filter, child: child)
      : BackdropFilter(filter: filter, child: child);
}
