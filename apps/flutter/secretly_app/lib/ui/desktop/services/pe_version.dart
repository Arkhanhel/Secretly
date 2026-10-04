// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Версия из ресурса версии Windows-программы (`VS_FIXEDFILEINFO`):
/// `FILEVERSION major,minor,patch,build`.
@immutable
class PeFileVersion {
  const PeFileVersion(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;

  /// Номер сборки — у установщика это `{#AppBuild}` из
  /// `VersionInfoVersion={#AppVersion}.{#AppBuild}` (`windows/installer/secretly.iss`),
  /// у самого приложения — `--build-number` сборки.
  final int build;

  @override
  String toString() => '$major.$minor.$patch.$build';
}

/// Прочитать версию файла `.exe`/`.dll` по пути. `null` — не PE, нет ресурса
/// версии или файл не читается. Файл читается в отдельном изоляте: установщик
/// весит десятки мегабайт.
Future<PeFileVersion?> readPeFileVersion(String path) async {
  try {
    return await Isolate.run(() async {
      try {
        return parsePeFileVersion(await File(path).readAsBytes());
      } catch (_) {
        return null;
      }
    });
  } catch (_) {
    return null;
  }
}

/// Разбор ресурса версии PE-файла на чистом Dart (01.10.2026).
///
/// Путь ровно тот, каким идёт сама Windows: заголовок DOS → `PE\0\0` →
/// каталог ресурсов (запись 2 таблицы каталогов) → `RT_VERSION` (16) → первое
/// имя → первый язык → данные → `VS_VERSIONINFO` с ключом `VS_VERSION_INFO` →
/// `VS_FIXEDFILEINFO` с подписью `0xFEEF04BD`. Любое расхождение по дороге —
/// `null`: вызывающий обязан считать «версии нет» отказом, а не согласием.
PeFileVersion? parsePeFileVersion(Uint8List bytes) {
  try {
    return _PeReader(bytes).fileVersion();
  } catch (_) {
    return null;
  }
}

class _PeReader {
  _PeReader(this.bytes) : data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData data;

  static const int _rtVersion = 16;
  static const int _fixedSignature = 0xFEEF04BD;

  bool _has(int offset, int length) =>
      offset >= 0 && length >= 0 && offset + length <= bytes.length;

  int _u16(int o) {
    if (!_has(o, 2)) throw const FormatException('out of range');
    return data.getUint16(o, Endian.little);
  }

  int _u32(int o) {
    if (!_has(o, 4)) throw const FormatException('out of range');
    return data.getUint32(o, Endian.little);
  }

  late final List<({int va, int size, int raw, int rawSize})> _sections;

  int? _rvaToOffset(int rva) {
    for (final s in _sections) {
      final span = s.size > s.rawSize ? s.size : s.rawSize;
      if (rva >= s.va && rva < s.va + span) {
        final off = s.raw + (rva - s.va);
        // Часть сверх данных на диске существует только в памяти.
        if (rva - s.va >= s.rawSize) return null;
        return off;
      }
    }
    return null;
  }

  PeFileVersion? fileVersion() {
    if (bytes.length < 0x40 || bytes[0] != 0x4D || bytes[1] != 0x5A) {
      return null; // не «MZ»
    }
    final pe = _u32(0x3C);
    if (_u32(pe) != 0x00004550) return null; // не «PE\0\0»
    final sectionCount = _u16(pe + 6);
    final optSize = _u16(pe + 20);
    final opt = pe + 24;
    final magic = _u16(opt);
    final int dirCountAt;
    final int dirsAt;
    if (magic == 0x10B) {
      dirCountAt = opt + 92;
      dirsAt = opt + 96;
    } else if (magic == 0x20B) {
      dirCountAt = opt + 108;
      dirsAt = opt + 112;
    } else {
      return null;
    }
    if (_u32(dirCountAt) < 3) return null; // нет записи каталога ресурсов
    final resRva = _u32(dirsAt + 2 * 8);
    if (resRva == 0) return null;

    final sectionsAt = opt + optSize;
    if (sectionCount <= 0 || sectionCount > 96) return null;
    _sections = [
      for (var i = 0; i < sectionCount; i++)
        (
          va: _u32(sectionsAt + i * 40 + 12),
          size: _u32(sectionsAt + i * 40 + 8),
          rawSize: _u32(sectionsAt + i * 40 + 16),
          raw: _u32(sectionsAt + i * 40 + 20),
        ),
    ];
    final base = _rvaToOffset(resRva);
    if (base == null) return null;

    // Уровень 1 — тип ресурса: ищем RT_VERSION по номеру.
    final typeDir = _entry(base, base, id: _rtVersion, wantDir: true);
    if (typeDir == null) return null;
    // Уровни 2 и 3 — имя и язык: берём первые.
    final nameDir = _entry(base, typeDir, wantDir: true);
    if (nameDir == null) return null;
    final dataEntry = _entry(base, nameDir, wantDir: false);
    if (dataEntry == null) return null;
    final dataRva = _u32(dataEntry);
    final dataSize = _u32(dataEntry + 4);
    final at = _rvaToOffset(dataRva);
    if (at == null || !_has(at, dataSize) || dataSize < 6 + 32 + 52) {
      return null;
    }
    return _versionInfo(at, dataSize);
  }

  /// Запись каталога ресурсов по смещению [dir] (от начала файла). [id] —
  /// нужный номер; без него — первая запись. Возвращает смещение (от начала
  /// файла) подкаталога или записи данных — в зависимости от [wantDir].
  int? _entry(int base, int dir, {int? id, required bool wantDir}) {
    final named = _u16(dir + 12);
    final ids = _u16(dir + 14);
    final total = named + ids;
    if (total <= 0 || total > 4096) return null;
    for (var i = 0; i < total; i++) {
      final e = dir + 16 + i * 8;
      final name = _u32(e);
      final target = _u32(e + 4);
      final isNamed = (name & 0x80000000) != 0;
      if (id != null && (isNamed || name != id)) continue;
      final isDir = (target & 0x80000000) != 0;
      if (isDir != wantDir) return null;
      final off = base + (target & 0x7FFFFFFF);
      if (!_has(off, 16)) return null;
      return off;
    }
    return null;
  }

  PeFileVersion? _versionInfo(int at, int size) {
    final length = _u16(at);
    final valueLength = _u16(at + 2);
    if (length > size || valueLength < 52) return null;
    // Ключ — строка UTF-16 «VS_VERSION_INFO» с нулём на конце.
    const key = 'VS_VERSION_INFO';
    var p = at + 6;
    for (var i = 0; i < key.length; i++, p += 2) {
      if (_u16(p) != key.codeUnitAt(i)) return null;
    }
    if (_u16(p) != 0) return null;
    p += 2;
    // Выравнивание значения на 32 бита — от начала структуры.
    final value = at + (((p - at) + 3) & ~3);
    if (!_has(value, 52) || value + 52 > at + length) return null;
    if (_u32(value) != _fixedSignature) return null;
    final ms = _u32(value + 8);
    final ls = _u32(value + 12);
    return PeFileVersion(ms >> 16, ms & 0xFFFF, ls >> 16, ls & 0xFFFF);
  }
}
