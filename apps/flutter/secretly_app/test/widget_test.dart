// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:secretly_app/main.dart';

void main() {
  testWidgets('App shows title and starts', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Secretly'), findsWidgets);
    expect(find.byType(Lottie), findsOneWidget);
  });
}
