// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// На какой системе решаем, какой файл опасно открывать.
enum DesktopFileOs { windows, macos, other }

/// Подмена системы — для тестов обеих половин на любой машине сборки.
@visibleForTesting
DesktopFileOs? debugDesktopFileOsOverride;

DesktopFileOs get currentDesktopFileOs {
  final forced = debugDesktopFileOsOverride;
  if (forced != null) return forced;
  if (kIsWeb) return DesktopFileOs.other;
  if (Platform.isWindows) return DesktopFileOs.windows;
  if (Platform.isMacOS) return DesktopFileOs.macos;
  return DesktopFileOs.other;
}

/// Чем кончилось «Сохранить как…».
enum AttachmentSaveResult {
  /// Файл записан туда, куда попросили.
  saved,

  /// Человек закрыл диалог — это не ошибка и говорить о ней не нужно.
  cancelled,

  /// Файла нет на диске (ещё не подкачали или вложение битое).
  unavailable,

  /// Не удалось записать; текст в [AttachmentSaveOutcome.error].
  failed,
}

class AttachmentSaveOutcome {
  const AttachmentSaveOutcome(this.result, [this.error]);

  final AttachmentSaveResult result;
  final String? error;

  bool get isSaved => result == AttachmentSaveResult.saved;
}

/// «Сохранить как…» для вложения — ОДНА реализация на всё окно.
///
/// 🔴 Почему отдельным файлом. Сохранение жило внутри состояния просмотрщика
/// фотографий, и из ленты его было не достать: снимок можно было сохранить,
/// только открыв его на весь экран. Первый же второй вызов породил бы вторую
/// копию диалога — с другим заголовком, другим именем по умолчанию и,
/// вероятно, без `copy` в try.
///
/// Функция НИЧЕГО не показывает человеку: у просмотрщика свои всплывашки, у
/// ленты свои. Она отвечает, что случилось, и молчит.
Future<AttachmentSaveOutcome> saveAttachmentAs({
  required File? file,
  required String suggestedName,
  required String dialogTitle,
  FileType type = FileType.any,
}) async {
  if (file == null || !await file.exists()) {
    return const AttachmentSaveOutcome(AttachmentSaveResult.unavailable);
  }
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedName,
      type: type,
    );
    if (path == null) {
      return const AttachmentSaveOutcome(AttachmentSaveResult.cancelled);
    }
    await markFileFromInternet(await file.copy(path));
    return const AttachmentSaveOutcome(AttachmentSaveResult.saved);
  } catch (e) {
    return AttachmentSaveOutcome(AttachmentSaveResult.failed, e.toString());
  }
}

/// Имя по умолчанию для вложения.
///
/// Настоящее имя файла лучше любого придуманного: человек ищет снимок в
/// «Загрузках» по тому имени, под которым его прислали. Придумываем только
/// когда имени нет вовсе — тогда из идентификатора и типа.
String suggestedAttachmentFileName({
  required String? fileName,
  required String? mime,
  required String blobId,
  String fallbackPrefix = 'secretly',
}) {
  final name = stripFileNameDisguise(fileName ?? '').trim();
  if (name.isNotEmpty) return name;
  final m = (mime ?? '').toLowerCase();
  var ext = 'bin';
  const known = <String, String>{
    'image/png': 'png',
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'image/heic': 'heic',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'audio/opus': 'opus',
    'audio/ogg': 'ogg',
    'audio/mpeg': 'mp3',
    'application/pdf': 'pdf',
  };
  ext = known[m] ?? (m.startsWith('image/') ? 'jpg' : 'bin');
  final clean = blobId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
  final short = clean.length > 12 ? clean.substring(0, 12) : clean;
  return '$fallbackPrefix-$short.$ext';
}

/// Невидимые знаки, которыми маскируют имя файла.
///
/// 🔴 «счёт\u202Efdp.exe» на экране читается как «счётexe.pdf» (30.09.2026):
/// знак U+202E разворачивает хвост строки справа налево. Убираем управление
/// направлением текста (U+202A–U+202E, U+2066–U+2069, U+200E, U+200F,
/// U+061C) и прочие невидимки — нулевой пробел, соединитель слов, BOM.
/// Нулевые соединители U+200C/U+200D оставляем: без них ломаются персидское
/// письмо и эмодзи-последовательности.
final RegExp _fileNameDisguise = RegExp(
  '[\u200B\u200E\u200F\u061C\u202A-\u202E\u2060-\u2064\u2066-\u2069'
  '\u206A-\u206F\uFEFF\uFFF9-\uFFFB]',
);

