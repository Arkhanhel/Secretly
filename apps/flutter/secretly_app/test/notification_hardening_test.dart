// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppController suppresses stale inbound notifications', () {
    const nowMs = 2_000_000;

    expect(
      AppController.shouldSuppressNotificationForSourceAge(
        nowMs: nowMs,
        sourceCreatedAtMs: nowMs - (16 * 60 * 1000),
      ),
      isTrue,
    );
    expect(
      AppController.shouldSuppressNotificationForSourceAge(
        nowMs: nowMs,
        sourceCreatedAtMs: nowMs - (2 * 60 * 1000),
      ),
      isFalse,
    );
    expect(
      AppController.shouldSuppressNotificationForSourceAge(
        nowMs: nowMs,
        sourceCreatedAtMs: null,
      ),
      isFalse,
    );
  });

  test('AppController resolves push platform for supported runtimes', () {
    expect(
      AppController.resolvePushPlatformForTesting(
        isAndroid: true,
        isIOS: false,
      ),
      'android',
    );
    expect(
      AppController.resolvePushPlatformForTesting(
        isAndroid: false,
        isIOS: true,
      ),
      'ios',
    );
    expect(
      AppController.resolvePushPlatformForTesting(
        isAndroid: false,
        isIOS: false,
      ),
      isEmpty,
    );
  });
}