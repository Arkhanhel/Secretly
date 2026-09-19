// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Полоса фильтров над списком чатов.
//
// 🔴 Главное, что здесь закреплено: до фильтра, уехавшего за край, ДОЛЖНО быть
// можно добраться, и человек обязан видеть, какой фильтр включён.
//
// Дефект, из-за которого файл появился: при ширине панели 320 точек «Личные»
// начинались на 321-й, а «Архив» не строился вовсе. Полоса при этом выглядела
// прокручиваемой и ей была — но только по оси X, а колесо мыши шлёт один Y.
// Для трекпада это работало, для мыши не работало никак, и разницу нельзя
// заметить, разрабатывая на ноутбуке.
//
// Второе: список показывает не все чаты, а срез, и единственный признак этого
// — подсвеченный чип. Уехал чип за край — интерфейс молча врёт о том, что
// показывает.

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_category_bar.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

/// Настоящая ширина панели списка чатов. На ней фильтры и не помещались.
const double _panelWidth = 320;

/// Подписи ровно те, что строит секция чатов: тест, сторожащий вымышленные
/// названия, перестаёт отвечать на вопрос «помещается ли на самом деле».
const List<ChatCategory> _many = <ChatCategory>[
  ChatCategory(id: '__all', label: 'Все'),
  ChatCategory(id: '__unread', label: 'Непрочит.', badge: 120),
  ChatCategory(id: '__personal', label: 'Личные', locked: true),
  ChatCategory(id: '__archive', label: 'Архив'),
];

const List<ChatCategory> _few = <ChatCategory>[
  ChatCategory(id: '__all', label: 'Все'),
  ChatCategory(id: '__unread', label: 'Непр.'),
];

Widget _host(
  List<ChatCategory> categories,
  String selectedId, {
  double width = _panelWidth,
  ValueChanged<String>? onSelect,
}) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: ChatCategoryBar(
            categories: categories,
            selectedId: selectedId,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      ),
    ),
  ),
);

/// Виден ли чип целиком в границах полосы.
bool _fullyVisible(WidgetTester t, String label) {
  final bar = t.getRect(find.byType(ChatCategoryBar));
  final chip = t.getRect(find.text(label));
  return chip.left >= bar.left - 0.5 && chip.right <= bar.right + 0.5;
}

double _scrollOffset(WidgetTester t) =>
    t.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

