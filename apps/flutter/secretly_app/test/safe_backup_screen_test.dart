// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/security/restore_error_classification.dart';
import 'package:secretly_app/ui/safe_backup_screen.dart';

void main() {
  void setLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildSubject(AppController controller) {
    return MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: SafeBackupScreen(controller: controller),
    );
  }

  testWidgets('safe backup screen exports recovery kit to QR screen', (
    WidgetTester tester,
  ) async {
    final controller = _FakeSafeBackupController(
      recoveryKitPayload: 'secretly-recovery:v1:test-payload',
    );
    final exportTile = find.text('Show the key');

    setLargeSurface(tester);

    await tester.pumpWidget(buildSubject(controller));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      exportTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(exportTile);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Password1!');
    await tester.enterText(find.byType(TextField).at(1), 'Password1!');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(controller.lastExportPassword, 'Password1!');
    expect(find.text('secretly-recovery:v1:test-payload'), findsOneWidget);

    controller.disposeFake();
  });

  testWidgets(
    'safe backup screen localizes invalid recovery kit restore errors',
    (WidgetTester tester) async {
      final controller = _FakeSafeBackupController(
        restoreError: const EncryptedRestoreException(
          EncryptedRestoreFailureKind.invalidPayload,
        ),
      );
      final restoreTile = find.text('Restore with a key');

      setLargeSurface(tester);

      await tester.pumpWidget(buildSubject(controller));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        restoreTile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(restoreTile);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(0),
        'secretly-recovery:v1:broken-payload',
      );
      await tester.enterText(find.byType(TextField).at(1), 'Password1!');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await tester.pumpAndSettle();

      expect(find.text('Restore account?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await tester.pumpAndSettle();

      expect(
        controller.lastRestorePayload,
        'secretly-recovery:v1:broken-payload',
      );
      expect(controller.lastRestorePassword, 'Password1!');
      expect(find.text('Invalid recovery kit'), findsOneWidget);

      controller.disposeFake();
    },
  );

  testWidgets('safe backup screen toggles media backup preference', (
    WidgetTester tester,
  ) async {
    final controller = _FakeSafeBackupController();

    setLargeSurface(tester);

    await tester.pumpWidget(buildSubject(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Include media'));
    await tester.pumpAndSettle();

    expect(controller.safeBackupIncludeMedia, isTrue);

    controller.disposeFake();
  });
}

class _FakeSafeBackupController extends AppController {
  _FakeSafeBackupController({
    this.recoveryKitPayload = 'secretly-recovery:v1:default-payload',
    this.restoreError,
  });

  final StreamController<void> _changedController =
      StreamController<void>.broadcast();

  final String recoveryKitPayload;
  final Object? restoreError;

  String? lastExportPassword;
  String? lastRestorePayload;
  String? lastRestorePassword;
  bool _includeMedia = false;

  @override
  Stream<void> get changed => _changedController.stream;

  @override
  String get profileId => 'profile-1';

  // The media row is only offered once automatic backup is on.
  @override
  bool get safeBackupAutoEnabled => true;

  @override
  bool get safeBackupAutoServerEnabled => false;

  @override
  bool get safeBackupAutoDeviceEnabled => false;

  @override
  bool get safeBackupIncludeMedia => _includeMedia;

  @override
  int get safeBackupAutoIntervalMin => 24 * 60;

  @override
  int get safeBackupLastAutoSuccessAtMs => 0;

  @override
  String get safeBackupLastAutoError => '';

  @override
  int get safeBackupLastDeviceSavedAtMs => 0;

  @override
  Future<void> setSafeBackupIncludeMedia(bool value) async {
    _includeMedia = value;
    _changedController.add(null);
  }

  @override
  Future<bool> hasSafeBackupAutoPassword() async => false;

  @override
  Future<String> createRecoveryKitPayload({required String password}) async {
    lastExportPassword = password;
    return recoveryKitPayload;
  }

  @override
  Future<void> restoreFromRecoveryKitPayload({
    required String payload,
    required String password,
  }) async {
    lastRestorePayload = payload;
    lastRestorePassword = password;
    if (restoreError != null) {
      throw restoreError!;
    }
  }

  void disposeFake() {
    _changedController.close();
  }
}
