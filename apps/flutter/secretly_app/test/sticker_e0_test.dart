// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Э0 наборов стикеров (docs/TZ_STICKER_PACKS_2026-11-14.md §8).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/stickers/sticker_pack_lock.dart';
import 'package:secretly_app/sync/sticker_pack_protocol.dart';

/// Строковые литералы с кириллицей вне комментариев.
List<String> _cyrillicLiterals(String path) {
  final out = <String>[];
  final lines = File(path).readAsLinesSync();
  final literal = RegExp(r"'[^'\n]*[А-Яа-яЁё][^'\n]*'");
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimLeft();
    if (line.startsWith('//')) continue;
    final code = line.split(' // ').first;
    if (literal.hasMatch(code)) out.add('$path:${i + 1}: $line');
  }
  return out;
}

void main() {
  test('🔴 подписи стикеров на телефоне — только через ARB', () {
    // Раньше эти экраны показывали русский или английский прямо из кода, и
    // человек на украинском, испанском, португальском, французском и немецком
    // видел английский. Новая строка в коде вернула бы эту дыру.
    final offenders = [
      for (final f in const [
        'lib/ui/sticker_preview_screen.dart',
        'lib/ui/sticker_editor_screen.dart',
        'lib/ui/widgets/secretly_sticker_widgets.dart',
        'lib/ui/widgets/sticker_pack_access_picker.dart',
        'lib/ui/desktop/chat/sticker_pack_dialog.dart',
      ])
        ..._cyrillicLiterals(f),
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('лист набора в чате телефона не собирает подписи из кода', () {
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    final start = src.indexOf('class _StickerPackSheet');
    final end = src.indexOf('class _StickerBubble', start);
    final sheet = src.substring(start, end);
    expect(sheet.contains('isRu'), isFalse);
    expect(RegExp(r"'[^'\n]*[А-Яа-яЁё][^'\n]*'").hasMatch(sheet), isFalse);
  });

  group('предел набора', () {
    test('120 стикеров передаются целиком', () {
      expect(kStickerPackMaxStickers, 120);
      expect(
        kStickerPackMaxChunksPerRequest * kStickerPackMaxStickersPerChunk,
        greaterThanOrEqualTo(kStickerPackMaxStickers),
      );
    });

    test('в полный набор новый стикер не добавляется', () {
      final full = [for (var i = 0; i < 120; i++) 's$i'];
      expect(stickerPackCanAdd(full, 'new', max: 120), isFalse);
      expect(stickerPackCanAdd(full.take(119), 'new', max: 120), isTrue);
    });

    test('повторное сохранение того же стикера в полный набор — можно', () {
      final full = [for (var i = 0; i < 120; i++) 's$i'];
      expect(stickerPackCanAdd(full, 's7', max: 120), isTrue);
    });

    test('🔴 набор больше предела (старый) не ломается — просто не растёт', () {
      final big = [for (var i = 0; i < 200; i++) 's$i'];
      expect(stickerPackCanAdd(big, 's150', max: 120), isTrue);
      expect(stickerPackCanAdd(big, 'new', max: 120), isFalse);
    });
  });

  group('передача без ужатия', () {
    const both = StickerPackChunkSticker(
      stickerId: 's1',
      inlinePngB64: 'iVBORw0KGgo=',
      blobId: 'b1',
      fileKeyB64: 'k1',
    );

    test('стикер несёт и инлайн, и полноразмерную ссылку', () {
      final chunk = StickerPackChunk(
        requestId: 'r',
        packId: 'user:a:p',
        packTitle: 'Котики',
        totalCount: 1,
        seq: 0,
        done: true,
        stickers: const [both],
      );
      final back = parseStickerPackChunk(encodeStickerPackChunk(chunk))!;
      final s = back.stickers.single;
      expect(s.hasInline, isTrue);
      expect(s.hasBlob, isTrue);
    });

    test('🔴 инлайн в проводе непустой — его читают сборки до 08.08', () {
      // Их разбор требует непустой `inline_png_b64` и пропускает стикер без
      // него. Ссылка рядом им не мешает.
      expect(both.toJson()['inline_png_b64'], isNotEmpty);
    });
  });

  test('🔴 чужой закрытый стикер не уходит ни пересылкой, ни в «Избранное»', () {
    // «В избранное» для полученного стикера — это сохранение сообщения в
    // переписку с собой, то есть та же пересылка. На ПК оба пути идут через
    // `_forwardableOf`, на телефоне — через сбор черновика пересылки.
    final desktop = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    final fwd = desktop.indexOf('_forwardableOf(\n    List<MessageData>');
    expect(fwd, greaterThan(0));
    final body = desktop.substring(
      fwd,
      desktop.indexOf('return (allowed', fwd),
    );
    expect(body.contains('stickerPack?.closed'), isTrue);
    expect(
      RegExp(r'_saveMessages\([\s\S]*?_forwardableOf\(').hasMatch(desktop),
      isTrue,
    );
    final mobile = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(
      RegExp(
        r'payload is StickerEventV1 &&\s*payload\.packClosed &&\s*!widget\.controller\.isOwnDeviceId',
      ).hasMatch(mobile),
      isTrue,
    );
  });
}
