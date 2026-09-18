// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Серверный переключатель ОТПРАВКИ повторного prekey (Э-4,
/// docs/TZ_PREKEY_UNTIL_CONFIRMED_2026-08-01.md), приезжает в дополнительном
/// блоке `handshake` подписанного `/v1/config`.
///
/// **Почему это не сборочный флаг.** До 03.08.2026 переключатель был
/// `bool.fromEnvironment`. Чтобы включить отправку, требовалась новая сборка,
/// ревью Play и обновление у людей — и, что хуже, чтобы ВЫКЛЮЧИТЬ обратно,
/// требовалось ровно то же самое. Функция, у которой откат занимает дни,
/// небезопасна независимо от того, насколько она хороша.
///
/// **Чем отличается от [RoomFlags].** Там сервер — только выключатель: включить
/// без пересборки нельзя, нужны два независимых ключа. Здесь сервер —
/// единственный ключ, и это осознанный размен. Безопасность даёт не пересборка,
/// а два других свойства:
///
///  * **Отказ в закрытую при любой неясности.** Недоступный сервер, старый
///    сервер без блока, срезанное поле, поддельная подпись — всё оставляет
///    отправку спящей. Спящая отправка ничего не стоит: обычный провод читают
///    все сборки, когда-либо существовавшие.
///  * **Доля раскатки.** Включать можно не всем сразу. Доля считается
///    ДЕТЕРМИНИРОВАННО от device_id, поэтому телефон не перескакивает между
///    группами от опроса к опросу — иначе половина устройств меняла бы
///    поведение каждые несколько минут, и понять причину поломки было бы нечем.
///
/// **Приём НИКОГДА не за флагом.** Сборка, которая умеет прочитать повтор,
/// читает его всегда — иначе повторяется 1.7.4+416, где отказ читать означал
/// безвозвратную потерю сообщений.
@immutable
class HandshakeFlags {
  const HandshakeFlags({
    this.prekeyUntilConfirmedSendEnabled = false,
    this.prekeyUntilConfirmedSendPercent = 0,
  });

  /// Спящее состояние: всё, что не удалось проверить, приводит сюда.
  static const HandshakeFlags defaults = HandshakeFlags();

  /// Разрешение сервера отправлять повтор рукопожатия.
  final bool prekeyUntilConfirmedSendEnabled;

  /// Доля устройств, 0..100, которым разрешение действительно выдаётся.
  final int prekeyUntilConfirmedSendPercent;

  /// Читает блок из ответа `/v1/config`.
  ///
  /// [verified] обязан быть результатом `verifyHandshakeSignature`: при false
  /// возвращается [defaults] и отправка остаётся спящей.
  static HandshakeFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['handshake'];
    if (payload is! Map) return defaults;
    final raw = payload['prekey_until_confirmed_send_percent'];
    final percent = raw is num ? raw.toInt() : 0;
    return HandshakeFlags(
      prekeyUntilConfirmedSendEnabled:
          payload['prekey_until_confirmed_send_enabled'] == true,
      // Зажимаем и здесь, хотя сервер уже зажал: клиент не обязан верить, что
      // на той стороне ничего не поменяется.
      prekeyUntilConfirmedSendPercent: percent.clamp(0, 100),
    );
  }

  /// Попадает ли ЭТО устройство в долю раскатки.
  ///
  /// Решение детерминированное: берётся sha256 от device_id, и первые байты
  /// дают число 0..99. Одно и то же устройство всегда получает один и тот же
  /// ответ при одной и той же доле — это и есть главное требование, иначе
  /// поведение мигало бы от опроса к опросу.
  ///
  /// Пустой device_id — не в доле: считать «неизвестно» за «включено» значит
  /// нарушить отказ в закрытую.
  bool allowsSendFor(String deviceId) {
    if (!prekeyUntilConfirmedSendEnabled) return false;
    if (prekeyUntilConfirmedSendPercent <= 0) return false;
    // 🔴 Проверка device_id ИДЁТ РАНЬШЕ ветки «сто процентов». Обратный порядок
    // означал бы, что при полной раскатке устройство без опознанного
    // идентификатора всё равно начинает отправлять — то есть «неизвестно»
    // засчитывается за «включено». Поймано тестом.
    final id = deviceId.trim();
    if (id.isEmpty) return false;
    if (prekeyUntilConfirmedSendPercent >= 100) return true;
    final digest = sha256.convert(utf8.encode('prekey-rollout-v1|$id')).bytes;
    final bucket = ((digest[0] << 8) | digest[1]) % 100;
    return bucket < prekeyUntilConfirmedSendPercent;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HandshakeFlags &&
          other.prekeyUntilConfirmedSendEnabled ==
              prekeyUntilConfirmedSendEnabled &&
          other.prekeyUntilConfirmedSendPercent ==
              prekeyUntilConfirmedSendPercent;

  @override
  int get hashCode => Object.hash(
    prekeyUntilConfirmedSendEnabled,
    prekeyUntilConfirmedSendPercent,
  );

  @override
  String toString() =>
      'HandshakeFlags(send: $prekeyUntilConfirmedSendEnabled, '
      'percent: $prekeyUntilConfirmedSendPercent)';
}
