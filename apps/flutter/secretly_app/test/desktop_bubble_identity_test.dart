// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/theme_bridge.dart';
import 'package:secretly_app/ui/theme_presets.dart';

MessageData _incoming({bool continuation = false}) => MessageData(
      id: 'm1',
      authorName: 'Игорь',
      text: 'Привет',
      time: '12:00',
      isSelf: false,
      continuation: continuation,
    );

Widget _host(Widget child, {DColorSet? colors}) => MaterialApp(
      home: Scaffold(
        body: DColors(
          colors: colors ?? kDColorsDark,
          child: SizedBox(width: 700, child: child),
        ),
      ),
    );

void main() {
  group('1:1 hides the peer identity', () {
    testWidgets('no sender name on an incoming bubble', (t) async {
      await t.pumpWidget(_host(
        MessageBubble(message: _incoming(), showPeerIdentity: false),
      ));
      await t.pump();

      // The name must not appear as a label above the text. The message body
      // itself ('Привет') is a different string, so this is unambiguous.
      expect(find.text('Игорь'), findsNothing,
          reason: 'a 1:1 chat has one other person — the header already says '
              'who, and repeating it on every bubble is noise');
    });

    testWidgets('a room still names who is speaking', (t) async {
      await t.pumpWidget(_host(
        MessageBubble(message: _incoming(), showPeerIdentity: true),
      ));
      await t.pump();

      expect(find.text('Игорь'), findsOneWidget,
          reason: 'hiding the author in a ROOM would make it unreadable — the '
              'flag must not leak across chat kinds');
    });

    testWidgets('defaults to showing identity', (t) async {
      // The safe wrong answer: a 1:1 that redundantly shows a name is untidy,
      // a room that hides it is broken. Default must fail toward the former.
      await t.pumpWidget(_host(MessageBubble(message: _incoming())));
      await t.pump();
      expect(find.text('Игорь'), findsOneWidget);
    });
  });

  group('outgoing bubble follows the shared preset', () {
    test('a chosen preset actually reaches the desktop palette', () {
      // The desktop settings screen already wrote chatBubbleStylePresetId
      // while nothing read it back, so the picker moved the phone's bubbles
      // and left the desktop's alone.
      final preset = kChatBubbleStylePresets.firstWhere(
        (p) => p.darkTop != kDColorsDark.bubbleSelfStart,
        orElse: () => kChatBubbleStylePresets.first,
      );

      final applied = applyThemePreset(
        kDColorsDark,
        'default',
        dark: true,
        bubblePresetId: preset.id,
      );

      expect(applied.bubbleSelfStart, preset.darkTop);
      expect(applied.bubbleSelfEnd, preset.darkBottom);
      expect(applied.bubbleSelfMid, preset.darkMid);
    });

    test('light palette takes the light variant', () {
      final preset = kChatBubbleStylePresets.first;
      final applied = applyThemePreset(
        kDColorsLight,
        'default',
        dark: false,
        bubblePresetId: preset.id,
      );

      expect(applied.bubbleSelfStart, preset.lightTop,
          reason: 'a dark-mixed bubble on a light surface is the bug this '
              'parameter exists to prevent');
      expect(applied.bubbleSelfEnd, preset.lightBottom);
    });

    test('no preset id keeps the old accent-driven behaviour', () {
      final applied = applyThemePreset(kDColorsDark, 'default', dark: true);
      expect(applied.bubbleSelfStart, applied.accentPrimary);
      expect(applied.bubbleSelfEnd, applied.accentPrimaryAlt);
      expect(applied.bubbleSelfMid, isNull);
    });

    test('a preset without a mid does not inherit the previous one', () {
      // copyWith cannot set a nullable field back to null, so this depends on
      // the palette constants never defining bubbleSelfMid. Lock that down.
      expect(kDColorsDark.bubbleSelfMid, isNull);
      expect(kDColorsLight.bubbleSelfMid, isNull);

      final noMid = kChatBubbleStylePresets.where((p) => p.darkMid == null);
      if (noMid.isNotEmpty) {
        final applied = applyThemePreset(kDColorsDark, 'default',
            dark: true, bubblePresetId: noMid.first.id);
        expect(applied.bubbleSelfMid, isNull,
            reason: 'a stale middle stop would blend two different presets');
      }
    });
  });
}
