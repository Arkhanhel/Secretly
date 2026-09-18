// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/contact_action_failure.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/l10n/app_localizations_en.dart';
import 'package:secretly_app/ui/contact_action_error_text.dart';
import 'package:secretly_app/ui/contacts_screen.dart';
import 'package:secretly_app/ui/direct_message_error_text.dart';
import 'package:secretly_app/ui/new_chat_picker_screen.dart';
import 'package:secretly_app/ui/privacy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  test('contact action helper localizes typed failures', () {
    final l10n = AppLocalizationsEn();

    expect(
      contactActionErrorText(
        l10n,
        ContactActionFailure(ContactActionFailureCode.profileNotFound),
      ),
      'Secretly ID was not found on this server.',
    );
    expect(
      contactActionErrorText(
        l10n,
        StateError('Calls are disabled for this contact'),
      ),
      'Calls are disabled for this contact.',
    );
    expect(
      contactLookupErrorText(l10n, StateError('unexpected lookup error')),
      'Search is unavailable right now. Try again in a moment.',
    );
    expect(
      contactActionErrorText(
        l10n,
        StateError('peer identity key changed for profile=peer device=dev-2'),
      ),
      'This contact\'s safety key changed. Verify the new device before continuing.',
    );
  });

  test('direct message helper localizes device lookup failures', () {
    final l10n = AppLocalizationsEn();

    expect(
      directMessageErrorText(
        l10n,
        StateError('listDevices failed: 503 upstream unavailable'),
      ),
      'Server is unavailable right now. Try again in a moment.',
    );
    expect(
      directMessageErrorText(
        l10n,
        ContactActionFailure(ContactActionFailureCode.generic),
      ),
      "Couldn't complete the action. Try again.",
    );
    expect(
      directMessageErrorText(
        l10n,
        StateError('listDevices failed: 401 unknown requester device'),
      ),
      l10n.sendFailed('Bad state: listDevices failed: 401 unknown requester device'),
    );
    expect(
      directMessageErrorText(
        l10n,
        StateError('peer identity key changed for profile=peer device=dev-2'),
      ),
      'This contact\'s safety key changed. Verify the new device before continuing.',
    );
  });

  testWidgets('Contacts screen shows localized lookup error', (
    WidgetTester tester,
  ) async {
    final controller = _FakeContactActionController(
      lookupError: ContactActionFailure(
        ContactActionFailureCode.serviceUnavailable,
      ),
    );
    addTearDown(controller.disposeFake);

    await tester.pumpWidget(
      wrapWithApp(ContactsScreen(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Search'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).first, 'alex');
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Server is unavailable right now. Try again in a moment.'),
      findsOneWidget,
    );
  });

  testWidgets('New chat picker shows localized add-contact error', (
    WidgetTester tester,
  ) async {
    final controller = _FakeContactActionController(
      lookupResults: const <UserLookupResult>[
        UserLookupResult(
          profileId: 'peer-1',
          nickname: 'Alice',
          alreadyInContacts: false,
        ),
      ],
      addContactError: ContactActionFailure(
        ContactActionFailureCode.transportBlocked,
      ),
    );
    addTearDown(controller.disposeFake);

    await tester.pumpWidget(
      wrapWithApp(NewChatPickerScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ali');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();

    expect(
      find.text(
        'This action is unavailable because the app is bound to a different server.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Privacy screen shows localized unblock error', (
    WidgetTester tester,
  ) async {
    final controller = _FakeContactActionController(
      blockedProfiles: const <String>['peer-1'],
      setProfileBlockedError: ContactActionFailure(
        ContactActionFailureCode.serviceUnavailable,
      ),
    );
    addTearDown(controller.disposeFake);

    await tester.pumpWidget(wrapWithApp(PrivacyScreen(controller: controller)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Unblock'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Unblock'));
    await tester.pump();

    expect(
      find.text('Server is unavailable right now. Try again in a moment.'),
      findsOneWidget,
    );
  });
}

class _FakeContactActionController extends AppController {
  _FakeContactActionController({
    this.lookupResults = const <UserLookupResult>[],
    this.blockedProfiles = const <String>[],
    this.lookupError,
    this.addContactError,
    this.setProfileBlockedError,
  });

  final StreamController<void> _changedController =
      StreamController<void>.broadcast();

  List<Contact> contacts = const <Contact>[];
  List<UserLookupResult> lookupResults;
  List<String> blockedProfiles;
  final Object? lookupError;
  final Object? addContactError;
  final Object? setProfileBlockedError;

  @override
  Stream<void> get changed => _changedController.stream;

  @override
  Future<List<Contact>> listContacts() async => contacts;

  @override
  Future<List<UserLookupResult>> lookupUsers(
    String query, {
    int limit = 20,
  }) async {
    if (lookupError != null) {
      throw lookupError!;
    }
    return lookupResults;
  }

  @override
  Future<void> addContact({
    required String profileId,
    String? displayName,
    bool displayNameIsCustom = false,
  }) async {
    if (addContactError != null) {
      throw addContactError!;
    }
  }

  @override
  Future<List<String>> listBlockedProfiles() async => blockedProfiles;

  @override
  Future<void> setProfileBlocked({
    required String profileId,
    required bool blocked,
    required bool deleteChatHistory,
  }) async {
    if (setProfileBlockedError != null) {
      throw setProfileBlockedError!;
    }
  }

  void disposeFake() {
    _changedController.close();
  }
}
