// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/cosmetic_catalog.dart';
import 'package:secretly_app/ui/chat_wallpapers.dart';
import 'package:secretly_app/ui/widgets/telegram_wallpaper.dart';

void main() {
  group('animated wallpaper ids', () {
    test('encode/decode round-trips for every bundled style', () {
      for (final style in WallpaperStyles.all) {
        final id = encodeAnimatedChatWallpaperId(style.key);
        expect(id, 'anim:${style.key}');
        expect(isAnimatedChatWallpaperId(id), isTrue);
        expect(decodeAnimatedChatWallpaperStyle(id), same(style));
      }
    });

    test('style keys are unique', () {
      final keys = WallpaperStyles.all.map((s) => s.key).toSet();
      expect(keys.length, WallpaperStyles.all.length);
    });

    test('unknown key or non-animated id decodes to null', () {
      expect(decodeAnimatedChatWallpaperStyle('anim:does_not_exist'), isNull);
      expect(decodeAnimatedChatWallpaperStyle('server:x'), isNull);
      expect(decodeAnimatedChatWallpaperStyle('default'), isNull);
      expect(isAnimatedChatWallpaperId('asset:assets/Background/x.jpg'), isFalse);
    });

    test('a valid animated id is a valid wallpaper id; a bogus one is not', () {
      expect(isValidChatWallpaperId('anim:aurora'), isTrue);
      expect(isValidChatWallpaperId('anim:not_a_style'), isFalse);
    });
  });

  group('premium gating', () {
    test('animated wallpapers are premium (never free)', () {
      for (final style in WallpaperStyles.all) {
        final id = encodeAnimatedChatWallpaperId(style.key);
        expect(isCosmeticFree(CosmeticKind.wallpaper, id), isFalse);
      }
    });

    test('server wallpapers stay premium, bundled stay free', () {
      expect(isCosmeticFree(CosmeticKind.wallpaper, 'server:abc'), isFalse);
      expect(
        isCosmeticFree(CosmeticKind.wallpaper, 'asset:assets/Background/x.jpg'),
        isTrue,
      );
    });
  });

  group('animation mode', () {
    test('parse round-trips via the stable name', () {
      for (final mode in ChatWallpaperAnimMode.values) {
        expect(parseChatWallpaperAnimMode(mode.name), mode);
        expect(mode.storageKey, mode.name);
      }
    });

    test('null / garbage fall back to onEnter (Telegram default)', () {
      expect(parseChatWallpaperAnimMode(null), ChatWallpaperAnimMode.onEnter);
      expect(parseChatWallpaperAnimMode('nope'), ChatWallpaperAnimMode.onEnter);
      expect(
        parseChatWallpaperAnimMode(null, fallback: ChatWallpaperAnimMode.off),
        ChatWallpaperAnimMode.off,
      );
    });
  });

  group('rendering + picker', () {
    testWidgets('buildChatWallpaperBackground renders a TelegramWallpaper for '
        'an animated id', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => buildChatWallpaperBackground(
              context,
              'anim:aurora',
              preview: true, // static frame — no timers in the test
            ),
          ),
        ),
      );
      expect(find.byType(TelegramWallpaper), findsOneWidget);
    });

    testWidgets('picker options include all animated styles', (tester) async {
      late List<ChatWallpaperOption> options;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              options = buildChatWallpaperOptions(
                context,
                assetPaths: const <String>[],
                includeGlobalOption: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      for (final style in WallpaperStyles.all) {
        expect(
          options.any((o) => o.id == 'anim:${style.key}'),
          isTrue,
          reason: 'missing anim:${style.key}',
        );
      }
    });
  });
}
