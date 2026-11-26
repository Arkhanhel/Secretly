// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Неподвижные кадры Lottie картинками (24.11.2026, разбор подтормаживаний
// панели стикеров на Xiaomi 14 Pro и iPhone 11).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:secretly_app/stickers/premium_sticker_packs.dart';
import 'package:secretly_app/ui/chat/emoji_panel/emoji_panel_stickers.dart';
import 'package:secretly_app/ui/widgets/lottie_still.dart';
import 'package:secretly_app/ui/widgets/secretly_sticker_widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Квадрат 100×100 с красной заливкой.
final Uint8List _square = Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'v': '5.7.4',
      'fr': 30,
      'ip': 0,
      'op': 30,
      'w': 100,
      'h': 100,
      'layers': [
        {
          'ty': 4,
          'ip': 0,
          'op': 30,
          'st': 0,
          'ks': {},
          'shapes': [
            {
              'ty': 'rc',
              'p': {'a': 0, 'k': [50, 50]},
              's': {'a': 0, 'k': [80, 80]},
              'r': {'a': 0, 'k': 0},
            },
            {
              'ty': 'fl',
              'c': {'a': 0, 'k': [1, 0, 0, 1]},
              'o': {'a': 0, 'k': 100},
            },
          ],
        },
      ],
    }),
  ),
);

void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  tearDown(LottieStillCache.clear);

  testWidgets('🔴 кадр приходит: obtain не ждёт сам себя (758 показывала '
      'пустые стикеры); повтор — сразу из кэша; вытеснение не ломает '
      'показанное', (t) async {
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async {
      final provider = MemoryLottie(_square);
      final key = LottieStillCache.keyFor('sq', 0, 40);
      final first = await LottieStillCache.obtain(
        provider,
        key,
        progress: 0,
        px: 40,
      ).timeout(const Duration(seconds: 10));
      expect(first, isNotNull);
      expect(first!.width, 40);
      expect(LottieStillCache.length, 1);
      final again = await LottieStillCache.obtain(
        provider,
        key,
        progress: 0,
        px: 40,
      ).timeout(const Duration(seconds: 10));
      expect(again, isNotNull);
      expect(identical(again, first), isFalse, reason: 'своя копия у каждого');
      LottieStillCache.clear();
      expect(first.debugDisposed, isFalse);
      first.dispose();
      again!.dispose();
    });
  });

  testWidgets('встроенный стикер: animate=false — картинка, без живого '
      'проигрывателя; animate=true — живой Lottie', (t) async {
    final sticker = kidsStickerPack.stickers.first;
    Widget host(bool animate) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: bundledStickerLottie(
          sticker,
          size: 60,
          maxLoops: null,
          animate: animate,
        ),
      ),
    );
    await t.pumpWidget(host(false));
    await t.pump();
    expect(find.byType(LottieStillImage), findsOneWidget);
    expect(find.byType(LottieBuilder), findsNothing);

    await t.pumpWidget(host(true));
    await t.pump();
    expect(find.byType(LottieBuilder), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.pump();
  });

  test('панель: на прокрутке все стоят, после — играют не больше шести', () {
    final gate = StickerPlaybackGate();
    final tokens = List.generate(9, (_) => Object());
    tokens.forEach(gate.register);
    expect(tokens.where(gate.allows), hasLength(StickerPlaybackGate.maxPlaying));
    gate.paused = true;
    expect(tokens.where(gate.allows), isEmpty);
    gate.paused = false;
    expect(tokens.where(gate.allows), hasLength(StickerPlaybackGate.maxPlaying));
  });
}