void main() {
  group('🔴 колесо мыши', () {
    testWidgets('вертикальное колесо двигает полосу вбок', (t) async {
      await t.pumpWidget(_host(_many, '__all'));
      await t.pumpAndSettle();
      expect(_scrollOffset(t), 0);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      final center = t.getCenter(find.byType(ChatCategoryBar));
      await t.sendEventToBinding(pointer.hover(center));
      await t.sendEventToBinding(pointer.scroll(const Offset(0, 80)));
      await t.pumpAndSettle();

      expect(
        _scrollOffset(t),
        greaterThan(0),
        reason:
            'Flutter отдаёт горизонтальному списку только dx, а колесо '
            'мыши шлёт один dy — без этой подмены до «Архива» мышью было не '
            'добраться вообще',
      );
    });

    testWidgets('колесо не уезжает за конец полосы', (t) async {
      await t.pumpWidget(_host(_many, '__all'));
      await t.pumpAndSettle();

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await t.sendEventToBinding(
        pointer.hover(t.getCenter(find.byType(ChatCategoryBar))),
      );
      for (var i = 0; i < 20; i++) {
        await t.sendEventToBinding(pointer.scroll(const Offset(0, 200)));
      }
      await t.pumpAndSettle();

      final pos = t.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(pos.pixels, pos.maxScrollExtent);
      expect(
        _fullyVisible(t, 'Архив'),
        isTrue,
        reason: 'докрутив до конца, человек обязан увидеть последний фильтр',
      );
    });

    testWidgets('🔴 горизонтальный жест не применяется дважды', (t) async {
      // Рамка сама обрабатывает dx. Если бы полоса добавляла к этому свой
      // сдвиг, трекпад проматывал бы фильтры вдвое быстрее мыши.
      await t.pumpWidget(_host(_many, '__all'));
      await t.pumpAndSettle();

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await t.sendEventToBinding(
        pointer.hover(t.getCenter(find.byType(ChatCategoryBar))),
      );
      await t.sendEventToBinding(pointer.scroll(const Offset(40, 0)));
      await t.pumpAndSettle();

      expect(_scrollOffset(t), 40);
    });

    testWidgets('когда всё помещается, колесо ничего не двигает', (t) async {
      await t.pumpWidget(_host(_few, '__all'));
      await t.pumpAndSettle();

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await t.sendEventToBinding(
        pointer.hover(t.getCenter(find.byType(ChatCategoryBar))),
      );
      await t.sendEventToBinding(pointer.scroll(const Offset(0, 80)));
      await t.pumpAndSettle();

      expect(_scrollOffset(t), 0);
    });
  });

  group('🔴 выбранный фильтр виден', () {
    testWidgets('полоса открывается на выбранном фильтре', (t) async {
      await t.pumpWidget(_host(_many, '__archive'));
      await t.pumpAndSettle();

      expect(
        _fullyVisible(t, 'Архив'),
        isTrue,
        reason:
            'подсвеченный чип — единственное, что объясняет неполный '
            'список чатов; спрятать его значит соврать о содержимом',
      );
    });

    testWidgets('смена выбора подтягивает новый чип', (t) async {
      await t.pumpWidget(_host(_many, '__all'));
      await t.pumpAndSettle();
      expect(_fullyVisible(t, 'Архив'), isFalse, reason: 'исходно он за краем');

      await t.pumpWidget(_host(_many, '__archive'));
      await t.pumpAndSettle();

      expect(_fullyVisible(t, 'Архив'), isTrue);
    });

    testWidgets('видимый чип полосу не двигает', (t) async {
      // Подтягивание МИНИМАЛЬНОЕ. Прыжок полосы при переключении на соседний,
      // и без того видимый фильтр сбивал бы сильнее, чем помогал.
      await t.pumpWidget(_host(_many, '__all'));
      await t.pumpAndSettle();

      await t.pumpWidget(_host(_many, '__unread'));
      await t.pumpAndSettle();

      expect(_scrollOffset(t), 0);
    });

    testWidgets('🔴 строятся ВСЕ чипы, включая уехавшие за край', (t) async {
      // Ленивый список не строил «Архив» вовсе — значит его нельзя было ни
      // подтянуть в видимую часть, ни честно померить для затухания.
      await t.pumpWidget(_host(_many, '__all'));
      await t.pumpAndSettle();

      for (final label in ['Все', 'Непрочит.', 'Личные', 'Архив']) {
        expect(find.text(label), findsOneWidget, reason: 'нет чипа «$label»');
      }
    });
  });

  group('затухание края', () {
    testWidgets('🔴 всё помещается — не гасим ничего', (t) async {
      // Постоянная дымка у края читается как приглушённый, недоступный
      // элемент — то есть ровно наоборот тому, что она должна сообщать.
      await t.pumpWidget(_host(_few, '__all'));
      await t.pumpAndSettle();

      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('не помещается — гасим', (t) async {
      await t.pumpWidget(_host(_many, '__all'));
      await t.pumpAndSettle();

      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('🔴 полоса сузилась — затухание появилось само', (t) async {
      // Окно можно сузить, не коснувшись полосы. Затухание обязано это
      // заметить: оно считается по размерам, а не по факту прокрутки.
      await t.pumpWidget(_host(_many, '__all', width: 900));
      await t.pumpAndSettle();
      expect(find.byType(ShaderMask), findsNothing);

      await t.pumpWidget(_host(_many, '__all', width: 260));
      await t.pumpAndSettle();
      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });

  testWidgets('нажатие на чип по-прежнему выбирает фильтр', (t) async {
    final picked = <String>[];
    await t.pumpWidget(_host(_many, '__all', onSelect: picked.add));
    await t.pumpAndSettle();

    await t.tap(find.text('Непрочит.'));
    await t.pump();

    expect(picked, ['__unread']);
  });

  testWidgets('пустой список категорий полосу не рисует', (t) async {
    await t.pumpWidget(_host(const <ChatCategory>[], '__all'));
    await t.pumpAndSettle();

    expect(find.byType(Scrollable), findsNothing);
  });
}
