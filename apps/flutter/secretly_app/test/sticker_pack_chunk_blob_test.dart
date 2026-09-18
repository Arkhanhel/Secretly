// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/sync/sticker_pack_protocol.dart';

// Блоб-путь в порции набора (08.08.2026).
//
// 🔴 ЗАЧЕМ. Порция везла ТОЛЬКО пиксели инлайном, а вложить можно не всё:
// анимированные, Lottie и крупные стикеры МОЛЧА выбрасывались на стороне
// отправителя. Человек делился набором анимированных — получатель не получал
// ничего, и никто не узнавал почему.
//
// 🔴 СОВМЕСТИМОСТЬ — главное, что здесь закреплено. Старый разбор требует
// непустой `inline_png_b64`, поэтому стикер со ссылкой он пропускает — ровно как
// пропускал и раньше. Новые поля уехавшим сборкам не вредят, и это свойство
// нельзя потерять при следующей правке.

void main() {
  test('стикер с пикселями разбирается как раньше', () {
    final json = const StickerPackChunkSticker(
      stickerId: 's1',
      inlinePngB64: 'cGl4ZWxz',
    ).toJson();
    final parsed = StickerPackChunkSticker.fromJson(json)!;
    expect(parsed.hasInline, isTrue);
    expect(parsed.hasBlob, isFalse);
    expect(parsed.inlinePngB64, 'cGl4ZWxz');
  });

  test('🔴 стикер со ССЫЛКОЙ разбирается — этого раньше не было', () {
    final json = const StickerPackChunkSticker(
      stickerId: 's1',
      inlinePngB64: '',
      format: 'lottie',
      animated: true,
      blobId: 'blob-1',
      fileKeyB64: 'a2V5',
      accessTokenB64: 'dG9r',
      sizeBytes: 90000,
    ).toJson();
    final parsed = StickerPackChunkSticker.fromJson(json)!;
    expect(parsed.hasBlob, isTrue);
    expect(parsed.hasInline, isFalse);
    expect(parsed.animated, isTrue);
    expect(parsed.format, 'lottie');
    expect(parsed.blobId, 'blob-1');
    expect(parsed.accessTokenB64, 'dG9r');
  });

  test('🔴 форма для СТАРЫХ сборок сохранена', () {
    // `inline_png_b64` пишется всегда, даже пустым: так уехавшая сборка видит
    // знакомое поле, находит его пустым и пропускает стикер тем же путём, что и
    // до правки. Убери это — и старый разбор споткнётся на отсутствующем ключе.
    final json = const StickerPackChunkSticker(
      stickerId: 's1',
      inlinePngB64: '',
      blobId: 'blob-1',
      fileKeyB64: 'a2V5',
    ).toJson();
    expect(json.containsKey('inline_png_b64'), isTrue);
    expect(json['inline_png_b64'], '');
  });

  test('🔴 блоб БЕЗ ключа непригоден', () {
    // Расшифровать нечем: принять такой стикер значило бы записать в набор дыру,
    // которую человек примет за поломку приложения.
    expect(
      StickerPackChunkSticker.fromJson(<String, Object?>{
        'sticker_id': 's1',
        'inline_png_b64': '',
        'blob_id': 'blob-1',
      }),
      isNull,
    );
    expect(
      StickerPackChunkSticker.fromJson(<String, Object?>{
        'sticker_id': 's1',
        'inline_png_b64': '',
        'file_key_b64': 'a2V5',
      }),
      isNull,
    );
  });

  test('стикер без пикселей и без ссылки отвергается', () {
    expect(
      StickerPackChunkSticker.fromJson(<String, Object?>{
        'sticker_id': 's1',
        'inline_png_b64': '',
      }),
      isNull,
    );
  });

  test('без идентификатора отвергается', () {
    expect(
      StickerPackChunkSticker.fromJson(<String, Object?>{
        'inline_png_b64': 'cGl4ZWxz',
      }),
      isNull,
    );
  });

  test('порция с обоими видами стикеров переживает круг', () {
    final chunk = StickerPackChunk(
      requestId: 'r1',
      packId: 'user:P1:a',
      packTitle: 'Набор',
      totalCount: 2,
      seq: 0,
      done: true,
      stickers: const <StickerPackChunkSticker>[
        StickerPackChunkSticker(stickerId: 's1', inlinePngB64: 'cGl4ZWxz'),
        StickerPackChunkSticker(
          stickerId: 's2',
          inlinePngB64: '',
          animated: true,
          blobId: 'blob-2',
          fileKeyB64: 'a2V5',
        ),
      ],
    );
    final restored = parseStickerPackChunk(encodeStickerPackChunk(chunk))!;
    expect(restored.stickers, hasLength(2));
    expect(restored.stickers[0].hasInline, isTrue);
    expect(restored.stickers[1].hasBlob, isTrue);
    expect(restored.done, isTrue);
  });
}
