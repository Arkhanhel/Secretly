// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../security/restore_payload_validation.dart'
  show validateSafeBackupDbSnapshot, validateSafeBackupFiles, validateServerBindingValue;
import '../security/secure_secrets.dart' show SecureSecrets;

import 'desktop_link_failure.dart'
  show DesktopLinkFailure, DesktopLinkFailureCode, desktopLinkFailureFromError;

const String desktopLinkQrType = 'secretly_desktop_link_v1';
const String desktopSyncAttachmentMime =
  'application/x-secretly-device-sync-v1';
const String desktopLinkDecisionAttachmentMime =
  'application/x-secretly-device-link-decision-v1';
const int desktopLinkRequestTtlMs = 10 * 60 * 1000;

enum AuthFlowState {
  unauthenticated,
  qrSessionPending,
  qrScannedWaitConfirm,
  bundleApplying,
  authenticated,
  authError,
}

class DesktopLinkRequest {
  const DesktopLinkRequest({
    required this.requestId,
    required this.targetProfileId,
    required this.targetDeviceId,
    required this.requestNonce,
    required this.deviceLabel,
    required this.createdAtMs,
    required this.expiresAtMs,
    required this.status,
  });

  final String requestId;
  final String targetProfileId;
  final String targetDeviceId;
  final String requestNonce;
  final String deviceLabel;
  final int createdAtMs;
  final int expiresAtMs;
  final String status;

  bool get isAwaitingDecision => status == 'pending' || status == 'scanned';

  bool isExpiredAt(int nowMs) => expiresAtMs <= nowMs;

  DesktopLinkRequest copyWith({
    String? requestId,
    String? targetProfileId,
    String? targetDeviceId,
    String? requestNonce,
    String? deviceLabel,
    int? createdAtMs,
    int? expiresAtMs,
    String? status,
  }) {
    return DesktopLinkRequest(
      requestId: requestId ?? this.requestId,
      targetProfileId: targetProfileId ?? this.targetProfileId,
      targetDeviceId: targetDeviceId ?? this.targetDeviceId,
      requestNonce: requestNonce ?? this.requestNonce,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'request_id': requestId,
      'target_profile_id': targetProfileId,
      'target_device_id': targetDeviceId,
      'request_nonce': requestNonce,
      'device_label': deviceLabel,
      'created_at_ms': createdAtMs,
      'expires_at_ms': expiresAtMs,
      'status': status,
    };
  }

  static DesktopLinkRequest? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final requestId = (m['request_id'] as String?)?.trim() ?? '';
    final targetProfileId = (m['target_profile_id'] as String?)?.trim() ?? '';
    final targetDeviceId = (m['target_device_id'] as String?)?.trim() ?? '';
    final requestNonce = (m['request_nonce'] as String?)?.trim() ?? '';
    if (requestId.isEmpty ||
        targetProfileId.isEmpty ||
        targetDeviceId.isEmpty ||
        requestNonce.isEmpty) {
      return null;
    }
    final deviceLabel = ((m['device_label'] as String?) ?? 'Desktop/Web')
        .trim();
    final createdAtMs =
        (m['created_at_ms'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs =
        (m['expires_at_ms'] as num?)?.toInt() ??
        (createdAtMs + desktopLinkRequestTtlMs);
    final status = ((m['status'] as String?) ?? 'pending').trim().toLowerCase();
    return DesktopLinkRequest(
      requestId: requestId,
      targetProfileId: targetProfileId,
      targetDeviceId: targetDeviceId,
      requestNonce: requestNonce,
      deviceLabel: deviceLabel.isEmpty ? 'Desktop/Web' : deviceLabel,
      createdAtMs: createdAtMs,
      expiresAtMs: expiresAtMs,
      status: status.isEmpty ? 'pending' : status,
    );
  }
}

class DesktopLinkQrPayload {
  const DesktopLinkQrPayload({
    required this.requestId,
    required this.targetProfileId,
    required this.targetDeviceId,
    required this.requestNonce,
    required this.deviceLabel,
    required this.expiresAtMs,
    required this.serverBinding,
  });

