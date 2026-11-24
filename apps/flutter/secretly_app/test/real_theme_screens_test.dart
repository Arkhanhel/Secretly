// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Главные экраны в НАСТОЯЩЕЙ теме приложения («Графит», тема по умолчанию):
// профиль, настройки и их внутренняя страница, список чатов — на Android и
// iPhone. Экраны должны подниматься без ошибок.
//
// `SECRETLY_SHOTS=/папка flutter test test/real_theme_screens_test.dart`
// сохраняет снимки — для сверки цветов и отступов.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/main.dart'
    show appLightBackgroundColors, buildSecretlyThemeForTest;
import 'package:secretly_app/ui/chats_screen.dart';
import 'package:secretly_app/ui/contacts_screen.dart';
import 'package:secretly_app/ui/groups_screen.dart';
import 'package:secretly_app/ui/profile_screen.dart';
import 'package:secretly_app/ui/settings_screen.dart';
import 'package:secretly_app/ui/theme_presets.dart';
import 'package:secretly_app/ui/widgets/app_background.dart';

Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

final String? _shotsDir = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

Future<void> _shoot(WidgetTester t, String name) async {
  final dir = _shotsDir;
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await t.pump();
  await t.runAsync(() async {
    final boundary =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _host(Widget child, Brightness b) {
  final preset = resolveAppThemePreset(AppController.kDefaultAppThemePresetId);
  final theme = buildSecretlyThemeForTest(
    b,
    appPreset: preset,
    bubblePreset: resolveChatBubbleStylePreset(
      AppController.kDefaultBubbleStylePresetId,
    ),
    nicknamePreset: resolveNicknameStylePreset('accent'),
    indicatorPreset: resolveIndicatorColorPreset('theme'),
  );
  final dark = b == Brightness.dark;
  final gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? [preset.darkBgTop, preset.darkBgMid, preset.darkBgBottom]
        : appLightBackgroundColors(preset),
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    // На iPhone приложение берёт системный шрифт Apple, которого в тесте
    // нет; для снимков — Inter, чтобы текст был виден.
    theme: theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
    ),
    builder: (context, nav) => RepaintBoundary(
      key: _shotKey,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: AppBackground(gradient: gradient, dark: dark, child: nav!),
      ),
    ),
    home: child,
  );
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(393 * 3, 852 * 3);
  t.view.devicePixelRatio = 3;
  t.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(t.view.reset);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  // Открытый репозиторий не несёт растров (белый список выкладки): без
  // самих картинок настоящие экраны не нарисовать — проверка молчит по
  // отсутствию файлов (24.11.2026).
  if (!File('assets/app_ui/icons/Settings/w11-notifications.png').existsSync()) {
    test('real_theme_screens_test.dart: нет растров (открытый репозиторий)', () {}, skip: 'no raster assets');
    return;
  }
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final (platform, b, tag) in <(TargetPlatform, Brightness, String)>[
    (TargetPlatform.android, Brightness.dark, 'android_dark'),
    (TargetPlatform.iOS, Brightness.dark, 'ios_dark'),
    (TargetPlatform.android, Brightness.light, 'android_light'),
    (TargetPlatform.iOS, Brightness.light, 'ios_light'),
  ]) {
    testWidgets('profile renders in the real theme ($tag)', (t) async {
      _phone(t);
      final c = AppController();
      await t.pumpWidget(_host(ProfileScreen(controller: c), b));
      await _settle(t);
      expect(t.takeException(), isNull);
      await _shoot(t, 'profile_$tag');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await _settle(t);
      await _shoot(t, 'profile_${tag}_2');
    }, variant: TargetPlatformVariant.only(platform));

    testWidgets('chats list renders in the real theme ($tag)', (t) async {
      _phone(t);
      final c = AppController();
      await t.pumpWidget(_host(ChatsScreen(controller: c), b));
      await _settle(t);
      expect(t.takeException(), isNull);
      await _shoot(t, 'chats_$tag');
      // Список держит таймеры (часы, обновление) — снимаем экран и даём им
      // отработать, иначе тест заканчивается с «висящим» таймером.
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(minutes: 2));
    }, variant: TargetPlatformVariant.only(platform));

    testWidgets('contacts and rooms render ($tag)', (t) async {
      _phone(t);
      final c = AppController();
      await t.pumpWidget(_host(ContactsScreen(controller: c), b));
      await _settle(t);
      expect(t.takeException(), isNull);
      await _shoot(t, 'contacts_$tag');
      await t.pumpWidget(_host(GroupsScreen(controller: c), b));
      await _settle(t);
      expect(t.takeException(), isNull);
      await _shoot(t, 'rooms_$tag');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(minutes: 2));
    }, variant: TargetPlatformVariant.only(platform));

    testWidgets('every settings section opens ($tag)', (t) async {
      _phone(t);
      final c = AppController();
      await t.pumpWidget(_host(SettingsScreen(controller: c), b));
      await _settle(t);
      final l = AppLocalizations.of(t.element(find.byType(SettingsScreen)))!;
      // Разделы, которые открывают страницу внутри приложения.
      final sections = <(String, String)>[
        (l.accountSection, 'account'),
        (l.securityTitle, 'security'),
        (l.devicesSection, 'devices'),
        (l.chatsSection, 'appearance'),
        (l.languageSection, 'language'),
        (l.netSettingsTitle, 'network'),
        (l.settingsRowReliability, 'reliability'),
        (l.settingsRowPower, 'power'),
        (l.storageSection, 'storage'),
        (l.systemSection, 'system'),
        (l.settingsRowSupport, 'support'),
      ];
      for (final (title, shot) in sections) {
        final finder = find.text(title);
        // Список ленивый: дальние строки появляются только при прокрутке.
        for (var i = 0; i < 10 && finder.hitTestable().evaluate().isEmpty; i++) {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -250));
          await _settle(t);
        }
        // Строки, которых нет в этой сборке теста (зависят от dart:io), —
        // пропускаем.
        if (finder.hitTestable().evaluate().isEmpty) continue;
        await t.tap(finder.hitTestable().first);
        await _settle(t);
        expect(t.takeException(), isNull, reason: shot);
        await _shoot(t, 'section_${shot}_$tag');
        Navigator.of(
          t.element(find.byType(SettingsScreen, skipOffstage: false)),
        ).pop();
        await _settle(t);
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(minutes: 2));
    }, variant: TargetPlatformVariant.only(platform));

    testWidgets('settings render in the real theme ($tag)', (t) async {
      _phone(t);
      final c = AppController();
      await t.pumpWidget(_host(SettingsScreen(controller: c), b));
      await _settle(t);
      expect(t.takeException(), isNull);
      await _shoot(t, 'settings_$tag');
      final l = AppLocalizations.of(t.element(find.byType(SettingsScreen)))!;
      for (final (title, shot) in <(String, String)>[
        (l.notificationsSection, 'notifications'),
        (l.privacySection, 'privacy'),
      ]) {
        await t.tap(find.text(title).first);
        await _settle(t);
        expect(t.takeException(), isNull, reason: shot);
        await _shoot(t, 'settings_${shot}_$tag');
        Navigator.of(t.element(find.text(title).last)).pop();
        await _settle(t);
      }
    }, variant: TargetPlatformVariant.only(platform));
  }
}
