// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ui/room_details_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject(AppController controller) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const <Locale>[Locale('en'), Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: RoomPermissionsScreen(
        controller: controller,
        groupId: 'group:test',
      ),
    );
  }

  testWidgets(
    'release-facing room settings matrix shows shipped settings including pin control',
    (WidgetTester tester) async {
      final controller = _FakeRoomSettingsController(
        RoomSettings.defaults(ownerProfileId: 'owner-1').copyWith(
          allowTextMessages: false,
          allowMedia: true,
          allowAddMembers: false,
          joinApprovalRequired: true,
          allowPinMessages: true,
          allowChangeGroupInfo: true,
          allowChangeTag: true,
          slowModeSeconds: 30,
          chatHistoryVisible: true,
        ),
      );

      // The permissions screen is a lazy ListView; the islands redesign moved the
      // Slow-mode controls into the Messages section, pushing later sections below
      // the default 800x600 fold. Use a tall viewport so every section is built.
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject(controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Joining'), findsOneWidget);

      for (final title in const <String>[
        'Send text messages',
        'Send media',
        'Pin messages',
        'Add participants',
        'Join only after approval',
      ]) {
        expect(find.text(title), findsOneWidget);
      }

      await tester.scrollUntilVisible(find.text('Privacy'), 240);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Show history to new members'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Room profile'), 240);
      expect(find.text('Room profile'), findsOneWidget);
      expect(find.text('Change room profile'), findsOneWidget);
      expect(find.text('Edit own room tag'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Slow mode'), 240);
      expect(find.text('Slow mode'), findsOneWidget);
    },
  );
}

class _FakeRoomSettingsController extends AppController {
  _FakeRoomSettingsController(this._settings);

  final RoomSettings _settings;

  @override
  Future<RoomSettings> getRoomSettings(String groupId) async => _settings;
}
