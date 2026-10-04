// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 «НЕ БЕСПОКОИТЬ» В ШАПКЕ СЛЕДИТ ЗА СОСТОЯНИЕМ, А НЕ ЧИТАЕТ ЕГО РАЗ
// (01.10.2026).
//
// «Без звука на час» из трея кнопку не трогал, а истёкший час оставлял её
// перечёркнутой. Служба и раньше держала `doNotDisturbListenable` верным —
// кнопка на него просто не была подписана.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_service.dart';
import 'package:secretly_app/ui/desktop/shell/dnd_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => DesktopNotificationService.instance = null);

  testWidgets('кнопка меняется, когда состояние меняют мимо неё', (t) async {
    final svc = DesktopNotificationService(controller: AppController());
    DesktopNotificationService.instance = svc;

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: const Scaffold(body: Center(child: DesktopDndButton())),
        ),
      ),
    );
    expect(find.byIcon(FluentIcons.alert_24_regular), findsOneWidget);

    // Трей: «без звука на час».
    svc.doNotDisturbListenable.value = true;
    await t.pump();
    expect(find.byIcon(FluentIcons.alert_off_24_regular), findsOneWidget);

    // Час истёк — служба сбрасывает то же значение.
    svc.doNotDisturbListenable.value = false;
    await t.pump();
    expect(find.byIcon(FluentIcons.alert_24_regular), findsOneWidget);
  });
}
