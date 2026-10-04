// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Выйти» на компьютере: один выход за раз и честный текст (30.09.2026).
//
// 🔴 ДВА ДЕФЕКТА.
// 1. Двойной щелчок по «Выйти» открывал два окна, и два подтверждения
//    запускали два `resetProfileAndLocalData` разом.
// 2. Текст обещал «аккаунт и история на телефоне не пострадают» — и тому, у
//    кого аккаунт заведён на этом компьютере и телефона нет вовсе. Такой
//    человек после выхода без набора восстановления теряет аккаунт насовсем.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';

class _Controller extends AppController {
  _Controller({this.devices});

  /// `null` — сервер ключей не ответил.
  final List<String>? devices;
  int resets = 0;
  final Completer<void> resetGate = Completer<void>();

  @override
  String get deviceId => 'dev-this';

  @override
  Future<List<String>> listMyDeviceIds() async {
    final d = devices;
    if (d == null) throw StateError('offline');
    return d;
  }

  @override
  Future<void> resetProfileAndLocalData() async {
    resets += 1;
    await resetGate.future;
  }
}

Widget _host(AppController controller) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: desktopMaterialTheme(kDColorsDark, dark: true),
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => unawaited(showSignOutDialog(context, controller)),
            child: const Text('trigger'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));

  Future<void> open(WidgetTester t) async {
    await t.tap(find.text('trigger'));
    await t.pumpAndSettle();
  }

  testWidgets('🔴 второй щелчок не открывает второе окно и не стирает дважды', (
    t,
  ) async {
    final controller = _Controller(devices: const ['dev-this', 'dev-phone']);
    await t.pumpWidget(_host(controller));

    await t.tap(find.text('trigger'));
    await t.tap(find.text('trigger'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text(ru.desktopSettingsSignOutTitle), findsOneWidget);

    await t.tap(find.text(ru.desktopSettingsSignOut));
    await t.pumpAndSettle();
    expect(controller.resets, 1);

    // Стирание ещё идёт — новое окно не открывается.
    await open(t);
    expect(find.text(ru.desktopSettingsSignOutTitle), findsNothing);
    expect(controller.resets, 1);

    // Закончилось (или сорвалось) — выйти снова можно.
    controller.resetGate.complete();
    await t.pumpAndSettle();
    await open(t);
    expect(find.text(ru.desktopSettingsSignOutTitle), findsOneWidget);
  });

  testWidgets('отмена снимает замок', (t) async {
    final controller = _Controller(devices: const ['dev-this', 'dev-phone']);
    await t.pumpWidget(_host(controller));
    await open(t);
    await t.tap(find.text(ru.cancel));
    await t.pumpAndSettle();
    await open(t);
    expect(find.text(ru.desktopSettingsSignOutTitle), findsOneWidget);
    expect(controller.resets, 0);
  });

  testWidgets('есть другие устройства — аккаунт остаётся на них', (t) async {
    final controller = _Controller(devices: const ['dev-this', 'dev-phone']);
    await t.pumpWidget(_host(controller));
    await open(t);
    expect(find.text(ru.desktopSettingsSignOutBody), findsOneWidget);
  });

  testWidgets('🔴 компьютер — единственное устройство: про набор, без телефона',
      (t) async {
    final controller = _Controller(devices: const ['dev-this']);
    await t.pumpWidget(_host(controller));
    await open(t);
    expect(find.text(ru.desktopSettingsSignOutBodyOnlyDevice), findsOneWidget);
    expect(find.text(ru.desktopSettingsSignOutBody), findsNothing);
    expect(
      ru.desktopSettingsSignOutBodyOnlyDevice.contains('телефон'),
      isFalse,
      reason: 'телефона у такого аккаунта нет — обещать его нельзя',
    );
  });

  testWidgets('сервер не ответил — осторожный текст про оба случая', (t) async {
    final controller = _Controller();
    await t.pumpWidget(_host(controller));
    await open(t);
    expect(find.text(ru.desktopSettingsSignOutBodyUnknown), findsOneWidget);
  });

  testWidgets('себя в ответе нет — ответу не верим', (t) async {
    final controller = _Controller(devices: const <String>[]);
    await t.pumpWidget(_host(controller));
    await open(t);
    expect(find.text(ru.desktopSettingsSignOutBodyUnknown), findsOneWidget);
  });
}
