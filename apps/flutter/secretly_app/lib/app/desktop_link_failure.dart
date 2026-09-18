// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
enum DesktopLinkFailureCode {
  targetTransportBlocked,
  targetIdentityNotServerBacked,
  targetProfileUnavailable,
  targetDeviceUnavailable,

  /// Сервер ключей ОТВЕТИЛ, но отказался принять связку ключей этого
  /// устройства. Без опубликованной связки телефону нечем зашифровать ответ,
  /// поэтому спаривание невозможно — но это не поломка сети и не «сервер
  /// офлайн», как показывали раньше.
  keysPublishRejected,
  desktopCompanionEntitlementRequired,
  desktopCompanionLimitReached,
  desktopPrimaryDeviceRequired,
  invalidQrPayload,
  qrExpired,
  serverBindingMismatch,
  syncTargetProfileMismatch,
  syncRequestNotFound,
  syncSessionExpired,
  syncNonceMismatch,
  syncRequestStateMismatch,
  syncTargetDeviceMismatch,
  decisionDeclined,
  invalidSyncPayload,
  syncInterrupted,
}

class DesktopLinkFailure implements Exception {
  DesktopLinkFailure(
    this.code, {
    String? message,
    this.cause,
  }) : message = message ?? _defaultDesktopLinkFailureMessage(code);

  final DesktopLinkFailureCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

DesktopLinkFailure desktopLinkFailureFromError(
  Object error, {
  DesktopLinkFailureCode fallbackCode = DesktopLinkFailureCode.invalidSyncPayload,
  String? fallbackMessage,
}) {
  if (error is DesktopLinkFailure) {
    return error;
  }
  return DesktopLinkFailure(
    fallbackCode,
    message: fallbackMessage,
    cause: error,
  );
}

String _defaultDesktopLinkFailureMessage(DesktopLinkFailureCode code) {
  switch (code) {
    case DesktopLinkFailureCode.targetTransportBlocked:
      return 'Transport is blocked for current server binding.';
    case DesktopLinkFailureCode.targetIdentityNotServerBacked:
      return 'Desktop identity is not server-backed yet.';
    case DesktopLinkFailureCode.targetProfileUnavailable:
      return 'Desktop profile is not visible on server yet. Keep desktop app open and retry in a few seconds.';
    case DesktopLinkFailureCode.targetDeviceUnavailable:
      return 'Desktop device is not registered on server yet. Keep desktop app open and regenerate QR.';
    case DesktopLinkFailureCode.keysPublishRejected:
      return 'The server refused this desktop key bundle, so pairing cannot start. Check that the computer clock is set automatically, then regenerate the QR.';
    case DesktopLinkFailureCode.desktopCompanionEntitlementRequired:
      return 'Desktop companion access is not enabled for this profile. Activate companion access on your primary phone, then retry linking desktop.';
    case DesktopLinkFailureCode.desktopCompanionLimitReached:
      return 'Desktop companion limit reached for this profile. Remove an old desktop session or increase the available companion seats.';
    case DesktopLinkFailureCode.desktopPrimaryDeviceRequired:
      return 'Create the main Secretly account on a phone first, then link desktop by QR.';
    case DesktopLinkFailureCode.invalidQrPayload:
      return 'Unsupported QR payload';
    case DesktopLinkFailureCode.qrExpired:
      return 'QR code expired. Generate a new one on desktop.';
    case DesktopLinkFailureCode.serverBindingMismatch:
      return 'This QR belongs to a different server. Switch to the same server on phone and desktop.';
    case DesktopLinkFailureCode.syncTargetProfileMismatch:
      return 'Sync bundle target profile mismatch. Regenerate QR and retry.';
    case DesktopLinkFailureCode.syncRequestNotFound:
      return 'Desktop sync request not found or already expired. Generate a new QR.';
    case DesktopLinkFailureCode.syncSessionExpired:
      return 'QR session expired. Generate a new QR and retry.';
    case DesktopLinkFailureCode.syncNonceMismatch:
      return 'QR session validation failed (nonce mismatch). Generate a new QR.';
    case DesktopLinkFailureCode.syncRequestStateMismatch:
      return 'Sync request state mismatch. Regenerate QR and retry.';
    case DesktopLinkFailureCode.syncTargetDeviceMismatch:
      return 'Sync bundle target device mismatch. Regenerate QR and retry.';
    case DesktopLinkFailureCode.decisionDeclined:
      return 'Sign-in was declined on the primary phone. Generate a new QR to retry.';
    case DesktopLinkFailureCode.invalidSyncPayload:
      return 'Invalid desktop sync payload. Regenerate QR and retry.';
    case DesktopLinkFailureCode.syncInterrupted:
      return 'Secure sync was interrupted before completion. Generate a new QR and retry.';
  }
}