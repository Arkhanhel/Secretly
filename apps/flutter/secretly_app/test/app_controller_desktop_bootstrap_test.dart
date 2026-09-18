// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

void main() {
  test('desktop runtime stays disabled while auth gate is active', () {
    expect(
      AppController.shouldBootstrapRuntimeForStartup(
        isDesktopOrWebPlatform: true,
        desktopAuthRequired: true,
        profileId: 'profile-123',
      ),
      isFalse,
    );

    expect(
      AppController.shouldBootstrapRuntimeForStartup(
        isDesktopOrWebPlatform: true,
        desktopAuthRequired: false,
        profileId: '',
      ),
      isFalse,
    );

    expect(
      AppController.shouldBootstrapRuntimeForStartup(
        isDesktopOrWebPlatform: true,
        desktopAuthRequired: false,
        profileId: 'LOCAL-temp-profile',
      ),
      isFalse,
    );
  });

  test('desktop runtime requires a server-backed identity', () {
    expect(
      AppController.shouldBootstrapRuntimeForStartup(
        isDesktopOrWebPlatform: true,
        desktopAuthRequired: false,
        profileId: 'profile-123',
      ),
      isTrue,
    );
  });

  test('mobile startup is never blocked by desktop auth gating', () {
    expect(
      AppController.shouldBootstrapRuntimeForStartup(
        isDesktopOrWebPlatform: false,
        desktopAuthRequired: true,
        profileId: null,
      ),
      isTrue,
    );
  });

  test('authenticated runtime needs db plus server-backed identity', () {
    expect(
      AppController.canStartAuthenticatedRuntime(
        shouldBootstrapRuntime: true,
        hasOpenDatabase: true,
        profileId: 'profile-123',
        deviceId: 'device-123',
      ),
      isTrue,
    );

    expect(
      AppController.canStartAuthenticatedRuntime(
        shouldBootstrapRuntime: true,
        hasOpenDatabase: false,
        profileId: 'profile-123',
        deviceId: 'device-123',
      ),
      isFalse,
    );

    expect(
      AppController.canStartAuthenticatedRuntime(
        shouldBootstrapRuntime: true,
        hasOpenDatabase: true,
        profileId: null,
        deviceId: 'device-123',
      ),
      isFalse,
    );

    expect(
      AppController.canStartAuthenticatedRuntime(
        shouldBootstrapRuntime: true,
        hasOpenDatabase: true,
        profileId: 'LOCAL-temp-profile',
        deviceId: 'device-123',
      ),
      isFalse,
    );

    expect(
      AppController.canStartAuthenticatedRuntime(
        shouldBootstrapRuntime: true,
        hasOpenDatabase: true,
        profileId: 'profile-123',
        deviceId: '',
      ),
      isFalse,
    );
  });
}
