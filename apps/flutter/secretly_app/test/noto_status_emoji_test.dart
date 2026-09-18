// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/emoji/noto_emoji_catalog.dart';
import 'package:secretly_app/ui/emoji/noto_status_emoji.dart';

void main() {
  group('animated emoji status', () {
    test('isAnimatableStatusEmoji matches the Noto animation catalog', () {
      // Trimmed lookups, variation-selector emoji, and plain ones all resolve.
      expect(isAnimatableStatusEmoji('😎'), isTrue);
      expect(isAnimatableStatusEmoji(' 😎 '), isTrue); // trims
      expect(isAnimatableStatusEmoji('❤️'), isTrue); // FE0F variation selector
      expect(isAnimatableStatusEmoji('🔥'), isTrue);
      // A non-Noto char has no animation and must fall back to the glyph.
      expect(isAnimatableStatusEmoji('Z'), isFalse);
    });

    test(
        'the «Animated» picker set is the full Noto catalog, not a handful',
        () {
      // The picker pins ALL animatable catalog emoji (minus collapsed skin-tone
      // variants) into its «Animated» section. Guard against silently shrinking
      // back to a small curated list.
      final animatedOptions = <String>[
        for (final emoji in kNotoCodepoints.keys)
          if (!kNotoSkinToneHidden.contains(emoji)) emoji,
      ];
      expect(animatedOptions.length, greaterThan(500));
      // Every option is genuinely animatable.
      for (final e in animatedOptions) {
        expect(isAnimatableStatusEmoji(e), isTrue, reason: '$e not animatable');
      }
    });
  });
}
