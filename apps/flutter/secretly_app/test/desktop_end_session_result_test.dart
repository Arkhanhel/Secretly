// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// «ЗАВЕРШИТЬ СЕАНС»: `false` — ЭТО НЕУДАЧА, А НЕ «ЗАВЕРШЁН» (01.10.2026).
//
// 🔴 Ответ `endDeviceSession` отбрасывался, и окно говорило «Сеанс
// устройства завершён» про устройство, которое сервер так и не снял.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Devices extends AppController {
  _Devices(this.result);

  final Future<bool> Function() result;

  @override
  String get deviceId => 'device-this-1234567890';

  @override
  Future<List<String>> listMyDeviceIds() async => const [
    'device-this-1234567890',
    'device-other-abcdef123456',
  ];

  @override
  Future<bool> endDeviceSession({required String targetDeviceId}) =>
      result();
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
  });

  Future<void> endOther(WidgetTester t, AppController ctrl) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final vm = DesktopAppViewModel(controller: ctrl);
    addTearDown(vm.dispose);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: desktopMaterialTheme(kDColorsDark, dark: true),
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: SettingsWorkspace(vm: vm, initialSectionId: 'devices'),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text(en.desktopDevicesDisconnect));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(en.desktopDevicesEnd));
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('🔴 сервер ответил «нет» — окно говорит «не удалось»',
      (t) async {
    await endOther(t, _Devices(() async => false));
    expect(find.text(en.desktopDevicesEnded), findsNothing);
    expect(
      find.text(en.desktopDevicesEndFailed(en.desktopDevicesEndNotConfirmed)),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('удалось — «завершён»', (t) async {
    await endOther(t, _Devices(() async => true));
    expect(find.text(en.desktopDevicesEnded), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
