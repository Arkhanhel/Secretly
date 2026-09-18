// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// 🔴 ИМЯ ФАЙЛА — ОДНО НА ВЕСЬ ПУТЬ (14.08.2026).
///
/// ЖАЛОБА ВЛАДЕЛЬЦА: «отправил другу app-release.apk — у него скачивается .bin,
/// и при пересылке в другое приложение тоже .bin».
///
/// КОРЕНЬ. Имя файла у нас БЫЛО — отправитель кладёт его в `filename`, и чат его
/// даже показывает. Но при сохранении и пересылке имя строилось ЗАНОВО: вид
/// брался из mime (фото/видео/голосовое, а всё прочее — «music»), а расширение —
/// из имени ЛОКАЛЬНОГО кэша. Кэш же зовётся `<blobId><ext-по-mime>`, и таблица
/// mime→расширение знала два десятка типов, отвечая на всё остальное `.bin`.
///
/// Значит apk, zip, docx, xlsx, epub — всё превращалось в `music_….bin`.
///
/// 🔴 ПОЧЕМУ ЭТО НЕ ЛЕЧИТСЯ РАСШИРЕНИЕМ ТАБЛИЦЫ. Типов тысячи, и следующий
/// незнакомый снова станет `.bin`. Лечится порядком источников: сначала имя,
/// которое прислал отправитель, и только если его нет — догадка по mime.
///
/// Здесь живёт ЕДИНСТВЕННОЕ определение этого порядка. Всё, что сохраняет,
/// пересылает или отдаёт файл наружу, обязано звать эти функции, а не собирать
/// имя по-своему: три разных сборщика имени мы уже прошли, и разошлись они молча.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


/// Типы, которые мы умеем назвать по mime, когда имени файла нет.
///
/// Список НЕ претендует на полноту — полнота здесь недостижима, и именно
/// поэтому он не является главным источником имени.
const Map<String, String> _mimeToExt = <String, String>{
  // изображения
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'image/heic': '.heic',
  'image/heif': '.heif',
  'image/bmp': '.bmp',
  'image/tiff': '.tiff',
  'image/svg+xml': '.svg',
  'image/x-icon': '.ico',
  'image/avif': '.avif',
  // видео
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
  'video/x-matroska': '.mkv',
  'video/webm': '.webm',
  'video/x-msvideo': '.avi',
  'video/x-m4v': '.m4v',
  'video/3gpp': '.3gp',
  'video/mpeg': '.mpeg',
  'video/x-flv': '.flv',
  // звук
  'audio/mpeg': '.mp3',
  'audio/mp4': '.m4a',
  'audio/aac': '.aac',
  'audio/wav': '.wav',
  'audio/x-wav': '.wav',
  'audio/ogg': '.ogg',
  'audio/opus': '.opus',
  'audio/flac': '.flac',
  'audio/x-flac': '.flac',
  'audio/x-ms-wma': '.wma',
  'audio/amr': '.amr',
  'audio/midi': '.mid',
  // документы
  'application/pdf': '.pdf',
  'text/plain': '.txt',
  'text/csv': '.csv',
  'text/html': '.html',
  'text/markdown': '.md',
  'text/xml': '.xml',
  'application/xml': '.xml',
  'application/json': '.json',
  'application/rtf': '.rtf',
  'application/epub+zip': '.epub',
  'application/msword': '.doc',
  'application/vnd.ms-excel': '.xls',
  'application/vnd.ms-powerpoint': '.ppt',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      '.docx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      '.pptx',
  'application/vnd.oasis.opendocument.text': '.odt',
  'application/vnd.oasis.opendocument.spreadsheet': '.ods',
  // архивы и пакеты
  'application/zip': '.zip',
  'application/x-zip-compressed': '.zip',
  'application/gzip': '.gz',
  'application/x-tar': '.tar',
  'application/x-7z-compressed': '.7z',
  'application/vnd.rar': '.rar',
  'application/x-rar-compressed': '.rar',
  'application/vnd.android.package-archive': '.apk',
  'application/x-apple-diskimage': '.dmg',
  'application/x-msdownload': '.exe',
  'application/x-iso9660-image': '.iso',
  'application/vnd.debian.binary-package': '.deb',
  'application/x-rpm': '.rpm',
};

