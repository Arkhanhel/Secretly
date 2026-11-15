// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Выключатели групповых созвонов: блок `calls` подписанного `/v1/config`
/// (ТЗ E2EE созвонов, ЗВ-С6 и ЗР-18).
///
/// **Отказ.** Блок не пришёл, подпись не сошлась, в сборке нет ключа —
/// [defaults], то есть всё как до этого блока: созвоны работают, новые
/// созвоны открытые (доля шифрования 0), флаг-дня нет.
///
/// **Флаг-день «липкий».** [e2eeRequired] однажды увиденный подписанным
/// `true` клиент хранит сам ([AppController] пишет его в локальную базу) и
/// больше не опускает — даже если потом придёт старый или неподписанный
/// конфиг: защиты от отката конфига на сервере нет (`issued_at_ms` не
/// проверяется).
///
/// **Выключатель шифрования у оператора не предусмотрен.** [groupCallsEnabled]
/// выключает групповые созвоны целиком, а [e2eeCreatePercent] до флаг-дня
/// решает только то, какие НОВЫЕ созвоны создаются зашифрованными; идущий
/// зашифрованный созвон им не понизить.
@immutable
class CallFlags {
  const CallFlags({
    this.groupCallsEnabled = true,
    this.e2eeCreatePercent = 0,
    this.e2eeRequired = false,
    this.maxParticipantsE2ee = defaultMaxParticipantsE2ee,
    this.keySwitchDelayMs = defaultKeySwitchDelayMs,
    this.joinRatchet = false,
  });

  static const int defaultMaxParticipantsE2ee = 20;
  static const int defaultKeySwitchDelayMs = 2000;

  static const CallFlags defaults = CallFlags();

  /// Аварийный выключатель групповых созвонов целиком.
  final bool groupCallsEnabled;

  /// Доля устройств, создающих НОВЫЕ созвоны зашифрованными (до флаг-дня).
  final int e2eeCreatePercent;

  /// Флаг-день: открытые созвоны больше не создаются и не открываются.
  final bool e2eeRequired;

  /// Предел участников зашифрованного созвона (2…50).
  final int maxParticipantsE2ee;

  /// Задержка переключения на новый ключ, мс (500…5000).
  final int keySwitchDelayMs;

  /// Этап 1.1 — храповик при входе (обратная секретность).
  final bool joinRatchet;

  static CallFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['calls'];
    if (payload is! Map) return defaults;
    int number(String key, int fallback) {
      final raw = payload[key];
      return raw is num ? raw.toInt() : fallback;
    }

    bool flag(String key, bool fallback) {
      final raw = payload[key];
      return raw is bool ? raw : fallback;
    }

    // Зажимаем и здесь, хотя сервер уже зажал.
    return CallFlags(
      groupCallsEnabled: flag('group_calls_enabled', true),
      e2eeCreatePercent: number('e2ee_create_percent', 0).clamp(0, 100),
      e2eeRequired: flag('e2ee_required', false),
      maxParticipantsE2ee: number(
        'max_participants_e2ee',
        defaultMaxParticipantsE2ee,
      ).clamp(2, 50),
      keySwitchDelayMs: number(
        'key_switch_delay_ms',
        defaultKeySwitchDelayMs,
      ).clamp(500, 5000),
      joinRatchet: flag('join_ratchet', false),
    );
  }

  /// Создаёт ли устройство [deviceId] новые созвоны зашифрованными.
  ///
  /// Флаг-день — всегда да. Иначе доля, детерминированно по устройству:
  /// sha256('calls-e2ee_create_percent-v1|' + device_id), два первых байта,
  /// остаток от 100. Пустой device_id — не в доле.
  bool e2eeCreateFor(String deviceId) {
    if (e2eeRequired) return true;
    if (e2eeCreatePercent <= 0) return false;
    final id = deviceId.trim();
    if (id.isEmpty) return false;
    if (e2eeCreatePercent >= 100) return true;
    return rolloutBucket('e2ee_create_percent', id) < e2eeCreatePercent;
  }

  @visibleForTesting
  static int rolloutBucket(String field, String deviceId) {
    final digest = sha256
        .convert(utf8.encode('calls-$field-v1|$deviceId'))
        .bytes;
    return ((digest[0] << 8) | digest[1]) % 100;
  }

  CallFlags copyWith({bool? e2eeRequired}) => CallFlags(
    groupCallsEnabled: groupCallsEnabled,
    e2eeCreatePercent: e2eeCreatePercent,
    e2eeRequired: e2eeRequired ?? this.e2eeRequired,
    maxParticipantsE2ee: maxParticipantsE2ee,
    keySwitchDelayMs: keySwitchDelayMs,
    joinRatchet: joinRatchet,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallFlags &&
          other.groupCallsEnabled == groupCallsEnabled &&
          other.e2eeCreatePercent == e2eeCreatePercent &&
          other.e2eeRequired == e2eeRequired &&
          other.maxParticipantsE2ee == maxParticipantsE2ee &&
          other.keySwitchDelayMs == keySwitchDelayMs &&
          other.joinRatchet == joinRatchet;

  @override
  int get hashCode => Object.hash(
    groupCallsEnabled,
    e2eeCreatePercent,
    e2eeRequired,
    maxParticipantsE2ee,
    keySwitchDelayMs,
    joinRatchet,
  );

  /// Для журнала: только числа и флаги.
  Map<String, Object> toLogFields() => <String, Object>{
    'group_calls': groupCallsEnabled,
    'e2ee_create_pct': e2eeCreatePercent,
    'e2ee_required': e2eeRequired,
    'max_e2ee': maxParticipantsE2ee,
    'switch_ms': keySwitchDelayMs,
    'join_ratchet': joinRatchet,
  };

  @override
  String toString() => 'CallFlags(${toLogFields()})';
}
