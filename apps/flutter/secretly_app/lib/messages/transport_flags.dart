// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

/// Блок `transport` подписанного `/v1/config` (Э1, 11.10.2026).
///
/// Непроверенный блок — умолчания: прокси включён, отчёты включены (решение
/// §4 ТЗ), Tor выключен, версии списка нет. То есть сервер без ключа подписи
/// ничего не может ни выключить, ни включить сверх встроенного.
@immutable
class TransportFlags {
  const TransportFlags({
    this.enabled = true,
    this.reportEnabled = true,
    this.torEnabled = false,
    this.endpointsVersion = 0,
  });

  static const TransportFlags defaults = TransportFlags();

  /// Выключатель локального прокси целиком: `false` — клиент ходит напрямую.
  final bool enabled;
  final bool reportEnabled;

  /// Разрешён ли встроенный Tor как последний путь (сам путь — Э1б).
  final bool torEnabled;

  /// `issued_at_ms` списка входов на сервере; 0 — списка нет.
  final int endpointsVersion;

  static TransportFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['transport'];
    if (payload is! Map) return defaults;
    bool flag(String key, bool fallback) {
      final raw = payload[key];
      return raw is bool ? raw : fallback;
    }

    final version = payload['endpoints_version'];
    return TransportFlags(
      enabled: flag('enabled', true),
      reportEnabled: flag('report_enabled', true),
      torEnabled: flag('tor_enabled', false),
      endpointsVersion: version is num && version > 0 ? version.toInt() : 0,
    );
  }

  Map<String, Object?> toLogFields() => <String, Object?>{
    'enabled': enabled,
    'report': reportEnabled,
    'tor': torEnabled,
    'endpoints_version': endpointsVersion,
  };

  @override
  bool operator ==(Object other) =>
      other is TransportFlags &&
      other.enabled == enabled &&
      other.reportEnabled == reportEnabled &&
      other.torEnabled == torEnabled &&
      other.endpointsVersion == endpointsVersion;

  @override
  int get hashCode =>
      Object.hash(enabled, reportEnabled, torEnabled, endpointsVersion);
}
