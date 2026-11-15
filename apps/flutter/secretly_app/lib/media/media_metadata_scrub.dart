// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// ТЗ E1, фаза 2 (14.11.2026): очистка метаданных снимков и роликов перед
// отправкой.
//
// Пиксели и кадры не перекодируются: убираются только служебные блоки
// контейнера. Поэтому размеры, миниатюра и качество остаются прежними, а
// получатель любой сборки открывает файл как раньше: для него это обычный
// JPEG, PNG, WebP, GIF, HEIC или MP4/MOV.
//
// Что убирается:
// - JPEG: все APP1 (EXIF целиком, XMP, расширенный XMP), APP2 кроме ICC
//   (MPF, FlashPix), APP3–APP13, APP15, комментарии, всё после конца картинки
//   (ролик «живого фото», вторые кадры MPF). Из EXIF остаётся один тег
//   Orientation, иначе портрет у получателя ляжет набок.
// - PNG: tEXt, zTXt, iTXt (там XMP), eXIf, tIME и любые чужие необязательные
//   блоки; всё после IEND.
// - WebP: блоки EXIF и XMP, флаги о них в VP8X.
// - GIF: комментарии и расширения приложений (XMP), кроме счётчика повторов.
// - HEIC/HEIF/AVIF: содержимое элементов Exif и XMP затирается на месте —
//   смещения в файле не меняются, поворот задают свойства irot/imir.
// - MP4/MOV/3GP: блоки udta и meta в moov и в дорожках, XMP-блок uuid
//   становятся блоками free (их пропускает любой проигрыватель). Там лежат
//   место съёмки, модель телефона и дата.
//
// Функции чистые и не бросают исключений: при разборе, который не сошёлся,
// возвращается `null`, и вызывающий сам решает, что делать (см.
// `AppController._scrubOutgoingMedia`: перекодирование или отказ отправки,
// но никогда не исходные байты).
import 'dart:io';
import 'dart:typed_data';

/// Формат по первым байтам — расширению и MIME не доверяем.
enum ScrubImageFormat { jpeg, png, webp, gif, heif, tiff, other }

ScrubImageFormat sniffImageFormat(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return ScrubImageFormat.jpeg;
  }
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A) {
    return ScrubImageFormat.png;
  }
  if (b.length >= 12 &&
      _ascii(b, 0, 4) == 'RIFF' &&
      _ascii(b, 8, 4) == 'WEBP') {
    return ScrubImageFormat.webp;
  }
  if (b.length >= 6 && _ascii(b, 0, 3) == 'GIF') return ScrubImageFormat.gif;
  if (b.length >= 4 &&
      ((b[0] == 0x49 && b[1] == 0x49 && b[2] == 0x2A && b[3] == 0x00) ||
          (b[0] == 0x4D && b[1] == 0x4D && b[2] == 0x00 && b[3] == 0x2A))) {
    return ScrubImageFormat.tiff;
  }
  if (b.length >= 12 && _ascii(b, 4, 4) == 'ftyp') {
    final size = _u32be(b, 0);
    final end = (size >= 16 && size <= b.length) ? size : 12;
    for (var o = 8; o + 4 <= end; o += 4) {
      if (o == 12) continue; // minor_version
      if (_heifBrands.contains(_ascii(b, o, 4))) return ScrubImageFormat.heif;
    }
  }
  return ScrubImageFormat.other;
}

const Set<String> _heifBrands = {
  'heic', 'heix', 'heim', 'heis', 'hevc', 'hevx', 'hevm', 'hevs', //
  'mif1', 'msf1', 'mif2', 'avif', 'avis', 'avio',
};

