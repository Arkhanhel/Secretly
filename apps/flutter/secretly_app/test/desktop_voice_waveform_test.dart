// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Волна голосового: данные были в протоколе и не доходили до окна.
//
// 🔴 Телефон рисует волну по `payload.waveform` с первого дня, а десктоп
// показывал ровную полоску в четыре точки — одно и то же сообщение выглядело
// на двух устройствах по-разному не потому, что так решили, а потому, что
// поле не прокинули из payload во вложение.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';

void main() {
  group('огибающая сводится к 14 столбикам', () {
    test('пустая даёт спокойный симметричный узор, а не нули', () {
      final bars = voiceWaveformBars(null);
      expect(bars.length, 14);
      expect(bars.every((b) => b > 0), isTrue,
          reason: 'нулевой столбик выглядит дырой в волне');
      // Симметрия: узор честно говорит «данных нет», не притворяясь записью.
      for (var i = 0; i < 7; i++) {
        expect((bars[i] - bars[13 - i]).abs() < 0.0001, isTrue);
      }
    });

    test('длинная огибающая усредняется, а не обрезается', () {
      // 140 значений: первая половина тихая, вторая громкая.
      final raw = <int>[
        for (var i = 0; i < 70; i++) 10,
        for (var i = 0; i < 70; i++) 90,
      ];
      final bars = voiceWaveformBars(raw);
      expect(bars.length, 14);
      expect(bars.first, closeTo(0.10, 0.03));
      expect(bars.last, closeTo(0.90, 0.03));
      expect(bars[6] < bars[7], isTrue, reason: 'переход должен попасть в середину');
    });

    test('короткая огибающая растягивается на все столбики', () {
      final bars = voiceWaveformBars(<int>[100, 0, 100]);
      expect(bars.length, 14);
      expect(bars.any((b) => b > 0.9), isTrue);
    });

    test('тишина не проваливается в ноль', () {
      final bars = voiceWaveformBars(<int>[0, 0, 0, 0]);
      expect(bars.every((b) => b >= 0.12), isTrue,
          reason: 'тишина в середине записи — это тишина, а не обрыв');
    });

    test('значения выше сотни не ломают шкалу', () {
      final bars = voiceWaveformBars(<int>[255, 255, 255]);
      expect(bars.every((b) => b <= 1.0), isTrue);
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
