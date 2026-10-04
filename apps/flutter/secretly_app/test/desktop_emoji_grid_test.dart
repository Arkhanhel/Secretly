// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 СЕТКА ЭМОДЗИ И ЭМОДЗИ-СТАТУС ПК (29.09.2026).
//
// Жалобы владельца: «эмодзистатусы на пк имеют не все эмодзи, которые есть у
// нас в мобильной» (на ПК было 16 знаков против 611 у телефона) и эмодзи
// при выборе «не как у нас». Сетка вынесена в общий виджет: весь каталог,
// подписи на языке окна, «Недавние», ленивая раскладка.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/emoji_grid.dart';
import 'package:secretly_app/ui/desktop/chat/noto_emoji_lottie.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/emoji/noto_emoji_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: Center(child: SizedBox(width: 360, height: 400, child: child)),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('каталог — тот же, что у телефона: без вариантов тона', () {
    final all = desktopEmojiCatalogGroups()
        .expand((g) => g.emoji)
        .toList(growable: false);
    final expected = kNotoCodepoints.keys
        .where((e) => !kNotoSkinToneHidden.contains(e))
        .length;
    expect(all.length, expected);
    expect(all.length, greaterThan(600), reason: 'было 16 знаков в статусе');
    expect(all.toSet().length, all.length, reason: 'без повторов');
    expect(all, contains('🫡'));
  });

  test('поиск по словам, а не по коду', () {
    final hits = desktopEmojiCatalogGroups(
      query: 'heart',
    ).expand((g) => g.emoji);
    expect(hits, contains('❤️'));
    final ru = desktopEmojiCatalogGroups(query: 'сердце').expand((g) => g.emoji);
    expect(ru, contains('❤️'));
  });

  test('недавние: последний сверху, без повторов, не больше 32', () async {
    for (var i = 0; i < 40; i++) {
      await DesktopEmojiRecents.record('k', 'e$i');
    }
    await DesktopEmojiRecents.record('k', 'e39');
    final r = await DesktopEmojiRecents.load('k');
    expect(r.length, DesktopEmojiRecents.max);
    expect(r.first, 'e39');
    expect(r.where((e) => e == 'e39').length, 1);
  });

  testWidgets('подписи категорий — на языке окна', (t) async {
    await t.pumpWidget(_host(DesktopEmojiGrid(onPicked: (_) {})));
    await t.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.desktopEmojiSmileys), findsWidgets);
    expect(find.text('Смайлики и эмоции'), findsNothing);
    expect(find.text('СМАЙЛИКИ И ЭМОЦИИ'), findsNothing);
  });

  testWidgets('сетка ленивая: строится только видимое', (t) async {
    await t.pumpWidget(_host(DesktopEmojiGrid(onPicked: (_) {})));
    await t.pumpAndSettle();
    final built = find.byWidgetPredicate(
      (w) => w is Text && kNotoCodepoints.containsKey(w.data),
    );
    expect(built.evaluate().length, lessThan(200));
    expect(built.evaluate().length, greaterThan(20));
  });

  testWidgets('выбор отдаёт знак и попадает в «Недавние»', (t) async {
    String? picked;
    await t.pumpWidget(
      _host(
        DesktopEmojiGrid(
          recentsKey: kDesktopStatusRecentsKey,
          onPicked: (e) => picked = e,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('😀').first);
    await t.pumpAndSettle();
    expect(picked, '😀');
    expect(await DesktopEmojiRecents.load(kDesktopStatusRecentsKey), ['😀']);
  });

  testWidgets('полоса категорий ведёт к разделу', (t) async {
    await t.pumpWidget(_host(DesktopEmojiGrid(onPicked: (_) {})));
    await t.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.desktopEmojiFlags), findsNothing);
    await t.tap(find.byTooltip(l10n.desktopEmojiFlags));
    await t.pumpAndSettle();
    expect(find.text(l10n.desktopEmojiFlags), findsOneWidget);
  });

  group('🔴 эмодзи-статус', () {
    final view = File(
      'lib/ui/desktop/chat/details/self_profile_view.dart',
    ).readAsStringSync();

    test('весь каталог, а не зашитые 16 знаков', () {
      expect(view.contains('DesktopEmojiGrid('), isTrue);
      expect(view.contains("'😀', '😎', '🥳', '🤝', '💼'"), isFalse);
      expect(view.contains('kDesktopStatusRecentsKey'), isTrue);
    });

    test('показ — анимацией Noto везде, как на телефоне', () {
      for (final path in const <String>[
        'lib/ui/desktop/chat/chat_list_panel.dart',
        'lib/ui/desktop/chat/chat_thread_panel.dart',
        'lib/ui/desktop/chat/details/details_headline.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('DesktopStatusEmoji('), isTrue, reason: path);
      }
    });

    testWidgets('«Анимация рамок и статусов» выключена — первый кадр', (
      t,
    ) async {
      DesktopUiPrefs.animatePeerCosmetics.value = false;
      addTearDown(() => DesktopUiPrefs.animatePeerCosmetics.value = true);
      await t.pumpWidget(_host(const DesktopStatusEmoji(emoji: '😎', size: 18)));
      var lottie = t.widget<NotoEmojiLottie>(find.byType(NotoEmojiLottie));
      expect(lottie.mode, NotoLottieMode.preview);
      DesktopUiPrefs.animatePeerCosmetics.value = true;
      await t.pump();
      lottie = t.widget<NotoEmojiLottie>(find.byType(NotoEmojiLottie));
      expect(lottie.mode, NotoLottieMode.looping);
      expect(find.bySemanticsLabel('😎'), findsOneWidget);
    });

    // 🔴 Контроллер анимации заводится один раз: без пересоздания выключенная
    // настройка оставляла крутиться уже запущенный цикл.
    testWidgets('переключили «Анимацию» — анимация пересоздаётся, а не крутится дальше', (
      t,
    ) async {
      DesktopUiPrefs.animatePeerCosmetics.value = true;
      addTearDown(() => DesktopUiPrefs.animatePeerCosmetics.value = true);
      await t.pumpWidget(_host(const DesktopStatusEmoji(emoji: '😎', size: 18)));
      final looping = t.state(find.byType(NotoEmojiLottie));
      DesktopUiPrefs.animatePeerCosmetics.value = false;
      await t.pump();
      final still = t.state(find.byType(NotoEmojiLottie));
      expect(still, isNot(same(looping)));
      expect(
        t.widget<NotoEmojiLottie>(find.byType(NotoEmojiLottie)).mode,
        NotoLottieMode.preview,
      );
      DesktopUiPrefs.animatePeerCosmetics.value = true;
      await t.pump();
      expect(t.state(find.byType(NotoEmojiLottie)), isNot(same(still)));
    });

    test('статус — украшение Premium, как на телефоне', () {
      final pick = view.substring(view.indexOf('Future<void> _pickEmojiStatus()'));
      final gate = pick.indexOf('isCosmeticAllowed(');
      final dialog = pick.indexOf('DesktopDialog.show');
      expect(gate, greaterThan(0));
      expect(gate, lessThan(dialog), reason: 'проверка — до окна выбора');
      expect(pick.contains('desktopProfileEmojiStatusPremiumOnly'), isTrue);
    });
  });
}