/// Обратный разбор: имя файла знает тип, которого не знает `mime`.
///
/// Нужен там, где тип обязателен, а пришёл пустым или обезличенным
/// (`application/octet-stream`) — например при записи в системные «Загрузки»
/// Android: с обезличенным типом система считает файл двоичным мусором, и APK
/// не предлагается к установке, а документ не открывается.
const Map<String, String> _extToMime = <String, String>{
  '.apk': 'application/vnd.android.package-archive',
  '.zip': 'application/zip',
  '.rar': 'application/vnd.rar',
  '.7z': 'application/x-7z-compressed',
  '.gz': 'application/gzip',
  '.tar': 'application/x-tar',
  '.pdf': 'application/pdf',
  '.txt': 'text/plain',
  '.csv': 'text/csv',
  '.json': 'application/json',
  '.xml': 'application/xml',
  '.html': 'text/html',
  '.htm': 'text/html',
  '.md': 'text/markdown',
  '.rtf': 'application/rtf',
  '.epub': 'application/epub+zip',
  '.doc': 'application/msword',
  '.docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.xls': 'application/vnd.ms-excel',
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '.ppt': 'application/vnd.ms-powerpoint',
  '.pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  '.odt': 'application/vnd.oasis.opendocument.text',
  '.ods': 'application/vnd.oasis.opendocument.spreadsheet',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.heic': 'image/heic',
  '.bmp': 'image/bmp',
  // 🔴 svg, tiff и avif СОЗНАТЕЛЬНО НЕ ЗДЕСЬ (14.08.2026).
  //
  // Эта таблица работает и на ОТПРАВКЕ: тип, выведенный из расширения, решает,
  // считать ли вложение изображением. Пузырь изображения рисуется средствами
  // Flutter, а он эти три формата не декодирует — файл, который раньше уходил
  // документом и показывался строкой с именем, стал бы «сломанной картинкой».
  //
  // Расширение по типу для них есть в `_mimeToExt` — там оно безвредно: оно
  // лишь называет файл, а не меняет способ его показа. Менять поведение, о
  // котором не просили и которое не измерено, эта правка права не имеет.
  '.mp4': 'video/mp4',
  '.mov': 'video/quicktime',
  '.mkv': 'video/x-matroska',
  '.webm': 'video/webm',
  '.avi': 'video/x-msvideo',
  '.m4v': 'video/x-m4v',
  '.3gp': 'video/3gpp',
  '.mp3': 'audio/mpeg',
  '.m4a': 'audio/mp4',
  '.aac': 'audio/aac',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.opus': 'audio/opus',
  '.flac': 'audio/flac',
  '.wma': 'audio/x-ms-wma',
  '.amr': 'audio/amr',
  '.dmg': 'application/x-apple-diskimage',
  '.exe': 'application/x-msdownload',
  '.iso': 'application/x-iso9660-image',
  '.deb': 'application/vnd.debian.binary-package',
};

/// Тип, который значит «я не знаю, что это».
const String kUnknownAttachmentMime = 'application/octet-stream';

bool _isMeaningfulMime(String mime) {
  final m = mime.trim().toLowerCase();
  if (m.isEmpty) return false;
  if (!m.contains('/')) return false;
  return m != kUnknownAttachmentMime && m != 'binary/octet-stream';
}

/// Обрезает имя до безопасного: никаких разделителей пути и управляющих
/// символов, ограниченная длина.
///
/// 🔴 Имя приходит ОТ СОБЕСЕДНИКА, то есть снаружи. `../` в нём — это запись
/// мимо папки назначения, а не косметика.
String sanitizeAttachmentFileName(String raw) {
  var name = raw.trim();
  if (name.isEmpty) return '';
  // Только последний сегмент: и '/', и '\' — разделители, откуда бы имя ни пришло.
  name = name.split(RegExp(r'[/\\]')).last;
  name = name.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '');
  // Символы, на которых спотыкаются файловые системы и MediaStore.
  name = name.replaceAll(RegExp(r'[<>:"|?*]'), '_');
  name = name.trim();
  // '.' и '..' именами файлов не являются.
  if (name == '.' || name == '..') return '';
  if (name.length > 180) {
    final ext = p.extension(name);
    final stem = name.substring(0, name.length - ext.length);
    final keep = 180 - ext.length;
    name = '${stem.substring(0, keep < 1 ? 1 : keep)}$ext';
  }
  return name;
}

/// Расширение (с точкой), которое файл обязан носить.
///
/// Порядок: имя от отправителя → таблица по mime → пусто.
String attachmentExtensionFor({String? filename, String? mime}) {
  final name = sanitizeAttachmentFileName(filename ?? '');
  final fromName = p.extension(name);
  // Расширение длиннее 12 символов — это не расширение, а часть имени.
  if (fromName.length > 1 && fromName.length <= 12) {
    return fromName.toLowerCase();
  }
  final m = (mime ?? '').trim().toLowerCase().split(';').first.trim();
  final mapped = _mimeToExt[m];
  if (mapped != null) return mapped;
  return '';
}

/// Тип файла, пригодный для системы: для «Загрузок», плашки выбора приложения
/// и установщика пакетов.
///
/// Порядок: осмысленный mime → тип по расширению имени → «не знаю».
String attachmentMimeFor({String? filename, String? mime}) {
  final m = (mime ?? '').trim().toLowerCase().split(';').first.trim();
  if (_isMeaningfulMime(m)) return m;
  final ext = attachmentExtensionFor(filename: filename, mime: null);
  final byExt = _extToMime[ext];
  if (byExt != null) return byExt;
  return kUnknownAttachmentMime;
}

