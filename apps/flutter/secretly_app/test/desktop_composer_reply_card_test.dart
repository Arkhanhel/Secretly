// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Карточка ответа и поле ввода — ОДИН блок, а не два.
//
// ◆ ЧТО БЫЛО. Карточка «Ответ · Игорь» стояла над полем отдельной плашкой:
// свой замкнутый радиус 10, своя рамка по кругу и 8 точек зазора до поля.
// Получалось две карточки друг над другом, и связь между «кому отвечаю» и
// «что пишу» держалась только их соседством.
//
// В макете это сросшийся блок: у карточки скругление только сверху и нет
// нижней грани, у поля — скругление только снизу; шов между ними — ровно
// одна линия, верхняя граница поля.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/composer.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget host(Widget child) => MaterialApp(
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 640, child: child)),
  ),
);

/// Оформление ближайшего к [text] предка-`Container` с заливкой.
BoxDecoration decorationAround(WidgetTester t, Finder inner) {
  final box = t.widget<Container>(
    find
        .ancestor(of: inner, matching: find.byType(Container))
        .first,
  );
  return box.decoration! as BoxDecoration;
}

void main() {
  testWidgets('◆ у карточки ответа скруглён только верх', (t) async {
    await t.pumpWidget(
      host(
        Composer(
          controller: TextEditingController(),
          onSend: (_) {},
          context: const ComposerContext.reply(
            authorName: 'Игорь',
            preview: 'Плюс 40 % к удержанию на второй день…',
          ),
          onClearContext: () {},
        ),
      ),
    );

    final d = decorationAround(t, find.text('Ответ · Игорь'));
    expect(
      d.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(12)),
    );
    // Нижней грани нет: её роль играет верхняя граница поля, иначе на шве
    // было бы две линии подряд.
    expect((d.border! as Border).bottom, BorderSide.none);
    expect((d.border! as Border).top.width, 1);
  });

  testWidgets('◆ поле под карточкой скруглено только снизу', (t) async {
    final ctl = TextEditingController();
    await t.pumpWidget(
      host(
        Composer(
          controller: ctl,
          onSend: (_) {},
          context: const ComposerContext.reply(
            authorName: 'Игорь',
            preview: 'текст',
          ),
          onClearContext: () {},
        ),
      ),
    );

    final d = decorationAround(t, find.byType(EditableText));
    expect(
      d.borderRadius,
      const BorderRadius.vertical(bottom: Radius.circular(12)),
    );
  });

  testWidgets('без ответа поле скруглено со всех сторон', (t) async {
    await t.pumpWidget(
      host(Composer(controller: TextEditingController(), onSend: (_) {})),
    );
    final d = decorationAround(t, find.byType(EditableText));
    expect(d.borderRadius, BorderRadius.circular(12));
  });

  testWidgets('🔴 в фокусе рамка у обеих частей ОДНА', (t) async {
    // Иначе акцентная линия шва режет сросшийся блок пополам ровно там, где
    // он должен читаться цельным.
    await t.pumpWidget(
      host(
        Composer(
          controller: TextEditingController(),
          onSend: (_) {},
          autofocus: true,
          context: const ComposerContext.reply(
            authorName: 'Игорь',
            preview: 'текст',
          ),
          onClearContext: () {},
        ),
      ),
    );
    await t.pump();

    final card = decorationAround(t, find.text('Ответ · Игорь')).border!
        as Border;
    final field = decorationAround(t, find.byType(EditableText)).border!
        as Border;
    expect(card.top.color, field.top.color);
    expect(card.top.width, field.top.width);
    expect(card.top.color, kDColorsDark.accentPrimary);
    expect(card.top.width, 1.5);
  });

  // 🔴 НАЙДЕНО ПО ДОРОГЕ: рамка фокуса была написана, но не перерисовывалась.
  //
  // Цвет рамки читает `_focus.hasFocus`, а подписки на узел не было ни одной.
  // `TextField` перестраивает себя сам, но рамку рисует контейнер ВОКРУГ
  // него — поэтому акцент появлялся не по щелчку в поле, а с первым набранным
  // символом: его перерисовывал слушатель текста.
  testWidgets('🔴 щелчок в поле красит рамку СРАЗУ, без единой буквы', (
    t,
  ) async {
    final ctl = TextEditingController();
    await t.pumpWidget(host(Composer(controller: ctl, onSend: (_) {})));
    expect(
      (decorationAround(t, find.byType(EditableText)).border! as Border)
          .top
          .color,
      kDColorsDark.borderSubtle,
    );

    await t.tap(find.byType(EditableText));
    await t.pump();

    expect(ctl.text, isEmpty, reason: 'ни одной буквы не набрано');
    final b = decorationAround(t, find.byType(EditableText)).border! as Border;
    expect(b.top.color, kDColorsDark.accentPrimary);
    expect(b.top.width, 1.5);
  });

  test('подписка на фокус снимается вместе с полем', () {
    final src = File(
      'lib/ui/desktop/chat/composer.dart',
    ).readAsStringSync();
    expect(src.contains('_focus.addListener(_onFocus)'), isTrue);
    expect(src.contains('_focus.removeListener(_onFocus)'), isTrue);
  });

  // · МЕЛОЧИ КАРТОЧКИ ИЗ МАКЕТА.
  test('· синий карточки — служебный синий ленты, а не сам акцент', () {
    // #6FA8F7 — им же набраны имя автора в чужом пузыре и галочки доставки.
    // `accentPrimary` (#3E8BF5) на шаг темнее и на подложке поля глуше.
    final src = File(
      'lib/ui/desktop/chat/composer.dart',
    ).readAsStringSync();
    final i = src.indexOf('Widget _contextCard(');
    final body = src.substring(i, (i + 3000).clamp(0, src.length));
    expect(body.contains('color: c.deliveryIndicator'), isTrue);
    expect(body.contains('color: c.accentPrimary,'), isFalse);
  });

  test('· закрытие — скруглённый квадрат, а не таблетка', () {
    // Значок стоит ВНУТРИ карточки с радиусом 12, и кружок в её углу спорил с
    // её собственной формой.
    final src = File(
      'lib/ui/desktop/chat/composer.dart',
    ).readAsStringSync();
    expect(src.contains('radius: DRadii.r8,'), isTrue);
    final btn = File(
      'lib/ui/desktop/primitives/desktop_button.dart',
    ).readAsStringSync();
    // Параметр добавочный: умолчание прежнее, существующие места не меняются.
    expect(btn.contains('final double? radius;'), isTrue);
    expect(btn.contains('BorderRadius.circular(radius ?? DRadii.pill)'), isTrue);
  });

  test('зазора между карточкой и полем больше нет', () {
    final src = File(
      'lib/ui/desktop/chat/composer.dart',
    ).readAsStringSync();
    // Смотрим ИМЕННО карточку ответа: у списка участников над полем свой
    // отступ снизу, и он к шву карточки отношения не имеет.
    final i = src.indexOf('Widget _contextCard(');
    final card = src.substring(i, (i + 3000).clamp(0, src.length));
    expect(card.contains('margin: const EdgeInsets.only(bottom: DSpace.s)'), isFalse);
    // Отступы карточки из макета: 7 сверху и снизу, 9 слева, 10 справа.
    expect(card.contains('EdgeInsets.fromLTRB(9, 7, 10, 7)'), isTrue);
  });
}
