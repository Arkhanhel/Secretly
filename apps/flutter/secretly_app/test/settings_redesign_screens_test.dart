// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Новые экраны настроек (20.11.2026) поднимаются без ошибок на iPhone и
// Android, на русском и английском, а поиск и выбор стиля значков работают.
//
// `SECRETLY_SHOTS=/папка flutter test test/settings_redesign_screens_test.dart`
// дополнительно сохраняет снимки экранов — для сверки с макетом.
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
import 'package:secretly_app/ui/chat_appearance_screen.dart';
import 'package:secretly_app/ui/settings_apple_root.dart';
import 'package:secretly_app/ui/settings_icons/settings_glyph_tile.dart';
import 'package:secretly_app/ui/settings_icons/settings_glyphs.dart';
import 'package:secretly_app/ui/settings_icons/settings_icon_style.dart';
import 'package:secretly_app/ui/settings_root_model.dart';

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

Widget _host(Widget child, {required Locale locale, required Brightness b}) {
  final dark = b == Brightness.dark;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2AABEE),
        brightness: b,
      ),
    ),
    builder: (context, nav) => RepaintBoundary(
      key: _shotKey,
      // Фон приложения — плавный градиент, как у страниц Secretly.
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF1B2440), Color(0xFF0E1424), Color(0xFF2A1430)]
                : const [Color(0xFFDCE6FF), Color(0xFFF1F2F8), Color(0xFFF7DDEB)],
          ),
        ),
        child: nav,
      ),
    ),
    home: child,
  );
}

Future<void> _shoot(WidgetTester t, String name) async {
  final dir = _shotsDir;
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    final boundary =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(393 * 3, 852 * 3);
  t.view.devicePixelRatio = 3;
  t.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(t.view.reset);
}

List<SettingsRootGroup> _groups(AppLocalizations l, List<String> taps) {
  SettingsRootRow row(
    String id,
    SettingsGlyph g,
    String title, {
    String? value,
    Widget? trailing,
  }) => SettingsRootRow(
    id: id,
    glyph: g,
    title: title,
    value: value,
    trailing: trailing,
    onTap: () => taps.add(id),
  );
  return [
    SettingsRootGroup(
      title: l.settingsHubAccountGroup,
      rows: [
        row('account', SettingsGlyph.account, l.accountSection),
        row('privacy', SettingsGlyph.privacy, l.privacySection),
        row('security', SettingsGlyph.security, l.securityTitle),
        row('devices', SettingsGlyph.devices, l.devicesSection),
      ],
    ),
    SettingsRootGroup(
      title: l.settingsHubTalkGroup,
      rows: [
        row('notifications', SettingsGlyph.notifications, l.notificationsSection),
        row('chats', SettingsGlyph.chats, l.chatsSection),
        row('language', SettingsGlyph.language, l.languageSection, value: 'Русский'),
      ],
    ),
    SettingsRootGroup(
      title: l.settingsHubConnectionGroup,
      rows: [
        row('network', SettingsGlyph.network, l.netSettingsTitle),
        row('offline', SettingsGlyph.offline, l.settingsGroupOffline),
        row(
          'reliability',
          SettingsGlyph.reliability,
          l.settingsRowReliability,
          trailing: Icon(
            Icons.error_outline_rounded,
            semanticLabel: l.settingsRowNeedsAttention,
          ),
        ),
      ],
    ),
    SettingsRootGroup(
      title: l.settingsHubPhoneGroup,
      rows: [
        row('power', SettingsGlyph.power, l.settingsRowPower),
        row('storage', SettingsGlyph.storage, l.storageSection),
        row('system', SettingsGlyph.system, l.systemSection),
      ],
    ),
    SettingsRootGroup(
      title: l.settingsHubMoreGroup,
      rows: [
        row('invite', SettingsGlyph.invite, l.settingsRowInvite),
        row('support', SettingsGlyph.support, l.settingsRowSupport),
        row('policy', SettingsGlyph.policy, l.settingsRowPolicy),
        row('about', SettingsGlyph.about, l.settingsRowAbout),
      ],
    ),
  ];
}

ChatAppearanceDelegate _delegate(AppController c) => ChatAppearanceDelegate(
  controller: c,
  // Настоящее превью переписки живёт в настройках; здесь — место под него.
  chatPreview: (context, height) => Container(
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: const Color(0xFF223047),
    ),
  ),
  isLocked: (kind, id) => false,
  pickCosmetic: (context, {required kind, required id, required apply}) =>
      apply(),
  wallpaperOptions: (context) => const [],
  pickWallpaper: (context, option) async {},
  openAllWallpapers: (context) async {},
);