/// Имя без маскирующих невидимых знаков — для показа и для записи.
String stripFileNameDisguise(String name) =>
    name.replaceAll(_fileNameDisguise, '');

/// Имя файла, пригодное для записи на диск.
///
/// 🔴 ИМЯ ПРИСЛАЛ ДРУГОЙ ЧЕЛОВЕК. «../../.ssh/authorized_keys» или имя с
/// двоеточием не должны вывести запись за пределы папки. Оставляем только
/// последнюю часть пути, без разделителей, управляющих и маскирующих знаков
/// ([stripFileNameDisguise]), без точки в начале (скрытый файл) и не длиннее
/// 120 знаков.
///
/// По ЭТОМУ имени [attachmentOpenRisk] решает, опасен ли файл: система
/// выберет программу по нему же.
String safeDownloadFileName(String name) {
  var clean = p.basename(stripFileNameDisguise(name).replaceAll('\\', '/'));
  clean = clean.replaceAll(RegExp(r'[/:*?"<>|\x00-\x1F\x7F-\x9F]'), '_').trim();
  while (clean.startsWith('.')) {
    clean = clean.substring(1);
  }
  if (clean.length > 120) {
    final ext = p.extension(clean);
    final keep = ext.length < 16 ? ext : '';
    clean = clean.substring(0, 120 - keep.length) + keep;
  }
  // Windows молча срезает точки и пробелы в конце имени: «счёт.exe.» ляжет на
  // диск как «счёт.exe». Срезаем сами — проверка обязана видеть то имя,
  // которое откроет система.
  clean = clean.replaceAll(RegExp(r'[. ]+$'), '');
  if (clean.isEmpty) clean = 'file';
  return clean;
}

/// Почему файл опасно открывать одним нажатием.
enum AttachmentRiskReason {
  /// Расширение запускает программу, сценарий, ярлык или макросы.
  executable,

  /// Расширения нет вовсе: чем открыть, система решит сама.
  noExtension,

  /// Отправитель выдал файл за снимок, звук, видео или PDF, а расширение у
  /// него незнакомое — так маскируют опасное.
  mismatch,
}

/// Чем опасен файл: [extension] — настоящее расширение с точкой в нижнем
/// регистре (пусто, если его нет).
class AttachmentOpenRisk {
  const AttachmentOpenRisk({required this.extension, required this.reason});

  final String extension;
  final AttachmentRiskReason reason;
}

/// Запускаемое на Windows: список блокируемых вложений Outlook, образы
/// дисков, пакеты приложений и документы с макросами.
const Set<String> _kWindowsRunnable = <String>{
  'ade', 'adp', 'app', 'application', 'appref-ms', 'appx', 'appxbundle',
  'asp', 'aspx', 'asx', 'bas', 'bat', 'bgi', 'cab', 'cdxml', 'cer', 'chm',
  'cmd', 'cnt', 'com', 'cpl', 'crt', 'csh', 'der', 'diagcab', 'exe', 'fxp',
  'gadget', 'grp', 'hlp', 'hpj', 'hta', 'htc', 'img', 'inf', 'ins', 'iso',
  'isp', 'its', 'jar', 'jnlp', 'js', 'jse', 'ksh', 'library-ms', 'lnk',
  'mad', 'maf', 'mag', 'mam', 'maq', 'mar', 'mas', 'mat', 'mau', 'mav',
  'maw', 'mcf', 'mda', 'mdb', 'mde', 'mdt', 'mdw', 'mdz', 'msc', 'msh',
  'msh1', 'msh1xml', 'msh2', 'msh2xml', 'mshxml', 'msi', 'msix',
  'msixbundle', 'msp', 'mst', 'msu', 'ops', 'osd', 'pcd', 'pif', 'pl', 'plg',
  'prf', 'prg', 'printerexport', 'ps1', 'ps1xml', 'ps2', 'ps2xml', 'psc1',
  'psc2', 'psd1', 'psdm1', 'psm1', 'pssc', 'pst', 'py', 'pyc', 'pyo', 'pyw',
  'pyz', 'pyzw', 'rdp', 'reg', 'scf', 'scr', 'sct', 'search-ms',
  'searchconnector-ms', 'settingcontent-ms', 'shb', 'shs', 'theme', 'tmp',
  'url', 'vb', 'vbe', 'vbp', 'vbs', 'vhd', 'vhdx', 'vsmacros', 'vsw',
  'webpnp', 'website', 'ws', 'wsb', 'wsc', 'wsf', 'wsh', 'xbap', 'xll',
  'xnk',
};

