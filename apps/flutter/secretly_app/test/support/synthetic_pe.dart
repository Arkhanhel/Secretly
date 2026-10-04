// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Маленький настоящий PE-файл для проверок: заголовки DOS и PE32+, одна
// секция `.rsrc` с каталогом ресурсов RT_VERSION → 1 → 0x409 и структурой
// VS_VERSIONINFO / VS_FIXEDFILEINFO — ровно так, как их кладёт компоновщик и
// Inno Setup (`VersionInfoVersion`). Хвост [padding] — «тело программы»,
// чтобы подпись и размер проверялись на файле заметного объёма.

import 'dart:typed_data';

Uint8List buildSyntheticPe({
  required int major,
  required int minor,
  required int patch,
  required int build,
  bool pe32 = false,
  bool withVersion = true,
  int fixedSignature = 0xFEEF04BD,
  int padding = 0,
}) {
  const peAt = 0x80;
  const rawAt = 0x200;
  const va = 0x1000;
  final optSize = pe32 ? 96 + 16 * 8 : 112 + 16 * 8;

  // ── .rsrc ───────────────────────────────────────────────────────────────
  final rsrc = ByteData(0x58 + 92);
  void dir(int at, int id, int target) {
    rsrc.setUint16(at + 14, 1, Endian.little); // одна запись по номеру
    rsrc.setUint32(at + 16, id, Endian.little);
    rsrc.setUint32(at + 20, target, Endian.little);
  }

  dir(0x00, withVersion ? 16 : 3, 0x80000000 | 0x18); // тип (3 — RT_ICON)
  dir(0x18, 1, 0x80000000 | 0x30); // имя
  dir(0x30, 0x409, 0x48); // язык → запись данных
  rsrc.setUint32(0x48, va + 0x58, Endian.little); // RVA данных
  rsrc.setUint32(0x4C, 92, Endian.little); // размер
  // VS_VERSIONINFO
  const vs = 0x58;
  rsrc.setUint16(vs, 92, Endian.little);
  rsrc.setUint16(vs + 2, 52, Endian.little);
  rsrc.setUint16(vs + 4, 0, Endian.little);
  const key = 'VS_VERSION_INFO';
  for (var i = 0; i < key.length; i++) {
    rsrc.setUint16(vs + 6 + i * 2, key.codeUnitAt(i), Endian.little);
  }
  // Ноль-терминатор и выравнивание — нули уже на месте; значение с +40.
  const fixed = vs + 40;
  rsrc.setUint32(fixed, fixedSignature, Endian.little);
  rsrc.setUint32(fixed + 4, 0x00010000, Endian.little);
  rsrc.setUint32(fixed + 8, (major << 16) | minor, Endian.little);
  rsrc.setUint32(fixed + 12, (patch << 16) | build, Endian.little);
  rsrc.setUint32(fixed + 16, (major << 16) | minor, Endian.little);
  rsrc.setUint32(fixed + 20, (patch << 16) | build, Endian.little);
  final rsrcBytes = rsrc.buffer.asUint8List();

  // ── заголовки ───────────────────────────────────────────────────────────
  final out = ByteData(rawAt + rsrcBytes.length + padding);
  out.setUint8(0, 0x4D); // M
  out.setUint8(1, 0x5A); // Z
  out.setUint32(0x3C, peAt, Endian.little);
  out.setUint32(peAt, 0x00004550, Endian.little); // PE\0\0
  out.setUint16(peAt + 4, pe32 ? 0x14C : 0x8664, Endian.little);
  out.setUint16(peAt + 6, 1, Endian.little); // одна секция
  out.setUint16(peAt + 20, optSize, Endian.little);
  const opt = peAt + 24;
  out.setUint16(opt, pe32 ? 0x10B : 0x20B, Endian.little);
  final dirs = pe32 ? opt + 96 : opt + 112;
  out.setUint32(dirs - 4, 16, Endian.little); // NumberOfRvaAndSizes
  out.setUint32(dirs + 2 * 8, va, Endian.little); // каталог ресурсов
  out.setUint32(dirs + 2 * 8 + 4, rsrcBytes.length, Endian.little);
  final section = opt + optSize;
  const name = '.rsrc';
  for (var i = 0; i < name.length; i++) {
    out.setUint8(section + i, name.codeUnitAt(i));
  }
  out.setUint32(section + 8, rsrcBytes.length, Endian.little); // VirtualSize
  out.setUint32(section + 12, va, Endian.little);
  out.setUint32(section + 16, rsrcBytes.length, Endian.little); // SizeOfRawData
  out.setUint32(section + 20, rawAt, Endian.little);
  final bytes = out.buffer.asUint8List();
  bytes.setRange(rawAt, rawAt + rsrcBytes.length, rsrcBytes);
  for (var i = rawAt + rsrcBytes.length; i < bytes.length; i++) {
    bytes[i] = 0x78; // «x» — тело
  }
  return bytes;
}
