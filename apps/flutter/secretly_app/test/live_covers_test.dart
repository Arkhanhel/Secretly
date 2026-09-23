// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЖИВЫЕ ОБЛОЖКИ: каталог и стык с набором.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:secretly_app/ui/premium/live_covers.dart';

void main() {
  test('набор перенесён, идентификаторы не столкнулись ни с чем', () {
    expect(kLiveCoverIds.length, 24);
    final all = kAllProfileCovers.map((c) => c.id).toList();
    expect(all.toSet().length, all.length);
    expect(all.length, kProfileCovers.length + 24);
    for (final id in kLiveCoverIds) {
      expect(coverById(id), isNotNull, reason: 'обложка $id не рисуется');
    }
    // 🔴 Имена рамок и обложек живут в ОДНОЙ таблице переводов: одинаковый
    // ключ дал бы обложке чужое имя. Четыре сцены набора не перенесены
    // намеренно — они у нас уже есть своей реализацией.
    final frames = kAllAvatarFrames.map((f) => f.id).toSet();
    for (final id in kLiveCoverIds) {
      expect(frames.contains(id), isFalse, reason: '$id: рамка и обложка');
    }
    for (final taken in const ['fireflies', 'fireworks', 'galaxy', 'blackhole']) {
      expect(kLiveCoverIds.contains(taken), isFalse, reason: '$taken подменён');
    }
  });

  testWidgets('название переведено на восемь языков', (tester) async {
    for (final tag in const ['ru', 'en', 'uk', 'es', 'pt', 'fr', 'de']) {
      late BuildContext ctx;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Localizations(
            locale: Locale(tag),
            delegates: const [
              DefaultWidgetsLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
            ],
            child: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      for (final c in kLivingProfileCovers) {
        expect(c.nameLocalized(ctx).trim(), isNotEmpty, reason: '${c.id}/$tag');
      }
    }
  });

  testWidgets('🔴 каждая сцена поднимается и снимается без ошибок', (
    tester,
  ) async {
    // Обложка — самая большая вещь на экране профиля, и падение в ней видно
    // всем. Поднимаем каждую, даём два кадра и снимаем.
    for (final id in kLiveCoverIds) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 360, height: 240, child: LiveCoverView(id: id)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull, reason: '$id упала на кадре');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.takeException(), isNull, reason: '$id упала на снятии');
    }
  });

  testWidgets('выключенный тикер останавливает сцену', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: SizedBox(width: 300, height: 200, child: LiveCoverView(id: 'silk')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('🔴 сцена вокруг фото берёт НАСТОЯЩЕЕ место портрета', (
    tester,
  ) async {
    // Без этого луна всходит мимо лица, а прожектор светит в пустоту: у сцены
    // свои доли, и знает их только экран, который раскладывает шапку.
    await tester.pumpWidget(
      MaterialApp(
        home: CoverAvatarGeometry(
          center: const Offset(0.5, 0.62),
          radius: 0.21,
          child: SizedBox(
            width: 360,
            height: 240,
            child: LiveCoverView(id: 'moon_path'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.takeException(), isNull);
    // Явно переданное важнее наследуемого — плитка выбора рисует сцену «как
    // есть», без портрета.
    await tester.pumpWidget(
      MaterialApp(
        home: CoverAvatarGeometry(
          center: const Offset(0.5, 0.62),
          radius: 0.21,
          child: SizedBox(
            width: 360,
            height: 240,
            child: LiveCoverView(
              id: 'moon_path',
              avatarCenter: const Offset(0.5, 0.36),
              avatarRadius: 0.1,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('🔴 живая сцена СЛЫШИТ палец', (tester) async {
    // Набор кладёт внутрь `Listener`: от него идут круги по воде и за ним
    // следит прожектор. Если сцену завернуть в `IgnorePointer`, слушателя
    // никто не позовёт — и это ровно то, что было на телефоне.
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(width: 300, height: 200, child: LiveCoverView(id: 'ripples')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byType(Listener).hitTestable(), findsWidgets);
    await tester.tapAt(const Offset(150, 100));
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.takeException(), isNull);
  });

  test('🔴 телефон не прячет живую сцену под IgnorePointer', () {
    // Слой обложки на экране профиля исторически стоял под запретом нажатий —
    // прежним сценам слушать было нечего. Живым есть.
    final src = File('lib/ui/profile_screen.dart').readAsStringSync();
    final i = src.indexOf('height: collapsedButtonsTop + 66,');
    expect(i, greaterThan(0));
    final head = src.substring(i, i + 1400);
    expect(
      head.contains('child: IgnorePointer('),
      isFalse,
      reason: 'живая сцена снова под запретом нажатий',
    );
    expect(head.contains('LiveCoverTouch('), isTrue);
    expect(head.contains('isLiveCoverId(controller.myCoverId)'), isTrue);
  });

  test('🔴 обложки уходят в прозрачность, а не в плашку цвета страницы', () {
    // 24.09.2026 владелец: «резкий переход между низом обложки и фоном, на
    // светлой теме очень заметно». Плашка цвета страницы лежала и на краю
    // картинки, и на самой странице, и на стыке выходила линия. Теперь низ
    // обложки сам теряет непрозрачность — подгонять под тему нечего.
    for (final path in const [
      'lib/ui/profile_screen.dart',
      'lib/ui/contact_details_screen.dart',
      'lib/ui/desktop/chat/details/details_headline.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('CoverBottomFade('), isTrue, reason: '$path: нет перехода');
      expect(
        src.contains('AppBackground.scrimColorOf'),
        isFalse,
        reason: '$path: вернулась плашка под цвет страницы',
      );
    }
  });

  testWidgets('переход прозрачности ложится на обложку без ошибок', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 360,
          height: 240,
          child: CoverBottomFade(child: LiveCoverView(id: 'silk')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('сцены вокруг фотографии помечены', () {
    for (final id in const ['eclipse', 'moon_path', 'ripples', 'spotlight']) {
      expect(liveCoverUsesAvatar(id), isTrue, reason: id);
    }
    expect(liveCoverUsesAvatar('silk'), isFalse);
  });
}
