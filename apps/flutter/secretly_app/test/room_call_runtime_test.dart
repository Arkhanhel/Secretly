// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/rooms/room_call_manager.dart';
import 'package:secretly_app/rooms/room_call_media_controller.dart';
import 'package:secretly_app/rooms/room_call_media_signal_codec.dart';
import 'package:secretly_app/rooms/room_call_media_state.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';

class _FakeRoomCallMediaControllerFactory
    implements RoomCallMediaControllerFactory {
  final List<_FakeRoomCallMediaController> createdControllers =
      <_FakeRoomCallMediaController>[];

  @override
  RoomCallMediaController create() {
    final controller = _FakeRoomCallMediaController();
    createdControllers.add(controller);
    return controller;
  }
}

class _FakeRoomCallMediaController implements RoomCallMediaController {
  final ValueNotifier<RoomCallLocalMediaState> _state = ValueNotifier(
    const RoomCallLocalMediaState.idle(),
  );
  final Set<String> cameraViewDeviceIds = <String>{};
  final Set<String> screenShareViewDeviceIds = <String>{};
  final Set<String> speakingDeviceIds = <String>{};

  RelayRoomCallMediaSession? lastSession;
  bool disposed = false;

  @override
  ValueListenable<RoomCallLocalMediaState> get state => _state;

  @override
  RTCVideoRenderer? get localRenderer => null;

  @override
  bool hasParticipantCameraView(String deviceId) {
    return cameraViewDeviceIds.contains(deviceId.trim());
  }

  @override
  bool hasParticipantScreenShareView(String deviceId) {
    return screenShareViewDeviceIds.contains(deviceId.trim());
  }

  @override
  bool isParticipantSpeaking(String deviceId) {
    return speakingDeviceIds.contains(deviceId.trim());
  }

  // Добавочное движку не нужно: подделка проверяет управление созвоном, а не
  // перечисление камер. Возвращаем «не знаю» — ровно то же, что вернул бы
  // движок без такой возможности.
  @override
  Future<List<RoomCallVideoDevice>> videoInputs() async =>
      const <RoomCallVideoDevice>[];

  @override
  String? get selectedVideoInputId => null;

  @override
  Future<void> selectVideoInput(String deviceId) async {}

  @override
  Future<List<RoomCallVideoDevice>> audioInputs() async =>
      const <RoomCallVideoDevice>[];

  @override
  String? get selectedAudioInputId => null;

  @override
  Future<void> selectAudioInput(String deviceId) async {}