  final String requestId;
  final String targetProfileId;
  final String targetDeviceId;
  final String requestNonce;
  final String deviceLabel;
  final int? expiresAtMs;
  final String serverBinding;

  bool isExpiredAt(int nowMs) => expiresAtMs != null && nowMs > expiresAtMs!;

  static DesktopLinkQrPayload? tryParse(String raw) {
    final parsed = _parseDesktopLinkQrPayload(raw);
    final reqType = (parsed['type'] ?? '').toLowerCase();
    if (reqType != desktopLinkQrType) return null;

    final requestId = (parsed['request_id'] ?? '').trim();
    final targetProfileId = (parsed['target_profile_id'] ?? '').trim();
    final targetDeviceId = (parsed['target_device_id'] ?? '').trim();
    final requestNonce = (parsed['request_nonce'] ?? '').trim();
    if (requestId.isEmpty ||
        targetProfileId.isEmpty ||
        targetDeviceId.isEmpty ||
        requestNonce.isEmpty) {
      return null;
    }

    return DesktopLinkQrPayload(
      requestId: requestId,
      targetProfileId: targetProfileId,
      targetDeviceId: targetDeviceId,
      requestNonce: requestNonce,
      deviceLabel: (parsed['device_label'] ?? '').trim(),
      expiresAtMs: int.tryParse((parsed['expires_at_ms'] ?? '').trim()),
      serverBinding: (parsed['server_binding'] ?? '').trim(),
    );
  }
}

class DesktopLinkSyncPayload {
  const DesktopLinkSyncPayload({
    required this.requestId,
    required this.requestNonce,
    required this.targetProfileId,
    required this.targetDeviceId,
    required this.profileId,
    required this.profileSecretB64,
    required this.cryptoKeyB64,
    required this.serverBinding,
    required this.settingsRaw,
    required this.pendingImportRaw,
    required this.filesRaw,
    this.senderDeviceId = '',
  });

  final String requestId;
  final String requestNonce;
  final String targetProfileId;
  final String targetDeviceId;
  final String profileId;
  final String profileSecretB64;
  final String cryptoKeyB64;
  final String serverBinding;
  final Object? settingsRaw;
  final Object? pendingImportRaw;
  final Object? filesRaw;

  /// Mobile-side `_deviceId` at the time the QR was approved.
  ///
  /// OPTIONAL field added 2026-05-19 (see docs/BUG_AUDIT.md §2026-05-19
  /// ADDENDUM and docs/FIX_TZ.md §2026-05-19 Bidirectional PC↔phone sync fix).
  ///
  /// The desktop seeds this into `_knownOwnDeviceIds` at apply time so the
  /// `senderIsOwn` receive gate accepts mobile's self-mirror commands from
  /// the very first millisecond — without waiting for the keys-server refresh
  /// (`_refreshKnownOwnDeviceIdsFromServer`) which is gated on transport/auth
  /// and races with the first mirror command from mobile after pairing.
  ///
  /// Empty string is allowed for back-compat: an older mobile build pairing
  /// with a newer desktop (or vice versa) silently degrades to the pre-fix
  /// behavior (still works once the boot-time keys refresh lands).
  final String senderDeviceId;

