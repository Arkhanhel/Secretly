// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Закреплённые (22.11.2026, Д-1, Д-4, Д-8): касание по плашке «ничего не
// делало», если сообщение вне окна ленты или строки выше 76 px; двойное
// касание гасило подсветку раньше времени.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/chat_pins_logic.dart';
import 'package:secretly_app/ui/chat/pin_jump.dart';

/// Перевёрнутая лента, как в чате: строки разной высоты (фото, голосовые).
class _Feed extends StatelessWidget {
  const _Feed({required this.controller, required this.keys});

  static const int count = 3000;

  final ScrollController controller;
  final Map<int, GlobalKey> keys;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: controller,
          reverse: true,
          cacheExtent: 600,
          itemCount: count,
          itemBuilder: (context, i) => SizedBox(
            key: keys.putIfAbsent(i, GlobalKey.new),
            height: 40.0 + (i % 7) * 45.0,
            child: Text('row $i'),
          ),
        ),
      ),
    );
  }
}

(int, int, double) _built(Map<int, GlobalKey> keys) {
  var lo = -1;
  var hi = -1;
  var sum = 0.0;
  var n = 0;
  keys.forEach((i, k) {
    final ctx = k.currentContext;
    if (ctx == null) return;
    if (lo < 0 || i < lo) lo = i;
    if (i > hi) hi = i;
    final h = builtRowExtent(ctx);
    if (h > 0) {
      sum += h;
      n++;
    }
  });
  return (lo, hi, n == 0 ? 0.0 : sum / n);
}

Future<BuildContext?> _run(
  WidgetTester tester,
  Future<BuildContext?> job,
) async {
  BuildContext? out;
  var done = false;
  job.then((c) {
    out = c;
    done = true;
  });
  for (var i = 0; i < 80 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done, isTrue, reason: 'переход не закончился за 80 кадров');
  return out;
}

void main() {
  testWidgets('строка далеко за экраном и выше 76 px — находится', (
    tester,
  ) async {
    final controller = ScrollController();
    final keys = <int, GlobalKey>{};
    await tester.pumpWidget(_Feed(controller: controller, keys: keys));
    const target = 2400;
    expect(keys[target]?.currentContext, isNull);
    // Прежний прыжок «76 px на строку» сюда не попадает: строки выше.
    final ctx = await _run(
      tester,
      scrollUntilRowBuilt(
        controller: controller,
        targetIndex: target,
        targetContext: () => keys[target]?.currentContext,
        builtRange: () => _built(keys),
      ),
    );
    expect(ctx, isNotNull);
    await Scrollable.ensureVisible(ctx!);
    await tester.pumpAndSettle();
    expect(find.text('row $target'), findsOneWidget);
  });

  testWidgets('цель ниже текущего места — идёт обратно', (tester) async {
    final controller = ScrollController();
    final keys = <int, GlobalKey>{};
    await tester.pumpWidget(_Feed(controller: controller, keys: keys));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    const target = 3;
    final ctx = await _run(
      tester,
      scrollUntilRowBuilt(
        controller: controller,
        targetIndex: target,
        targetContext: () => keys[target]?.currentContext,
        builtRange: () => _built(keys),
      ),
    );
    expect(ctx, isNotNull);
  });

  testWidgets('новая попытка останавливает старую', (tester) async {
    final controller = ScrollController();
    final keys = <int, GlobalKey>{};
    await tester.pumpWidget(_Feed(controller: controller, keys: keys));
    final attempts = LatestAttempt();
    final first = attempts.begin();
    final job = scrollUntilRowBuilt(
      controller: controller,
      targetIndex: 2500,
      targetContext: () => keys[2500]?.currentContext,
      builtRange: () => _built(keys),
      keepGoing: () => attempts.isLatest(first),
    );
    attempts.begin(); // двойное касание
    expect(await _run(tester, job), isNull);
  });

  test('Д-8: подсветку гасит только последняя попытка', () {
    final a = LatestAttempt();
    final first = a.begin();
    final second = a.begin();
    expect(a.isLatest(first), isFalse);
    expect(a.isLatest(second), isTrue);
  });

  test('Д-4: шаг 0,8 экрана в сторону цели, край — не дальше', () {
    expect(
      nextPinJumpOffset(
        pixels: 100,
        viewport: 800,
        maxExtent: 5000,
        targetIndex: 50,
        minBuilt: 0,
        maxBuilt: 10,
      ),
      740,
    );
    expect(
      nextPinJumpOffset(
        pixels: 100,
        viewport: 800,
        maxExtent: 5000,
        targetIndex: 0,
        minBuilt: 5,
        maxBuilt: 10,
      ),
      0,
    );
    expect(
      nextPinJumpOffset(
        pixels: 4900,
        viewport: 800,
        maxExtent: 5000,
        targetIndex: 99,
        minBuilt: 10,
        maxBuilt: 20,
      ),
      5000,
    );
    // Далеко — прыжок на оценку по средней высоте (с недолётом).
    expect(
      nextPinJumpOffset(
        pixels: 0,
        viewport: 800,
        maxExtent: 1e6,
        targetIndex: 1010,
        minBuilt: 0,
        maxBuilt: 10,
        averageRowExtent: 100,
      ),
      90000,
    );
    // Ни одной строки не построено — оценка по индексу.
    expect(
      nextPinJumpOffset(
        pixels: 0,
        viewport: 800,
        maxExtent: 5000,
        targetIndex: 10,
        minBuilt: -1,
        maxBuilt: -1,
      ),
      760,
    );
  });

  test('Д-1: окно ленты растёт шагами до потолка', () {
    expect(
      nextPinJumpWindowLimit(current: 200, step: 400, ceiling: 4000),
      600,
    );
    expect(
      nextPinJumpWindowLimit(current: 3800, step: 400, ceiling: 4000),
      4000,
    );
    expect(
      nextPinJumpWindowLimit(current: 4000, step: 400, ceiling: 4000),
      isNull,
    );
  });

  group('🔴 провода экрана', () {
    final s = File('lib/ui/chat_screen.dart').readAsStringSync();

    test('переход: окно, тема, «недоступно», без переключения плашки', () {
      expect(kPinJumpV2, isTrue);
      expect(s.contains('widget.controller.chatEventExists('), isTrue);
      expect(s.contains('_growTimelineUntilRendered(target, latest)'), isTrue);
      expect(s.contains('_switchTopicForTarget(target)'), isTrue);
      expect(s.contains('l10n.pinnedMessageUnavailable'), isTrue);
      expect(s.contains('label: l10n.unpin'), isTrue);
      final at = s.indexOf('Future<void> _handlePinnedMessageTap(');
      final body = s.substring(at, at + 700);
      expect(body.contains('if (!shown) return;'), isTrue);
    });

    test('индекс — в показанном списке, подсветка по номеру попытки', () {
      expect(s.contains('_lastRowIndexOffset = rowIndexOffset;'), isTrue);
      expect(s.contains('_jumpAttempts.isLatest(attempt)'), isTrue);
      expect(s.contains('scrollUntilRowBuilt('), isTrue);
    });
  });
}
