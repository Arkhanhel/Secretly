// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ЗР-10 (ТЗ E2EE созвонов): захват включает только человек. Реле может
// выключить микрофон, камеру и экран, но не включить.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/rooms/room_call_capture_intent.dart';
import 'package:secretly_app/transport/relay_client.dart';

RelayRoomCallMediaParticipant _p({
  required bool self,
  bool audio = true,
  bool video = true,
  bool screen = true,
}) => RelayRoomCallMediaParticipant(
  profileId: self ? 'me' : 'other',
  deviceId: self ? 'dev-me' : 'dev-other',
  joinState: 'joined',
  isSelf: self,
  supportsVideo: true,
  supportsScreenShare: true,
  muted: !audio,
  deafened: false,
  videoEnabled: video,
  screenShareEnabled: screen,
  speaking: false,
  publishAudio: audio,
  publishVideo: video,
  publishScreenShare: screen,
  receiveAudio: true,
  receiveVideo: true,
  receiveScreenShare: true,
  updatedAtMs: 1,
);

RelayRoomCallMediaSession _session({
  bool audio = true,
  bool video = true,
  bool screen = true,
  String callId = 'call-1',
}) =>
    RelayRoomCallMediaSession.fromJson(<String, dynamic>{
      'room_id': 'room-1',
      'call_id': callId,
      'participants': <Object?>[],
    }).copyWithParticipantsForTest([
      _p(self: true, audio: audio, video: video, screen: screen),
      _p(self: false),
    ]);

extension on RelayRoomCallMediaSession {
  RelayRoomCallMediaSession copyWithParticipantsForTest(
    List<RelayRoomCallMediaParticipant> participants,
  ) => RelayRoomCallMediaSession(
    roomId: roomId,
    callId: callId,
    sessionId: sessionId,
    contractVersion: contractVersion,
    topology: topology,
    capabilityState: capabilityState,
    mediaType: mediaType,
    stateVersion: stateVersion,
    selfProfileId: selfProfileId,
    selfDeviceId: selfDeviceId,
    participantCount: participants.length,
    publishVideoSupported: publishVideoSupported,
    publishScreenShareSupported: publishScreenShareSupported,
    subscribeAllSupported: subscribeAllSupported,
    backend: backend,
    signal: signal,
    ice: ice,
    participants: participants,
  );
}

