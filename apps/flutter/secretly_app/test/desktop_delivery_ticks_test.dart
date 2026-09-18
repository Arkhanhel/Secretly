// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';

/// U-14 — the desktop delivery ticks must read identically to mobile.
///
/// The model is user-specified and count-based:
///   in-flight → clock · failed → ONE RED tick · sent/delivered → ONE tick ·
///   read → TWO ticks · scheduled → its own glyph.
///
/// Count carries "read vs unread"; colour is reserved for "never sent". Desktop
/// had drifted (an error circle for failed, a blue second tick for read), which
/// made the same message look different depending on the device it was opened
/// on. These tests exist so that cannot silently happen again.
void main() {
  Future<void> pumpGlyph(WidgetTester tester, DeliveryStatus status) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: deliveryTickGlyph(status, const Color(0xFF999999))),
        ),
      ),
    );
  }

  List<Icon> iconsOf(WidgetTester tester) =>
      tester.widgetList<Icon>(find.byType(Icon)).toList();

  testWidgets('sent shows exactly one tick', (tester) async {
    await pumpGlyph(tester, DeliveryStatus.sent);
    final icons = iconsOf(tester);
    expect(icons, hasLength(1));
    expect(icons.single.icon, FluentIcons.checkmark_24_regular);
  });

  testWidgets('🔴 sent is DIMMER than delivered — the three steps differ',
      (tester) async {
    // Как на телефоне (`chatDeliveryTickStyle`): отправлено — 0,55,
    // доставлено — полная яркость. Раньше обе рисовались одинаково.
    await pumpGlyph(tester, DeliveryStatus.sent);
    final sent = iconsOf(tester).single.color!;
    await pumpGlyph(tester, DeliveryStatus.delivered);
    final delivered = iconsOf(tester).single.color!;
    expect(sent, isNot(delivered));
    expect(delivered.a, closeTo(1.0, 0.001));
    expect(sent.a, closeTo(kDesktopSentTickAlpha, 0.001));
    expect(sent.r, delivered.r);
    expect(sent.g, delivered.g);
    expect(sent.b, delivered.b);
  });

  testWidgets('delivered-but-unread is still ONE tick', (tester) async {
    await pumpGlyph(tester, DeliveryStatus.delivered);
    final icons = iconsOf(tester);
    expect(icons, hasLength(1),
        reason: 'a second tick must mean READ, nothing else');
    expect(icons.single.icon, FluentIcons.checkmark_24_regular);
  });

  testWidgets('read shows TWO ticks in the SAME colour', (tester) async {
    await pumpGlyph(tester, DeliveryStatus.read);
    final icons = iconsOf(tester);
    expect(icons, hasLength(2));
    expect(icons.every((i) => i.icon == FluentIcons.checkmark_24_regular), isTrue);
    // The count is the signal — a differently-coloured second tick would
    // reintroduce the "blue read" that mobile deliberately dropped.
    expect(icons.first.color, icons.last.color);
  });

  testWidgets('failed is ONE RED tick, not an error glyph', (tester) async {
    await pumpGlyph(tester, DeliveryStatus.failed);
    final icons = iconsOf(tester);
    expect(icons, hasLength(1));
    expect(icons.single.icon, FluentIcons.checkmark_24_regular);
    expect(icons.single.color, kDesktopUnsentTickColor);
  });

  testWidgets('in-flight shows a clock, not a tick', (tester) async {
    await pumpGlyph(tester, DeliveryStatus.sending);
    final icons = iconsOf(tester);
    expect(icons, hasLength(1));
    expect(icons.single.icon, FluentIcons.clock_24_regular);
  });

  testWidgets('scheduled is distinct from both sending and sent',
      (tester) async {
    await pumpGlyph(tester, DeliveryStatus.scheduled);
    final icons = iconsOf(tester);
    expect(icons, hasLength(1));
    // A deferred send is not an error and not "already sent" — it gets its own
    // glyph so the timeline does not claim it went out.
    expect(icons.single.icon, isNot(FluentIcons.checkmark_24_regular));
    expect(icons.single.icon, isNot(FluentIcons.clock_24_regular));
  });

  testWidgets('every delivery state renders something', (tester) async {
    for (final status in DeliveryStatus.values) {
      await pumpGlyph(tester, status);
      expect(iconsOf(tester), isNotEmpty, reason: 'no glyph for $status');
    }
  });
}
