// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui' as ui;

/// М3 (разбор медиа 22.11.2026): размеры снимка по ЗАГОЛОВКУ файла.
///
/// `ImageDescriptor` читает только заголовок и пикселей не раскодирует —
/// миллисекунды даже для снимка в 12 Мп. Тем же способом отправитель ставит
/// размеры в сообщение (`_imagePixelDimsFromBytes` в контроллере), поэтому
/// заготовка в очереди и готовый пузырь получают одну и ту же пропорцию.
///
/// `null` — не картинка, файла нет или формат не распознан.
Future<({int width, int height})?> readImageHeaderDims(String path) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final w = descriptor.width;
    final h = descriptor.height;
    if (w > 0 && h > 0) return (width: w, height: h);
    return null;
  } catch (_) {
    return null;
  } finally {
    try {
      descriptor?.dispose();
    } catch (_) {}
    try {
      buffer?.dispose();
    } catch (_) {}
  }
}
