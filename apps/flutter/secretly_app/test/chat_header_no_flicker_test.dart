// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// 🔴 FIELD (2026-08-01): "opening a chat flashes the peer's avatar in a moment
/// later — it feels like a separate web page loading, not one app."
///
/// The data was never missing. The chats list had just rendered the very same
/// avatar and left the row in the controller's in-memory conversation cache.
/// Two things still forced an empty frame:
///
///   1. the header's `FutureBuilder` future was built INLINE in `build()`,
///      inside a `StreamBuilder` on `controller.changed` — so every unrelated
///      controller tick handed it a NEW future, and a new future resets a
///      FutureBuilder to `waiting` with `data == null`. The header blanked
///      during ordinary use, not only on open;
///   2. `listConversations()` is async, so even a pure cache HIT resolves on a
///      later microtask — guaranteeing one `null` frame on first build.
///
/// Both halves are wiring, and wiring is invisible to a test that only checks
/// that the pieces exist. These prove the pieces are CONNECTED — the same
/// lesson the power-settings localization guard was written for.
void main() {
  // AppController spins up audio players on construction, which reach for the
  // platform channels.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chat header paints on the first frame', () {
    test('🔴 the header future is MEMOIZED, not rebuilt inline', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      expect(
        code.contains('future: _headerConversationFuture()'),
        isTrue,
        reason: 'the header no longer uses the memoized future',
      );
      expect(
        code.contains('future: _loadHeaderConversation(widget.convoId)'),
        isFalse,
        reason: 'the header builds a NEW future inside build() again — every '
            'controller tick will blank the avatar, which is the field report',
      );
    });

    test('🔴 the header is SEEDED from the warm cache', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code.contains('initialData: widget.controller.cachedConversation('),
        isTrue,
        reason: 'without initialData the first frame has no avatar even when '
            'the conversation is already in memory — the flash returns',
      );
    });

    test('the memoization is keyed on the CONVERSATION, not just the version', () {
      // Reusing one chat's header row for another is worse than a flash: it
      // shows the wrong person. The cache key must include convoId.
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      expect(src.contains('_headerFutureConvoId'), isTrue);
      expect(
        src.contains('_headerFutureConvoId == widget.convoId'),
        isTrue,
        reason: 'a memoized header must be invalidated when the chat changes',
      );
    });

    test('cachedConversation is total — no throw on empty or unknown ids', () {
      // Called during build on EVERY chat open, including a cold start where
      // nothing is cached yet. It must answer "I do not know" rather than
      // throw, and it must never block.
      final c = AppController();
      expect(c.cachedConversation(''), isNull);
      expect(c.cachedConversation('   '), isNull);
      expect(c.cachedConversation('convo-that-does-not-exist'), isNull);
    });
  });
}
