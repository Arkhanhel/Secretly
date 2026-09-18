// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

/// ПОЛОЖЕНИЕ ОКНА ПРОКРУТКИ СЧИТАЕТСЯ ОДИН РАЗ ЗА КАДР (правка 03.09.2026).
///
/// Каждая поверхность — градиентный пузырь и матовое окно — звала в своей
/// отрисовке `localToGlobal` у окна прокрутки. Это обход дерева вверх до корня
/// с перемножением преобразований, а дерево экрана чата глубокое. Обход шёл
/// столько раз, сколько поверхностей на экране, и так на каждом кадре подъёма
/// клавиатуры.
///
/// 🔴 ГЛАВНОЕ СВОЙСТВО, КОТОРОЕ НЕЛЬЗЯ ПОТЕРЯТЬ. Ключ кэша — отметка текущего
/// кадра, а НЕ время жизни. Внутри кадра значение переиспользуется, на новом
/// кадре считается заново. Если подменить это «кэшем на N миллисекунд», цвет
/// пузыря начнёт отставать от его геометрии — ровно тот дефект, который чинили
/// 01.08.2026: поднятые клавиатурой пузыри сохраняли окраску прежнего
/// положения, и новое сообщение не совпадало по цвету с соседями.
///
/// Проверяется копия ветвления: настоящий кэш берёт отметку у планировщика,
/// который в тесте не крутится.
class FrameScopedOrigin {
  Object? _frame;
  Offset? _origin;

  int computations = 0;

  Offset originGlobal(Object currentFrame, Offset Function() compute) {
    final cached = _origin;
    if (cached != null && _frame == currentFrame) {
      return cached;
    }
    computations++;
    final origin = compute();
    _frame = currentFrame;
    _origin = origin;
    return origin;
  }
}

void main() {
  group('кэш положения окна на кадр', () {
    test('🔴 десять поверхностей на одном кадре — один обход дерева', () {
      final cache = FrameScopedOrigin();
      const frame = 'frame-1';
      for (var i = 0; i < 10; i++) {
        cache.originGlobal(frame, () => const Offset(0, 120));
      }
      expect(
        cache.computations,
        1,
        reason: 'положение окна на одном кадре одинаково для всех пузырей — '
            'десять обходов дерева здесь были лишними девять раз',
      );
    });

    test('🔴 новый кадр — новый расчёт, отставания быть не может', () {
      final cache = FrameScopedOrigin();
      var y = 0.0;
      final seen = <Offset>[];
      // Подъём клавиатуры: двадцать кадров, окно едет вверх.
      for (var f = 0; f < 20; f++) {
        y = f * 16.0;
        for (var bubble = 0; bubble < 10; bubble++) {
          seen.add(cache.originGlobal('frame-$f', () => Offset(0, y)));
        }
      }
      expect(
        cache.computations,
        20,
        reason: 'по одному разу на кадр вместо двухсот',
      );
      expect(
        seen.last,
        const Offset(0, 19 * 16.0),
        reason: 'последний пузырь последнего кадра обязан видеть АКТУАЛЬНОЕ '
            'положение: иначе цвет отстанет от геометрии — дефект 01.08.2026',
      );
    });

    test('внутри кадра значение не «плывёт»', () {
      final cache = FrameScopedOrigin();
      var callCount = 0;
      final first = cache.originGlobal('f', () {
        callCount++;
        return const Offset(0, 100);
      });
      // Если бы вычислитель вызвали снова, он вернул бы другое — так проверяем,
      // что второй вызов действительно взял кэш, а не пересчитал.
      final second = cache.originGlobal('f', () {
        callCount++;
        return const Offset(0, 999);
      });
      expect(first, second);
      expect(callCount, 1);
    });

    test('смена кадра сбрасывает даже при том же значении', () {
      final cache = FrameScopedOrigin();
      cache.originGlobal('a', () => Offset.zero);
      cache.originGlobal('b', () => Offset.zero);
      expect(
        cache.computations,
        2,
        reason: 'кадр — единственный ключ; совпадение значений роли не играет',
      );
    });
  });
}
