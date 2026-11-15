// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

/// Корзины выравнивания длины полезной нагрузки (Б2, 23.10.2026).
///
/// Без выравнивания реле и наблюдатель сети видят длину открытого текста с
/// точностью до байта: «да», «нет», короткий код, длину пароля. С ним — только
/// корзину. Signal выравнивает до кратного 160; здесь корзины крупнее для
/// длинных сообщений, а выше 4096 — кратно 4096.
const List<int> kPayloadPadBuckets = <int>[160, 512, 1024, 2048, 4096];
const int kPayloadPadLargeStep = 4096;

/// Размер, до которого выравнивается полезная нагрузка длиной [length].
int paddedPayloadLength(int length) {
  if (length <= 0) return length;
  for (final bucket in kPayloadPadBuckets) {
    if (length <= bucket) return bucket;
  }
  return ((length + kPayloadPadLargeStep - 1) ~/ kPayloadPadLargeStep) *
      kPayloadPadLargeStep;
}

/// Дописывает к JSON полезной нагрузки пробелы до размера корзины.
///
/// 🔴 СОВМЕСТИМОСТЬ — ГЛАВНОЕ СВОЙСТВО. Пробел после JSON-объекта разрешён
/// стандартом, и `jsonDecode` его пропускает: выпущенные сборки читают такое
/// сообщение как обычное, ни строчки у них менять не нужно. Поэтому
/// выравнивается ТОЛЬКО то, что выглядит как JSON-объект (`{` … `}`): любой
/// другой формат уходит как есть. Уже выровненное (последний байт — пробел)
/// повторно не трогается.
Uint8List padPayloadForWire(Uint8List plain) {
  final n = plain.length;
  if (n == 0 || plain.first != 0x7B || plain.last != 0x7D) return plain;
  final target = paddedPayloadLength(n);
  if (target <= n) return plain;
  final out = Uint8List(target)
    ..setRange(0, n, plain)
    ..fillRange(n, target, 0x20);
  return out;
}
