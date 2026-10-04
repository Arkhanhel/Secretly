// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «О программе» предлагает исходный код (30.09.2026).
//
// 🔴 AGPL-3.0 требует предложить исходный код тому, кто получил программу.
// Лицензия была названа в подписи, а куда идти за кодом — нигде.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  const repo = 'https://github.com/Arkhanhel/Secretly';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null);
  });

  testWidgets('лицензия названа, адрес кода виден и открывается', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final opened = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
          final args = call.arguments;
          if (args is Map && args['url'] is String) {
            opened.add(args['url'] as String);
          }
          return true;
        });
    final vm = DesktopAppViewModel(controller: AppController());
    addTearDown(vm.dispose);

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: desktopMaterialTheme(kDColorsDark, dark: true),
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: SettingsWorkspace(vm: vm, initialSectionId: 'about'),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));

    // Адрес виден текстом — даже если браузер не откроется.
    expect(find.text(ru.desktopAboutLicenseLine(repo)), findsOneWidget);
    expect(ru.desktopAboutLicenseLine(repo).contains('AGPL-3.0'), isTrue);

    await t.tap(find.text(ru.desktopAboutSourceCode));
    await t.pump(const Duration(milliseconds: 100));
    expect(opened, contains(repo));

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
