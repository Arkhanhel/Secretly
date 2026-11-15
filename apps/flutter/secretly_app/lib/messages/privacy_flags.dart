// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Выключатели приватности провода: блок `privacy` подписанного `/v1/config`
/// (Б2, 23.10.2026). Пока одно поле — доля профилей, чьи устройства
/// выравнивают длину полезной нагрузки.
///
/// **Отказ.** Блок не пришёл или не проверен — [defaults]: доля 0, провод
/// прежний. Приём флага не ждёт — выровненное сообщение читается любой
/// сборкой.
@immutable
class PrivacyFlags {
  const PrivacyFlags({this.padSendShare = 0});

  static const PrivacyFlags defaults = PrivacyFlags();

  /// Доля профилей (0…100), чьи устройства выравнивают длину.
  final int padSendShare;

  static PrivacyFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['privacy'];
    if (payload is! Map) return defaults;
    final raw = payload['pad_send_share'];
    return PrivacyFlags(
      padSendShare: (raw is num ? raw.toInt() : 0).clamp(0, 100),
    );
  }

  /// Выравнивает ли профиль [profileId]: детерминированно по профилю —
  /// sha256('privacy-pad_send_share-v1|' + profile_id), два первых байта,
  /// остаток от 100. Пустой профиль — нет.
  bool padAllowedFor(String profileId) {
    if (padSendShare <= 0) return false;
    final id = profileId.trim();
    if (id.isEmpty) return false;
    if (padSendShare >= 100) return true;
    final digest = sha256
        .convert(utf8.encode('privacy-pad_send_share-v1|$id'))
        .bytes;
    return ((digest[0] << 8) | digest[1]) % 100 < padSendShare;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyFlags && other.padSendShare == padSendShare;

  @override
  int get hashCode => padSendShare.hashCode;
}
