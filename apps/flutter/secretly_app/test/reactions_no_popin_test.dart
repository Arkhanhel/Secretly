// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// 🔴 FIELD (2026-08-01): "reactions that were added long ago get placed again,
/// visually, every time I open the chat — it feels like the bubbles jump."
///
/// Nothing was re-adding them. The chat screen seeded its reaction
/// `FutureBuilder` with a warm map so a bubble and its chips paint in the same
/// frame — but that map lived on the SCREEN's State. Leaving the chat destroys
/// it, so frame one of every re-entry had no chips, the async query dropped
/// them in a frame or two later, and every bubble carrying a reaction grew
/// AFTER layout. That late growth is the jump.
///
/// The warm map therefore has to outlive the screen. These pin the two halves
/// that make that true, and the one case where a cache would otherwise lie.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reactions are known before the first frame', () {
    test('cachedReactionsFor is total and synchronous', () {
      // Read during build on EVERY chat open, including a cold start with an
      // empty cache. It must answer "nothing known" rather than throw or block.
      final c = AppController();
      expect(cachedEmpty(c), isTrue);
      expect(c.cachedReactionsFor(const <String>['no-such-event']), isEmpty);
    });

    test('🔴 the chat screen SEEDS from the controller, not only itself', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code.contains('widget.controller.cachedReactionsFor('),
        isTrue,
        reason: 'the screen seeds only from its own State again — that map is '
            'empty on every re-entry, which is exactly the reported jump',
      );
      // The screen-local map must still take precedence while the screen is
      // alive: it is the fresher of the two.
      expect(
        code.contains('_reactionsShown.isNotEmpty'),
        isTrue,
        reason: 'the fresher screen-local map must win while it has content',
      );
    });

    /// 🔴 The failure direction that matters. A cache that only ever ADDS would
    /// keep painting a chip whose last reaction was removed — showing a
    /// reaction that no longer exists is worse than the pop-in being fixed.
    test('a warm cache must FORGET an event whose reactions are all gone', () {
      final src = File('lib/app/app_controller.dart').readAsStringSync();
      final start = src.indexOf('_reactionsCache.addAll(out);');
      expect(start, greaterThan(-1), reason: 'the cache warm-up moved');
      final window = src.substring(start, start + 400);
      expect(
        window.contains('_reactionsCache.remove(id)'),
        isTrue,
        reason: 'ids queried but absent from the result must be EVICTED, or a '
            'removed reaction keeps rendering from cache on the next open',
      );
    });
  });
}

bool cachedEmpty(AppController c) =>
    c.cachedReactionsFor(const <String>[]).isEmpty;