/// Очищенные байты снимка; тот же объект, если чистить нечего; `null`, если
/// файл не разобрался (повреждён или формат не тот, что в заголовке).
///
/// Для форматов без метаданных (BMP, ICO…) возвращает исходные байты.
/// Для TIFF — `null`: в нём GPS лежит в той же структуре, что и картинка,
/// надёжно его можно убрать только перекодированием.
Uint8List? scrubImageMetadata(Uint8List bytes) {
  try {
    switch (sniffImageFormat(bytes)) {
      case ScrubImageFormat.jpeg:
        return _scrubJpeg(bytes);
      case ScrubImageFormat.png:
        return _scrubPng(bytes);
      case ScrubImageFormat.webp:
        return _scrubWebp(bytes);
      case ScrubImageFormat.gif:
        return _scrubGif(bytes);
      case ScrubImageFormat.heif:
        return _scrubHeif(bytes);
      case ScrubImageFormat.tiff:
        return null;
      case ScrubImageFormat.other:
        return bytes;
    }
  } catch (_) {
    return null;
  }
}

/// Может ли формат нести геометку или данные устройства (нужен ли отказ,
/// если очистка и перекодирование не удались).
bool imageFormatCarriesMetadata(ScrubImageFormat f) =>
    f != ScrubImageFormat.other;

// ───────────────────────────── JPEG ─────────────────────────────

Uint8List? _scrubJpeg(Uint8List b) {
  final out = BytesBuilder(copy: false);
  out.add(const [0xFF, 0xD8]);
  var i = 2;
  var changed = false;
  var exifWritten = false;
  while (true) {
    if (i >= b.length) return null; // нет конца картинки
    if (b[i] != 0xFF) return null;
    // Заполняющие 0xFF перед маркером.
    while (i < b.length && b[i] == 0xFF) {
      i++;
    }
    if (i >= b.length) return null;
    final marker = b[i];
    i++;
    if (marker == 0xD9) {
      out.add(const [0xFF, 0xD9]);
      if (i < b.length) changed = true; // хвост после конца картинки
      break;
    }
    if ((marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
      out.add([0xFF, marker]);
      continue;
    }
    if (i + 2 > b.length) return null;
    final len = (b[i] << 8) | b[i + 1];
    if (len < 2 || i + len > b.length) return null;
    final segStart = i - 2;
    final segEnd = i + len;
    final payloadStart = i + 2;
    final payloadLen = len - 2;
    if (marker == 0xDA) {
      // Начало скана: заголовок, затем данные до следующего маркера.
      out.add(Uint8List.sublistView(b, segStart, segEnd));
      var j = segEnd;
      while (true) {
        if (j + 1 >= b.length) return null;
        if (b[j] == 0xFF) {
          final n = b[j + 1];
          if (n == 0x00 || (n >= 0xD0 && n <= 0xD7)) {
            j += 2;
            continue;
          }
          if (n == 0xFF) {
            j += 1;
            continue;
          }
          break; // настоящий маркер
        }
        j++;
      }
      out.add(Uint8List.sublistView(b, segEnd, j));
      i = j;
      continue;
    }
    var keep = true;
    if (marker == 0xE0) {
      keep = _startsWith(b, payloadStart, payloadLen, 'JFIF\u0000');
    } else if (marker == 0xE1) {
      keep = false;
      if (!exifWritten && _startsWith(b, payloadStart, payloadLen, 'Exif\u0000\u0000')) {
        final orientation = _tiffOrientation(
          b,
          payloadStart + 6,
          payloadLen - 6,
        );
        exifWritten = true;
        if (orientation != null) {
          final tiff = minimalOrientationTiff(orientation);
          final seg = BytesBuilder(copy: false)
            ..add(const [0xFF, 0xE1])
            ..add(_u16beBytes(2 + 6 + tiff.length))
            ..add('Exif\u0000\u0000'.codeUnits)
            ..add(tiff);
          final built = seg.takeBytes();
          out.add(built);
          if (!_sameBytes(b, segStart, segEnd, built)) changed = true;
          i = segEnd;
          continue;
        }
      }
    } else if (marker == 0xE2) {
      keep = _startsWith(b, payloadStart, payloadLen, 'ICC_PROFILE\u0000');
    } else if (marker == 0xEE) {
      keep = _startsWith(b, payloadStart, payloadLen, 'Adobe');
    } else if (marker >= 0xE3 && marker <= 0xEF) {
      keep = false;
    } else if (marker == 0xFE) {
      keep = false;
    }
    if (keep) {
      out.add(Uint8List.sublistView(b, segStart, segEnd));
    } else {
      changed = true;
    }
    i = segEnd;
  }
  return changed ? out.takeBytes() : b;
}

/// Значение Orientation (1–8) из TIFF-структуры EXIF, иначе `null`.
int? _tiffOrientation(Uint8List b, int start, int len) {
  if (len < 8 || start + len > b.length) return null;
  final le = b[start] == 0x49 && b[start + 1] == 0x49;
  final be = b[start] == 0x4D && b[start + 1] == 0x4D;
  if (!le && !be) return null;
  int u16(int o) => le ? (b[o] | (b[o + 1] << 8)) : ((b[o] << 8) | b[o + 1]);
  int u32(int o) => le
      ? (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24))
      : ((b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]);
  final ifd = u32(start + 4);
  if (ifd < 8 || ifd + 2 > len) return null;
  final count = u16(start + ifd);
  for (var k = 0; k < count; k++) {
    final e = start + ifd + 2 + k * 12;
    if (e + 12 > start + len) return null;
    if (u16(e) == 0x0112) {
      final v = u16(e + 8);
      return (v >= 1 && v <= 8) ? v : null;
    }
  }
  return null;
}

