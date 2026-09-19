// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Форма портрета = тип разговора.
//
// 🔴 Почему это сторожится, а не «и так видно».
//
// В списке из сорока строк тип разговора надо понимать боковым зрением, не
// читая. Форма портрета — единственное, что отличает «написать человеку» от
// «написать в комнату», где сообщение увидят двадцать человек. Цена ошибки
// несимметрична, поэтому отличие сделано грубым — и обязано таким остаться.
//
// Второе, что здесь закреплено и что легко потерять: ЦВЕТ у комнат и людей
// общий. Соблазн дать комнатам свою палитру (как в макете) возвращается при
// каждой правке оформления, а стоит он того, что одна и та же комната станет
// зелёной на столе и синей в кармане. Люди узнают чаты по цветному пятну.

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_list_panel.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/avatar.dart';
import 'package:secretly_app/ui/widgets/shared_palette.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: Center(child: child),
    ),
  ),
);

/// Оформление самого портрета — первый Container внутри [Avatar].
BoxDecoration _decorationOf(WidgetTester t) {
  final box = t.widget<Container>(
    find
        .descendant(of: find.byType(Avatar), matching: find.byType(Container))
        .first,
  );
  return box.decoration! as BoxDecoration;
}

/// Цвет инициалов внутри портрета.
Color _initialsColorOf(WidgetTester t) {
  final text = t.widget<Text>(
    find.descendant(of: find.byType(Avatar), matching: find.byType(Text)).first,
  );
  return text.style!.color!;
}