void main() {
  group('фильтр перед медиа', () {
    test('🔴 реле включило микрофон, человек выключал — микрофон выключен', () {
      const intent = RoomCallCaptureIntent(
        callId: 'call-1',
        audio: false,
        video: true,
        screenShare: false,
      );
      final filtered = applyRoomCallCaptureIntent(_session(), intent);
      final self = filtered.selfParticipant!;
      expect(self.publishAudio, isFalse);
      expect(self.publishVideo, isTrue);
      expect(self.publishScreenShare, isFalse);
      // Чужие участники не трогаются.
      final other = filtered.participants.firstWhere((p) => !p.isSelf);
      expect(other.publishAudio, isTrue);
    });

    test('реле выключило — выключено, даже если человек хотел', () {
      const intent = RoomCallCaptureIntent(
        callId: 'call-1',
        audio: true,
        video: true,
        screenShare: true,
      );
      final filtered = applyRoomCallCaptureIntent(
        _session(audio: false, video: false),
        intent,
      );
      expect(filtered.selfParticipant!.publishAudio, isFalse);
      expect(filtered.selfParticipant!.publishVideo, isFalse);
    });

    test('нет желания — всё как раньше (тот же объект)', () {
      final session = _session();
      expect(
        identical(applyRoomCallCaptureIntent(session, null), session),
        isTrue,
      );
    });

    test('желание другого созвона не применяется', () {
      const intent = RoomCallCaptureIntent(
        callId: 'call-OLD',
        audio: false,
        video: false,
        screenShare: false,
      );
      final session = _session();
      expect(
        identical(applyRoomCallCaptureIntent(session, intent), session),
        isTrue,
      );
    });

    test('желание со входа (без callId) относится к созвону', () {
      final intent = RoomCallCaptureIntent.fromJoin(
        muted: true,
        deafened: false,
        videoEnabled: false,
        screenShareEnabled: false,
      );
      final filtered = applyRoomCallCaptureIntent(_session(), intent);
      expect(filtered.selfParticipant!.publishAudio, isFalse);
      expect(filtered.selfParticipant!.publishVideo, isFalse);
    });
  });

  group('желание из запроса «изменить своё состояние»', () {
    const relayNow = (
      muted: false,
      deafened: false,
      videoEnabled: false,
      screenShareEnabled: false,
    );

    test('🔴 подменённый снимок не протекает в желание: человек нажал '
        '«камера», а микрофон в запросе — повтор из снимка', () {
      const previous = RoomCallCaptureIntent(
        callId: 'c',
        audio: false, // человек выключал микрофон
        video: false,
        screenShare: false,
      );
      // Реле подменило снимок: muted=false. Экран собирает запрос из снимка,
      // меняя только камеру.
      final next = RoomCallCaptureIntent.merge(
        callId: 'c',
        previous: previous,
        relayNow: relayNow,
        muted: false,
        deafened: false,
        videoEnabled: true,
        screenShareEnabled: false,
      );
      expect(next.video, isTrue, reason: 'камеру человек включил сам');
      expect(next.audio, isFalse, reason: 'микрофон он не трогал');
    });

    test('человек включил микрофон — желание включено', () {
      const previous = RoomCallCaptureIntent(
        callId: 'c',
        audio: false,
        video: false,
        screenShare: false,
      );
      final next = RoomCallCaptureIntent.merge(
        callId: 'c',
        previous: previous,
        relayNow: (
          muted: true,
          deafened: false,
          videoEnabled: false,
          screenShareEnabled: false,
        ),
        muted: false,
        deafened: false,
        videoEnabled: false,
        screenShareEnabled: false,
      );
      expect(next.audio, isTrue);
    });

    test('нет прежнего желания или снимка — берётся запрос целиком', () {
      final next = RoomCallCaptureIntent.merge(
        callId: 'c',
        previous: null,
        relayNow: relayNow,
        muted: true,
        deafened: false,
        videoEnabled: true,
        screenShareEnabled: true,
      );
      expect(next.audio, isFalse);
      expect(next.video, isTrue);
      expect(next.screenShare, isTrue);
    });

    test('«не слышу» выключает и отправку звука', () {
      final next = RoomCallCaptureIntent.fromJoin(
        muted: false,
        deafened: true,
        videoEnabled: false,
        screenShareEnabled: false,
      );
      expect(next.audio, isFalse);
    });
  });

  group('отказ реле 409 с настоящим контрактом', () {
    RelayHttpException e(int code, String body) => RelayHttpException(
      operation: 'x',
      message: 'm',
      statusCode: code,
      responseBody: body,
    );

    test('разбирается только 409 с известным контрактом', () {
      expect(
        roomCallContractFromMismatch(
          e(409, 'room_call_contract_mismatch:room_media_e2ee_v1'),
        ),
        'room_media_e2ee_v1',
      );
      expect(
        roomCallContractFromMismatch(
          e(409, '{"error":"room_call_contract_mismatch:room_media_v1"}'),
        ),
        'room_media_v1',
      );
      expect(
        roomCallContractFromMismatch(
          e(409, 'room_call_contract_mismatch:room_media_v9'),
        ),
        isNull,
      );
      expect(
        roomCallContractFromMismatch(
          e(403, 'room_call_contract_mismatch:room_media_e2ee_v1'),
        ),
        isNull,
      );
      expect(roomCallContractFromMismatch(StateError('x')), isNull);
    });
  });
}
