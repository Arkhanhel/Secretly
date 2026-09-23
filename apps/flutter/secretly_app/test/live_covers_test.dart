// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЖИВЫЕ ОБЛОЖКИ: каталог и стык с набором.
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

  test('сцены вокруг фотографии помечены', () {
    for (final id in const ['eclipse', 'moon_path', 'ripples', 'spotlight']) {
      expect(liveCoverUsesAvatar(id), isTrue, reason: id);
    }
    expect(liveCoverUsesAvatar('silk'), isFalse);
  });
}
