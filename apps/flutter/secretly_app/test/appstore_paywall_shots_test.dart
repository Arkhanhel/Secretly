// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// App Store screenshot GENERATOR for the purchase page (PaywallScreen).
//
// Renders the real PaywallScreen at exact 6.9"-display device resolutions and
// writes PNGs to build/appstore_shots/. Run explicitly:
//   flutter test test/appstore_paywall_shots_test.dart
//
// It renders on the host (no simulator / no native plugins), loads the real app
// fonts so text + icons are crisp, sizes the viewport to the native logical
// size of the target device (so the layout matches a real phone), and captures
// at the device pixel ratio so the PNG is byte-exact to App Store Connect's
// required pixel dimensions for the 6.9" slot (1290x2796 and 1320x2868).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/paywall_screen.dart';

/// Load every font from the test asset bundle's FontManifest (app fonts +
/// framework icon fonts) so text and Material/Cupertino icons render for real
/// instead of as the test placeholder (Ahem) boxes.
Future<void> _loadAppFonts() async {
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Widget _host(
  Widget child,
  Locale locale, {
  Brightness brightness = Brightness.dark,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: locale,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en'), Locale('ru')],
  // PaywallScreen now adapts to the ambient brightness (dark = bluish canvas,
  // light = purple). The seed keeps colorScheme.primary consistent for dark.
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF9FB0FF),
      brightness: brightness,
    ),
  ),
  home: child,
);

Future<void> _shoot(
  WidgetTester t, {
  required String name,
  required Locale locale,
  required int wPx,
  required int hPx,
  double dpr = 3.0,
  PaywallTrigger trigger = PaywallTrigger.general,
  Brightness brightness = Brightness.dark,
}) async {
  t.view.physicalSize = Size(wPx.toDouble(), hPx.toDouble());
  t.view.devicePixelRatio = dpr;
  // Simulate the 6.9" top safe-area inset (Dynamic Island) so content sits
  // where it would on a real device.
  t.view.padding = FakeViewPadding(top: 59.0 * dpr, bottom: 34.0 * dpr);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);

  final key = GlobalKey();
  await t.pumpWidget(
    RepaintBoundary(
      key: key,
      child: _host(PaywallScreen(trigger: trigger), locale, brightness: brightness),
    ),
  );
  // The hero logo is an AssetImage; real asset I/O + decode only runs inside
  // runAsync in a widget test, so precache it before capturing — otherwise the
  // hero renders as a blank glow circle.
  await t.runAsync(() async {
    final ctx = key.currentContext;
    if (ctx != null && ctx.mounted) {
      // Bound the precache: in a headless widget test the asset decode can
      // stall inside runAsync. Cap it so the generator can't hang for 10 min —
      // worst case the hero renders as its glow circle.
      await precacheImage(
        const AssetImage('assets/app_ui/icons/png/premium_logo.png'),
        ctx,
      ).timeout(const Duration(seconds: 8), onTimeout: () {});
    }
  });
  // Bounded pump — the paywall has looping animations (hero/shimmer), so
  // pumpAndSettle would never return. A short settle picks a clean frame.
  await t.pump(const Duration(milliseconds: 750));

  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: dpr);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('build/appstore_shots');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());

  // Byte-exact dimension guard — App Store Connect rejects anything else.
  expect(image.width, wPx, reason: 'width must be exactly $wPx');
  expect(image.height, hPx, reason: 'height must be exactly $hPx');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // This is a manual App Store SCREENSHOT GENERATOR, not a CI test: it renders
  // six full-screen PNGs on the host and is slow (and the hero-logo precache can
  // stall a headless run). Skip it in the normal `flutter test` suite so it
  // doesn't dominate wall-clock or hang. Generate the shots explicitly with:
  //   SECRETLY_GENERATE_APPSTORE_SHOTS=1 flutter test test/appstore_paywall_shots_test.dart
  if (Platform.environment['SECRETLY_GENERATE_APPSTORE_SHOTS'] != '1') {
    test(
      'App Store paywall shots (generator — opt in with SECRETLY_GENERATE_APPSTORE_SHOTS=1)',
      () {},
      skip: 'screenshot generator; set SECRETLY_GENERATE_APPSTORE_SHOTS=1 to run',
    );
    return;
  }

  setUpAll(_loadAppFonts);

  // 6.9" display — primary accepted size (iPhone 15 Pro Max / 16 Plus, 430x932@3x).
  testWidgets('paywall 6.9in 1290x2796 EN', (t) async {
    await _shoot(t,
        name: 'paywall_6_9in_1290x2796_en',
        locale: const Locale('en'),
        wPx: 1290,
        hPx: 2796);
  });
  testWidgets('paywall 6.9in 1290x2796 RU', (t) async {
    await _shoot(t,
        name: 'paywall_6_9in_1290x2796_ru',
        locale: const Locale('ru'),
        wPx: 1290,
        hPx: 2796);
  });

  // 6.9" display — larger accepted size (iPhone 16 Pro Max, 440x956@3x).
  testWidgets('paywall 6.9in 1320x2868 EN', (t) async {
    await _shoot(t,
        name: 'paywall_6_9in_1320x2868_en',
        locale: const Locale('en'),
        wPx: 1320,
        hPx: 2868);
  });
  testWidgets('paywall 6.9in 1320x2868 RU', (t) async {
    await _shoot(t,
        name: 'paywall_6_9in_1320x2868_ru',
        locale: const Locale('ru'),
        wPx: 1320,
        hPx: 2868);
  });

  // LIGHT theme (purple canvas) variant — for design verification.
  testWidgets('paywall 6.9in 1290x2796 RU light', (t) async {
    await _shoot(t,
        name: 'paywall_6_9in_1290x2796_ru_light',
        locale: const Locale('ru'),
        wPx: 1290,
        hPx: 2796,
        brightness: Brightness.light);
  });
  testWidgets('paywall 6.9in 1290x2796 EN light', (t) async {
    await _shoot(t,
        name: 'paywall_6_9in_1290x2796_en_light',
        locale: const Locale('en'),
        wPx: 1290,
        hPx: 2796,
        brightness: Brightness.light);
  });
}
