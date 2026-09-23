// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Приглашение в набор стикеров — Ш-2.
///
/// ЗАЧЕМ. Сегодня уезжают ОТДЕЛЬНЫЕ картинки: получатель видит стикер, но не
/// может добавить набор себе. Пока делить нечего, второй настройке («кто может
/// пользоваться») нечем управлять.
///
/// 🔴 СЕРВЕР ЗДЕСЬ НЕ УЧАСТВУЕТ, и это главное свойство замысла. Каждый стикер
/// уже лежит на сервере ЗАШИФРОВАННЫМ блобом, а ключ к нему — только у
/// собеседников. Значит «поделиться набором» это просто список этих ссылок,
/// отправленный обычным E2EE-сообщением: сервер по-прежнему не знает ни что за
/// набор, ни кому его передали. Ни выгрузки, ни каталога, ни модерации не нужно —
/// а публикация (§4 ТЗ) всего этого требует.
library;

import 'dart:convert';

/// Один стикер внутри приглашения.
///
/// 🔴 `localPath` СЮДА НЕ ВХОДИТ, и это не забывчивость. Путь к файлу на моём
/// устройстве собеседнику бесполезен, а вот раскрывает он лишнее: имя
/// пользователя в пути, структуру каталогов, иногда модель устройства. В провод
/// уходит только то, чем стикер можно достать и показать.
class StickerPackInviteItem {
  const StickerPackInviteItem({
    required this.stickerId,
    required this.fileName,
    required this.format,
    required this.animated,
    required this.blobId,
    required this.fileKeyB64,
    this.accessTokenB64,
    this.emojiHint = '',
    this.label = '',
    this.sizeBytes,
    this.sha256B64,
  });

  final String stickerId;
  final String fileName;
  final String format;
  final bool animated;

  /// Ссылка на шифртекст и ключ к нему.
  ///
  /// 🔴 Стикер БЕЗ этой пары нельзя ни достать, ни расшифровать, поэтому он в
  /// приглашении бесполезен и отбрасывается при разборе. Пропустить его «на
  /// всякий случай» значило бы отдать получателю набор с дырами, которые он
  /// принял бы за поломку приложения.
  final String blobId;
  final String fileKeyB64;
  final String? accessTokenB64;

  final String emojiHint;
  final String label;
  final int? sizeBytes;
  final String? sha256B64;

  Map<String, Object?> toJson() => <String, Object?>{
    'stickerId': stickerId,
    'fileName': fileName,
    'format': format,
    'animated': animated,
    'blobId': blobId,
    'fileKeyB64': fileKeyB64,
    if ((accessTokenB64 ?? '').isNotEmpty) 'accessTokenB64': accessTokenB64,
    if (emojiHint.isNotEmpty) 'emojiHint': emojiHint,
    if (label.isNotEmpty) 'label': label,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
    if ((sha256B64 ?? '').isNotEmpty) 'sha256B64': sha256B64,
  };

  /// Разбор одного стикера. `null` — если он бесполезен.
  static StickerPackInviteItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    String str(String key) {
      final value = raw[key];
      return value is String ? value.trim() : '';
    }

    final stickerId = str('stickerId');
    final blobId = str('blobId');
    final fileKeyB64 = str('fileKeyB64');
    if (stickerId.isEmpty || blobId.isEmpty || fileKeyB64.isEmpty) return null;

    final format = str('format');
    if (format.isEmpty) return null;

    final size = raw['sizeBytes'];
    return StickerPackInviteItem(
      stickerId: stickerId,
      // Имя файла восстановимо: если его нет, соберём из идентификатора, иначе
      // придётся выбросить рабочий стикер из-за косметики.
      fileName: str('fileName').isEmpty ? '$stickerId.$format' : str('fileName'),
      format: format,
      animated: raw['animated'] == true,
      blobId: blobId,
      fileKeyB64: fileKeyB64,
      accessTokenB64: str('accessTokenB64').isEmpty
          ? null
          : str('accessTokenB64'),
      emojiHint: str('emojiHint'),
      label: str('label'),
      sizeBytes: size is num ? size.toInt() : null,
      sha256B64: str('sha256B64').isEmpty ? null : str('sha256B64'),
    );
  }
}

