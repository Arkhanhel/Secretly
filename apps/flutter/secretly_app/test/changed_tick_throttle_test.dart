// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// ДРОССЕЛЬ СБРОСА КЭША СПИСКА БЕСЕД (найдено 02.09.2026, аудит доставки).
///
/// Подписка на `changed` в `AppController` сбрасывала кэш списка бесед на
/// каждом тике. Обнуление бесплатно, дорого следствие: очередной
/// `listConversations()` идёт в базу пятью запросами. При разборе почтового
/// ящика тик приходит на каждое применённое сообщение, поэтому пачка из
/// шестидесяти давала до шестидесяти полных перезагрузок на потоке кадров.
///
/// Здесь закреплены три свойства правки, каждое из которых легко потерять при
/// последующем редактировании:
///
///   1. первый тик после паузы обслуживается НЕМЕДЛЕННО — одиночное сообщение
///      не должно ждать окна;
///   2. подавленный тик НЕ теряется — он выполняется в конце окна, иначе
///      список чатов остался бы без последнего сообщения пачки;
///   3. отложенное срабатывание не порождает бесконечную цепочку — к моменту
///      его тика окно истекло, поэтому следующий проход идёт по немедленной
///      ветке и нового таймера не ставит.
///
/// Проверяется точная копия ветвления из `AppController`, а не сам контроллер:
/// он тянет за собой базу, платформенные каналы и сеть. Копия сверяется с
/// оригиналом глазами — тест ловит смену ПОВЕДЕНИЯ, а не опечатку.
class _ThrottleHarness {
  _ThrottleHarness({required this.windowMs});

  final int windowMs;

  /// Часы. В отличие от первой версии этого теста они ИДУТ: срабатывание
  /// таймера двигает их на реально прошедшее время. Неподвижные часы скрывали
  /// бы ровно тот дефект, ради которого тест написан.
  int nowMs = 0;

  /// Живёт ли кэш. Дроссель выходит сразу, когда сбрасывать нечего.
  bool cacheFilled = true;

  int invalidations = 0;
  int selfTicks = 0;
  Timer? _timer;
  int _lastAtMs = 0;
  bool _selfTickPending = false;

  bool get hasPendingTimer => _timer != null;

  void onChangedTick() {
    if (_selfTickPending) {
      _selfTickPending = false;
      return;
    }
    if (!cacheFilled) return;
    final elapsed = nowMs - _lastAtMs;
    if (elapsed >= windowMs || elapsed < 0) {
      _timer?.cancel();
      _timer = null;
      _lastAtMs = nowMs;
      invalidations++;
      cacheFilled = false;
      return;
    }
    if (_timer != null) return;
    final delayMs = windowMs - elapsed;
    _timer = Timer(Duration(milliseconds: delayMs), () {
      _timer = null;
      nowMs += delayMs; // часы идут вместе с таймером
      _lastAtMs = nowMs;
      invalidations++;
      cacheFilled = false;
      selfTicks++;
      _selfTickPending = true;
      // 🔴 Доставка ОТЛОЖЕНА на следующий оборот цикла событий — так же, как
      // `_changed.add` в контроллере, который коалесцирует тики через
      // `Timer.run`. Синхронный вызов здесь скрывал бы дефект: кэш в этот
      // момент ещё пуст, и вторая защёлка выпускала бы тик сама, из-за чего
      // тест проходил бы и БЕЗ флага собственного тика.
      //
      // Время в тестах виртуальное (04.09.2026): с реальными задержками эти
      // проверки плыли под нагрузкой и давали ложные падения.
      Timer.run(onChangedTick);
    });
  }