  void validateForSyncApply() {
    try {
      if (requestId.trim().isEmpty) {
        throw StateError('Desktop sync payload missing request_id');
      }
      if (requestNonce.trim().isEmpty) {
        throw StateError('Desktop sync payload missing request_nonce');
      }
      if (targetProfileId.trim().isEmpty) {
        throw StateError('Desktop sync payload missing target_profile_id');
      }
      if (targetDeviceId.trim().isEmpty) {
        throw StateError('Desktop sync payload missing target_device_id');
      }
      if (profileId.trim().isEmpty) {
        throw StateError('Desktop sync payload missing profile_id');
      }
      // INTENTIONALLY NOT asserting `profile_id == target_profile_id`.
      //
      // Sprint 2 PR8 (2026-05-19): this assert was the root cause of
      // "Invalid desktop sync payload. Regenerate QR and retry." after
      // a real (non-test-mode) QR scan.
      //
      // Semantics of the two fields:
      //   * `target_profile_id` is echoed back from the QR — it is the
      //     DESKTOP's current pre-pairing `_profileId` (the placeholder/stub
      //     identity desktop was running with before the user scanned).
      //   * `profile_id` is the MOBILE-side identity being shipped TO the
      //     desktop. After apply, desktop's `_profileId` is overwritten with
      //     this value (see `_applyDesktopSyncBundle` →
      //     `DesktopLinkSyncBundleApplier.apply`).
      //
      // These two values legitimately differ in every real pairing (they only
      // match in the degenerate test-mode case where desktop boots with a
      // hardcoded identity equal to mobile's). The "is this bundle for me?"
      // check is done elsewhere in [DesktopLinkStateMachine.validateSyncRequest]
      // by comparing `target_profile_id == controllerProfileId`.

      SecureSecrets.validateProfileSecretB64(profileSecretB64);
      SecureSecrets.validateCryptoKeyB64(cryptoKeyB64);
      validateServerBindingValue(
        payloadName: 'Desktop sync payload',
        serverBinding: serverBinding,
      );
      _validateSettings(settingsRaw);
      _validatePendingImport(pendingImportRaw);
      _validateFiles(filesRaw);
    } catch (error) {
      throw desktopLinkFailureFromError(
        error,
        fallbackCode: DesktopLinkFailureCode.invalidSyncPayload,
      );
    }
  }

  /// Diagnostic-only: when [tryParseDecoded] returns null, this field is set
  /// to a short human-readable reason so the caller can log it (the public
  /// failure surface still collapses to [DesktopLinkFailureCode.invalidSyncPayload],
  /// but we need the specific reason to debug QR pairing in production logs).
  /// Sprint 2 PR8 (2026-05-19): added so desktop_link_flow.dart's
  /// `catch (_) { return null; }` no longer hides which field broke. Pure-Dart
  /// file — no logger dep; callers read this and forward to their own logger.
  static String? lastParseError;

  static DesktopLinkSyncPayload? tryParseDecoded(Object? raw) {
    lastParseError = null;
    if (raw is! Map) {
      lastParseError = 'raw is not a Map (runtimeType=${raw.runtimeType})';
      return null;
    }
    final json = raw.map((k, v) => MapEntry(k.toString(), v));
    final requestId = (json['request_id'] as String?)?.trim() ?? '';
    final requestNonce = (json['request_nonce'] as String?)?.trim() ?? '';
    final targetProfileId =
        (json['target_profile_id'] as String?)?.trim() ?? '';
    final targetDeviceId =
        (json['target_device_id'] as String?)?.trim() ?? '';
    final profileId = (json['profile_id'] as String?)?.trim() ?? '';
    final profileSecretB64 =
        (json['profile_secret_b64'] as String?)?.trim() ?? '';
    final cryptoKeyB64 = (json['crypto_key_b64'] as String?)?.trim() ?? '';
    final serverBinding = (json['server_binding'] as String?)?.trim() ?? '';
    // Optional — older mobile builds don't include this. We treat empty as
    // "fall back to keys-server refresh" rather than rejecting the bundle.
    final senderDeviceId = (json['sender_device_id'] as String?)?.trim() ?? '';
    final missing = <String>[
      if (requestId.isEmpty) 'request_id',
      if (requestNonce.isEmpty) 'request_nonce',
      if (targetProfileId.isEmpty) 'target_profile_id',
      if (targetDeviceId.isEmpty) 'target_device_id',
      if (profileId.isEmpty) 'profile_id',
      if (profileSecretB64.isEmpty) 'profile_secret_b64',
      if (cryptoKeyB64.isEmpty) 'crypto_key_b64',
      if (serverBinding.isEmpty) 'server_binding',
    ];
    if (missing.isNotEmpty) {
      lastParseError = 'required field(s) empty: ${missing.join(',')}';
      return null;
    }

    try {
      final payload = DesktopLinkSyncPayload(
        requestId: requestId,
        requestNonce: requestNonce,
        targetProfileId: targetProfileId,
        targetDeviceId: targetDeviceId,
        profileId: profileId,
        profileSecretB64: profileSecretB64,
        cryptoKeyB64: cryptoKeyB64,
        serverBinding: serverBinding,
        settingsRaw: json['settings'],
        pendingImportRaw: json['pending_import'],
        filesRaw: json['files_b64_by_relative_path'],
        senderDeviceId: senderDeviceId,
      );
      payload.validateForSyncApply();
      return payload;
    } catch (e) {
      // [validateForSyncApply] always rewraps the inner cause in a
      // [DesktopLinkFailure]. Unwrap `.cause` so we see which specific
      // validator (profile_secret_b64 / crypto_key_b64 / server_binding /
      // settings / pending_import / files) actually failed.
      if (e is DesktopLinkFailure && e.cause != null) {
        final cause = e.cause!;
        lastParseError =
            'validateForSyncApply threw via DesktopLinkFailure → '
            '${cause.runtimeType}: $cause';
      } else {
        lastParseError = 'validateForSyncApply threw: ${e.runtimeType}: $e';
      }
      return null;
    }
  }

