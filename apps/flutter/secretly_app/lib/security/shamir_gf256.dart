// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math';
import 'dart:typed_data';

/// Разделение секрета по Шамиру над GF(256) (Э3 «социальное восстановление»).
///
/// Поле — GF(2^8) с многочленом 0x11B (как в AES и в крейте `sharks`).
/// Секрет делится побайтно: для каждого байта — свой случайный многочлен
/// степени `threshold - 1`; доля с индексом `x` (1..255) — значения всех
/// многочленов в точке `x`. Восстановление — интерполяция Лагранжа в нуле.
///
/// Почему своя реализация, а не крейт: на iOS Rust-мост в проекте не
/// используется для криптографии восстановления (см. ТЗ, §1.1), а здесь
/// 150 строк с векторами, сверенными тестом против `vsss-rs`.
///
/// 🔴 Что эта схема даёт и чего нет. Любые `threshold` долей восстанавливают
/// секрет; `threshold - 1` долей не дают о нём НИЧЕГО (информационно-
/// теоретически). Доли не проверяемы: подменённую долю обнаружит только
/// неверная расшифровка блока (AEAD), поэтому блок всегда с аутентификацией.
class ShamirGf256 {
  ShamirGf256._();

  static const int minThreshold = 2;
  static const int maxShares = 255;

  static final Uint8List _exp = Uint8List(512);
  static final Uint8List _log = Uint8List(256);
  static bool _tablesReady = false;

  static void _ensureTables() {
    if (_tablesReady) return;
    var x = 1;
    for (var i = 0; i < 255; i++) {
      _exp[i] = x;
      _log[x] = i;
      // Умножение на порождающий элемент 3 (x + 1).
      var x2 = x << 1;
      if (x2 & 0x100 != 0) x2 ^= 0x11B;
      x = x2 ^ x;
    }
    for (var i = 255; i < 512; i++) {
      _exp[i] = _exp[i - 255];
    }
    _tablesReady = true;
  }

  static int _mul(int a, int b) {
    if (a == 0 || b == 0) return 0;
    _ensureTables();
    return _exp[_log[a] + _log[b]];
  }

  static int _div(int a, int b) {
    if (b == 0) throw ArgumentError('division by zero in GF(256)');
    if (a == 0) return 0;
    _ensureTables();
    return _exp[(_log[a] + 255 - _log[b]) % 255];
  }

  /// Делит [secret] на [shares] долей с порогом [threshold].
  ///
  /// Каждая доля — `threshold`-независимый массив длины `secret.length + 1`:
  /// первый байт — индекс `x` (1..shares), дальше — значения.
  static List<Uint8List> split(
    Uint8List secret, {
    required int threshold,
    required int shares,
    Random? random,
  }) {
    if (secret.isEmpty) throw ArgumentError('secret is empty');
    if (threshold < minThreshold) {
      throw ArgumentError('threshold must be at least $minThreshold');
    }
    if (shares < threshold || shares > maxShares) {
      throw ArgumentError('shares must be in [$threshold, $maxShares]');
    }
    final rng = random ?? Random.secure();
    final out = List<Uint8List>.generate(
      shares,
      (i) => Uint8List(secret.length + 1)..[0] = i + 1,
    );
    final coeffs = Uint8List(threshold);
    for (var byteIndex = 0; byteIndex < secret.length; byteIndex++) {
      coeffs[0] = secret[byteIndex];
      for (var k = 1; k < threshold; k++) {
        coeffs[k] = rng.nextInt(256);
      }
      // Старший коэффициент не должен быть нулём, иначе степень падает и
      // порог фактически уменьшается.
      if (threshold > 1 && coeffs[threshold - 1] == 0) {
        coeffs[threshold - 1] = 1 + rng.nextInt(255);
      }
      for (var s = 0; s < shares; s++) {
        final x = s + 1;
        // Схема Горнера.
        var y = 0;
        for (var k = threshold - 1; k >= 0; k--) {
          y = _mul(y, x) ^ coeffs[k];
        }
        out[s][byteIndex + 1] = y;
      }
    }
    return out;
  }

  /// Восстанавливает секрет из любых долей. Число долей задаёт степень
  /// интерполяции; меньше порога — результат мусор (и AEAD блока это
  /// обнаружит), поэтому порог хранится рядом с долями и проверяется выше.
  static Uint8List combine(List<Uint8List> shares) {
    if (shares.length < minThreshold) {
      throw ArgumentError('need at least $minThreshold shares');
    }
    final length = shares.first.length;
    if (length < 2) throw ArgumentError('share too short');
    final xs = <int>[];
    for (final s in shares) {
      if (s.length != length) throw ArgumentError('shares differ in length');
      if (s[0] == 0) throw ArgumentError('share index 0 is invalid');
      if (xs.contains(s[0])) throw ArgumentError('duplicate share index ${s[0]}');
      xs.add(s[0]);
    }
    final secret = Uint8List(length - 1);
    for (var byteIndex = 1; byteIndex < length; byteIndex++) {
      var acc = 0;
      for (var i = 0; i < shares.length; i++) {
        // Базисный многочлен Лагранжа в нуле:
        //   prod_{j != i} x_j / (x_j - x_i) = prod x_j / (x_j ^ x_i)
        var num = 1;
        var den = 1;
        for (var j = 0; j < shares.length; j++) {
          if (i == j) continue;
          num = _mul(num, xs[j]);
          den = _mul(den, xs[j] ^ xs[i]);
        }
        acc ^= _mul(shares[i][byteIndex], _div(num, den));
      }
      secret[byteIndex - 1] = acc;
    }
    return secret;
  }

  /// Умножение в поле — открыто для проверочных тестов.
  static int mulForTesting(int a, int b) => _mul(a, b);
}
