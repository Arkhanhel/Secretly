// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'desktop_link_flow.dart';

class DesktopUnauthenticatedModeResult {
  const DesktopUnauthenticatedModeResult({
    required this.authFlowState,
    required this.authFlowError,
    required this.startupWarning,
  });

  final AuthFlowState authFlowState;
  final String? authFlowError;
  final String? startupWarning;
}

class MissingCurrentDeviceResolution {
  const MissingCurrentDeviceResolution._({
    required this.allowAutoRepair,
    required this.desktopUnauthenticatedMode,
    required this.runtimeWarning,
  });

  const MissingCurrentDeviceResolution.allowed()
    : this._(
        allowAutoRepair: true,
        desktopUnauthenticatedMode: null,
        runtimeWarning: null,
      );

  const MissingCurrentDeviceResolution.desktopReauthRequired({
    required DesktopUnauthenticatedModeResult desktopUnauthenticatedMode,
  }) : this._(
         allowAutoRepair: false,
         desktopUnauthenticatedMode: desktopUnauthenticatedMode,
         runtimeWarning: null,
       );

  const MissingCurrentDeviceResolution.blocked({required String runtimeWarning})
    : this._(
        allowAutoRepair: false,
        desktopUnauthenticatedMode: null,
        runtimeWarning: runtimeWarning,
      );

  final bool allowAutoRepair;
  final DesktopUnauthenticatedModeResult? desktopUnauthenticatedMode;
  final String? runtimeWarning;
}

class ServerBindingMismatchResolution {
  const ServerBindingMismatchResolution._({
    required this.didMismatch,
    required this.clearProfileId,
    required this.clearServerBinding,
    required this.serverBindingMismatch,
    required this.transportBlocked,
    required this.transportBlockedReason,
    required this.desktopUnauthenticatedMode,
  });

  const ServerBindingMismatchResolution.none()
    : this._(
        didMismatch: false,
        clearProfileId: false,
        clearServerBinding: false,
        serverBindingMismatch: false,
        transportBlocked: false,
        transportBlockedReason: null,
        desktopUnauthenticatedMode: null,
      );

  const ServerBindingMismatchResolution.desktopReauthRequired({
    required DesktopUnauthenticatedModeResult desktopUnauthenticatedMode,
  }) : this._(
         didMismatch: true,
         clearProfileId: true,
         clearServerBinding: true,
         serverBindingMismatch: false,
         transportBlocked: false,
         transportBlockedReason: null,
         desktopUnauthenticatedMode: desktopUnauthenticatedMode,
       );

  const ServerBindingMismatchResolution.transportBlocked({
    required String transportBlockedReason,
  }) : this._(
         didMismatch: true,
         clearProfileId: false,
         clearServerBinding: false,
         serverBindingMismatch: true,
         transportBlocked: true,
         transportBlockedReason: transportBlockedReason,
         desktopUnauthenticatedMode: null,
       );

  final bool didMismatch;
  final bool clearProfileId;
  final bool clearServerBinding;
  final bool serverBindingMismatch;
  final bool transportBlocked;
  final String? transportBlockedReason;
  final DesktopUnauthenticatedModeResult? desktopUnauthenticatedMode;
}

class AppRuntimeResetResult {
  const AppRuntimeResetResult({
    required this.profileId,
    required this.deviceId,
    required this.knownOwnDeviceIds,
    required this.desktopLinkRequests,
    required this.keysOnline,
    required this.relayOnline,
    required this.startupWarning,
    required this.transportBlocked,
    required this.transportBlockedReason,
    required this.serverBindingMismatch,
  });

  final String? profileId;
  final String? deviceId;
  final List<String> knownOwnDeviceIds;
  final List<DesktopLinkRequest> desktopLinkRequests;
  final bool keysOnline;
  final bool relayOnline;
  final String? startupWarning;
  final bool transportBlocked;
  final String? transportBlockedReason;
  final bool serverBindingMismatch;
}

class AppRuntimeLifecycleCoordinator {
  const AppRuntimeLifecycleCoordinator._();

  static bool shouldBootstrapRuntimeForStartup({
    required bool isDesktopOrWebPlatform,
    required bool desktopAuthRequired,
    required String? profileId,
  }) {
    if (!isDesktopOrWebPlatform) return true;
    if (desktopAuthRequired) return false;
    final normalized = (profileId ?? '').trim();
    return normalized.isNotEmpty && !normalized.startsWith('LOCAL-');
  }