void main() {
  group('форма', () {
    testWidgets('человек — круг', (t) async {
      await t.pumpWidget(_host(const Avatar(name: 'Игорь', size: 46)));
      await t.pump();

      final d = _decorationOf(t);
      expect(d.shape, BoxShape.circle);
      expect(d.borderRadius, isNull, reason: 'у круга скругления нет вовсе');
    });

    testWidgets('🔴 комната — скруглённый квадрат', (t) async {
      await t.pumpWidget(
        _host(
          const Avatar(
            name: 'Secretly Core',
            size: 46,
            shape: AvatarShape.room,
          ),
        ),
      );
      await t.pump();

      final d = _decorationOf(t);
      expect(d.shape, BoxShape.rectangle);
      expect(d.borderRadius, BorderRadius.circular(46 * 0.33));
    });

    test('🔴 скругление — ДОЛЯ размера, а не число точек', () {
      // Портрет живёт в шести размерах: 32 в поиске, 40 в звонках, 46 в
      // списке, 88 в шапке, 96 в подробностях. Фиксированные 14 точек из
      // макета на 32-м выглядели бы почти квадратом, на 96-м — почти кругом.
      for (final size in <double>[32, 40, 46, 88, 96]) {
        expect(Avatar.roomRadius(size) / size, closeTo(0.33, 0.001));
      }
      // Размер из макета даёт его же радиус — доля подобрана по нему.
      expect(Avatar.roomRadius(42), closeTo(14, 0.2));
    });
  });

  group('🔴 цвет общий с телефоном', () {
    testWidgets('🔴 цвет комнаты считается ОБЩЕЙ с телефоном палитрой', (
      t,
    ) async {
      // Своя палитра для комнат развела бы стол и телефон: одна и та же
      // комната стала бы зелёной здесь и синей в кармане.
      const a = 'Secretly Core';
      const b = 'Release Radar';

      await t.pumpWidget(
        _host(const Avatar(name: a, size: 46, shape: AvatarShape.room)),
      );
      await t.pump();
      final first = _decorationOf(t).color;

      await t.pumpWidget(
        _host(const Avatar(name: b, size: 46, shape: AvatarShape.room)),
      );
      await t.pump();

      expect(
        _decorationOf(t).color,
        isNot(first),
        reason: 'две разные комнаты обязаны отличаться пятном',
      );
    });

    // 🔴 ЛЮДИ ТОЖЕ ЦВЕТНЫЕ (15.09.2026, указание владельца).
    //
    // До этого цветными были только комнаты: так читался исходник макета, где
    // у всех людей заливка нейтральная. Владелец решил иначе, и довод сильный:
    // на телефоне человек без фотографии УЖЕ цветной, и один и тот же
    // собеседник выходил на двух устройствах разным — на телефоне синий, на
    // компьютере серый.
    //
    // Разница между устройствами осталась, но теперь она про ЯРКОСТЬ: на
    // телефоне яркая заливка и белые буквы, на компьютере приглушённая заливка
    // и цветные буквы.
    testWidgets('🔴 разные люди — разные пятна', (t) async {
      await t.pumpWidget(_host(const Avatar(name: 'Игорь', size: 46)));
      await t.pump();
      final one = _decorationOf(t).color;
      final oneInk = _initialsColorOf(t);

      // «Анна» и «Игорь» попадают в разные ступени палитры — проверено
      // хэшем, а не на глаз.
      await t.pumpWidget(_host(const Avatar(name: 'Анна', size: 46)));
      await t.pump();

      expect(
        _decorationOf(t).color,
        isNot(one),
        reason: 'два разных человека обязаны отличаться пятном',
      );
      expect(_initialsColorOf(t), isNot(oneInk));
      // И это НЕ прежний нейтральный серый.
      expect(one, isNot(kDColorsDark.avatarNeutral));
      expect(oneInk, isNot(kDColorsDark.avatarNeutralInk));
    });

    testWidgets('🔴 человек и комната одного ключа — одного цвета', (t) async {
      // Приём один на оба вида: приглушённая заливка того же оттенка и буквы
      // того же оттенка. Разница между ними — ФОРМА, а не цвет.
      await t.pumpWidget(_host(const Avatar(name: 'Секрет', size: 46)));
      await t.pump();
      final personFill = _decorationOf(t).color;
      final personInk = _initialsColorOf(t);

      await t.pumpWidget(
        _host(const Avatar(name: 'Секрет', size: 46, shape: AvatarShape.room)),
      );
      await t.pump();
      expect(_decorationOf(t).color, personFill);
      expect(_initialsColorOf(t), personInk);
    });

    // 🔴 ОТТЕНОК СЧИТАЕТСЯ ПО ТОМУ ЖЕ КЛЮЧУ, ЧТО У ТЕЛЕФОНА.
    //
    // Телефон сеет палитру по `profileId` / `convoId`, десктоп сеял по ИМЕНИ:
    // один человек выходил на двух устройствах разного цвета, а переименование
    // меняло оттенок только на компьютере.
    testWidgets('🔴 ключ важнее имени', (t) async {
      await t.pumpWidget(
        _host(const Avatar(name: 'Игорь', seed: 'PID-1', size: 46)),
      );
      await t.pump();
      final byId = _decorationOf(t).color;

      // Переименовали — цвет остался прежним.
      await t.pumpWidget(
        _host(const Avatar(name: 'Игорь Петров', seed: 'PID-1', size: 46)),
      );
      await t.pump();
      expect(_decorationOf(t).color, byId);

      // А другой профиль с тем же именем — другого цвета.
      await t.pumpWidget(
        _host(const Avatar(name: 'Игорь', seed: 'PID-2', size: 46)),
      );
      await t.pump();
      expect(_decorationOf(t).color, isNot(byId));
    });

    testWidgets('🔴 заглушка ПРИГЛУШЕНА, а цвет живёт в буквах', (t) async {
      // 14.09.2026, макет владельца. Было: яркий градиент во всю плитку и
      // белые буквы поверх — в списке из тридцати чатов это давало радугу, в
      // которой тонули непрочитанное, «в сети» и выбранная строка.
      const name = 'Secretly Core';
      final palette = sharedAvatarGradientColors(name);

      await t.pumpWidget(
        _host(const Avatar(name: name, size: 46, shape: AvatarShape.room)),
      );
      await t.pump();

      final d = _decorationOf(t);
      expect(
        d.gradient,
        isNull,
        reason: 'заливка ровная: градиент во всю плитку и был той самой радугой',
      );
      final fill = d.color!;
      for (final bright in palette) {
        expect(
          fill,
          isNot(bright),
          reason: 'заливка обязана быть приглушённой, а не палитровой в упор',
        );
      }
      // Приглушённая — значит ТЕМНЕЕ любой из палитровых.
      expect(
        fill.computeLuminance(),
        lessThan(palette.first.computeLuminance()),
      );

      final ink = _initialsColorOf(t);
      expect(
        ink,
        isNot(Colors.white),
        reason: 'цвет переехал в буквы — белыми они больше не бывают',
      );
    });


  });

  group('🔴 рамки доступны и комнатам', () {
    // 13.09 я сначала запретил рамки на квадратном портрете, рассудив, что это
    // личное украшение. Рассуждение было неверным: `RoomSettings` несёт
    // `frameId` — комнатные рамки существуют в модели и покупаются так же.
    //
    // Настоящая трудность была не в праве, а в геометрии: кольцо круглое, и
    // скруглённый квадрат углами вылезает за него. Поэтому у квадрата посадка
    // глубже — и это единственное, что здесь стоит сторожить: доля выведена
    // арифметикой, и «подровнять» её на глаз значит выпустить углы за кольцо.
    test('квадрат сидит в кольце глубже круга', () {
      // Кольцо: внутренний край по окружности 0,43 × size.
      const ringInner = 0.43;
      // Скруглённый квадрат стороной a с радиусом угла 0,33a: самая дальняя
      // точка на √2 × (0,5a − 0,33a) + 0,33a.
      double cornerReach(double side) =>
          1.4142 * (0.5 * side - 0.33 * side) + 0.33 * side;

      const roomInset = 0.123;
      final side = 1.0 - roomInset * 2;

      expect(
        cornerReach(side),
        lessThanOrEqualTo(ringInner + 0.001),
        reason:
            'угол квадрата обязан остаться ВНУТРИ кольца — иначе рамка '
            'выглядит браком, а не украшением',
      );
      // И не «с запасом на всякий случай»: лишняя посадка уменьшает сам
      // портрет, ради которого рамка и нужна.
      expect(cornerReach(side), greaterThan(ringInner - 0.02));
    });

    testWidgets('у комнаты с рамкой кольцо рисуется', (t) async {
      await t.pumpWidget(
        _host(
          const Avatar(
            name: 'Secretly Core',
            size: 96,
            shape: AvatarShape.room,
            frameId: 'flame',
            allowAnimatedFrame: true,
          ),
        ),
      );
      await t.pump();

      expect(
        find.descendant(
          of: find.byType(Avatar),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
        reason: 'слой кольца строится, когда рамка действительно рисуется',
      );
    });
  });

  group('список чатов раздаёт форму по типу', () {
    Widget list(ChatKind kind) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DColors(
          colors: kDColorsDark,
          child: SizedBox(
            width: 320,
            height: 400,
            child: ChatListPanel(
              items: [
                ChatListItem(
                  id: 'c1',
                  name: 'Secretly Core',
                  preview: 'привет',
                  time: '14:02',
                  kind: kind,
                ),
              ],
              selectedId: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );

    testWidgets('личная переписка — круг', (t) async {
      await t.pumpWidget(list(ChatKind.direct));
      await t.pump();
      expect(t.widget<Avatar>(find.byType(Avatar)).shape, AvatarShape.round);
    });

    testWidgets('группа — квадрат', (t) async {
      await t.pumpWidget(list(ChatKind.group));
      await t.pump();
      expect(t.widget<Avatar>(find.byType(Avatar)).shape, AvatarShape.room);
    });

    testWidgets('канал — тоже квадрат', (t) async {
      // Канал это комната, куда нельзя ответить. Что туда пишут многие —
      // общее с комнатой, поэтому и форма общая; отличает его значок рупора.
      await t.pumpWidget(list(ChatKind.channel));
      await t.pump();
      expect(t.widget<Avatar>(find.byType(Avatar)).shape, AvatarShape.room);
    });
  });
}
