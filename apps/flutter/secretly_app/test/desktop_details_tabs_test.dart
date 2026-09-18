// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Панель подробностей режется на вкладки.
//
// 🔴 ЧТО БЫЛО. Панель комнаты была ОДНОЙ непрерывной лентой: обложка, портрет,
// кнопки, темы, описание, сведения, переключатели чата, заявки на вступление,
// список участников, забаненные — и в самом низу галерея, у которой СВОИ
// четыре вкладки. Прокрутка внутри прокрутки и экран на три высоты окна: чтобы
// дойти до медиа, нужно было проехать мимо всех участников, а чтобы вернуться
// к переключателю «в архив» — проехать обратно.
//
// Владелец сказал прямо: «она какая-то слишком огромная, нужно укоротить».

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/details/details_info_section.dart';
import 'package:secretly_app/ui/desktop/chat/details/details_tabs.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget host(Widget child) => MaterialApp(
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: SizedBox(width: 360, height: 700, child: child),
        ),
      ),
    );

void main() {
  group('полоса вкладок', () {
    testWidgets('переключает и отмечает выбранную', (t) async {
      var picked = -1;
      await t.pumpWidget(host(StatefulBuilder(
        builder: (ctx, setState) => DetailsTabs(
          tabs: const ['Инфо', 'Участники', 'Медиа'],
          index: picked < 0 ? 0 : picked,
          onChanged: (i) => setState(() => picked = i),
        ),
      )));
      expect(find.text('Участники'), findsOneWidget);
      await t.tap(find.text('Медиа'));
      await t.pumpAndSettle();
      expect(picked, 2);
    });

    testWidgets('одна вкладка полосы не рисует', (t) async {
      await t.pumpWidget(host(
        DetailsTabs(tabs: const ['Инфо'], index: 0, onChanged: (_) {}),
      ));
      expect(find.text('Инфо'), findsNothing,
          reason: 'полоса из одной вкладки ничего не переключает');
    });
  });

  group('🔴 ссылка-приглашение больше не занимает пять строк', () {
    test('короткая форма без протокола и без параметров', () {
      const full =
          'https://links.secretlyapp.com/room-invite/01a09d1ca9f17d20a6bd4d'
          '643c48fdf?by=OD3S-WHK6-CHBM-U-FH54HXA&group=group%3Ae848617d-378';
      final short = DetailsInfoRow.shortUrl(full);
      expect(short.startsWith('links.secretlyapp.com/'), isTrue);
      expect(short.contains('?'), isFalse, reason: 'параметры длиннее ссылки');
      expect(short.length, lessThanOrEqualTo(40));
      expect(short.endsWith('…'), isTrue);
    });

    test('короткую ссылку не портит', () {
      expect(
        DetailsInfoRow.shortUrl('https://secretlyapp.com/i/abc'),
        'secretlyapp.com/i/abc',
      );
    });

    test('пустая остаётся пустой', () {
      expect(DetailsInfoRow.shortUrl('   '), '');
    });
  });

  test('🔴 обе панели подробностей разрезаны на вкладки', () {
    final room = File(
      'lib/ui/desktop/chat/details/room_details_view.dart',
    ).readAsStringSync();
    final contact = File(
      'lib/ui/desktop/chat/details/contact_details_view.dart',
    ).readAsStringSync();
    for (final src in <String>[room, contact]) {
      expect(src.contains('DetailsTabs('), isTrue);
      expect(src.contains('IndexedStack('), isTrue,
          reason: 'вкладка обязана сохранять прокрутку, а не строиться заново');
    }
    expect(room.contains("tabs: const ['Инфо', 'Участники', 'Медиа']"), isTrue);
    expect(contact.contains("tabs: const ['Инфо', 'Медиа']"), isTrue);
    // Галерея лежит ВНУТРИ своей вкладки, а не в конце общей ленты.
    expect(
      room.contains('Widget _mediaTab()') &&
          room.indexOf('DesktopMediaGallery(') >
              room.indexOf('Widget _mediaTab()'),
      isTrue,
    );
  });
}
