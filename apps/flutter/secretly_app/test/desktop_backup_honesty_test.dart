// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ЧЕСТНОСТЬ РЕЗЕРВНЫХ КОПИЙ НА КОМПЬЮТЕРЕ (01.10.2026).
//
// 🔴 Три молчания, которые здесь закрыты:
//   1. Восстановление копии с сервера делает компьютер ТЕМ ЖЕ устройством,
//      что сделало копию (обычно телефон), — об этом не говорилось ни слова.
//   2. Копия на сервер с компьютера затирала копию телефона без вопроса:
//      сервер держит одну копию на аккаунт.
//   3. Автоматическая копия включалась без пароля и падала по-английски.
// И попутно — поля окна пароля освобождались, пока окно ещё уезжало.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/security/safe_backup.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/onboarding/desktop_restore_flow.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kit = SafeBackupPlainV1(
  profileId: 'pid',
  profileSecretB64: 'c2VjcmV0',
  deviceId: 'phone-device',
  deviceKeysMaterialJson: '{}',
  serverBinding: 'binding',
  contacts: [],
  blockedProfiles: [],
  darkMode: true,
  blockUnverified: false,
  shareNicknameInQr: false,
  myNickname: '',
  profileGalleryPaths: [],
  profileBackgroundPaths: [],
  profileMusicPaths: [],
  personalConvoIds: [],
);

class _Restore extends AppController {
  int restores = 0;
  bool? asNewDevice;

  @override
  Future<(bool exists, String? payload, int updatedAtMs)> backupGetFromServer(
    String targetProfileId, {
    bool useDeviceAuth = true,
    String? backupPassword,
  }) async =>
      (true, 'payload', 0);

  @override
  Future<SafeBackupPlainV1> decryptSafeBackupPayloadForRestore({
    required String payload,
    required String password,
  }) async =>
      _kit;

  @override
  Future<void> restoreFromSafeBackup(
    SafeBackupPlainV1 kit, {
    bool completeOnboarding = false,
    bool restoreAsNewDevice = false,
  }) async {
    restores++;
    asNewDevice = restoreAsNewDevice;
  }
}

class _Backup extends AppController {
  bool hasPassword = false;
  bool serverOn = true;
  final List<String> passwords = [];
  final List<bool> autoCalls = [];
  final List<bool> serverCalls = [];

  @override
  bool get safeBackupAutoServerEnabled => serverOn;

  @override
  Future<bool> hasSafeBackupAutoPassword() async => hasPassword;

  @override
  Future<void> setSafeBackupAutoPassword(String password) async {
    passwords.add(password);
    hasPassword = true;
  }

  @override
  Future<void> setSafeBackupAutoEnabled(bool value) async =>
      autoCalls.add(value);

