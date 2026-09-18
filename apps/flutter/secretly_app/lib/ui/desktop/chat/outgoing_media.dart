// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../attachments/attachment_naming.dart'
    show attachmentMimeForOrNull;
import '../../../media/music_tags.dart';
import '../../../media/video_thumbnail_cache.dart';

// 🔴 ЧТО УХОДИТ ИЗ ОКНА ОТПРАВКИ — И В КАКОМ ВИДЕ.
//
// Указание владельца 16.09.2026: перетащил файлы — появилось окно, как в
// Telegram, там подпись, и отправленное выглядит так же, как в Telegram.
// Здесь всё, что окно знает о файлах: вид, размеры, что показывать и что
// отправлять, и как пачка делится на сообщения.

/// Вид файла в окне отправки.
enum OutgoingKind { photo, video, gif, audio, file }

/// Тип по расширению.
///
/// Нужен дважды: чтобы решить, снимок это или документ, и чтобы получатель
/// знал, чем файл открыть. Неизвестное — `null`: контроллер отправит его как
/// двоичный файл, и он нарисуется строкой документа.
String? desktopMimeForName(String name) =>
    _desktopMimeByExtension(name) ?? attachmentMimeForOrNull(name);

/// Своя таблица компьютера — первой, чтобы уже знакомые типы не поменялись.
/// Всё, чего в ней нет, берётся из ОБЩЕЙ таблицы (`attachment_naming.dart`,
/// 17.09.2026): установочный пакет `.apk` и прочие типы, которые знает
/// телефон, уходили отсюда безымянным `application/octet-stream`.
String? _desktopMimeByExtension(String name) {
  final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' || 'heif' => 'image/heic',
    'bmp' => 'image/bmp',
    'tif' || 'tiff' => 'image/tiff',
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'mkv' => 'video/x-matroska',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'ogg' || 'oga' => 'audio/ogg',
    'opus' => 'audio/opus',
    'flac' => 'audio/flac',
    'wav' => 'audio/wav',
    'pdf' => 'application/pdf',
    'zip' => 'application/zip',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'json' => 'application/json',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    _ => null,
  };
}

/// Какие снимки можно отправить «как фото». SVG, PSD и прочее — только
/// файлом: получатель их не нарисует.
const Set<String> _photoExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'heif',
  'bmp',
  'tif',
  'tiff',
};

/// Ролики, которые умеют играть все устройства. `mkv` и прочее — файлом.
const Set<String> _videoExtensions = <String>{'mp4', 'm4v', 'mov', 'webm'};

/// Песни, которые уходят музыкой (стопкой песен), а не документами.
const Set<String> _audioExtensions = <String>{
  'mp3',
  'm4a',
  'aac',
  'ogg',
  'oga',
  'opus',
  'flac',
  'wav',
};

OutgoingKind outgoingKindFor(String name) {
  final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
  if (ext == 'gif') return OutgoingKind.gif;
  if (_photoExtensions.contains(ext)) return OutgoingKind.photo;
  if (_videoExtensions.contains(ext)) return OutgoingKind.video;
  if (_audioExtensions.contains(ext)) return OutgoingKind.audio;
  return OutgoingKind.file;
}

/// Файл, который человек собирается отправить.
class OutgoingFile {
  OutgoingFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    OutgoingKind? kind,
  }) : kind = kind ?? outgoingKindFor(name);

  /// Исходный файл — его же отправляем «как файл».
  final String path;

  /// Имя документа у получателя.
  final String name;
  final int sizeBytes;
  final OutgoingKind kind;

  String? get mime => desktopMimeForName(name);

  /// Снимок или ролик — то, что вообще может уйти «как медиа».
  bool get isVisual =>
      kind == OutgoingKind.photo ||
      kind == OutgoingKind.video ||
      kind == OutgoingKind.gif;

  // ── Заполняет [OutgoingMediaPrep.prepare] ──────────────────────────────

  /// Пропорции для раскладки — уже с учётом поворота.
  ui.Size? size;

  /// Что показывать в окне: перекодированный снимок (HEIC Flutter не
  /// читает) или кадр ролика. `null` — показывать нечего, будет значок.
  String? previewPath;

  /// Что отправлять «как медиа», если это не исходный файл: снимок
  /// перекодирован (HEIC, больше 2560 точек).
  String? mediaPath;
  String? mediaMime;
  int? mediaSizeBytes;

  /// Ролик: длительность и крошечная миниатюра по кадру для получателя.
  int? durationMs;
  String? thumbB64;

  /// Песня: название и исполнитель из тегов файла. Уходят в сообщении —
  /// иначе у получателя песня подписана именем файла.
  String? musicTitle;
  String? musicArtist;

  /// Снимок, который не удалось прочесть ни Flutter, ни системе, уходит
  /// файлом: у получателя вместо картинки была бы пустая плитка.
  bool canBeMedia = true;

  bool prepared = false;

  /// Что уйдёт при отправке «как медиа».
  String get mediaSendPath => mediaPath ?? path;
  String? get mediaSendMime => mediaMime ?? mime;
  int get mediaSendSize => mediaSizeBytes ?? sizeBytes;
}

