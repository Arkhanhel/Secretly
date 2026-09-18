// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/liquid_glass_flags.dart';

// 2026-07-23: the nav-bar's floating pill refracts ONLY while it slides between
// tabs; at rest it becomes a flat grey oval so it stops bending the left edge of
// long labels («Контакты» / «Настройки»), Telegram-style. secretlyIslandLensFlat
// is that at-rest look. Pin the two properties that define "flat" so a future
// tweak can't silently bring the magnifier back — while keeping the oval's tint
// and footprint identical to the live lens ("серый овал как сейчас").
void main() {
  for (final brightness in Brightness.values) {
    test('flat lens has no refraction/chromatic split ($brightness)', () {
      final live = secretlyIslandGlass(brightness);
      final flat = secretlyIslandLensFlat(brightness);

      // Everything that can mark the glyphs — refraction, chromatic split, AND
      // the shader's rim/ambient/glow light — killed, so a letter touching the
      // pill edge is not painted white.
      expect(flat.refractiveIndex, 1.0, reason: 'no light bending at rest');
      expect(flat.chromaticAberration, 0.0, reason: 'no colour fringing at rest');
      expect(flat.lightIntensity, 0.0, reason: 'no rim light whitening the edge');
      expect(flat.ambientStrength, 0.0);
      expect(flat.glowIntensity, 0.0);

      // Everything that defines the oval's look/footprint — unchanged, so it is
      // visually "the same grey oval", just without the lensing.
      expect(flat.glassColor, live.glassColor);
      expect(flat.thickness, live.thickness);
      expect(flat.blur, live.blur);
      expect(flat.saturation, live.saturation);
    });
  }
}
