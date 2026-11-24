// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';

/// Выключатель М3 для роликов: `false` — заготовка ролика ждёт кадр, как
/// раньше (0,62 до него).
const bool kPendingVideoHeaderDims = true;

/// М3 для роликов (разбор медиа 22.11.2026): размеры кадра по заголовку
/// MP4/MOV — без ffprobe и без декодера.
///
/// Обходит коробки `moov` → `trak` → `tkhd` (ширина и высота 16.16) и
/// `mdia/hdlr` (дорожка видео — `vide`), читая только заголовки коробок и
/// перескакивая тела по смещению: `moov` в конце файла (без `faststart`)
/// находится так же быстро. Поворот из матрицы `tkhd` (90° / 270° у
/// вертикальных съёмок iPhone) учитывается — ширина и высота меняются местами.
///
/// `null` — не MP4/MOV, файла нет или размеры не нашлись (тогда заготовка
/// ведёт себя как раньше).
Future<({int width, int height})?> readVideoHeaderDims(String path) async {
  RandomAccessFile? raf;
  try {
    raf = await File(path).open();
    final len = await raf.length();
    final moov = await _findBox(raf, 0, len, 'moov');
    if (moov == null) return null;
    ({int width, int height})? anyTrack;
    var guard = 0;
    var off = moov.bodyStart;
    while (off + 8 <= moov.end && guard++ < 256) {
      final box = await _readBoxHeader(raf, off, moov.end);
      if (box == null) break;
      if (box.type == 'trak') {
        final t = await _readTrack(raf, box.bodyStart, box.end);
        if (t != null) {
          if (t.video) return (width: t.width, height: t.height);
          anyTrack ??= (width: t.width, height: t.height);
        }
      }
      off = box.end;
    }
    return anyTrack;
  } catch (_) {
    return null;
  } finally {
    try {
      await raf?.close();
    } catch (_) {}
  }
}

class _Box {
  const _Box(this.type, this.bodyStart, this.end);
  final String type;
  final int bodyStart;
  final int end;
}

Future<_Box?> _readBoxHeader(RandomAccessFile raf, int off, int limit) async {
  if (off + 8 > limit) return null;
  await raf.setPosition(off);
  final h = await raf.read(16 <= limit - off ? 16 : 8);
  if (h.length < 8) return null;
  final bd = ByteData.sublistView(h);
  var size = bd.getUint32(0, Endian.big);
  final type = String.fromCharCodes(h.sublist(4, 8));
  var header = 8;
  if (size == 1) {
    if (h.length < 16) return null;
    size = bd.getUint64(8, Endian.big);
    header = 16;
  } else if (size == 0) {
    size = limit - off;
  }
  if (size < header || off + size > limit) return null;
  return _Box(type, off + header, off + size);
}

Future<_Box?> _findBox(
  RandomAccessFile raf,
  int start,
  int end,
  String type,
) async {
  var off = start;
  var guard = 0;
  while (off + 8 <= end && guard++ < 4096) {
    final box = await _readBoxHeader(raf, off, end);
    if (box == null) return null;
    if (box.type == type) return box;
    off = box.end;
  }
  return null;
}

Future<({int width, int height, bool video})?> _readTrack(
  RandomAccessFile raf,
  int start,
  int end,
) async {
  final tkhd = await _findBox(raf, start, end, 'tkhd');
  if (tkhd == null) return null;
  await raf.setPosition(tkhd.bodyStart);
  final body = await raf.read(
    (tkhd.end - tkhd.bodyStart).clamp(0, 104),
  );
  if (body.isEmpty) return null;
  final version = body[0];
  final matrixAt = version == 1 ? 4 + 32 + 16 : 4 + 20 + 16;
  final sizeAt = matrixAt + 36;
  if (body.length < sizeAt + 8) return null;
  final bd = ByteData.sublistView(body);
  final a = bd.getInt32(matrixAt, Endian.big);
  final b = bd.getInt32(matrixAt + 4, Endian.big);
  final c = bd.getInt32(matrixAt + 12, Endian.big);
  final d = bd.getInt32(matrixAt + 16, Endian.big);
  var w = (bd.getUint32(sizeAt, Endian.big) / 65536).round();
  var h = (bd.getUint32(sizeAt + 4, Endian.big) / 65536).round();
  if (w <= 0 || h <= 0) return null;
  // Поворот на 90° / 270°: a = d = 0, b и c — ±1.
  if (a == 0 && d == 0 && b != 0 && c != 0) {
    final t = w;
    w = h;
    h = t;
  }
  var video = false;
  final mdia = await _findBox(raf, start, end, 'mdia');
  if (mdia != null) {
    final hdlr = await _findBox(raf, mdia.bodyStart, mdia.end, 'hdlr');
    if (hdlr != null && hdlr.end - hdlr.bodyStart >= 12) {
      await raf.setPosition(hdlr.bodyStart + 8);
      final kind = await raf.read(4);
      video = String.fromCharCodes(kind) == 'vide';
    }
  }
  return (width: w, height: h, video: video);
}