/// Приглашение в набор целиком.
class StickerPackInvite {
  const StickerPackInvite({
    required this.packId,
    required this.packVersion,
    required this.title,
    required this.iconStickerId,
    required this.items,
  });

  /// Вид сообщения на проводе.
  static const String wireKind = 'sticker_pack_invite';

  /// Версия формата.
  ///
  /// 🔴 Приёмник обязан ИГНОРИРОВАТЬ незнакомую версию, а не падать: сообщение
  /// приходит из чужой сборки, и падение на нём означало бы, что новая версия
  /// формата ломает старым сборкам разбор входящих. Ровно тот шрам, что
  /// 1.7.4+416, где отказ читать стоил безвозвратной потери сообщений.
  static const int wireVersion = 1;

  /// Потолок стикеров в одном приглашении.
  ///
  /// 🔴 Нужен затем, что конверт едет ОДНИМ сообщением: набор в тысячу стикеров
  /// собрал бы конверт, который не пролезет, и отправка молча умерла бы у
  /// человека на руках. Лучше честно отдать первые [maxItems] и сказать об этом,
  /// чем не отдать ничего.
  static const int maxItems = 120;

  final String packId;
  final int packVersion;
  final String title;
  final String iconStickerId;
  final List<StickerPackInviteItem> items;

  /// Своего ли человека это набор (в отличие от каталожного).
  bool get isUserPack => packId.startsWith('user:');

  Map<String, Object?> toJson() => <String, Object?>{
    'v': wireVersion,
    'kind': wireKind,
    'packId': packId,
    'packVersion': packVersion,
    'title': title,
    'iconStickerId': iconStickerId,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };

  String encode() => jsonEncode(toJson());

  /// Разбор приглашения. `null` — если оно непригодно.
  ///
  /// 🔴 Отказ в закрытую: всё непонятое даёт `null`, а не половину набора.
  /// Единственное исключение — отдельные негодные стикеры внутри годного
  /// приглашения: они отбрасываются, остальные принимаются. Выбросить весь набор
  /// из-за одного битого стикера было бы хуже для человека, чем набор на один
  /// стикер меньше.
  static StickerPackInvite? fromJson(Object? raw) {
    if (raw is! Map) return null;
    if (raw['kind'] != wireKind) return null;

    final version = raw['v'];
    // Незнакомая версия — молча не наше дело. Именно так, а не исключением.
    if (version is! num || version.toInt() != wireVersion) return null;

    String str(String key) {
      final value = raw[key];
      return value is String ? value.trim() : '';
    }

    final packId = str('packId');
    final title = str('title');
    final rawVersion = raw['packVersion'];
    final packVersion = rawVersion is num ? rawVersion.toInt() : 0;
    if (packId.isEmpty || title.isEmpty || packVersion <= 0) return null;

    final rawItems = raw['items'];
    if (rawItems is! List) return null;
    final items = <StickerPackInviteItem>[];
    final seen = <String>{};
    for (final entry in rawItems) {
      final item = StickerPackInviteItem.fromJson(entry);
      if (item == null) continue;
      // Повтор одного stickerId сделал бы набор с дублями; берём первый.
      if (!seen.add(item.stickerId)) continue;
      items.add(item);
      if (items.length >= maxItems) break;
    }
    // Набор без ни одного пригодного стикера предлагать нечего.
    if (items.isEmpty) return null;

    final icon = str('iconStickerId');
    return StickerPackInvite(
      packId: packId,
      packVersion: packVersion,
      title: title,
      // Значок восстановим первым стикером — терять из-за него набор незачем.
      iconStickerId: icon.isEmpty ? items.first.stickerId : icon,
      items: List<StickerPackInviteItem>.unmodifiable(items),
    );
  }

  static StickerPackInvite? decode(String rawJson) {
    try {
      return fromJson(jsonDecode(rawJson));
    } on FormatException {
      return null;
    }
  }
}
