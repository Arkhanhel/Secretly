// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Liquid Glass по всему iPhone (20.11.2026): настоящий экран настроек и его
// внутренние страницы поднимаются на iPhone и на Android, значки на iPhone —
// iOS, на Android — прежние Material, стекло включается только на iPhone.
//
// `SECRETLY_SHOTS=/папка flutter test test/ios_glass_everywhere_test.dart`
// дополнительно сохраняет снимки.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/apple_glass.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';
import 'package:secretly_app/ui/settings_screen.dart';

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
    final boundary =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _host(Widget child, Brightness b) {
  final dark = b == Brightness.dark;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: b,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2AABEE),
        brightness: b,
      ),
      cardTheme: appleGlassPanelsEnabled
          ? CardThemeData(
              color: AppleGlass.fill(dark),
              elevation: 0,
              shape: AppleGlassBorder(dark: dark),
            )
          : null,
    ),
    builder: (context, nav) => RepaintBoundary(
      key: _shotKey,
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

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(393 * 3, 852 * 3);
  t.view.devicePixelRatio = 3;
  t.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(t.view.reset);
}

void main() {
  // Открытый репозиторий не несёт растров (белый список выкладки): без
  // самих картинок настоящие экраны не нарисовать — проверка молчит по
  // отсутствию файлов (24.11.2026).
  if (!File('assets/app_ui/icons/Settings/w11-notifications.png').existsSync()) {
    test('ios_glass_everywhere_test.dart: нет растров (открытый репозиторий)', () {}, skip: 'no raster assets');
    return;
  }
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('icons are iOS on iPhone', (t) async {
    expect(AdaptiveIcons.lock_rounded.codePoint,
        CupertinoIcons.lock_fill.codePoint);
    expect(AdaptiveIcons.lock_rounded.fontFamily,
        CupertinoIcons.lock_fill.fontFamily);
    expect(appleGlassPanelsEnabled, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('icons stay Material on Android', (t) async {
    expect(AdaptiveIcons.lock_rounded.codePoint, Icons.lock_rounded.codePoint);
    expect(AdaptiveIcons.lock_rounded.fontFamily, Icons.lock_rounded.fontFamily);
    expect(appleGlassPanelsEnabled, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final (platform, b, tag) in <(TargetPlatform, Brightness, String)>[
    (TargetPlatform.iOS, Brightness.dark, 'ios_dark'),
    (TargetPlatform.iOS, Brightness.light, 'ios_light'),
    (TargetPlatform.android, Brightness.dark, 'android_dark'),
  ]) {
    testWidgets('real settings screen and its pages render ($tag)', (t) async {
      _phone(t);
      final c = AppController();
      await t.pumpWidget(_host(SettingsScreen(controller: c), b));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      await _shoot(t, 'settings_root_$tag');

      final l = AppLocalizations.of(t.element(find.byType(SettingsScreen)))!;
      for (final (title, shot) in <(String, String)>[
        (l.notificationsSection, 'notifications'),
        (l.accountSection, 'account'),
      ]) {
        await t.tap(find.text(title).first);
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        expect(t.takeException(), isNull, reason: shot);
        await _shoot(t, 'settings_${shot}_$tag');
        Navigator.of(t.element(find.text(title).last)).pop();
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
      }
    }, variant: TargetPlatformVariant.only(platform));
  }
}