void main() {
  // Открытый репозиторий не несёт растров (белый список выкладки): без
  // самих картинок настоящие экраны не нарисовать — проверка молчит по
  // отсутствию файлов (24.11.2026).
  if (!File('assets/app_ui/icons/Settings/w11-notifications.png').existsSync()) {
    test('settings_redesign_screens_test.dart: нет растров (открытый репозиторий)', () {}, skip: 'no raster assets');
    return;
  }
  setUpAll(_loadFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SettingsIconStylePrefs.debugReset();
  });

  for (final (locale, b, tag) in <(Locale, Brightness, String)>[
    (const Locale('ru'), Brightness.dark, 'ru_dark'),
    (const Locale('en'), Brightness.light, 'en_light'),
  ]) {
    testWidgets('iPhone settings root renders, searches and taps ($tag)', (
      t,
    ) async {
      _phone(t);
      final taps = <String>[];
      await t.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              final l = AppLocalizations.of(context)!;
              return AppleSettingsRoot(
                title: l.settingsTitle,
                groups: _groups(l, taps),
                profileName: 'Алекс',
                avatarPath: null,
                onOpenProfile: () => taps.add('profile'),
                onOpenQr: () => taps.add('qr'),
                footer: const SizedBox(height: 40),
              );
            },
          ),
          locale: locale,
          b: b,
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // «Объём» — стиль по умолчанию на всех платформах (20.11.2026).
      expect(SettingsIconStylePrefs.style.value, SettingsIconStyle.clay);
      await _shoot(t, 'settings_ios_$tag');

      final l = AppLocalizations.of(t.element(find.byType(AppleSettingsRoot)))!;
      await t.tap(find.text(l.privacySection));
      expect(taps, contains('privacy'));

      // Поиск: по части слова, без учёта регистра.
      await t.enterText(find.byType(TextField), l.notificationsSection.substring(0, 4).toUpperCase());
      await t.pumpAndSettle();
      expect(find.text(l.notificationsSection), findsOneWidget);
      expect(find.text(l.privacySection), findsNothing);
      await _shoot(t, 'settings_ios_search_$tag');

      // Значок «требует внимания» справа слышен экранному диктору вместе с
      // названием строки.
      await t.enterText(find.byType(TextField), '');
      await t.pumpAndSettle();
      final handle = t.ensureSemantics();
      expect(
        find.bySemanticsLabel(
          RegExp(
            '${RegExp.escape(l.settingsRowReliability)}[\\s\\S]*'
            '${RegExp.escape(l.settingsRowNeedsAttention)}',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();

      await t.enterText(find.byType(TextField), 'zzzz-nothing');
      await t.pumpAndSettle();
      expect(find.text(l.settingsSearchNoResults('zzzz-nothing')), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  for (final (platform, b, tag) in <(TargetPlatform, Brightness, String)>[
    (TargetPlatform.iOS, Brightness.dark, 'ios_dark'),
    (TargetPlatform.android, Brightness.light, 'android_light'),
  ]) {
    testWidgets('appearance screen: every tab renders ($tag)', (t) async {
      _phone(t);
      final c = AppController();
      await t.pumpWidget(
        _host(
          ChatAppearanceScreen(delegate: _delegate(c)),
          locale: const Locale('ru'),
          b: b,
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await _shoot(t, 'appearance_${tag}_theme');

      final l = AppLocalizations.of(t.element(find.byType(ChatAppearanceScreen)))!;
      // Все вкладки по очереди — кнопкой «следующая категория».
      final shots = <String>[
        'background',
        'wallpaper',
        'bubbles',
        'text',
        'icons',
        'appicon',
        'behavior',
      ];
      for (final shot in shots) {
        await t.tap(find.bySemanticsLabel(l.appearanceNextTab));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: shot);
        await _shoot(t, 'appearance_${tag}_$shot');
      }

      // Выбор стиля значков сохраняется и сразу виден в превью.
      for (var i = 0; i < 2; i++) {
        await t.tap(find.bySemanticsLabel(l.appearancePrevTab));
        await t.pumpAndSettle();
      }
      await t.tap(find.bySemanticsLabel(l.iconStyleNeon));
      await t.pumpAndSettle();
      expect(SettingsIconStylePrefs.style.value, SettingsIconStyle.neon);
      final tiles = t.widgetList<SettingsGlyphTile>(find.byType(SettingsGlyphTile));
      expect(
        tiles.where((w) => w.style == SettingsIconStyle.neon && w.size == 28),
        isNotEmpty,
      );
    }, variant: TargetPlatformVariant.only(platform));
  }
}