/// Тип по имени файла — или `null`, если тип неизвестен.
///
/// 🔴 ОТДЕЛЬНАЯ ФУНКЦИЯ, А НЕ ПАРАМЕТР [attachmentMimeFor] (14.08.2026).
/// Разница между «не знаю» как `null` и как `application/octet-stream`
/// определяет поведение вызывающих: в местах вида
/// `_guessMime(path) ?? выбранныйСистемойТип` подстановка «не знаю» ЗАТЁРЛА БЫ
/// настоящий тип, пришедший от системного выбора файлов, — то есть правка,
/// которая чинит тип, испортила бы его в другом месте.
String? attachmentMimeForOrNull(String pathOrName) {
  final resolved = attachmentMimeFor(filename: pathOrName);
  return resolved == kUnknownAttachmentMime ? null : resolved;
}

/// Имя, под которым файл уходит наружу — в «Загрузки», в плашку выбора
/// приложения, в другое приложение.
///
/// Порядок: имя от отправителя (при необходимости дополненное расширением) →
/// осмысленное имя по виду вложения и времени.
///
/// [kindStem] — как назвать файл, у которого имени нет: `photo`, `video`,
/// `voice_message`… Для всего остального `file`, а НЕ `music`: документ,
/// архив и установочный пакет музыкой не являются, а именно так они и
/// назывались.
String attachmentExportFileName({
  String? filename,
  String? mime,
  required int createdAtMs,
  String kindStem = 'file',
}) {
  final ext = attachmentExtensionFor(filename: filename, mime: mime);
  final given = sanitizeAttachmentFileName(filename ?? '');
  if (given.isNotEmpty) {
    // Имя есть, но без расширения — дополняем, иначе система не поймёт тип.
    if (p.extension(given).isEmpty && ext.isNotEmpty) {
      return '$given$ext';
    }
    return given;
  }
  final dt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');
  return '${kindStem}_${dt.year}$mm${dd}_$hh$min$ss$ext';
}

/// Отдаёт файл, ГОТОВЫЙ уйти наружу: лежащий по пути, последний сегмент
/// которого — правильное имя.
///
/// 🔴 ЗАЧЕМ КОПИЯ. Локальный кэш зовётся по идентификатору блоба
/// (`<blobId>.bin`) — это служебное имя, и менять его нельзя: по нему кэш
/// находят и чистят. Но и отдавать наружу его нельзя: и системная плашка, и
/// принимающее приложение читают имя С ДИСКА, а не то, что мы объявили в
/// параметрах. Поэтому наружу уходит копия с правильным именем.
///
/// Если файл уже назван правильно — копия не делается.
Future<File> prepareAttachmentFileForExport({
  required File source,
  String? filename,
  String? mime,
  required int createdAtMs,
  String kindStem = 'file',
}) async {
  final desired = attachmentExportFileName(
    filename: filename,
    mime: mime,
    createdAtMs: createdAtMs,
    kindStem: kindStem,
  );
  if (desired.isEmpty) return source;
  if (p.basename(source.path) == desired) return source;

  final tmp = await getTemporaryDirectory();
  // Отдельная папка: имена здесь человеческие и потому могут совпасть у разных
  // вложений. Метка времени в пути разводит их, не попадая в имя.
  final root = Directory(p.join(tmp.path, 'secretly_share'));
  await _pruneExportCopies(root);
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final dir = Directory(p.join(root.path, stamp));
  await dir.create(recursive: true);
  final target = File(p.join(dir.path, desired));
  return source.copy(target.path);
}

/// Сколько держим копию, отданную наружу.
///
/// 🔴 УДАЛЯТЬ СРАЗУ ПОСЛЕ ВЫГРУЗКИ НЕЛЬЗЯ. Плашка возвращает управление раньше,
/// чем принимающее приложение дочитает файл: у 73-мегабайтного пакета это
/// секунды. Удаление «на возврате» дало бы обрыв передачи — дефект хуже того,
/// что мы чиним.
const Duration _exportCopyTtl = Duration(minutes: 10);

/// Убирает копии прошлых выгрузок.
///
/// Без этого каждая пересылка большого файла оставляла его полный дубликат:
/// система вычистит их когда-нибудь сама, но на забитом телефоне «когда-нибудь»
/// не ответ.
///
/// Никогда не бросает: неудача уборки не имеет права отменить саму выгрузку.
Future<void> _pruneExportCopies(Directory root) async {
  try {
    if (!await root.exists()) return;
    final cutoff = DateTime.now().subtract(_exportCopyTtl);
    await for (final entity in root.list(followLinks: false)) {
      try {
        final stat = await entity.stat();
        if (stat.modified.isAfter(cutoff)) continue;
        await entity.delete(recursive: true);
      } catch (_) {
        // Отдельная неудаляемая копия — не повод бросать остальные.
      }
    }
  } catch (_) {
    // ignore
  }
}
