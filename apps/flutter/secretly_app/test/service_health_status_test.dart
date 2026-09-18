// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/service_health_status.dart';

void main() {
  test('parses supported compatibility response', () {
    final status = ServiceHealthStatus.fromHttpResponse(
      httpStatusCode: 200,
      responseBody:
          '{"status":"ok","service":"keys","server_protocol_version":2,"min_client_protocol_version":1,"max_client_protocol_version":2,"client_protocol_version":1,"compatibility_status":"supported","deployment_id":"deploy-20260331-abcdef","release_channel":"stable","service_started_at_ms":1743386400000,"max_request_body_bytes":307200}',
      fallbackService: 'keys',
      requestedClientProtocolVersion: 1,
    );

    expect(status.isHealthy, isTrue);
    expect(status.isCompatible, isTrue);
    expect(status.protocolWindowLabel, '1-2');
    expect(status.serverProtocolVersion, 2);
    expect(status.releaseMetadataLabel, 'stable | deployment=deploy-20260331-abcdef');
    expect(status.serviceStartedAtMs, 1743386400000);
    expect(status.maxRequestBodyBytes, 307200);
    expect(status.maxAttachmentBytes, isNull);
  });

  test('derives too-old compatibility when server omits explicit status', () {
    final status = ServiceHealthStatus.fromHttpResponse(
      httpStatusCode: 426,
      responseBody:
          '{"status":"unsupported_client","service":"relay","server_protocol_version":3,"min_client_protocol_version":2,"max_client_protocol_version":3,"compatibility_message":"Install a newer app build."}',
      fallbackService: 'relay',
      requestedClientProtocolVersion: 1,
    );

    expect(status.isUnsupported, isTrue);
    expect(status.compatibilityState, ServiceCompatibilityState.clientTooOld);
    expect(status.compatibilityMessage, 'Install a newer app build.');
    expect(status.releaseMetadataLabel, isNull);
  });

  test('creates unreachable status when transport cannot respond', () {
    final status = ServiceHealthStatus.unreachable(service: 'keys');

    expect(status.reachable, isFalse);
    expect(status.isHealthy, isFalse);
    expect(status.compatibilityState, ServiceCompatibilityState.unknown);
    expect(status.releaseMetadataLabel, isNull);
    expect(status.serviceStartedAtMs, isNull);
    expect(status.maxRequestBodyBytes, isNull);
    expect(status.maxAttachmentBytes, isNull);
  });

  test('parses relay attachment limit fields', () {
    final status = ServiceHealthStatus.fromHttpResponse(
      httpStatusCode: 200,
      responseBody:
          '{"status":"ok","service":"relay","server_protocol_version":3,"min_client_protocol_version":2,"max_client_protocol_version":3,"max_request_body_bytes":26214400,"max_attachment_bytes":8388608}',
      fallbackService: 'relay',
    );

    expect(status.maxRequestBodyBytes, 26214400);
    expect(status.maxAttachmentBytes, 8388608);
  });
}