  /// Экран прочитал список — кэш снова заполнен. Именно это в бою и
  /// поддерживало бы цепочку, не будь флага собственного тика.
  void screenReloaded() => cacheFilled = true;

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

void main() {
  group('дроссель сброса кэша списка бесед', () {
    test('первый тик после паузы проходит немедленно', () {
      final h = _ThrottleHarness(windowMs: 100);
      h.nowMs = 5000;
      h.onChangedTick();
      expect(
        h.invalidations,
        1,
        reason: 'одиночное сообщение обязано обновить список сразу, '
            'без ожидания окна',
      );
      expect(h.hasPendingTimer, isFalse);
      h.dispose();
    });

    test('пачка внутри окна даёт один немедленный сброс, остальные подавлены',
        () {
      final h = _ThrottleHarness(windowMs: 100);
      h.nowMs = 5000;
      h.onChangedTick(); // первый — немедленно
      h.screenReloaded(); // экран отрисовал список, кэш снова живой
      for (var i = 1; i <= 59; i++) {
        h.nowMs = 5000 + i; // 59 тиков плотной пачкой внутри окна
        h.onChangedTick();
      }
      expect(
        h.invalidations,
        1,
        reason: 'шестьдесят тиков внутри окна — ровно один сброс, '
            'остальные подавлены; до правки их было бы шестьдесят, '
            'и каждый тянул за собой пять запросов к базе',
      );
      expect(
        h.hasPendingTimer,
        isTrue,
        reason: 'подавленные тики обязаны оставить отложенный сброс',
      );
      h.dispose();
    });

    test('подавленный сброс всё-таки происходит в конце окна', () {
      fakeAsync((async) {
        final h = _ThrottleHarness(windowMs: 100);
        h.nowMs = 5000;
        h.onChangedTick();
        h.screenReloaded();
        h.nowMs = 5010;
        h.onChangedTick(); // подавлен, ставит таймер на 90 мс

        expect(h.invalidations, 1, reason: 'окно ещё не истекло');

        async.elapse(const Duration(milliseconds: 250));

        expect(
          h.invalidations,
          2,
          reason: 'последнее сообщение пачки не должно потеряться: '
              'кэш обязан быть сброшен по истечении окна',
        );
        expect(
          h.selfTicks,
          1,
          reason: 'без тика changed экраны не перечитали бы список '
              'и последнее сообщение не появилось бы в чатах',
        );
        h.dispose();
      });
    });

    test('отложенный тик не запускает бесконечную цепочку', () {
      fakeAsync((async) {
        final h = _ThrottleHarness(windowMs: 60);
        h.nowMs = 5000;
        h.onChangedTick();
        h.screenReloaded();
        h.nowMs = 5010;
        h.onChangedTick(); // подавлен, ставит отложенный сброс

        // Экран перечитывает список постоянно — значки непрочитанного подписаны
        // на тот же поток. Поэтому к моменту доставки нашего собственного тика
        // кэш успевает снова заполниться, и вторая защёлка его НЕ остановит:
        // цепочку обрывает только флаг собственного тика.
        final refill = Timer.periodic(
          const Duration(milliseconds: 1),
          (_) => h.screenReloaded(),
        );

        async.elapse(const Duration(milliseconds: 500));
        refill.cancel();

        expect(
          h.selfTicks,
          1,
          reason: 'ровно один отложенный сброс. Без флага собственного тика '
              'здесь была бы вечная цепочка: сброс шлёт тик, тик видит живой '
              'кэш и невышедшее окно, ставит новый сброс — и так каждые '
              'шестьдесят миллисекунд, с перестройкой всех экранов',
        );
        expect(
          h.hasPendingTimer,
          isFalse,
          reason: 'цепочка обязана останавливаться сама',
        );
        h.dispose();
      });
    });

    test('скачок часов назад не подвешивает сброс', () {
      final h = _ThrottleHarness(windowMs: 100);
      h.nowMs = 5000;
      h.onChangedTick();
      h.screenReloaded();
      h.nowMs = 1000; // перевод системных часов назад
      h.onChangedTick();
      expect(
        h.invalidations,
        2,
        reason: 'отрицательная разница времени обязана вести в немедленную '
            'ветку, иначе сброс завис бы до совпадения часов',
      );
      h.dispose();
    });

    test('редкие тики никогда не подавляются', () {
      final h = _ThrottleHarness(windowMs: 100);
      for (var i = 0; i < 20; i++) {
        h.nowMs = 5000 + i * 500; // раз в полсекунды — обычная работа
        h.onChangedTick();
        h.screenReloaded();
      }
      expect(
        h.invalidations,
        20,
        reason: 'вне пачки поведение обязано совпадать с прежним: '
            'каждый тик сбрасывает кэш',
      );
      h.dispose();
    });
  });
}
