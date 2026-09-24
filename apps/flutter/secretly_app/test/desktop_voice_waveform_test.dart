// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Волна голосового — тонкими штрихами, как в Telegram.
//
// 🔴 История. Сначала десктоп рисовал ровную полоску: огибающая была в
// протоколе, но не доходила из payload во вложение. Потом появилась волна из
// четырнадцати столбиков на всю ширину пузыря — каждый растягивался на свою
// долю и выходил толстым бруском. 24.09.2026 владелец попросил привычный вид:
// много тонких штрихов, число — от ширины, толщина постоянная.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/chat/voice_waveform.dart';

void main() {
  group('штрихи тонкие, число — от ширины', () {
    test('толщина постоянная, шаг — штрих плюс зазор', () {
      expect(kVoiceBarWidth, 2.0);
      expect(voiceBarCount(200), 56); // (200 + 1.6) / 3.6
      expect(voiceBarCount(3.6 * 10 - kVoiceBarGap), 10);
    });

    test('🔴 шире место — больше штрихов, а не толще', () {
      expect(voiceBarCount(300), greaterThan(voiceBarCount(200)));
      expect(
        voiceBarCount(200),
        greaterThan(14),
        reason: 'четырнадцать брусков на всю ширину — это и было «широко»',
      );
    });

    test('пустая или невозможная ширина даёт один штрих, а не падение', () {
      expect(voiceBarCount(0), 1);
      expect(voiceBarCount(double.infinity), 1);
    });
  });

  group('огибающая сводится к числу штрихов', () {
    test('без данных — ровная невысокая дуга, а не выдуманная запись', () {
      final bars = voiceWaveformHeights(null, 41);
      expect(bars.length, 41);
      expect(bars.every((b) => b >= 0.22 && b <= 0.4), isTrue);
      for (var i = 0; i < 20; i++) {
        expect((bars[i] - bars[40 - i]).abs() < 1e-9, isTrue);
      }
    });

    test('длинная сводится пиком отрезка и нормируется по громкому месту', () {
      final raw = <int>[
        for (var i = 0; i < 70; i++) 10,
        for (var i = 0; i < 70; i++) 90,
      ];
      final bars = voiceWaveformHeights(raw, 14);
      expect(bars.length, 14);
      expect(bars.first, closeTo(0.1 + 0.9 * 10 / 90, 1e-9));
      expect(
        bars.last,
        closeTo(1.0, 1e-9),
        reason: 'самое громкое место записи — во всю высоту',
      );
      expect(bars[6] < bars[7], isTrue, reason: 'переход — посередине');
    });

    test('🔴 короткий всплеск не теряется при сжатии', () {
      // Усреднение размазало бы одиночный пик по отрезку в полку.
      final raw = List<int>.filled(200, 0)..[100] = 100;
      final bars = voiceWaveformHeights(raw, 20);
      expect(bars.reduce((a, b) => a > b ? a : b), closeTo(1.0, 1e-9));
    });

    test('короткая растягивается плавно, без ступенек', () {
      final bars = voiceWaveformHeights(<int>[0, 100], 11);
      expect(bars.first, closeTo(0.1, 1e-9));
      expect(bars.last, closeTo(1.0, 1e-9));
      expect(bars[5], closeTo(0.55, 1e-9));
      for (var i = 1; i < bars.length; i++) {
        expect(bars[i] > bars[i - 1], isTrue);
      }
    });

    test('тишина не проваливается в ноль', () {
      final bars = voiceWaveformHeights(<int>[0, 0, 0, 0], 8);
      expect(
        bars.every((b) => b >= 0.1),
        isTrue,
        reason: 'тишина в середине записи — это тишина, а не обрыв',
      );
    });

    test('тихая запись растягивается, но не притворяется громкой', () {
      final bars = voiceWaveformHeights(<int>[20, 20, 20], 6);
      expect(bars.every((b) => (b - 0.55).abs() < 1e-9), isTrue);
    });

    test('значения выше сотни не ломают шкалу', () {
      final bars = voiceWaveformHeights(<int>[255, 255, 255], 5);
      expect(bars.every((b) => b <= 1.0), isTrue);
    });
  });

  group('ширина пузыря растёт с длиной записи', () {
    test('от 230 до 320 за первую минуту, дальше не растёт', () {
      expect(voiceBubbleMinWidth(Duration.zero), 230);
      expect(voiceBubbleMinWidth(const Duration(seconds: 30)), 275);
      expect(voiceBubbleMinWidth(const Duration(seconds: 60)), 320);
      expect(voiceBubbleMinWidth(const Duration(minutes: 10)), 320);
    });
  });

  group('полосы в пузыре', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          // 🔴 Голосовой пузырь обёрнут в IntrinsicWidth — ровно так, как в
          // живом окне. Строитель разметки здесь уронил бы проверку.
          child: IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200),
              child: Row(children: [Expanded(child: child)]),
            ),
          ),
        ),
      ),
    );

    testWidgets('волна живёт внутри IntrinsicWidth и перематывает по месту', (
      t,
    ) async {
      double? sought;
      await t.pumpWidget(
        host(
          DesktopVoiceWaveform(
            progress: 0.3,
            played: Colors.white,
            unplayed: Colors.white24,
            semanticsLabel: 'Воспроизведение голосового',
            waveform: const <int>[10, 50, 90, 50, 10],
            onSeek: (f) => sought = f,
          ),
        ),
      );
      expect(t.takeException(), isNull);
      final box = t.getRect(find.byType(DesktopVoiceWaveform));
      expect(box.width, 200);
      await t.tapAt(Offset(box.left + box.width / 4, box.center.dy));
      expect(sought, closeTo(0.25, 0.01));
    });

    testWidgets('без перемотки волна не ловит нажатия', (t) async {
      await t.pumpWidget(
        host(
          const DesktopVoiceWaveform(
            progress: 0,
            played: Colors.white,
            unplayed: Colors.white24,
            semanticsLabel: 'Воспроизведение голосового',
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(DesktopVoiceWaveform),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });

    testWidgets('дорожка песни перематывает протяжкой', (t) async {
      final sought = <double>[];
      await t.pumpWidget(
        host(
          DesktopAudioSeekLine(
            progress: 0.5,
            played: Colors.white,
            unplayed: Colors.white24,
            semanticsLabel: 'Воспроизведение',
            onSeek: sought.add,
          ),
        ),
      );
      final box = t.getRect(find.byType(DesktopAudioSeekLine));
      await t.dragFrom(
        Offset(box.left + 20, box.center.dy),
        Offset(box.width * 0.6, 0),
      );
      expect(sought, isNotEmpty);
      expect(sought.last, greaterThan(0.5));
    });
  });

  test('🔴 вложение несёт огибающую и длительность', () {
    const att = MessageAttachment(
      kind: MessageAttachmentKind.voice,
      blobId: 'b',
      payloadEventId: 'e',
      durationMs: 24000,
      waveform: <int>[1, 2, 3],
    );
    expect(att.waveform, isNotNull);
    expect(att.durationMs, 24000);
  });
}
