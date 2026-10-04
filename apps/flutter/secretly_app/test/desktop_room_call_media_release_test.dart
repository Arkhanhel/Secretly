// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 После «Выйти» микрофон оставался в эфире (30.09.2026).
//
// Общий управляющий созвона в трёх ветках переходит в «созвона нет», не
// отпуская медиадвижок: LiveKit подключён, микрофон опубликован, окно пишет
// «созвона нет», а `clearIfMatches` уже не срабатывает — у пустого состояния
// нет комнаты. Здесь — настоящий управляющий с подставным движком: сначала
// воспроизводим дыру, потом проверяем, что ПК её закрывает.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/rooms/room_call_manager.dart';
import 'package:secretly_app/rooms/room_call_media_controller.dart';
import 'package:secretly_app/rooms/room_call_media_state.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';
import 'package:secretly_app/ui/desktop/calls/room_call_media_guard.dart';

class _FakeMediaFactory implements RoomCallMediaControllerFactory {
  final List<_FakeMedia> created = <_FakeMedia>[];

  @override
  RoomCallMediaController create() {
    final media = _FakeMedia();
    created.add(media);
    return media;
  }
}

/// Движок, который только помнит, отпустили ли его.
class _FakeMedia implements RoomCallMediaController {
  final ValueNotifier<RoomCallLocalMediaState> _state = ValueNotifier(
    const RoomCallLocalMediaState.idle(),
  );
  bool disposed = false;

  @override
  ValueListenable<RoomCallLocalMediaState> get state => _state;

  @override
  RTCVideoRenderer? get localRenderer => null;

  @override
  bool hasParticipantCameraView(String deviceId) => false;

  @override
  bool hasParticipantScreenShareView(String deviceId) => false;

  @override
  bool isParticipantSpeaking(String deviceId) => false;