/// TIFF с одним тегом Orientation (big-endian).
Uint8List minimalOrientationTiff(int orientation) => Uint8List.fromList([
  0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // заголовок, IFD0 по 8
  0x00, 0x01, // одна запись
  0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, // Orientation, SHORT, 1
  (orientation >> 8) & 0xFF, orientation & 0xFF, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, // следующего IFD нет
]);

// ───────────────────────────── PNG ─────────────────────────────

const Set<String> _pngKeep = {
  'IHDR', 'PLTE', 'IDAT', 'IEND', 'tRNS', 'gAMA', 'cHRM', 'sRGB', 'iCCP', //
  'sBIT', 'bKGD', 'hIST', 'pHYs', 'sPLT', 'acTL', 'fcTL', 'fdAT', 'cICP',
  'mDCV', 'cLLI',
};

Uint8List? _scrubPng(Uint8List b) {
  final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(b, 0, 8));
  var i = 8;
  var changed = false;
  var sawEnd = false;
  while (i + 12 <= b.length) {
    final len = _u32be(b, i);
    final type = _ascii(b, i + 4, 4);
    final end = i + 12 + len;
    if (len > b.length || end > b.length) return null;
    // Неизвестный обязательный блок (заглавная первая буква) оставляем —
    // без него картинка не откроется; необязательные чужие — убираем.
    final critical = (b[i + 4] & 0x20) == 0;
    if (_pngKeep.contains(type) || critical) {
      out.add(Uint8List.sublistView(b, i, end));
    } else {
      changed = true;
    }
    i = end;
    if (type == 'IEND') {
      sawEnd = true;
      break;
    }
  }
  if (!sawEnd) return null;
  if (i < b.length) changed = true;
  return changed ? out.takeBytes() : b;
}

// ───────────────────────────── WebP ─────────────────────────────

Uint8List? _scrubWebp(Uint8List b) {
  final riffSize = _u32le(b, 4);
  final end = 8 + riffSize;
  if (end > b.length || riffSize < 4) return null;
  final chunks = BytesBuilder(copy: false);
  var i = 12;
  var changed = end < b.length;
  int? vp8xAt; // позиция флагов VP8X в выходе
  var outLen = 0;
  while (i + 8 <= end) {
    final fourcc = _ascii(b, i, 4);
    final size = _u32le(b, i + 4);
    final padded = size + (size & 1);
    final chunkEnd = i + 8 + padded;
    if (chunkEnd > end + (size & 1)) return null;
    final realEnd = chunkEnd > end ? end : chunkEnd;
    if (fourcc == 'EXIF' || fourcc == 'XMP ') {
      changed = true;
    } else {
      if (fourcc == 'VP8X') vp8xAt = outLen + 8;
      final piece = Uint8List.sublistView(b, i, realEnd);
      chunks.add(piece);
      outLen += piece.length;
    }
    i = chunkEnd;
  }
  if (!changed) return b;
  final body = chunks.takeBytes();
  if (vp8xAt != null && vp8xAt < body.length) {
    body[vp8xAt] = body[vp8xAt] & ~0x0C; // без флагов EXIF (0x08) и XMP (0x04)
  }
  final out = BytesBuilder(copy: false)
    ..add('RIFF'.codeUnits)
    ..add(_u32leBytes(4 + body.length))
    ..add('WEBP'.codeUnits)
    ..add(body);
  return out.takeBytes();
}