/// Запускаемое на macOS: программы, установщики, сценарии и «ярлыки»,
/// ведущие к ним.
const Set<String> _kMacRunnable = <String>{
  'action', 'app', 'applescript', 'bash', 'caction', 'command', 'csh',
  'fileloc', 'jar', 'ksh', 'mpkg', 'osax', 'pkg', 'pl', 'py', 'rb', 'scpt',
  'scptd', 'sh', 'terminal', 'tool', 'webarchive', 'workflow', 'zsh',
};

/// Прочие системы (Linux) — осторожнее обоих списков сразу.
final Set<String> _kAnyRunnable = <String>{
  ..._kWindowsRunnable,
  ..._kMacRunnable,
};

/// Документы Office с макросами — опасны на любой системе.
const Set<String> _kMacroDocuments = <String>{
  'docm', 'dotm', 'potm', 'ppam', 'ppa', 'ppsm', 'pptm', 'sldm', 'xla',
  'xlam', 'xlm', 'xlsm', 'xltm',
};

/// Знакомые расширения снимков, видео, звука и PDF. Если отправитель назвал
/// файл одним из этих типов, а расширение не отсюда — это подмена.
const Set<String> _kKnownMediaExtensions = <String>{
  // PDF
  'pdf',
  // снимки
  'apng', 'arw', 'avif', 'bmp', 'cr2', 'cr3', 'cur', 'dib', 'dng', 'gif',
  'heic', 'heif', 'hif', 'ico', 'jfif', 'jpe', 'jpeg', 'jpg', 'jxl', 'nef',
  'orf', 'pjp', 'pjpeg', 'png', 'psd', 'raf', 'rw2', 'srw', 'svg', 'svgz',
  'tga', 'tif', 'tiff', 'webp',
  // видео
  '3g2', '3gp', 'avi', 'divx', 'f4v', 'flv', 'm2ts', 'm2v', 'm4v', 'mkv',
  'mov', 'mp4', 'mpe', 'mpeg', 'mpg', 'mts', 'mxf', 'ogv', 'qt', 'ts',
  'vob', 'webm', 'wmv',
  // звук
  '3ga', 'aac', 'ac3', 'aif', 'aifc', 'aiff', 'alac', 'amr', 'ape', 'awb',
  'caf', 'flac', 'm4a', 'm4b', 'm4p', 'mid', 'midi', 'mka', 'mp2', 'mp3',
  'mpga', 'oga', 'ogg', 'opus', 'ra', 'wav', 'wave', 'weba', 'wma',
};

/// Выдаёт ли тип от отправителя файл за «безобидный» — снимок, видео, звук
/// или PDF.
bool _claimsHarmlessType(String mime) =>
    mime == 'application/pdf' ||
    mime == 'application/x-pdf' ||
    mime.startsWith('image/') ||
    mime.startsWith('video/') ||
    mime.startsWith('audio/');

