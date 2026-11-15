// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// ТЗ E2EE созвонов: куда идёт медиа созвона.
// - Открытый созвон (room_media_v1) — прежним путём, без изменений (И-2).
// - Зашифрованный — только своим контроллером; при любой невозможности —
//   закрытый отказ, а не открытое медиа (ЗР-5).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/rooms/call_e2ee/call_e2ee_protocol.dart';
import 'package:secretly_app/rooms/call_e2ee/call_key_transport.dart';
import 'package:secretly_app/rooms/call_e2ee/e2ee_room_call_media_controller.dart';
import 'package:secretly_app/rooms/call_e2ee/room_call_e2ee_status.dart';
import 'package:secretly_app/rooms/room_call_media_controller.dart';
import 'package:secretly_app/rooms/room_call_media_state.dart';
import 'package:secretly_app/transport/relay_client.dart';

class _Transport implements RoomCallKeyTransport {
  final StreamController<InboundRoomCallKeyCommand> controller =
      StreamController<InboundRoomCallKeyCommand>.broadcast();
  final List<RoomCallKeyCommand> sent = <RoomCallKeyCommand>[];

  @override
  Stream<InboundRoomCallKeyCommand> get inbound => controller.stream;

  @override
  List<InboundRoomCallKeyCommand> drainBuffered({required String callId}) =>
      const <InboundRoomCallKeyCommand>[];

  @override
  Future<bool> send({
    required String peerProfileId,
    required String peerDeviceId,
    required RoomCallKeyCommand command,
  }) async {
    sent.add(command);
    return true;
  }

  @override
  Future<RoomCallKeyPeerFacts> peerFacts({
    required String roomId,
    required String profileId,
    required String deviceId,
  }) async => const RoomCallKeyPeerFacts(
    deviceBelongsToProfile: true,
    activeRoomMember: true,
  );
}

RelayRoomCallMediaSession _session({
  required String contract,
  String? identity,
  String selfProfile = 'prof-me',
  String selfDevice = 'dev-me',
}) => RelayRoomCallMediaSession.fromJson(<String, dynamic>{
  'room_id': 'room-1',
  'call_id': 'call-1',
  'contract_version': contract,
  'capability_state': 'runtime_ready',
  'self_profile_id': selfProfile,
  'self_device_id': selfDevice,
  'backend': <String, dynamic>{
    'kind': 'livekit',
    'url': 'wss://example.invalid/livekit',
    'room_name': 'secretly-room-x',
    'participant_identity':
        identity ?? roomMediaParticipantIdentity(selfProfile, selfDevice),
    'access_token': 'token',
  },
  'participants': <Object?>[
    <String, dynamic>{
      'profile_id': selfProfile,
      'device_id': selfDevice,
      'join_state': 'joined',
      'is_self': true,
      'publish_audio': true,
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('открытый созвон — прежний путь, шифрования нет и не обещается', () {
    final controller = DefaultRoomCallMediaController(
      e2eeTransport: _Transport(),
    );
    // Сам LiveKit в тестах не подключится — важно, что состояние шифрования
    // так и осталось «нет».
    unawaited(
      controller
          .syncSession(session: _session(contract: kRoomMediaContractV1))
          .catchError((Object _) {}),
    );
    expect(controller.e2eeStatus.value, isNull);
  });

  test(
    '🔴 зашифрованный созвон без транспорта ключей — закрытый отказ',
    () async {
      final controller = DefaultRoomCallMediaController();
      await controller.syncSession(
        session: _session(contract: kRoomMediaContractE2eeV1),
      );
      final status = controller.e2eeStatus.value;
      expect(status, isNotNull);
      expect(status!.own, RoomCallE2eeOwnState.failed);
      expect(status.errorCode, 'transport_unavailable');
      expect(controller.state.value.phase, RoomCallLocalMediaPhase.failed);
      await controller.dispose();
    },
  );

  test('🔴 платформа не умеет шифровать — в созвон не входим', () async {
    final e2ee = E2eeLiveKitRoomCallMediaController(
      transport: _Transport(),
      platformSupported: () => false,
    );
    await e2ee.syncSession(
      session: _session(contract: kRoomMediaContractE2eeV1),
    );
    expect(e2ee.e2eeStatus.value?.errorCode, 'platform_unsupported');
    expect(e2ee.state.value.phase, RoomCallLocalMediaPhase.failed);
    await e2ee.dispose();
  });

  test('🔴 реле выдало чужую идентичность — в созвон не входим', () async {
    final e2ee = E2eeLiveKitRoomCallMediaController(
      transport: _Transport(),
      platformSupported: () => true,
    );
    await e2ee.syncSession(
      session: _session(
        contract: kRoomMediaContractE2eeV1,
        identity: roomMediaParticipantIdentity('prof-other', 'dev-other'),
      ),
    );
    expect(e2ee.e2eeStatus.value?.errorCode, 'identity_mismatch');
    await e2ee.dispose();
  });

  test('🔴 открытый контракт в зашифрованном контроллере — отказ', () async {
    final e2ee = E2eeLiveKitRoomCallMediaController(
      transport: _Transport(),
      platformSupported: () => true,
    );
    await e2ee.syncSession(session: _session(contract: kRoomMediaContractV1));
    expect(e2ee.e2eeStatus.value?.errorCode, 'contract_mismatch');
    await e2ee.dispose();
  });

  test(
    'натив недоступен (нет FrameCryptor) — отказ, а не открытое медиа',
    () async {
      final e2ee = E2eeLiveKitRoomCallMediaController(
        transport: _Transport(),
        platformSupported: () => true,
      );
      await e2ee.syncSession(
        session: _session(contract: kRoomMediaContractE2eeV1),
      );
      // В тестах плагина WebRTC нет: провайдер ключей не создаётся, и созвон
      // обязан встать в ошибку, не подключая LiveKit без шифрования.
      expect(e2ee.state.value.phase, RoomCallLocalMediaPhase.failed);
      expect(
        e2ee.e2eeStatus.value?.own,
        isNot(RoomCallE2eeOwnState.encrypting),
      );
      await e2ee.dispose();
    },
  );
}