  static void _validateSettings(Object? raw) {
    if (raw == null) {
      return;
    }
    if (raw is! Map) {
      throw StateError('Desktop sync payload invalid settings');
    }

    final settings = raw.map((k, v) => MapEntry(k.toString(), v));
    _validateOptionalBool(settings['dark_mode'], 'dark_mode');
    _validateOptionalBool(settings['block_unverified'], 'block_unverified');
    _validateOptionalBool(
      settings['share_nickname_in_qr'],
      'share_nickname_in_qr',
    );
    _validateOptionalString(settings['my_nickname'], 'my_nickname');
    _validateOptionalStringList(
      settings['profile_gallery_paths'],
      'profile_gallery_paths',
    );
    _validateOptionalStringList(
      settings['profile_background_paths'],
      'profile_background_paths',
    );
    _validateOptionalStringList(
      settings['profile_music_paths'],
      'profile_music_paths',
    );
  }

  static void _validatePendingImport(Object? raw) {
    if (raw == null) {
      return;
    }
    if (raw is! Map) {
      throw StateError('Desktop sync payload invalid pending_import');
    }

    final pending = raw.map((k, v) => MapEntry(k.toString(), v));
    final contacts = pending['contacts'];
    if (contacts != null) {
      if (contacts is! List) {
        throw StateError('Desktop sync payload invalid pending_import');
      }
      for (final entry in contacts) {
        if (entry is! Map) {
          throw StateError('Desktop sync payload invalid pending_import');
        }
        final profileId = (entry['profile_id'] as String?)?.trim() ?? '';
        if (profileId.isEmpty) {
          throw StateError('Desktop sync payload invalid pending_import');
        }
        final displayName = entry['display_name'];
        if (displayName != null && displayName is! String) {
          throw StateError('Desktop sync payload invalid pending_import');
        }
      }
    }

    final blockedProfiles = pending['blocked_profiles'];
    if (blockedProfiles != null) {
      if (blockedProfiles is! List) {
        throw StateError('Desktop sync payload invalid pending_import');
      }
      for (final entry in blockedProfiles) {
        if (entry is! String || entry.trim().isEmpty) {
          throw StateError('Desktop sync payload invalid pending_import');
        }
      }
    }

    final dbSnapshot = pending['db_snapshot'];
    if (dbSnapshot != null) {
      if (dbSnapshot is! Map) {
        throw StateError('Desktop sync payload invalid pending_import');
      }
      validateSafeBackupDbSnapshot(
        payloadName: 'Desktop sync payload',
        dbSnapshot: dbSnapshot.map(
          (k, v) => MapEntry(k.toString(), v as Object?),
        ),
      );
    }
  }

