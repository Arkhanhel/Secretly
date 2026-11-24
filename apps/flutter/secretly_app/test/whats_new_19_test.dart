// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Встречайте Secretly 1.9»: приветствие, мини-демо, пометки пером
// (макет «Whats New 1.9», 24.11.2026).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/whats_new/pen_mark.dart';
import 'package:secretly_app/ui/whats_new/whats_new_flow.dart';
import 'package:secretly_app/ui/whats_new/whats_new_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WhatsNew19.enabledForThisRun = false;
    WhatsNew19.sheetOpen.value = false;
    WhatsNew19.tourSettled.value = false;
  });

  testWidgets('🔴 в тестах и без запуска из main окно не всплывает', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      _app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    );
    expect(await maybeShowWhatsNew19(ctx), isFalse);
    await t.pump();
    expect(find.byType(WhatsNewSheet), findsNothing);
  });

  testWidgets('приветствие → «Что нового» → 6 карточек → «Начать» закрывает', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(const WhatsNewSheet()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1600));
    expect(find.text('Meet Secretly 1.9'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    await t.tap(find.text('What’s new'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('What’s new in 1.9'), findsOneWidget);
    expect(find.text('Straight from the notification'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('Next'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Emotions'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    // Карточка 6 отыгрывает весь сценарий без ошибок.
    await t.pump(const Duration(milliseconds: 4800));
    expect(t.takeException(), isNull);
  });

  testWidgets('карточки листаются сами по таймеру 4,5 с', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(const WhatsNewSheet(startWithDemo: true)));
    await t.pump();
    expect(find.text('Straight from the notification'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 4900));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('A fresh look'), findsOneWidget);
  });

  testWidgets('немецкий — длинные строки влезают без переполнения', (t) async {
    await t.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      _app(const WhatsNewSheet(), locale: const Locale('de')),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 1600));
    expect(find.text('Willkommen bei Secretly 1.9'), findsOneWidget);
    await t.tap(find.text('Was ist neu'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull);
  });

  testWidgets('«уменьшить движение» — всё сразу, без полётов', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      _app(
        Builder(
          builder: (c) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: true),
            child: const WhatsNewSheet(startWithDemo: true),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 2500));
    expect(t.takeException(), isNull);
  });

  testWidgets('перо: только после окна, один раз, касание убирает', (t) async {
    WhatsNew19.enabledForThisRun = true;
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      _app(
        Scaffold(
          body: Center(
            child: PenMark(
              hint: PenHint.search,
              round: true,
              child: const SizedBox(width: 52, height: 52),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 600));
    // Окно ещё не закрыто — пера нет.
    expect(find.text('Search by username and contacts'), findsNothing);
    WhatsNew19.tourSettled.value = true;
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 1100));
    expect(find.text('Search by username and contacts'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pen_search_seen_v1'), isTrue);
    await t.tapAt(const Offset(20, 20));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    expect(find.text('Search by username and contacts'), findsNothing);
    WhatsNew19.enabledForThisRun = false;
  });

  test('снимки для карточек есть в обеих темах, сжатые', () {
    // Открытый репозиторий не несёт растров (белый список выкладки):
    // там каталог есть, а снимков нет — проверка молчит по отсутствию
    // самих файлов, а не каталога.
    final shots = Directory('assets/whats_new');
    if (!shots.existsSync() ||
        !shots.listSync().any((f) => f.path.endsWith('.jpg'))) {
      return;
    }
    for (final name in [
      'home', 'chat_unread', 'chat', 'profile', 'settings', 'style',
      'emoji_panel',
    ]) {
      for (final theme in ['dark', 'light']) {
        final f = File('assets/whats_new/shot_${name}_$theme.jpg');
        expect(f.existsSync(), isTrue, reason: f.path);
        expect(f.lengthSync(), lessThan(260 * 1024), reason: f.path);
      }
    }
    expect(File('assets/whats_new/avatar_daniel.jpg').existsSync(), isTrue);
  });

  test('тексты на 8 языках', () {
    const keys = [
      'whatsNewTitle', 'whatsNewSubtitle', 'whatsNewOpen', 'whatsNewLater',
      'whatsNewHeader', 'whatsNewNext', 'whatsNewStart', 'whatsNewClose',
      'whatsNewCard1Title', 'whatsNewCard6Body', 'whatsNewSettingsRow',
      'penHintSearch', 'penHintStyle', 'penHintPanels', 'penHintCovers',
      'penHintEmoji', 'penHintReactions',
    ];
    for (final lang in ['en', 'ru', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de']) {
      final m = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, dynamic>;
      for (final k in keys) {
        expect((m[k] as String?)?.trim(), isNotEmpty, reason: '$lang $k');
      }
    }
  });

  test('🔴 подключено: main включает, главный экран зовёт, настройки', () {
    expect(
      File('lib/main.dart')
          .readAsStringSync()
          .contains('WhatsNew19.enabledForThisRun = true;'),
      isTrue,
    );
    final shell = File('lib/ui/app_shell.dart').readAsStringSync();
    expect(shell.contains('if (await maybeShowWhatsNew19(context)) return;'),
        isTrue);
    expect(shell.contains('key: WhatsNew19.captureKey'), isTrue);
    expect(
      File('lib/ui/settings_screen.dart')
          .readAsStringSync()
          .contains('showWhatsNew19(context, startWithDemo: true)'),
      isTrue,
    );
    for (final (f, h) in [
      ('lib/ui/home/home_islands.dart', 'PenHint.search'),
      ('lib/ui/settings_apple_root.dart', 'PenHint.style'),
      ('lib/ui/settings_screen.dart', 'PenHint.panels'),
      ('lib/ui/profile_screen.dart', 'PenHint.covers'),
      ('lib/ui/chat_screen.dart', 'PenHint.emoji'),
    ]) {
      expect(File(f).readAsStringSync().contains(h), isTrue, reason: f);
    }
  });

  // 🔴 Проверка перед выпуском (24.11.2026): все 8 языков на самых узких
  // экранах — приветствие и шесть карточек без переполнения.
  for (final size in const [Size(320, 568), Size(375, 667)]) {
    for (final loc in const [
      Locale('en'), Locale('ru'), Locale('uk'), Locale('es'), Locale('pt'),
      Locale('pt', 'BR'), Locale('fr'), Locale('de'),
    ]) {
      testWidgets('8 языков: $loc ${size.width.toInt()}×${size.height.toInt()}',
          (t) async {
        await t.binding.setSurfaceSize(size);
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_app(const WhatsNewSheet(), locale: loc));
        await t.pump();
        await t.pump(const Duration(milliseconds: 1600));
        expect(t.takeException(), isNull, reason: 'приветствие $loc');
        final l = await AppLocalizations.delegate.load(loc);
        await t.tap(find.text(l.whatsNewOpen));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        for (var i = 0; i < 6; i++) {
          await t.pump(const Duration(milliseconds: 2400));
          expect(t.takeException(), isNull, reason: 'карточка ${i + 1} $loc');
          if (i < 5) {
            await t.tap(find.text(l.whatsNewNext));
            await t.pump();
            await t.pump(const Duration(milliseconds: 500));
          }
        }
        expect(find.text(l.whatsNewStart), findsOneWidget);
      });
    }
  }

  for (final loc in const [
    Locale('en'), Locale('ru'), Locale('uk'), Locale('es'), Locale('pt'),
    Locale('pt', 'BR'), Locale('fr'), Locale('de'),
  ]) {
    testWidgets('подписи пера: $loc, все шесть, у края экрана', (t) async {
      final l = await AppLocalizations.delegate.load(loc);
      for (final h in PenHint.values) {
        expect(penHintText(l, h).trim(), isNotEmpty, reason: '$loc $h');
      }
      WhatsNew19.enabledForThisRun = true;
      WhatsNew19.tourSettled.value = true;
      await t.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        _app(
          Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: PenMark(
                hint: PenHint.panels,
                child: const SizedBox(width: 120, height: 44),
              ),
            ),
          ),
          locale: loc,
        ),
      );
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 1600));
      expect(t.takeException(), isNull, reason: '$loc');
      expect(find.text(penHintText(l, PenHint.panels)), findsOneWidget);
      WhatsNew19.enabledForThisRun = false;
    });
  }

  test('отрезки времени', () {
    expect(whatsNewSeg(0, 100, 200), 0);
    expect(whatsNewSeg(200, 100, 200), 0.5);
    expect(whatsNewSeg(400, 100, 200), 1);
  });
}
