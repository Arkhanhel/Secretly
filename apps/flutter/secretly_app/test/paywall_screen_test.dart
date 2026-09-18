// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/billing/restore_outcome.dart';

import 'package:secretly_app/entitlements/feature_gate.dart';
import 'package:secretly_app/ui/paywall_screen.dart';

import 'art_assets_availability.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en'), Locale('ru')],
    home: child,
  );
}

/// Give the test a tall viewport so the (lazy) ListView builds every row,
/// including the Restore / Terms / Privacy footer below the normal fold.
Future<void> _pumpTall(WidgetTester t, Widget child,
    {Locale locale = const Locale('en')}) async {
  t.view.physicalSize = const Size(1200, 2600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(_host(child, locale: locale));
  // The paywall hero icon / shimmer animate continuously, so pumpAndSettle never
  // settles — advance a bounded number of frames instead.
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  // Экран подписки рисует premium_logo.png. В публичной копии картинка —
  // заглушка, и все три проверки падают на её загрузке, а не на том, ради
  // чего написаны. Пропуск на всю группу: у `group` параметр `skip`
  // принимает строку, поэтому причина видна в отчёте CI.
  group('paywall screen', () {
    testWidgets('renders three SKUs, restore, terms/privacy and close', (t) async {
      await _pumpTall(t, const PaywallScreen(trigger: PaywallTrigger.file));

      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Lifetime'), findsOneWidget);
      expect(find.text(r'$14.99'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // File trigger header.
      expect(find.textContaining('Share files up to 1 GB'), findsOneWidget);
    });

    testWidgets('purchase + restore callbacks fire', (t) async {
      PaywallSku? purchased;
      var restored = false;
      await _pumpTall(
        t,
        PaywallScreen(
          trigger: PaywallTrigger.desktop,
          onPurchase: (s) async {
            purchased = s;
            return true;
          },
          onRestore: () async {
            restored = true;
            return RestoreOutcome.restored;
          },
        ),
      );

      await t.tap(find.text('Yearly'));
      await t.pump();
      expect(purchased?.productId, 'secretly_premium_yearly');

      // The top-bar restore control is labelled 'Restore' (en).
      await t.tap(find.text('Restore'));
      await t.pump();
      expect(restored, isTrue);
    });

    testWidgets('localizes header in Russian', (t) async {
      await _pumpTall(
        t,
        const PaywallScreen(trigger: PaywallTrigger.desktop),
        locale: const Locale('ru'),
      );
      expect(find.textContaining('Secretly на компьютере'), findsOneWidget);
      expect(find.text('Восстановить'), findsOneWidget);
    });

    test('paywallTriggerFromFeature maps features', () {
      expect(paywallTriggerFromFeature(GatedFeature.desktop),
          PaywallTrigger.desktop);
      expect(paywallTriggerFromFeature(GatedFeature.attachment),
          PaywallTrigger.file);
      expect(paywallTriggerFromFeature(GatedFeature.customId), PaywallTrigger.id);
      expect(paywallTriggerFromFeature(GatedFeature.group), PaywallTrigger.group);
      expect(paywallTriggerFromFeature(GatedFeature.cosmetic),
          PaywallTrigger.cosmetic);
      expect(paywallTriggerFromFeature(GatedFeature.premiumStickers),
          PaywallTrigger.cosmetic);
    });
  }, skip: artAssetsArePlaceholders ? artAssetsSkipReason : null);
}