  static void _validateFiles(Object? raw) {
    if (raw == null) {
      return;
    }
    if (raw is! Map) {
      throw StateError(
        'Desktop sync payload invalid files_b64_by_relative_path',
      );
    }

    final files = <String, String>{};
    raw.forEach((key, value) {
      if (value is! String) {
        throw StateError(
          'Desktop sync payload invalid files_b64_by_relative_path',
        );
      }
      files[key.toString()] = value;
    });

    validateSafeBackupFiles(
      payloadName: 'Desktop sync payload',
      filesB64ByRelativePath: files,
    );
  }

  static void _validateOptionalBool(Object? value, String fieldName) {
    if (value != null && value is! bool) {
      throw StateError('Desktop sync payload invalid $fieldName');
    }
  }

  static void _validateOptionalString(Object? value, String fieldName) {
    if (value != null && value is! String) {
      throw StateError('Desktop sync payload invalid $fieldName');
    }
  }

  static void _validateOptionalStringList(Object? value, String fieldName) {
    if (value == null) {
      return;
    }
    if (value is! List) {
      throw StateError('Desktop sync payload invalid $fieldName');
    }
    for (final entry in value) {
      if (entry is! String) {
        throw StateError('Desktop sync payload invalid $fieldName');
      }
    }
  }
}

class DesktopLinkSyncValidationResult {
  const DesktopLinkSyncValidationResult._({
    required this.requestIndex,
    required this.request,
    required this.failure,
    required this.replacementRequest,
  });

  const DesktopLinkSyncValidationResult.valid({
    required int requestIndex,
    required DesktopLinkRequest request,
  }) : this._(
         requestIndex: requestIndex,
         request: request,
         failure: null,
         replacementRequest: null,
       );

  const DesktopLinkSyncValidationResult.invalid({
    required DesktopLinkFailure failure,
    int? requestIndex,
    DesktopLinkRequest? replacementRequest,
  }) : this._(
         requestIndex: requestIndex,
         request: null,
         failure: failure,
         replacementRequest: replacementRequest,
       );

  final int? requestIndex;
  final DesktopLinkRequest? request;
  final DesktopLinkFailure? failure;
  final DesktopLinkRequest? replacementRequest;

  String? get error => failure?.message;

  bool get isValid => failure == null;
}

class DesktopLinkDecisionHandlingResult {
  const DesktopLinkDecisionHandlingResult._({
    required this.isHandled,
    required this.requestIndex,
    required this.replacementRequest,
    required this.failure,
  });

  const DesktopLinkDecisionHandlingResult.ignored()
    : this._(
        isHandled: false,
        requestIndex: null,
        replacementRequest: null,
        failure: null,
      );

  const DesktopLinkDecisionHandlingResult.handled({
    required int requestIndex,
    required DesktopLinkRequest replacementRequest,
    required DesktopLinkFailure failure,
  }) : this._(
         isHandled: true,
         requestIndex: requestIndex,
         replacementRequest: replacementRequest,
         failure: failure,
       );

  final bool isHandled;
  final int? requestIndex;
  final DesktopLinkRequest? replacementRequest;
  final DesktopLinkFailure? failure;

  String? get error => failure?.message;
}

class DesktopLinkSyncApplyPreparationResult {
  const DesktopLinkSyncApplyPreparationResult._({
    required this.requests,
    required this.requestIndex,
    required this.payload,
    required this.failure,
    required this.didMutateRequests,
  });

  const DesktopLinkSyncApplyPreparationResult.invalid({
    required List<DesktopLinkRequest> requests,
    required DesktopLinkFailure failure,
    required bool didMutateRequests,
  }) : this._(
         requests: requests,
         requestIndex: null,
         payload: null,
         failure: failure,
         didMutateRequests: didMutateRequests,
       );