// ───────────────────────────── GIF ─────────────────────────────

Uint8List? _scrubGif(Uint8List b) {
  if (b.length < 13) return null;
  final out = BytesBuilder(copy: false);
  var i = 13;
  final flags = b[10];
  if (flags & 0x80 != 0) i += 3 * (1 << ((flags & 0x07) + 1));
  if (i > b.length) return null;
  out.add(Uint8List.sublistView(b, 0, i));
  var changed = false;
  int skipSubBlocks(int j) {
    while (true) {
      if (j >= b.length) return -1;
      final n = b[j];
      j += 1 + n;
      if (n == 0) return j;
    }
  }

  while (true) {
    if (i >= b.length) return null;
    final intro = b[i];
    if (intro == 0x3B) {
      out.add(const [0x3B]);
      if (i + 1 < b.length) changed = true;
      break;
    }
    if (intro == 0x21) {
      if (i + 2 > b.length) return null;
      final label = b[i + 1];
      final next = skipSubBlocks(i + 2);
      if (next < 0) return null;
      var keep = true;
      if (label == 0xFE) {
        keep = false; // комментарий
      } else if (label == 0xFF) {
        // Расширение приложения: оставляем только счётчик повторов.
        final id = (i + 3 + 11 <= b.length && b[i + 2] == 11)
            ? _ascii(b, i + 3, 11)
            : '';
        keep = id == 'NETSCAPE2.0' || id == 'ANIMEXTS1.0';
      }
      if (keep) {
        out.add(Uint8List.sublistView(b, i, next));
      } else {
        changed = true;
      }
      i = next;
      continue;
    }
    if (intro == 0x2C) {
      var j = i + 10;
      if (j > b.length) return null;
      final lf = b[i + 9];
      if (lf & 0x80 != 0) j += 3 * (1 << ((lf & 0x07) + 1));
      j += 1; // минимальный размер кода LZW
      final next = skipSubBlocks(j);
      if (next < 0) return null;
      out.add(Uint8List.sublistView(b, i, next));
      i = next;
      continue;
    }
    return null;
  }
  return changed ? out.takeBytes() : b;
}

// ───────────────────────────── HEIF ─────────────────────────────

class _Box {
  _Box(this.start, this.headerLen, this.end, this.type);
  final int start;
  final int headerLen;
  final int end;
  final String type;
  int get body => start + headerLen;
}

List<_Box>? _boxes(Uint8List b, int from, int to) {
  final list = <_Box>[];
  var i = from;
  while (i + 8 <= to) {
    var size = _u32be(b, i);
    final type = _ascii(b, i + 4, 4);
    var header = 8;
    if (size == 1) {
      if (i + 16 > to) return null;
      size = _u64be(b, i + 8);
      header = 16;
    } else if (size == 0) {
      size = to - i;
    }
    if (size < header || i + size > to) return null;
    list.add(_Box(i, header, i + size, type));
    i += size;
  }
  return list;
}

int _readN(Uint8List b, int o, int n) {
  var v = 0;
  for (var k = 0; k < n; k++) {
    v = (v << 8) | b[o + k];
  }
  return v;
}

