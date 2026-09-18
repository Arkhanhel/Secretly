// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/services.dart';
import '../attachments/attachment_naming.dart';

class PlatformClipboardMediaItem {
  const PlatformClipboardMediaItem({required this.path, this.mime, this.name});

  final String path;
  final String? mime;
  final String? name;

  String get resolvedMime {
    final normalized = mime?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
    return _guessMime(path) ?? 'image/jpeg';
  }

  bool get isImage => resolvedMime.toLowerCase().startsWith('image/');
}

class PlatformClipboardMedia {
  static const MethodChannel _channel = MethodChannel(
    'secretly/clipboard_media',
  );

  static Future<PlatformClipboardMediaItem?> readImage() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    try {
      final raw = await _channel.invokeMethod<Object?>('readImage');
      return _decodeItem(raw);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<PlatformClipboardMediaItem?> copyUri({
    required String uri,
    String? mime,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<Object?>('copyUri', {
        'uri': uri,
        'mime': mime,
      });
      return _decodeItem(raw);
    } on MissingPluginException {
      return null;
    }
  }

  static PlatformClipboardMediaItem? _decodeItem(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final path = (map['path'] as String?)?.trim() ?? '';
    if (path.isEmpty) return null;
    final item = PlatformClipboardMediaItem(
      path: path,
      mime: (map['mime'] as String?)?.trim(),
      name: (map['name'] as String?)?.trim(),
    );
    return item.isImage ? item : null;
  }
}

String? _guessMime(String pathOrName) =>
    // 🔴 ОДНА ТАБЛИЦА ТИПОВ НА ПРИЛОЖЕНИЕ (14.08.2026). Здесь лежал свой список
    // из ~26 расширений — он знал pdf и zip, но НЕ знал apk, docx, xlsx, rar.
    // Поэтому apk уходил с сервера как `application/octet-stream`, то есть
    // портился в самом источнике, у отправителя. Таких списков было ТРИ, с
    // разным содержимым.
    //
    // Возврат `null` для незнакомого типа СОХРАНЁН намеренно: вызывающие пишут
    // `_guessMime(p) ?? выбранныйСистемойТип`, и «не знаю» вместо `null` затёрло
    // бы настоящий тип.
    attachmentMimeForOrNull(pathOrName);
