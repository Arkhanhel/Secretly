// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Поймут ли таймер устройства собеседника и мои (ТЗ 22.10.2026, §2.4).
/// Источник — подсказка реле `all_build_at_least`; это не допуск, а повод
/// показать плашку.
enum DisappearingPeerSupport {
  /// Все устройства обеих сторон не старше `min_build`.
  supported,

  /// У собеседника есть устройство старой версии: у него не исчезнет.
  peerOutdated,

  /// У меня самого есть устройство старой версии (например, ПК).
  ownOutdated,

  /// Не удалось проверить (реле недоступно, старое реле, нет строк
  /// активности). Плашка говорит об этом прямо, а не молчит.
  unknown,
}

/// Выключатели исчезающих сообщений: блок `disappearing` подписанного
/// `/v1/config` (ТЗ 22.10.2026, §2.5; решения владельца 23.10).
///
/// **Два флага.** [sendEnabled] гасит только отправку: срок в сообщении,
/// команды смены таймера, пункт в настройках. [expireEnabled] — исполнение
/// уже назначенных истечений; выключается только при ошибке, которая удаляет
/// не то. Приём срока и команд флага не ждёт: получатели должны уметь раньше,
/// чем отправители начнут.
///
/// **Отказ.** Блок не пришёл, подпись не сошлась, в сборке нет ключа —
/// [defaults]: отправка выключена, доля 0, удаление включено. Без связи
/// обещанное удаление всё равно происходит; новых обещаний не даётся.
///
/// **Сборка не задана.** [minBuild] равный нулю означает «оператор ещё не
/// назвал сборку, которая понимает таймер»: устройства собеседника считаются
/// старыми, плашка показывается.
@immutable
class DisappearingFlags {
  const DisappearingFlags({
    this.sendEnabled = false,
    this.sendShare = 0,
    this.expireEnabled = true,
    this.minBuild = 0,
    this.customMaxS = defaultCustomMaxS,
  });

  /// Предел «своего» срока по умолчанию — 30 дней.
  static const int defaultCustomMaxS = 30 * 24 * 60 * 60;

  /// Минимум «своего» срока — 30 секунд; зашит в клиенте, конфигом не
  /// опускается.
  static const int customMinS = 30;

  static const DisappearingFlags defaults = DisappearingFlags();

  /// Отправка срока и команд таймера разрешена.
  final bool sendEnabled;

  /// Доля профилей, которым отправка разрешена (0…100).
  final int sendShare;

  /// Исполнять уже назначенные истечения.
  final bool expireEnabled;

  /// Сборка, с которой таймер понимают; 0 — не задана.
  final int minBuild;

  /// Предел «своего» срока, секунд.
  final int customMaxS;

  static DisappearingFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['disappearing'];
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
    return DisappearingFlags(
      sendEnabled: flag('send_enabled', false),
      sendShare: number('send_share', 0).clamp(0, 100),
      expireEnabled: flag('expire_enabled', true),
      minBuild: number('min_build', 0).clamp(0, 100000000),
      customMaxS: number(
        'custom_max_s',
        defaultCustomMaxS,
      ).clamp(customMinS, 365 * 24 * 60 * 60),
    );
  }

  /// Разрешена ли отправка профилю [profileId]: флаг и доля, детерминированно
  /// по профилю — sha256('disappearing-send_share-v1|' + profile_id), два
  /// первых байта, остаток от 100. Пустой профиль — не в доле.
  bool sendAllowedFor(String profileId) {
    if (!sendEnabled || sendShare <= 0) return false;
    final id = profileId.trim();
    if (id.isEmpty) return false;
    if (sendShare >= 100) return true;
    return rolloutBucket('send_share', id) < sendShare;
  }

  @visibleForTesting
  static int rolloutBucket(String field, String profileId) {
    final digest = sha256
        .convert(utf8.encode('disappearing-$field-v1|$profileId'))
        .bytes;
    return ((digest[0] << 8) | digest[1]) % 100;
  }

  Map<String, Object?> toLogFields() => <String, Object?>{
    'send_enabled': sendEnabled,
    'send_share': sendShare,
    'expire_enabled': expireEnabled,
    'min_build': minBuild,
    'custom_max_s': customMaxS,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisappearingFlags &&
          other.sendEnabled == sendEnabled &&
          other.sendShare == sendShare &&
          other.expireEnabled == expireEnabled &&
          other.minBuild == minBuild &&
          other.customMaxS == customMaxS;

  @override
  int get hashCode =>
      Object.hash(sendEnabled, sendShare, expireEnabled, minBuild, customMaxS);

  @override
  String toString() =>
      'DisappearingFlags(send=$sendEnabled/$sendShare%, expire=$expireEnabled, '
      'minBuild=$minBuild, customMax=$customMaxS)';
}
