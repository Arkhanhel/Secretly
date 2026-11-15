// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Подпись ответов сервера: блок `server_auth` подписанного `/v1/config` (Б3,
/// 25.10.2026, docs/TZ_SERVER_AUTH_B3_2026-10-25.md §5).
///
/// Проверку подписи новая сборка делает всегда; этот блок решает только, кому
/// неподписанный ответ — отказ (Э2), и раздаёт ключ подписи реле (Э3).
///
/// **Отказ.** Блок не пришёл или не проверен — [defaults]: отказа нет, ключа
/// реле нет.
@immutable
class ServerAuthFlags {
  const ServerAuthFlags({
    this.enforceShare = 0,
    this.relayKid = '',
    this.relayPubB64 = '',
  });

  static const ServerAuthFlags defaults = ServerAuthFlags();

  /// Доля устройств (0…100), для которых неподписанный ответ — отказ.
  final int enforceShare;

  /// Ключ подписи ответов реле; пусто — реле не подписывает.
  final String relayKid;
  final String relayPubB64;

  static ServerAuthFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['server_auth'];
    if (payload is! Map) return defaults;
    final raw = payload['enforce_share'];
    final kid = payload['relay_kid'];
    final pub = payload['relay_pub_b64'];
    final hasRelayKey =
        kid is String && kid.isNotEmpty && pub is String && pub.isNotEmpty;
    return ServerAuthFlags(
      enforceShare: (raw is num ? raw.toInt() : 0).clamp(0, 100),
      relayKid: hasRelayKey ? kid : '',
      relayPubB64: hasRelayKey ? pub : '',
    );
  }

  /// Детерминированно по устройству: sha256('server-auth-enforce_share-v1|' +
  /// device_id), два первых байта, остаток от 100. Пустой номер — нет.
  bool enforceFor(String deviceId) {
    if (enforceShare <= 0) return false;
    final id = deviceId.trim();
    if (id.isEmpty) return false;
    if (enforceShare >= 100) return true;
    final digest = sha256
        .convert(utf8.encode('server-auth-enforce_share-v1|$id'))
        .bytes;
    return ((digest[0] << 8) | digest[1]) % 100 < enforceShare;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerAuthFlags &&
          other.enforceShare == enforceShare &&
          other.relayKid == relayKid &&
          other.relayPubB64 == relayPubB64;

  @override
  int get hashCode => Object.hash(enforceShare, relayKid, relayPubB64);
}
