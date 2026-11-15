// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Выключатели отправки файлов: блок `media` подписанного `/v1/config`
/// (разбор медиа, 15.11.2026). Пока одно поле — доля устройств, которые
/// отправляют файлы ЧАСТЯМИ с докачкой (сессии реле), как Signal и WhatsApp.
///
/// **Отказ.** Блок не пришёл или не проверен — [defaults]: доля 0, отправка
/// прежняя (одним запросом). Реле без сессий отвечает 404 — клиент тогда
/// сам возвращается к прежней отправке (см. `BlobClient`).
@immutable
class MediaFlags {
  const MediaFlags({this.resumableUploadShare = 0});

  static const MediaFlags defaults = MediaFlags();

  /// Доля устройств (0…100) с отправкой частями.
  final int resumableUploadShare;

  static MediaFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['media'];
    if (payload is! Map) return defaults;
    final raw = payload['resumable_upload_share'];
    return MediaFlags(
      resumableUploadShare: (raw is num ? raw.toInt() : 0).clamp(0, 100),
    );
  }

  /// Детерминированно по устройству: sha256('media-resumable_upload-v1|' +
  /// device_id), два первых байта, остаток от 100. Расширение доли не
  /// выключает уже включённых. Пустой id — нет.
  bool resumableUploadFor(String deviceId) {
    if (resumableUploadShare <= 0) return false;
    final id = deviceId.trim();
    if (id.isEmpty) return false;
    if (resumableUploadShare >= 100) return true;
    final digest = sha256
        .convert(utf8.encode('media-resumable_upload-v1|$id'))
        .bytes;
    return ((digest[0] << 8) | digest[1]) % 100 < resumableUploadShare;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaFlags &&
          other.resumableUploadShare == resumableUploadShare;

  @override
  int get hashCode => resumableUploadShare.hashCode;
}
