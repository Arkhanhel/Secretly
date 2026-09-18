// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:shared_preferences/shared_preferences.dart';

const kOnboardingDoneKey = 'onboarding_complete_v1';

Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kOnboardingDoneKey) ?? false;
}

Future<void> markOnboardingComplete({SharedPreferences? prefs}) async {
  final store = prefs ?? await SharedPreferences.getInstance();
  await store.setBool(kOnboardingDoneKey, true);
}

Future<void> resetOnboardingComplete({SharedPreferences? prefs}) async {
  final store = prefs ?? await SharedPreferences.getInstance();
  await store.remove(kOnboardingDoneKey);
}
