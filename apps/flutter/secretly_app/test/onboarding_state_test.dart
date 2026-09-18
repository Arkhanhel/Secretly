// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/onboarding_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('markOnboardingComplete persists completion', () async {
    expect(await isOnboardingComplete(), isFalse);

    await markOnboardingComplete();

    expect(await isOnboardingComplete(), isTrue);
  });

  test('resetOnboardingComplete returns next launch to onboarding', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kOnboardingDoneKey: true,
    });
    expect(await isOnboardingComplete(), isTrue);

    await resetOnboardingComplete();

    expect(await isOnboardingComplete(), isFalse);
  });
}
