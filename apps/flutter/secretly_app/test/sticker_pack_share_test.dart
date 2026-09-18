// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/sync/sticker_pack_protocol.dart';

void main() {
  group('StickerEventV1 pack metadata (wire)', () {
    test('round-trips the new pack fields', () {
      final ev = StickerEventV1(
        eventId: 'e1',
        packId: 'user:alice:doodles',
        packVersion: 1,
        stickerId: 's1',
        packTitle: 'Doodles',
        packStickerCount: 12,
        packOriginPid: 'alice',
      );
      final back = E2eEventV1.fromJson(ev.toJson()) as StickerEventV1;
      expect(back.packTitle, 'Doodles');
      expect(back.packStickerCount, 12);
      expect(back.packOriginPid, 'alice');
    });

    test('old wire JSON (no pack fields) still decodes with nulls', () {
      final old = <String, Object?>{
        'type': 'sticker',
        'event_id': 'e2',
        'pack_id': 'user:bob:set',
        'pack_version': 1,
        'sticker_id': 's2',
        'animated': false,
        'format': 'png',
      };
      final ev = E2eEventV1.fromJson(old) as StickerEventV1;
      expect(ev.packTitle, isNull);
      expect(ev.packStickerCount, isNull);
      expect(ev.packOriginPid, isNull);
    });

    test('null pack fields are omitted from the wire JSON', () {
      final ev = StickerEventV1(
        eventId: 'e3',
        packId: 'p',
        packVersion: 1,
        stickerId: 's',
      );
      final json = ev.toJson();
      expect(json.containsKey('pack_title'), isFalse);
      expect(json.containsKey('pack_sticker_count'), isFalse);
      expect(json.containsKey('pack_origin_pid'), isFalse);
    });
  });

  group('sticker_pack_protocol', () {
    test('request encode → parse round trip', () {
      const req = StickerPackRequest(
        requestId: 'r1',
        packId: 'user:alice:doodles',
      );
      final text = encodeStickerPackRequest(req);
      expect(isStickerPackCommand(text), isTrue);
      final back = parseStickerPackRequest(text);
      expect(back, isNotNull);
      expect(back!.requestId, 'r1');
      expect(back.packId, 'user:alice:doodles');
      // A chunk parser must NOT accept a request frame.
      expect(parseStickerPackChunk(text), isNull);
    });

    test('chunk encode → parse round trip preserves stickers + flags', () {
      const chunk = StickerPackChunk(
        requestId: 'r2',
        packId: 'user:alice:doodles',
        packTitle: 'Doodles',
        totalCount: 3,
        seq: 1,
        done: true,
        stickers: [
          StickerPackChunkSticker(
            stickerId: 's1',
            inlinePngB64: 'AAAA',
            emojiHint: '😀',
          ),
          StickerPackChunkSticker(stickerId: 's2', inlinePngB64: 'BBBB'),
        ],
      );
      final text = encodeStickerPackChunk(chunk);
      expect(isStickerPackCommand(text), isTrue);
      final back = parseStickerPackChunk(text);
      expect(back, isNotNull);
      expect(back!.requestId, 'r2');
      expect(back.packTitle, 'Doodles');
      expect(back.totalCount, 3);
      expect(back.seq, 1);
      expect(back.done, isTrue);
      expect(back.stickers.length, 2);
      expect(back.stickers.first.stickerId, 's1');
      expect(back.stickers.first.emojiHint, '😀');
    });

    test('isStickerPackCommand is false for unrelated text', () {
      expect(isStickerPackCommand('hello'), isFalse);
      expect(isStickerPackCommand('__secretly_history_req_v1__:abc'), isFalse);
    });

    test('garbage after a valid prefix parses to null, not a throw', () {
      expect(
        parseStickerPackRequest('$kStickerPackRequestCmdPrefix!!!notb64!!!'),
        isNull,
      );
    });

    test('PNG magic-byte validator', () {
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 1, 2,
      ]);
      final notPng = Uint8List.fromList(utf8.encode('not a png at all'));
      expect(stickerPackBytesLookLikePng(png), isTrue);
      expect(stickerPackBytesLookLikePng(notPng), isFalse);
      expect(stickerPackBytesLookLikePng(Uint8List.fromList([0x89])), isFalse);
    });
  });
}
