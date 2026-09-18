// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/e2e_payload_v1.dart' show AttachmentEventV1;

/// Название и исполнитель песни.
@immutable
class MusicTags {
  const MusicTags({this.title, this.artist});

  final String? title;
  final String? artist;

  bool get isEmpty => title == null && artist == null;
}

/// 🔴 ТЕГИ ПЕСНИ — ОДИН ЧТЕЦ НА ВСЕ УСТРОЙСТВА (17.09.2026).
///
/// Библиотека тегов (`audiotags`, Rust) на iPhone ОТКЛЮЧЕНА — `AudioTags.read`
/// там молча возвращает пусто. Из-за этого песни с iPhone уходили с именем
/// файла вместо названия и без исполнителя, а полученную песню iPhone не мог
/// подписать и сам. На iPhone теги читает система (AVFoundation, канал
/// `secretly/music_tags` в `AppDelegate.swift`): разбор чужого файла остаётся
/// в системном компоненте, который обновляет Apple, — так же, как у PDF.
///
/// На остальных устройствах сначала читает библиотека, а если не справилась —
/// система (AVFoundation на Mac, MediaMetadataRetriever на Android; тот же
/// канал). Библиотека не видит M4A, у которого служебный блок `moov` стоит
/// после данных, — так по умолчанию пишет, например, ffmpeg, — и такие песни
/// уходили без подписи. На Windows и Linux системного пути нет.
///
/// Никогда не бросает: не прочлось — `null`.
class MusicTagReader {
  MusicTagReader._();

  static const MethodChannel _channel = MethodChannel('secretly/music_tags');

  /// Подмена для тестов: в тестах нет ни библиотеки, ни системного канала.
  @visibleForTesting
  static Future<MusicTags?> Function(String path)? readOverride;

  static Future<MusicTags?> read(String path) async {
    final override = readOverride;
    if (override != null) return override(path);
    if (kIsWeb || path.trim().isEmpty) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _readWithSystem(path);
    }
    MusicTags? fromLibrary;
    try {
      final tag = await AudioTags.read(path);
      fromLibrary = _tags(tag?.title, tag?.trackArtist);
    } catch (_) {
      fromLibrary = null;
    }
    if (fromLibrary != null) return fromLibrary;
    return _readWithSystem(path);
  }

  /// Сколько ждать системного чтения. Android разбирает файлы по одному в
  /// своём потоке: застрявший файл не должен держать отправку или
  /// воспроизведение (17.09.2026).
  @visibleForTesting
  static Duration systemReadTimeout = const Duration(seconds: 5);

  static Future<MusicTags?> _readWithSystem(String path) async {
    try {
      final raw = await _channel
          .invokeMapMethod<String, Object?>(
            'read',
            <String, Object?>{'path': path},
          )
          .timeout(systemReadTimeout);
      if (raw == null) return null;
      return _tags(raw['title'] as String?, raw['artist'] as String?);
    } catch (_) {
      return null;
    }
  }

  static MusicTags? _tags(String? title, String? artist) {
    final tags = MusicTags(
      title: normalizeMusicLabel(title),
      artist: normalizeMusicLabel(artist),
    );
    return tags.isEmpty ? null : tags;
  }
}

/// Подпись из тега без лишних пробелов; пустая — `null`.
String? normalizeMusicLabel(String? value) {
  if (value == null) return null;
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return compact.isEmpty ? null : compact;
}

/// Название песни из сообщения — если это НАСТОЯЩИЙ тег.
///
/// 🔴 Телефон долго клал в «название» имя файла: теги читались уже после
/// того, как очередь забрала подписи (а на iPhone не читались вовсе), и в
/// сообщение уходило `track.mp3` вместо названия. Такое «название» ничего не
/// говорит, но стоит ПЕРВЫМ в порядке показа и заслоняет теги, которые
/// получатель мог бы прочитать из самого файла. Поэтому название, совпадающее
/// с именем файла, за тег не считается.
String? taggedMusicTitle(AttachmentEventV1 a) {
  final title = normalizeMusicLabel(a.musicTitle);
  if (title == null) return null;
  final filename = normalizeMusicLabel(a.filename);
  if (filename != null && filename.toLowerCase() == title.toLowerCase()) {
    return null;
  }
  return title;
}

/// Исполнитель из сообщения; пустой — `null`.
String? taggedMusicArtist(AttachmentEventV1 a) =>
    normalizeMusicLabel(a.musicArtist);
