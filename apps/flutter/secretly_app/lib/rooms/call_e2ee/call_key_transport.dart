// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Как ключи зашифрованного созвона ходят между устройствами (ТЗ E2EE
/// созвонов, ЗР-3, §4.2): попарные сессии Double Ratchet, адресно на одно
/// устройство. Медиаконтроллер видит только этот интерфейс — в приложении его
/// реализует контроллер, в тестах — запись.
library;

import 'call_e2ee_protocol.dart';

/// Пришедшая команда ключа. Отправителя назвала попарная сессия и подтвердило
/// реле — эти поля не из текста команды.
class InboundRoomCallKeyCommand {
  const InboundRoomCallKeyCommand({
    required this.command,
    required this.senderProfileId,
    required this.senderDeviceId,
    required this.receivedAtMs,
  });

  final RoomCallKeyCommand command;
  final String senderProfileId;
  final String senderDeviceId;
  final int receivedAtMs;
}

/// Что приложение знает об отправителе по своей базе.
class RoomCallKeyPeerFacts {
  const RoomCallKeyPeerFacts({
    required this.deviceBelongsToProfile,
    required this.activeRoomMember,
  });

  /// Устройство числится у профиля в локальном списке устройств.
  final bool deviceBelongsToProfile;

  /// Профиль — действующий член комнаты (не вышел, не забанен).
  final bool activeRoomMember;
}

abstract interface class RoomCallKeyTransport {
  /// Команды ключей, пришедшие по попарным сессиям.
  Stream<InboundRoomCallKeyCommand> get inbound;

  /// Команды, пришедшие раньше, чем созвон начал их слушать (не старше
  /// минуты). Забираются один раз.
  List<InboundRoomCallKeyCommand> drainBuffered({required String callId});

  /// Отправить команду одному устройству. `false` — не ушла.
  Future<bool> send({
    required String peerProfileId,
    required String peerDeviceId,
    required RoomCallKeyCommand command,
  });

  Future<RoomCallKeyPeerFacts> peerFacts({
    required String roomId,
    required String profileId,
    required String deviceId,
  });
}
