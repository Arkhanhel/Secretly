// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ТЗ E1, фаза 2: очистка метаданных снимков и роликов без перекодирования.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/media/media_metadata_scrub.dart';

Uint8List _seg(int marker, List<int> payload) => Uint8List.fromList([
  0xFF,
  marker,
  ((payload.length + 2) >> 8) & 0xFF,
  (payload.length + 2) & 0xFF,
  ...payload,
]);

List<int> _ascii(String s) => s.codeUnits;

bool _contains(Uint8List hay, String needle) {
  final n = needle.codeUnits;
  outer:
  for (var i = 0; i + n.length <= hay.length; i++) {
    for (var k = 0; k < n.length; k++) {
      if (hay[i + k] != n[k]) continue outer;
    }
    return true;
  }
  return false;
}

/// EXIF (little-endian) с Orientation=6 и «геометкой» — тегом GPS IFD и
/// строкой-маркером, чтобы было что искать в выходе.
List<int> _exifPayload() {
  final tiff = <int>[
    0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00, //
    0x02, 0x00,
    0x12, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00,
    0x25, 0x88, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x26, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    ..._ascii('GPSSECRET-55.75N-37.61E'),
  ];
  return [..._ascii('Exif\u0000\u0000'), ...tiff];
}

Uint8List _jpegWithMetadata({bool iccFirst = false}) {
  final base = img.encodeJpg(img.Image(width: 8, height: 6), quality: 90);
  // base: SOI, APP0 JFIF, …
  final out = BytesBuilder()..add([0xFF, 0xD8]);
  final icc = _seg(0xE2, [..._ascii('ICC_PROFILE\u0000'), 1, 1, 9, 9, 9]);
  if (iccFirst) out.add(icc);
  out
    ..add(_seg(0xE1, _exifPayload()))
    ..add(_seg(0xE1, _ascii('http://ns.adobe.com/xap/1.0/\u0000<x:xmpmeta GPSXMP/>')))
    ..add(_seg(0xE2, [..._ascii('MPF\u0000'), 0, 0]))
    ..add(_seg(0xED, _ascii('Photoshop 3.0\u0000IPTCCITY')))
    ..add(_seg(0xFE, _ascii('COMMENT-SERIAL-123')));
  if (!iccFirst) out.add(icc);
  out
    ..add(Uint8List.sublistView(base, 2))
    ..add(_ascii('LIVEPHOTO-MOVIE-TRAILER'));
  return out.takeBytes();
}