/// 🔴 ОДНО НАЖАТИЕ НЕ ДОЛЖНО ЗАПУСКАТЬ ПРОГРАММУ (30.09.2026).
///
/// Имя и тип файла пишет ОТПРАВИТЕЛЬ. «счёт.pdf.lnk» с типом
/// `application/pdf` на Windows уходил системе как есть, и та запускала
/// ярлык: своего просмотра PDF там нет, и файл сразу отдавался наружу.
///
/// Решает ПОСЛЕДНЕЕ расширение того имени, под которым файл ляжет на диск
/// ([safeDownloadFileName]), — по нему система выберет, чем открыть. Тип от
/// отправителя расширения не отменяет: он лишь делает подозрительным файл,
/// который выдан за снимок или PDF, а назван по-другому.
///
/// Имени нет вовсе — его придумываем мы сами по типу ([suggestedAttachmentFileName]),
/// и опасного расширения там не бывает. `null` — файл обычный.
AttachmentOpenRisk? attachmentOpenRisk({
  required String? fileName,
  String? mime,
  DesktopFileOs? os,
}) {
  final given = stripFileNameDisguise(fileName ?? '').trim();
  if (given.isEmpty) return null;
  final onDisk = safeDownloadFileName(given);
  final dotted = p.extension(onDisk).toLowerCase();
  final ext = dotted.startsWith('.') ? dotted.substring(1) : dotted;
  if (ext.isEmpty) {
    return const AttachmentOpenRisk(
      extension: '',
      reason: AttachmentRiskReason.noExtension,
    );
  }
  final runnable = switch (os ?? currentDesktopFileOs) {
    DesktopFileOs.windows => _kWindowsRunnable,
    DesktopFileOs.macos => _kMacRunnable,
    DesktopFileOs.other => _kAnyRunnable,
  };
  if (runnable.contains(ext) || _kMacroDocuments.contains(ext)) {
    return AttachmentOpenRisk(
      extension: dotted,
      reason: AttachmentRiskReason.executable,
    );
  }
  final claimed = (mime ?? '').trim().toLowerCase();
  if (_claimsHarmlessType(claimed) && !_kKnownMediaExtensions.contains(ext)) {
    return AttachmentOpenRisk(
      extension: dotted,
      reason: AttachmentRiskReason.mismatch,
    );
  }
  return null;
}

/// Метка «файл из интернета» (Mark-of-the-Web) для Windows.
const String kZoneIdentifierInternet = '[ZoneTransfer]\r\nZoneId=3\r\n';

/// 🔴 МЕТКА «ИЗ ИНТЕРНЕТА» НА КАЖДОЙ РАСШИФРОВАННОЙ КОПИИ (Windows,
/// 30.09.2026).
///
/// Браузер помечает скачанное потоком `:Zone.Identifier`, и по этой метке
/// SmartScreen проверяет программу, а Office открывает документ в режиме
/// защищённого просмотра и не запускает макросы. Наши копии метки не несли:
/// для системы это были «свои» файлы, и обе защиты молчали.
///
/// На macOS то же делает песочница: каждый записанный приложением файл
/// получает `com.apple.quarantine` сам (проверено на кэше вложений:
/// «0082;Secretly»), поэтому там писать нечего.
///
/// Не вышло (флешка FAT32, сетевая папка без потоков) — файл остаётся как
/// был: метка лишь усиливает защиту и открытие не останавливает.
Future<void> markFileFromInternet(File file) async {
  if (currentDesktopFileOs != DesktopFileOs.windows) return;
  try {
    await File(
      '${file.path}:Zone.Identifier',
    ).writeAsString(kZoneIdentifierInternet, flush: true);
  } catch (_) {}
}

/// Копия вложения в «Загрузки/Secretly» — для «Показать в Finder».
///
/// Как в Telegram: скачанный файл лежит в «Загрузках» под своим именем. Сам
/// расшифрованный файл при этом остаётся в хранилище приложения, а копия
/// появляется только по нажатию. Если такой же файл (того же размера) там уже
/// лежит — берём его, а не плодим «(1)», «(2)».
Future<File> exportAttachmentToDownloads(
  File source,
  String fileName, {
  Directory? downloadsOverride,
}) async {
  final downloads =
      downloadsOverride ??
      await getDownloadsDirectory() ??
      Directory(p.join(Platform.environment['HOME'] ?? '', 'Downloads'));
  final dir = Directory(p.join(downloads.path, 'Secretly'));
  await dir.create(recursive: true);
  final safe = safeDownloadFileName(fileName);
  final stem = p.basenameWithoutExtension(safe);
  final ext = p.extension(safe);
  final sourceLength = await source.length();
  var target = File(p.join(dir.path, safe));
  var index = 1;
  while (await target.exists()) {
    if (await target.length() == sourceLength) {
      // Копию могла положить прежняя сборка, ещё без метки.
      await markFileFromInternet(target);
      return target;
    }
    target = File(p.join(dir.path, '$stem ($index)$ext'));
    index++;
  }
  final copy = await source.copy(target.path);
  await markFileFromInternet(copy);
  return copy;
}

/// Папка временных копий, которые открывает внешняя программа.
Directory attachmentOpenCopyDir({Directory? root}) => Directory(
  p.join((root ?? Directory.systemTemp).path, 'secretly_open'),
);