  @override
  Future<void> setSafeBackupAutoServerEnabled(bool value) async =>
      serverCalls.add(value);
}

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
  });

  Widget app(Widget child) => MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: desktopMaterialTheme(kDColorsDark, dark: true),
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(body: child),
        ),
      );

  void bigView(WidgetTester t) {
    t.view.physicalSize = const Size(1400, 1100);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('🔴 восстановление с сервера сначала называет последствия',
      (t) async {
    bigView(t);
    final ctrl = _Restore();
    final vm = DesktopAppViewModel(controller: ctrl);
    addTearDown(vm.dispose);
    await t.pumpWidget(app(DesktopRestoreFlow(vm: vm, onBack: () {})));
    await settle(t);

    await t.tap(find.text(ru.desktopAuthServerOptionTitle));
    await settle(t);
    final fields = find.byType(EditableText);
    await t.enterText(fields.at(0), 'pid');
    await t.enterText(fields.at(1), 'correct horse battery');
    await t.pump();
    await t.tap(find.text(ru.desktopAuthRestoreTitle).last);
    await settle(t);

    expect(find.text(ru.desktopRestoreTakeOverTitle), findsOneWidget);
    expect(find.text(ru.desktopRestoreTakeOverBody), findsOneWidget);
    expect(ru.desktopRestoreTakeOverBody, contains('QR'));

    // Отказ — ничего не восстановлено, форма снова доступна.
    await t.tap(find.text(ru.cancel));
    await settle(t);
    expect(ctrl.restores, 0);
    expect(find.text(ru.desktopRestoreTakeOverTitle), findsNothing);

    await t.tap(find.text(ru.desktopAuthRestoreTitle).last);
    await settle(t);
    await t.tap(find.text(ru.desktopRestoreTakeOverConfirm));
    await settle(t);
    expect(ctrl.restores, 1);
    expect(ctrl.asNewDevice, isFalse);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('🔴 копия на сервер: сначала «Заменить копию на сервере?»',
      (t) async {
    bigView(t);
    bool? answer;
    await t.pumpWidget(app(Builder(
      builder: (ctx) => TextButton(
        onPressed: () async =>
            answer = await confirmDesktopServerBackupReplace(ctx),
        child: const Text('go'),
      ),
    )));
    await t.tap(find.text('go'));
    await settle(t);
    expect(find.text(ru.desktopServerBackupReplaceBody), findsOneWidget);
    await t.tap(find.text(ru.cancel));
    await settle(t);
    expect(answer, isFalse);

    await t.tap(find.text('go'));
    await settle(t);
    await t.tap(find.text(ru.desktopServerBackupReplaceConfirm));
    await settle(t);
    expect(answer, isTrue);
  });

  testWidgets('окно пароля закрывается без обращения к освобождённым полям',
      (t) async {
    bigView(t);
    String? got = 'untouched';
    await t.pumpWidget(app(Builder(
      builder: (ctx) => TextButton(
        onPressed: () async => got = await promptDesktopBackupPassword(
          ctx,
          actionLabel: 'OK',
        ),
        child: const Text('go'),
      ),
    )));
    await t.tap(find.text('go'));
    await settle(t);
    await t.enterText(find.byType(EditableText).first, 'abc');
    await t.tap(find.text(ru.cancel));
    // Кадры ухода окна: поля ещё рисуются — контроллеры обязаны быть живы.
    await settle(t);
    expect(t.takeException(), isNull);
    expect(got, isNull);
  });

  testWidgets('🔴 автоматическая копия без пароля не включается', (t) async {
    bigView(t);
    final ctrl = _Backup()..serverOn = false;
    final vm = DesktopAppViewModel(controller: ctrl);
    addTearDown(vm.dispose);
    await t.pumpWidget(
      app(SettingsWorkspace(vm: vm, initialSectionId: 'backup')),
    );
    await settle(t);

    final autoRow = find.ancestor(
      of: find.text(ru.desktopBackupCreateAuto),
      matching: find.byType(WorkspaceRow),
    );
    final autoSwitch = find.descendant(
      of: autoRow,
      matching: find.byType(WorkspaceSwitch),
    );
    await t.tap(autoSwitch);
    await settle(t);

    // Спросили пароль — окно отменили: не включено.
    expect(find.text(ru.desktopServerBackupPassword), findsOneWidget);
    await t.tap(find.text(ru.cancel));
    await settle(t);
    expect(ctrl.autoCalls, isEmpty);
    expect(ctrl.passwords, isEmpty);

    // Пароль задан — включено, и пароль сохранён ДО включения.
    await t.tap(autoSwitch);
    await settle(t);
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(EditableText),
    );
    await t.enterText(fields.at(0), 'Str0ng-backup-pass!');
    await t.enterText(fields.at(1), 'Str0ng-backup-pass!');
    await t.tap(find.text(ru.saveAction));
    await settle(t);
    expect(ctrl.passwords, ['Str0ng-backup-pass!']);
    expect(ctrl.autoCalls, [true]);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('🔴 автоматическая копия на сервер: сначала про замену копии',
      (t) async {
    bigView(t);
    final ctrl = _Backup()
      ..serverOn = true
      ..hasPassword = true;
    final vm = DesktopAppViewModel(controller: ctrl);
    addTearDown(vm.dispose);
    await t.pumpWidget(
      app(SettingsWorkspace(vm: vm, initialSectionId: 'backup')),
    );
    await settle(t);

    final autoSwitch = find.descendant(
      of: find.ancestor(
        of: find.text(ru.desktopBackupCreateAuto),
        matching: find.byType(WorkspaceRow),
      ),
      matching: find.byType(WorkspaceSwitch),
    );
    await t.tap(autoSwitch);
    await settle(t);
    expect(find.text(ru.desktopServerBackupReplaceTitle), findsOneWidget);
    await t.tap(find.text(ru.cancel));
    await settle(t);
    expect(ctrl.autoCalls, isEmpty);

    await t.tap(autoSwitch);
    await settle(t);
    await t.tap(find.text(ru.desktopServerBackupReplaceConfirm));
    await settle(t);
    expect(ctrl.autoCalls, [true]);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  test('причины сбоя про пароль — дословно те, что пишет контроллер', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();
    expect(src, contains("'$kDesktopBackupNoPasswordError'"));
    expect(src, contains("'$kDesktopBackupWeakPasswordError'"));
    expect(desktopBackupAutoErrorIsPassword(kDesktopBackupNoPasswordError),
        isTrue);
    expect(desktopBackupAutoErrorIsPassword('network down'), isFalse);
    expect(
      desktopBackupAutoErrorText(ru, kDesktopBackupNoPasswordError),
      ru.desktopBackupAutoPasswordMissing,
    );
    expect(
      desktopBackupAutoErrorText(ru, kDesktopBackupWeakPasswordError),
      ru.desktopBackupAutoPasswordWeak,
    );
    expect(desktopBackupAutoErrorText(ru, 'boom'), 'boom');
  });
}
