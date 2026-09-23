// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

/// Server-signed switch for SENDING room messages under the sender key
/// (F-ROOMSK-2), carried in the additive
/// `rooms` block of `/v1/config`.
///
/// **Why this block exists at all.** On 1.7.4+416 a build shipped with the
/// sender key SENDING, and a peer on an older build could not read the format:
/// it stored the wire invisibly, ACKed it, and every room message was lost
/// permanently. The flag was compile-time, so there was no way to stop it — the
/// only remedy was reinstalling the app on the affected phone. A feature that
/// can destroy messages must be stoppable in minutes, from the server.
///
/// **Failure direction is OFF, like [IdentityFlags] and unlike
/// [ReliabilityFlags].** The reliability switches guard machinery that already
/// shipped and whose absence loses messages, so unauthenticated silence must
/// leave it RUNNING. Sending under the sender key is the opposite: it is new
/// behaviour whose failure mode is silent, permanent loss on the RECIPIENT. So
/// it activates only after this client has seen a VERIFIED block that says so.
/// An unreachable server, an old server without the block, a stripped field or
/// a forged response all leave sending dormant.
///
/// Dormant is cheap and safe: the send path simply falls back to the ordinary
/// pairwise fanout, which every build in existence can read. The feature is a
/// cost optimisation (one seal instead of N×M), never a capability — so the
/// worst case of failing closed is a slightly more expensive send, while the
/// worst case of failing open is somebody's messages.
///
/// This is a KILL-SWITCH, not a remote enable: the compile-time flag must ALSO
/// be on (see `AppController.roomSenderKeySendEnabled`). Two independent keys
/// are required to turn sending on, and either one turns it off.
@immutable
class RoomFlags {
  const RoomFlags({this.senderKeySendEnabled = false});

  /// The dormant state: used whenever the server said nothing we could verify.
  static const RoomFlags defaults = RoomFlags();

  /// Server's permission to SEAL room messages under the sender key. Receiving
  /// is never gated by this — a build that can read `gmsg` always reads it, or
  /// we recreate the 1.7.4+416 loss.
  final bool senderKeySendEnabled;

  /// Reads the flags out of a `/v1/config` response.
  ///
  /// [verified] must be the result of `verifyRoomsSignature` — when it is false
  /// this returns [defaults] and sending stays dormant.
  static RoomFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['rooms'];
    if (payload is! Map) return defaults;
    return RoomFlags(
      senderKeySendEnabled: payload['sender_key_send_enabled'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomFlags &&
          other.senderKeySendEnabled == senderKeySendEnabled;

  @override
  int get hashCode => senderKeySendEnabled.hashCode;

  @override
  String toString() => 'RoomFlags(senderKeySend: $senderKeySendEnabled)';
}

/// Второй подписанный блок комнат, `rooms2` (К-2 / К-5, 17.09.2026).
///
/// Отдельный блок, а не новые поля в `rooms`: подписанный текст того блока
/// заморожен, а выпущенные сборки при несовпадении подписи выключают отправку
/// под ключом комнаты.
///
/// * [rawBroadcastEnabled] — можно отдать реле ОДИН запечатанный провод
///   комнаты для рассылки. Новое поведение, поэтому по умолчанию выключено;
/// * [bigRoomMembers] / [bigRoomMinBuild] — до скольких участников комната
///   растёт сверх тарифа и с какой сборки. Решает реле; здесь — только чтобы
///   показать правильный потолок и объяснить отказ.
@immutable
class Rooms2Flags {
  const Rooms2Flags({
    this.rawBroadcastEnabled = false,
    this.bigRoomMembers = 0,
    this.bigRoomMinBuild = 0,
  });

  static const Rooms2Flags defaults = Rooms2Flags();

  final bool rawBroadcastEnabled;
  final int bigRoomMembers;
  final int bigRoomMinBuild;

  /// Большие комнаты доступны сборке [build], если сервер их включил.
  bool bigRoomsAllowFor(int build) =>
      bigRoomMembers > 0 && bigRoomMinBuild > 0 && build >= bigRoomMinBuild;

  /// [verified] — результат `verifyRooms2Signature`; без него — [defaults].
  static Rooms2Flags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['rooms2'];
    if (payload is! Map) return defaults;
    int readInt(Object? v) => v is num ? v.toInt() : 0;
    return Rooms2Flags(
      rawBroadcastEnabled: payload['raw_broadcast_enabled'] == true,
      bigRoomMembers: readInt(payload['big_room_members']).clamp(0, 100000),
      bigRoomMinBuild: readInt(payload['big_room_min_build']).clamp(0, 1 << 30),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rooms2Flags &&
          other.rawBroadcastEnabled == rawBroadcastEnabled &&
          other.bigRoomMembers == bigRoomMembers &&
          other.bigRoomMinBuild == bigRoomMinBuild;

  @override
  int get hashCode =>
      Object.hash(rawBroadcastEnabled, bigRoomMembers, bigRoomMinBuild);

  @override
  String toString() =>
      'Rooms2Flags(raw: $rawBroadcastEnabled, big: $bigRoomMembers from $bigRoomMinBuild)';
}
