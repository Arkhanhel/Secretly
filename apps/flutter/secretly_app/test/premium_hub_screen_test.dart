// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Окно Premium (макет «Premium Hub», 23.11.2026): бесплатный и подписчик,
// тёмная и светлая тема. `SECRETLY_SHOTS=папка` — снимки с настоящего кода.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/entitlements/entitlement_models.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/premium/premium_firefly_logo.dart';
import 'package:secretly_app/ui/emoji/emoji_status_picker.dart';
import 'package:secretly_app/ui/premium/premium_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

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

const _free = EntitlementState(
  monetizationEnabled: true,
  tier: EntitlementTier.free,
  source: 'test',
  features: EntitlementFeatures.none,
  limits: EntitlementLimits.free,
);

final _premium = EntitlementState(
  monetizationEnabled: true,
  tier: EntitlementTier.premium,
  source: 'test',
  features: EntitlementFeatures.all,
  limits: EntitlementLimits.premium,
  expiresAtMs: DateTime(2027, 11, 23).millisecondsSinceEpoch,
);

Widget _app(
  AppController c,
  EntitlementState e,
  Brightness b, {
  Locale locale = const Locale('ru'),
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: locale,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(brightness: b, useMaterial3: true),
  home: RepaintBoundary(
    key: _shotKey,
    child: PremiumHubScreen(controller: c, entitlementOverride: e),
  ),
);

Future<void> _shot(WidgetTester t, String name) async {
  final dir = _shots;
  if (dir == null) return;
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = await t.runAsync(() => boundary.toImage(pixelRatio: 1));
  final bytes = await t.runAsync(
    () => img!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final b in Brightness.values) {
    testWidgets('бесплатный: сравнение лимитов и кнопка покупки (${b.name})', (
      t,
    ) async {
      t.view.physicalSize = const Size(390 * 2, 844 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final c = AppController();
      await t.pumpWidget(_app(c, _free, b));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Secretly Premium'), findsOneWidget);
      expect(find.text('Получить Premium'), findsOneWidget);
      expect(find.text('Восстановить'), findsOneWidget);
      expect(find.byType(PremiumFireflyLogo), findsOneWidget);
      // Лимиты — из настоящих лимитов тарифов.
      await t.scrollUntilVisible(
        find.text('ЛИМИТЫ: FREE И PREMIUM'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('100 МБ'), findsOneWidget);
      expect(find.text('1 ГБ'), findsWidgets);
      expect(find.text('без лимита'), findsOneWidget);
      expect(find.text('СКОРО В PREMIUM'), findsNothing);
      await t.drag(find.byType(ListView).first, const Offset(0, 4000));
      await t.pump(const Duration(milliseconds: 300));
      await _shot(t, 'premium_hub_free_${b.name}_top');
      await t.drag(find.byType(ListView).first, const Offset(0, -1100));
      await t.pump(const Duration(milliseconds: 300));
      await _shot(t, 'premium_hub_free_${b.name}_mid');
      await t.drag(find.byType(ListView).first, const Offset(0, -3000));
      await t.pump(const Duration(milliseconds: 300));
      await _shot(t, 'premium_hub_free_${b.name}_bottom');
      expect(t.takeException(), isNull);
    });

    testWidgets('подписчик: тариф, продление, «скоро» (${b.name})', (t) async {
      t.view.physicalSize = const Size(390 * 2, 844 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final c = AppController();
      await t.pumpWidget(_app(c, _premium, b));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Поздравляем!'), findsOneWidget);
      expect(find.text('Premium активен'), findsOneWidget);
      expect(find.text('Получить Premium'), findsNothing);
      expect(find.text('Восстановить'), findsNothing);
      expect(find.text('Следующее продление'), findsOneWidget);
      expect(find.text('23 ноября 2027 г.'), findsOneWidget);
      await _shot(t, 'premium_hub_premium_${b.name}_top');
      await t.scrollUntilVisible(
        find.text('СКОРО В PREMIUM'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pump(const Duration(milliseconds: 300));
      await _shot(t, 'premium_hub_premium_${b.name}_bottom');
      expect(t.takeException(), isNull);
    });
  }

  test('наклон знака пальцем: в обе стороны и с пределом', () {
    var tilt = fireflyTiltAfterDrag(yaw: 0, pitch: 0, dx: 50, dy: 0);
    expect(tilt.yaw, closeTo(0.6, 1e-9));
    expect(tilt.pitch, 0);
    tilt = fireflyTiltAfterDrag(yaw: 0, pitch: 0, dx: 0, dy: 50);
    expect(tilt.pitch, closeTo(-0.6, 1e-9));
    tilt = fireflyTiltAfterDrag(yaw: 1.1, pitch: -1.1, dx: 500, dy: 500);
    expect(tilt.yaw, kFireflyTiltMax);
    expect(tilt.pitch, -kFireflyTiltMax);
  });

  test('палитра светлячков разноцветная', () {
    expect(kFireflyPalette.toSet().length, greaterThanOrEqualTo(6));
  });

  // 23.11.2026 (владелец): каждый язык, малые и большие экраны, крупный
  // шрифт — ничего не вылезает (переполнение роняет проверку).
  group('все языки и размеры экрана', () {
    const sizes = [Size(320, 568), Size(375, 667), Size(430, 932)];
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in sizes) {
        for (final scale in const [1.0, 1.35]) {
          testWidgets('$locale ${size.width.toInt()}x${size.height.toInt()} '
              'шрифт ×$scale', (t) async {
            t.view.physicalSize = size * 2;
            t.view.devicePixelRatio = 2;
            addTearDown(t.view.reset);
            final c = AppController();
            for (final e in [_free, _premium]) {
              await t.pumpWidget(
                _app(c, e, Brightness.dark, locale: locale, textScale: scale),
              );
              await t.pump(const Duration(milliseconds: 300));
              final list = find.byType(Scrollable).first;
              for (var i = 0; i < 12; i++) {
                await t.drag(list, const Offset(0, -400));
                await t.pump(const Duration(milliseconds: 60));
              }
              expect(t.takeException(), isNull, reason: '$locale $size ×$scale');
            }
          });
        }
      }
      testWidgets('выбор эмодзи-статуса: $locale, 320x568, шрифт ×1.35', (
        t,
      ) async {
        t.view.physicalSize = const Size(320, 568) * 2;
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        late BuildContext ctx;
        await t.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.35),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (c) {
                ctx = c;
                return const Scaffold();
              },
            ),
          ),
        );
        unawaited(showEmojiStatusPicker(ctx, current: '🔥'));
        await t.pump(const Duration(milliseconds: 600));
        final grid = find.byType(Scrollable).last;
        for (var i = 0; i < 6; i++) {
          await t.drag(grid, const Offset(0, -500));
          await t.pump(const Duration(milliseconds: 60));
        }
        // Поиск по словам.
        await t.enterText(find.byType(TextField), 'fire');
        await t.pump(const Duration(milliseconds: 100));
        expect(find.byType(GestureDetector), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  });
}
