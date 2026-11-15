// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Гигиена предключей: блок `prekeys` подписанного `/v1/config` (Б5,
/// 24.10.2026, docs/TZ_PREKEY_HYGIENE_B5_2026-10-24.md §4).
///
/// **Отказ.** Блок не пришёл или не проверен — [defaults]: всё выключено,
/// устройство ведёт себя как выпущенная сборка. Доли — по устройству.
@immutable
class PrekeyFlags {
  const PrekeyFlags({
    this.otkHygieneShare = 0,
    this.spkRotateShare = 0,
    this.spkRotateDays = 7,
    this.legacyWireRejectShare = 0,
  });

  static const PrekeyFlags defaults = PrekeyFlags();

  /// Э2: пополнение OTK по остатку и стирание закрытых половин.
  final int otkHygieneShare;

  /// Э3: ротация подписанного предключа и период, дни.
  final int spkRotateShare;
  final int spkRotateDays;

  /// Э4: отказ от старого провода (в Э2 только читается).
  final int legacyWireRejectShare;

  static PrekeyFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['prekeys'];
    if (payload is! Map) return defaults;
    int read(String key, int dflt, int lo, int hi) {
      final raw = payload[key];
      return (raw is num ? raw.toInt() : dflt).clamp(lo, hi);
    }

    return PrekeyFlags(
      otkHygieneShare: read('otk_hygiene_share', 0, 0, 100),
      spkRotateShare: read('spk_rotate_share', 0, 0, 100),
      spkRotateDays: read('spk_rotate_days', 7, 1, 90),
      legacyWireRejectShare: read('legacy_wire_reject_share', 0, 0, 100),
    );
  }

  /// Детерминированно по устройству: sha256('prekeys-' + имя доли + '-v1|' + device_id),
  /// два первых байта, остаток от 100. Пустой номер — нет.
  static bool _inShare(String name, int share, String deviceId) {
    if (share <= 0) return false;
    final id = deviceId.trim();
    if (id.isEmpty) return false;
    if (share >= 100) return true;
    final digest = sha256.convert(utf8.encode('prekeys-$name-v1|$id')).bytes;
    return ((digest[0] << 8) | digest[1]) % 100 < share;
  }

  bool otkHygieneFor(String deviceId) =>
      _inShare('otk_hygiene_share', otkHygieneShare, deviceId);

  bool spkRotateFor(String deviceId) =>
      _inShare('spk_rotate_share', spkRotateShare, deviceId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrekeyFlags &&
          other.otkHygieneShare == otkHygieneShare &&
          other.spkRotateShare == spkRotateShare &&
          other.spkRotateDays == spkRotateDays &&
          other.legacyWireRejectShare == legacyWireRejectShare;

  @override
  int get hashCode => Object.hash(
      otkHygieneShare, spkRotateShare, spkRotateDays, legacyWireRejectShare);
}

/// Б5 Э2: сколько одноразовых ключей добавить при публикации. Остаток не
/// известен (keys до Б5, первая публикация) — прежние 20; меньше
/// [refillBelow] — до [target]; иначе ни одного.
int otkTopUpCount(int? lastRemaining,
    {int target = 100, int refillBelow = 20, int legacy = 20}) {
  if (lastRemaining == null) return legacy;
  if (lastRemaining < refillBelow) return target - lastRemaining.clamp(0, target);
  return 0;
}