Uint8List? _scrubHeif(Uint8List src) {
  final top = _boxes(src, 0, src.length);
  if (top == null) return null;
  final meta = top.where((x) => x.type == 'meta').toList();
  if (meta.isEmpty) return src;
  final m = meta.first;
  final children = _boxes(src, m.body + 4, m.end); // FullBox
  if (children == null) return null;
  _Box? iinf;
  _Box? iloc;
  _Box? idat;
  for (final c in children) {
    if (c.type == 'iinf') iinf = c;
    if (c.type == 'iloc') iloc = c;
    if (c.type == 'idat') idat = c;
  }
  if (iinf == null || iloc == null) return src;

  // Какие элементы — метаданные.
  final targets = <int>{};
  final iv = src[iinf.body];
  final entriesFrom = iinf.body + 4 + (iv == 0 ? 2 : 4);
  final infes = _boxes(src, entriesFrom, iinf.end);
  if (infes == null) return null;
  for (final e in infes) {
    if (e.type != 'infe') continue;
    final v = src[e.body];
    if (v < 2) continue; // в старых версиях нет item_type
    var o = e.body + 4;
    final id = v == 2 ? _readN(src, o, 2) : _readN(src, o, 4);
    o += v == 2 ? 2 : 4;
    o += 2; // item_protection_index
    if (o + 4 > e.end) continue;
    final itemType = _ascii(src, o, 4);
    o += 4;
    if (itemType == 'Exif') {
      targets.add(id);
    } else if (itemType == 'mime') {
      // item_name\0 content_type\0
      final nameEnd = src.indexOf(0, o);
      if (nameEnd < 0 || nameEnd >= e.end) continue;
      final ctEnd = src.indexOf(0, nameEnd + 1);
      final ct = String.fromCharCodes(
        src.sublist(nameEnd + 1, (ctEnd < 0 || ctEnd > e.end) ? e.end : ctEnd),
      ).toLowerCase();
      if (ct.contains('xmp') || ct.contains('rdf+xml')) targets.add(id);
    }
  }
  if (targets.isEmpty) return src;

  // Где лежат их байты.
  final ranges = <(int, int)>[];
  final v = src[iloc.body];
  var o = iloc.body + 4;
  final offsetSize = src[o] >> 4;
  final lengthSize = src[o] & 0x0F;
  final baseOffsetSize = src[o + 1] >> 4;
  final indexSize = (v == 1 || v == 2) ? (src[o + 1] & 0x0F) : 0;
  o += 2;
  final itemCount = v < 2 ? _readN(src, o, 2) : _readN(src, o, 4);
  o += v < 2 ? 2 : 4;
  for (var k = 0; k < itemCount; k++) {
    final id = v < 2 ? _readN(src, o, 2) : _readN(src, o, 4);
    o += v < 2 ? 2 : 4;
    var construction = 0;
    if (v == 1 || v == 2) {
      construction = _readN(src, o, 2) & 0x0F;
      o += 2;
    }
    o += 2; // data_reference_index
    final base = _readN(src, o, baseOffsetSize);
    o += baseOffsetSize;
    final extents = _readN(src, o, 2);
    o += 2;
    for (var x = 0; x < extents; x++) {
      if (indexSize > 0) o += indexSize;
      final off = _readN(src, o, offsetSize);
      o += offsetSize;
      final len = _readN(src, o, lengthSize);
      o += lengthSize;
      if (o > iloc.end) return null;
      if (!targets.contains(id)) continue;
      int start;
      if (construction == 0) {
        start = base + off;
      } else if (construction == 1 && idat != null) {
        start = idat.body + base + off;
      } else {
        return null; // ссылка на другой элемент — не разбираем, лучше перекодировать
      }
      final end = len == 0 ? src.length : start + len;
      if (start < 0 || end > src.length || start > end) return null;
      ranges.add((start, end));
    }
  }
  if (ranges.isEmpty) return src;
  final out = Uint8List.fromList(src);
  for (final (s, e) in ranges) {
    out.fillRange(s, e, 0);
  }
  return out;
}

// ───────────────────────────── Видео ─────────────────────────────

