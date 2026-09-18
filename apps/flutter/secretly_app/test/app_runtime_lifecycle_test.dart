// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_runtime_lifecycle.dart';
import 'package:secretly_app/app/desktop_link_flow.dart';

void main() {
  DesktopLinkRequest makeRequest({
    String requestId = 'req-1',
    String status = 'pending',
  }) {
    return DesktopLinkRequest(
      requestId: requestId,
      targetProfileId: 'profile-1',
      targetDeviceId: 'desktop-1',
      requestNonce: 'nonce-1',
      deviceLabel: 'Windows Desktop',
      createdAtMs: 1000,
      expiresAtMs: 2000,
      status: status,
    );
  }

  test('initialAuthFlowState matches startup bootstrap gate', () {
    expect(
      AppRuntimeLifecycleCoordinator.initialAuthFlowState(
        isDesktopOrWebPlatform: true,
        desktopAuthRequired: true,
        profileId: 'profile-1',
      ),
      AuthFlowState.unauthenticated,
    );

    expect(
      AppRuntimeLifecycleCoordinator.initialAuthFlowState(
        isDesktopOrWebPlatform: true,
        desktopAuthRequired: false,
        profileId: 'profile-1',
      ),
      AuthFlowState.authenticated,
    );

    expect(
      AppRuntimeLifecycleCoordinator.initialAuthFlowState(
        isDesktopOrWebPlatform: false,
        desktopAuthRequired: true,
        profileId: null,
      ),
      AuthFlowState.authenticated,
    );
  });

  test('desktopUnauthenticatedMode preserves warning and auth error state', () {
    final result = AppRuntimeLifecycleCoordinator.desktopUnauthenticatedMode(
      warning: ' warning ',
      error: 'fatal',
    );

    expect(result.authFlowState, AuthFlowState.authError);
    expect(result.authFlowError, 'fatal');
    expect(result.startupWarning, 'warning');
  });

  test('desktop retry warnings stay actionable', () {
    expect(
      AppRuntimeLifecycleCoordinator.desktopAuthRepairRetryWarning(),
      'Desktop device auth repair is retrying automatically. Keep this desktop open. If it still does not recover, sign in again via QR from your primary phone. Your synced profile is preserved.',
    );
    expect(
      AppRuntimeLifecycleCoordinator.desktopVerificationRetryWarning(),
      'Secretly could not confirm this desktop in Keys yet. Keeping your synced profile intact and retrying automatically. If this continues, sign in again via QR from your primary phone.',
    );
    expect(
      AppRuntimeLifecycleCoordinator.desktopRegistrationPendingWarning(),
      'Desktop device is not yet visible in Keys registration. Keeping your synced profile intact and retrying automatically. If this continues, sign in again via QR from your primary phone.',
    );
    expect(
      AppRuntimeLifecycleCoordinator.desktopAuthRepairRetryWarning(),
      isNot(contains('temporarily unavailable')),
    );
    expect(
      AppRuntimeLifecycleCoordinator.desktopVerificationRetryWarning(),
      isNot(contains('temporarily unavailable')),
    );
  });

  test('resolveMissingCurrentDevice allows auto repair for empty server device list', () {
    final result = AppRuntimeLifecycleCoordinator.resolveMissingCurrentDevice(
      isDesktopOrWebPlatform: true,
      explicitUserInitiatedRepair: false,
      currentDeviceId: 'desktop-1',
      serverDeviceIds: const <String>[],
    );

    expect(result.allowAutoRepair, isTrue);
    expect(result.desktopUnauthenticatedMode, isNull);
    expect(result.runtimeWarning, isNull);
  });

  test('resolveMissingCurrentDevice requires desktop reauth when current device is missing', () {
    final result = AppRuntimeLifecycleCoordinator.resolveMissingCurrentDevice(
      isDesktopOrWebPlatform: true,
      explicitUserInitiatedRepair: false,
      currentDeviceId: 'desktop-1',
      serverDeviceIds: const <String>['phone-1', 'desktop-2'],
    );

    expect(result.allowAutoRepair, isFalse);
    expect(result.desktopUnauthenticatedMode, isNotNull);
    expect(
      result.desktopUnauthenticatedMode!.authFlowError,
      'This desktop device was removed from your Secretly ID. Sign in again from your primary device to continue.',
    );
    expect(result.runtimeWarning, isNull);
  });

  test('resolveMissingCurrentDevice allows explicit user initiated relink', () {
    final result = AppRuntimeLifecycleCoordinator.resolveMissingCurrentDevice(
      isDesktopOrWebPlatform: true,
      explicitUserInitiatedRepair: true,
      currentDeviceId: 'desktop-1',
      serverDeviceIds: const <String>['phone-1'],
    );

    expect(result.allowAutoRepair, isTrue);
    expect(result.desktopUnauthenticatedMode, isNull);
    expect(result.runtimeWarning, isNull);
  });

  test('resolveServerBindingMismatch returns desktop reauth plan', () {
    final result = AppRuntimeLifecycleCoordinator.resolveServerBindingMismatch(
      isDesktopOrWebPlatform: true,
      savedBinding: 'keys=https://old;relay=https://old',
      expectedBinding: 'keys=https://new;relay=https://new',
    );

    expect(result.didMismatch, isTrue);
    expect(result.clearProfileId, isTrue);
    expect(result.clearServerBinding, isTrue);
    expect(result.transportBlocked, isFalse);
    expect(result.serverBindingMismatch, isFalse);
    expect(result.desktopUnauthenticatedMode, isNotNull);
    expect(
      result.desktopUnauthenticatedMode!.startupWarning,
      'Previous desktop profile belonged to another server. Select Create new account or Sign in via QR.',
    );
  });

  test('resolveServerBindingMismatch blocks mobile runtime', () {
    final result = AppRuntimeLifecycleCoordinator.resolveServerBindingMismatch(
      isDesktopOrWebPlatform: false,
      savedBinding: 'keys=https://old;relay=https://old',
      expectedBinding: 'keys=https://new;relay=https://new',
    );

    expect(result.didMismatch, isTrue);
    expect(result.transportBlocked, isTrue);
    expect(result.serverBindingMismatch, isTrue);
    expect(
      result.transportBlockedReason,
      'Profile belongs to a different server. Reset profile to continue.\n\nSaved: keys=https://old;relay=https://old\nNow:   keys=https://new;relay=https://new',
    );
    expect(result.desktopUnauthenticatedMode, isNull);
  });

  test('restartReset cancels awaiting requests and preserves next device id', () {
    final result = AppRuntimeLifecycleCoordinator.restartReset(
      desktopLinkRequests: <DesktopLinkRequest>[
        makeRequest(status: 'pending'),
        makeRequest(requestId: 'req-2', status: 'scanned'),
        makeRequest(requestId: 'req-3', status: 'rejected'),
      ],
      cancelAwaitingDesktopLinkRequests: true,
      nextDeviceId: 'desktop-new',
      knownOwnDeviceIds: <String>['desktop-new', ''],
    );

    expect(result.profileId, isNull);
    expect(result.deviceId, 'desktop-new');
    expect(result.knownOwnDeviceIds, <String>['desktop-new']);
    expect(result.desktopLinkRequests[0].status, 'cancelled');
    expect(result.desktopLinkRequests[1].status, 'cancelled');
    expect(result.desktopLinkRequests[2].status, 'rejected');
    expect(result.keysOnline, isFalse);
    expect(result.relayOnline, isFalse);
    expect(result.startupWarning, isNull);
    expect(result.transportBlocked, isFalse);
    expect(result.transportBlockedReason, isNull);
    expect(result.serverBindingMismatch, isFalse);
  });
}