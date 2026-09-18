// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';

/// ЗАМЕР КЭША ГРАДИЕНТНОГО ШЕЙДЕРА (аудит 03.09.2026, жалоба «клавиатура
/// подтормаживает»).
///
/// Цвет пузыря зависит от его положения на экране: градиент — одна лента через
/// весь экран, каждый пузырь берёт свой срез. Клавиатура двигает пузыри, значит
/// на КАЖДОМ кадре её анимации КАЖДЫЙ видимый пузырь перекрашивается, и внутри
/// перекраски создаётся градиентный шейдер.
///
/// Кэш в коде есть, но он ОДНОСЛОТОВЫЙ: хранит один прямоугольник и один
/// шейдер. А прямоугольник вычисляется от положения пузыря, то есть у каждого
/// он свой. Этот тест — замер: он считает попадания и промахи на реальном
/// сценарии и показывает, что при двух и более пузырях кэш не срабатывает
/// никогда.
///
/// Тест намеренно проверяет ОБЕ стратегии, чтобы выигрыш был виден числом, а не
/// на словах.

/// Копия нынешнего кэша: один слот.
class SingleSlotCache {
  Rect? _lastRect;
  Object? _lastShader;

  int hits = 0;
  int misses = 0;

  Object shaderFor(Rect rect) {
    final cached = _lastShader;
    if (cached != null && _lastRect == rect) {
      hits++;
      return cached;
    }
    misses++;
    final shader = Object();
    _lastRect = rect;
    _lastShader = shader;
    return shader;
  }
}

/// Предлагаемая замена: несколько слотов с вытеснением давних.
class MultiSlotCache {
  MultiSlotCache({this.capacity = 16});

  final int capacity;
  final Map<Rect, Object> _slots = <Rect, Object>{};

  int hits = 0;
  int misses = 0;

  Object shaderFor(Rect rect) {
    final cached = _slots.remove(rect);
    if (cached != null) {
      hits++;
      _slots[rect] = cached; // освежаем: снова самый недавний
      return cached;
    }
    misses++;
    final shader = Object();
    if (_slots.length >= capacity) {
      _slots.remove(_slots.keys.first); // вытесняем самый давний
    }
    _slots[rect] = shader;
    return shader;
  }
}

/// Экран с [bubbles] пузырями: у каждого своё смещение по вертикали.
List<Rect> bubbleRects({required int bubbles, required double keyboardOffset}) {
  return List<Rect>.generate(bubbles, (i) {
    // Пузыри идут по экрану с шагом; клавиатура сдвигает их все разом.
    final top = 100.0 + i * 90.0 - keyboardOffset;
    return Rect.fromLTWH(-260, top, 420, 900);
  });
}

void main() {
  group('замер: кэш шейдера при прокрутке', () {
    test('🔴 однослотовый кэш промахивается на КАЖДОМ пузыре', () {
      final cache = SingleSlotCache();
      // Один кадр, десять пузырей на экране, ничего не движется.
      for (final rect in bubbleRects(bubbles: 10, keyboardOffset: 0)) {
        cache.shaderFor(rect);
      }
      expect(
        cache.hits,
        0,
        reason: 'у каждого пузыря свой прямоугольник, поэтому единственный '
            'слот вытесняется следующим же пузырём',
      );
      expect(cache.misses, 10);
    });

    test('многослотовый: первый кадр платит, дальше попадания', () {
      final cache = MultiSlotCache();
      final rects = bubbleRects(bubbles: 10, keyboardOffset: 0);
      for (final rect in rects) {
        cache.shaderFor(rect);
      }
      expect(cache.misses, 10, reason: 'первый кадр создаёт всё честно');

      // Второй кадр без движения — то, что бывает при любой перерисовке
      // (например, тик анимации соседнего элемента).
      for (final rect in rects) {
        cache.shaderFor(rect);
      }
      expect(
        cache.hits,
        10,
        reason: 'ничего не сдвинулось — шейдеры обязаны переиспользоваться',
      );
    });
  });

  group('замер: анимация клавиатуры', () {
    // Подъём клавиатуры это примерно двадцать кадров, за которые пузыри
    // проезжают высоту клавиатуры.
    const frames = 20;
    const bubbles = 10;
    const keyboardHeight = 320.0;

    test('🔴 сколько шейдеров создаётся за один подъём — сейчас', () {
      final cache = SingleSlotCache();
      for (var f = 0; f < frames; f++) {
        final offset = keyboardHeight * (f / (frames - 1));
        for (final rect in bubbleRects(bubbles: bubbles, keyboardOffset: offset)) {
          cache.shaderFor(rect);
        }
      }
      expect(
        cache.misses,
        frames * bubbles,
        reason: 'двести созданий шейдера за одно открытие клавиатуры',
      );
      expect(cache.hits, 0);
    });

    test('многослотовый на анимации: помогает мало, и это ожидаемо', () {
      final cache = MultiSlotCache();
      for (var f = 0; f < frames; f++) {
        final offset = keyboardHeight * (f / (frames - 1));
        for (final rect in bubbleRects(bubbles: bubbles, keyboardOffset: offset)) {
          cache.shaderFor(rect);
        }
      }
      // Каждый кадр даёт НОВЫЕ прямоугольники — попаданий почти нет.
      expect(
        cache.hits,
        lessThan(frames * bubbles ~/ 4),
        reason: 'во время движения кэш по прямоугольнику принципиально не '
            'спасает: геометрия меняется на каждом кадре. Кэш нужен для '
            'ПОКОЯ и прокрутки, а стоимость самой анимации снимается тем, '
            'что из paint убираются обходы дерева',
      );
    });

    test('🔴 после остановки клавиатуры кадры становятся бесплатными', () {
      final cache = MultiSlotCache();
      // Анимация закончилась, клавиатура стоит — но перерисовки продолжаются
      // (курсор, подсказки, тик набора текста).
      final settled = bubbleRects(bubbles: bubbles, keyboardOffset: keyboardHeight);
      for (var f = 0; f < 30; f++) {
        for (final rect in settled) {
          cache.shaderFor(rect);
        }
      }
      expect(cache.misses, bubbles, reason: 'платим один раз за весь покой');
      expect(cache.hits, 29 * bubbles);
    });

    test('однослотовый в покое: платит на каждом кадре заново', () {
      final cache = SingleSlotCache();
      final settled = bubbleRects(bubbles: bubbles, keyboardOffset: keyboardHeight);
      for (var f = 0; f < 30; f++) {
        for (final rect in settled) {
          cache.shaderFor(rect);
        }
      }
      expect(
        cache.misses,
        30 * bubbles,
        reason: 'триста созданий шейдера там, где хватило бы десяти',
      );
    });
  });

  group('вытеснение не ломает длинную ленту', () {
    test('при числе пузырей больше ёмкости кэш не деградирует в ноль', () {
      final cache = MultiSlotCache(capacity: 16);
      final rects = bubbleRects(bubbles: 40, keyboardOffset: 0);
      for (final rect in rects) {
        cache.shaderFor(rect);
      }
      // Второй проход по ПОСЛЕДНИМ шестнадцати — они ещё в кэше.
      for (final rect in rects.sublist(rects.length - 16)) {
        cache.shaderFor(rect);
      }
      expect(
        cache.hits,
        16,
        reason: 'на экране одновременно столько пузырей не бывает, но даже '
            'при переполнении свежие остаются',
      );
    });
  });
}
