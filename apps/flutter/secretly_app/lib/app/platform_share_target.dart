// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/services.dart';
import '../attachments/attachment_naming.dart';

class PlatformSharedFile {
  const PlatformSharedFile({required this.path, this.mime, this.name});

  final String path;
  final String? mime;
  final String? name;

  String get resolvedMime {
    final normalized = mime?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
    // 🔴 ТИП ВЫВОДИМ ИЗ ИМЕНИ, А НЕ ИЗ ПУТИ (14.08.2026). Путь у файла,
    // пришедшего через «поделиться», временный (`…/cache/share_…`) и расширения
    // не содержит — поэтому здесь всегда получалось «не знаю», то есть
    // `application/octet-stream`, и apk отправлялся обезличенным.
    return _guessMime(name ?? '') ??
        _guessMime(path) ??
        'application/octet-stream';
  }

  bool get isVisualMedia {
    final normalized = resolvedMime.toLowerCase();
    return normalized.startsWith('image/') || normalized.startsWith('video/');
  }
}

class PlatformSharePayload {
  const PlatformSharePayload({
    this.files = const <PlatformSharedFile>[],
    this.text,
  });

  final List<PlatformSharedFile> files;
  final String? text;

  bool get isEmpty => files.isEmpty && (text ?? '').trim().isEmpty;

  /// The text that should actually be posted as a message.
  ///
  /// A file share often carries the file's OWN name as EXTRA_TEXT/EXTRA_SUBJECT
  /// — screenshots especially, where many share sheets set the subject to
  /// "Screenshot_2026…". Posting that put a separate bubble with the filename
  /// next to the image (the "extra name bubble" report). When files are present
  /// we drop text that is merely a filename, but keep a genuine caption a person
  /// actually typed. A pure text share (no files) is never touched.
  String? get meaningfulText {
    final t = (text ?? '').trim();
    if (t.isEmpty) return null;
    if (files.isEmpty) return t;
    return _isJustAFilename(t) ? null : t;
  }

  bool _isJustAFilename(String t) {
    for (final f in files) {
      final base = _basename(f.path);
      final byName = (f.name ?? '').trim();
      if (t == base || (byName.isNotEmpty && t == byName)) return true;
      if (t == _stripExt(base) ||
          (byName.isNotEmpty && t == _stripExt(byName))) {
        return true;
      }
    }
    // A bare filename token: no spaces and a short extension.
    if (!t.contains(' ') && RegExp(r'\.[A-Za-z0-9]{2,5}$').hasMatch(t)) {
      return true;
    }
    // Common screenshot/camera auto-name prefixes, even without an extension.
    if (RegExp(
      r'^(Screenshot|Screen[ _]?Shot|IMG|PXL|DSC|Photo|Снимок экрана|Скриншот)[\w\-. ]*$',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    return false;
  }

  static String _basename(String path) {
    final norm = path.replaceAll('\\', '/');
    final i = norm.lastIndexOf('/');
    return (i >= 0 ? norm.substring(i + 1) : norm).trim();
  }

  static String _stripExt(String name) {
    final dot = name.lastIndexOf('.');
    return (dot > 0 ? name.substring(0, dot) : name).trim();
  }
}

class PlatformShareTarget {
  static const EventChannel _channel = EventChannel('secretly/share_intents');

  static Stream<PlatformSharePayload> get stream {
    return _channel
        .receiveBroadcastStream()
        .map(_decodePayload)
        .where((payload) => !payload.isEmpty);
  }

  static PlatformSharePayload _decodePayload(Object? raw) {
    if (raw is! Map) return const PlatformSharePayload();
    final map = raw.cast<Object?, Object?>();
    final rawFiles = map['files'];
    final files = <PlatformSharedFile>[];
    if (rawFiles is List) {
      for (final item in rawFiles) {
        if (item is! Map) continue;
        final fileMap = item.cast<Object?, Object?>();
        final path = (fileMap['path'] as String?)?.trim() ?? '';
        if (path.isEmpty) continue;
        files.add(
          PlatformSharedFile(
            path: path,
            mime: (fileMap['mime'] as String?)?.trim(),
            name: (fileMap['name'] as String?)?.trim(),
          ),
        );
      }
    }
    final text = (map['text'] as String?)?.trim();
    return PlatformSharePayload(
      files: List<PlatformSharedFile>.unmodifiable(files),
      text: text == null || text.isEmpty ? null : text,
    );
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
