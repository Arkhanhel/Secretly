// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// «ЗАЩИТА ОТ СНИМКОВ ЭКРАНА» НА КОМПЬЮТЕРЕ (01.10.2026).
//
// 🔴 Контроллер звал канал `secretly/screen_privacy` при запуске и при
// переключении, но на компьютере ему никто не отвечал — и переключателя здесь
// не было. Теперь отвечают раннеры Mac и Windows, а в «Приватности» есть
// переключатель с честным текстом: это просьба к системе, а не замок.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/services/desktop_screen_privacy.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  const channel = MethodChannel('secretly/screen_privacy');
  late List<bool> calls;
  late bool accept;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
    calls = <bool>[];
    accept = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add((call.arguments as Map)['enabled'] as bool);
      return accept;
    });
  });

  tearDown(() {
    DesktopScreenPrivacy.debugSupported = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<AppController> pumpPrivacy(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final ctrl = AppController();
    final vm = DesktopAppViewModel(controller: ctrl);
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
            body: SettingsWorkspace(vm: vm, initialSectionId: 'privacy'),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    return ctrl;
  }

  Finder toggle() => find.descendant(
        of: find.ancestor(
          of: find.text(ru.desktopPrivacyScreenCaptureSwitch),
          matching: find.byType(WorkspaceRow),
        ),
        matching: find.byType(WorkspaceSwitch),
      );

  testWidgets('🔴 переключатель доходит до системы и держит её ответ',
      (t) async {
    DesktopScreenPrivacy.debugSupported = true;
    final ctrl = await pumpPrivacy(t);
    expect(find.text(ru.desktopPrivacyScreenCaptureHint), findsOneWidget);
    expect(ctrl.screenPrivacy, isFalse, reason: 'по умолчанию выключено');

    await t.tap(toggle());
    await t.pump(const Duration(milliseconds: 300));
    expect(calls, [true]);
    expect(ctrl.screenPrivacy, isTrue);

    await t.tap(toggle());
    await t.pump(const Duration(milliseconds: 300));
    expect(calls, [true, false]);
    expect(ctrl.screenPrivacy, isFalse);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('🔴 система отказала — не «включено», и сказано почему',
      (t) async {
    DesktopScreenPrivacy.debugSupported = true;
    accept = false;
    final ctrl = await pumpPrivacy(t);
    await t.tap(toggle());
    await t.pump(const Duration(milliseconds: 300));
    expect(ctrl.screenPrivacy, isFalse);
    expect(find.text(ru.desktopPrivacyScreenCaptureFailed), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('без нативной защиты (Linux) переключателя нет', (t) async {
    DesktopScreenPrivacy.debugSupported = false;
    await pumpPrivacy(t);
    expect(find.text(ru.desktopPrivacyScreenCaptureTitle), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  test('раннер Mac отвечает на канал и защищает все окна', () {
    final mac = File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
    expect(mac, contains('name: "secretly/screen_privacy"'));
    expect(mac, contains('case "setEnabled":'));
    expect(mac, contains('window.sharingType = enabled ? .none : .readOnly'));
    expect(mac, contains('for w in NSApp.windows'));
    expect(mac, contains('screenPrivacyBridge.attach('));
    // Отдельные окна (звонок) рождаются уже защищёнными.
    final childOpen = mac.substring(mac.indexOf('case "open":'));
    expect(childOpen, contains('ScreenPrivacyBridge.apply(to: window)'));
  });

  test('раннер Windows отвечает на канал и защищает все окна', () {
    final cpp = File('windows/runner/screen_privacy.cpp').readAsStringSync();
    expect(cpp, contains('"secretly/screen_privacy"'));
    expect(cpp, contains('SetWindowDisplayAffinity(window, WDA_EXCLUDEFROMCAPTURE)'));
    expect(cpp, contains('SetWindowDisplayAffinity(window, WDA_MONITOR)'));
    expect(cpp, contains('SetWindowDisplayAffinity(window, WDA_NONE)'));
    expect(cpp, contains('EnumThreadWindows('));
    final main = File('windows/runner/flutter_window.cpp').readAsStringSync();
    expect(main, contains('std::make_unique<ScreenPrivacyChannel>('));
    final child = File('windows/runner/child_window.cpp').readAsStringSync();
    expect(child, contains('ApplyScreenPrivacy(window->GetHandle())'));
    final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();
    expect(cmake, contains('"screen_privacy.cpp"'));
  });
}
