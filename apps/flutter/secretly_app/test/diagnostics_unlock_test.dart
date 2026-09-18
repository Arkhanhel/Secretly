// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/diagnostics_unlock.dart';

/// 🔴 РАЗДЕЛ «ДИАГНОСТИКА» СКРЫТ ПО УМОЛЧАНИЮ И ОТКРЫВАЕТСЯ НАМЕРЕННО.
///
/// До 16.08.2026 он был доступен всем прямо из настроек магазинной сборки, а
/// показывает `profile_id`, `device_id`, адреса серверов, состояние очередей и
/// флаги раскатки. Обычному человеку эти строки ничего не говорят, но
/// скопировать и переслать их он может — и отдаст свои идентификаторы, не
/// понимая, что отдал.
void main() {
  const now = 1_800_000_000_000;
  const reset = DiagnosticsUnlock.resetAfter;

  group('счёт нажатий', () {
    test('первое нажатие всегда начинает счёт', () {
      expect(
        DiagnosticsUnlock.nextTapCount(
          previousTaps: 0,
          lastTapAtMs: 0,
          nowMs: now,
        ),
        1,
      );
    });

    test('нажатия подряд складываются', () {
      var taps = 0;
      var last = 0;
      for (var i = 1; i <= DiagnosticsUnlock.tapsRequired; i += 1) {
        taps = DiagnosticsUnlock.nextTapCount(
          previousTaps: taps,
          lastTapAtMs: last,
          nowMs: now + i * 200,
        );
        last = now + i * 200;
        expect(taps, i);
      }
      expect(DiagnosticsUnlock.unlocksAt(taps), isTrue);
    });

    test('🔴 пауза сбрасывает счёт — иначе случайные нажатия за неделю '
        'сложились бы в жест', () {
      final taps = DiagnosticsUnlock.nextTapCount(
        previousTaps: 4,
        lastTapAtMs: now,
        nowMs: now + reset.inMilliseconds + 1,
      );
      expect(taps, 1);
    });

    test('на самой границе паузы нажатие ещё засчитывается', () {
      final taps = DiagnosticsUnlock.nextTapCount(
        previousTaps: 2,
        lastTapAtMs: now,
        nowMs: now + reset.inMilliseconds,
      );
      expect(taps, 3);
    });

    test('🔴 прыжок часов назад не открывает раздел и не ломает счёт', () {
      final taps = DiagnosticsUnlock.nextTapCount(
        previousTaps: 4,
        lastTapAtMs: now,
        nowMs: now - 60 * 1000,
      );
      expect(taps, 1, reason: 'начинаем заново — это предсказуемо для человека');
    });

    test('🔴 четырёх нажатий НЕ хватает', () {
      expect(DiagnosticsUnlock.unlocksAt(4), isFalse);
      expect(DiagnosticsUnlock.unlocksAt(5), isTrue);
    });
  });

  group('подсказка', () {
    test('молчит на первых нажатиях — иначе подсказываем каждому, кто ткнул',
        () {
      expect(DiagnosticsUnlock.remainingHint(1), isNull);
      expect(DiagnosticsUnlock.remainingHint(2), isNull);
    });

    test('появляется на третьем и считает вниз', () {
      expect(DiagnosticsUnlock.remainingHint(3), 2);
      expect(DiagnosticsUnlock.remainingHint(4), 1);
    });

    test('на открывающем нажатии не показывается — там своё сообщение', () {
      expect(DiagnosticsUnlock.remainingHint(5), isNull);
    });
  });
}
