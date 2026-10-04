// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Сессии и устройства» не выкидывают вошедший компьютер из аккаунта
// (30.09.2026).
//
// 🔴 ЧТО БЫЛО. Строка «Подключить устройство» звала `createDesktopLinkRequest`
// — вход НЕпривязанного компьютера. Он взводит запрет входа
// (`desktop_auth_required_after_logout_v1`), и корень окна менял оболочку на
// экран выбора входа — и после перезапуска тоже. Вернуться можно было только
// новой привязкой, которая стирает базу. QR при этом нёс личность ЭТОГО же
// компьютера, то есть и отсканировать его было незачем.

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

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: desktopMaterialTheme(kDColorsDark, dark: true),
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: child),
  ),
);

/// Код без строк-комментариев: в файлах об опасности НАПИСАНО, и искать имя по
/// всему тексту значило бы ловить собственное объяснение.
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
  });

  test('🔴 настройки не зовут вход непривязанного компьютера', () {
    for (final entity in Directory('lib/ui/desktop/workspace').listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final code = _code(entity.path);
      for (final api in const [
        'createDesktopLinkRequest',
        'buildDesktopLinkQrPayload',
      ]) {
        expect(
          code.contains(api),
          isFalse,
          reason: '${entity.path} зовёт $api — это выход из аккаунта',
        );
      }
    }
  });

  testWidgets('«Устройства»: подсказка вместо «Подключить устройство»', (
    t,
  ) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final vm = DesktopAppViewModel(controller: AppController());
    addTearDown(vm.dispose);

    await t.pumpWidget(
      _host(SettingsWorkspace(vm: vm, initialSectionId: 'devices')),
    );
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text(ru.desktopPairTitle), findsNothing);
    expect(find.text(ru.desktopDevicesAddComputerTitle), findsOneWidget);
    expect(find.text(ru.desktopDevicesAddComputerHint), findsOneWidget);
    // Подсказка — не кнопка: нажать нечего, значит и шеврона нет.
    final row = find.ancestor(
      of: find.text(ru.desktopDevicesAddComputerTitle),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(
        of: row.first,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );

    // Открыть раздел — не значит начать привязку: запрет входа не взведён.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('desktop_auth_required_after_logout_v1'), isNot(true));
    expect(vm.controller.authFlowState, isNot(AuthFlowState.qrSessionPending));

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  test('подсказка ведёт туда, где кнопка есть на самом деле', () {
    // Подключают с телефона: Настройки → Устройства → «Подключить
    // устройство». Подсказка обязана называть ровно эти пункты, иначе человек
    // ищет на телефоне то, чего там нет.
    for (final code in const ['en', 'ru', 'uk', 'de', 'es', 'fr', 'pt']) {
      final l = lookupAppLocalizations(Locale(code));
      expect(
        l.desktopDevicesAddComputerHint.contains(l.devicesConnectDevice),
        isTrue,
        reason: '$code: нет «${l.devicesConnectDevice}»',
      );
      expect(
        l.desktopDevicesAddComputerHint.contains(l.desktopAuthPhoneTitle),
        isTrue,
        reason: '$code: нет «${l.desktopAuthPhoneTitle}»',
      );
    }
  });
}
