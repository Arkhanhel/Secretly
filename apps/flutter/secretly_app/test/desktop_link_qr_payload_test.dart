// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

void main() {
  test('DesktopLinkQrPayload parses valid desktop link QR payload', () {
    final payload = DesktopLinkQrPayload.tryParse(
      'type=${AppController.desktopLinkQrType}\n'
      'request_id=req-1\n'
      'target_profile_id=profile-1\n'
      'target_device_id=device-1\n'
      'request_nonce=nonce-1\n'
      'device_label=Windows Desktop\n'
      'expires_at_ms=12345\n'
      'server_binding=keys=https://example.com;relay=https://relay.example.com',
    );

    expect(payload, isNotNull);
    expect(payload!.requestId, 'req-1');
    expect(payload.targetProfileId, 'profile-1');
    expect(payload.targetDeviceId, 'device-1');
    expect(payload.requestNonce, 'nonce-1');
    expect(payload.deviceLabel, 'Windows Desktop');
    expect(payload.expiresAtMs, 12345);
    expect(
      payload.serverBinding,
      'keys=https://example.com;relay=https://relay.example.com',
    );
  });

  test('DesktopLinkQrPayload rejects unsupported or incomplete payloads', () {
    expect(DesktopLinkQrPayload.tryParse('type=wrong'), isNull);
    expect(
      DesktopLinkQrPayload.tryParse(
        'type=${AppController.desktopLinkQrType}\nrequest_id=req-1',
      ),
      isNull,
    );
  });

  test('DesktopLinkQrPayload keeps optional fields nullable', () {
    final payload = DesktopLinkQrPayload.tryParse(
      'type=${AppController.desktopLinkQrType}\n'
      'request_id=req-2\n'
      'target_profile_id=profile-2\n'
      'target_device_id=device-2\n'
      'request_nonce=nonce-2',
    );

    expect(payload, isNotNull);
    expect(payload!.deviceLabel, isEmpty);
    expect(payload.expiresAtMs, isNull);
    expect(payload.serverBinding, isEmpty);
  });

  test('DesktopLinkQrPayload reports expiration correctly', () {
    final payload = DesktopLinkQrPayload.tryParse(
      'type=${AppController.desktopLinkQrType}\n'
      'request_id=req-1\n'
      'target_profile_id=profile-1\n'
      'target_device_id=device-1\n'
      'request_nonce=nonce-1\n'
      'expires_at_ms=1000',
    );

    expect(payload, isNotNull);
    expect(payload!.isExpiredAt(999), isFalse);
    expect(payload.isExpiredAt(1001), isTrue);
  });

  test(
    'DesktopLinkRequest awaiting-decision helper matches pending states',
    () {
      const request = DesktopLinkRequest(
        requestId: 'req-3',
        targetProfileId: 'profile-3',
        targetDeviceId: 'device-3',
        requestNonce: 'nonce-3',
        deviceLabel: 'Windows Desktop',
        createdAtMs: 1,
        expiresAtMs: 2,
        status: 'pending',
      );

      expect(request.isAwaitingDecision, isTrue);
      expect(request.copyWith(status: 'scanned').isAwaitingDecision, isTrue);
      expect(request.copyWith(status: 'cancelled').isAwaitingDecision, isFalse);
      expect(request.copyWith(status: 'rejected').isAwaitingDecision, isFalse);
      expect(
        request.copyWith(status: 'interrupted').isAwaitingDecision,
        isFalse,
      );
    },
  );
}
