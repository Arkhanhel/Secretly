// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Выключатели наборов стикеров: блок `stickers` подписанного `/v1/config`
/// (docs/TZ_STICKER_PACKS_2026-11-14.md §7).
///
/// **Флагом включается только интерфейс.** Выбор «закрытый / открытый» и
/// кнопка публикации показываются по доле. Проверка закрытости у автора и
/// замок у получателя работают ВСЕГДА: откат флага не имеет права открыть
/// набор, который автор уже закрыл.
///
/// **Отказ.** Блок не пришёл или не проверен — [defaults]: всё выключено.
@immutable
class StickerFlags {
  const StickerFlags({
    this.packAccessPercent = 0,
    this.publicPublishPercent = 0,
    this.publicSearchEnabled = false,
  });

  static const StickerFlags defaults = StickerFlags();

  /// Доля устройств (0…100), которым показан выбор режима набора.
  final int packAccessPercent;

  /// Доля устройств с кнопкой «Опубликовать». До запуска модерации — 0.
  final int publicPublishPercent;

  /// Поиск публичных наборов.
  final bool publicSearchEnabled;

  static StickerFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['stickers'];
    if (payload is! Map) return defaults;
    int percent(String key) {
      final raw = payload[key];
      return (raw is num ? raw.toInt() : 0).clamp(0, 100);
    }

    return StickerFlags(
      packAccessPercent: percent('pack_access_percent'),
      publicPublishPercent: percent('public_publish_percent'),
      publicSearchEnabled: payload['public_search_enabled'] == true,
    );
  }

  bool packAccessFor(String deviceId) =>
      inRollout('pack_access_percent', packAccessPercent, deviceId);

  bool publicPublishFor(String deviceId) =>
      inRollout('public_publish_percent', publicPublishPercent, deviceId);

  /// Детерминированно по устройству: sha256('stickers-<поле>-v1|' + id), два
  /// первых байта, остаток от 100. Расширение доли не выключает уже
  /// включённых. Пустой id — не в доле, и проверка идёт раньше «ста процентов».
  static bool inRollout(String field, int percent, String deviceId) {
    if (percent <= 0) return false;
    final id = deviceId.trim();
    if (id.isEmpty) return false;
    if (percent >= 100) return true;
    final digest = sha256.convert(utf8.encode('stickers-$field-v1|$id')).bytes;
    return ((digest[0] << 8) | digest[1]) % 100 < percent;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickerFlags &&
          other.packAccessPercent == packAccessPercent &&
          other.publicPublishPercent == publicPublishPercent &&
          other.publicSearchEnabled == publicSearchEnabled;

  @override
  int get hashCode =>
      Object.hash(packAccessPercent, publicPublishPercent, publicSearchEnabled);
}
