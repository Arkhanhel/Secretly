// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Вход на ПК в стиле макета «Secretly Kit» (17.11.2026): пояснения — в «?»,
// с восстановления есть дорога к привязке по телефону, имя обязательно,
// Windows рисуется в виде Fluent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/onboarding/desktop_auth_gate.dart';
import 'package:secretly_app/ui/desktop/onboarding/desktop_create_account_flow.dart';
import 'package:secretly_app/ui/desktop/onboarding/desktop_restore_flow.dart';
import 'package:secretly_app/ui/welcome/welcome_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ru = lookupAppLocalizations(const Locale('ru'));

  late DesktopAppViewModel vm;
  setUp(() => vm = DesktopAppViewModel(controller: AppController()));
  tearDown(() => vm.dispose());

  Widget host(Widget child, {TargetPlatform platform = TargetPlatform.macOS}) =>
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(brightness: Brightness.dark, platform: platform),
        home: DColors(colors: kDColorsDark, child: Scaffold(body: child)),
      );

  void desk(WidgetTester t) {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  testWidgets('восстановление: «Войдите через него» ведёт к телефону', (
    t,
  ) async {
    desk(t);
    var phone = 0;
    await t.pumpWidget(
      host(DesktopRestoreFlow(vm: vm, onBack: () {}, onUsePhone: () => phone++)),
    );
    await t.pumpAndSettle();
    final link = find.textContaining(ru.welcomeDesktopUsePhoneLink, findRichText: true);
    expect(link, findsOneWidget);
    await t.tapOnText(find.textRange.ofSubstring(ru.welcomeDesktopUsePhoneLink));
    await t.pumpAndSettle();
    expect(phone, 1);
  });

  testWidgets('без дороги к телефону подсказки нет', (t) async {
    desk(t);
    await t.pumpWidget(host(DesktopRestoreFlow(vm: vm, onBack: () {})));
    await t.pumpAndSettle();
    expect(
      find.textContaining(ru.welcomeDesktopUsePhoneLink, findRichText: true),
      findsNothing,
    );
  });

  testWidgets('имя: пустое не пропускаем, буква в круге', (t) async {
    desk(t);
    await t.pumpWidget(host(DesktopCreateAccountFlow(vm: vm, onBack: () {})));
    await t.pumpAndSettle();
    expect(find.text(ru.desktopAuthNameTitle), findsOneWidget);
    WelcomePrimaryButton button() => t.widget<WelcomePrimaryButton>(
      find.widgetWithText(WelcomePrimaryButton, ru.desktopAuthContinue),
    );
    expect(button().onPressed, isNull);
    await t.enterText(find.byType(TextField), 'Ира');
    await t.pump();
    expect(button().onPressed, isNotNull);
    expect(find.text('И'), findsOneWidget);
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    testWidgets('вход рисуется без ошибок: ${platform.name}', (t) async {
      desk(t);
      await t.pumpWidget(host(DesktopAuthGate(vm: vm), platform: platform));
      await t.pumpAndSettle();
      await t.tap(find.text(ru.welcomeStart));
      await t.pumpAndSettle();
      expect(find.text(ru.welcomeDesktopChooseTitle), findsOneWidget);
      expect(find.text(ru.welcomeOr), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    testWidgets('поля восстановления рисуются: ${platform.name}', (t) async {
      desk(t);
      await t.pumpWidget(
        host(DesktopRestoreFlow(vm: vm, onBack: () {}), platform: platform),
      );
      await t.pumpAndSettle();
      await t.tap(find.text(ru.desktopAuthServerOptionTitle));
      await t.pumpAndSettle();
      await t.enterText(find.byType(EditableText).first, 'R7KQ');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('R7KQ'), findsOneWidget);
      await t.tap(find.byType(EditableText).last);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  test('Windows — вид Fluent, macOS — Apple', () {
    final win = WelcomeStyle.resolve(
      brightness: Brightness.dark,
      platform: TargetPlatform.windows,
    );
    expect(win.fluent, isTrue);
    expect(win.primaryHeight, 40);
    expect(win.radiusFor(40), 6);
    final mac = WelcomeStyle.resolve(
      brightness: Brightness.light,
      platform: TargetPlatform.macOS,
    );
    expect(mac.fluent, isFalse);
    expect(mac.material, isFalse);
  });
}
