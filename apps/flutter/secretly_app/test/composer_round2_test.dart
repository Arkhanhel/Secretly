// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Поле ввода, второй круг (22.11.2026): меню отложенной отправки при открытой
// панели эмодзи (С-6), чип скорости голосового (Н-8), эффекты реакций и эмодзи
// не доигрывают поверх другого экрана (Н-10).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/reaction_fx.dart';
import 'package:secretly_app/ui/chat/route_bound_fx.dart';
import 'package:secretly_app/ui/chat/solo_emoji_fx.dart';
import 'package:secretly_app/ui/chat/voice_speed_chip.dart';
import 'package:secretly_app/ui/chat_screen.dart' show scheduleMenuBottom;

const _label = 'Скорость воспроизведения';

/// Пузырь голосового в миниатюре: волна (своё касание), под ней строка
/// «длительность · чип», нижний отступ 6 — как в настоящем пузыре.
Widget _bubble({
  required bool playing,
  required VoidCallback onSpeed,
  required VoidCallback onWave,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 220,
          child: SpeedChipHitScope(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    key: const ValueKey('wave'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onWave,
                    child: const SizedBox(height: 24, width: double.infinity),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('0:12', style: TextStyle(fontSize: 12, height: 1)),
                      const SizedBox(width: 6),
                      VoiceSpeedChip(
                        key: const ValueKey('chip'),
                        label: '1,5×',
                        semanticLabel: _label,
                        visible: playing,
                        onTap: onSpeed,
                        textStyle: const TextStyle(
                          fontSize: 11,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const Text('11:20', style: TextStyle(fontSize: 11, height: 1)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // ─── С-6 ──────────────────────────────────────────────────────────────────

  group('С-6: меню отложенной отправки', () {
    const pad = EdgeInsets.only(bottom: 34);

    test('без панели — прежняя формула', () {
      expect(
        scheduleMenuBottom(
          keyboardInset: 0,
          panelInset: 0,
          padding: pad,
          viewPadding: pad,
          replying: false,
        ),
        34 + 96,
      );
      // Клавиатура: системный отступ уже съеден ею (padding = 0).
      expect(
        scheduleMenuBottom(
          keyboardInset: 336,
          panelInset: 0,
          padding: EdgeInsets.zero,
          viewPadding: pad,
          replying: true,
        ),
        336 + 96 + 58,
      );
    });

    test('панель открыта — меню над кнопкой, а не внутри панели', () {
      final bottom = scheduleMenuBottom(
        keyboardInset: 0,
        panelInset: 336,
        padding: pad,
        viewPadding: pad,
        replying: false,
      );
      // Раньше: 0 + 34 + 96 = 130 — на ~340 px ниже кнопки.
      expect(bottom, 336 + 96);
      // Клавиатура уезжает, панель стоит — меню не прыгает.
      expect(
        scheduleMenuBottom(
          keyboardInset: 200,
          panelInset: 336,
          padding: EdgeInsets.zero,
          viewPadding: pad,
          replying: false,
        ),
        bottom,
      );
      // Раскрытая панель выше клавиатуры — меню выше.
      expect(
        scheduleMenuBottom(
          keyboardInset: 0,
          panelInset: 540,
          padding: pad,
          viewPadding: pad,
          replying: false,
        ),
        540 + 96,
      );
    });
  });

  // ─── Н-8 ──────────────────────────────────────────────────────────────────

  group('Н-8: чип скорости', () {
    testWidgets('видимый чип прежнего размера, касание — в зоне ≥ 32×28', (t) async {
      var speed = 0;
      var wave = 0;
      await t.pumpWidget(
        _bubble(playing: true, onSpeed: () => speed++, onWave: () => wave++),
      );
      final chip = t.getRect(find.byKey(const ValueKey('chip')));
      // Видимый чип маленький (14 в высоту) — зону касания даёт обёртка, а
      // не раскладка: пузырь не вырос.
      expect(chip.height, 14);
      // Касания вокруг чипа — чипу: зона 8 вверх + 14 + 6 вниз = 28.
      final probes = <Offset>[
        chip.center,
        Offset(chip.center.dx, chip.top - 7.5), // над чипом, у края волны
        Offset(chip.center.dx, chip.bottom + 5.5), // в нижнем отступе пузыря
      ];
      for (final p in probes) {
        await t.tapAt(p);
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(speed, probes.length);
      expect(wave, 0);
      // Дальше — уже волна.
      await t.tapAt(Offset(chip.center.dx, chip.top - 14));
      await t.pump(const Duration(milliseconds: 50));
      expect(wave, 1);
      expect(speed, probes.length);
    });

    testWidgets('чтец экрана: кнопка «Скорость воспроизведения», значение — скорость', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(_bubble(playing: true, onSpeed: () {}, onWave: () {}));
      final node = t.getSemantics(find.bySemanticsLabel(_label));
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.value, '1,5×');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('на паузе место держится: строка не прыгает, чип не ловит касания', (t) async {
      var speed = 0;
      var wave = 0;
      await t.pumpWidget(
        _bubble(playing: true, onSpeed: () => speed++, onWave: () => wave++),
      );
      final playingChip = t.getRect(find.byKey(const ValueKey('chip')));
      final playingTime = t.getRect(find.text('11:20'));
      final playingDur = t.getRect(find.text('0:12'));
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        _bubble(playing: false, onSpeed: () => speed++, onWave: () => wave++),
      );
      expect(t.getRect(find.byKey(const ValueKey('chip'))), playingChip);
      expect(t.getRect(find.text('11:20')), playingTime);
      expect(t.getRect(find.text('0:12')), playingDur);
      expect(find.bySemanticsLabel(_label), findsNothing);
      await t.tapAt(playingChip.center);
      await t.pump(const Duration(milliseconds: 50));
      await t.tapAt(Offset(playingChip.center.dx, playingChip.top - 7));
      await t.pump(const Duration(milliseconds: 50));
      expect(speed, 0);
      expect(wave, 1);
      handle.dispose();
    });
  });

  // ─── Н-10 ─────────────────────────────────────────────────────────────────

  group('Н-10: эффекты не доигрывают поверх другого экрана', () {
    setUp(resetSoloFxForTest);

    Future<BuildContext> openChat(WidgetTester t, GlobalKey<NavigatorState> nav) async {
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: Text('Список чатов')),
        ),
      );
      final chatKey = GlobalKey();
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: SizedBox.expand(key: chatKey)),
        ),
      );
      await t.pumpAndSettle();
      return chatKey.currentContext!;
    }

    SoloEmojiEffect ghost() => soloEmojiEffect(
      '👻',
      screen: const Size(800, 600),
      origin: const Offset(200, 400),
      random: math.Random(1),
    );

    testWidgets('эффект эмодзи снимается, когда чат закрыли', (t) async {
      final nav = GlobalKey<NavigatorState>();
      final chat = await openChat(t, nav);
      expect(
        playSoloEmojiFx(context: chat, effect: ghost(), origin: const Offset(200, 400)),
        isTrue,
      );
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(RouteBoundFx), findsOneWidget);
      nav.currentState!.pop();
      await t.pump();
      await t.pump();
      expect(find.byType(RouteBoundFx), findsNothing);
      await t.pumpAndSettle();
      expect(find.text('Список чатов'), findsOneWidget);
      // Занятость эффекта сброшена — следующий запустится.
      final again = await openChat(t, nav);
      expect(
        playSoloEmojiFx(context: again, effect: ghost(), origin: const Offset(200, 400)),
        isTrue,
      );
      nav.currentState!.pop();
      await t.pumpAndSettle();
    });

    testWidgets('эффект эмодзи доигрывает, если чат на месте', (t) async {
      final nav = GlobalKey<NavigatorState>();
      final chat = await openChat(t, nav);
      playSoloEmojiFx(context: chat, effect: ghost(), origin: const Offset(200, 400));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(RouteBoundFx), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.byType(RouteBoundFx), findsNothing);
    });

    testWidgets('полёт реакции снимается, когда поверх чата открыли страницу; чип не остаётся скрытым', (t) async {
      final nav = GlobalKey<NavigatorState>();
      final chat = await openChat(t, nav);
      const fxId = 'ev1|❤️';
      final reg = ReactionFxRegistry.instance;
      launchReactionFlight(
        context: chat,
        emoji: '❤️',
        start: const Rect.fromLTWH(60, 300, 34, 34),
        bubble: null,
        fxId: fxId,
        haptics: false,
        emojiBuilder: (e, size, play) => Text(e),
      );
      await t.pump();
      expect(reg.of(fxId), ReactionChipFx.waiting);
      expect(find.byType(RouteBoundFx), findsOneWidget);
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Профиль'))),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(RouteBoundFx), findsNothing);
      expect(reg.of(fxId), isNull);
      await t.pumpAndSettle();
    });
  });
}
