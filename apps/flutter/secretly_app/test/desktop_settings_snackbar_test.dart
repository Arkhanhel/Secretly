// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Ответы настроек видны: своя плашка окна, а не материальная (30.09.2026).
//
// 🔴 ЧТО БЫЛО. «Сессии и устройства» и «Удалить аккаунт» отвечали
// материальным `SnackBar` через `ScaffoldMessenger`. Он рисуется в `Scaffold`
// ПОД слоем настроек — «сеанс завершён», «не удалось удалить», «сначала
// завершите звонок» не видел никто.

import 'dart:io';

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
  @override
  String get deviceId => 'device-this-1234567890';

  @override
  Future<List<String>> listMyDeviceIds() async => const [
    'device-this-1234567890',
    'device-other-abcdef123456',
  ];

  @override
  Future<bool> endDeviceSession({required String targetDeviceId}) async =>
      throw StateError('keys refused');
}

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
  });

  test('🔴 в настройках нет материальных всплывашек', () {
    for (final entity in Directory('lib/ui/desktop/workspace').listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final code = entity
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('ScaffoldMessenger'), isFalse, reason: entity.path);
      expect(code.contains('SnackBar('), isFalse, reason: entity.path);
    }
  });

  testWidgets('отказ «Отключить» виден и без «Bad state»', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final vm = DesktopAppViewModel(controller: _Devices());
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
            body: SettingsWorkspace(vm: vm, initialSectionId: 'devices'),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));

    await t.tap(find.text(ru.desktopDevicesDisconnect));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(ru.desktopDevicesEnd));
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text(ru.desktopDevicesEndFailed('keys refused')), findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
