// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/diagnostics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> scrollToText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text, skipOffstage: false),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 90));
    await tester.pumpAndSettle();
  }

  Finder textInTree(String text) => find.text(text, skipOffstage: false);

  Widget buildSubject(AppController controller) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiagnosticsScreen(controller: controller),
    );
  }

  testWidgets('Diagnostics screen shows message diagnostics sections', (
    WidgetTester tester,
  ) async {
    final controller = AppController();

    await tester.pumpWidget(buildSubject(controller));
    await tester.pumpAndSettle();

    expect(textInTree('Copy report'), findsOneWidget);
    expect(textInTree('Force outbox pump'), findsNothing);
    expect(textInTree('Recover stuck sends'), findsNothing);

    await tester.longPress(textInTree('For support'));
    await tester.pumpAndSettle();

    await scrollToText(tester, 'Force outbox pump');

    expect(textInTree('Force outbox pump'), findsOneWidget);
    expect(textInTree('Recover stuck sends'), findsOneWidget);
    expect(textInTree('message_queue'), findsOneWidget);
    expect(textInTree('actionable_message_diagnostics'), findsOneWidget);
    expect(textInTree('pending'), findsOneWidget);
    expect(textInTree('sending'), findsOneWidget);
    expect(textInTree('retry'), findsOneWidget);
    expect(textInTree('failed'), findsOneWidget);

    await scrollToText(tester, 'actionable_call_diagnostics');

    expect(textInTree('call_diagnostics'), findsOneWidget);
    expect(textInTree('actionable_call_diagnostics'), findsOneWidget);

    await scrollToText(tester, 'message_attempt_trace');

    expect(textInTree('message_state_trace'), findsOneWidget);
    expect(textInTree('message_attempt_trace'), findsOneWidget);
  });

  testWidgets('Diagnostics force pump action shows snackbar', (
    WidgetTester tester,
  ) async {
    final controller = AppController();

    await tester.pumpWidget(buildSubject(controller));
    await tester.pumpAndSettle();

    await tester.longPress(textInTree('For support'));
    await tester.pumpAndSettle();

    await scrollToText(tester, 'Force outbox pump');

    final forcePumpButton = find.widgetWithText(
      FilledButton,
      'Force outbox pump',
    );

    await tester.tap(forcePumpButton);
    await tester.pumpAndSettle();

    expect(find.text('Outbox pump triggered'), findsOneWidget);
  });

  testWidgets('Diagnostics recover action shows snackbar', (
    WidgetTester tester,
  ) async {
    final controller = AppController();

    await tester.pumpWidget(buildSubject(controller));
    await tester.pumpAndSettle();

    await tester.longPress(textInTree('For support'));
    await tester.pumpAndSettle();

    await scrollToText(tester, 'Recover stuck sends');

    final recoverButton = find.widgetWithText(
      FilledButton,
      'Recover stuck sends',
    );

    await tester.tap(recoverButton);
    await tester.pumpAndSettle();

    expect(find.text('Recovered stuck sends: 0'), findsOneWidget);
  });
}
