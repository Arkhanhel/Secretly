// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ВЛОЖЕНИЕ К ПИСЬМУ В ПОДДЕРЖКУ: ЧТЕНИЕ, ПРЕДЕЛ РАЗМЕРА, СЖАТИЕ КАРТИНКИ.
///
/// 🔴 ЗАЧЕМ ОТДЕЛЬНЫМ ФАЙЛОМ. Половина ошибок, с которыми пишут в поддержку,
/// показывается снимком экрана. На телефоне его приложить можно, на
/// компьютере было нельзя — а именно там снимок делается одной клавишей.
/// Логика вынесена из панели, чтобы её проверяли тесты, а не глаз.
///
/// 🔴 ПРО ПРЕДЕЛ. Письмо уходит одним запечатанным свёртком, и вложение
/// внутри него. Слишком большой свёрток сервер не примет, поэтому предел
/// проверяется ЗДЕСЬ, до отправки: человек должен узнать про размер сразу,
/// а не после «не удалось отправить».
///
/// Снимок экрана с экрана Retina легко весит больше предела, поэтому
/// изображение сначала ужимается — как на телефоне, тем же способом. Файл,
/// который не картинка, ужать нечем: о таком честно говорим «не отправить».
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Предел на вложение. Совпадает с телефонным (`kSupportAttachmentMaxBytes`):
/// одно и то же письмо не должно уходить с телефона и не уходить с компьютера.
const int kDesktopSupportAttachmentMaxBytes = 5 * 1024 * 1024;

/// К чему стремимся, ужимая картинку. Меньше предела с запасом: свёрток несёт
/// ещё и текст, и служебные сведения, и разрастается при кодировании в base64.
const int kDesktopSupportImageTargetBytes = 1200 * 1024;

/// Почему файл не взяли.
enum DesktopSupportAttachmentProblem {
  /// Файл не прочитать: его нет, нет прав, диск отсоединили.
  unreadable,

  /// Больше предела, и ужать нечем.
  tooLarge,
}

@immutable
class DesktopSupportAttachment {
  const DesktopSupportAttachment({
    required this.name,
    required this.mime,
    required this.bytes,
    required this.originalBytes,
    required this.shrunk,
  });

  final String name;
  final String mime;
  final Uint8List bytes;

  /// Сколько весил файл на диске — чтобы сказать «ужали», а не молча подменить.
  final int originalBytes;
  final bool shrunk;

  bool get isImage => mime.startsWith('image/');
}

@immutable
class DesktopSupportAttachmentResult {
  const DesktopSupportAttachmentResult.ready(DesktopSupportAttachment this.file)
      : problem = null;
  const DesktopSupportAttachmentResult.failed(
    DesktopSupportAttachmentProblem this.problem,
  ) : file = null;

  final DesktopSupportAttachment? file;
  final DesktopSupportAttachmentProblem? problem;

  bool get ok => file != null;
}

/// Тип файла по расширению.
///
/// Берём по имени, а не гадаем по содержимому: поддержке важно, чем открыть, и
/// ошибиться здесь безопаснее, чем тянуть в приложение распознавание форматов.
String desktopSupportMimeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
    case 'heif':
      return 'image/heic';
    case 'pdf':
      return 'application/pdf';
    case 'txt':
    case 'log':
      return 'text/plain';
    case 'json':
      return 'application/json';
    case 'zip':
      return 'application/zip';
    default:
      return 'application/octet-stream';
  }
}