  const DesktopLinkSyncApplyPreparationResult.ready({
    required List<DesktopLinkRequest> requests,
    required int requestIndex,
    required DesktopLinkSyncPayload payload,
  }) : this._(
         requests: requests,
         requestIndex: requestIndex,
         payload: payload,
         failure: null,
         didMutateRequests: true,
       );

  final List<DesktopLinkRequest> requests;
  final int? requestIndex;
  final DesktopLinkSyncPayload? payload;
  final DesktopLinkFailure? failure;
  final bool didMutateRequests;

  String? get error => failure?.message;

  bool get canApply =>
      requestIndex != null && payload != null && failure == null;
}

class DesktopLinkRequestUpdateResult {
  const DesktopLinkRequestUpdateResult._({
    required this.requests,
    required this.updatedIndex,
  });

  const DesktopLinkRequestUpdateResult.notFound({
    required List<DesktopLinkRequest> requests,
  }) : this._(requests: requests, updatedIndex: null);

  const DesktopLinkRequestUpdateResult.updated({
    required List<DesktopLinkRequest> requests,
    required int updatedIndex,
  }) : this._(requests: requests, updatedIndex: updatedIndex);

  final List<DesktopLinkRequest> requests;
  final int? updatedIndex;

  bool get didUpdate => updatedIndex != null;
}

class DesktopLinkExpirationResult {
  const DesktopLinkExpirationResult._({
    required this.requests,
    required this.authFlowState,
    required this.authFlowErrorMessage,
    required this.authFlowFailure,
    required this.didExpire,
  });

  const DesktopLinkExpirationResult.unchanged({
    required List<DesktopLinkRequest> requests,
    required AuthFlowState authFlowState,
    String? authFlowError,
    DesktopLinkFailure? authFlowFailure,
  }) : this._(
         requests: requests,
         authFlowState: authFlowState,
         authFlowErrorMessage: authFlowError,
         authFlowFailure: authFlowFailure,
         didExpire: false,
       );

  const DesktopLinkExpirationResult.expired({
    required List<DesktopLinkRequest> requests,
    required AuthFlowState authFlowState,
    String? authFlowError,
    DesktopLinkFailure? authFlowFailure,
  }) : this._(
         requests: requests,
         authFlowState: authFlowState,
         authFlowErrorMessage: authFlowError,
         authFlowFailure: authFlowFailure,
         didExpire: true,
       );

  final List<DesktopLinkRequest> requests;
  final AuthFlowState authFlowState;
  final String? authFlowErrorMessage;
  final DesktopLinkFailure? authFlowFailure;
  final bool didExpire;

  String? get authFlowError => authFlowFailure?.message ?? authFlowErrorMessage;
}

class DesktopLinkStateMachine {
  const DesktopLinkStateMachine._();

  static DesktopLinkRequest? activeRequest({
    required List<DesktopLinkRequest> requests,
    required int nowMs,
  }) {
    for (final request in requests) {
      if (request.isAwaitingDecision && !request.isExpiredAt(nowMs)) {
        return request;
      }
    }
    return null;
  }

  static List<DesktopLinkRequest> cancelAwaitingRequests(
    List<DesktopLinkRequest> requests,
  ) {
    return requests
        .map(
          (request) => request.isAwaitingDecision
              ? request.copyWith(status: 'cancelled')
              : request,
        )
        .toList(growable: true);
  }

  static List<DesktopLinkRequest> prepareForNewRequest({
    required List<DesktopLinkRequest> existingRequests,
    required DesktopLinkRequest request,
  }) {
    final next = cancelAwaitingRequests(existingRequests);
    final idx = next.indexWhere(
      (existing) => existing.requestId == request.requestId,
    );
    if (idx >= 0) {
      next[idx] = request;
      return next;
    }
    return <DesktopLinkRequest>[request, ...next];
  }

