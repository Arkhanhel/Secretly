// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/rooms/room_policy_failure.dart';
import 'package:secretly_app/ui/new_group_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('create room works even without selected participants', (
    WidgetTester tester,
  ) async {
    final controller = _FakeNewGroupController();

    await tester.pumpWidget(
      wrapWithApp(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NewGroupScreen(controller: controller),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(controller.createCalls, hasLength(1));
    expect(controller.createCalls.single.memberProfileIds, isEmpty);
    expect(controller.createCalls.single.title, 'New room');
  });

  testWidgets('selected contacts are sent during room creation', (
    WidgetTester tester,
  ) async {
    final controller = _FakeNewGroupController(
      contacts: const <Contact>[
        Contact(profileId: 'peer-1', displayName: 'Alice'),
      ],
    );

    await tester.pumpWidget(
      wrapWithApp(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NewGroupScreen(controller: controller),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alpha room');
    await tester.tap(find.text('Alice'));
    await tester.pump();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(controller.createCalls, hasLength(1));
    expect(controller.createCalls.single.title, 'Alpha room');
    expect(controller.createCalls.single.memberProfileIds, <String>['peer-1']);
  });

  testWidgets('room creation shows localized relay failure', (
    WidgetTester tester,
  ) async {
    final controller = _FakeNewGroupController(
      createError: RoomPolicyFailure(RoomPolicyFailureCode.serviceUnavailable),
    );

    await tester.pumpWidget(
      wrapWithApp(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NewGroupScreen(controller: controller),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text(
        'Room service is unavailable right now. Try again when the relay reconnects.',
      ),
      findsOneWidget,
    );
  });
}

class _CreateGroupCall {
  const _CreateGroupCall({
    required this.title,
    required this.memberProfileIds,
    required this.autoDeleteSeconds,
  });

  final String title;
  final List<String> memberProfileIds;
  final int? autoDeleteSeconds;
}

class _FakeNewGroupController extends AppController {
  _FakeNewGroupController({
    this.contacts = const <Contact>[],
    this.createError,
  });

  final List<Contact> contacts;
  final Object? createError;
  final List<_CreateGroupCall> createCalls = <_CreateGroupCall>[];

  @override
  Future<List<Contact>> listContacts() async => contacts;

  @override
  Future<String> createGroup({
    required String title,
    required List<String> memberProfileIds,
    int? autoDeleteSeconds,
  }) async {
    createCalls.add(
      _CreateGroupCall(
        title: title,
        memberProfileIds: List<String>.from(memberProfileIds),
        autoDeleteSeconds: autoDeleteSeconds,
      ),
    );
    if (createError != null) {
      throw createError!;
    }
    return 'group:created';
  }
}