  @override
  Future<RoomCallVideoStats?> videoStats({
    required String deviceId,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) async => null;

  @override
  double participantAudioLevel(String deviceId) => 0;

  @override
  Widget? buildParticipantVideoView({
    required String deviceId,
    bool mirror = false,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) {
    if (!hasParticipantCameraView(deviceId) &&
        !hasParticipantScreenShareView(deviceId)) {
      return null;
    }
    return const SizedBox.shrink();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _state.dispose();
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    _state.value = _state.value.copyWith(speakerEnabled: enabled);
  }

  @override
  Future<void> switchCamera() async {
    _state.value = _state.value.copyWith(
      usingFrontCamera: !_state.value.usingFrontCamera,
    );
  }

  @override
  Future<void> syncSession({required RelayRoomCallMediaSession session}) async {
    lastSession = session;
    final self = session.selfParticipant;
    cameraViewDeviceIds
      ..clear()
      ..addAll(
        self?.publishVideo == true
            ? <String>{session.selfDeviceId}
            : const <String>{},
      );
    screenShareViewDeviceIds
      ..clear()
      ..addAll(
        self?.publishScreenShare == true
            ? <String>{session.selfDeviceId}
            : const <String>{},
      );
    _state.value = RoomCallLocalMediaState(
      phase: RoomCallLocalMediaPhase.ready,
      audioCaptureActive: self?.publishAudio ?? false,
      videoCaptureActive: self?.publishVideo ?? false,
      screenShareActive: self?.publishScreenShare ?? false,
      localPreviewAvailable:
          (self?.publishVideo ?? false) || (self?.publishScreenShare ?? false),
      speakerEnabled: true,
      usingFrontCamera: true,
      runtimeConnected: false,
      runtimeReconnecting: false,
      runtimeRevision: _state.value.runtimeRevision + 1,
      errorMessage: null,
    );
  }

  void setParticipantViews({
    Iterable<String> cameraDeviceIds = const <String>[],
    Iterable<String> screenShareDeviceIds = const <String>[],
    bool runtimeConnected = false,
    bool runtimeReconnecting = false,
  }) {
    cameraViewDeviceIds
      ..clear()
      ..addAll(
        cameraDeviceIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    screenShareViewDeviceIds
      ..clear()
      ..addAll(
        screenShareDeviceIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    _state.value = _state.value.copyWith(
      runtimeConnected: runtimeConnected,
      runtimeReconnecting: runtimeReconnecting,
      runtimeRevision: _state.value.runtimeRevision + 1,
    );
  }
}

Future<RelayClient> _buildRelayClient({
  required AppDb db,
  required http.Client httpClient,
  required SimpleKeyPair identityKeyPair,
  String deviceId = 'owner-device',
  String selfProfileId = 'owner-1',
}) async {
  return RelayClient(
    db: db,
    deviceId: deviceId,
    selfProfileId: selfProfileId,
    deviceKeys: DeviceKeys.create(),
    wsUrl: Uri.parse('ws://example.test/ws'),
    httpBaseUrl: Uri.parse('https://example.test'),
    httpClient: httpClient,
    identityKeyPairOverride: identityKeyPair,
    onDelivered: ({required msgId, required ciphertextB64}) async => true,
    loadNextSeq: () async => 1,
    saveNextSeq: (_) async {},
    // Inject a throwing connector so `connect()` (called by triggerPushWakeSync)
    // and its background `_scheduleReconnect` never attempt a real WebSocket
    // under the test binding — matching the fake-socket pattern used by the
    // other relay tests. Without this the real `WebSocket.connect` throws a
    // "Mocked response" error from a retry timer, surfacing as an unhandled
    // async failure even though the asserted HTTP calls succeed.
    webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
        throw StateError('no websocket in this test'),
  );
}

Map<String, Object?> _relayRoomJson({
  required String roomId,
  String ownerProfileId = 'owner-1',
  String createdByDeviceId = 'owner-device',
  String title = 'Alpha Room',
  int version = 1,
  int membershipVersion = 1,
}) {
  return <String, Object?>{
    'room_id': roomId,
    'version': version,
    'membership_version': membershipVersion,
    'owner_profile_id': ownerProfileId,
    'created_by_device_id': createdByDeviceId,
    'title': title,
    'description': null,
    'avatar_hash': null,
    'avatar_image_b64': null,
    'reactions_mode': 'all',
    'allow_text': true,
    'allow_media': true,
    'allow_add_members': true,
    'allow_pin_messages': true,
    'allow_change_group_info': true,
    'allow_change_tag': false,
    'join_approval_required': false,
    'slow_mode_seconds': 0,
    'chat_history_visible': false,
    'pinned_message_id': null,
    'created_at_ms': 1000,
    'updated_at_ms': 2000,
  };
}

Map<String, Object?> _relayRoomCallJson({
  required String roomId,
  required String callId,
  String state = 'active',
  String mediaType = 'audio',
  String createdByProfileId = 'owner-1',
  String createdByDeviceId = 'owner-device',
  int stateVersion = 1,
  int startedAtMs = 1000,
  int updatedAtMs = 2000,
  int? endedAtMs,
  int expiresAtMs = 9000,
}) {
  return <String, Object?>{
    'call_id': callId,
    'room_id': roomId,
    'state': state,
    'media_type': mediaType,
    'created_by_profile_id': createdByProfileId,
    'created_by_device_id': createdByDeviceId,
    'state_version': stateVersion,
    'started_at_ms': startedAtMs,
    'updated_at_ms': updatedAtMs,
    'ended_at_ms': endedAtMs,
    'expires_at_ms': expiresAtMs,
  };
}

Map<String, Object?> _relayRoomCallParticipantJson({
  required String roomId,
  required String callId,
  required String profileId,
  required String deviceId,
  String joinState = 'joined',
  bool supportsVideo = false,
  bool supportsScreenShare = false,
  bool muted = false,
  bool deafened = false,
  bool videoEnabled = false,
  bool screenShareEnabled = false,
  bool speaking = false,
  int joinedAtMs = 1000,
  int? leftAtMs,
  int updatedAtMs = 2000,
}) {
  return <String, Object?>{
    'call_id': callId,
    'room_id': roomId,
    'profile_id': profileId,
    'device_id': deviceId,
    'join_state': joinState,
    'supports_video': supportsVideo,
    'supports_screen_share': supportsScreenShare,
    'muted': muted,
    'deafened': deafened,
    'video_enabled': videoEnabled,
    'screen_share_enabled': screenShareEnabled,
    'speaking': speaking,
    'joined_at_ms': joinedAtMs,
    'left_at_ms': leftAtMs,
    'updated_at_ms': updatedAtMs,
  };
}

String _roomCallSnapshotJson({
  required bool exists,
  required Map<String, Object?> room,
  Map<String, Object?>? call,
  List<Map<String, Object?>> participants = const <Map<String, Object?>>[],
  Map<String, Object?>? selfParticipant,
}) {
  return jsonEncode(<String, Object?>{
    'exists': exists,
    'room': room,
    'call': call,
    'participants': participants,
    'self_participant': selfParticipant,
  });
}

String _roomCallMutationJson({
  required Map<String, Object?> room,
  required Map<String, Object?> call,
  List<Map<String, Object?>> participants = const <Map<String, Object?>>[],
  Map<String, Object?>? selfParticipant,
  bool changed = true,
}) {
  return jsonEncode(<String, Object?>{
    'ok': true,
    'changed': changed,
    'room': room,
    'call': call,
    'participants': participants,
    'self_participant': selfParticipant,
  });
}

Map<String, Object?> _roomCallMediaParticipantJson({
  required String profileId,
  required String deviceId,
  String joinState = 'joined',
  bool isSelf = false,
  bool supportsVideo = false,
  bool supportsScreenShare = false,
  bool muted = false,
  bool deafened = false,
  bool videoEnabled = false,
  bool screenShareEnabled = false,
  bool speaking = false,
  bool publishAudio = true,
  bool publishVideo = false,
  bool publishScreenShare = false,
  bool receiveAudio = true,
  bool receiveVideo = true,
  bool receiveScreenShare = true,
  int updatedAtMs = 2000,
}) {
  return <String, Object?>{
    'profile_id': profileId,
    'device_id': deviceId,
    'join_state': joinState,
    'is_self': isSelf,
    'supports_video': supportsVideo,
    'supports_screen_share': supportsScreenShare,
    'muted': muted,
    'deafened': deafened,
    'video_enabled': videoEnabled,
    'screen_share_enabled': screenShareEnabled,
    'speaking': speaking,
    'publish_audio': publishAudio,
    'publish_video': publishVideo,
    'publish_screen_share': publishScreenShare,
    'receive_audio': receiveAudio,
    'receive_video': receiveVideo,
    'receive_screen_share': receiveScreenShare,
    'updated_at_ms': updatedAtMs,
  };
}

Map<String, Object?> _roomCallMediaBackendJson({
  String kind = 'unavailable',
  String? url,
  String? roomName,
  String? participantIdentity,
  String? accessToken,
  int? accessTokenExpiresAtMs,
}) {
  return <String, Object?>{
    'kind': kind,
    'url': url,
    'room_name': roomName,
    'participant_identity': participantIdentity,
    'access_token': accessToken,
    'access_token_expires_at_ms': accessTokenExpiresAtMs,
  };
}

String _roomCallMediaJson({
  required String roomId,
  required String callId,
  List<Map<String, Object?>> participants = const <Map<String, Object?>>[],
  String capabilityState = 'bootstrap_only',
  String mediaType = 'audio',
  int stateVersion = 1,
  int? descriptorVersion,
  String selfProfileId = 'owner-1',
  String selfDeviceId = 'owner-device',
  bool publishVideoSupported = true,
  bool publishScreenShareSupported = true,
  bool subscribeAllSupported = true,
  Map<String, Object?>? backend,
}) {
  return jsonEncode(<String, Object?>{
    'room_id': roomId,
    'call_id': callId,
    'session_id': callId,
    'contract_version': 'room_media_v1',
    'topology': 'centralized',
    'capability_state': capabilityState,
    'media_type': mediaType,
    'state_version': stateVersion,
    'self_profile_id': selfProfileId,
    'self_device_id': selfDeviceId,
    'participant_count': participants.length,
    'publish_video_supported': publishVideoSupported,
    'publish_screen_share_supported': publishScreenShareSupported,
    'subscribe_all_supported': subscribeAllSupported,
    'backend': backend ?? _roomCallMediaBackendJson(),
    'signal': <String, Object?>{
      'transport_kind': 'room_call_media_signal_v1',
      'descriptor_version': descriptorVersion ?? stateVersion,
    },
    'ice': <String, Object?>{
      'policy': 'relay_preferred',
      'expires_at_ms': 65000,
      'ice_servers': const <Map<String, Object?>>[
        <String, Object?>{
          'urls': <String>['turn:relay.example.test:3478'],
          'username': 'turn-user',
          'credential': 'turn-pass',
        },
      ],
    },
    'participants': participants,
  });
}

String _roomCallMediaJoinJson({
  required String roomId,
  required String callId,
  List<Map<String, Object?>> participants = const <Map<String, Object?>>[],
  String capabilityState = 'bootstrap_only',
  String mediaType = 'audio',
  int stateVersion = 1,
  int? descriptorVersion,
  String selfProfileId = 'owner-1',
  String selfDeviceId = 'owner-device',
  Map<String, Object?>? backend,
}) {
  return jsonEncode(<String, Object?>{
    'ok': true,
    'media': jsonDecode(
      _roomCallMediaJson(
        roomId: roomId,
        callId: callId,
        participants: participants,
        capabilityState: capabilityState,
        mediaType: mediaType,
        stateVersion: stateVersion,
        descriptorVersion: descriptorVersion,
        selfProfileId: selfProfileId,
        selfDeviceId: selfDeviceId,
        backend: backend,
      ),
    ),
  });
}

Future<bool> _deliverInboundControl({
  required AppController controller,
  required AppDb db,
  required String transportMsgId,
  required String payloadEventId,
  required String controlText,
  required String senderDeviceId,
  required String senderProfileId,
  required int payloadCreatedAtMs,
  required int receivedAtMs,
}) {
  final payload = E2ePayloadV1(
    senderDeviceId: senderDeviceId,
    createdAtMs: payloadCreatedAtMs,
    events: [MsgEventV1(eventId: payloadEventId, text: controlText)],
  );

  return controller.handleDecryptedInboundPayloadForTesting(
    db: db,
    msgId: transportMsgId,
    ciphertextB64: 'AA==',
    plainBytes: Uint8List.fromList(payload.encode()),
    payload: payload,
    senderDeviceId: senderDeviceId,
    senderProfileId: senderProfileId,
    nowMs: receivedAtMs,
  );
}

Future<void> _seedCachedRoomCall({
  required AppDb db,
  required String roomId,
  required String callId,
  required int stateVersion,
  String state = 'active',
  int startedAtMs = 1000,
  int updatedAtMs = 2000,
  int expiresAtMs = 9000,
}) {
  return db.roomCallSnapshotReplace(
    groupId: roomId,
    callId: callId,
    state: state,
    mediaType: 'audio',
    createdByProfileId: 'owner-1',
    createdByDeviceId: 'owner-device',
    stateVersion: stateVersion,
    startedAtMs: startedAtMs,
    updatedAtMs: updatedAtMs,
    expiresAtMs: expiresAtMs,
    participants: const <RoomCallParticipantStateRecord>[
      (
        profileId: 'owner-1',
        deviceId: 'owner-device',
        joinState: 'joined',
        supportsVideo: false,
        supportsScreenShare: false,
        muted: false,
        deafened: false,
        videoEnabled: false,
        screenShareEnabled: false,
        speaking: false,
        joinedAtMs: 1000,
        leftAtMs: null,
        updatedAtMs: 2000,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('room call runtime foundation', () {
    test(
      'room media descriptor signals are dispatched once per signal id',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );

        final events = <RoomCallMediaSignalEvent>[];
        final sub = controller.roomCallMediaSignals.listen(events.add);

        try {
          final controlText =
              RoomCallMediaSignalCommandCodec.encode(<String, Object?>{
                'v': 1,
                'action': 'descriptor_updated',
                'roomId': 'group:alpha',
                'callId': 'call-1',
                'sessionId': 'call-1',
                'descriptorVersion': 11,
                'stateVersion': 4,
                'reason': 'bootstrap_join',
                'signalId': 'room-media-signal-1',
                'createdAtMs': 3000,
              });

          final first = await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-room-media-1',
            payloadEventId: 'payload-room-media-1',
            controlText: controlText,
            senderDeviceId: 'peer-device',
            senderProfileId: 'peer-1',
            payloadCreatedAtMs: 3000,
            receivedAtMs: 3050,
          );
          final second = await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-room-media-2',
            payloadEventId: 'payload-room-media-2',
            controlText: controlText,
            senderDeviceId: 'peer-device',
            senderProfileId: 'peer-1',
            payloadCreatedAtMs: 3000,
            receivedAtMs: 3100,
          );

          expect(first, isTrue);
          expect(second, isTrue);
          expect(events, hasLength(1));
          expect(events.single.action, 'descriptor_updated');
          expect(events.single.roomId, 'group:alpha');
          expect(events.single.callId, 'call-1');
          expect(events.single.descriptorVersion, 11);
          expect(events.single.stateVersion, 4);
          expect(events.single.fromDeviceId, 'peer-device');
        } finally {
          await sub.cancel();
          await db.close();
        }
      },
    );

    test('room-call sync hint skips unchanged cached call state', () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final identityKeyPair = await Ed25519().newKeyPair();
      final requests = <String>[];
      final relay = await _buildRelayClient(
        db: db,
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          return http.Response('unexpected', 500);
        }),
        identityKeyPair: identityKeyPair,
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );
      controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

      try {
        await _seedCachedRoomCall(
          db: db,
          roomId: 'group:alpha',
          callId: 'call-1',
          stateVersion: 3,
        );

        final delivered = await _deliverInboundControl(
          controller: controller,
          db: db,
          transportMsgId: 'transport-room-call-sync-skip',
          payloadEventId: 'payload-room-call-sync-skip',
          controlText:
              AppController.encodeRoomInviteCommandForTesting(<String, Object?>{
                'v': 1,
                'action': 'room_call_sync',
                'groupId': 'group:alpha',
                'callExists': true,
                'callId': 'call-1',
                'stateVersion': 3,
              }),
          senderDeviceId: 'peer-device',
          senderProfileId: 'peer-1',
          payloadCreatedAtMs: 5000,
          receivedAtMs: 6000,
        );

        expect(delivered, isTrue);
        expect(requests, isEmpty);

        final cached = await controller.getCachedRoomCall('group:alpha');
        expect(cached, isNotNull);
        expect(cached!.callId, 'call-1');
        expect(cached.stateVersion, 3);
      } finally {
        await db.close();
      }
    });

    test(
      'room-call sync hint refreshes stale active cache from relay',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final requests = <String>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'GET' &&
                request.url.path == '/v1/rooms/group%3Aalpha/call') {
              final room = _relayRoomJson(roomId: 'group:alpha');
              final call = _relayRoomCallJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                stateVersion: 5,
                updatedAtMs: 5000,
              );
              final owner = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinedAtMs: 1000,
                updatedAtMs: 5000,
              );
              final peer = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'peer-1',
                deviceId: 'peer-device',
                joinedAtMs: 1200,
                updatedAtMs: 4800,
              );
              return http.Response(
                _roomCallSnapshotJson(
                  exists: true,
                  room: room,
                  call: call,
                  participants: <Map<String, Object?>>[owner, peer],
                  selfParticipant: owner,
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          await _seedCachedRoomCall(
            db: db,
            roomId: 'group:alpha',
            callId: 'call-1',
            stateVersion: 1,
          );

          final delivered = await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-room-call-sync-refresh',
            payloadEventId: 'payload-room-call-sync-refresh',
            controlText: AppController.encodeRoomInviteCommandForTesting(
              <String, Object?>{
                'v': 1,
                'action': 'room_call_sync',
                'groupId': 'group:alpha',
                'callExists': true,
                'callId': 'call-1',
                'stateVersion': 5,
              },
            ),
            senderDeviceId: 'peer-device',
            senderProfileId: 'peer-1',
            payloadCreatedAtMs: 5000,
            receivedAtMs: 6000,
          );

          expect(delivered, isTrue);
          expect(requests, <String>['GET /v1/rooms/group%3Aalpha/call']);

          final cached = await controller.getCachedRoomCall('group:alpha');
          expect(cached, isNotNull);
          expect(cached!.callId, 'call-1');
          expect(cached.stateVersion, 5);
          expect(cached.joinedParticipantCount, 2);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'room-call sync hint clears stale cache when relay reports no call',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final requests = <String>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'GET' &&
                request.url.path == '/v1/rooms/group%3Aalpha/call') {
              return http.Response(
                _roomCallSnapshotJson(
                  exists: false,
                  room: _relayRoomJson(roomId: 'group:alpha'),
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          await _seedCachedRoomCall(
            db: db,
            roomId: 'group:alpha',
            callId: 'call-1',
            stateVersion: 2,
          );

          final delivered = await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-room-call-sync-clear',
            payloadEventId: 'payload-room-call-sync-clear',
            controlText: AppController.encodeRoomInviteCommandForTesting(
              <String, Object?>{
                'v': 1,
                'action': 'room_call_sync',
                'groupId': 'group:alpha',
                'callExists': false,
                'callId': 'call-1',
                'stateVersion': 3,
              },
            ),
            senderDeviceId: 'peer-device',
            senderProfileId: 'peer-1',
            payloadCreatedAtMs: 5000,
            receivedAtMs: 6000,
          );

          expect(delivered, isTrue);
          expect(requests, <String>['GET /v1/rooms/group%3Aalpha/call']);
          expect(await controller.getCachedRoomCall('group:alpha'), isNull);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'push wake sync refreshes hinted room-call snapshots from relay',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final requests = <String>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'GET' &&
                request.url.path == '/v1/rooms/group%3Aalpha/call') {
              final room = _relayRoomJson(roomId: 'group:alpha');
              final call = _relayRoomCallJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                stateVersion: 6,
                updatedAtMs: 6100,
              );
              final owner = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinedAtMs: 1000,
                updatedAtMs: 6100,
              );
              final peer = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'peer-1',
                deviceId: 'peer-device',
                joinedAtMs: 1300,
                updatedAtMs: 6050,
              );
              return http.Response(
                _roomCallSnapshotJson(
                  exists: true,
                  room: room,
                  call: call,
                  participants: <Map<String, Object?>>[owner, peer],
                  selfParticipant: owner,
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          await _seedCachedRoomCall(
            db: db,
            roomId: 'group:alpha',
            callId: 'call-1',
            stateVersion: 1,
          );

          await controller.triggerPushWakeSync(
            roomCallRoomIds: const <String>['group:alpha'],
          );

          expect(requests, <String>[
            'GET /v1/pending/owner-device',
            'GET /v1/rooms/group%3Aalpha/call',
          ]);

          final cached = await controller.getCachedRoomCall('group:alpha');
          expect(cached, isNotNull);
          expect(cached!.callId, 'call-1');
          expect(cached.stateVersion, 6);
          expect(cached.joinedParticipantCount, 2);
        } finally {
          await db.close();
        }
      },
    );

    test('AppDb stores and replaces room-call snapshots', () async {
      final db = await AppDb.openForTesting();

      try {
        await db.roomCallSnapshotReplace(
          groupId: 'group:alpha',
          callId: 'call-1',
          state: 'active',
          mediaType: 'audio',
          createdByProfileId: 'owner-1',
          createdByDeviceId: 'owner-device',
          stateVersion: 3,
          startedAtMs: 1000,
          updatedAtMs: 2000,
          expiresAtMs: 9000,
          participants: const <RoomCallParticipantStateRecord>[
            (
              profileId: 'owner-1',
              deviceId: 'owner-device',
              joinState: 'joined',
              supportsVideo: true,
              supportsScreenShare: false,
              muted: false,
              deafened: false,
              videoEnabled: true,
              screenShareEnabled: false,
              speaking: true,
              joinedAtMs: 1000,
              leftAtMs: null,
              updatedAtMs: 2000,
            ),
            (
              profileId: 'peer-1',
              deviceId: 'peer-device',
              joinState: 'reconnecting',
              supportsVideo: false,
              supportsScreenShare: false,
              muted: true,
              deafened: false,
              videoEnabled: false,
              screenShareEnabled: false,
              speaking: false,
              joinedAtMs: 1100,
              leftAtMs: null,
              updatedAtMs: 2100,
            ),
          ],
        );

        final stored = await db.roomCallSnapshotGet('group:alpha');
        expect(stored, isNotNull);
        expect(stored!.callId, 'call-1');
        expect(stored.stateVersion, 3);
        expect(stored.participants, hasLength(2));
        expect(stored.participants.last.joinState, 'reconnecting');
        expect(await db.roomCallActiveGroupIdsList(), const <String>[
          'group:alpha',
        ]);

        await db.roomCallSnapshotReplace(
          groupId: 'group:alpha',
          callId: 'call-2',
          state: 'active',
          mediaType: 'video',
          createdByProfileId: 'owner-1',
          createdByDeviceId: 'owner-device',
          stateVersion: 4,
          startedAtMs: 3000,
          updatedAtMs: 4000,
          expiresAtMs: 12000,
          participants: const <RoomCallParticipantStateRecord>[
            (
              profileId: 'owner-1',
              deviceId: 'owner-device',
              joinState: 'joined',
              supportsVideo: true,
              supportsScreenShare: false,
              muted: false,
              deafened: false,
              videoEnabled: true,
              screenShareEnabled: false,
              speaking: false,
              joinedAtMs: 3000,
              leftAtMs: null,
              updatedAtMs: 4000,
            ),
          ],
        );

        final replaced = await db.roomCallSnapshotGet('group:alpha');
        expect(replaced, isNotNull);
        expect(replaced!.callId, 'call-2');
        expect(replaced.mediaType, 'video');
        expect(replaced.participants, hasLength(1));

        await db.roomCallSnapshotDelete('group:alpha');

        expect(await db.roomCallSnapshotGet('group:alpha'), isNull);
        expect(await db.roomCallActiveGroupIdsList(), isEmpty);
      } finally {
        await db.close();
      }
    });

    test(
      'controller lists active cached room calls and filters self joined',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );

        try {
          await db.roomCallSnapshotReplace(
            groupId: 'group:alpha',
            callId: 'call-1',
            state: 'active',
            mediaType: 'audio',
            createdByProfileId: 'owner-1',
            createdByDeviceId: 'owner-device',
            stateVersion: 2,
            startedAtMs: 1000,
            updatedAtMs: 7000,
            expiresAtMs: 9000,
            participants: const <RoomCallParticipantStateRecord>[
              (
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinState: 'joined',
                supportsVideo: true,
                supportsScreenShare: true,
                muted: false,
                deafened: false,
                videoEnabled: false,
                screenShareEnabled: false,
                speaking: true,
                joinedAtMs: 1000,
                leftAtMs: null,
                updatedAtMs: 7000,
              ),
            ],
          );
          await db.roomCallSnapshotReplace(
            groupId: 'group:beta',
            callId: 'call-2',
            state: 'active',
            mediaType: 'video',
            createdByProfileId: 'peer-1',
            createdByDeviceId: 'peer-device',
            stateVersion: 3,
            startedAtMs: 2000,
            updatedAtMs: 5000,
            expiresAtMs: 9000,
            participants: const <RoomCallParticipantStateRecord>[
              (
                profileId: 'peer-1',
                deviceId: 'peer-device',
                joinState: 'joined',
                supportsVideo: true,
                supportsScreenShare: false,
                muted: false,
                deafened: false,
                videoEnabled: true,
                screenShareEnabled: false,
                speaking: false,
                joinedAtMs: 2000,
                leftAtMs: null,
                updatedAtMs: 5000,
              ),
            ],
          );

          final allCalls = await controller.listCachedActiveRoomCalls();
          final selfJoinedCalls = await controller.listCachedActiveRoomCalls(
            selfJoinedOnly: true,
          );
          final primary = await controller.getPrimarySelfJoinedCachedRoomCall();

          expect(allCalls.map((call) => call.roomId), <String>[
            'group:alpha',
            'group:beta',
          ]);
          expect(selfJoinedCalls.map((call) => call.roomId), <String>[
            'group:alpha',
          ]);
          expect(primary?.roomId, 'group:alpha');
          expect(primary?.selfParticipant?.speaking, isTrue);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'controller caches authoritative room-call join update and leave',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final requests = <String>[];
        final room = _relayRoomJson(roomId: 'group:alpha');
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'POST' &&
                request.url.path == '/v1/rooms/group%3Aalpha/call') {
              final call = _relayRoomCallJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                mediaType: 'video',
                stateVersion: 1,
              );
              final selfParticipant = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'owner-1',
                deviceId: 'owner-device',
                supportsVideo: true,
                videoEnabled: true,
              );
              return http.Response(
                _roomCallMutationJson(
                  room: room,
                  call: call,
                  participants: <Map<String, Object?>>[selfParticipant],
                  selfParticipant: selfParticipant,
                ),
                200,
              );
            }
            if (request.method == 'POST' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/self') {
              final call = _relayRoomCallJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                mediaType: 'video',
                stateVersion: 2,
                updatedAtMs: 3000,
              );
              final selfParticipant = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinState: 'reconnecting',
                supportsVideo: true,
                muted: true,
                videoEnabled: true,
                speaking: true,
                updatedAtMs: 3000,
              );
              final peerParticipant = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'peer-1',
                deviceId: 'peer-device',
                joinedAtMs: 1200,
                updatedAtMs: 2500,
              );
              return http.Response(
                _roomCallMutationJson(
                  room: room,
                  call: call,
                  participants: <Map<String, Object?>>[
                    selfParticipant,
                    peerParticipant,
                  ],
                  selfParticipant: selfParticipant,
                ),
                200,
              );
            }
            if (request.method == 'POST' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/leave') {
              final call = _relayRoomCallJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                state: 'ended',
                mediaType: 'video',
                stateVersion: 3,
                updatedAtMs: 4000,
                endedAtMs: 4000,
              );
              return http.Response(
                _roomCallMutationJson(
                  room: room,
                  call: call,
                  participants: const <Map<String, Object?>>[],
                  selfParticipant: null,
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          final joined = await controller.joinRelayRoomCall(
            roomId: 'group:alpha',
            mediaType: 'video',
            supportsVideo: true,
            videoEnabled: true,
          );

          expect(joined, isNotNull);

          final joinedCache = await controller.getCachedRoomCall('group:alpha');
          expect(joinedCache, isNotNull);
          expect(joinedCache!.mediaType, 'video');
          expect(joinedCache.selfParticipant, isNotNull);
          expect(joinedCache.selfParticipant!.videoEnabled, isTrue);

          final updated = await controller.updateRelayRoomCallParticipant(
            roomId: 'group:alpha',
            callId: 'call-1',
            reconnecting: true,
            muted: true,
            videoEnabled: true,
            speaking: true,
          );

          expect(updated, isNotNull);

          final updatedCache = await controller.getCachedRoomCall(
            'group:alpha',
          );
          expect(updatedCache, isNotNull);
          expect(updatedCache!.stateVersion, 2);
          expect(updatedCache.joinedParticipantCount, 2);
          expect(updatedCache.selfParticipant, isNotNull);
          expect(updatedCache.selfParticipant!.isReconnecting, isTrue);
          expect(updatedCache.selfParticipant!.muted, isTrue);
          expect(updatedCache.selfParticipant!.speaking, isTrue);

          final left = await controller.leaveRelayRoomCall(
            roomId: 'group:alpha',
            callId: 'call-1',
          );

          expect(left, isNotNull);
          expect(await controller.getCachedRoomCall('group:alpha'), isNull);
          expect(requests, <String>[
            'POST /v1/rooms/group%3Aalpha/call',
            'POST /v1/rooms/group%3Aalpha/call/call-1/self',
            'GET /v1/rooms/group%3Aalpha/call/call-1/media',
            'POST /v1/rooms/group%3Aalpha/call/call-1/leave',
          ]);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'controller caches authoritative room-call participant removal and end',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final requests = <String>[];
        final room = _relayRoomJson(roomId: 'group:alpha');
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'POST' &&
                request.url.path == '/v1/rooms/group%3Aalpha/call') {
              final call = _relayRoomCallJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                mediaType: 'video',
                stateVersion: 1,
              );
              final selfParticipant = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'owner-1',
                deviceId: 'owner-device',
                supportsVideo: true,
                videoEnabled: true,
              );
              final peerParticipant = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'peer-1',
                deviceId: 'peer-device',
                joinedAtMs: 1200,
                updatedAtMs: 2200,
              );
              return http.Response(
                _roomCallMutationJson(
                  room: room,
                  call: call,
                  participants: <Map<String, Object?>>[
                    selfParticipant,
                    peerParticipant,
                  ],
                  selfParticipant: selfParticipant,
                ),
                200,
              );
            }
            if (request.method == 'POST' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/participants/peer-device/remove') {
              final call = _relayRoomCallJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                mediaType: 'video',
                stateVersion: 2,
                updatedAtMs: 3000,
              );
              final selfParticipant = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'owner-1',
                deviceId: 'owner-device',
                supportsVideo: true,
                videoEnabled: true,
                updatedAtMs: 3000,
              );
              final peerParticipant = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'peer-1',
                deviceId: 'peer-device',
                joinState: 'left',
                leftAtMs: 3000,
                updatedAtMs: 3000,
              );
              return http.Response(
                _roomCallMutationJson(
                  room: room,
                  call: call,
                  participants: <Map<String, Object?>>[
                    selfParticipant,
                    peerParticipant,
                  ],
                  selfParticipant: selfParticipant,
                ),
                200,
              );
            }
            if (request.method == 'POST' &&
                request.url.path == '/v1/rooms/group%3Aalpha/call/call-1/end') {
              final call = _relayRoomCallJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                state: 'ended',
                mediaType: 'video',
                stateVersion: 3,
                updatedAtMs: 4000,
                endedAtMs: 4000,
              );
              final selfParticipant = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinState: 'left',
                supportsVideo: true,
                leftAtMs: 4000,
                updatedAtMs: 4000,
              );
              final peerParticipant = _relayRoomCallParticipantJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                profileId: 'peer-1',
                deviceId: 'peer-device',
                joinState: 'left',
                leftAtMs: 3000,
                updatedAtMs: 4000,
              );
              return http.Response(
                _roomCallMutationJson(
                  room: room,
                  call: call,
                  participants: <Map<String, Object?>>[
                    selfParticipant,
                    peerParticipant,
                  ],
                  selfParticipant: selfParticipant,
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          final joined = await controller.joinRelayRoomCall(
            roomId: 'group:alpha',
            mediaType: 'video',
            supportsVideo: true,
            videoEnabled: true,
          );

          expect(joined, isNotNull);
          expect(
            (await controller.getCachedRoomCall(
              'group:alpha',
            ))!.joinedParticipantCount,
            2,
          );

          final removed = await controller.removeRelayRoomCallParticipant(
            roomId: 'group:alpha',
            callId: 'call-1',
            participantDeviceId: 'peer-device',
          );

          expect(removed, isNotNull);

          final afterRemove = await controller.getCachedRoomCall('group:alpha');
          expect(afterRemove, isNotNull);
          expect(afterRemove!.stateVersion, 2);
          expect(afterRemove.joinedParticipantCount, 1);
          expect(
            afterRemove.participants
                .firstWhere(
                  (participant) => participant.deviceId == 'peer-device',
                )
                .joinState,
            'left',
          );

          final ended = await controller.endRelayRoomCall(
            roomId: 'group:alpha',
            callId: 'call-1',
          );

          expect(ended, isNotNull);
          expect(await controller.getCachedRoomCall('group:alpha'), isNull);
          expect(requests, <String>[
            'POST /v1/rooms/group%3Aalpha/call',
            'POST /v1/rooms/group%3Aalpha/call/call-1/participants/peer-device/remove',
            'POST /v1/rooms/group%3Aalpha/call/call-1/end',
          ]);
        } finally {
          await db.close();
        }
      },
    );

    test('room-call reconnect resync refreshes cached active calls', () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final identityKeyPair = await Ed25519().newKeyPair();
      final requests = <String>[];
      final relay = await _buildRelayClient(
        db: db,
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'GET' &&
              request.url.path == '/v1/rooms/group%3Aalpha/call') {
            final alphaRoom = _relayRoomJson(roomId: 'group:alpha');
            final alphaCall = _relayRoomCallJson(
              roomId: 'group:alpha',
              callId: 'call-alpha',
              stateVersion: 5,
              updatedAtMs: 5000,
            );
            final owner = _relayRoomCallParticipantJson(
              roomId: 'group:alpha',
              callId: 'call-alpha',
              profileId: 'owner-1',
              deviceId: 'owner-device',
              joinedAtMs: 1000,
              updatedAtMs: 5000,
            );
            final peer = _relayRoomCallParticipantJson(
              roomId: 'group:alpha',
              callId: 'call-alpha',
              profileId: 'peer-1',
              deviceId: 'peer-device',
              joinedAtMs: 1100,
              updatedAtMs: 4800,
            );
            return http.Response(
              _roomCallSnapshotJson(
                exists: true,
                room: alphaRoom,
                call: alphaCall,
                participants: <Map<String, Object?>>[owner, peer],
                selfParticipant: owner,
              ),
              200,
            );
          }
          if (request.method == 'GET' &&
              request.url.path == '/v1/rooms/group%3Abeta/call') {
            return http.Response(
              _roomCallSnapshotJson(
                exists: false,
                room: _relayRoomJson(roomId: 'group:beta', title: 'Beta Room'),
              ),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        identityKeyPair: identityKeyPair,
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );
      controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

      try {
        await db.roomCallSnapshotReplace(
          groupId: 'group:alpha',
          callId: 'call-alpha',
          state: 'active',
          mediaType: 'audio',
          createdByProfileId: 'owner-1',
          createdByDeviceId: 'owner-device',
          stateVersion: 1,
          startedAtMs: 1000,
          updatedAtMs: 2000,
          expiresAtMs: 9000,
          participants: const <RoomCallParticipantStateRecord>[
            (
              profileId: 'owner-1',
              deviceId: 'owner-device',
              joinState: 'joined',
              supportsVideo: false,
              supportsScreenShare: false,
              muted: false,
              deafened: false,
              videoEnabled: false,
              screenShareEnabled: false,
              speaking: false,
              joinedAtMs: 1000,
              leftAtMs: null,
              updatedAtMs: 2000,
            ),
          ],
        );
        await db.roomCallSnapshotReplace(
          groupId: 'group:beta',
          callId: 'call-beta',
          state: 'active',
          mediaType: 'audio',
          createdByProfileId: 'owner-1',
          createdByDeviceId: 'owner-device',
          stateVersion: 1,
          startedAtMs: 1000,
          updatedAtMs: 1900,
          expiresAtMs: 9000,
          participants: const <RoomCallParticipantStateRecord>[
            (
              profileId: 'owner-1',
              deviceId: 'owner-device',
              joinState: 'joined',
              supportsVideo: false,
              supportsScreenShare: false,
              muted: false,
              deafened: false,
              videoEnabled: false,
              screenShareEnabled: false,
              speaking: false,
              joinedAtMs: 1000,
              leftAtMs: null,
              updatedAtMs: 1900,
            ),
          ],
        );

        await controller.resyncKnownRoomCallsFromRelayBestEffortForTesting();

        expect(
          requests,
          unorderedEquals(<String>[
            'GET /v1/rooms/group%3Aalpha/call',
            'GET /v1/rooms/group%3Abeta/call',
          ]),
        );

        final alphaCache = await controller.getCachedRoomCall('group:alpha');
        expect(alphaCache, isNotNull);
        expect(alphaCache!.stateVersion, 5);
        expect(alphaCache.joinedParticipantCount, 2);

        expect(await controller.getCachedRoomCall('group:beta'), isNull);
      } finally {
        await db.close();
      }
    });

    test(
      'room-call resync clears stale cache on terminal relay failure',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final requests = <String>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'GET' &&
                request.url.path == '/v1/rooms/group%3Aalpha/call') {
              return http.Response('{"message":"forbidden"}', 403);
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          await _seedCachedRoomCall(
            db: db,
            roomId: 'group:alpha',
            callId: 'call-alpha',
            stateVersion: 2,
          );

          await controller.resyncKnownRoomCallsFromRelayBestEffortForTesting();

          expect(requests, <String>['GET /v1/rooms/group%3Aalpha/call']);
          expect(await controller.getCachedRoomCall('group:alpha'), isNull);
        } finally {
          await db.close();
        }
      },
    );

    test('room-call mutation failure refresh clears stale cache', () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final identityKeyPair = await Ed25519().newKeyPair();
      final requests = <String>[];
      final relay = await _buildRelayClient(
        db: db,
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'POST' &&
              request.url.path == '/v1/rooms/group%3Aalpha/call/call-1/self') {
            return http.Response('{"message":"room call is not active"}', 409);
          }
          if (request.method == 'GET' &&
              request.url.path == '/v1/rooms/group%3Aalpha/call') {
            return http.Response('{"message":"room call not found"}', 404);
          }
          return http.Response('not found', 404);
        }),
        identityKeyPair: identityKeyPair,
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );
      controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

      try {
        await _seedCachedRoomCall(
          db: db,
          roomId: 'group:alpha',
          callId: 'call-1',
          stateVersion: 2,
        );

        final updated = await controller.updateRelayRoomCallParticipant(
          roomId: 'group:alpha',
          callId: 'call-1',
          speaking: true,
        );

        expect(updated, isNull);
        expect(requests, <String>[
          'POST /v1/rooms/group%3Aalpha/call/call-1/self',
          'GET /v1/rooms/group%3Aalpha/call',
        ]);
        expect(await controller.getCachedRoomCall('group:alpha'), isNull);
      } finally {
        await db.close();
      }
    });

    test('controller joins room-call media bootstrap session', () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final identityKeyPair = await Ed25519().newKeyPair();
      final requests = <String>[];
      final relay = await _buildRelayClient(
        db: db,
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'POST' &&
              request.url.path ==
                  '/v1/rooms/group%3Aalpha/call/call-1/media/join') {
            final self = _roomCallMediaParticipantJson(
              profileId: 'owner-1',
              deviceId: 'owner-device',
              isSelf: true,
              supportsVideo: true,
              supportsScreenShare: true,
              videoEnabled: true,
              publishAudio: true,
              publishVideo: true,
              publishScreenShare: false,
            );
            return http.Response(
              _roomCallMediaJoinJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                participants: <Map<String, Object?>>[self],
                mediaType: 'video',
                stateVersion: 3,
              ),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        identityKeyPair: identityKeyPair,
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );
      controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

      try {
        final media = await controller.joinRelayRoomCallMedia(
          roomId: 'group:alpha',
          callId: 'call-1',
          publishAudio: true,
          publishVideo: true,
          subscribeAll: true,
        );

        expect(requests, <String>[
          'POST /v1/rooms/group%3Aalpha/call/call-1/media/join',
        ]);
        expect(media, isNotNull);
        expect(media!.roomId, 'group:alpha');
        expect(media.callId, 'call-1');
        expect(media.stateVersion, 3);
        expect(media.isBootstrapOnly, isTrue);
        expect(media.participantCount, 1);
        expect(media.selfParticipant, isNotNull);
        expect(media.selfParticipant!.publishVideo, isTrue);
        expect(media.ice.hasConfiguredIceServers, isTrue);
      } finally {
        await db.close();
      }
    });

    test(
      'controller parses room-call media session authority descriptor',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            if (request.method == 'POST' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/media/join') {
              final self = _roomCallMediaParticipantJson(
                profileId: 'owner-1',
                deviceId: 'owner-device',
                isSelf: true,
                supportsVideo: true,
                supportsScreenShare: true,
                videoEnabled: true,
                publishAudio: true,
                publishVideo: true,
                publishScreenShare: false,
              );
              return http.Response(
                _roomCallMediaJoinJson(
                  roomId: 'group:alpha',
                  callId: 'call-1',
                  participants: <Map<String, Object?>>[self],
                  capabilityState: 'session_auth_ready',
                  mediaType: 'video',
                  stateVersion: 3,
                  backend: _roomCallMediaBackendJson(
                    kind: 'livekit',
                    url: 'wss://livekit.example.test',
                    roomName: 'secretly-room-alpha-123',
                    participantIdentity: 'secretly-participant-owner-123',
                    accessToken: 'jwt-room-media-token',
                    accessTokenExpiresAtMs: 65000,
                  ),
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          final media = await controller.joinRelayRoomCallMedia(
            roomId: 'group:alpha',
            callId: 'call-1',
            publishAudio: true,
            publishVideo: true,
            subscribeAll: true,
          );

          expect(media, isNotNull);
          expect(
            media!.capabilityState,
            RelayRoomCallMediaCapabilityState.sessionAuthReady,
          );
          expect(media.isBootstrapOnly, isFalse);
          expect(media.hasSessionAuthority, isTrue);
          expect(media.isRuntimeReady, isFalse);
          expect(media.backend.kind, RelayRoomCallMediaBackendKind.livekit);
          expect(media.backend.url, 'wss://livekit.example.test');
          expect(media.backend.roomName, 'secretly-room-alpha-123');
          expect(
            media.backend.participantIdentity,
            'secretly-participant-owner-123',
          );
          expect(media.backend.accessToken, 'jwt-room-media-token');
          expect(media.backend.accessTokenExpiresAtMs, 65000);
        } finally {
          await db.close();
        }
      },
    );

    test('RoomCallManager bootstraps primary self-joined room call', () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final identityKeyPair = await Ed25519().newKeyPair();
      final mediaFactory = _FakeRoomCallMediaControllerFactory();
      final requests = <String>[];
      final relay = await _buildRelayClient(
        db: db,
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'POST' &&
              request.url.path ==
                  '/v1/rooms/group%3Aalpha/call/call-1/media/join') {
            final self = _roomCallMediaParticipantJson(
              profileId: 'owner-1',
              deviceId: 'owner-device',
              isSelf: true,
              supportsVideo: true,
              supportsScreenShare: true,
              videoEnabled: true,
              publishAudio: true,
              publishVideo: true,
              publishScreenShare: false,
            );
            return http.Response(
              _roomCallMediaJoinJson(
                roomId: 'group:alpha',
                callId: 'call-1',
                participants: <Map<String, Object?>>[self],
                mediaType: 'video',
                stateVersion: 4,
              ),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        identityKeyPair: identityKeyPair,
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );
      controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

      try {
        await db.roomCallSnapshotReplace(
          groupId: 'group:alpha',
          callId: 'call-1',
          state: 'active',
          mediaType: 'video',
          createdByProfileId: 'owner-1',
          createdByDeviceId: 'owner-device',
          stateVersion: 2,
          startedAtMs: 1000,
          updatedAtMs: 2000,
          expiresAtMs: 9000,
          participants: const <RoomCallParticipantStateRecord>[
            (
              profileId: 'owner-1',
              deviceId: 'owner-device',
              joinState: 'joined',
              supportsVideo: true,
              supportsScreenShare: true,
              muted: false,
              deafened: false,
              videoEnabled: true,
              screenShareEnabled: false,
              speaking: false,
              joinedAtMs: 1000,
              leftAtMs: null,
              updatedAtMs: 2000,
            ),
          ],
        );

        final manager = RoomCallManager(
          controller: controller,
          mediaControllerFactory: mediaFactory,
        );
        try {
          await manager.restorePrimaryJoinedRoomCallForTesting();

          expect(requests, <String>[
            'POST /v1/rooms/group%3Aalpha/call/call-1/media/join',
          ]);
          expect(
            manager.state.value.phase,
            RoomCallRuntimePhase.bootstrapReady,
          );
          expect(manager.state.value.roomId, 'group:alpha');
          expect(manager.state.value.callId, 'call-1');
          expect(manager.state.value.stateVersion, 4);
          expect(manager.state.value.session, isNotNull);
          expect(manager.state.value.session!.selfParticipant, isNotNull);
          expect(
            manager.state.value.session!.selfParticipant!.publishVideo,
            isTrue,
          );
          expect(
            manager.state.value.localMedia.phase,
            RoomCallLocalMediaPhase.ready,
          );
          expect(manager.state.value.localMedia.videoCaptureActive, isTrue);
          expect(manager.state.value.localMedia.localPreviewAvailable, isTrue);
          expect(manager.state.value.participants, hasLength(1));
          expect(
            manager.state.value.participants.first.kind,
            RoomCallParticipantRuntimeKind.localPreview,
          );
          expect(mediaFactory.createdControllers, hasLength(1));
          expect(mediaFactory.createdControllers.first.lastSession, isNotNull);
        } finally {
          await manager.dispose();
        }
      } finally {
        await db.close();
      }
    });

    test(
      'RoomCallManager maps controller-backed remote media views to live runtime kinds',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final mediaFactory = _FakeRoomCallMediaControllerFactory();
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            if (request.method == 'POST' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/media/join') {
              final self = _roomCallMediaParticipantJson(
                profileId: 'owner-1',
                deviceId: 'owner-device',
                isSelf: true,
                supportsVideo: true,
                supportsScreenShare: true,
                publishAudio: true,
                publishVideo: true,
              );
              final remoteVideo = _roomCallMediaParticipantJson(
                profileId: 'peer-video',
                deviceId: 'peer-video-device',
                publishAudio: true,
                publishVideo: true,
                updatedAtMs: 2100,
              );
              final remoteScreenShare = _roomCallMediaParticipantJson(
                profileId: 'peer-screen',
                deviceId: 'peer-screen-device',
                publishAudio: true,
                publishScreenShare: true,
                updatedAtMs: 2200,
              );
              return http.Response(
                _roomCallMediaJoinJson(
                  roomId: 'group:alpha',
                  callId: 'call-1',
                  participants: <Map<String, Object?>>[
                    self,
                    remoteVideo,
                    remoteScreenShare,
                  ],
                  mediaType: 'video',
                  stateVersion: 4,
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          await db.roomCallSnapshotReplace(
            groupId: 'group:alpha',
            callId: 'call-1',
            state: 'active',
            mediaType: 'video',
            createdByProfileId: 'owner-1',
            createdByDeviceId: 'owner-device',
            stateVersion: 2,
            startedAtMs: 1000,
            updatedAtMs: 2000,
            expiresAtMs: 9000,
            participants: const <RoomCallParticipantStateRecord>[
              (
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinState: 'joined',
                supportsVideo: true,
                supportsScreenShare: true,
                muted: false,
                deafened: false,
                videoEnabled: true,
                screenShareEnabled: false,
                speaking: false,
                joinedAtMs: 1000,
                leftAtMs: null,
                updatedAtMs: 2000,
              ),
              (
                profileId: 'peer-video',
                deviceId: 'peer-video-device',
                joinState: 'joined',
                supportsVideo: true,
                supportsScreenShare: false,
                muted: false,
                deafened: false,
                videoEnabled: true,
                screenShareEnabled: false,
                speaking: false,
                joinedAtMs: 1100,
                leftAtMs: null,
                updatedAtMs: 2100,
              ),
              (
                profileId: 'peer-screen',
                deviceId: 'peer-screen-device',
                joinState: 'joined',
                supportsVideo: false,
                supportsScreenShare: true,
                muted: false,
                deafened: false,
                videoEnabled: false,
                screenShareEnabled: true,
                speaking: false,
                joinedAtMs: 1200,
                leftAtMs: null,
                updatedAtMs: 2200,
              ),
            ],
          );

          final manager = RoomCallManager(
            controller: controller,
            mediaControllerFactory: mediaFactory,
          );
          try {
            await manager.restorePrimaryJoinedRoomCallForTesting();

            final fakeController = mediaFactory.createdControllers.single;
            fakeController.setParticipantViews(
              cameraDeviceIds: const <String>[
                'owner-device',
                'peer-video-device',
              ],
              screenShareDeviceIds: const <String>['peer-screen-device'],
              runtimeConnected: true,
            );

            expect(manager.state.value.localMedia.runtimeConnected, isTrue);
            expect(
              manager.state.value.participants
                  .firstWhere(
                    (participant) => participant.deviceId == 'owner-device',
                  )
                  .kind,
              RoomCallParticipantRuntimeKind.localPreview,
            );
            expect(
              manager.state.value.participants
                  .firstWhere(
                    (participant) =>
                        participant.deviceId == 'peer-video-device',
                  )
                  .kind,
              RoomCallParticipantRuntimeKind.remoteVideo,
            );
            expect(
              manager.state.value.participants
                  .firstWhere(
                    (participant) =>
                        participant.deviceId == 'peer-screen-device',
                  )
                  .kind,
              RoomCallParticipantRuntimeKind.remoteScreenShare,
            );
          } finally {
            await manager.dispose();
          }
        } finally {
          await db.close();
        }
      },
    );

    test(
      'RoomCallManager toggles speaker through isolated room runtime',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final mediaFactory = _FakeRoomCallMediaControllerFactory();
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            if (request.method == 'POST' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/media/join') {
              final self = _roomCallMediaParticipantJson(
                profileId: 'owner-1',
                deviceId: 'owner-device',
                isSelf: true,
                supportsVideo: false,
                supportsScreenShare: false,
                publishAudio: true,
                publishVideo: false,
                publishScreenShare: false,
              );
              return http.Response(
                _roomCallMediaJoinJson(
                  roomId: 'group:alpha',
                  callId: 'call-1',
                  participants: <Map<String, Object?>>[self],
                  mediaType: 'audio',
                  stateVersion: 4,
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          await db.roomCallSnapshotReplace(
            groupId: 'group:alpha',
            callId: 'call-1',
            state: 'active',
            mediaType: 'audio',
            createdByProfileId: 'owner-1',
            createdByDeviceId: 'owner-device',
            stateVersion: 2,
            startedAtMs: 1000,
            updatedAtMs: 2000,
            expiresAtMs: 9000,
            participants: const <RoomCallParticipantStateRecord>[
              (
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinState: 'joined',
                supportsVideo: false,
                supportsScreenShare: false,
                muted: false,
                deafened: false,
                videoEnabled: false,
                screenShareEnabled: false,
                speaking: false,
                joinedAtMs: 1000,
                leftAtMs: null,
                updatedAtMs: 2000,
              ),
            ],
          );

          final manager = RoomCallManager(
            controller: controller,
            mediaControllerFactory: mediaFactory,
          );
          try {
            await manager.restorePrimaryJoinedRoomCallForTesting();
            expect(manager.state.value.localMedia.speakerEnabled, isTrue);

            await manager.setSpeakerEnabled(false);

            expect(manager.state.value.localMedia.speakerEnabled, isFalse);
            expect(mediaFactory.createdControllers, hasLength(1));
            expect(mediaFactory.createdControllers.first.disposed, isFalse);
          } finally {
            await manager.dispose();
          }
        } finally {
          await db.close();
        }
      },
    );

    test(
      'RoomCallManager refreshes relay media session for remote runtime changes',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final mediaFactory = _FakeRoomCallMediaControllerFactory();
        final requests = <String>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'POST' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/media/join') {
              final self = _roomCallMediaParticipantJson(
                profileId: 'owner-1',
                deviceId: 'owner-device',
                isSelf: true,
                supportsVideo: true,
                publishAudio: true,
                publishVideo: false,
              );
              final peer = _roomCallMediaParticipantJson(
                profileId: 'peer-1',
                deviceId: 'peer-device',
                isSelf: false,
                publishAudio: false,
                publishVideo: false,
                receiveAudio: false,
                receiveVideo: false,
                updatedAtMs: 2100,
              );
              return http.Response(
                _roomCallMediaJoinJson(
                  roomId: 'group:alpha',
                  callId: 'call-1',
                  participants: <Map<String, Object?>>[self, peer],
                  mediaType: 'video',
                  stateVersion: 4,
                ),
                200,
              );
            }
            if (request.method == 'GET' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/media') {
              final self = _roomCallMediaParticipantJson(
                profileId: 'owner-1',
                deviceId: 'owner-device',
                isSelf: true,
                supportsVideo: true,
                publishAudio: true,
                publishVideo: false,
                updatedAtMs: 4000,
              );
              final peer = _roomCallMediaParticipantJson(
                profileId: 'peer-1',
                deviceId: 'peer-device',
                isSelf: false,
                publishAudio: true,
                publishVideo: false,
                receiveAudio: false,
                receiveVideo: false,
                updatedAtMs: 5000,
              );
              return http.Response(
                _roomCallMediaJson(
                  roomId: 'group:alpha',
                  callId: 'call-1',
                  participants: <Map<String, Object?>>[self, peer],
                  mediaType: 'video',
                  stateVersion: 4,
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          await db.roomCallSnapshotReplace(
            groupId: 'group:alpha',
            callId: 'call-1',
            state: 'active',
            mediaType: 'video',
            createdByProfileId: 'owner-1',
            createdByDeviceId: 'owner-device',
            stateVersion: 2,
            startedAtMs: 1000,
            updatedAtMs: 2000,
            expiresAtMs: 9000,
            participants: const <RoomCallParticipantStateRecord>[
              (
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinState: 'joined',
                supportsVideo: true,
                supportsScreenShare: false,
                muted: false,
                deafened: false,
                videoEnabled: false,
                screenShareEnabled: false,
                speaking: false,
                joinedAtMs: 1000,
                leftAtMs: null,
                updatedAtMs: 2000,
              ),
              (
                profileId: 'peer-1',
                deviceId: 'peer-device',
                joinState: 'joined',
                supportsVideo: false,
                supportsScreenShare: false,
                muted: false,
                deafened: false,
                videoEnabled: false,
                screenShareEnabled: false,
                speaking: false,
                joinedAtMs: 1100,
                leftAtMs: null,
                updatedAtMs: 2100,
              ),
            ],
          );

          final manager = RoomCallManager(
            controller: controller,
            mediaControllerFactory: mediaFactory,
          );
          try {
            await manager.restorePrimaryJoinedRoomCallForTesting();

            final initialPeer = manager.state.value.participants.firstWhere(
              (participant) => participant.deviceId == 'peer-device',
            );
            expect(initialPeer.publishAudio, isFalse);

            await manager.refreshMediaSessionFromRelayForTesting();

            expect(requests, <String>[
              'POST /v1/rooms/group%3Aalpha/call/call-1/media/join',
              'GET /v1/rooms/group%3Aalpha/call/call-1/media',
            ]);
            final refreshedPeer = manager.state.value.participants.firstWhere(
              (participant) => participant.deviceId == 'peer-device',
            );
            expect(refreshedPeer.publishAudio, isTrue);
            expect(refreshedPeer.receiveAudio, isFalse);
            expect(refreshedPeer.updatedAtMs, 5000);
          } finally {
            await manager.dispose();
          }
        } finally {
          await db.close();
        }
      },
    );

    test(
      'RoomCallManager refreshes immediately on inbound room media descriptor signal',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();
        final identityKeyPair = await Ed25519().newKeyPair();
        final mediaFactory = _FakeRoomCallMediaControllerFactory();
        final requests = <String>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'POST' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/media/join') {
              final self = _roomCallMediaParticipantJson(
                profileId: 'owner-1',
                deviceId: 'owner-device',
                isSelf: true,
                supportsVideo: true,
                publishAudio: true,
                publishVideo: false,
                updatedAtMs: 2000,
              );
              final peer = _roomCallMediaParticipantJson(
                profileId: 'peer-1',
                deviceId: 'peer-device',
                isSelf: false,
                publishAudio: false,
                publishVideo: false,
                updatedAtMs: 2100,
              );
              return http.Response(
                _roomCallMediaJoinJson(
                  roomId: 'group:alpha',
                  callId: 'call-1',
                  participants: <Map<String, Object?>>[self, peer],
                  mediaType: 'video',
                  stateVersion: 4,
                  descriptorVersion: 4,
                ),
                200,
              );
            }
            if (request.method == 'GET' &&
                request.url.path ==
                    '/v1/rooms/group%3Aalpha/call/call-1/media') {
              final self = _roomCallMediaParticipantJson(
                profileId: 'owner-1',
                deviceId: 'owner-device',
                isSelf: true,
                supportsVideo: true,
                publishAudio: true,
                publishVideo: false,
                updatedAtMs: 4000,
              );
              final peer = _roomCallMediaParticipantJson(
                profileId: 'peer-1',
                deviceId: 'peer-device',
                isSelf: false,
                publishAudio: true,
                publishVideo: false,
                updatedAtMs: 5000,
              );
              return http.Response(
                _roomCallMediaJson(
                  roomId: 'group:alpha',
                  callId: 'call-1',
                  participants: <Map<String, Object?>>[self, peer],
                  mediaType: 'video',
                  stateVersion: 4,
                  descriptorVersion: 9,
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: identityKeyPair,
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        try {
          await db.roomCallSnapshotReplace(
            groupId: 'group:alpha',
            callId: 'call-1',
            state: 'active',
            mediaType: 'video',
            createdByProfileId: 'owner-1',
            createdByDeviceId: 'owner-device',
            stateVersion: 2,
            startedAtMs: 1000,
            updatedAtMs: 2000,
            expiresAtMs: 9000,
            participants: const <RoomCallParticipantStateRecord>[
              (
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinState: 'joined',
                supportsVideo: true,
                supportsScreenShare: false,
                muted: false,
                deafened: false,
                videoEnabled: false,
                screenShareEnabled: false,
                speaking: false,
                joinedAtMs: 1000,
                leftAtMs: null,
                updatedAtMs: 2000,
              ),
              (
                profileId: 'peer-1',
                deviceId: 'peer-device',
                joinState: 'joined',
                supportsVideo: false,
                supportsScreenShare: false,
                muted: false,
                deafened: false,
                videoEnabled: false,
                screenShareEnabled: false,
                speaking: false,
                joinedAtMs: 1100,
                leftAtMs: null,
                updatedAtMs: 2100,
              ),
            ],
          );

          final manager = RoomCallManager(
            controller: controller,
            mediaControllerFactory: mediaFactory,
          );
          try {
            manager.start();
            await manager.restorePrimaryJoinedRoomCallForTesting();

            final initialPeer = manager.state.value.participants.firstWhere(
              (participant) => participant.deviceId == 'peer-device',
            );
            expect(initialPeer.publishAudio, isFalse);
            expect(manager.state.value.session?.descriptorVersion, 4);

            final controlText =
                RoomCallMediaSignalCommandCodec.encode(<String, Object?>{
                  'v': 1,
                  'action': 'descriptor_updated',
                  'roomId': 'group:alpha',
                  'callId': 'call-1',
                  'sessionId': 'call-1',
                  'descriptorVersion': 9,
                  'stateVersion': 4,
                  'reason': 'participant_state_changed',
                  'signalId': 'room-media-refresh-1',
                  'createdAtMs': 3500,
                });

            final handled = await _deliverInboundControl(
              controller: controller,
              db: db,
              transportMsgId: 'transport-room-media-refresh-1',
              payloadEventId: 'payload-room-media-refresh-1',
              controlText: controlText,
              senderDeviceId: 'peer-device',
              senderProfileId: 'peer-1',
              payloadCreatedAtMs: 3500,
              receivedAtMs: 3600,
            );

            expect(handled, isTrue);
            await Future<void>.delayed(const Duration(milliseconds: 30));

            expect(requests, <String>[
              'POST /v1/rooms/group%3Aalpha/call/call-1/media/join',
              'GET /v1/rooms/group%3Aalpha/call/call-1/media',
            ]);
            final refreshedPeer = manager.state.value.participants.firstWhere(
              (participant) => participant.deviceId == 'peer-device',
            );
            expect(refreshedPeer.publishAudio, isTrue);
            expect(manager.state.value.session?.descriptorVersion, 9);
          } finally {
            await manager.dispose();
          }
        } finally {
          await db.close();
        }
      },
    );

    test('room-call fetch deduplicates concurrent relay refreshes', () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final identityKeyPair = await Ed25519().newKeyPair();
      final requests = <String>[];
      final room = _relayRoomJson(roomId: 'group:alpha');
      final relay = await _buildRelayClient(
        db: db,
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'GET' &&
              request.url.path == '/v1/rooms/group%3Aalpha/call') {
            await Future<void>.delayed(const Duration(milliseconds: 25));
            final call = _relayRoomCallJson(
              roomId: 'group:alpha',
              callId: 'call-1',
              stateVersion: 4,
              updatedAtMs: 4000,
            );
            final owner = _relayRoomCallParticipantJson(
              roomId: 'group:alpha',
              callId: 'call-1',
              profileId: 'owner-1',
              deviceId: 'owner-device',
              updatedAtMs: 4000,
            );
            return http.Response(
              _roomCallSnapshotJson(
                exists: true,
                room: room,
                call: call,
                participants: <Map<String, Object?>>[owner],
                selfParticipant: owner,
              ),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        identityKeyPair: identityKeyPair,
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );
      controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

      try {
        final results = await Future.wait(<Future<RelayRoomCallSnapshot?>>[
          controller.fetchRelayRoomCall(roomId: 'group:alpha'),
          controller.fetchRelayRoomCall(roomId: 'group:alpha'),
        ]);

        expect(requests, <String>['GET /v1/rooms/group%3Aalpha/call']);
        expect(results, hasLength(2));
        expect(results.first?.call?.callId, 'call-1');
        expect(results.last?.call?.stateVersion, 4);
      } finally {
        await db.close();
      }
    });

    test(
      'authoritative room snapshot clears cached room-call for inactive self',
      () async {
        final controller = AppController();
        final db = await AppDb.openForTesting();

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );

        try {
          await db.roomCallSnapshotReplace(
            groupId: 'group:alpha',
            callId: 'call-1',
            state: 'active',
            mediaType: 'audio',
            createdByProfileId: 'owner-1',
            createdByDeviceId: 'owner-device',
            stateVersion: 1,
            startedAtMs: 1000,
            updatedAtMs: 2000,
            expiresAtMs: 9000,
            participants: const <RoomCallParticipantStateRecord>[
              (
                profileId: 'owner-1',
                deviceId: 'owner-device',
                joinState: 'joined',
                supportsVideo: false,
                supportsScreenShare: false,
                muted: false,
                deafened: false,
                videoEnabled: false,
                screenShareEnabled: false,
                speaking: false,
                joinedAtMs: 1000,
                leftAtMs: null,
                updatedAtMs: 2000,
              ),
            ],
          );

          await controller.applyRoomSnapshotPayloadForTesting(
            db: db,
            payload: <String, Object?>{
              'v': 1,
              'action': 'snapshot',
              'groupId': 'group:alpha',
              'groupTitle': 'Alpha Room',
              'ownerProfileId': 'owner-1',
              'stateVersion': 1,
              'membershipVersion': 2,
              'memberProfileIds': const <String>['owner-1'],
              'membershipStates': const <Map<String, Object?>>[
                <String, Object?>{
                  'profileId': 'owner-1',
                  'status': 'left',
                  'role': 'owner',
                  'createdAtMs': 1000,
                  'updatedAtMs': 2000,
                },
              ],
              'adminProfileIds': const <String>['owner-1'],
              'inviteLinks': const <Map<String, Object?>>[],
            },
          );

          expect(await controller.getCachedRoomCall('group:alpha'), isNull);
          final convo = await db.convoGet('group:alpha');
          expect(convo?['archived_at_ms'], isNotNull);
        } finally {
          await db.close();
        }
      },
    );
  });
}
