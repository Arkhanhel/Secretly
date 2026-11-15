// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Закрытый набор стикеров: решение автора и размытые превью
/// (docs/TZ_STICKER_PACKS_2026-11-14.md §4).
///
/// 🔴 ЗАМОК — ОГРАНИЧЕНИЕ ИНТЕРФЕЙСА, А НЕ КРИПТОГРАФИЯ. Стикер, который автор
/// прислал, уже лежит у получателя расшифрованным. Закрытость гарантированно
/// защищает только то, что автор никому не присылал: устройство автора не
/// отдаёт такие стикеры никому, а вместо них отдаёт крошечные размытые копии,
/// из которых стикер не собрать.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'sticker_share_mode.dart';

/// Можно ли добавить стикер [stickerId] в набор, где уже лежат [existingIds].
/// Повторное сохранение того же стикера (тот же хэш) — не новый стикер.
bool stickerPackCanAdd(
  Iterable<String> existingIds,
  String stickerId, {
  required int max,
}) {
  var count = 0;
  for (final id in existingIds) {
    if (id == stickerId) return true;
    count++;
  }
  return count < max;
}

/// Сторона превью, px. Видно силуэт и цвет, использовать как стикер нельзя.
const int kStickerLockedPreviewPx = 24;

/// Отдаёт ли устройство автора набор собеседнику, который его попросил.
///
/// 🔴 Проверка НЕ за флагом: флаг управляет только тем, показан ли выбор
/// режима. Откат флага не имеет права открыть набор, который автор закрыл.
bool stickerPackServesPeers(StickerShareMode mode) =>
    mode != StickerShareMode.personal;

/// Делает размытое превью из файла стикера. `null` — не удалось (Lottie,
/// битый файл): клетка останется пустой с замком, и это честнее, чем сбой.
Uint8List? buildLockedStickerPreview(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final tall = decoded.height > decoded.width;
    final small = img.copyResize(
      decoded,
      width: tall ? null : kStickerLockedPreviewPx,
      height: tall ? kStickerLockedPreviewPx : null,
      interpolation: img.Interpolation.average,
    );
    final blurred = img.gaussianBlur(small, radius: 3);
    return Uint8List.fromList(img.encodePng(blurred, level: 9));
  } catch (_) {
    return null;
  }
}

/// Пачка превью за один заход — для `compute`, чтобы разбор картинок не
/// подвешивал интерфейс автора.
List<Uint8List?> buildLockedStickerPreviewsBatch(List<Uint8List> files) =>
    files.map(buildLockedStickerPreview).toList(growable: false);

/// Что получатель знает о закрытом наборе после отказа автора.
class StickerPackLockedView {
  const StickerPackLockedView({
    required this.title,
    required this.total,
    required this.previews,
  });

  final String title;

  /// Сколько стикеров в наборе у автора.
  final int total;

  /// Размытые превью (PNG около 24 px), не больше
  /// `kStickerPackLockedPreviewMax`.
  final List<Uint8List> previews;
}
