// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validProfileSecretB64 = 'c2VjcmV0';
  final validCryptoKeyB64 = base64Encode(List<int>.filled(32, 7));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  DesktopLinkRequest makeRequest({
    String requestId = 'req-1',
    String targetProfileId = 'profile-1',
    String targetDeviceId = 'desktop-1',
    String requestNonce = 'nonce-1',
    int createdAtMs = 1000,
    int expiresAtMs = 2000,
    String status = 'pending',
  }) {
    return DesktopLinkRequest(
      requestId: requestId,
      targetProfileId: targetProfileId,
      targetDeviceId: targetDeviceId,
      requestNonce: requestNonce,
      deviceLabel: 'Windows Desktop',
      createdAtMs: createdAtMs,
      expiresAtMs: expiresAtMs,
      status: status,
    );
  }

  AttachmentEventV1 makeAttachment({
    required String blobId,
    required String mime,
  }) {
    return AttachmentEventV1(
      eventId: 'att-$blobId',
      blobId: blobId,
      fileKeyB64: 'file-key',
      sizeBytes: 1,
      mime: mime,
    );
  }

  DesktopLinkRequest makeLiveRequest({
    String requestId = 'req-1',
    String targetProfileId = 'profile-1',
    String targetDeviceId = 'desktop-1',
    String requestNonce = 'nonce-1',
    String status = 'pending',
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return makeRequest(
      requestId: requestId,
      targetProfileId: targetProfileId,
      targetDeviceId: targetDeviceId,
      requestNonce: requestNonce,
      createdAtMs: nowMs,
      expiresAtMs: nowMs + 60 * 1000,
      status: status,
    );
  }

  test(
    'prepareDesktopLinkRequestsForNewRequest cancels previous awaiting requests',
    () {
      final nextRequest = makeRequest(
        requestId: 'req-next',
        requestNonce: 'nonce-next',
      );

      final prepared = AppController.prepareDesktopLinkRequestsForNewRequest(
        existingRequests: <DesktopLinkRequest>[
          makeRequest(requestId: 'req-pending', status: 'pending'),
          makeRequest(requestId: 'req-scanned', status: 'scanned'),
          makeRequest(requestId: 'req-rejected', status: 'rejected'),
        ],
        request: nextRequest,
      );

      expect(prepared.map((request) => request.requestId), <String>[
        'req-next',
        'req-pending',
        'req-scanned',
        'req-rejected',
      ]);
      expect(prepared[0].status, 'pending');
      expect(prepared[1].status, 'cancelled');
      expect(prepared[2].status, 'cancelled');
      expect(prepared[3].status, 'rejected');
    },
  );

  test(
    'cancelAwaitingDesktopLinkRequests preserves order and terminal states',
    () {
      final cancelled =
          AppController.cancelAwaitingDesktopLinkRequests(<DesktopLinkRequest>[
            makeRequest(requestId: 'req-pending', status: 'pending'),
            makeRequest(requestId: 'req-scanned', status: 'scanned'),
            makeRequest(requestId: 'req-applied', status: 'applied'),
            makeRequest(requestId: 'req-expired', status: 'expired'),
          ]);

      expect(cancelled.map((request) => request.requestId), <String>[
        'req-pending',
        'req-scanned',
        'req-applied',
        'req-expired',
      ]);
      expect(cancelled[0].status, 'cancelled');
      expect(cancelled[1].status, 'cancelled');
      expect(cancelled[2].status, 'applied');
      expect(cancelled[3].status, 'expired');
    },
  );

  test(
    'DesktopLinkStateMachine.activeRequest skips expired requests',
    () {
      final active = DesktopLinkStateMachine.activeRequest(
        requests: <DesktopLinkRequest>[
          makeRequest(requestId: 'req-expired', expiresAtMs: 1400),
          makeRequest(
            requestId: 'req-active',
            requestNonce: 'nonce-active',
            status: 'scanned',
            expiresAtMs: 1800,
          ),
          makeRequest(
            requestId: 'req-later',
            requestNonce: 'nonce-later',
            expiresAtMs: 1900,
          ),
        ],
        nowMs: 1500,
      );

      expect(active, isNotNull);
      expect(active!.requestId, 'req-active');
    },
  );

  test('DesktopLinkStateMachine.updateRequestStatus updates matching request', () {
    final requests = <DesktopLinkRequest>[
      makeRequest(requestId: 'req-1', status: 'pending'),
      makeRequest(requestId: 'req-2', requestNonce: 'nonce-2', status: 'rejected'),
    ];

    final result = DesktopLinkStateMachine.updateRequestStatus(
      requests: requests,
      requestId: 'req-1',
      status: 'applied',
    );

    expect(result.didUpdate, isTrue);
    expect(result.updatedIndex, 0);
    expect(result.requests[0].status, 'applied');
    expect(result.requests[1].status, 'rejected');
    expect(requests[0].status, 'pending');
  });

  test(
    'DesktopLinkStateMachine.expireRequests moves auth flow to authError for pending QR session',
    () {
      final result = DesktopLinkStateMachine.expireRequests(
        requests: <DesktopLinkRequest>[
          makeRequest(requestId: 'req-expired', expiresAtMs: 1400),
          makeRequest(
            requestId: 'req-terminal',
            requestNonce: 'nonce-terminal',
            status: 'rejected',
            expiresAtMs: 1300,
          ),
        ],
        nowMs: 1500,
        authFlowState: AuthFlowState.qrSessionPending,
      );

      expect(result.didExpire, isTrue);
      expect(result.requests, hasLength(1));
      expect(result.requests.single.requestId, 'req-terminal');
      expect(result.authFlowState, AuthFlowState.authError);
      expect(
        result.authFlowError,
        'QR session expired. Generate a new QR and retry.',
      );
    },
  );

  test('DesktopLinkStateMachine.expireRequests keeps state when nothing expired', () {
    final result = DesktopLinkStateMachine.expireRequests(
      requests: <DesktopLinkRequest>[
        makeRequest(requestId: 'req-live', expiresAtMs: 1800),
      ],
      nowMs: 1500,
      authFlowState: AuthFlowState.authenticated,
      authFlowError: 'existing-error',
    );

    expect(result.didExpire, isFalse);
    expect(result.requests, hasLength(1));
    expect(result.authFlowState, AuthFlowState.authenticated);
    expect(result.authFlowError, 'existing-error');
  });

  test('prepareDesktopLinkRequestsForNewRequest replaces matching ids', () {
    final replacement = makeRequest(
      requestId: 'req-1',
      requestNonce: 'nonce-replaced',
      status: 'pending',
    );

    final prepared = AppController.prepareDesktopLinkRequestsForNewRequest(
      existingRequests: <DesktopLinkRequest>[
        makeRequest(requestId: 'req-1', requestNonce: 'nonce-old'),
        makeRequest(requestId: 'req-2', status: 'rejected'),
      ],
      request: replacement,
    );

    expect(prepared, hasLength(2));
    expect(prepared[0].requestId, 'req-1');
    expect(prepared[0].requestNonce, 'nonce-replaced');
    expect(prepared[0].status, 'pending');
    expect(prepared[1].requestId, 'req-2');
  });

  test('validateDesktopLinkSyncRequest accepts matching pending request', () {
    final result = AppController.validateDesktopLinkSyncRequest(
      requests: <DesktopLinkRequest>[makeRequest()],
      requestId: 'req-1',
      requestNonce: 'nonce-1',
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      targetProfileId: 'profile-1',
      targetDeviceId: 'desktop-1',
      nowMs: 1500,
    );

    expect(result.isValid, isTrue);
    expect(result.requestIndex, 0);
    expect(result.request, isNotNull);
    expect(result.request!.status, 'pending');
    expect(result.replacementRequest, isNull);
  });

  test('validateDesktopLinkSyncRequest rejects target profile mismatch', () {
    final result = AppController.validateDesktopLinkSyncRequest(
      requests: <DesktopLinkRequest>[makeRequest()],
      requestId: 'req-1',
      requestNonce: 'nonce-1',
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      targetProfileId: 'profile-2',
      targetDeviceId: 'desktop-1',
      nowMs: 1500,
    );

    expect(result.isValid, isFalse);
    expect(
      result.failure?.code,
      DesktopLinkFailureCode.syncTargetProfileMismatch,
    );
    expect(
      result.error,
      'Sync bundle target profile mismatch. Regenerate QR and retry.',
    );
  });

  test('validateDesktopLinkSyncRequest rejects missing request ids', () {
    final result = AppController.validateDesktopLinkSyncRequest(
      requests: <DesktopLinkRequest>[makeRequest(requestId: 'req-other')],
      requestId: 'req-1',
      requestNonce: 'nonce-1',
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      targetProfileId: 'profile-1',
      targetDeviceId: 'desktop-1',
      nowMs: 1500,
    );

    expect(result.isValid, isFalse);
    expect(result.failure?.code, DesktopLinkFailureCode.syncRequestNotFound);
    expect(
      result.error,
      'Desktop sync request not found or already expired. Generate a new QR.',
    );
    expect(result.requestIndex, isNull);
    expect(result.replacementRequest, isNull);
  });

  test(
    'validateDesktopLinkSyncRequest marks expired requests for persistence',
    () {
      final result = AppController.validateDesktopLinkSyncRequest(
        requests: <DesktopLinkRequest>[makeRequest(expiresAtMs: 1400)],
        requestId: 'req-1',
        requestNonce: 'nonce-1',
        controllerProfileId: 'profile-1',
        controllerDeviceId: 'desktop-1',
        targetProfileId: 'profile-1',
        targetDeviceId: 'desktop-1',
        nowMs: 1500,
      );

      expect(result.isValid, isFalse);
  expect(result.failure?.code, DesktopLinkFailureCode.syncSessionExpired);
      expect(result.requestIndex, 0);
      expect(result.error, 'QR session expired. Generate a new QR and retry.');
      expect(result.replacementRequest, isNotNull);
      expect(result.replacementRequest!.status, 'expired');
    },
  );

  test('validateDesktopLinkSyncRequest rejects nonce mismatch', () {
    final result = AppController.validateDesktopLinkSyncRequest(
      requests: <DesktopLinkRequest>[makeRequest()],
      requestId: 'req-1',
      requestNonce: 'wrong-nonce',
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      targetProfileId: 'profile-1',
      targetDeviceId: 'desktop-1',
      nowMs: 1500,
    );

    expect(result.isValid, isFalse);
    expect(result.failure?.code, DesktopLinkFailureCode.syncNonceMismatch);
    expect(
      result.error,
      'QR session validation failed (nonce mismatch). Generate a new QR.',
    );
  });

  test('validateDesktopLinkSyncRequest rejects non-pending request states', () {
    for (final status in <String>[
      'cancelled',
      'rejected',
      'scanned',
      'interrupted',
    ]) {
      final result = AppController.validateDesktopLinkSyncRequest(
        requests: <DesktopLinkRequest>[makeRequest(status: status)],
        requestId: 'req-1',
        requestNonce: 'nonce-1',
        controllerProfileId: 'profile-1',
        controllerDeviceId: 'desktop-1',
        targetProfileId: 'profile-1',
        targetDeviceId: 'desktop-1',
        nowMs: 1500,
      );

      expect(result.isValid, isFalse, reason: status);
      expect(
        result.failure?.code,
        DesktopLinkFailureCode.syncRequestStateMismatch,
        reason: status,
      );
      expect(
        result.error,
        'Sync request state mismatch. Regenerate QR and retry.',
        reason: status,
      );
    }
  });

  test('validateDesktopLinkSyncRequest rejects target device mismatch', () {
    final result = AppController.validateDesktopLinkSyncRequest(
      requests: <DesktopLinkRequest>[makeRequest()],
      requestId: 'req-1',
      requestNonce: 'nonce-1',
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      targetProfileId: 'profile-1',
      targetDeviceId: 'desktop-2',
      nowMs: 1500,
    );

    expect(result.isValid, isFalse);
    expect(result.failure?.code, DesktopLinkFailureCode.syncTargetDeviceMismatch);
    expect(
      result.error,
      'Sync bundle target device mismatch. Regenerate QR and retry.',
    );
  });

  test('DesktopLinkSyncPayload.tryParseDecoded parses required sync fields', () {
    final payload = DesktopLinkSyncPayload.tryParseDecoded(<String, Object?>{
      'request_id': 'req-1',
      'request_nonce': 'nonce-1',
      'target_profile_id': 'profile-1',
      'target_device_id': 'desktop-1',
      'profile_id': 'profile-1',
      'profile_secret_b64': validProfileSecretB64,
      'crypto_key_b64': validCryptoKeyB64,
      'server_binding': 'keys=https://keys;relay=https://relay',
      'settings': <String, Object?>{'dark_mode': true},
      'pending_import': <String, Object?>{'contacts': <Object>[]},
      'files_b64_by_relative_path': <String, Object?>{'foo.txt': 'QQ=='},
    });

    expect(payload, isNotNull);
    expect(payload!.requestId, 'req-1');
    expect(payload.requestNonce, 'nonce-1');
    expect(payload.targetProfileId, 'profile-1');
    expect(payload.targetDeviceId, 'desktop-1');
    expect(payload.profileId, 'profile-1');
    expect(payload.profileSecretB64, validProfileSecretB64);
    expect(payload.cryptoKeyB64, validCryptoKeyB64);
    expect(payload.serverBinding, 'keys=https://keys;relay=https://relay');
    expect(payload.settingsRaw, isA<Map>());
    expect(payload.pendingImportRaw, isA<Map>());
    expect(payload.filesRaw, isA<Map>());
  });

  test('DesktopLinkSyncPayload.tryParseDecoded rejects invalid sync secret fields', () {
    expect(
      DesktopLinkSyncPayload.tryParseDecoded(<String, Object?>{
        'request_id': 'req-1',
        'request_nonce': 'nonce-1',
        'target_profile_id': 'profile-1',
        'target_device_id': 'desktop-1',
        'profile_id': 'profile-1',
        'profile_secret_b64': 'not-base64',
        'crypto_key_b64': validCryptoKeyB64,
        'server_binding': 'keys=https://keys;relay=https://relay',
      }),
      isNull,
    );

    expect(
      DesktopLinkSyncPayload.tryParseDecoded(<String, Object?>{
        'request_id': 'req-1',
        'request_nonce': 'nonce-1',
        'target_profile_id': 'profile-1',
        'target_device_id': 'desktop-1',
        'profile_id': 'profile-1',
        'profile_secret_b64': validProfileSecretB64,
        'crypto_key_b64': 'bad-crypto',
        'server_binding': 'keys=https://keys;relay=https://relay',
      }),
      isNull,
    );
  });

  test('DesktopLinkSyncPayload.tryParseDecoded rejects malformed sync payload body', () {
    // Sprint 2 PR8 (2026-05-19): removed a former assertion that
    // `target_profile_id == profile_id`. These two fields refer to different
    // identities (target = desktop's pre-pairing stub, profile_id = mobile's
    // identity being shipped) and legitimately differ in every real pairing.
    // The "is this bundle for me?" check is enforced elsewhere by
    // [DesktopLinkStateMachine.validateSyncRequest] which compares
    // target_profile_id against the controller's own profileId.

    expect(
      DesktopLinkSyncPayload.tryParseDecoded(<String, Object?>{
        'request_id': 'req-1',
        'request_nonce': 'nonce-1',
        'target_profile_id': 'profile-1',
        'target_device_id': 'desktop-1',
        'profile_id': 'profile-1',
        'profile_secret_b64': validProfileSecretB64,
        'crypto_key_b64': validCryptoKeyB64,
        'server_binding': 'keys=https://keys;relay=https://relay',
        'pending_import': <String, Object?>{'contacts': 'broken'},
      }),
      isNull,
    );

    expect(
      DesktopLinkSyncPayload.tryParseDecoded(<String, Object?>{
        'request_id': 'req-1',
        'request_nonce': 'nonce-1',
        'target_profile_id': 'profile-1',
        'target_device_id': 'desktop-1',
        'profile_id': 'profile-1',
        'profile_secret_b64': validProfileSecretB64,
        'crypto_key_b64': validCryptoKeyB64,
        'server_binding': 'keys=https://keys;relay=https://relay',
        'files_b64_by_relative_path': <String, Object?>{
          '../escape.txt': 'QQ==',
        },
      }),
      isNull,
    );
  });

  test('DesktopLinkStateMachine.prepareSyncApply marks request scanned', () {
    final payload = DesktopLinkSyncPayload.tryParseDecoded(<String, Object?>{
      'request_id': 'req-1',
      'request_nonce': 'nonce-1',
      'target_profile_id': 'profile-1',
      'target_device_id': 'desktop-1',
      'profile_id': 'profile-1',
      'profile_secret_b64': validProfileSecretB64,
      'crypto_key_b64': validCryptoKeyB64,
      'server_binding': 'keys=https://keys;relay=https://relay',
    });

    final result = DesktopLinkStateMachine.prepareSyncApply(
      requests: <DesktopLinkRequest>[makeRequest()],
      payload: payload,
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      nowMs: 1500,
    );

    expect(result.canApply, isTrue);
    expect(result.didMutateRequests, isTrue);
    expect(result.requestIndex, 0);
    expect(result.requests.single.status, 'scanned');
    expect(result.payload, isNotNull);
    expect(result.payload!.profileId, 'profile-1');
  });

  test(
    'DesktopLinkStateMachine.prepareSyncApply persists expired replacement on validation failure',
    () {
      final payload = DesktopLinkSyncPayload.tryParseDecoded(<String, Object?>{
        'request_id': 'req-1',
        'request_nonce': 'nonce-1',
        'target_profile_id': 'profile-1',
        'target_device_id': 'desktop-1',
        'profile_id': 'profile-1',
        'profile_secret_b64': validProfileSecretB64,
        'crypto_key_b64': validCryptoKeyB64,
        'server_binding': 'keys=https://keys;relay=https://relay',
      });

      final result = DesktopLinkStateMachine.prepareSyncApply(
        requests: <DesktopLinkRequest>[makeRequest(expiresAtMs: 1400)],
        payload: payload,
        controllerProfileId: 'profile-1',
        controllerDeviceId: 'desktop-1',
        nowMs: 1500,
      );

      expect(result.canApply, isFalse);
      expect(result.didMutateRequests, isTrue);
      expect(result.failure?.code, DesktopLinkFailureCode.syncSessionExpired);
      expect(result.error, 'QR session expired. Generate a new QR and retry.');
      expect(result.requests.single.status, 'expired');
    },
  );

  test('DesktopLinkStateMachine.prepareSyncApply rejects invalid payload', () {
    final result = DesktopLinkStateMachine.prepareSyncApply(
      requests: <DesktopLinkRequest>[makeRequest()],
      payload: null,
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      nowMs: 1500,
    );

    expect(result.canApply, isFalse);
    expect(result.didMutateRequests, isFalse);
    expect(result.failure?.code, DesktopLinkFailureCode.invalidSyncPayload);
    expect(result.error, 'Invalid desktop sync payload. Regenerate QR and retry.');
  });

  test('resolveDesktopLinkDecision handles matching rejection payloads', () {
    final result = AppController.resolveDesktopLinkDecision(
      requests: <DesktopLinkRequest>[makeRequest()],
      requestId: 'req-1',
      requestNonce: 'nonce-1',
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      targetProfileId: 'profile-1',
      targetDeviceId: 'desktop-1',
      decision: 'rejected',
    );

    expect(result.isHandled, isTrue);
    expect(result.requestIndex, 0);
    expect(result.replacementRequest, isNotNull);
    expect(result.replacementRequest!.status, 'rejected');
    expect(result.failure?.code, DesktopLinkFailureCode.decisionDeclined);
    expect(
      result.error,
      'Sign-in was declined on the primary phone. Generate a new QR to retry.',
    );
  });

  test('resolveDesktopLinkDecision ignores unsupported decisions', () {
    final result = AppController.resolveDesktopLinkDecision(
      requests: <DesktopLinkRequest>[makeRequest()],
      requestId: 'req-1',
      requestNonce: 'nonce-1',
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      targetProfileId: 'profile-1',
      targetDeviceId: 'desktop-1',
      decision: 'approved',
    );

    expect(result.isHandled, isFalse);
    expect(result.requestIndex, isNull);
    expect(result.replacementRequest, isNull);
    expect(result.error, isNull);
  });

  test('resolveDesktopLinkDecision ignores target and nonce mismatches', () {
    final wrongTarget = AppController.resolveDesktopLinkDecision(
      requests: <DesktopLinkRequest>[makeRequest()],
      requestId: 'req-1',
      requestNonce: 'nonce-1',
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      targetProfileId: 'profile-2',
      targetDeviceId: 'desktop-1',
      decision: 'rejected',
    );
    final wrongNonce = AppController.resolveDesktopLinkDecision(
      requests: <DesktopLinkRequest>[makeRequest()],
      requestId: 'req-1',
      requestNonce: 'wrong-nonce',
      controllerProfileId: 'profile-1',
      controllerDeviceId: 'desktop-1',
      targetProfileId: 'profile-1',
      targetDeviceId: 'desktop-1',
      decision: 'rejected',
    );

    expect(wrongTarget.isHandled, isFalse);
    expect(wrongNonce.isHandled, isFalse);
  });

  test('resolveDesktopLinkDecision ignores duplicate or stale decisions', () {
    for (final status in <String>['rejected', 'cancelled', 'interrupted']) {
      final result = AppController.resolveDesktopLinkDecision(
        requests: <DesktopLinkRequest>[makeRequest(status: status)],
        requestId: 'req-1',
        requestNonce: 'nonce-1',
        controllerProfileId: 'profile-1',
        controllerDeviceId: 'desktop-1',
        targetProfileId: 'profile-1',
        targetDeviceId: 'desktop-1',
        decision: 'rejected',
      );

      expect(result.isHandled, isFalse, reason: status);
    }
  });

  test(
    'handleInboundAttachmentCommands applies rejected desktop decisions',
    () async {
      final controller =
          _FakeDesktopLinkAttachmentController(
            payloadsByBlobId: <String, Object>{
              'decision-1': <String, Object?>{
                'request_id': 'req-1',
                'request_nonce': 'nonce-1',
                'target_profile_id': 'profile-1',
                'target_device_id': 'desktop-1',
                'decision': 'rejected',
              },
            },
          )..seedDesktopLinkStateForTesting(
            profileId: 'profile-1',
            deviceId: 'desktop-1',
            requests: <DesktopLinkRequest>[makeLiveRequest()],
            authFlowState: AuthFlowState.qrSessionPending,
          );

      final handled = await controller
          .handleInboundAttachmentCommands(<AttachmentEventV1>[
            makeAttachment(
              blobId: 'decision-1',
              mime: AppController.desktopLinkDecisionAttachmentMime,
            ),
          ]);

      expect(handled, isTrue);
      expect(controller.desktopLinkRequests.single.status, 'rejected');
      expect(controller.authFlowState, AuthFlowState.authError);
      expect(
        controller.authFlowFailure?.code,
        DesktopLinkFailureCode.decisionDeclined,
      );
      expect(
        controller.authFlowError,
        'Sign-in was declined on the primary phone. Generate a new QR to retry.',
      );
      expect(controller.activeDesktopLinkRequest, isNull);
    },
  );

  test(
    'handleInboundAttachmentCommands suppresses invalid sync control attachments',
    () async {
      final controller =
          _FakeDesktopLinkAttachmentController(
            payloadsByBlobId: <String, Object>{
              'sync-1': <String, Object?>{
                'request_id': 'req-1',
                'request_nonce': 'wrong-nonce',
                'target_profile_id': 'profile-1',
                'target_device_id': 'desktop-1',
                'profile_id': 'profile-1',
                'profile_secret_b64': validProfileSecretB64,
                'crypto_key_b64': validCryptoKeyB64,
                'server_binding': 'keys=https://keys;relay=https://relay',
              },
            },
          )..seedDesktopLinkStateForTesting(
            profileId: 'profile-1',
            deviceId: 'desktop-1',
            requests: <DesktopLinkRequest>[makeLiveRequest()],
            authFlowState: AuthFlowState.qrSessionPending,
          );

      final handled = await controller
          .handleInboundAttachmentCommands(<AttachmentEventV1>[
            makeAttachment(
              blobId: 'sync-1',
              mime: AppController.desktopSyncAttachmentMime,
            ),
          ]);

      expect(handled, isTrue);
      expect(controller.desktopLinkRequests.single.status, 'pending');
      expect(controller.authFlowState, AuthFlowState.authError);
      expect(
        controller.authFlowFailure?.code,
        DesktopLinkFailureCode.syncNonceMismatch,
      );
      expect(
        controller.authFlowError,
        'QR session validation failed (nonce mismatch). Generate a new QR.',
      );
    },
  );

  test(
    'handleInboundAttachmentCommands rejects malformed sync bundle without apply side effects',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final controller =
          _FakeDesktopLinkAttachmentController(
            payloadsByBlobId: <String, Object>{
              'sync-malformed': <String, Object?>{
                'request_id': 'req-1',
                'request_nonce': 'nonce-1',
                'target_profile_id': 'profile-1',
                'target_device_id': 'desktop-1',
                'profile_id': 'profile-1',
                'profile_secret_b64': validProfileSecretB64,
                'crypto_key_b64': validCryptoKeyB64,
                'server_binding': 'broken-binding',
              },
            },
          )..seedDesktopLinkStateForTesting(
            profileId: 'profile-1',
            deviceId: 'desktop-1',
            requests: <DesktopLinkRequest>[makeLiveRequest()],
            authFlowState: AuthFlowState.qrSessionPending,
          );
      final observedAuthStates = <AuthFlowState>[];
      var restartEvents = 0;
      final changedSub = controller.changed.listen((_) {
        observedAuthStates.add(controller.authFlowState);
      });
      final restartSub = controller.restartRequested.listen((_) {
        restartEvents += 1;
      });

      final handled = await controller
          .handleInboundAttachmentCommands(<AttachmentEventV1>[
            makeAttachment(
              blobId: 'sync-malformed',
              mime: AppController.desktopSyncAttachmentMime,
            ),
          ]);
      await Future<void>.delayed(Duration.zero);
      await changedSub.cancel();
      await restartSub.cancel();

      expect(handled, isTrue);
      expect(controller.desktopLinkRequests.single.status, 'pending');
      expect(controller.activeDesktopLinkRequest, isNotNull);
      expect(controller.authFlowState, AuthFlowState.authError);
      expect(
        controller.authFlowFailure?.code,
        DesktopLinkFailureCode.invalidSyncPayload,
      );
      expect(
        controller.authFlowError,
        'Invalid desktop sync payload. Regenerate QR and retry.',
      );
      expect(observedAuthStates, <AuthFlowState>[AuthFlowState.authError]);
      expect(restartEvents, 0);
      expect(prefs.getString('desktop_link_requests_v1'), isNull);
    },
  );

  test(
    'handleInboundAttachmentCommands suppresses unsupported desktop decisions',
    () async {
      final controller =
          _FakeDesktopLinkAttachmentController(
            payloadsByBlobId: <String, Object>{
              'decision-2': <String, Object?>{
                'request_id': 'req-1',
                'request_nonce': 'nonce-1',
                'target_profile_id': 'profile-1',
                'target_device_id': 'desktop-1',
                'decision': 'approved',
              },
            },
          )..seedDesktopLinkStateForTesting(
            profileId: 'profile-1',
            deviceId: 'desktop-1',
            requests: <DesktopLinkRequest>[makeLiveRequest()],
            authFlowState: AuthFlowState.qrSessionPending,
          );

      final handled = await controller
          .handleInboundAttachmentCommands(<AttachmentEventV1>[
            makeAttachment(
              blobId: 'decision-2',
              mime: AppController.desktopLinkDecisionAttachmentMime,
            ),
          ]);

      expect(handled, isTrue);
      expect(controller.desktopLinkRequests.single.status, 'pending');
      expect(controller.authFlowState, AuthFlowState.qrSessionPending);
      expect(controller.authFlowError, isNull);
    },
  );

  test(
    'handleDecryptedInboundPayloadForTesting suppresses desktop controls before timeline storage',
    () async {
      final controller =
          _FakeDesktopLinkAttachmentController(
            payloadsByBlobId: <String, Object>{
              'decision-full-path': <String, Object?>{
                'request_id': 'req-1',
                'request_nonce': 'nonce-1',
                'target_profile_id': 'profile-1',
                'target_device_id': 'desktop-1',
                'decision': 'rejected',
              },
            },
          )..seedDesktopLinkStateForTesting(
            profileId: 'profile-1',
            deviceId: 'desktop-1',
            requests: <DesktopLinkRequest>[makeLiveRequest()],
            authFlowState: AuthFlowState.qrSessionPending,
          );
      final db = await AppDb.openForTesting();
      try {
        final payload = E2ePayloadV1(
          senderDeviceId: 'phone-1',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          events: <E2eEventV1>[
            makeAttachment(
              blobId: 'decision-full-path',
              mime: AppController.desktopLinkDecisionAttachmentMime,
            ),
          ],
        );

        final handled = await controller
            .handleDecryptedInboundPayloadForTesting(
              db: db,
              msgId: 'msg-control-1',
              ciphertextB64: 'AA==',
              plainBytes: Uint8List.fromList(payload.encode()),
              payload: payload,
              senderDeviceId: 'phone-1',
              nowMs: DateTime.now().millisecondsSinceEpoch,
            );

        expect(handled, isTrue);
        expect(controller.desktopLinkRequests.single.status, 'rejected');
        expect(controller.authFlowState, AuthFlowState.authError);
        expect(await db.convoGet('dev:phone-1'), isNull);
        expect(await db.listEvents('dev:phone-1'), isEmpty);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'handleDecryptedInboundPayloadForTesting stores regular attachments in timeline',
    () async {
      final controller =
          _FakeDesktopLinkAttachmentController(
            payloadsByBlobId: const <String, Object>{},
          )..seedDesktopLinkStateForTesting(
            profileId: 'profile-1',
            deviceId: 'desktop-1',
          );
      final db = await AppDb.openForTesting();
      try {
        final payload = E2ePayloadV1(
          senderDeviceId: 'phone-2',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          events: <E2eEventV1>[
            makeAttachment(blobId: 'plain-full-path', mime: 'image/png'),
          ],
        );

        final handled = await controller
            .handleDecryptedInboundPayloadForTesting(
              db: db,
              msgId: 'msg-regular-1',
              ciphertextB64: 'AA==',
              plainBytes: Uint8List.fromList(payload.encode()),
              payload: payload,
              senderDeviceId: 'phone-2',
              nowMs: DateTime.now().millisecondsSinceEpoch,
            );

        expect(handled, isTrue);
        expect(await db.convoGet('dev:phone-2'), isNotNull);
        final events = await db.listEvents('dev:phone-2');
        expect(events, hasLength(1));
        expect(events.single['event_id'], 'msg-regular-1');
        expect(events.single['type'], 'att');
        expect(events.single['payload_event_id'], 'att-plain-full-path');
      } finally {
        await db.close();
      }
    },
  );

  test('handleInboundAttachmentCommands ignores regular attachments', () async {
    final controller =
        _FakeDesktopLinkAttachmentController(
          payloadsByBlobId: const <String, Object>{},
        )..seedDesktopLinkStateForTesting(
          profileId: 'profile-1',
          deviceId: 'desktop-1',
          requests: <DesktopLinkRequest>[makeLiveRequest()],
        );

    final handled = await controller.handleInboundAttachmentCommands(
      <AttachmentEventV1>[makeAttachment(blobId: 'plain-1', mime: 'image/png')],
    );

    expect(handled, isFalse);
    expect(controller.desktopLinkRequests.single.status, 'pending');
  });
}

class _FakeDesktopLinkAttachmentController extends AppController {
  _FakeDesktopLinkAttachmentController({
    required Map<String, Object> payloadsByBlobId,
  }) : _payloadsByBlobId = payloadsByBlobId.map(
         (blobId, payload) => MapEntry(
           blobId,
           Uint8List.fromList(utf8.encode(jsonEncode(payload))),
         ),
       );

  final Map<String, Uint8List> _payloadsByBlobId;

  @override
  Future<Uint8List> downloadAndDecryptAttachment(AttachmentEventV1 a) async {
    final payload = _payloadsByBlobId[a.blobId];
    if (payload == null) {
      throw StateError('Missing fake payload for ${a.blobId}');
    }
    return payload;
  }
}