const String _xmpUuid = '¾zÏË\u0097©Bè'
    '\u009cq\u0099\u0094\u0091ã¯¬';

/// Смещения заголовков блоков (позиция поля type), которые надо переименовать
/// в `free`. Читает только заголовки — подходит и для роликов в гигабайт.
/// `null` — не MP4/MOV или структура не сошлась.
Future<List<int>?> findVideoMetadataBoxes(RandomAccessFile f) async {
  try {
    final length = await f.length();
    Future<Uint8List> readAt(int pos, int n) async {
      await f.setPosition(pos);
      return f.read(n);
    }

    Future<List<_Box>?> boxesAt(int from, int to) async {
      final list = <_Box>[];
      var i = from;
      while (i + 8 <= to) {
        final h = await readAt(i, 16);
        if (h.length < 8) return null;
        var size = _u32be(h, 0);
        final type = _ascii(h, 4, 4);
        var header = 8;
        if (size == 1) {
          if (h.length < 16) return null;
          size = _u64be(h, 8);
          header = 16;
        } else if (size == 0) {
          size = to - i;
        }
        if (size < header || i + size > to) return null;
        list.add(_Box(i, header, i + size, type));
        i += size;
        if (list.length > 100000) return null;
      }
      return list;
    }

    final head = await readAt(0, 12);
    if (head.length < 8 || _ascii(head, 4, 4) != 'ftyp') {
      // QuickTime без ftyp начинается сразу с moov/mdat/wide.
      const qt = {'moov', 'mdat', 'wide', 'free', 'skip'};
      if (head.length < 8 || !qt.contains(_ascii(head, 4, 4))) return null;
    }
    final top = await boxesAt(0, length);
    if (top == null) return null;
    final patches = <int>[];
    for (final t in top) {
      if (t.type == 'uuid' && t.end - t.body >= 16) {
        final id = await readAt(t.body, 16);
        if (String.fromCharCodes(id) == _xmpUuid) patches.add(t.start + 4);
      }
      if (t.type != 'moov') continue;
      final moov = await boxesAt(t.body, t.end);
      if (moov == null) return null;
      for (final c in moov) {
        if (c.type == 'udta' || c.type == 'meta') {
          patches.add(c.start + 4);
        } else if (c.type == 'trak') {
          final trak = await boxesAt(c.body, c.end);
          if (trak == null) return null;
          for (final tc in trak) {
            if (tc.type == 'udta' || tc.type == 'meta') {
              patches.add(tc.start + 4);
            }
          }
        }
      }
    }
    return patches;
  } catch (_) {
    return null;
  }
}

/// Переименовывает найденные блоки в `free` (в уже скопированном файле).
Future<void> applyVideoMetadataPatches(
  RandomAccessFile f,
  List<int> typeOffsets,
) async {
  for (final o in typeOffsets) {
    await f.setPosition(o);
    await f.writeFrom(const [0x66, 0x72, 0x65, 0x65]); // 'free'
  }
  await f.flush();
}

// ───────────────────────────── Мелочи ─────────────────────────────

String _ascii(Uint8List b, int o, int n) {
  if (o + n > b.length) return '';
  return String.fromCharCodes(b, o, o + n);
}

bool _startsWith(Uint8List b, int o, int len, String s) {
  if (len < s.length || o + s.length > b.length) return false;
  for (var k = 0; k < s.length; k++) {
    if (b[o + k] != s.codeUnitAt(k)) return false;
  }
  return true;
}

bool _sameBytes(Uint8List b, int s, int e, Uint8List other) {
  if (e - s != other.length) return false;
  for (var k = 0; k < other.length; k++) {
    if (b[s + k] != other[k]) return false;
  }
  return true;
}

int _u32be(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

int _u32le(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

int _u64be(Uint8List b, int o) => (_u32be(b, o) << 32) | _u32be(b, o + 4);

List<int> _u16beBytes(int v) => [(v >> 8) & 0xFF, v & 0xFF];

List<int> _u32leBytes(int v) =>
    [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