  static DesktopLinkSyncValidationResult validateSyncRequest({
    required List<DesktopLinkRequest> requests,
    required String requestId,
    required String requestNonce,
    required String controllerProfileId,
    required String controllerDeviceId,
    required String targetProfileId,
    required String targetDeviceId,
    required int nowMs,
  }) {
    if (targetProfileId != controllerProfileId) {
      return DesktopLinkSyncValidationResult.invalid(
        failure: DesktopLinkFailure(
          DesktopLinkFailureCode.syncTargetProfileMismatch,
        ),
      );
    }

    final reqIndex = requests.indexWhere(
      (request) => request.requestId == requestId,
    );
    if (reqIndex < 0) {
      return DesktopLinkSyncValidationResult.invalid(
        failure: DesktopLinkFailure(
          DesktopLinkFailureCode.syncRequestNotFound,
        ),
      );
    }

    final req = requests[reqIndex];
    if (req.isExpiredAt(nowMs)) {
      return DesktopLinkSyncValidationResult.invalid(
        failure: DesktopLinkFailure(
          DesktopLinkFailureCode.syncSessionExpired,
        ),
        requestIndex: reqIndex,
        replacementRequest: req.copyWith(status: 'expired'),
      );
    }
    if (requestNonce.isNotEmpty && req.requestNonce != requestNonce) {
      return DesktopLinkSyncValidationResult.invalid(
        failure: DesktopLinkFailure(
          DesktopLinkFailureCode.syncNonceMismatch,
        ),
      );
    }
    if (req.targetDeviceId != controllerDeviceId || req.status != 'pending') {
      return DesktopLinkSyncValidationResult.invalid(
        failure: DesktopLinkFailure(
          DesktopLinkFailureCode.syncRequestStateMismatch,
        ),
      );
    }
    if (targetDeviceId.isNotEmpty && targetDeviceId != controllerDeviceId) {
      return DesktopLinkSyncValidationResult.invalid(
        failure: DesktopLinkFailure(
          DesktopLinkFailureCode.syncTargetDeviceMismatch,
        ),
      );
    }

    return DesktopLinkSyncValidationResult.valid(
      requestIndex: reqIndex,
      request: req,
    );
  }

  static DesktopLinkDecisionHandlingResult resolveDecision({
    required List<DesktopLinkRequest> requests,
    required String requestId,
    required String requestNonce,
    required String controllerProfileId,
    required String controllerDeviceId,
    required String targetProfileId,
    required String targetDeviceId,
    required String decision,
  }) {
    if (requestId.isEmpty ||
        requestNonce.isEmpty ||
        targetProfileId != controllerProfileId ||
        (targetDeviceId.isNotEmpty && targetDeviceId != controllerDeviceId)) {
      return const DesktopLinkDecisionHandlingResult.ignored();
    }

    final reqIndex = requests.indexWhere(
      (request) => request.requestId == requestId,
    );
    if (reqIndex < 0) {
      return const DesktopLinkDecisionHandlingResult.ignored();
    }

    final req = requests[reqIndex];
    if (!req.isAwaitingDecision || req.requestNonce != requestNonce) {
      return const DesktopLinkDecisionHandlingResult.ignored();
    }

    if (decision != 'rejected') {
      return const DesktopLinkDecisionHandlingResult.ignored();
    }

    return DesktopLinkDecisionHandlingResult.handled(
      requestIndex: reqIndex,
      replacementRequest: req.copyWith(status: 'rejected'),
      failure: DesktopLinkFailure(DesktopLinkFailureCode.decisionDeclined),
    );
  }

