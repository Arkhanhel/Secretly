// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Что интерфейс может честно сказать о шифровании созвона (ТЗ E2EE
/// созвонов, §8). Отдельный интерфейс, а не поле в `RoomCallMediaController`:
/// открытые созвоны и выпущенные экраны о нём не знают и не меняются.
library;

import 'package:flutter/foundation.dart';

/// Своё шифрование.
enum RoomCallE2eeOwnState {
  /// Подключаемся, ключ ещё не стоит или шифратор не повешен.
  connecting,

  /// Все свои отправители под шифратором.
  encrypting,

  /// Не вышло: созвон закрыт для этого устройства (см. [RoomCallE2eeStatus.errorCode]).
  failed,
}

/// Состояние собеседника.
enum RoomCallE2eePeerState {
  /// Ждём его ключ.
  waitingKey,

  /// Его медиа расшифровывается.
  decrypting,

  /// Ключ есть, а кадры не расшифровываются дольше 10 с.
  failing,
}

@immutable
class RoomCallE2eeStatus {
  const RoomCallE2eeStatus({
    required this.own,
    this.peersByDeviceId = const <String, RoomCallE2eePeerState>{},
    this.unknownParticipants = 0,
    this.errorCode,
  });

  final RoomCallE2eeOwnState own;

  /// Проверенные собеседники по устройству.
  final Map<String, RoomCallE2eePeerState> peersByDeviceId;

  /// Участники SFU, чья идентичность не сошлась со снимком созвона: их не
  /// слушаем и ключей им не даём.
  final int unknownParticipants;

  /// `platform_unsupported`, `identity_mismatch`, `encryption_failed`,
  /// `codec_rejected`, `dynacast_forced` (сервер включил dynacast — ЛК-12),
  /// `transport_unavailable`.
  final String? errorCode;

  /// «Сквозное шифрование» в шапке: своё шифрование включено и ни одного
  /// собеседника, чьё медиа играет без расшифровки, нет (такое медиа мы и не
  /// играем — ждущие ключ молчат).
  bool get secure => own == RoomCallE2eeOwnState.encrypting;

  @override
  bool operator ==(Object other) =>
      other is RoomCallE2eeStatus &&
      other.own == own &&
      mapEquals(other.peersByDeviceId, peersByDeviceId) &&
      other.unknownParticipants == unknownParticipants &&
      other.errorCode == errorCode;

  @override
  int get hashCode => Object.hash(
    own,
    Object.hashAllUnordered(
      peersByDeviceId.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    unknownParticipants,
    errorCode,
  );
}

/// Источник состояния шифрования. Реализуют только зашифрованный медиа-
/// контроллер и фасад, который его оборачивает.
abstract interface class RoomCallE2eeStatusSource {
  /// `null` — созвон открытый: шифрование не включено и не обещается.
  ValueListenable<RoomCallE2eeStatus?> get e2eeStatus;
}
