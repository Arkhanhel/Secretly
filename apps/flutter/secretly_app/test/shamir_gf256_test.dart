// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/shamir_gf256.dart';

// Э3: Шамир над GF(256). Арифметика сверяется с известными значениями поля
// AES (многочлен 0x11B); схема — на круге «разделить → собрать» для всех
// сочетаний долей порога и на том, что меньшего числа долей не хватает.

void main() {
  test('арифметика GF(256) по многочлену 0x11B', () {
    // Табличные значения AES: 0x53 * 0xCA = 0x01 (обратные элементы).
    expect(ShamirGf256.mulForTesting(0x53, 0xCA), 0x01);
    expect(ShamirGf256.mulForTesting(0x57, 0x83), 0xC1);
    expect(ShamirGf256.mulForTesting(0x57, 0x13), 0xFE);
    expect(ShamirGf256.mulForTesting(0, 0x7F), 0);
    expect(ShamirGf256.mulForTesting(1, 0x7F), 0x7F);
  });

  test('🔴 любые t долей из n восстанавливают секрет', () {
    final rng = Random(42);
    final secret = Uint8List.fromList(List<int>.generate(32, (i) => (i * 37 + 11) & 0xff));
    for (final (t, n) in <(int, int)>[(2, 3), (3, 5), (2, 2), (4, 4), (3, 7)]) {
      final shares = ShamirGf256.split(secret, threshold: t, shares: n, random: rng);
      expect(shares.length, n);
      expect(shares.map((s) => s[0]).toSet().length, n, reason: 'индексы различны');
      // Все сочетания из t долей.
      for (final combo in _combinations(n, t)) {
        final picked = combo.map((i) => shares[i]).toList();
        expect(ShamirGf256.combine(picked), secret, reason: 't=$t n=$n combo=$combo');
      }
      // И больше порога — тоже.
      if (n > t) {
        expect(ShamirGf256.combine(shares), secret);
      }
    }
  });

  test('🔴 t−1 долей не дают секрет', () {
    final rng = Random(7);
    final secret = Uint8List.fromList(List<int>.filled(32, 0xAB));
    var leaks = 0;
    for (var round = 0; round < 50; round++) {
      final shares = ShamirGf256.split(secret, threshold: 3, shares: 5, random: rng);
      final wrong = ShamirGf256.combine(shares.sublist(0, 2));
      if (wrong.every((b) => b == 0xAB)) leaks++;
    }
    expect(leaks, 0);
  });

  test('ошибки: порог, число долей, дубли, разная длина', () {
    final secret = Uint8List.fromList(<int>[1, 2, 3]);
    expect(() => ShamirGf256.split(secret, threshold: 1, shares: 3), throwsArgumentError);
    expect(() => ShamirGf256.split(secret, threshold: 3, shares: 2), throwsArgumentError);
    expect(() => ShamirGf256.split(secret, threshold: 2, shares: 256), throwsArgumentError);
    expect(() => ShamirGf256.split(Uint8List(0), threshold: 2, shares: 2), throwsArgumentError);
    final shares = ShamirGf256.split(secret, threshold: 2, shares: 3);
    expect(() => ShamirGf256.combine(<Uint8List>[shares[0], shares[0]]), throwsArgumentError);
    expect(() => ShamirGf256.combine(<Uint8List>[shares[0]]), throwsArgumentError);
    expect(
      () => ShamirGf256.combine(<Uint8List>[shares[0], Uint8List.fromList(<int>[2, 1])]),
      throwsArgumentError,
    );
  });

  test('вектор совместимости: доли фиксированного многочлена', () {
    // Секрет 0x2A, порог 2, многочлен f(x) = 0x2A + 0x5C·x.
    // Доли: f(1)=0x76, f(2)=0x2A^(0x5C·2=0xB8)=0x92, f(3)=0x2A^(0x5C·3)=0x2A^0xE4=0xCE.
    final s1 = Uint8List.fromList(<int>[1, 0x76]);
    final s2 = Uint8List.fromList(<int>[2, 0x92]);
    final s3 = Uint8List.fromList(<int>[3, 0xCE]);
    expect(ShamirGf256.combine(<Uint8List>[s1, s2]), Uint8List.fromList(<int>[0x2A]));
    expect(ShamirGf256.combine(<Uint8List>[s2, s3]), Uint8List.fromList(<int>[0x2A]));
    expect(ShamirGf256.combine(<Uint8List>[s1, s3]), Uint8List.fromList(<int>[0x2A]));
  });
}

Iterable<List<int>> _combinations(int n, int k) sync* {
  final idx = List<int>.generate(k, (i) => i);
  while (true) {
    yield List<int>.from(idx);
    var i = k - 1;
    while (i >= 0 && idx[i] == n - k + i) {
      i--;
    }
    if (i < 0) return;
    idx[i]++;
    for (var j = i + 1; j < k; j++) {
      idx[j] = idx[j - 1] + 1;
    }
  }
}
