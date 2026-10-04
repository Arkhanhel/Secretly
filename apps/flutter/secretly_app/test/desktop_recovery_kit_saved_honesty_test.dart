// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Шаг «сохраните набор восстановления» не говорит «сохранён», пока ничего не
// сохранено (30.09.2026).
//
// 🔴 ЧТО БЫЛО. Шаг показывал телефонный экран с QR, и ЗАКРЫТИЕ этого окна
// считалось успехом: «Набор сохранён. Теперь аккаунт можно вернуть» — хотя не
// было ни файла, ни копии, ни снимка. Для аккаунта, у которого нет ни почты,
// ни телефона, это единственный способ его вернуть.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/onboarding/desktop_recovery_kit_gate.dart';

class _Kit extends AppController {
  @override
  Future<String> createRecoveryKitPayload({required String password}) async =>
      'KIT-PAYLOAD-0123456789';
}

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  late Directory tmp;
  late DesktopAppViewModel vm;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('desktop_kit_gate');
    vm = DesktopAppViewModel(controller: _Kit());
  });

  tearDown(() async {
    vm.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> openKitReady(WidgetTester t) async {
    t.view.physicalSize = const Size(1200, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: DesktopRecoveryKitGate(
              vm: vm,
              pickSavePath:
                  ({required String dialogTitle, required String fileName}) async =>
                      '${tmp.path}/$fileName',
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text(ru.desktopAuthKitAction));
    await t.pumpAndSettle();
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), 'Secretly#2026pass');
    await t.enterText(fields.at(1), 'Secretly#2026pass');
    await t.tap(find.text(ru.desktopListCreate));
    await t.pumpAndSettle();
    expect(find.text(ru.desktopKitReadyTitle), findsOneWidget);
  }

  testWidgets('🔴 закрыл окно, ничего не сохранив, — «сохранён» не пишется', (
    t,
  ) async {
    await openKitReady(t);
    await t.tap(find.text(ru.close));
    await t.pumpAndSettle();
    expect(find.text(ru.desktopAuthKitSaved), findsNothing);
    expect(find.text(ru.desktopAuthKitConfirmed), findsNothing);
    // Шаг не пройден: кнопка создания на месте, «Продолжить» нет.
    expect(find.text(ru.desktopAuthKitAction), findsOneWidget);
    expect(find.text(ru.desktopAuthContinue), findsNothing);
  });

  testWidgets('«Сохранить в файл…» пишет набор туда, куда выбрали', (t) async {
    await openKitReady(t);
    // Запись на диск — настоящая, ей нужно настоящее время: нажатие и
    // ожидание идут вне поддельных часов теста.
    await t.runAsync(() async {
      await t.tap(find.text(ru.desktopKitSaveToFile));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();

    final file = File('${tmp.path}/Secretly-recovery-kit.txt');
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync().trim(), 'KIT-PAYLOAD-0123456789');
    expect(find.text(ru.desktopKitSavedTo(file.path)), findsOneWidget);

    await t.tap(find.text(ru.close));
    await t.pumpAndSettle();
    expect(find.text(ru.desktopAuthKitSaved), findsOneWidget);
    expect(find.text(ru.desktopAuthContinue), findsOneWidget);
  });

  testWidgets('сохранил иначе — только после явного подтверждения', (t) async {
    await openKitReady(t);
    await t.tap(find.text(ru.desktopKitSavedElsewhere));
    await t.pumpAndSettle();
    expect(find.text(ru.desktopKitConfirmTitle), findsOneWidget);

    // Передумал — окно набора на месте, шаг не пройден.
    await t.tap(find.text(ru.cancel));
    await t.pumpAndSettle();
    expect(find.text(ru.desktopKitReadyTitle), findsOneWidget);

    await t.tap(find.text(ru.desktopKitSavedElsewhere));
    await t.pumpAndSettle();
    await t.tap(find.text(ru.desktopKitConfirmYes));
    await t.pumpAndSettle();
    // Честно: «вы подтвердили», а не «сохранено».
    expect(find.text(ru.desktopAuthKitConfirmed), findsOneWidget);
    expect(find.text(ru.desktopAuthKitSaved), findsNothing);
    expect(find.text(ru.desktopAuthContinue), findsOneWidget);
  });
}