/// Ужимает картинку до [targetBytes], насколько выходит. `null` — не картинка
/// либо формат нечем разобрать (такой, как HEIC, читает только система).
///
/// Лестница та же, что на телефоне: сперва сторона до 2048, затем качество
/// вниз по ступеням. Работает без ввода-вывода, поэтому её и гоняют тесты.
Uint8List? shrinkDesktopSupportImage(
  Uint8List input, {
  int targetBytes = kDesktopSupportImageTargetBytes,
}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  var im = decoded;
  if (im.width >= im.height && im.width > 2048) {
    im = img.copyResize(im, width: 2048);
  } else if (im.height > im.width && im.height > 2048) {
    im = img.copyResize(im, height: 2048);
  }
  for (final q in <int>[86, 76, 64, 52, 40]) {
    final out = img.encodeJpg(im, quality: q);
    if (out.length <= targetBytes) return Uint8List.fromList(out);
  }
  // 🔴 ТОЛЬКО ВНИЗ. Здесь напрашивается «ужать до 1280 точек», но картинка
  // может быть УЖЕ меньше — и тогда её растянут, а файл станет больше, чем
  // был. Поэтому уменьшаем от текущей ширины и оставляем самую лёгкую из
  // попыток, даже если до цели не дотянули: это честнее отказа.
  var width = im.width;
  var best = Uint8List.fromList(img.encodeJpg(im, quality: 45));
  while (width > 320 && best.length > targetBytes) {
    width = (width * 0.7).round();
    final out = Uint8List.fromList(
      img.encodeJpg(img.copyResize(im, width: width), quality: 45),
    );
    if (out.length < best.length) best = out;
  }
  return best;
}

typedef _ShrinkRequest = ({Uint8List bytes, int targetBytes});

Uint8List? _shrinkInIsolate(_ShrinkRequest req) =>
    shrinkDesktopSupportImage(req.bytes, targetBytes: req.targetBytes);

/// Готовит выбранный файл к отправке.
///
/// Разбор картинки уходит в отдельный поток: снимок экрана на 12 мегапикселей
/// разбирается заметно дольше кадра, и окно на это время замирало бы вместе с
/// кружком «готовим».
Future<DesktopSupportAttachmentResult> prepareDesktopSupportAttachment(
  String path, {
  int maxBytes = kDesktopSupportAttachmentMaxBytes,
  int targetBytes = kDesktopSupportImageTargetBytes,
}) async {
  final file = File(path);
  Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    return const DesktopSupportAttachmentResult.failed(
      DesktopSupportAttachmentProblem.unreadable,
    );
  }
  if (bytes.isEmpty) {
    return const DesktopSupportAttachmentResult.failed(
      DesktopSupportAttachmentProblem.unreadable,
    );
  }
  final name = _baseName(path);
  final mime = desktopSupportMimeFor(name);
  final original = bytes.length;
  if (original <= maxBytes) {
    return DesktopSupportAttachmentResult.ready(
      DesktopSupportAttachment(
        name: name,
        mime: mime,
        bytes: bytes,
        originalBytes: original,
        shrunk: false,
      ),
    );
  }
  if (!mime.startsWith('image/')) {
    return const DesktopSupportAttachmentResult.failed(
      DesktopSupportAttachmentProblem.tooLarge,
    );
  }
  final shrunk = await compute(
    _shrinkInIsolate,
    (bytes: bytes, targetBytes: targetBytes),
  );
  if (shrunk == null || shrunk.length > maxBytes) {
    return const DesktopSupportAttachmentResult.failed(
      DesktopSupportAttachmentProblem.tooLarge,
    );
  }
  return DesktopSupportAttachmentResult.ready(
    DesktopSupportAttachment(
      name: _jpegName(name),
      mime: 'image/jpeg',
      bytes: shrunk,
      originalBytes: original,
      shrunk: true,
    ),
  );
}

String _baseName(String path) {
  final cut = path.lastIndexOf(RegExp(r'[/\\]'));
  final name = cut < 0 ? path : path.substring(cut + 1);
  return name.trim().isEmpty ? 'file' : name.trim();
}

/// Ужатое ушло в JPEG — имя должно говорить правду о содержимом.
String _jpegName(String name) {
  final dot = name.lastIndexOf('.');
  final stem = dot <= 0 ? name : name.substring(0, dot);
  return '$stem.jpg';
}
