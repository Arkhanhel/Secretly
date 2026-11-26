// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Покой украшений на телефоне (25.11.2026, замер iPhone 14: спокойный чат
// держал видеочип на 70–90 %).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/motion/decoration_pacer.dart';

class _W extends StatefulWidget {
  const _W(this.ticks, {required this.rests});
  final List<Duration> ticks;
  final bool rests;
  @override
  State<_W> createState() => _WState();
}

class _WState extends State<_W> with PacedTickerProviderStateMixin {
  @override
  bool get restsWhenIdle => widget.rests;
  late final Ticker _t = createTicker(widget.ticks.add);
  @override
  void initState() {
    super.initState();
    _t.start();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 40);
}

Future<void> _run(WidgetTester t, Duration d) async {
  for (var us = 0; us < d.inMicroseconds; us += 8333) {
    await t.pump(const Duration(microseconds: 8333));
  }
}

void main() {
  tearDown(DecorationPacer.debugReset);

  testWidgets('🔴 касание — 60, через 3 с — 30, через 20 с — стоит и кадров '
      'не просит; касание будит с того же места', (t) async {
    DecorationPacer.debugEnable(rest: true);
    final ticks = <Duration>[];
    await t.pumpWidget(_W(ticks, rests: true));
    await _run(t, const Duration(seconds: 1));
    ticks.clear();
    await _run(t, const Duration(seconds: 1));
    expect(ticks.length, inInclusiveRange(57, 62), reason: 'живое');

    await _run(t, const Duration(seconds: 2));
    ticks.clear();
    await _run(t, const Duration(seconds: 1));
    expect(ticks.length, inInclusiveRange(28, 32), reason: 'спокойно');

    await _run(t, const Duration(seconds: 17));
    ticks.clear();
    await _run(t, const Duration(seconds: 5));
    expect(ticks, isEmpty, reason: 'замерло');
    expect(t.binding.hasScheduledFrame, isFalse, reason: 'кадров не просит');
    expect(debugPacerTimersPending, 0);
    expect(DecorationActivity.resting.value, isTrue);

    await t.tapAt(const Offset(5, 5));
    await _run(t, const Duration(milliseconds: 500));
    expect(ticks.length, inInclusiveRange(28, 32), reason: 'ожило сразу');
    expect(
      ticks.first,
      lessThan(const Duration(seconds: 22)),
      reason: 'сон (5 с) не считается: поза не прыгает',
    );
    for (var i = 1; i < ticks.length; i++) {
      expect(ticks[i] - ticks[i - 1], lessThan(const Duration(milliseconds: 40)));
    }
    await t.pumpWidget(const SizedBox());
    DecorationPacer.debugReset();
  });

  testWidgets('содержимое (стикер, «печатает») не замирает никогда', (t) async {
    DecorationPacer.debugEnable(rest: true);
    final content = <Duration>[], deco = <Duration>[];
    await t.pumpWidget(
      Column(children: [_W(content, rests: false), _W(deco, rests: true)]),
    );
    await _run(t, const Duration(seconds: 21));
    content.clear();
    deco.clear();
    await _run(t, const Duration(seconds: 1));
    expect(content.length, inInclusiveRange(57, 62));
    expect(deco, isEmpty);
    await t.pumpWidget(const SizedBox());
    expect(debugPacerTimersPending, 0);
  });

  testWidgets('касания продлевают; уход и остановка во сне ничего не ломают', (
    t,
  ) async {
    DecorationPacer.debugEnable(rest: true);
    final ticks = <Duration>[];
    await t.pumpWidget(_W(ticks, rests: true));
    for (var i = 0; i < 12; i++) {
      await _run(t, const Duration(seconds: 2));
      await t.tapAt(const Offset(5, 5));
    }
    expect(DecorationActivity.resting.value, isFalse);
    ticks.clear();
    await _run(t, const Duration(seconds: 1));
    expect(ticks.length, inInclusiveRange(57, 62));
    await _run(t, const Duration(seconds: 25));
    expect(DecorationActivity.resting.value, isTrue);
    await t.pumpWidget(const SizedBox());
    await t.tapAt(const Offset(5, 5));
    await t.pump();
    DecorationPacer.debugReset();
  });

  testWidgets('возврат в приложение будит', (t) async {
    DecorationPacer.debugEnable(rest: true);
    final ticks = <Duration>[];
    await t.pumpWidget(_W(ticks, rests: true));
    await _run(t, const Duration(seconds: 22));
    expect(DecorationActivity.resting.value, isTrue);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(DecorationActivity.resting.value, isFalse);
    await t.pumpWidget(const SizedBox());
    DecorationPacer.debugReset();
  });

  testWidgets('выключено (ПК, проверки) — как раньше, без остановки', (t) async {
    DecorationPacer.debugEnable();
    final ticks = <Duration>[];
    await t.pumpWidget(_W(ticks, rests: true));
    await _run(t, const Duration(seconds: 25));
    ticks.clear();
    await _run(t, const Duration(seconds: 1));
    expect(ticks.length, inInclusiveRange(57, 62));
    await t.pumpWidget(const SizedBox());
    DecorationPacer.debugReset();
  });

  test('🔴 замирают украшения, содержимое — нет', () {
    bool rests(String path, String cls) {
      final s = File(path).readAsStringSync();
      final at = s.indexOf('class $cls');
      expect(at, greaterThan(0), reason: '$cls в $path');
      return s.substring(at, at + 700).contains('bool get restsWhenIdle => true;');
    }

    for (final (p, c) in [
      ('lib/ui/premium/live_frames.dart', '_LiveFrameViewState'),
      ('lib/ui/premium/profile_fx/frames/avatar_frame.dart', '_AnimatedAvatarFrameState'),
      ('lib/ui/premium/profile_fx/covers/profile_cover.dart', '_ProfileCoverState'),
      ('lib/ui/widgets/verified_badges.dart', '_VerifiedBadgeState'),
      ('lib/ui/emoji/noto_status_emoji.dart', '_NotoStatusEmojiState'),
    ]) {
      expect(rests(p, c), isTrue, reason: c);
    }
    for (final (p, c) in [
      ('lib/ui/widgets/typing_dots.dart', 'TypingDots'),
      ('lib/ui/chat_screen.dart', '_TypingDotsState'),
      ('lib/ui/chat_screen.dart', '_SendingClockStatusIconState'),
      ('lib/ui/widgets/secretly_sticker_widgets.dart', '_BundledStickerLottieState'),
    ]) {
      expect(rests(p, c), isFalse, reason: c);
    }
    final w = File('lib/ui/widgets/telegram_wallpaper.dart').readAsStringSync();
    expect(w.contains('!DecorationActivity.resting.value'), isTrue);
  });
}