  @override
  Widget? buildParticipantVideoView({
    required String deviceId,
    bool mirror = false,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) => null;

  @override
  Future<void> syncSession({required RelayRoomCallMediaSession session}) async {
    _state.value = _state.value.copyWith(
      phase: RoomCallLocalMediaPhase.ready,
      audioCaptureActive: true,
      runtimeRevision: _state.value.runtimeRevision + 1,
    );
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {}

  @override
  Future<void> switchCamera() async {}

  @override
  Future<List<RoomCallVideoDevice>> videoInputs() async =>
      const <RoomCallVideoDevice>[];

  @override
  Future<List<RoomCallVideoDevice>> audioInputs() async =>
      const <RoomCallVideoDevice>[];

  @override
  String? get selectedAudioInputId => null;

  @override
  Future<void> selectAudioInput(String deviceId) async {}

  @override
  String? get selectedVideoInputId => null;

  @override
  Future<void> selectVideoInput(String deviceId) async {}

  @override
  Future<RoomCallVideoStats?> videoStats({
    required String deviceId,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) async => null;

  @override
  double participantAudioLevel(String deviceId) => 0;

  @override
  Future<void> dispose() async {
    disposed = true;
    _state.dispose();
  }
}

String _mediaJoinJson() {
  final self = <String, Object?>{
    'profile_id': 'owner-1',
    'device_id': 'owner-device',
    'join_state': 'joined',
    'is_self': true,
    'supports_video': false,
    'supports_screen_share': false,
    'muted': false,
    'deafened': false,
    'video_enabled': false,
    'screen_share_enabled': false,
    'speaking': false,
    'publish_audio': true,
    'publish_video': false,
    'publish_screen_share': false,
    'receive_audio': true,
    'receive_video': true,
    'receive_screen_share': true,
    'updated_at_ms': 2000,
  };
  return jsonEncode(<String, Object?>{
    'ok': true,
    'media': <String, Object?>{
      'room_id': 'group:alpha',
      'call_id': 'call-1',
      'session_id': 'call-1',
      'contract_version': 'room_media_v1',
      'topology': 'centralized',
      'capability_state': 'bootstrap_only',
      'media_type': 'audio',
      'state_version': 4,
      'self_profile_id': 'owner-1',
      'self_device_id': 'owner-device',
      'participant_count': 1,
      'publish_video_supported': true,
      'publish_screen_share_supported': true,
      'subscribe_all_supported': true,
      'backend': <String, Object?>{'kind': 'unavailable'},
      'signal': <String, Object?>{
        'transport_kind': 'room_call_media_signal_v1',
        'descriptor_version': 4,
      },
      'ice': <String, Object?>{
        'policy': 'relay_preferred',
        'expires_at_ms': 65000,
        'ice_servers': const <Map<String, Object?>>[],
      },
      'participants': <Map<String, Object?>>[self],
    },
  });
}

Future<void> _seedCall(AppDb db, {required String selfJoinState}) {
  return db.roomCallSnapshotReplace(
    groupId: 'group:alpha',
    callId: 'call-1',
    state: 'active',
    mediaType: 'audio',
    createdByProfileId: 'owner-1',
    createdByDeviceId: 'owner-device',
    stateVersion: selfJoinState == 'joined' ? 2 : 5,
    startedAtMs: 1000,
    updatedAtMs: 2000,
    expiresAtMs: 9000,
    participants: <RoomCallParticipantStateRecord>[
      (
        profileId: 'owner-1',
        deviceId: 'owner-device',
        joinState: selfJoinState,
        supportsVideo: false,
        supportsScreenShare: false,
        muted: false,
        deafened: false,
        videoEnabled: false,
        screenShareEnabled: false,
        speaking: false,
        joinedAtMs: 1000,
        leftAtMs: selfJoinState == 'joined' ? null : 3000,
        updatedAtMs: 3000,
      ),
    ],
  );
}

/// Настоящий управляющий в созвоне, движок — подставной.
Future<
  ({
    AppController controller,
    AppDb db,
    RoomCallManager manager,
    _FakeMediaFactory media,
  })
>
_joinedManager() async {
  final controller = AppController();
  final db = await AppDb.openForTesting();
  final identityKeyPair = await Ed25519().newKeyPair();
  final relay = RelayClient(
    db: db,
    deviceId: 'owner-device',
    selfProfileId: 'owner-1',
    deviceKeys: DeviceKeys.create(),
    wsUrl: Uri.parse('ws://example.test/ws'),
    httpBaseUrl: Uri.parse('https://example.test'),
    httpClient: MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path ==
              '/v1/rooms/group%3Aalpha/call/call-1/media/join') {
        return http.Response(_mediaJoinJson(), 200);
      }
      return http.Response('not found', 404);
    }),
    identityKeyPairOverride: identityKeyPair,
    onDelivered: ({required msgId, required ciphertextB64}) async => true,
    loadNextSeq: () async => 1,
    saveNextSeq: (_) async {},
    webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
        throw StateError('no websocket in this test'),
  );
  controller.seedRoomRuntimeForTesting(
    db: db,
    profileId: 'owner-1',
    deviceId: 'owner-device',
  );
  controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);
  await _seedCall(db, selfJoinState: 'joined');
  final media = _FakeMediaFactory();
  final manager = RoomCallManager(
    controller: controller,
    mediaControllerFactory: media,
  );
  await manager.restorePrimaryJoinedRoomCallForTesting();
  return (controller: controller, db: db, manager: manager, media: media);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(DesktopRoomCallMediaGuard.debugReset);

  group('RoomCallManager.releaseMediaIfIdle', () {
    test('🔴 дыра общего кода: «созвона нет», а движок жив', () async {
      final s = await _joinedManager();
      try {
        expect(s.manager.state.value.hasActiveSession, isTrue);
        final engine = s.media.created.single;

        // Нас вывели из созвона (сами вышли / убрал модератор / завершили для
        // всех) — снимок говорит «не в созвоне».
        await _seedCall(s.db, selfJoinState: 'left');
        await s.manager.refreshCurrent();

        expect(s.manager.state.value.hasActiveSession, isFalse);
        // Ровно то, что видел человек: окно — «созвона нет», движок — жив.
        expect(engine.disposed, isFalse);
        expect(s.manager.mediaController, same(engine));
        // И прежний путь выхода его уже не находит.
        await s.manager.clearIfMatches(roomId: 'group:alpha', callId: 'call-1');
        expect(engine.disposed, isFalse);

        await s.manager.releaseMediaIfIdle();

        expect(engine.disposed, isTrue);
        expect(s.manager.mediaController, isNull);
      } finally {
        await s.manager.dispose();
        await s.db.close();
      }
    });

    test('идёт созвон — ничего не отпускает', () async {
      final s = await _joinedManager();
      try {
        final engine = s.media.created.single;
        await s.manager.releaseMediaIfIdle();
        expect(engine.disposed, isFalse);
        expect(s.manager.mediaController, same(engine));
        expect(s.manager.state.value.hasActiveSession, isTrue);
      } finally {
        await s.manager.dispose();
        await s.db.close();
      }
    });

    test('повторный вызов безвреден', () async {
      final s = await _joinedManager();
      try {
        await _seedCall(s.db, selfJoinState: 'left');
        await s.manager.refreshCurrent();
        await Future.wait([
          s.manager.releaseMediaIfIdle(),
          s.manager.releaseMediaIfIdle(),
        ]);
        await s.manager.releaseMediaIfIdle();
        expect(s.media.created.single.disposed, isTrue);
        expect(s.manager.mediaController, isNull);
      } finally {
        await s.manager.dispose();
        await s.db.close();
      }
    });
  });

  group('DesktopRoomCallMediaGuard', () {
    test('🔴 переход в «созвона нет» отпускает движок сам', () async {
      final s = await _joinedManager();
      try {
        DesktopRoomCallMediaGuard.attach(s.manager);
        final engine = s.media.created.single;
        expect(engine.disposed, isFalse, reason: 'созвон идёт — не трогаем');

        await _seedCall(s.db, selfJoinState: 'left');
        await s.manager.refreshCurrent();
        await pumpEventQueue();

        expect(engine.disposed, isTrue);
        expect(s.manager.mediaController, isNull);
      } finally {
        await s.manager.dispose();
        await s.db.close();
      }
    });

    test('подключился позже, чем движок осиротел, — отпускает сразу', () async {
      final s = await _joinedManager();
      try {
        await _seedCall(s.db, selfJoinState: 'left');
        await s.manager.refreshCurrent();
        final engine = s.media.created.single;
        expect(engine.disposed, isFalse);

        DesktopRoomCallMediaGuard.attach(s.manager);
        await pumpEventQueue();

        expect(engine.disposed, isTrue);
      } finally {
        await s.manager.dispose();
        await s.db.close();
      }
    });

    test('новый управляющий (смена профиля) — следит за ним', () async {
      final first = await _joinedManager();
      final second = await _joinedManager();
      try {
        DesktopRoomCallMediaGuard.attach(first.manager);
        DesktopRoomCallMediaGuard.attach(first.manager);
        expect(
          DesktopRoomCallMediaGuard.attachedManager,
          same(first.manager),
        );
        DesktopRoomCallMediaGuard.attach(second.manager);
        expect(
          DesktopRoomCallMediaGuard.attachedManager,
          same(second.manager),
        );

        // Прежний управляющий больше не наш: его переходы сторож не трогает.
        await _seedCall(first.db, selfJoinState: 'left');
        await first.manager.refreshCurrent();
        await pumpEventQueue();
        expect(first.media.created.single.disposed, isFalse);

        await _seedCall(second.db, selfJoinState: 'left');
        await second.manager.refreshCurrent();
        await pumpEventQueue();
        expect(second.media.created.single.disposed, isTrue);
      } finally {
        await first.manager.dispose();
        await second.manager.dispose();
        await first.db.close();
        await second.db.close();
      }
    });

    test('разобранный управляющий отпускается без ошибок', () async {
      final s = await _joinedManager();
      DesktopRoomCallMediaGuard.attach(s.manager);
      await s.manager.dispose();
      await s.db.close();
      // `RoomCallManager.instance` пуст — сторож просто отпускает старого.
      DesktopRoomCallMediaGuard.attach();
      expect(DesktopRoomCallMediaGuard.attachedManager, isNull);
    });
  });

  group('🔴 подключено', () {
    final window = File(
      'lib/ui/desktop/calls/room_call_window.dart',
    ).readAsStringSync();
    final miniHost = File(
      'lib/ui/desktop/calls/call_mini_host.dart',
    ).readAsStringSync();

    String bodyOf(String source, String declaration) {
      final start = source.indexOf(declaration);
      expect(start, greaterThan(0), reason: 'нет «$declaration»');
      final end = source.indexOf('\n  }\n', start);
      return source.substring(start, end > 0 ? end : source.length);
    }

    test('«Выйти» отпускает движок и после clearIfMatches', () {
      final body = bodyOf(window, 'Future<void> _leave() {');
      final clear = body.indexOf('clearIfMatches');
      final release = body.indexOf('releaseMediaIfIdle()');
      expect(clear, greaterThan(0));
      expect(release, greaterThan(clear));
    });

    test('«Завершить для всех» — тоже', () {
      final body = bodyOf(window, 'Future<void> _leavePressed() async {');
      final end = body.indexOf('endRelayRoomCall');
      final release = body.indexOf('releaseMediaIfIdle()');
      expect(end, greaterThan(0));
      expect(release, greaterThan(end));
    });

    test('сторож подключён там, где ПК живёт всегда', () {
      expect(
        bodyOf(miniHost, 'void initState() {').contains(
          'DesktopRoomCallMediaGuard.attach();',
        ),
        isTrue,
      );
      expect(
        bodyOf(miniHost, 'void didUpdateWidget(DesktopCallMiniHost old) {')
            .contains('DesktopRoomCallMediaGuard.attach();'),
        isTrue,
      );
      expect(
        bodyOf(window, 'void initState() {').contains(
          'DesktopRoomCallMediaGuard.attach();',
        ),
        isTrue,
      );
    });

    test('телефон добавочного метода не зовёт — у него всё как было', () {
      final phone = File('lib/ui/room_call_screen.dart').readAsStringSync();
      expect(phone.contains('releaseMediaIfIdle'), isFalse);
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.contains('releaseMediaIfIdle'), isFalse);
    });
  });
}
