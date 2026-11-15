// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

import '../../app/app_controller.dart';
import 'call_e2ee_protocol.dart';
import 'call_key_transport.dart';

/// [RoomCallKeyTransport] поверх контроллера приложения: попарные сессии,
/// адресно на устройство (ТЗ E2EE созвонов, ЗР-3, ЗР-14).
class AppRoomCallKeyTransport implements RoomCallKeyTransport {
  AppRoomCallKeyTransport(this._controller);

  final AppController _controller;

  @override
  Stream<InboundRoomCallKeyCommand> get inbound =>
      _controller.roomCallKeyCommands;

  @override
  List<InboundRoomCallKeyCommand> drainBuffered({required String callId}) =>
      _controller.drainRoomCallKeyCommandBuffer(callId: callId);

  @override
  Future<bool> send({
    required String peerProfileId,
    required String peerDeviceId,
    required RoomCallKeyCommand command,
  }) => _controller.sendRoomCallKeyCommand(
    peerProfileId: peerProfileId,
    peerDeviceId: peerDeviceId,
    command: command,
  );

  @override
  Future<RoomCallKeyPeerFacts> peerFacts({
    required String roomId,
    required String profileId,
    required String deviceId,
  }) => _controller.roomCallKeyPeerFacts(
    roomId: roomId,
    profileId: profileId,
    deviceId: deviceId,
  );
}