/// Временная копия вложения под НАСТОЯЩИМ именем — её и открывает система.
///
/// 🔴 ЗАЧЕМ КОПИЯ (17.09.2026). Из кэша файл уходил как есть, а там он лежит
/// под именем `<идентификатор>.bin`: система не понимала, чем его открыть, и
/// человек получал либо «выберите программу», либо ничего. Вдобавок чужая
/// программа получала путь ВНУТРЬ нашего расшифрованного кэша и могла
/// переписать файл, которым мы же и пользуемся.
///
/// Копия лежит в отдельной папке во временных файлах, по подпапке на вложение
/// (одинаковые имена от разных людей не затирают друг друга).
///
/// 🔴 КОПИЯ НЕ ЖИВЁТ ДОЛЬШЕ НАДОБНОСТИ (30.09.2026). Раньше их стирал только
/// следующий запуск — при окне, открытом неделями, расшифрованные документы
/// копились во временных файлах неделями. Теперь каждое открытие убирает
/// копии старше [kAttachmentOpenCopyMaxAge] ([pruneAttachmentOpenCopies]),
/// выход из приложения — все ([clearAttachmentOpenCopiesSync]), запуск — то,
/// что пережило сбой ([clearAttachmentOpenCopies]).
Future<File> attachmentOpenCopy({
  required File file,
  required String suggestedName,
  required String blobId,
  Directory? root,
}) async {
  await pruneAttachmentOpenCopies(root: root);
  final clean = blobId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
  final bucket = clean.isEmpty
      ? 'x'
      : (clean.length > 16 ? clean.substring(0, 16) : clean);
  final dir = Directory(
    p.join(attachmentOpenCopyDir(root: root).path, bucket),
  );
  await dir.create(recursive: true);
  var target = File(p.join(dir.path, safeDownloadFileName(suggestedName)));
  // Повторное открытие того же вложения не копирует его заново.
  if (!await target.exists() ||
      await target.length() != await file.length()) {
    target = await file.copy(target.path);
  }
  // Возраст копии — от последнего открытия: копирование сохраняет время
  // исходника, и свежая копия давно полученного файла выглядела бы старой.
  try {
    await target.setLastModified(DateTime.now());
  } catch (_) {}
  await markFileFromInternet(target);
  return target;
}

/// Сколько живёт временная копия, отданная внешней программе.
const Duration kAttachmentOpenCopyMaxAge = Duration(minutes: 10);

/// Стирает временные копии, открытые дольше [maxAge] назад.
///
/// Файл, который программа держит открытым (Windows не даёт его удалить),
/// остаётся до следующей уборки.
Future<void> pruneAttachmentOpenCopies({
  Directory? root,
  DateTime? now,
  Duration maxAge = kAttachmentOpenCopyMaxAge,
}) async {
  final dir = attachmentOpenCopyDir(root: root);
  final cutoff = (now ?? DateTime.now()).subtract(maxAge);
  try {
    if (!await dir.exists()) return;
    await for (final bucket in dir.list(followLinks: false)) {
      if (bucket is! Directory) continue;
      var alive = false;
      await for (final entry in bucket.list(followLinks: false)) {
        try {
          final stat = await entry.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entry.delete(recursive: true);
          } else {
            alive = true;
          }
        } catch (_) {
          alive = true;
        }
      }
      if (!alive) {
        try {
          await bucket.delete(recursive: true);
        } catch (_) {}
      }
    }
  } catch (_) {
    // Уборка — не повод отказать в открытии файла.
  }
}

/// Стирает временные копии, оставшиеся от прошлых запусков.
///
/// Это расшифрованные файлы: держать их дольше сеанса незачем.
Future<void> clearAttachmentOpenCopies({Directory? root}) async {
  final dir = attachmentOpenCopyDir(root: root);
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // Занятый файл (программа ещё открыта) — не повод падать при запуске.
  }
}

/// То же на выходе из приложения — синхронно: процесс уходит сразу следом за
/// окном, и отложенное удаление могло бы не успеть.
void clearAttachmentOpenCopiesSync({Directory? root}) {
  final dir = attachmentOpenCopyDir(root: root);
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } catch (_) {
    // Занятый файл остаётся до следующего запуска.
  }
}

/// Показать файл в Finder (Проводнике, файловом менеджере).
Future<void> revealInFileManager(String path) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', path]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [File(path).parent.path]);
  } else {
    await launchUrl(Uri.file(File(path).parent.path));
  }
}
