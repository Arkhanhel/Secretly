// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

enum ServiceCompatibilityState {
  unknown,
  supported,
  clientTooOld,
  clientTooNew,
}

ServiceCompatibilityState parseServiceCompatibilityState(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'supported':
      return ServiceCompatibilityState.supported;
    case 'client_too_old':
      return ServiceCompatibilityState.clientTooOld;
    case 'client_too_new':
      return ServiceCompatibilityState.clientTooNew;
    default:
      return ServiceCompatibilityState.unknown;
  }
}

class ServiceHealthStatus {
  const ServiceHealthStatus({
    required this.httpStatusCode,
    required this.reachable,
    required this.service,
    required this.status,
    required this.serverProtocolVersion,
    required this.minClientProtocolVersion,
    required this.maxClientProtocolVersion,
    this.clientProtocolVersion,
    required this.compatibilityState,
    this.compatibilityMessage,
    this.deploymentId,
    this.releaseChannel,
    this.serviceStartedAtMs,
    this.maxRequestBodyBytes,
    this.maxAttachmentBytes,
    this.onlineOnly = false,
  });

  final int httpStatusCode;
  final bool reachable;
  final String service;
  final String status;
  final int serverProtocolVersion;
  final int minClientProtocolVersion;
  final int maxClientProtocolVersion;
  final int? clientProtocolVersion;
  final ServiceCompatibilityState compatibilityState;
  final String? compatibilityMessage;
  final String? deploymentId;
  final String? releaseChannel;
  final int? serviceStartedAtMs;
  final int? maxRequestBodyBytes;
  final int? maxAttachmentBytes;

  /// П-4: реле исполняет `online_only` («печатает» только тем, кто на связи).
  /// Клиент ставит поле только тогда — иначе тратил бы долю раскатки впустую.
  final bool onlineOnly;

  bool get isHealthy => reachable && status == 'ok';

  bool get isCompatible =>
      compatibilityState != ServiceCompatibilityState.clientTooOld &&
      compatibilityState != ServiceCompatibilityState.clientTooNew;

  bool get isUnsupported => !isCompatible;

  String? get releaseMetadataLabel {
    final parts = <String>[];
    final channel = (releaseChannel ?? '').trim();
    final deployment = (deploymentId ?? '').trim();
    if (channel.isNotEmpty) {
      parts.add(channel);
    }
    if (deployment.isNotEmpty) {
      parts.add('deployment=$deployment');
    }
    return parts.isEmpty ? null : parts.join(' | ');
  }

  String get compatibilityLabel {
    switch (compatibilityState) {
      case ServiceCompatibilityState.unknown:
        return 'unknown';
      case ServiceCompatibilityState.supported:
        return 'supported';
      case ServiceCompatibilityState.clientTooOld:
        return 'client_too_old';
      case ServiceCompatibilityState.clientTooNew:
        return 'client_too_new';
    }
  }

  String get protocolWindowLabel =>
      '$minClientProtocolVersion-$maxClientProtocolVersion';

  factory ServiceHealthStatus.unreachable({required String service}) {
    return ServiceHealthStatus(
      httpStatusCode: 0,
      reachable: false,
      service: service,
      status: 'unreachable',
      serverProtocolVersion: 1,
      minClientProtocolVersion: 1,
      maxClientProtocolVersion: 1,
      compatibilityState: ServiceCompatibilityState.unknown,
    );
  }

  factory ServiceHealthStatus.fromHttpResponse({
    required int httpStatusCode,
    required String responseBody,
    required String fallbackService,
    int? requestedClientProtocolVersion,
  }) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final service = ((json['service'] as String?) ?? fallbackService).trim();
    final status = ((json['status'] as String?) ?? 'unknown').trim();
    final serverProtocolVersion =
        _parseInt(json['server_protocol_version']) ?? 1;
    final minClientProtocolVersion =
        _parseInt(json['min_client_protocol_version']) ?? 1;
    final maxClientProtocolVersion =
        _parseInt(json['max_client_protocol_version']) ??
        (serverProtocolVersion < minClientProtocolVersion
            ? minClientProtocolVersion
            : serverProtocolVersion);
    final clientProtocolVersion =
        _parseInt(json['client_protocol_version']) ??
        requestedClientProtocolVersion;
    final deploymentId = _parseNonEmptyString(json['deployment_id']);
    final releaseChannel = _parseNonEmptyString(json['release_channel']);
    final serviceStartedAtMs = _parseInt(json['service_started_at_ms']);
    final maxRequestBodyBytes = _parseInt(json['max_request_body_bytes']);
    final maxAttachmentBytes = _parseInt(json['max_attachment_bytes']);

    var compatibilityState = parseServiceCompatibilityState(
      json['compatibility_status'] as String?,
    );
    if (compatibilityState == ServiceCompatibilityState.unknown &&
        clientProtocolVersion != null) {
      if (clientProtocolVersion < minClientProtocolVersion) {
        compatibilityState = ServiceCompatibilityState.clientTooOld;
      } else if (clientProtocolVersion > maxClientProtocolVersion) {
        compatibilityState = ServiceCompatibilityState.clientTooNew;
      } else {
        compatibilityState = ServiceCompatibilityState.supported;
      }
    }

    return ServiceHealthStatus(
      httpStatusCode: httpStatusCode,
      reachable: true,
      service: service.isEmpty ? fallbackService : service,
      status: status,
      serverProtocolVersion: serverProtocolVersion,
      minClientProtocolVersion: minClientProtocolVersion,
      maxClientProtocolVersion: maxClientProtocolVersion,
      clientProtocolVersion: clientProtocolVersion,
      compatibilityState: compatibilityState,
      compatibilityMessage: (json['compatibility_message'] as String?)?.trim(),
      deploymentId: deploymentId,
      releaseChannel: releaseChannel,
      serviceStartedAtMs: serviceStartedAtMs,
      maxRequestBodyBytes: maxRequestBodyBytes,
      maxAttachmentBytes: maxAttachmentBytes,
      onlineOnly: json['online_only'] == true,
    );
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _parseNonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
