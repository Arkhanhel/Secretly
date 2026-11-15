// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/security/social_recovery.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/ui/social_recovery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Э3: экран хранителя. Главное свойство — доля не уходит, пока человек не
// подтвердил, что услышал проверочные слова.

void main() {
  testWidgets('🔴 «Отправить свою часть» заблокирована до подтверждения слов',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('secretly_guardian_ui_'),
    );
    final db = await tester.runAsync(
      () => AppDb.openForTesting(path: '${dir!.path}/g.db'),
    );
    final controller = AppController()
      ..seedRoomRuntimeForTesting(
        db: db!,
        profileId: 'guardian-1',
        deviceId: 'guardian-device',
        crypto: DartCryptoProvider(Uint8List(32)),
      );
    final sent = <String>[];
    controller.controlMessageSenderForTesting = (to, text) async {
      sent.add(to);
    };
    // Владелец раздал долю этому хранителю.
    final share = GuardianShare(
      ownerProfileId: 'owner-1',
      ownerName: 'Иван',
      version: 1,
      threshold: 2,
      guardians: 3,
      shareB64: base64Encode(List<int>.generate(33, (i) => i + 1)),
      blobB64: base64Encode(List<int>.filled(64, 1)),
      receivedAtMs: 0,
    );
    await tester.runAsync(
      () => controller.handleGuardianCommandForTesting(
        text:
            '__secretly_guardian_share_v1__:${base64Url.encode(utf8.encode(jsonEncode(share.toJson())))}',
        senderProfileId: 'owner-1',
      ),
    );
    sent.clear(); // подтверждение владельцу не в счёт

    const code = RecoveryRequestCode(profileId: 'temp-1', nonce: 'abcdefghijkl');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GuardianHelpScreen(controller: controller, initialCode: code),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Иван'), findsOneWidget);
    final words = await tester.runAsync(() => SocialRecovery.checkWords(code.encode()));
    expect(find.text(words!.join('  ·  ')), findsOneWidget);

    final sendFinder = find.widgetWithText(FilledButton, 'Send my part');
    final sendFinderRu = find.widgetWithText(FilledButton, 'Отправить свою часть');
    final button = sendFinder.evaluate().isNotEmpty ? sendFinder : sendFinderRu;
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(sent, <String>['temp-1']);

    await tester.runAsync(() async {
      await db.close();
      await dir!.delete(recursive: true);
    });
  });
}
