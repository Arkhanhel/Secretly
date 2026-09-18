// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/rooms/room_call_state.dart';
import 'package:secretly_app/ui/widgets/room_call_presence.dart';

CachedRoomCall _buildCall({
  String joinState = 'joined',
  String mediaType = 'audio',
}) {
  final selfParticipant = CachedRoomCallParticipant(
    profileId: 'self-1',
    deviceId: 'self-device',
    joinState: joinState,
    supportsVideo: mediaType == 'video',
    supportsScreenShare: false,
    muted: false,
    deafened: false,
    videoEnabled: mediaType == 'video',
    screenShareEnabled: false,
    speaking: false,
    joinedAtMs: 1000,
    leftAtMs: null,
    updatedAtMs: 2000,
  );

  return CachedRoomCall(
    roomId: 'group:alpha',
    callId: 'call-1',
    state: 'active',
    mediaType: mediaType,
    createdByProfileId: 'owner-1',
    createdByDeviceId: 'owner-device',
    stateVersion: 1,
    startedAtMs: 1000,
    updatedAtMs: 2000,
    endedAtMs: null,
    expiresAtMs: 9000,
    participants: [
      selfParticipant,
      const CachedRoomCallParticipant(
        profileId: 'peer-1',
        deviceId: 'peer-device-1',
        joinState: 'joined',
        supportsVideo: false,
        supportsScreenShare: false,
        muted: false,
        deafened: false,
        videoEnabled: false,
        screenShareEnabled: false,
        speaking: true,
        joinedAtMs: 1000,
        leftAtMs: null,
        updatedAtMs: 2000,
      ),
      const CachedRoomCallParticipant(
        profileId: 'peer-2',
        deviceId: 'peer-device-2',
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
    selfParticipant: selfParticipant,
  );
}

void main() {
  testWidgets('formatRoomCallPresenceText surfaces reconnecting state', (
    tester,
  ) async {
    final call = _buildCall(joinState: 'reconnecting');
    String? summary;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            summary = formatRoomCallPresenceText(
              context,
              call,
              inactiveLabel: 'Room',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(summary, 'Reconnecting to voice room call • 3 in call');
  });

  testWidgets('RoomCallPresenceCard renders summary and action', (
    tester,
  ) async {
    final call = _buildCall();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomCallPresenceCard(call: call, onTap: () {}),
        ),
      ),
    );

    expect(find.text('You are already in the room call'), findsOneWidget);
    expect(
      find.text('You are in the active voice room call • 3 in call'),
      findsOneWidget,
    );
    expect(find.text('Return to call'), findsOneWidget);
  });
}