/// Что вышло из брошенных путей.
class OutgoingIntake {
  const OutgoingIntake({
    required this.files,
    this.folders = const <String>[],
    this.empty = const <String>[],
    this.tooLarge = const <String>[],
    this.unreadable = const <String>[],
  });

  final List<OutgoingFile> files;
  final List<String> folders;
  final List<String> empty;
  final List<String> tooLarge;
  final List<String> unreadable;

  bool get hasRejected =>
      folders.isNotEmpty ||
      empty.isNotEmpty ||
      tooLarge.isNotEmpty ||
      unreadable.isNotEmpty;

  /// Одна строка о том, что не взято, — или `null`.
  String? rejectionText({required int maxBytes}) {
    final parts = <String>[];
    if (folders.isNotEmpty) {
      parts.add(
        folders.length == 1
            ? 'папку «${folders.single}» отправить нельзя'
            : 'папки отправить нельзя',
      );
    }
    if (tooLarge.isNotEmpty) {
      final limit = (maxBytes / (1024 * 1024)).round();
      parts.add(
        tooLarge.length == 1
            ? '«${tooLarge.single}» больше $limit МБ'
            : '${tooLarge.length} ${_plural(tooLarge.length, 'файл', 'файла', 'файлов')} больше $limit МБ',
      );
    }
    if (empty.isNotEmpty) {
      parts.add(
        empty.length == 1
            ? '«${empty.single}» пустой'
            : '${empty.length} ${_plural(empty.length, 'файл', 'файла', 'файлов')} пустые',
      );
    }
    if (unreadable.isNotEmpty) {
      parts.add(
        unreadable.length == 1
            ? '«${unreadable.single}» не удалось прочитать'
            : '${unreadable.length} ${_plural(unreadable.length, 'файл', 'файла', 'файлов')} не удалось прочитать',
      );
    }
    if (parts.isEmpty) return null;
    final text = parts.join('; ');
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// Разбирает пути, брошенные в окно или вставленные из буфера.
///
/// Папки, пустые файлы и файлы больше предела не берутся — с объяснением, а
/// не молча. Повторы (тот же файл брошен второй раз) пропускаются.
OutgoingIntake intakeOutgoingPaths(
  Iterable<String> paths, {
  required int maxBytes,
  Set<String> alreadyAdded = const <String>{},
}) {
  final files = <OutgoingFile>[];
  final folders = <String>[];
  final empty = <String>[];
  final tooLarge = <String>[];
  final unreadable = <String>[];
  final seen = <String>{...alreadyAdded};
  for (final raw in paths) {
    final path = raw.trim();
    if (path.isEmpty || !seen.add(path)) continue;
    final name = p.basename(path);
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        folders.add(name);
        continue;
      }
      if (type != FileSystemEntityType.file) {
        unreadable.add(name);
        continue;
      }
      final size = File(path).lengthSync();
      if (size <= 0) {
        empty.add(name);
      } else if (maxBytes > 0 && size > maxBytes) {
        tooLarge.add(name);
      } else {
        files.add(OutgoingFile(path: path, name: name, sizeBytes: size));
      }
    } catch (_) {
      unreadable.add(name);
    }
  }
  return OutgoingIntake(
    files: files,
    folders: folders,
    empty: empty,
    tooLarge: tooLarge,
    unreadable: unreadable,
  );
}

/// Одно будущее сообщение (или альбом) из пачки.
class OutgoingGroup {
  OutgoingGroup({required this.asMedia}) : files = <OutgoingFile>[];

  final List<OutgoingFile> files;

