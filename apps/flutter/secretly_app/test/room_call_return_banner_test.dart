// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/rooms/room_call_media_state.dart';
import 'package:secretly_app/rooms/room_call_state.dart';
import 'package:secretly_app/ui/widgets/room_call_return_banner.dart';

CachedRoomCall _buildCall({
  String roomId = 'room-alpha',
  String callId = 'call-alpha',
  String selfJoinState = 'joined',
  bool selfMuted = false,
  bool selfSpeaking = false,
  int joinedParticipantCount = 2,
}) {
  final participants = <CachedRoomCallParticipant>[
    CachedRoomCallParticipant(
      profileId: 'self-profile',
      deviceId: 'self-device',
      joinState: selfJoinState,
      supportsVideo: false,
      supportsScreenShare: false,
      muted: selfMuted,
      deafened: false,
      videoEnabled: false,
      screenShareEnabled: false,
      speaking: selfSpeaking,
      joinedAtMs: 1,
      leftAtMs: null,
      updatedAtMs: 1,
    ),
  ];
  for (var index = 1; index < joinedParticipantCount; index += 1) {
    participants.add(
      CachedRoomCallParticipant(
        profileId: 'peer-$index',
        deviceId: 'peer-device-$index',
        joinState: 'joined',
        supportsVideo: false,
        supportsScreenShare: false,
        muted: false,
        deafened: false,
        videoEnabled: false,
        screenShareEnabled: false,
        speaking: false,
        joinedAtMs: 1,
        leftAtMs: null,
        updatedAtMs: 1,
      ),
    );
  }
  return CachedRoomCall(
    roomId: roomId,
    callId: callId,
    state: 'active',
    mediaType: 'audio',
    createdByProfileId: 'self-profile',
    createdByDeviceId: 'self-device',
    stateVersion: 1,
    startedAtMs: 1,
    updatedAtMs: 1,
    endedAtMs: null,
    expiresAtMs: 10,
    participants: participants,
    selfParticipant: participants.first,
  );
}

void main() {
  testWidgets('RoomCallReturnBanner renders room title and live state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomCallReturnBanner(
            title: 'Bridge Alpha',
            mediaType: 'audio',
            joinedCount: 3,
            selfReconnecting: false,
            selfSpeaking: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Bridge Alpha'), findsOneWidget);
    expect(find.textContaining('3'), findsOneWidget);
  });

  test('resolveRoomCallReturnBannerState prefers matching runtime reconnect state', () {
    final call = _buildCall(joinedParticipantCount: 2);
    final runtimeState = RoomCallRuntimeState(
      phase: RoomCallRuntimePhase.bootstrapReady,
      roomId: call.roomId,
      callId: call.callId,
      stateVersion: 4,
      lastSyncedAtMs: 42,
      session: null,
      localMedia: const RoomCallLocalMediaState.idle().copyWith(
        runtimeReconnecting: true,
      ),
      participants: const <RoomCallParticipantRuntimeState>[
        RoomCallParticipantRuntimeState(
          profileId: 'self-profile',
          deviceId: 'self-device',
          joinState: 'reconnecting',
          isSelf: true,
          publishAudio: true,
          publishVideo: false,
          publishScreenShare: false,
          receiveAudio: true,
          receiveVideo: false,
          receiveScreenShare: false,
          kind: RoomCallParticipantRuntimeKind.reconnecting,
          errorMessage: null,
          updatedAtMs: 10,
        ),
        RoomCallParticipantRuntimeState(
          profileId: 'peer-1',
          deviceId: 'peer-device-1',
          joinState: 'joined',
          isSelf: false,
          publishAudio: true,
          publishVideo: false,
          publishScreenShare: false,
          receiveAudio: true,
          receiveVideo: false,
          receiveScreenShare: false,
          kind: RoomCallParticipantRuntimeKind.audioOnly,
          errorMessage: null,
          updatedAtMs: 10,
        ),
        RoomCallParticipantRuntimeState(
          profileId: 'peer-2',
          deviceId: 'peer-device-2',
          joinState: 'joined',
          isSelf: false,
          publishAudio: true,
          publishVideo: false,
          publishScreenShare: false,
          receiveAudio: true,
          receiveVideo: false,
          receiveScreenShare: false,
          kind: RoomCallParticipantRuntimeKind.audioOnly,
          errorMessage: null,
          updatedAtMs: 10,
        ),
      ],
      errorMessage: null,
    );

    final resolved = resolveRoomCallReturnBannerState(
      call,
      runtimeState: runtimeState,
    );

    expect(resolved.joinedCount, 3);
    expect(resolved.selfReconnecting, isTrue);
    expect(resolved.selfMuted, isFalse);
    expect(resolved.selfSpeaking, isFalse);
  });

  test('resolveRoomCallReturnBannerState ignores mismatched runtime state', () {
    final call = _buildCall(joinedParticipantCount: 2);
    final runtimeState = RoomCallRuntimeState(
      phase: RoomCallRuntimePhase.bootstrapReady,
      roomId: 'room-beta',
      callId: 'call-beta',
      stateVersion: 2,
      lastSyncedAtMs: 7,
      session: null,
      localMedia: const RoomCallLocalMediaState.idle().copyWith(
        runtimeReconnecting: true,
      ),
      participants: const <RoomCallParticipantRuntimeState>[
        RoomCallParticipantRuntimeState(
          profileId: 'self-profile',
          deviceId: 'self-device',
          joinState: 'reconnecting',
          isSelf: true,
          publishAudio: true,
          publishVideo: false,
          publishScreenShare: false,
          receiveAudio: true,
          receiveVideo: false,
          receiveScreenShare: false,
          kind: RoomCallParticipantRuntimeKind.reconnecting,
          errorMessage: null,
          updatedAtMs: 10,
        ),
      ],
      errorMessage: null,
    );

    final resolved = resolveRoomCallReturnBannerState(
      call,
      runtimeState: runtimeState,
    );

    expect(resolved.joinedCount, 2);
    expect(resolved.selfReconnecting, isFalse);
  });
}