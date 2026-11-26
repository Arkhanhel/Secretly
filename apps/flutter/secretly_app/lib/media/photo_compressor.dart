// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Качество фото при отправке (SendFlow 24.11.2026): HD — длинная сторона
/// 2560, SD — 1280. Раскрытие сразу в нужный размер (системный декодер, с
/// поворотом EXIF), JPEG — в фоновом потоке. Метаданные (GPS и пр.) в новый
/// файл не переносятся. Ошибка или снимок уже меньше — исходный путь.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const int kPhotoSendMaxSideHd = 2560;
const int kPhotoSendMaxSideSd = 1280;

Uint8List _encodeJpeg((Uint8List, int, int, int) a) {
  // Прозрачные места (PNG) — на белый: у JPEG нет прозрачности, а
  // premultiplied-пиксели без этого стали бы чёрными.
  final px = a.$1;
  for (var i = 0; i + 3 < px.length; i += 4) {
    final alpha = px[i + 3];
    if (alpha == 255) continue;
    final k = 255 - alpha;
    px[i] = (px[i] + k).clamp(0, 255);
    px[i + 1] = (px[i + 1] + k).clamp(0, 255);
    px[i + 2] = (px[i + 2] + k).clamp(0, 255);
    px[i + 3] = 255;
  }
  final image = img.Image.fromBytes(
    width: a.$2,
    height: a.$3,
    bytes: a.$1.buffer,
    numChannels: 4,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: a.$4));
}

Future<String> downscalePhotoForSend(
  String path, {
  required int maxSide,
  int quality = 86,
}) async {
  final lower = path.toLowerCase();
  // GIF — анимация; не трогаем.
  if (lower.endsWith('.gif')) return path;
  ui.ImmutableBuffer? buf;
  ui.ImageDescriptor? desc;
  try {
    buf = await ui.ImmutableBuffer.fromFilePath(path);
    desc = await ui.ImageDescriptor.encoded(buf);
    final w = desc.width;
    final h = desc.height;
    final longest = w > h ? w : h;
    if (longest <= maxSide && (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))) {
      return path;
    }
    final scale = longest > maxSide ? maxSide / longest : 1.0;
    // Одна сторона — вторая по пропорции: так поворот EXIF (у которого
    // ширина и высота в заголовке могут быть «до поворота») не исказит
    // снимок, в худшем случае он выйдет чуть больше заданного.
    final codec = await desc.instantiateCodec(
      targetWidth: w >= h ? (w * scale).round() : null,
      targetHeight: w < h ? (h * scale).round() : null,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return path;
      final jpg = await compute(_encodeJpeg, (
        data.buffer.asUint8List(),
        image.width,
        image.height,
        quality,
      ));
      final dir = await getTemporaryDirectory();
      final out = File(
        p.join(
          dir.path,
          'psend_${DateTime.now().microsecondsSinceEpoch}.jpg',
        ),
      );
      await out.writeAsBytes(jpg, flush: true);
      return out.path;
    } finally {
      image.dispose();
      codec.dispose();
    }
  } catch (_) {
    return path;
  } finally {
    desc?.dispose();
    buf?.dispose();
  }
}