  /// `true` — снимки и ролики без имён (альбом); `false` — документы или
  /// песни с именами.
  final bool asMedia;
}

/// Сколько вложений в одном альбоме — как в Telegram.
const int kOutgoingAlbumLimit = 10;

/// Делит пачку на сообщения — так же, как Telegram Desktop
/// (`DivideByGroups`): подряд идущие снимки и ролики — альбомами по десять,
/// песни — своими стопками, прочие файлы — своими; гифка всегда отдельно.
/// Без группировки каждый файл — отдельное сообщение.
List<OutgoingGroup> planOutgoingGroups(
  List<OutgoingFile> files, {
  required bool sendAsFiles,
  required bool grouped,
}) {
  final groups = <OutgoingGroup>[];
  OutgoingGroup? open;
  String? openShelf;
  for (final f in files) {
    final asMedia =
        !sendAsFiles &&
        f.canBeMedia &&
        (f.kind == OutgoingKind.photo ||
            f.kind == OutgoingKind.video ||
            f.kind == OutgoingKind.gif);
    final shelf = !asMedia
        ? (f.kind == OutgoingKind.audio ? 'music' : 'files')
        : (f.kind == OutgoingKind.gif ? 'gif' : 'media');
    final startNew =
        open == null ||
        !grouped ||
        shelf == 'gif' ||
        shelf != openShelf ||
        open.files.length >= kOutgoingAlbumLimit;
    if (startNew) {
      open = OutgoingGroup(asMedia: asMedia);
      openShelf = shelf;
      groups.add(open);
    }
    open.files.add(f);
  }
  return groups;
}

/// Подпись уходит внутри сообщения, только если сообщение одно. Иначе — как
/// в Telegram — отдельным текстом ПЕРЕД файлами: подпись под последним из
/// пяти несгруппированных снимков читалась бы как подпись к нему одному.
bool captionTravelsSeparately(List<OutgoingGroup> groups) => groups.length > 1;

/// Заголовок окна: «Фото», «3 фото», «2 медиа», «5 файлов».
String outgoingDialogTitle(List<OutgoingFile> files, {required bool sendAsFiles}) {
  final n = files.length;
  if (n == 0) return 'Отправка';
  final visual = files.every(
    (f) => f.canBeMedia && (f.kind == OutgoingKind.photo || f.kind == OutgoingKind.gif),
  );
  final videos = files.every((f) => f.kind == OutgoingKind.video);
  final media = files.every(
    (f) =>
        f.canBeMedia &&
        (f.kind == OutgoingKind.photo ||
            f.kind == OutgoingKind.video ||
            f.kind == OutgoingKind.gif),
  );
  final music = files.every((f) => f.kind == OutgoingKind.audio);
  if (!sendAsFiles && visual) return n == 1 ? 'Фото' : '$n фото';
  if (!sendAsFiles && videos) return n == 1 ? 'Видео' : '$n видео';
  if (!sendAsFiles && media) return '$n медиа';
  if (music) return n == 1 ? 'Аудио' : '$n аудио';
  return n == 1 ? 'Файл' : '$n ${_plural(n, 'файл', 'файла', 'файлов')}';
}

String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/// Подготовка файлов для окна и для отправки.
abstract final class OutgoingMediaPrep {
  static const MethodChannel _channel = MethodChannel('secretly/image_prep');

  /// Длинная сторона снимка «как фото» — как в Telegram.
  static const int maxPhotoSide = 2560;

  /// Эти форматы перекодируются всегда: HEIC и TIFF не читают многие
  /// получатели, BMP — несжатый и огромный.
  static const Set<String> _alwaysTranscode = <String>{
    'heic',
    'heif',
    'tif',
    'tiff',
    'bmp',
  };

  /// Подменяет системный перекодировщик в тестах.
  @visibleForTesting
  static Future<Map<Object?, Object?>?> Function(String path, String outPath)?
  transcodeOverride;

  static Future<void> prepare(OutgoingFile f) async {
    if (f.prepared) return;
    try {
      switch (f.kind) {
        case OutgoingKind.photo:
          await _preparePhoto(f);
        case OutgoingKind.gif:
          final size = await readImageSize(f.path);
          f.size = size;
          f.previewPath = size == null ? null : f.path;
          f.canBeMedia = size != null;
        case OutgoingKind.video:
          await _prepareVideo(f);
        case OutgoingKind.audio:
          final tags = await MusicTagReader.read(f.path);
          f.musicTitle = tags?.title;
          f.musicArtist = tags?.artist;
        case OutgoingKind.file:
          break;
      }
    } catch (_) {
      // Подготовка — не условие отправки: не вышло, файл уйдёт как есть.
    }
    f.prepared = true;
  }

