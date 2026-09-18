// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

/// КУРСОР ЯЩИКА ПИСАЛСЯ НА КАЖДОЕ СООБЩЕНИЕ (найдено 02.09.2026, аудит
/// скорости доставки).
///
/// Запись идёт через платформенный канал в хранилище настроек. На пачке из
/// шестидесяти конвертов это шестьдесят обращений через канал, и все — в
/// главном изоляте, вперемежку с расшифровкой и отрисовкой кадров.
///
/// 🔴 ПОЧЕМУ ДРОССЕЛЬ ЗДЕСЬ БЕЗОПАСЕН, хотя курсор — часть модели надёжности.
/// Он защищает от ПОВТОРНОЙ ВЫДАЧИ, а не от потери. Если процесс убьют между
/// записями, курсор откатится на несколько сообщений, реле переотдаст их — и
/// они отсеются: `inboxHasSeen` проверяется ПЕРЕД расшифровкой, а
/// `inboxMarkSeen` пишется в базу ещё до подтверждения реле. Отметка «уже
/// видели» переживает падение надёжнее самого курсора.
///
/// Условие, без которого правка становится опасной: отложенный курсор ОБЯЗАН
/// дописываться в конце слива. Иначе последняя пачка осталась бы за пределами
/// сохранённого значения — и реле переотдавало бы её при каждом подключении.
class _CursorHarness {
  _CursorHarness({required this.minIntervalMs});
  final int minIntervalMs;
  int nowMs = 0;
  final List<int> writes = <int>[];
  int? _pending;
  int _lastAtMs = 0;
  Future<void> save(int value) async {
    final elapsed = nowMs - _lastAtMs;
    if (elapsed >= minIntervalMs || elapsed < 0) {
      _lastAtMs = nowMs;
      _pending = null;
      writes.add(value);
      return;
    }
    _pending = value;
  }
  Future<void> flush() async {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    _lastAtMs = nowMs;
    writes.add(pending);
  }
}
void main() {
  group('дроссель записи курсора', () {
    test('🔴 пачка из шестидесяти даёт единицы записей, а не шестьдесят',
        () async {
      final h = _CursorHarness(minIntervalMs: 250);
      // Разбор идёт быстро: примерно 20 мс на конверт.
      for (var i = 1; i <= 60; i++) {
        h.nowMs = i * 20;
        await h.save(i);
      }
      await h.flush();
      expect(
        h.writes.length,
        lessThan(10),
        reason: 'до правки было шестьдесят обращений через платформенный '
            'канал, все в главном изоляте',
      );
      expect(
        h.writes.last,
        60,
        reason: 'итоговое значение обязано быть записано, иначе реле '
            'переотдаст последнюю пачку при следующем подключении',
      );
    });
    test('🔴 отложенный курсор дописывается в конце слива', () async {
      final h = _CursorHarness(minIntervalMs: 250);
      h.nowMs = 1000;
      await h.save(10); // первая запись проходит сразу
      h.nowMs = 1010;
      await h.save(11); // подавлена
      h.nowMs = 1020;
      await h.save(12); // подавлена
      expect(h.writes, [10], reason: 'внутри окна пишется только первая');
      await h.flush();
      expect(
        h.writes,
        [10, 12],
        reason: 'без дописывания в finally сообщения 11 и 12 остались бы за '
            'пределами курсора навсегда',
      );
    });
    test('редкие сообщения пишутся сразу, как раньше', () async {
      final h = _CursorHarness(minIntervalMs: 250);
      for (var i = 1; i <= 5; i++) {
        h.nowMs = i * 1000; // раз в секунду — обычная переписка
        await h.save(i);
      }
      expect(
        h.writes,
        [1, 2, 3, 4, 5],
        reason: 'вне пачки поведение обязано совпадать с прежним',
      );
    });
    test('повторный сброс не пишет дважды', () async {
      final h = _CursorHarness(minIntervalMs: 250);
      h.nowMs = 500;
      await h.save(7);
      h.nowMs = 510;
      await h.save(8);
      await h.flush();
      await h.flush();
      expect(h.writes, [7, 8], reason: 'второй сброс пуст — писать нечего');
    });
    test('скачок часов назад не подвешивает запись', () async {
      final h = _CursorHarness(minIntervalMs: 250);
      h.nowMs = 5000;
      await h.save(1);
      h.nowMs = 1000; // перевод системных часов назад
      await h.save(2);
      expect(
        h.writes,
        [1, 2],
        reason: 'отрицательная разница обязана вести в немедленную ветку',
      );
    });
  });
}
