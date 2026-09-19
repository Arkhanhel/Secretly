// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Шапка правой панели стоит ПО ЦЕНТРУ, а не у левого края.
//
// 🔴 Почему это ловится тестом, а не глазом.
//
// Внутри блока всё было сцентрировано с самого начала: у колонки центр по
// умолчанию, у имени `TextAlign.center`, у значков `WrapAlignment.center`.
// И при этом на экране аватар с именем стояли слева.
//
// Причина не в блоке, а в его окружении: с обложкой блок лежит в [Stack].
// Стопка отдаёт непозиционированному ребёнку свободные ограничения и
// прижимает его к левому верхнему углу — колонка схлопывается по содержимому,
// и «по центру» начинает означать «по центру схлопнутого столбика».
//
// Такую поломку невозможно заметить по коду виджета: он выглядит правильным.
// Видно её только по КООРДИНАТАМ на настоящей раскладке — поэтому проверка
// меряет положение, а не ищет строки.

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/details/details_headline.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

const double _panelWidth = 330;

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: _panelWidth, child: child),
      ),
    ),
  ),
);

/// Насколько центр виджета отстоит от центра панели, в точках.
double _offsetFromCenter(WidgetTester t, Finder f) {
  final box = t.getRect(f);
  return (box.center.dx - _panelWidth / 2).abs();
}

/// Меряем ГРУППУ, а не отдельную надпись внутри неё.
///
/// 🔴 Тонкость, на которой проверка чуть не получилась ложной. Имя стоит в
/// строке вместе со звездой премиума, а слово «PRO» — в значке вместе с
/// иконкой. Центрируется строка целиком, поэтому сама надпись честно смещена
/// влево на половину соседа: имя на 15 точек, «PRO» на 8,5. Померив надпись,
/// тест обвинил бы в перекосе правильную раскладку.
Finder _groupOf(Finder leaf, Type group) =>
    find.ancestor(of: leaf, matching: find.byType(group)).first;

Widget _avatar() => Container(
  key: const Key('avatar'),
  width: 96,
  height: 96,
  color: const Color(0xFF123456),
);

void main() {
  // Допуск: половина точки на округления раскладки. Не «около центра» — центр.
  const eps = 0.5;

  testWidgets('🔴 с обложкой аватар и имя по центру панели', (t) async {
    await t.pumpWidget(
      _host(
        DetailsHeadline(
          name: 'Игорь',
          avatar: _avatar(),
          cover: const ColoredBox(color: Color(0xFF203040)),
          presence: 'был(а) недавно',
          premiumBadge: true,
        ),
      ),
    );
    await t.pump();

    expect(
      _offsetFromCenter(t, find.byKey(const Key('avatar'))),
      lessThan(eps),
      reason: 'именно этот случай и был сломан: Stack прижимал блок влево',
    );
    expect(
      _offsetFromCenter(t, _groupOf(find.text('Игорь'), Row)),
      lessThan(eps),
      reason: 'имя со звездой премиума — одна группа, центрируется целиком',
    );
    expect(_offsetFromCenter(t, find.text('был(а) недавно')), lessThan(eps));
    expect(
      _offsetFromCenter(t, find.byType(Wrap)),
      lessThan(eps),
      reason: 'значки премиума — это «инфа о премиум» из просьбы владельца',
    );
  });

  testWidgets('без обложки центр тот же', (t) async {
    // У комнаты обложки может не быть вовсе. Два вида одного блока не имеют
    // права разъезжаться: человек переключает чаты подряд и видит прыжок.
    await t.pumpWidget(
      _host(
        DetailsHeadline(
          name: 'Secretly Core',
          avatar: _avatar(),
          presence: '12 участников',
        ),
      ),
    );
    await t.pump();

    expect(_offsetFromCenter(t, find.byKey(const Key('avatar'))), lessThan(eps));
    expect(
      _offsetFromCenter(t, _groupOf(find.text('Secretly Core'), Row)),
      lessThan(eps),
    );
    expect(_offsetFromCenter(t, find.text('12 участников')), lessThan(eps));
  });

  testWidgets('🔴 блок занимает ВСЮ ширину панели, а не ширину имени', (
    t,
  ) async {
    // Корень поломки: когда блок уже панели, центрировать внутри него
    // бессмысленно. Сторожим сам размер, чтобы поломка не вернулась через
    // другую разметку.
    await t.pumpWidget(
      _host(
        DetailsHeadline(
          name: 'Ия',
          avatar: _avatar(),
          cover: const ColoredBox(color: Color(0xFF203040)),
        ),
      ),
    );
    await t.pump();

    expect(t.getSize(find.byType(DetailsHeadline)).width, _panelWidth);
  });

  testWidgets('длинное имя переносится, но не сдвигает блок', (t) async {
    await t.pumpWidget(
      _host(
        DetailsHeadline(
          name: 'Александра Константинопольская-Вышневолоцкая',
          avatar: _avatar(),
          cover: const ColoredBox(color: Color(0xFF203040)),
          premiumBadge: true,
        ),
      ),
    );
    await t.pump();

    expect(_laidOutWithoutOverflow(t), isTrue);
    expect(_offsetFromCenter(t, find.byKey(const Key('avatar'))), lessThan(eps));
  });
}

/// Раскладка уложилась без переполнения: у теста не осталось исключений.
bool _laidOutWithoutOverflow(WidgetTester t) => t.takeException() == null;