  static AuthFlowState initialAuthFlowState({
    required bool isDesktopOrWebPlatform,
    required bool desktopAuthRequired,
    required String? profileId,
  }) {
    return shouldBootstrapRuntimeForStartup(
          isDesktopOrWebPlatform: isDesktopOrWebPlatform,
          desktopAuthRequired: desktopAuthRequired,
          profileId: profileId,
        )
        ? AuthFlowState.authenticated
        : AuthFlowState.unauthenticated;
  }

  static DesktopUnauthenticatedModeResult desktopUnauthenticatedMode({
    String? warning,
    String? error,
  }) {
    return DesktopUnauthenticatedModeResult(
      authFlowState:
          error == null ? AuthFlowState.unauthenticated : AuthFlowState.authError,
      authFlowError: error,
      startupWarning: _normalizeWarning(warning),
    );
  }

  static String desktopAuthRepairRetryWarning() {
    return 'Desktop device auth repair is retrying automatically. Keep this desktop open. If it still does not recover, sign in again via QR from your primary phone. Your synced profile is preserved.';
  }

  static String desktopVerificationRetryWarning() {
    return 'Secretly could not confirm this desktop in Keys yet. Keeping your synced profile intact and retrying automatically. If this continues, sign in again via QR from your primary phone.';
  }

  static String desktopRegistrationPendingWarning() {
    return 'Desktop device is not yet visible in Keys registration. Keeping your synced profile intact and retrying automatically. If this continues, sign in again via QR from your primary phone.';
  }

  static MissingCurrentDeviceResolution resolveMissingCurrentDevice({
    required bool isDesktopOrWebPlatform,
    required bool explicitUserInitiatedRepair,
    required String currentDeviceId,
    required Iterable<String> serverDeviceIds,
  }) {
    final normalizedCurrentDeviceId = currentDeviceId.trim();
    final normalizedServerDeviceIds = serverDeviceIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (explicitUserInitiatedRepair ||
        normalizedCurrentDeviceId.isEmpty ||
        normalizedServerDeviceIds.isEmpty ||
        normalizedServerDeviceIds.contains(normalizedCurrentDeviceId)) {
      return const MissingCurrentDeviceResolution.allowed();
    }

    if (isDesktopOrWebPlatform) {
      return MissingCurrentDeviceResolution.desktopReauthRequired(
        desktopUnauthenticatedMode: desktopUnauthenticatedMode(
          warning:
              'Desktop device access was revoked on another device. Generate a new QR from your primary device to continue.',
          error:
              'This desktop device was removed from your Secretly ID. Sign in again from your primary device to continue.',
        ),
      );
    }

    return const MissingCurrentDeviceResolution.blocked(
      runtimeWarning:
          'This device was removed from your Secretly ID. Reset profile or restore from a recovery kit to continue.',
    );
  }

  static ServerBindingMismatchResolution resolveServerBindingMismatch({
    required bool isDesktopOrWebPlatform,
    required String? savedBinding,
    required String expectedBinding,
  }) {
    final saved = (savedBinding ?? '').trim();
    final expected = expectedBinding.trim();
    if (saved.isEmpty || saved == expected) {
      return const ServerBindingMismatchResolution.none();
    }

    if (isDesktopOrWebPlatform) {
      return ServerBindingMismatchResolution.desktopReauthRequired(
        desktopUnauthenticatedMode: desktopUnauthenticatedMode(
          warning:
              'Previous desktop profile belonged to another server. Select Create new account or Sign in via QR.',
        ),
      );
    }

    return ServerBindingMismatchResolution.transportBlocked(
      transportBlockedReason:
          'Profile belongs to a different server. Reset profile to continue.\n\n'
          'Saved: $saved\n'
          'Now:   $expected',
    );
  }

  static AppRuntimeResetResult restartReset({
    required List<DesktopLinkRequest> desktopLinkRequests,
    required bool cancelAwaitingDesktopLinkRequests,
    String? nextDeviceId,
    Iterable<String> knownOwnDeviceIds = const <String>[],
  }) {
    final requests = cancelAwaitingDesktopLinkRequests
        ? DesktopLinkStateMachine.cancelAwaitingRequests(desktopLinkRequests)
        : List<DesktopLinkRequest>.from(desktopLinkRequests);
    final normalizedKnownOwnDeviceIds = knownOwnDeviceIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return AppRuntimeResetResult(
      profileId: null,
      deviceId: nextDeviceId,
      knownOwnDeviceIds: normalizedKnownOwnDeviceIds,
      desktopLinkRequests: requests,
      keysOnline: false,
      relayOnline: false,
      startupWarning: null,
      transportBlocked: false,
      transportBlockedReason: null,
      serverBindingMismatch: false,
    );
  }

  static String? _normalizeWarning(String? warning) {
    final normalized = (warning ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}