  static Future<void> _preparePhoto(OutgoingFile f) async {
    final ext = p.extension(f.name).toLowerCase().replaceFirst('.', '');
    final size = await readImageSize(f.path);
    final tooBig =
        size != null && math.max(size.width, size.height) > maxPhotoSide;
    final mustTranscode = size == null || tooBig || _alwaysTranscode.contains(ext);
    if (mustTranscode) {
      final out = await _transcode(f.path);
      if (out != null) {
        f.mediaPath = out.path;
        f.mediaMime = out.mime;
        f.mediaSizeBytes = out.sizeBytes;
        f.size = out.size;
        f.previewPath = out.path;
        return;
      }
    }
    if (size == null) {
      // Ни Flutter, ни система снимок не прочли — пусть уходит файлом.
      f.canBeMedia = false;
      return;
    }
    f.size = size;
    f.previewPath = f.path;
  }

  /// Ключ кадра исходящего ролика — по пути, размеру и времени правки: тот
  /// же файл после правки — уже другой кадр. Им же пользуется заготовка в
  /// ленте, чтобы не снимать кадр второй раз.
  static String videoThumbKey(String path) {
    try {
      final stat = File(path).statSync();
      return 'outgoing_${path.hashCode.toUnsigned(32)}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
    } catch (_) {
      return 'outgoing_${path.hashCode.toUnsigned(32)}';
    }
  }

  static Future<void> _prepareVideo(OutgoingFile f) async {
    final key = videoThumbKey(f.path);
    final thumb = await VideoThumbnailCache.forVideo(key: key, videoPath: f.path);
    if (thumb == null) return;
    f.previewPath = thumb.file.path;
    f.durationMs = thumb.durationMs;
    // Кадр уменьшен, но пропорции у него — ролика; получателю нужны именно
    // они.
    f.size = await readImageSize(thumb.file.path);
    f.thumbB64 = await inlineThumbB64(thumb.file.path);
  }

