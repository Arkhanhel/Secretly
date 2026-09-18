// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/telegram_wallpaper.dart';

/// The Midnight wallpaper style and the top/bottom shading (owner request,
/// 2026-08-01).
///
/// Context worth keeping: the animated wallpaper paints a black base, then four
/// radial blobs in `BlendMode.plus`, then masks everything down to the doodle
/// lines with `dstIn`. There was no shading layer at all — the depth was an
/// accident of wherever the additive blobs failed to reach, which is also the
/// leading suspect for it reading differently on iOS (additive compositing is
/// the operation most sensitive to the renderer's colour space).
void main() {
  group('Midnight style', () {
    test('is offered in the picker', () {
      expect(
        WallpaperStyles.all.map((s) => s.key),
        contains('midnight'),
      );
      expect(WallpaperStyles.byKey('midnight'), isNotNull);
    });

    test('every style still has exactly four blobs', () {
      // The painter indexes colours 0..3 unconditionally; a short list would
      // throw at paint time, on a screen, in front of a user.
      for (final s in WallpaperStyles.all) {
        expect(s.colors, hasLength(4), reason: '${s.key} has ${s.colors.length}');
      }
    });

    test('stays DARK — that is the whole point of it', () {
      final midnight = WallpaperStyles.byKey('midnight')!;

      // Dim on its own…
      for (final c in midnight.colors) {
        expect(
          c.computeLuminance(),
          lessThan(0.20),
          reason: 'a bright blob would wash the black background out',
        );
      }

      // …and dimmer than every other style once the four additive layers are
      // taken into account. Opacity is the knob that keeps it dark; at the
      // full 1.0 the others use, four `plus` layers saturate and it stops
      // being a dark wallpaper at all.
      expect(midnight.blobOpacity, lessThan(1.0));
      for (final other in WallpaperStyles.all.where((s) => s.key != 'midnight')) {
        final mid = midnight.colors
                .map((c) => c.computeLuminance())
                .reduce((a, b) => a + b) *
            midnight.blobOpacity;
        final o = other.colors
                .map((c) => c.computeLuminance())
                .reduce((a, b) => a + b) *
            other.blobOpacity;
        expect(mid, lessThan(o), reason: '${other.key} is darker than Midnight');
      }
    });

    test('keys are unique, so byKey cannot resolve the wrong wallpaper', () {
      final keys = WallpaperStyles.all.map((s) => s.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });
  });

  group('top/bottom shading', () {
    test('is on, and gentle enough to leave the artwork readable', () {
      expect(kWallpaperEdgeShade, greaterThan(0.0));
      expect(
        kWallpaperEdgeShade,
        lessThan(0.6),
        reason: 'past this it stops being depth and starts eating the wallpaper',
      );
    });

    test(
      '🔴 is painted AFTER the mask layer, or the dstIn would erase it',
      () {
        // The single mistake that would make this feature silently do nothing:
        // a gradient drawn inside the saveLayer is masked down to the doodle
        // lines along with everything else. Position is the whole contract, so
        // assert it in the source rather than trusting a comment.
        final src = File(
          'lib/ui/widgets/telegram_wallpaper.dart',
        ).readAsStringSync();

        final restore = src.indexOf('canvas.restore();');
        final shade = src.indexOf('kWallpaperEdgeShade > 0');
        final mask = src.indexOf('BlendMode.dstIn');

        expect(restore, isNot(-1));
        expect(shade, isNot(-1), reason: 'the shading block is gone');
        expect(mask, isNot(-1));
        expect(
          mask < restore && restore < shade,
          isTrue,
          reason: 'order must be mask → restore → shade; the shading is inside '
              'the masked layer and will be invisible',
        );
      },
    );

    test('does not use an additive blend, so both platforms agree', () {
      // Everything above the shading is `plus`. Using it here too would put the
      // fix back at the mercy of the very thing it works around.
      final src = File(
        'lib/ui/widgets/telegram_wallpaper.dart',
      ).readAsStringSync();
      final shadeBlock = src.substring(src.indexOf('kWallpaperEdgeShade > 0'));
      final end = shadeBlock.indexOf('\n  }');
      expect(
        shadeBlock.substring(0, end).contains('BlendMode.plus'),
        isFalse,
        reason: 'the shading must composite normally, not additively',
      );
    });
  });
}