void main() {
  group('JPEG', () {
    for (final iccFirst in [false, true]) {
      test('drops EXIF/XMP/MPF/IPTC/comments/trailer, keeps orientation, ICC '
          'and pixels (iccFirst=$iccFirst)', () {
        final src = _jpegWithMetadata(iccFirst: iccFirst);
        final out = scrubImageMetadata(src)!;
        for (final secret in [
          'GPSSECRET',
          'GPSXMP',
          'MPF',
          'IPTCCITY',
          'COMMENT-SERIAL',
          'LIVEPHOTO',
        ]) {
          expect(_contains(out, secret), isFalse, reason: secret);
        }
        expect(_contains(out, 'ICC_PROFILE'), isTrue);
        expect(out.sublist(out.length - 2), [0xFF, 0xD9]);
        final decoded = img.decodeJpg(out)!;
        // Orientation=6 сохранён — декодер поворачивает кадр 8×6 в 6×8.
        expect((decoded.width, decoded.height), (6, 8));
        expect(img.decodeJpgExif(out)!.imageIfd['Orientation']!.toInt(), 6);
        // Пиксели не перекодированы: данные скана совпадают побайтно.
        final base = img.decodeJpg(src)!;
        expect(decoded.getPixel(3, 3), base.getPixel(3, 3));
      });
    }

    test('idempotent: a clean file comes back as the same object', () {
      final once = scrubImageMetadata(_jpegWithMetadata())!;
      expect(identical(scrubImageMetadata(once), once), isTrue);
      final plain = img.encodeJpg(img.Image(width: 4, height: 4));
      expect(identical(scrubImageMetadata(plain), plain), isTrue);
    });

    test('progressive JPEG survives', () {
      // Несколько сканов (DHT/SOS между ними) — разбор не должен споткнуться.
      final src = img.encodeJpg(img.Image(width: 16, height: 16));
      final withExif = BytesBuilder()
        ..add([0xFF, 0xD8])
        ..add(_seg(0xE1, _exifPayload()))
        ..add(Uint8List.sublistView(src, 2));
      final out = scrubImageMetadata(withExif.takeBytes())!;
      expect(img.decodeJpg(out), isNotNull);
    });

    test('truncated file is reported, not passed through', () {
      final src = _jpegWithMetadata();
      expect(scrubImageMetadata(Uint8List.sublistView(src, 0, 40)), isNull);
    });
  });

  group('PNG', () {
    Uint8List chunk(String type, List<int> data) {
      final c = BytesBuilder()
        ..add([
          (data.length >> 24) & 0xFF,
          (data.length >> 16) & 0xFF,
          (data.length >> 8) & 0xFF,
          data.length & 0xFF,
        ])
        ..add(_ascii(type))
        ..add(data)
        ..add([0, 0, 0, 0]); // CRC этим блокам не проверяется: их убирают
      return c.takeBytes();
    }

    test('drops text/XMP/eXIf/tIME, keeps image, stops at IEND', () {
      final base = img.encodePng(img.Image(width: 5, height: 3));
      final ihdrEnd = 8 + 25;
      final src = (BytesBuilder()
            ..add(Uint8List.sublistView(base, 0, ihdrEnd))
            ..add(chunk('tEXt', _ascii('Comment\u0000GPSPNG')))
            ..add(chunk('iTXt', _ascii('XML:com.adobe.xmp\u0000\u0000\u0000\u0000\u0000XMPPNG')))
            ..add(chunk('eXIf', _exifPayload().sublist(6)))
            ..add(chunk('tIME', [7, 234, 11, 14, 12, 0, 0]))
            ..add(Uint8List.sublistView(base, ihdrEnd))
            ..add(_ascii('TRAILER')))
          .takeBytes();
      final out = scrubImageMetadata(src)!;
      for (final s in ['GPSPNG', 'XMPPNG', 'GPSSECRET', 'tIME', 'TRAILER']) {
        expect(_contains(out, s), isFalse, reason: s);
      }
      final d = img.decodePng(out)!;
      expect((d.width, d.height), (5, 3));
      expect(identical(scrubImageMetadata(base), base), isTrue);
    });
  });

  group('WebP', () {
    List<int> chunk(String fourcc, List<int> data) => [
      ..._ascii(fourcc),
      data.length & 0xFF,
      (data.length >> 8) & 0xFF,
      (data.length >> 16) & 0xFF,
      (data.length >> 24) & 0xFF,
      ...data,
      if (data.length.isOdd) 0,
    ];

    test('drops EXIF and XMP chunks, clears VP8X flags, fixes RIFF size', () {
      final body = [
        ..._ascii('WEBP'),
        ...chunk('VP8X', [0x0C | 0x20, 0, 0, 0, 1, 0, 0, 1, 0, 0]),
        ...chunk('VP8L', [1, 2, 3, 4, 5]),
        ...chunk('EXIF', _exifPayload().sublist(6)),
        ...chunk('XMP ', _ascii('<x GPSWEBP/>')),
      ];
      final src = Uint8List.fromList([
        ..._ascii('RIFF'),
        body.length & 0xFF,
        (body.length >> 8) & 0xFF,
        0,
        0,
        ...body,
      ]);
      final out = scrubImageMetadata(src)!;
      expect(_contains(out, 'GPSSECRET'), isFalse);
      expect(_contains(out, 'GPSWEBP'), isFalse);
      final riff = out[4] | (out[5] << 8) | (out[6] << 16) | (out[7] << 24);
      expect(riff, out.length - 8);
      expect(out[20] & 0x0C, 0, reason: 'VP8X EXIF/XMP flags cleared');
      expect(out[20] & 0x20, 0x20, reason: 'other flags kept');
      expect(_contains(out, 'VP8L'), isTrue);
    });
  });

  group('GIF', () {
    test('drops comments and XMP, keeps the loop counter and frames', () {
      final anim = img.Image(width: 4, height: 4)
        ..addFrame(img.Image(width: 4, height: 4));
      final base = img.encodeGif(anim, repeat: 0);
      // Вставка комментария и XMP сразу после глобальной палитры.
      final flags = base[10];
      final headerEnd =
          13 + ((flags & 0x80) != 0 ? 3 * (1 << ((flags & 0x07) + 1)) : 0);
      final xmp = [
        0x21, 0xFF, 11, ..._ascii('XMP DataXMP'),
        9, ..._ascii('GPSGIF-XX'), 0,
      ];
      final comment = [0x21, 0xFE, 10, ..._ascii('SERIALGIF1'), 0];
      final src = Uint8List.fromList([
        ...base.sublist(0, headerEnd),
        ...xmp,
        ...comment,
        ...base.sublist(headerEnd),
      ]);
      final out = scrubImageMetadata(src)!;
      expect(_contains(out, 'GPSGIF'), isFalse);
      expect(_contains(out, 'SERIALGIF'), isFalse);
      final d = img.decodeGif(out)!;
      expect(d.numFrames, 2);
    });
  });

  group('HEIF', () {
    List<int> box(String type, List<int> body) {
      final n = body.length + 8;
      return [
        (n >> 24) & 0xFF,
        (n >> 16) & 0xFF,
        (n >> 8) & 0xFF,
        n & 0xFF,
        ..._ascii(type),
        ...body,
      ];
    }

    List<int> u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];
    List<int> u32(int v) => [
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ];

    test('zeroes Exif and XMP items in place, leaves the image item', () {
      final exif = [0, 0, 0, 0, ..._exifPayload().sublist(6)];
      final xmp = _ascii('<x:xmpmeta GPSHEIC/>');
      final image = _ascii('HEVC-IMAGE-DATA');
      final ftyp = box('ftyp', [..._ascii('heic'), 0, 0, 0, 0, ..._ascii('mif1heic')]);
      List<int> infe(int id, String type, [String ct = '']) => box('infe', [
        2, 0, 0, 0, ...u16(id), 0, 0, ..._ascii(type), 0,
        if (type == 'mime') ...[..._ascii(ct), 0],
      ]);
      final iinf = box('iinf', [
        0, 0, 0, 0, ...u16(3),
        ...infe(1, 'hvc1'),
        ...infe(2, 'Exif'),
        ...infe(3, 'mime', 'application/rdf+xml'),
      ]);
      // iloc v0: offset 4, length 4, base 0; позиции впишем после сборки.
      List<int> iloc(int o1, int o2, int o3) => box('iloc', [
        0, 0, 0, 0, 0x44, 0x00, ...u16(3),
        ...u16(1), 0, 0, ...u16(1), ...u32(o1), ...u32(image.length),
        ...u16(2), 0, 0, ...u16(1), ...u32(o2), ...u32(exif.length),
        ...u16(3), 0, 0, ...u16(1), ...u32(o3), ...u32(xmp.length),
      ]);
      final hdlr = box('hdlr', [0, 0, 0, 0, 0, 0, 0, 0, ..._ascii('pict'), ...List.filled(13, 0)]);
      List<int> meta(List<int> il) => box('meta', [0, 0, 0, 0, ...hdlr, ...iinf, ...il]);
      final metaLen = meta(iloc(0, 0, 0)).length;
      final mdatStart = ftyp.length + metaLen + 8;
      final o1 = mdatStart;
      final o2 = o1 + image.length;
      final o3 = o2 + exif.length;
      final file = Uint8List.fromList([
        ...ftyp,
        ...meta(iloc(o1, o2, o3)),
        ...box('mdat', [...image, ...exif, ...xmp]),
      ]);
      expect(sniffImageFormat(file), ScrubImageFormat.heif);
      final out = scrubImageMetadata(file)!;
      expect(out.length, file.length);
      expect(_contains(out, 'GPSSECRET'), isFalse);
      expect(_contains(out, 'GPSHEIC'), isFalse);
      expect(_contains(out, 'HEVC-IMAGE-DATA'), isTrue);
      expect(out.sublist(0, o1), file.sublist(0, o1));
    });
  });

  group('video', () {
    List<int> box(String type, List<int> body) {
      final n = body.length + 8;
      return [
        (n >> 24) & 0xFF,
        (n >> 16) & 0xFF,
        (n >> 8) & 0xFF,
        n & 0xFF,
        ..._ascii(type),
        ...body,
      ];
    }

    test('udta/meta in moov and tracks become free; size and media intact', () async {
      final bytes = Uint8List.fromList([
        ...box('ftyp', _ascii('isom\u0000\u0000\u0000\u0000isommp42')),
        ...box('moov', [
          ...box('mvhd', _ascii('MOVIE-HEADER')),
          ...box('udta', box('©xyz', _ascii('+55.7558+037.6173/'))),
          ...box('meta', _ascii('com.apple.quicktime.make Apple')),
          ...box('trak', [
            ...box('tkhd', _ascii('TRACK-HEADER')),
            ...box('udta', _ascii('TRACK-SERIAL')),
          ]),
        ]),
        ...box('mdat', _ascii('FRAMES')),
      ]);
      final dir = await Directory.systemTemp.createTemp('scrubvid');
      try {
        final src = File('${dir.path}/a.mp4')..writeAsBytesSync(bytes);
        final raf = await src.open();
        final patches = (await findVideoMetadataBoxes(raf))!;
        await raf.close();
        expect(patches.length, 3);
        final copy = await src.copy('${dir.path}/b.mp4');
        final w = await copy.open(mode: FileMode.append);
        await applyVideoMetadataPatches(w, patches);
        await w.close();
        final out = copy.readAsBytesSync();
        expect(out.length, bytes.length);
        expect(_contains(out, 'udta'), isFalse);
        expect(_contains(out, 'meta'), isFalse);
        for (final keep in ['MOVIE-HEADER', 'TRACK-HEADER', 'FRAMES', 'mvhd', 'tkhd']) {
          expect(_contains(out, keep), isTrue, reason: keep);
        }
        // Исходник не тронут.
        expect(src.readAsBytesSync(), bytes);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('not an ISO media file → null', () async {
      final dir = await Directory.systemTemp.createTemp('scrubvid');
      try {
        final f = File('${dir.path}/x.webm')
          ..writeAsBytesSync([0x1A, 0x45, 0xDF, 0xA3, 1, 2, 3, 4, 5, 6, 7, 8]);
        final raf = await f.open();
        expect(await findVideoMetadataBoxes(raf), isNull);
        await raf.close();
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  test('formats without metadata pass through; TIFF asks for re-encode', () {
    final bmp = img.encodeBmp(img.Image(width: 2, height: 2));
    expect(identical(scrubImageMetadata(bmp), bmp), isTrue);
    final tiff = img.encodeTiff(img.Image(width: 2, height: 2));
    expect(scrubImageMetadata(tiff), isNull);
    expect(imageFormatCarriesMetadata(sniffImageFormat(tiff)), isTrue);
  });
}