  /// Размеры снимка без полного декодирования. С учётом поворота из EXIF.
  static Future<ui.Size?> readImageSize(String path) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      if (w <= 0 || h <= 0) return null;
      return ui.Size(w.toDouble(), h.toDouble());
    } catch (_) {
      return null;
    } finally {
      _quietly(() => descriptor?.dispose());
      _quietly(() => buffer?.dispose());
    }
  }

  /// Миниатюра до 32 точек — как у контроллера для снимков
  /// (`_buildAttachmentInlineThumbB64`), чтобы у получателя ролик до загрузки
  /// был размытым кадром, а не пустым прямоугольником.
  static Future<String?> inlineThumbB64(String path) async {
    ui.ImmutableBuffer? buffer;
    ui.Codec? codec;
    ui.Image? frame;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (w, h) => ui.TargetImageSize(
          width: w >= h ? 32 : null,
          height: h > w ? 32 : null,
        ),
      );
      frame = (await codec.getNextFrame()).image;
      final raw = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) return null;
      final small = img.Image.fromBytes(
        width: frame.width,
        height: frame.height,
        bytes: raw.buffer,
        numChannels: 4,
      );
      final jpg = img.encodeJpg(small, quality: 50);
      if (jpg.length > 3 * 1024) return null;
      return base64Encode(jpg);
    } catch (_) {
      return null;
    } finally {
      _quietly(() => frame?.dispose());
      _quietly(() => codec?.dispose());
      _quietly(() => buffer?.dispose());
    }
  }

  static Future<_Transcoded?> _transcode(String path) async {
    final dir = await prepDirectory();
    final base = p.join(
      dir.path,
      'send_${DateTime.now().microsecondsSinceEpoch}_${path.hashCode.toUnsigned(20)}',
    );
    Map<Object?, Object?>? res;
    try {
      final override = transcodeOverride;
      if (override != null) {
        res = await override(path, base);
      } else {
        if (!Platform.isMacOS) return null;
        res = await _channel.invokeMapMethod<Object?, Object?>('transcode', {
          'path': path,
          'outPath': base,
          'maxSide': maxPhotoSide,
          'quality': 0.87,
        });
      }
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
    if (res == null) return null;
    final written = res['path'] as String?;
    final w = (res['width'] as num?)?.toDouble() ?? 0;
    final h = (res['height'] as num?)?.toDouble() ?? 0;
    final mime = (res['mime'] as String?) ?? 'image/jpeg';
    if (written == null || w <= 0 || h <= 0) return null;
    // Расширение — по тому, что записано: по нему файл узнают при просмотре.
    final ext = mime == 'image/png' ? '.png' : '.jpg';
    try {
      final file = File(written);
      final named = await file.rename('$written$ext');
      return _Transcoded(
        path: named.path,
        mime: mime,
        size: ui.Size(w, h),
        sizeBytes: await named.length(),
      );
    } catch (_) {
      return null;
    }
  }

  static Directory? _prepDir;

  /// Подменяет папку подготовки в тестах.
  @visibleForTesting
  static Directory? debugPrepDirectory;

  /// Папка подготовленных к отправке снимков. Старше суток — удаляются при
  /// первом обращении: к этому времени всё давно отправлено.
  static Future<Directory> prepDirectory() async {
    final forced = debugPrepDirectory;
    if (forced != null) return forced;
    final ready = _prepDir;
    if (ready != null) return ready;
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'send_prep'));
    await dir.create(recursive: true);
    _prepDir = dir;
    unawaited(_sweep(dir));
    return dir;
  }

  static Future<void> _sweep(Directory dir) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    try {
      await for (final e in dir.list()) {
        try {
          if (e is File && (await e.lastModified()).isBefore(cutoff)) {
            await e.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Снимок из буфера обмена — в файл, чтобы дальше он шёл тем же путём,
  /// что и брошенный.
  static Future<OutgoingFile?> stagePastedImage(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    final dir = await prepDirectory();
    final file = File(
      p.join(dir.path, 'pasted_${DateTime.now().microsecondsSinceEpoch}.png'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return OutgoingFile(
      path: file.path,
      name: 'image.png',
      sizeBytes: bytes.length,
      kind: OutgoingKind.photo,
    );
  }

  static void _quietly(void Function() release) {
    try {
      release();
    } catch (_) {}
  }
}

class _Transcoded {
  const _Transcoded({
    required this.path,
    required this.mime,
    required this.size,
    required this.sizeBytes,
  });

  final String path;
  final String mime;
  final ui.Size size;
  final int sizeBytes;
}

/// Буфер обмена: скопированные файлы и картинка.
abstract final class DesktopClipboardMedia {
  @visibleForTesting
  static Future<List<String>> Function()? filesOverride;
  @visibleForTesting
  static Future<Uint8List?> Function()? imageOverride;
  @visibleForTesting
  static Future<String?> Function()? textOverride;

  static final RegExp _urlLike = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');

  /// Пути скопированных файлов.
  ///
  /// 🔴 СПЕРВА ФАЙЛЫ, ПОТОМ КАРТИНКА. У файла, скопированного в Finder, в
  /// буфере лежит ещё и его ЗНАЧОК картинкой: прочитай мы сначала картинку,
  /// вместо файла ушла бы его иконка.
  ///
  /// 🔴 АДРЕС — НЕ ФАЙЛ. Скопированную ссылку система тоже отдаёт как URL, и
  /// путь в ней («https://site/etc/hosts» → «/etc/hosts») может совпасть с
  /// настоящим файлом. Если в буфере текстом лежит адрес, файлы не берём.
  static Future<List<String>> files() async {
    try {
      final text =
          (await (textOverride?.call() ?? Pasteboard.text))?.trim() ?? '';
      if (_urlLike.hasMatch(text) && !text.startsWith('file://')) {
        return const <String>[];
      }
      final raw = await (filesOverride?.call() ?? Pasteboard.files());
      return <String>[
        for (final path in raw)
          if (path.trim().isNotEmpty &&
              FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound)
            path,
      ];
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<Uint8List?> image() async {
    try {
      final bytes = await (imageOverride?.call() ?? Pasteboard.image);
      return (bytes == null || bytes.isEmpty) ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> text() async {
    try {
      return await (textOverride?.call() ?? Pasteboard.text);
    } catch (_) {
      return null;
    }
  }
}
