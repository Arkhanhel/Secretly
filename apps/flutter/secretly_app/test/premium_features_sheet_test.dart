// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium_features_sheet.dart';

void main() {
  testWidgets('premium features sheet opens and lists localized features', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPremiumFeaturesSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The sheet header renders.
    expect(find.text('Secretly Premium'), findsOneWidget);
    // English is the default test locale, so feature names come out in English.
    // The first feature's name + its lighter description line are on-screen
    // (later rows are below the fold in the lazy list).
    expect(find.text('Profile frames & covers'), findsOneWidget);
    expect(
      find.textContaining('Animated rings around your avatar'),
      findsOneWidget,
    );
  });
}