  static DesktopLinkSyncApplyPreparationResult prepareSyncApply({
    required List<DesktopLinkRequest> requests,
    required DesktopLinkSyncPayload? payload,
    required String controllerProfileId,
    required String controllerDeviceId,
    required int nowMs,
  }) {
    if (payload == null) {
      return DesktopLinkSyncApplyPreparationResult.invalid(
        requests: requests,
        failure: DesktopLinkFailure(DesktopLinkFailureCode.invalidSyncPayload),
        didMutateRequests: false,
      );
    }

    final validation = validateSyncRequest(
      requests: requests,
      requestId: payload.requestId,
      requestNonce: payload.requestNonce,
      controllerProfileId: controllerProfileId,
      controllerDeviceId: controllerDeviceId,
      targetProfileId: payload.targetProfileId,
      targetDeviceId: payload.targetDeviceId,
      nowMs: nowMs,
    );
    if (!validation.isValid) {
      if (validation.requestIndex != null &&
          validation.replacementRequest != null) {
        final next = List<DesktopLinkRequest>.from(requests);
        next[validation.requestIndex!] = validation.replacementRequest!;
        return DesktopLinkSyncApplyPreparationResult.invalid(
          requests: next,
          failure: validation.failure!,
          didMutateRequests: true,
        );
      }
      return DesktopLinkSyncApplyPreparationResult.invalid(
        requests: requests,
        failure: validation.failure!,
        didMutateRequests: false,
      );
    }

    final requestIndex = validation.requestIndex!;
    final next = List<DesktopLinkRequest>.from(requests);
    next[requestIndex] = validation.request!.copyWith(status: 'scanned');
    return DesktopLinkSyncApplyPreparationResult.ready(
      requests: next,
      requestIndex: requestIndex,
      payload: payload,
    );
  }

  static DesktopLinkRequestUpdateResult updateRequestStatus({
    required List<DesktopLinkRequest> requests,
    required String requestId,
    required String status,
  }) {
    final rid = requestId.trim();
    if (rid.isEmpty) {
      return DesktopLinkRequestUpdateResult.notFound(requests: requests);
    }

    final next = List<DesktopLinkRequest>.from(requests);
    final idx = next.indexWhere((request) => request.requestId == rid);
    if (idx < 0) {
      return DesktopLinkRequestUpdateResult.notFound(requests: requests);
    }

    next[idx] = next[idx].copyWith(status: status);
    return DesktopLinkRequestUpdateResult.updated(
      requests: next,
      updatedIndex: idx,
    );
  }

  static DesktopLinkExpirationResult expireRequests({
    required List<DesktopLinkRequest> requests,
    required int nowMs,
    required AuthFlowState authFlowState,
    String? authFlowError,
    DesktopLinkFailure? authFlowFailure,
  }) {
    final hadExpired = requests.any(
      (request) => request.isAwaitingDecision && request.isExpiredAt(nowMs),
    );
    if (!hadExpired) {
      return DesktopLinkExpirationResult.unchanged(
        requests: requests,
        authFlowState: authFlowState,
        authFlowError: authFlowError,
        authFlowFailure: authFlowFailure,
      );
    }

    final nextRequests = requests
        .where(
          (request) => !request.isAwaitingDecision || !request.isExpiredAt(nowMs),
        )
        .toList(growable: true);

    if (authFlowState == AuthFlowState.qrSessionPending ||
        authFlowState == AuthFlowState.qrScannedWaitConfirm) {
      return DesktopLinkExpirationResult.expired(
        requests: nextRequests,
        authFlowState: AuthFlowState.authError,
        authFlowFailure: DesktopLinkFailure(
          DesktopLinkFailureCode.syncSessionExpired,
        ),
      );
    }

    return DesktopLinkExpirationResult.expired(
      requests: nextRequests,
      authFlowState: authFlowState,
      authFlowError: authFlowError,
      authFlowFailure: authFlowFailure,
    );
  }
}

Map<String, String> _parseDesktopLinkQrPayload(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const <String, String>{};
  final parts = text.split(RegExp(r'[\n&]+'));
  final out = <String, String>{};
  for (final p in parts) {
    final idx = p.indexOf('=');
    if (idx <= 0) continue;
    final k = p.substring(0, idx).trim().toLowerCase();
    final v = p.substring(idx + 1).trim();
    if (k.isEmpty || v.isEmpty) continue;
    out[k] = v;
  }
  return out;
}