// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Какой участок общего перехода достаётся пузырю.
//
// Заливка своих пузырей принадлежит ЭКРАНУ, а не пузырю: один переход на всю
// видимую область, и каждый пузырь показывает тот кусок, над которым стоит.
// Раньше каждый красился сам по себе — у длинного сообщения переход проходил
// весь путь, у короткого «ок» тот же путь на двадцати точках, и подряд это
// читалось как набор одинаковых полосок.
//
// Здесь закреплено само правило. Подписка на прокрутку и рисование — уже не
// решение, а исполнение; ломается обычно правило.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/screen_gradient.dart';

void main() {
  const viewportHeight = 800.0;

  test('переход строится на высоту видимой области, а не пузыря', () {
    final r = screenGradientRect(
      bubble: const Rect.fromLTWH(40, 100, 200, 44),
      topInViewport: 100,
      viewportHeight: viewportHeight,
    );

    expect(r.height, viewportHeight,
        reason: 'иначе короткий пузырь снова пройдёт весь переход сам');
    expect(r.width, 200, reason: 'по ширине пузырь берёт свою полосу');
  });

  test('пузырь у верха видимой области берёт НАЧАЛО перехода', () {
    final bubble = const Rect.fromLTWH(40, 0, 200, 44);
    final r = screenGradientRect(
      bubble: bubble,
      topInViewport: 0,
      viewportHeight: viewportHeight,
    );

    expect(r.top, bubble.top,
        reason: 'верх пузыря совпал с верхом перехода — это первый цвет');
  });

  test('пузырь у низа берёт КОНЕЦ перехода', () {
    // Пузырь стоит почти у нижнего края: до низа перехода остаётся его высота.
    final r = screenGradientRect(
      bubble: const Rect.fromLTWH(40, 756, 200, 44),
      topInViewport: viewportHeight - 44,
      viewportHeight: viewportHeight,
    );

    expect(r.bottom, 800.0,
        reason: 'низ пузыря упёрся в низ перехода — это последний цвет');
  });

  test('у всех пузырей переход ОДИН И ТОТ ЖЕ — разные у них куски', () {
    // Так это выглядит в жизни: пузырь стоит на холсте там же, где и в видимой
    // области, поэтому `bubble.top` и `topInViewport` совпадают.
    const near = Rect.fromLTWH(40, 10, 200, 44);
    const far = Rect.fromLTWH(40, 600, 200, 44);

    final top = screenGradientRect(
      bubble: near,
      topInViewport: near.top,
      viewportHeight: viewportHeight,
    );
    final bottom = screenGradientRect(
      bubble: far,
      topInViewport: far.top,
      viewportHeight: viewportHeight,
    );

    // 🔴 Суть правки. Переход у обоих начинается в одной точке — у верха
    // видимой области, — и тянется на одну высоту. Именно поэтому верхний
    // пузырь показывает его начало, а нижний — середину: разные у них не
    // переходы, а КУСКИ одного перехода. Если эти рамки разойдутся, вернётся
    // прежнее «у каждого пузыря свой градиент».
    expect(top.top, bottom.top);
    expect(top.height, bottom.height);

    // И проверим, что куски действительно разные: доля перехода, на которой
    // сидит пузырь, считается от его положения внутри общей рамки.
    double shareAt(Rect gradient, Rect bubble) =>
        (bubble.top - gradient.top) / gradient.height;

    expect(shareAt(top, near), lessThan(shareAt(bottom, far)));
  });

  test('при прокрутке участок едет вместе с положением, а не с пузырём', () {
    const bubble = Rect.fromLTWH(40, 300, 200, 44);

    final before = screenGradientRect(
      bubble: bubble,
      topInViewport: 300,
      viewportHeight: viewportHeight,
    );
    // Прокрутили на 120 вверх: пузырь на холсте там же, но выше в видимой области.
    final after = screenGradientRect(
      bubble: bubble,
      topInViewport: 180,
      viewportHeight: viewportHeight,
    );

    expect(after.top - before.top, 120,
        reason: 'переход остался на месте — по нему поехал пузырь');
  });

  test('пузырь, уехавший за верхний край, продолжает тот же переход', () {
    final r = screenGradientRect(
      bubble: const Rect.fromLTWH(40, 0, 200, 44),
      topInViewport: -30, // верх пузыря выше верха видимой области
      viewportHeight: viewportHeight,
    );

    expect(r.top, 30,
        reason: 'начало перехода осталось выше пузыря, а не прыгнуло к нему');
  });

  test('пузырь ВЫШЕ окна получает переход не короче себя', () {
    // Длинное сообщение на низком окне. Если строить переход по высоте окна,
    // он кончится раньше пузыря и весь низ зальётся одним последним цветом.
    const tall = Rect.fromLTWH(40, 0, 200, 1200);
    final r = screenGradientRect(
      bubble: tall,
      topInViewport: 0,
      viewportHeight: 400,
    );

    expect(r.height, tall.height,
        reason: 'иначе низ длинного пузыря станет одноцветным');
  });

  test('без вменяемой видимой области остаётся прежний вид', () {
    const bubble = Rect.fromLTWH(40, 100, 200, 44);

    for (final bad in <double>[0, -1, double.nan, double.infinity]) {
      expect(
        screenGradientRect(
          bubble: bubble,
          topInViewport: 100,
          viewportHeight: bad,
        ),
        bubble,
        reason: 'лучше прежняя заливка по пузырю, чем пустое место',
      );
    }
  });

  test('без вменяемого положения остаётся прежний вид', () {
    const bubble = Rect.fromLTWH(40, 100, 200, 44);

    expect(
      screenGradientRect(
        bubble: bubble,
        topInViewport: double.nan,
        viewportHeight: viewportHeight,
      ),
      bubble,
    );
  });

  group('кэш шейдеров', () {
    setUp(ScreenGradientShaders.resetForTest);
    tearDown(ScreenGradientShaders.resetForTest);

    const blue = Color(0xFF6366F1);
    const violet = Color(0xFF5046E5);

    test('одинаковые цвета — один переход на весь экран', () {
      final a = ScreenGradientShaders.of(const [blue, violet]);
      final b = ScreenGradientShaders.of(const [blue, violet]);

      expect(identical(a, b), isTrue,
          reason: 'иначе у каждого пузыря снова свой кэш, и он не доживёт '
              'до второго обращения');
      expect(ScreenGradientShaders.paletteCount, 1);
    });

    test('смена темы честно даёт другой переход', () {
      ScreenGradientShaders.of(const [blue, violet]);
      ScreenGradientShaders.of(const [violet, blue]);

      expect(ScreenGradientShaders.paletteCount, 2,
          reason: 'порядок цветов — часть ключа, иначе подсунутся старые');
    });

    test('повторная отрисовка того же места шейдер НЕ пересоздаёт', () {
      final p = ScreenGradientShaders.of(const [blue, violet]);
      const rect = Rect.fromLTWH(0, 0, 200, 800);

      final first = p.shaderFor(rect);
      final second = p.shaderFor(rect);

      expect(identical(first, second), isTrue);
      expect(p.cachedShaderCount, 1);
    });

    test('десять пузырей держатся в кэше одновременно', () {
      // 🔴 Суть правки. Прямоугольник считается от положения пузыря, поэтому у
      // каждого он свой. С одним слотом следующий пузырь вытеснял бы
      // предыдущего и попаданий не было бы никогда.
      final p = ScreenGradientShaders.of(const [blue, violet]);
      final rects = List<Rect>.generate(
        10,
        (i) => Rect.fromLTWH(0, i * 60.0, 200, 800),
      );

      for (final r in rects) {
        p.shaderFor(r);
      }
      expect(p.cachedShaderCount, 10);

      // Второй проход по тем же местам — покой при поднятой панели: ни одного
      // нового шейдера.
      final before = p.cachedShaderCount;
      for (final r in rects) {
        p.shaderFor(r);
      }
      expect(p.cachedShaderCount, before);
    });

    test('кэш не разрастается в словарь на всю переписку', () {
      final p = ScreenGradientShaders.of(const [blue, violet]);
      for (var i = 0; i < 200; i++) {
        p.shaderFor(Rect.fromLTWH(0, i * 7.0, 200, 800));
      }

      expect(p.cachedShaderCount, lessThanOrEqualTo(24),
          reason: 'шейдеры держат ресурсы видеопамяти — вытеснение обязательно');
    });
  });
}
