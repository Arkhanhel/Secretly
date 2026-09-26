// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

import 'double_ratchet_v3.dart';

/// П-3 (ТЗ мультиустройства, 25.09.2026): пределы пропуска ключей для ЖИВОЙ
/// сессии.
///
/// Устройство, долго бывшее без связи, получает провод, опередивший его
/// цепочку на сотни номеров: у собеседника на реле истекли «печатает»,
/// квитанции, сигналы звонка — ключи на них потрачены при шифровании, а
/// посылок нет. При пределе 200 такой провод не открывался никогда.
///
/// * [legacy] — прежнее поведение ПОБАЙТОВО: скачок 200, хранение без потолка.
///   Так работают архивные сессии всегда (при откате до 8 архивных большой
///   предел умножал бы цену неподдающегося провода на 9) и телефон, пока его
///   не поднимет сервер.
/// * поднятый предел — скачок до 25 000, на провод и на устройство собеседника
///   хранится не больше [storedCap] САМЫХ НОВЫХ ключей, проход переигровки
///   карантина ограничен [raisedReplayBudget].
///
/// 🔴 Телефон остаётся на 200, хотя таблица ТЗ предлагает 2 000: мобильная
/// версия заморожена (без флага поведение обязано быть прежним), а сам П-3
/// требует сначала замерить 2 000 на Xiaomi владельца и слабом Android.
/// Поднимается полем `ratchet_jump_mobile` блока `multidevice` после замера.
@immutable
class RatchetSkipLimits {
  const RatchetSkipLimits._({
    required this.jump,
    this.storedPerWire,
    this.storedPerPeer,
    this.replayBudget,
  });

  static const int legacyJump = 200;
  static const int maxJump = 25000;
  static const int storedCap = 2000;
  static const Duration raisedReplayBudget = Duration(seconds: 2);

  /// Встроенные скачки, когда сервер молчит (поле блока = 0).
  static const int builtInDesktopJump = 5000;
  static const int builtInMobileJump = legacyJump;

  static const RatchetSkipLimits legacy = RatchetSkipLimits._(jump: legacyJump);

  /// Пределы для скачка [jump]. Не больше 200 — это [legacy], целиком.
  factory RatchetSkipLimits.forJump(int jump) {
    if (jump <= legacyJump) return legacy;
    return RatchetSkipLimits._(
      jump: jump > maxJump ? maxJump : jump,
      storedPerWire: storedCap,
      storedPerPeer: storedCap,
      replayBudget: raisedReplayBudget,
    );
  }

  /// Насколько номер провода может опережать цепочку — на каждую петлю.
  final int jump;

  /// Сколько ключей одного провода сохранять (самые новые). null — все.
  final int? storedPerWire;

  /// Потолок ключей на устройство собеседника. null — без потолка.
  final int? storedPerPeer;

  /// Сколько один проход переигровки карантина может считать. null — без
  /// предела, как раньше.
  final Duration? replayBudget;

  bool get raised => jump > legacyJump;

  DoubleRatchetV3 buildRatchet() =>
      DoubleRatchetV3(maxSkip: jump, maxStoredSkipped: storedPerWire);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RatchetSkipLimits &&
          other.jump == jump &&
          other.storedPerWire == storedPerWire &&
          other.storedPerPeer == storedPerPeer &&
          other.replayBudget == replayBudget;

  @override
  int get hashCode =>
      Object.hash(jump, storedPerWire, storedPerPeer, replayBudget);

  @override
  String toString() =>
      'RatchetSkipLimits(jump: $jump, perWire: $storedPerWire, '
      'perPeer: $storedPerPeer, replay: $replayBudget)';
}
