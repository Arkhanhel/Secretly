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
// 24.09.2026 блок стал ОДНИМ островком матового стекла, как на телефоне:
// карточка и поле внутри одного стекла, у карточки своей заливки нет, шов —
// волосяная черта, рамка фокуса — одна на весь островок.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/composer.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/glass.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 640, child: child)),
  ),
);

/// Оформление ближайшего к [inner] предка-`Container`.
BoxDecoration decorationAround(WidgetTester t, Finder inner) {
  final box = t.widget<Container>(
    find.ancestor(of: inner, matching: find.byType(Container)).first,
  );
  return box.decoration! as BoxDecoration;
}

/// Рамка фокуса островка — передний слой ближайшего к полю
/// `AnimatedContainer`.
Border frameBorder(WidgetTester t) {
  final frame = t.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.byType(EditableText),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return (frame.foregroundDecoration! as BoxDecoration).border! as Border;
}

Widget reply(TextEditingController ctl, {bool autofocus = false}) => host(
  Composer(
    controller: ctl,
    onSend: (_) {},
    autofocus: autofocus,
    context: const ComposerContext.reply(
      authorName: 'Игорь',
      preview: 'Плюс 40 % к удержанию на второй день…',
    ),
    onClearContext: () {},
  ),
);

void main() {
  testWidgets('◆ карточка ответа и поле — в одном стеклянном островке', (
    t,
  ) async {
    await t.pumpWidget(reply(TextEditingController()));
    final aroundCard = find.ancestor(
      of: find.text('Ответ · Игорь'),
      matching: find.byType(DesktopGlass),
    );
    final aroundField = find.ancestor(
      of: find.byType(EditableText),
      matching: find.byType(DesktopGlass),
    );
    expect(aroundCard, findsOneWidget);
    expect(
      t.element(aroundCard),
      same(t.element(aroundField)),
      reason: 'два стекла — это снова две плашки друг над другом',
    );
  });

  testWidgets('◆ у карточки нет своей заливки, шов — волосяная черта', (
    t,
  ) async {
    await t.pumpWidget(reply(TextEditingController()));
    final d = decorationAround(t, find.text('Ответ · Игорь'));
    expect(d.color, isNull);
    final b = d.border! as Border;
    expect(b.top, BorderSide.none);
    expect(b.bottom.color, kDColorsDark.borderHairline);
  });

  testWidgets('без ответа поле — тот же островок', (t) async {
    await t.pumpWidget(
      host(Composer(controller: TextEditingController(), onSend: (_) {})),
    );
    final glass = t.widget<DesktopGlass>(
      find.ancestor(
        of: find.byType(EditableText),
        matching: find.byType(DesktopGlass),
      ),
    );
    expect(glass.radius, 18);
  });

  testWidgets('🔴 в фокусе рамка ОДНА — у всего островка, цвета акцента', (
    t,
  ) async {
    await t.pumpWidget(reply(TextEditingController(), autofocus: true));
    await t.pump();
    final b = frameBorder(t);
    expect(b.top.color, kDColorsDark.accentPrimary);
    expect(b.top.width, 1.5);
    expect(b.bottom, b.top, reason: 'рамка замкнута, а не собрана из кусков');
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
    expect(frameBorder(t).top.color, Colors.transparent);

    await t.tap(find.byType(EditableText));
    await t.pump();
    expect(ctl.text, isEmpty, reason: 'ни одной буквы не набрано');
    final b = frameBorder(t);
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
