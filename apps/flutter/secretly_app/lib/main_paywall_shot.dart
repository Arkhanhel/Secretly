// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// DEV-ONLY screenshot harness for the paywall (TZ-MONETIZE-01 §C-4).
// Renders PaywallScreen directly (no onboarding) so we can capture App Store /
// Play review screenshots. Not referenced by any release entrypoint.
//
// Run: flutter run -t lib/main_paywall_shot.dart -d <ios-simulator>
// Locale: change `_locale` to Locale('en') for the English shot.

import 'package:flutter/material.dart';
import 'billing/restore_outcome.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/paywall_screen.dart';

const Locale _locale = Locale('en');
const PaywallTrigger _trigger = PaywallTrigger.general;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // App Store wording in the renewal disclosure for the Apple review screenshot,
  // even though we render on Android (iOS simulator can't link ffmpeg_kit).
  debugPaywallForceAppleStore = true;
  // Hide Android status/nav bars so the screenshot is clean full-bleed (no
  // Android chrome) — captured at an exact iPhone size via `adb shell wm size`.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const PaywallShotApp());
}

class PaywallShotApp extends StatelessWidget {
  const PaywallShotApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4A6BFF); // app brand accent (theme_presets.dart)
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: PaywallScreen(
        trigger: _trigger,
        // No-op handlers so Restore / Terms / Privacy render enabled, not greyed.
        onPurchase: (_) async => true,
        onRestore: () async => RestoreOutcome.restored,
        onOpenTerms: () {},
        onOpenPrivacy: () {},
      ),
    );
  }
}
