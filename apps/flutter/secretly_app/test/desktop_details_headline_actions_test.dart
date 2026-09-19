// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Кнопки панели подробностей лежат на обложке, а имя пишется один раз.
//
// 🔴 ЧТО БЫЛО. Панель начиналась со строки-шапки в 56 точек: крестик, ИМЯ,
// подпись присутствия, «⋮». Имя и присутствие при этом уже стояли под
// портретом двумя строками ниже — и третий раз в шапке самой переписки.
// Человек открывал панель ради того, что НИЖЕ, а первые 56 точек уходили на
// повтор того, что он и так видит.
//
// Этот тест держит две вещи: имя в блоке ровно одно, и три действия
// (закрыть · поделиться · дополнительно) живут прямо на обложке.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:secretly_app/ui/desktop/chat/details/details_headline.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/context_menu.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: SizedBox(width: 360, height: 700, child: child),
    ),
  ),
);

void main() {
  testWidgets('имя выводится один раз', (t) async {
    await t.pumpWidget(
      host(
        const DetailsHeadline(
          name: 'Игорь',
          presence: 'в сети',
          avatar: SizedBox(width: 88, height: 88),
        ),
      ),
    );
    expect(find.text('Игорь'), findsOneWidget);
    expect(find.text('в сети'), findsOneWidget);
  });

  testWidgets('три действия лежат на обложке', (t) async {
    var closed = 0;
    var shared = 0;
    await t.pumpWidget(
      host(
        DetailsHeadline(
          name: 'Команда',
          cover: const ColoredBox(color: Color(0xFF223344)),
          avatar: const SizedBox(width: 88, height: 88),
          onClose: () => closed++,
          onShare: () => shared++,
          shareTooltip: 'Скопировать приглашение',
          menuSections: <List<CtxMenuItem>>[
            [CtxMenuItem(label: 'Копировать ID', onTap: () {})],
          ],
        ),
      ),
    );

    expect(find.byIcon(FluentIcons.dismiss_24_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.share_24_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.more_vertical_24_regular), findsOneWidget);

    await t.tap(find.byIcon(FluentIcons.dismiss_24_regular));
    await t.tap(find.byIcon(FluentIcons.share_24_regular));
    await t.pump();
    expect(closed, 1);
    expect(shared, 1);
  });

  testWidgets('без обложки кнопки всё равно видны и нажимаются', (t) async {
    var closed = 0;
    await t.pumpWidget(
      host(
        DetailsHeadline(
          name: 'Комната',
          avatar: const SizedBox(width: 88, height: 88),
          onClose: () => closed++,
        ),
      ),
    );
    expect(find.byIcon(FluentIcons.dismiss_24_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.share_24_regular), findsNothing);
    await t.tap(find.byIcon(FluentIcons.dismiss_24_regular));
    await t.pump();
    expect(closed, 1);
  });

  testWidgets('без действий блок остаётся прежним', (t) async {
    await t.pumpWidget(
      host(
        const DetailsHeadline(
          name: 'Никто',
          avatar: SizedBox(width: 88, height: 88),
        ),
      ),
    );
    expect(find.byIcon(FluentIcons.dismiss_24_regular), findsNothing);
    expect(find.byIcon(FluentIcons.more_vertical_24_regular), findsNothing);
  });

  // 🔴 «СМЕНИТЬ ОБЛОЖКУ» — НА САМОЙ ОБЛОЖКЕ.
  //
  // Обложку меняли только из ряда действий ниже, и связи между кнопкой и
  // картинкой не было никакой: человек видит обложку, хочет её поменять — и
  // ищет, где.
  testWidgets('кнопка смены обложки лежит на обложке', (t) async {
    var changed = 0;
    await t.pumpWidget(
      host(
        DetailsHeadline(
          name: 'Yurii',
          cover: const ColoredBox(color: Color(0xFF223344)),
          avatar: const SizedBox(width: 88, height: 88),
          onChangeCover: () => changed++,
        ),
      ),
    );
    // Плитка, а не подпись: у обложки-фона свободного угла под широкую
    // кнопку нет ни одного — проверено живьём, подпись накрывала сперва чипы
    // «PRO» и «Рамка», потом портрет.
    expect(find.byTooltip('Сменить обложку'), findsOneWidget);
    await t.tap(find.byIcon(FluentIcons.image_24_regular));
    await t.pump();
    expect(changed, 1);
  });

  testWidgets('🔴 без обложки кнопки «сменить» нет', (t) async {
    // На пустом месте «сменить» нечего — там работает «Обложка» в ряду
    // действий.
    await t.pumpWidget(
      host(
        const DetailsHeadline(
          name: 'Yurii',
          avatar: SizedBox(width: 88, height: 88),
        ),
      ),
    );
    expect(find.byTooltip('Сменить обложку'), findsNothing);
  });

  test('чужой профиль кнопку не получает', () {
    final contact = File(
      'lib/ui/desktop/chat/details/contact_details_view.dart',
    ).readAsStringSync();
    final room = File(
      'lib/ui/desktop/chat/details/room_details_view.dart',
    ).readAsStringSync();
    expect(contact.contains('onChangeCover'), isFalse);
    expect(room.contains('onChangeCover'), isFalse);
  });
}
