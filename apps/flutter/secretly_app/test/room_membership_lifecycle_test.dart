// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/rooms/room_system_event_text.dart';
import 'package:secretly_app/rooms/room_membership_failure.dart';
import 'package:secretly_app/rooms/room_policy_failure.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';

Future<List<SystemEventV1>> _decodeSystemEventPayloads(
  AppController controller,
  AppDb db,
  String groupId,
) async {
  final rows = await db.listEventsChronological(groupId, limit: 20);
  final payloads = <SystemEventV1>[];
  for (final row in rows) {
    final payload = await controller.payloadEventForChatEvent(
      ChatEvent(
        eventId: (row['event_id'] as String?) ?? '',
        createdAtMs: (row['created_at_ms'] as num?)?.toInt() ?? 0,
        type: (row['type'] as String?) ?? 'msg',
        ciphertextB64: (row['ciphertext_b64'] as String?) ?? '',
        senderDeviceId: (row['sender_device_id'] as String?) ?? '',
        localState: (row['local_state'] as String?) ?? 'received',
        payloadEventId: row['payload_event_id'] as String?,
        localCiphertextB64: row['local_ciphertext_b64'] as String?,
      ),
    );
    if (payload is SystemEventV1) {
      payloads.add(payload);
    }
  }
  return payloads;
}

Future<RelayClient> _buildRelayClient({
  required AppDb db,
  required http.Client httpClient,
  required SimpleKeyPair identityKeyPair,
  required String deviceId,
  required String selfProfileId,
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
  );
}

Map<String, Object?> _relayRoomJson({
  required String roomId,
  required String ownerProfileId,
  required String createdByDeviceId,
  required String title,
  required int version,
  required int membershipVersion,
  required int updatedAtMs,
  bool joinApprovalRequired = false,
  bool allowChangeTag = false,
  String? pinnedMessageId,
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
    'allow_change_tag': allowChangeTag,
    'join_approval_required': joinApprovalRequired,
    'slow_mode_seconds': 0,
    'chat_history_visible': false,
    'pinned_message_id': pinnedMessageId,
    'created_at_ms': 1000,
    'updated_at_ms': updatedAtMs,
  };
}

Map<String, Object?> _relayMembershipJson({
  required String roomId,
  required String profileId,
  required String status,
  required String role,
  String? sourceLinkId,
  String? tag,
  int createdAtMs = 1000,
  required int updatedAtMs,
}) {
  return <String, Object?>{
    'room_id': roomId,
    'profile_id': profileId,
    'status': status,
    'role': role,
    'source_link_id': sourceLinkId,
    'tag': tag,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
  };
}

String _relayMembershipMutationJson({
  required bool changed,
  required Map<String, Object?> room,
  required Map<String, Object?> membership,
}) {
  return jsonEncode(<String, Object?>{
    'ok': true,
    'changed': changed,
    'room': room,
    'membership': membership,
  });
}

String _relayMembersSnapshotJson({
  required Map<String, Object?> room,
  required List<Map<String, Object?>> members,
}) {
  return jsonEncode(<String, Object?>{'room': room, 'members': members});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'approve and decline join requests update membership lifecycle',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>['peer-1'],
        );

        final joinApprovalSettings = await controller.getRoomSettings(groupId);
        await controller.updateRoomSettings(
          groupId: groupId,
          settings: joinApprovalSettings.copyWith(joinApprovalRequired: true),
        );

        await db.groupMembershipStateUpsert(
          groupId: groupId,
          profileId: 'joiner-1',
          status: RoomMembershipStatus.pending.value,
          role: RoomMemberRole.guest.value,
          sourceLinkId: 'link-a',
          createdAtMs: 1000,
          updatedAtMs: 1000,
        );
        await db.groupMembershipStateUpsert(
          groupId: groupId,
          profileId: 'joiner-2',
          status: RoomMembershipStatus.pending.value,
          role: RoomMemberRole.member.value,
          sourceLinkId: 'link-b',
          createdAtMs: 2000,
          updatedAtMs: 2000,
        );

        final versionBefore = (await controller.getRoomSettings(
          groupId,
        )).membershipVersion;
        final pendingBefore = await controller.listRoomJoinRequestsDetailed(
          groupId,
        );
        expect(
          pendingBefore
              .map((member) => member.profileId)
              .toList(growable: false),
          unorderedEquals(const <String>['joiner-1', 'joiner-2']),
        );

        await controller.approveRoomJoinRequest(
          groupId: groupId,
          memberProfileId: 'joiner-1',
        );
        await controller.declineRoomJoinRequest(
          groupId: groupId,
          memberProfileId: 'joiner-2',
        );

        final pendingAfter = await controller.listRoomJoinRequestsDetailed(
          groupId,
        );
        expect(pendingAfter, isEmpty);

        final activeMembers = await controller.listRoomMembersDetailed(groupId);
        expect(
          activeMembers
              .map((member) => member.profileId)
              .toList(growable: false),
          unorderedEquals(const <String>['owner-1', 'peer-1', 'joiner-1']),
        );
        final approvedJoiner = activeMembers
            .where((member) => member.profileId == 'joiner-1')
            .first;
        expect(approvedJoiner.role, RoomMemberRole.guest);

        final membershipStates = await controller.listRoomMembershipStates(
          groupId,
        );
        final statesByProfile = <String, RoomMembershipStatus>{
          for (final state in membershipStates)
            state.profileId: RoomMembershipStatusX.fromValue(state.status),
        };
        expect(statesByProfile['joiner-1'], RoomMembershipStatus.active);
        expect(statesByProfile['joiner-2'], RoomMembershipStatus.removed);
        final membershipsByProfile = <String, GroupMembershipStateRecord>{
          for (final state in membershipStates) state.profileId: state,
        };
        expect(
          membershipsByProfile['joiner-1']?.role,
          RoomMemberRole.guest.value,
        );
        expect(membershipsByProfile['joiner-1']?.sourceLinkId, 'link-a');
        expect(
          membershipsByProfile['joiner-1']?.createdAtMs,
          greaterThan(1000),
        );

        final versionAfter = (await controller.getRoomSettings(
          groupId,
        )).membershipVersion;
        expect(versionAfter, versionBefore + 2);
      } finally {
        await db.close();
      }
    },
  );

  test('createGroup fails closed without authoritative relay', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
      allowLocalRoomFallback: false,
    );

    try {
      await expectLater(
        controller.createGroup(
          title: 'Relay required',
          memberProfileIds: const <String>['peer-1'],
        ),
        throwsA(
          isA<RoomPolicyFailure>().having(
            (error) => error.code,
            'code',
            RoomPolicyFailureCode.serviceUnavailable,
          ),
        ),
      );
    } finally {
      await db.close();
    }
  });

  test(
    'authoritative createGroup succeeds when invite listing fails after room create',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );

      try {
        late String createdGroupId;
        final requests = <String>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');

            if (request.method == 'POST' && request.url.path == '/v1/rooms') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              createdGroupId = body['room_id'] as String;
              return http.Response(
                jsonEncode(<String, Object?>{
                  'ok': true,
                  'created': true,
                  'room': _relayRoomJson(
                    roomId: createdGroupId,
                    ownerProfileId: 'owner-1',
                    createdByDeviceId: 'owner-device',
                    title: 'Solo Room',
                    version: 1,
                    membershipVersion: 1,
                    updatedAtMs: 2000,
                  ),
                }),
                200,
              );
            }

            if (request.method == 'GET' &&
                request.url.path ==
                    '/v1/rooms/${Uri.encodeComponent(createdGroupId)}/members') {
              return http.Response(
                _relayMembersSnapshotJson(
                  room: _relayRoomJson(
                    roomId: createdGroupId,
                    ownerProfileId: 'owner-1',
                    createdByDeviceId: 'owner-device',
                    title: 'Solo Room',
                    version: 1,
                    membershipVersion: 1,
                    updatedAtMs: 2000,
                  ),
                  members: <Map<String, Object?>>[
                    _relayMembershipJson(
                      roomId: createdGroupId,
                      profileId: 'owner-1',
                      status: RoomMembershipStatus.active.value,
                      role: RoomMemberRole.owner.value,
                      updatedAtMs: 2000,
                    ),
                  ],
                ),
                200,
              );
            }

            if (request.method == 'GET' &&
                request.url.path ==
                    '/v1/rooms/${Uri.encodeComponent(createdGroupId)}/invite-links') {
              return http.Response('invite list unavailable', 503);
            }

            return http.Response('not found', 404);
          }),
          identityKeyPair: await Ed25519().newKeyPair(),
          deviceId: 'owner-device',
          selfProfileId: 'owner-1',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        final groupId = await controller.createGroup(
          title: 'Solo Room',
          memberProfileIds: const <String>[],
        );

        expect(groupId, startsWith('group:'));
        final convos = await controller.listConversations();
        expect(convos.any((convo) => convo.convoId == groupId), isTrue);

        final members = await controller.listRoomMembershipStates(groupId);
        expect(members, hasLength(1));
        expect(members.single.profileId, 'owner-1');
        expect(members.single.role, RoomMemberRole.owner.value);

        expect(requests, contains('POST /v1/rooms'));
        expect(
          requests,
          isNot(
            contains(
              'POST /v1/rooms/${Uri.encodeComponent(groupId)}/invite-links',
            ),
          ),
        );
        expect(
          requests,
          contains(
            'GET /v1/rooms/${Uri.encodeComponent(groupId)}/invite-links',
          ),
        );
        expect(await controller.listRoomInviteLinks(groupId), isEmpty);
      } finally {
        await db.close();
      }
    },
  );

  test('updateRoomSettings fails closed without authoritative relay', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
    );

    try {
      final groupId = await controller.createGroup(
        title: 'Relay required',
        memberProfileIds: const <String>['peer-1'],
      );
      final settingsBefore = await controller.getRoomSettings(groupId);

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        allowLocalRoomFallback: false,
      );

      await expectLater(
        controller.updateRoomSettings(
          groupId: groupId,
          settings: settingsBefore.copyWith(joinApprovalRequired: true),
        ),
        throwsA(
          isA<RoomPolicyFailure>().having(
            (error) => error.code,
            'code',
            RoomPolicyFailureCode.serviceUnavailable,
          ),
        ),
      );

      final settingsAfter = await controller.getRoomSettings(groupId);
      expect(settingsAfter.joinApprovalRequired, isFalse);
    } finally {
      await db.close();
    }
  });

  test('ban and unban member enforce lifecycle state before rejoin', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
    );

    try {
      final groupId = await controller.createGroup(
        title: 'Alpha Room',
        memberProfileIds: const <String>['peer-1'],
      );
      await controller.addGroupMembers(
        groupId: groupId,
        memberProfileIds: const <String>['peer-2'],
      );

      await controller.banRoomMember(
        groupId: groupId,
        memberProfileId: 'peer-2',
      );

      final bannedMembers = await controller.listRoomBannedMembersDetailed(
        groupId,
      );
      expect(
        bannedMembers.map((member) => member.profileId).toList(growable: false),
        const <String>['peer-2'],
      );
      expect(
        (await controller.listGroupMembers(groupId)).contains('peer-2'),
        isFalse,
      );

      await expectLater(
        controller.addGroupMembers(
          groupId: groupId,
          memberProfileIds: const <String>['peer-2'],
        ),
        throwsA(
          isA<RoomMembershipFailure>().having(
            (error) => error.code,
            'code',
            RoomMembershipFailureCode.memberBanned,
          ),
        ),
      );

      await controller.unbanRoomMember(
        groupId: groupId,
        memberProfileId: 'peer-2',
      );
      expect(await controller.listRoomBannedMembersDetailed(groupId), isEmpty);

      await controller.addGroupMembers(
        groupId: groupId,
        memberProfileIds: const <String>['peer-2'],
      );
      expect(
        (await controller.listGroupMembers(groupId)).contains('peer-2'),
        isTrue,
      );

      final membershipStates = await controller.listRoomMembershipStates(
        groupId,
      );
      final statesByProfile = <String, RoomMembershipStatus>{
        for (final state in membershipStates)
          state.profileId: RoomMembershipStatusX.fromValue(state.status),
      };
      expect(statesByProfile['peer-2'], RoomMembershipStatus.active);
    } finally {
      await db.close();
    }
  });

  test(
    'owner must transfer room ownership before leaving active room',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>['peer-1'],
        );

        await expectLater(
          controller.leaveRoom(groupId),
          throwsA(
            isA<RoomMembershipFailure>().having(
              (error) => error.code,
              'code',
              RoomMembershipFailureCode.ownerTransferRequired,
            ),
          ),
        );

        await controller.transferRoomOwnership(
          groupId: groupId,
          nextOwnerProfileId: 'peer-1',
        );

        final settingsAfterTransfer = await controller.getRoomSettings(groupId);
        expect(settingsAfterTransfer.ownerProfileId, 'peer-1');

        await controller.leaveRoom(groupId);

        final activeMembers = await controller.listGroupMembers(groupId);
        expect(activeMembers, unorderedEquals(const <String>['peer-1']));

        final membershipStates = await controller.listRoomMembershipStates(
          groupId,
        );
        final statesByProfile = <String, RoomMembershipStatus>{
          for (final state in membershipStates)
            state.profileId: RoomMembershipStatusX.fromValue(state.status),
        };
        expect(statesByProfile['owner-1'], RoomMembershipStatus.left);
        expect(statesByProfile['peer-1'], RoomMembershipStatus.active);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'authoritative leave converges when local membership is already non-active',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>['peer-1'],
        );
        await controller.transferRoomOwnership(
          groupId: groupId,
          nextOwnerProfileId: 'peer-1',
        );

        final selfState = (await controller.listRoomMembershipStates(
          groupId,
        )).where((state) => state.profileId == 'owner-1').single;
        await db.groupMembershipStateUpsert(
          groupId: groupId,
          profileId: 'owner-1',
          status: RoomMembershipStatus.removed.value,
          role: selfState.role,
          sourceLinkId: selfState.sourceLinkId,
          createdAtMs: selfState.createdAtMs,
          updatedAtMs: selfState.updatedAtMs + 1,
        );

        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            final expectedLeavePath =
                '/v1/rooms/${Uri.encodeComponent(groupId)}/leave';
            if (request.method == 'POST' &&
                request.url.path == expectedLeavePath) {
              return http.Response('membership is not active', 409);
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: await Ed25519().newKeyPair(),
          deviceId: 'owner-device',
          selfProfileId: 'owner-1',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        await controller.leaveRoom(groupId);

        final membershipStates = await controller.listRoomMembershipStates(
          groupId,
        );
        final statesByProfile = <String, RoomMembershipStatus>{
          for (final state in membershipStates)
            state.profileId: RoomMembershipStatusX.fromValue(state.status),
        };
        expect(statesByProfile['owner-1'], RoomMembershipStatus.removed);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'authoritative decline join request uses removed membership mutation path',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>['peer-1'],
        );
        final joinApprovalSettings = await controller.getRoomSettings(groupId);
        await controller.updateRoomSettings(
          groupId: groupId,
          settings: joinApprovalSettings.copyWith(joinApprovalRequired: true),
        );
        await db.groupMembershipStateUpsert(
          groupId: groupId,
          profileId: 'joiner-2',
          status: RoomMembershipStatus.pending.value,
          role: RoomMemberRole.member.value,
          sourceLinkId: 'link-b',
          createdAtMs: 2000,
          updatedAtMs: 2000,
        );

        final roomJson = _relayRoomJson(
          roomId: groupId,
          ownerProfileId: 'owner-1',
          createdByDeviceId: 'owner-device',
          title: 'Alpha Room',
          version: 4,
          membershipVersion: 4,
          updatedAtMs: 4000,
          joinApprovalRequired: true,
        );
        final ownerMembership = _relayMembershipJson(
          roomId: groupId,
          profileId: 'owner-1',
          status: RoomMembershipStatus.active.value,
          role: RoomMemberRole.owner.value,
          updatedAtMs: 1000,
        );
        final peerMembership = _relayMembershipJson(
          roomId: groupId,
          profileId: 'peer-1',
          status: RoomMembershipStatus.active.value,
          role: RoomMemberRole.guest.value,
          updatedAtMs: 1000,
        );
        final removedMembership = _relayMembershipJson(
          roomId: groupId,
          profileId: 'joiner-2',
          status: RoomMembershipStatus.removed.value,
          role: RoomMemberRole.member.value,
          sourceLinkId: 'link-b',
          createdAtMs: 2000,
          updatedAtMs: 4000,
        );
        final membersPath = '/v1/rooms/${Uri.encodeComponent(groupId)}/members';
        final captured = <http.Request>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            captured.add(request);
            final roomPath = '/v1/rooms/${Uri.encodeComponent(groupId)}';
            if (request.method == 'POST' && request.url.path == membersPath) {
              return http.Response(
                _relayMembershipMutationJson(
                  changed: true,
                  room: roomJson,
                  membership: removedMembership,
                ),
                200,
              );
            }
            if (request.method == 'GET' && request.url.path == roomPath) {
              return http.Response(jsonEncode(roomJson), 200);
            }
            if (request.method == 'GET' && request.url.path == membersPath) {
              return http.Response(
                _relayMembersSnapshotJson(
                  room: roomJson,
                  members: <Map<String, Object?>>[
                    ownerMembership,
                    peerMembership,
                    removedMembership,
                  ],
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: await Ed25519().newKeyPair(),
          deviceId: 'owner-device',
          selfProfileId: 'owner-1',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        await controller.declineRoomJoinRequest(
          groupId: groupId,
          memberProfileId: 'joiner-2',
        );

        expect(captured, isNotEmpty);
        expect(captured.first.method, 'POST');
        expect(captured.first.url.path, membersPath);
        expect(
          captured.any((request) => request.url.path.endsWith('/unban')),
          isFalse,
        );
        final requestBody =
            jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(requestBody['profile_id'], 'joiner-2');
        expect(requestBody['status'], RoomMembershipStatus.removed.value);
        expect(requestBody['role'], RoomMemberRole.member.value);
        expect(requestBody['source_link_id'], 'link-b');

        final membershipStates = await controller.listRoomMembershipStates(
          groupId,
        );
        final statesByProfile = <String, RoomMembershipStatus>{
          for (final state in membershipStates)
            state.profileId: RoomMembershipStatusX.fromValue(state.status),
        };
        expect(statesByProfile['joiner-2'], RoomMembershipStatus.removed);
      } finally {
        await db.close();
      }
    },
  );

  test('authoritative unban uses dedicated relay unban path', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
    );

    try {
      final groupId = await controller.createGroup(
        title: 'Alpha Room',
        memberProfileIds: const <String>['peer-1'],
      );
      await controller.addGroupMembers(
        groupId: groupId,
        memberProfileIds: const <String>['peer-2'],
      );
      await controller.banRoomMember(
        groupId: groupId,
        memberProfileId: 'peer-2',
      );

      final roomJson = _relayRoomJson(
        roomId: groupId,
        ownerProfileId: 'owner-1',
        createdByDeviceId: 'owner-device',
        title: 'Alpha Room',
        version: 5,
        membershipVersion: 5,
        updatedAtMs: 5000,
      );
      final ownerMembership = _relayMembershipJson(
        roomId: groupId,
        profileId: 'owner-1',
        status: RoomMembershipStatus.active.value,
        role: RoomMemberRole.owner.value,
        updatedAtMs: 1000,
      );
      final peerMembership = _relayMembershipJson(
        roomId: groupId,
        profileId: 'peer-1',
        status: RoomMembershipStatus.active.value,
        role: RoomMemberRole.guest.value,
        updatedAtMs: 1000,
      );
      final unbannedMembership = _relayMembershipJson(
        roomId: groupId,
        profileId: 'peer-2',
        status: RoomMembershipStatus.removed.value,
        role: RoomMemberRole.member.value,
        updatedAtMs: 5000,
      );
      final captured = <http.Request>[];
      final relay = await _buildRelayClient(
        db: db,
        httpClient: MockClient((request) async {
          captured.add(request);
          final roomPath = '/v1/rooms/${Uri.encodeComponent(groupId)}';
          final membersPath =
              '/v1/rooms/${Uri.encodeComponent(groupId)}/members';
          final unbanPath =
              '/v1/rooms/${Uri.encodeComponent(groupId)}/members/peer-2/unban';
          if (request.method == 'POST' && request.url.path == unbanPath) {
            return http.Response(
              _relayMembershipMutationJson(
                changed: true,
                room: roomJson,
                membership: unbannedMembership,
              ),
              200,
            );
          }
          if (request.method == 'GET' && request.url.path == roomPath) {
            return http.Response(jsonEncode(roomJson), 200);
          }
          if (request.method == 'GET' && request.url.path == membersPath) {
            return http.Response(
              _relayMembersSnapshotJson(
                room: roomJson,
                members: <Map<String, Object?>>[
                  ownerMembership,
                  peerMembership,
                  unbannedMembership,
                ],
              ),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        identityKeyPair: await Ed25519().newKeyPair(),
        deviceId: 'owner-device',
        selfProfileId: 'owner-1',
      );
      controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

      await controller.unbanRoomMember(
        groupId: groupId,
        memberProfileId: 'peer-2',
      );

      expect(captured, isNotEmpty);
      expect(captured.first.method, 'POST');
      expect(
        captured.first.url.path,
        '/v1/rooms/${Uri.encodeComponent(groupId)}/members/peer-2/unban',
      );
      expect(
        captured.any(
          (request) =>
              request.method == 'POST' &&
              request.url.path ==
                  '/v1/rooms/${Uri.encodeComponent(groupId)}/members',
        ),
        isFalse,
      );

      final membershipStates = await controller.listRoomMembershipStates(
        groupId,
      );
      final statesByProfile = <String, RoomMembershipStatus>{
        for (final state in membershipStates)
          state.profileId: RoomMembershipStatusX.fromValue(state.status),
      };
      expect(statesByProfile['peer-2'], RoomMembershipStatus.removed);
    } finally {
      await db.close();
    }
  });

  test(
    'authoritative leave no-op on banned membership does not append member-left event',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>['peer-1'],
        );
        await controller.transferRoomOwnership(
          groupId: groupId,
          nextOwnerProfileId: 'peer-1',
        );

        final selfState = (await controller.listRoomMembershipStates(
          groupId,
        )).where((state) => state.profileId == 'owner-1').single;
        await db.groupMembershipStateUpsert(
          groupId: groupId,
          profileId: 'owner-1',
          status: RoomMembershipStatus.banned.value,
          role: selfState.role,
          sourceLinkId: selfState.sourceLinkId,
          createdAtMs: selfState.createdAtMs,
          updatedAtMs: selfState.updatedAtMs + 1,
        );

        final settings = await controller.getRoomSettings(groupId);
        final roomJson = _relayRoomJson(
          roomId: groupId,
          ownerProfileId: settings.ownerProfileId,
          createdByDeviceId: 'owner-device',
          title: 'Alpha Room',
          version: settings.stateVersion,
          membershipVersion: settings.membershipVersion,
          updatedAtMs: settings.membershipVersion + 5000,
        );
        final bannedMembership = _relayMembershipJson(
          roomId: groupId,
          profileId: 'owner-1',
          status: RoomMembershipStatus.banned.value,
          role: selfState.role,
          sourceLinkId: selfState.sourceLinkId,
          createdAtMs: selfState.createdAtMs,
          updatedAtMs: selfState.updatedAtMs + 10,
        );
        final captured = <http.Request>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            captured.add(request);
            final expectedLeavePath =
                '/v1/rooms/${Uri.encodeComponent(groupId)}/leave';
            if (request.method == 'POST' &&
                request.url.path == expectedLeavePath) {
              return http.Response(
                _relayMembershipMutationJson(
                  changed: false,
                  room: roomJson,
                  membership: bannedMembership,
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: await Ed25519().newKeyPair(),
          deviceId: 'owner-device',
          selfProfileId: 'owner-1',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        final eventsBefore = await _decodeSystemEventPayloads(
          controller,
          db,
          groupId,
        );
        await controller.leaveRoom(groupId);
        final eventsAfter = await _decodeSystemEventPayloads(
          controller,
          db,
          groupId,
        );

        expect(captured, hasLength(1));
        expect(captured.single.method, 'POST');
        expect(
          captured.single.url.path,
          '/v1/rooms/${Uri.encodeComponent(groupId)}/leave',
        );
        expect(eventsAfter.length, eventsBefore.length);

        final membershipStates = await controller.listRoomMembershipStates(
          groupId,
        );
        final statesByProfile = <String, RoomMembershipStatus>{
          for (final state in membershipStates)
            state.profileId: RoomMembershipStatusX.fromValue(state.status),
        };
        expect(statesByProfile['owner-1'], RoomMembershipStatus.banned);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'local room lifecycle mutations append structured system events',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: DartCryptoProvider(
          Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
        ),
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>['peer-1'],
        );

        await controller.addGroupMembers(
          groupId: groupId,
          memberProfileIds: const <String>['peer-2'],
        );
        await controller.transferRoomOwnership(
          groupId: groupId,
          nextOwnerProfileId: 'peer-1',
        );
        await controller.removeGroupMember(
          groupId: groupId,
          memberProfileId: 'peer-2',
        );

        final payloads = await _decodeSystemEventPayloads(
          controller,
          db,
          groupId,
        );

        expect(
          payloads.map((payload) => payload.action).toList(growable: false),
          containsAllInOrder(const <String>[
            RoomSystemEventAction.memberAdded,
            RoomSystemEventAction.ownerTransferred,
            RoomSystemEventAction.memberRemoved,
          ]),
        );
        expect(payloads[0].targetProfileId, 'peer-2');
        expect(payloads[1].targetProfileId, 'peer-1');
        expect(payloads[2].targetProfileId, 'peer-2');
      } finally {
        await db.close();
      }
    },
  );

  test(
    'local deleteRoom removes conversation and room-local state atomically',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: DartCryptoProvider(
          Uint8List.fromList(List<int>.generate(32, (index) => index + 33)),
        ),
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Delete Me Room',
          memberProfileIds: const <String>['peer-1'],
        );
        await controller.createRoomInviteLink(groupId, maxUses: 2);
        await db.roomCallSnapshotReplace(
          groupId: groupId,
          callId: 'call-delete-room',
          state: 'active',
          mediaType: 'audio',
          createdByProfileId: 'owner-1',
          createdByDeviceId: 'owner-device',
          stateVersion: 1,
          startedAtMs: 1000,
          updatedAtMs: 1000,
          expiresAtMs: 2000,
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
              updatedAtMs: 1000,
            ),
          ],
        );

        expect(await db.convoGet(groupId), isNotNull);
        expect(await db.groupSettingsGet(groupId), isNotNull);
        expect(await db.groupMembershipStatesList(groupId), isNotEmpty);
        expect(await db.groupInviteLinksList(groupId), isNotEmpty);
        expect(await db.roomCallSnapshotGet(groupId), isNotNull);

        await controller.deleteRoom(groupId);

        expect(await db.convoGet(groupId), isNull);
        expect(await db.groupSettingsGet(groupId), isNull);
        expect(await db.groupMembershipStatesList(groupId), isEmpty);
        expect(await db.groupAdminsList(groupId), isEmpty);
        expect(await db.groupInviteLinksList(groupId), isEmpty);
        expect(await db.roomCallSnapshotGet(groupId), isNull);
        final convos = await controller.listConversations();
        expect(convos.any((convo) => convo.convoId == groupId), isFalse);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'room profile and settings changes append structured system events',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: DartCryptoProvider(
          Uint8List.fromList(List<int>.generate(32, (index) => index + 17)),
        ),
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>['peer-1'],
        );

        await controller.updateRoomProfile(
          groupId: groupId,
          title: 'Alpha Launch Room',
          description: 'Daily release sync',
        );
        await controller.updateRoomSettings(
          groupId: groupId,
          settings: (await controller.getRoomSettings(groupId)).copyWith(
            joinApprovalRequired: true,
            slowModeSeconds: 45,
            chatHistoryVisible: true,
          ),
        );

        final payloads = await _decodeSystemEventPayloads(
          controller,
          db,
          groupId,
        );
        final profileEvent = payloads.firstWhere(
          (payload) => payload.action == RoomSystemEventAction.profileUpdated,
        );
        final settingsEvent = payloads.firstWhere(
          (payload) => payload.action == RoomSystemEventAction.settingsUpdated,
        );

        expect(
          profileEvent.changedKeys,
          containsAll(const <String>['title', 'description']),
        );
        expect(
          settingsEvent.changedKeys,
          containsAll(const <String>[
            'join_approval_required',
            'slow_mode',
            'chat_history_visible',
          ]),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'room roles enforce moderator restricted guest and owner-only admin flows',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final crypto = DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (index) => index + 33)),
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: crypto,
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Roles Room',
          memberProfileIds: const <String>[
            'peer-1',
            'peer-2',
            'peer-3',
            'peer-4',
          ],
        );

        await controller.setRoomMemberRole(
          groupId: groupId,
          memberProfileId: 'peer-1',
          role: RoomMemberRole.moderator,
        );
        await controller.setRoomMemberRole(
          groupId: groupId,
          memberProfileId: 'peer-2',
          role: RoomMemberRole.restricted,
        );
        await controller.setRoomMemberRole(
          groupId: groupId,
          memberProfileId: 'peer-3',
          role: RoomMemberRole.guest,
        );
        await controller.setGroupAdmins(
          groupId: groupId,
          profileIds: const <String>['peer-4'],
        );

        final members = await controller.listRoomMembersDetailed(groupId);
        final rolesByProfileId = <String, RoomMemberRole>{
          for (final member in members) member.profileId: member.role,
        };
        expect(rolesByProfileId['owner-1'], RoomMemberRole.owner);
        expect(rolesByProfileId['peer-1'], RoomMemberRole.moderator);
        expect(rolesByProfileId['peer-2'], RoomMemberRole.restricted);
        expect(rolesByProfileId['peer-3'], RoomMemberRole.guest);
        expect(rolesByProfileId['peer-4'], RoomMemberRole.admin);

        final moderatorPolicy = await controller.getRoomPolicyState(
          groupId,
          profileIdOverride: 'peer-1',
        );
        expect(moderatorPolicy.canApproveJoinRequests, isTrue);
        expect(moderatorPolicy.canBanMembers, isTrue);
        expect(moderatorPolicy.canManageSettings, isFalse);
        expect(moderatorPolicy.canUseBroadcastMentions, isTrue);

        final restrictedPolicy = await controller.getRoomPolicyState(
          groupId,
          profileIdOverride: 'peer-2',
        );
        expect(restrictedPolicy.canSendText, isTrue);
        expect(restrictedPolicy.canSendMedia, isFalse);
        expect(restrictedPolicy.canReact, isFalse);

        final guestPolicy = await controller.getRoomPolicyState(
          groupId,
          profileIdOverride: 'peer-3',
        );
        expect(guestPolicy.canSendText, isFalse);
        expect(guestPolicy.canSendMedia, isFalse);
        expect(guestPolicy.canReact, isFalse);

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'peer-4',
          deviceId: 'peer-4-device',
        );
        await expectLater(
          controller.setRoomMemberRole(
            groupId: groupId,
            memberProfileId: 'peer-1',
            role: RoomMemberRole.admin,
          ),
          throwsA(
            isA<RoomMembershipFailure>().having(
              (error) => error.code,
              'code',
              RoomMembershipFailureCode.ownerOnly,
            ),
          ),
        );

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
        );

        final payloads = await _decodeSystemEventPayloads(
          controller,
          db,
          groupId,
        );
        final roleChangedEvents = payloads
            .where(
              (payload) => payload.action == RoomSystemEventAction.roleChanged,
            )
            .toList(growable: false);
        expect(
          roleChangedEvents.expand((payload) => payload.changedKeys).toSet(),
          containsAll(const <String>[
            'role:moderator',
            'role:restricted',
            'role:guest',
          ]),
        );
        expect(
          payloads.map((payload) => payload.action).toList(growable: false),
          contains(RoomSystemEventAction.adminGranted),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'authoritative room text send uses relay admission timestamp and cooldown cache',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final crypto = DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: crypto,
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>[],
        );

        final roomJson = _relayRoomJson(
          roomId: groupId,
          ownerProfileId: 'owner-1',
          createdByDeviceId: 'owner-device',
          title: 'Alpha Room',
          version: 3,
          membershipVersion: 1,
          updatedAtMs: 4000,
        )..['slow_mode_seconds'] = 15;
        final captured = <http.Request>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            captured.add(request);
            final admissionPath =
                '/v1/rooms/${Uri.encodeComponent(groupId)}/message-admissions';
            if (request.method == 'POST' && request.url.path == admissionPath) {
              final requestBody =
                  jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode(<String, Object?>{
                  'ok': true,
                  'message_id': requestBody['message_id'],
                  'kind': 'text',
                  'admitted_at_ms': 4000,
                  'next_allowed_at_ms': 19000,
                  'room': roomJson,
                }),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: await Ed25519().newKeyPair(),
          deviceId: 'owner-device',
          selfProfileId: 'owner-1',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        await controller.sendGroupMessage(
          groupId: groupId,
          text: 'hello relay',
        );

        expect(captured, hasLength(1));
        expect(captured.single.method, 'POST');
        expect(
          captured.single.url.path,
          '/v1/rooms/${Uri.encodeComponent(groupId)}/message-admissions',
        );
        final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
        expect(body['kind'], 'text');
        expect((body['message_id'] as String?)?.isNotEmpty, isTrue);

        final rows = await db.listEventsChronological(groupId, limit: 20);
        final localMessages = rows
            .where((row) {
              final eventId = (row['event_id'] as String?) ?? '';
              return eventId.startsWith('local:grp:');
            })
            .toList(growable: false);
        expect(localMessages, hasLength(1));
        expect(localMessages.single['created_at_ms'], 4000);
        expect(localMessages.single['local_state'], 'pending');

        final nextAllowedAtMs = await db.groupPostingStateNextAllowedAtMs(
          groupId: groupId,
          profileId: 'owner-1',
        );
        expect(nextAllowedAtMs, 19000);

        final settings = await controller.getRoomSettings(groupId);
        expect(settings.slowModeSeconds, 15);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'authoritative room text send maps relay slow mode failure and caches next allowed time',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final crypto = DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (index) => index + 2)),
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: crypto,
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>['peer-1'],
        );
        await controller.setRoomMemberRole(
          groupId: groupId,
          memberProfileId: 'peer-1',
          role: RoomMemberRole.member,
        );
        await controller.updateRoomSettings(
          groupId: groupId,
          settings: (await controller.getRoomSettings(
            groupId,
          )).copyWith(slowModeSeconds: 30),
        );
        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'peer-1',
          deviceId: 'peer-device',
          crypto: crypto,
        );

        final nextAllowedAtMs =
            DateTime.now().millisecondsSinceEpoch + 12 * 1000;
        final roomJson = _relayRoomJson(
          roomId: groupId,
          ownerProfileId: 'owner-1',
          createdByDeviceId: 'owner-device',
          title: 'Alpha Room',
          version: 4,
          membershipVersion: 1,
          updatedAtMs: nextAllowedAtMs,
        )..['slow_mode_seconds'] = 30;
        final ownerMembership = _relayMembershipJson(
          roomId: groupId,
          profileId: 'owner-1',
          status: RoomMembershipStatus.active.value,
          role: RoomMemberRole.owner.value,
          updatedAtMs: nextAllowedAtMs,
        );
        final peerMembership = _relayMembershipJson(
          roomId: groupId,
          profileId: 'peer-1',
          status: RoomMembershipStatus.active.value,
          role: RoomMemberRole.member.value,
          updatedAtMs: nextAllowedAtMs,
        );

        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            final admissionPath =
                '/v1/rooms/${Uri.encodeComponent(groupId)}/message-admissions';
            final membersPath =
                '/v1/rooms/${Uri.encodeComponent(groupId)}/members';
            if (request.method == 'POST' && request.url.path == admissionPath) {
              return http.Response(
                jsonEncode(<String, Object?>{
                  'code': 'slow_mode_active',
                  'message': 'slow mode is active',
                  'retry_after_seconds': 12,
                  'next_allowed_at_ms': nextAllowedAtMs,
                }),
                429,
              );
            }
            if (request.method == 'GET' && request.url.path == membersPath) {
              return http.Response(
                _relayMembersSnapshotJson(
                  room: roomJson,
                  members: <Map<String, Object?>>[
                    ownerMembership,
                    peerMembership,
                  ],
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: await Ed25519().newKeyPair(),
          deviceId: 'peer-device',
          selfProfileId: 'peer-1',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        await expectLater(
          controller.sendGroupMessage(groupId: groupId, text: 'blocked relay'),
          throwsA(
            isA<RoomPolicyFailure>()
                .having(
                  (error) => error.code,
                  'code',
                  RoomPolicyFailureCode.slowModeActive,
                )
                .having(
                  (error) => error.retryAfterSeconds,
                  'retryAfterSeconds',
                  12,
                ),
          ),
        );

        final nextAllowed = await db.groupPostingStateNextAllowedAtMs(
          groupId: groupId,
          profileId: 'peer-1',
        );
        expect(nextAllowed, nextAllowedAtMs);

        final policy = await controller.getRoomPolicyState(groupId);
        expect(policy.isSlowModeActive, isTrue);
        expect(policy.slowModeRemainingSeconds, inInclusiveRange(10, 12));

        final rows = await db.listEventsChronological(groupId, limit: 20);
        expect(
          rows.where((row) {
            final eventId = (row['event_id'] as String?) ?? '';
            return eventId.startsWith('local:grp:');
          }),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'authoritative room pinned message mutation updates cached room settings',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final crypto = DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (index) => index + 3)),
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: crypto,
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>[],
        );

        final captured = <http.Request>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            captured.add(request);
            final pinPath =
                '/v1/rooms/${Uri.encodeComponent(groupId)}/pinned-message';
            if (request.method == 'POST' && request.url.path == pinPath) {
              return http.Response(
                jsonEncode(<String, Object?>{
                  'ok': true,
                  'changed': true,
                  'room': _relayRoomJson(
                    roomId: groupId,
                    ownerProfileId: 'owner-1',
                    createdByDeviceId: 'owner-device',
                    title: 'Alpha Room',
                    version: captured.length == 1 ? 3 : 4,
                    membershipVersion: 1,
                    updatedAtMs: captured.length == 1 ? 4000 : 5000,
                    pinnedMessageId: captured.length == 1
                        ? 'event-pin-1'
                        : null,
                  ),
                }),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: await Ed25519().newKeyPair(),
          deviceId: 'owner-device',
          selfProfileId: 'owner-1',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        await controller.setRoomPinnedMessage(
          groupId: groupId,
          messageEventId: 'event-pin-1',
        );
        expect(
          (await controller.getRoomSettings(groupId)).pinnedMessageEventId,
          'event-pin-1',
        );

        await controller.setRoomPinnedMessage(
          groupId: groupId,
          messageEventId: null,
        );

        final settings = await controller.getRoomSettings(groupId);
        expect(settings.pinnedMessageEventId, isNull);
        expect(settings.stateVersion, 4);

        expect(captured, hasLength(4));
        expect(
          captured.map((request) => '${request.method} ${request.url.path}'),
          <String>[
            'POST /v1/rooms/${Uri.encodeComponent(groupId)}/pinned-message',
            'GET /v1/rooms/${Uri.encodeComponent(groupId)}/members',
            'POST /v1/rooms/${Uri.encodeComponent(groupId)}/pinned-message',
            'GET /v1/rooms/${Uri.encodeComponent(groupId)}/members',
          ],
        );

        final firstBody = jsonDecode(captured[0].body) as Map<String, dynamic>;
        expect(firstBody['message_id'], 'event-pin-1');

        final secondBody = jsonDecode(captured[2].body) as Map<String, dynamic>;
        expect(secondBody['message_id'], isNull);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'authoritative room self tag mutation updates cached membership and emits system event',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final crypto = DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (index) => index + 4)),
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: crypto,
      );

      try {
        final groupId = await controller.createGroup(
          title: 'Alpha Room',
          memberProfileIds: const <String>['peer-1'],
        );

        final captured = <http.Request>[];
        final relay = await _buildRelayClient(
          db: db,
          httpClient: MockClient((request) async {
            captured.add(request);
            final tagPath =
                '/v1/rooms/${Uri.encodeComponent(groupId)}/member-tag';
            final membersPath =
                '/v1/rooms/${Uri.encodeComponent(groupId)}/members';
            if (request.method == 'POST' && request.url.path == tagPath) {
              return http.Response(
                _relayMembershipMutationJson(
                  changed: true,
                  room: _relayRoomJson(
                    roomId: groupId,
                    ownerProfileId: 'owner-1',
                    createdByDeviceId: 'owner-device',
                    title: 'Alpha Room',
                    version: 3,
                    membershipVersion: 2,
                    updatedAtMs: 4000,
                    allowChangeTag: true,
                  ),
                  membership: _relayMembershipJson(
                    roomId: groupId,
                    profileId: 'owner-1',
                    status: RoomMembershipStatus.active.value,
                    role: RoomMemberRole.owner.value,
                    tag: 'captain',
                    updatedAtMs: 4000,
                  ),
                ),
                200,
              );
            }
            if (request.method == 'GET' && request.url.path == membersPath) {
              return http.Response(
                _relayMembersSnapshotJson(
                  room: _relayRoomJson(
                    roomId: groupId,
                    ownerProfileId: 'owner-1',
                    createdByDeviceId: 'owner-device',
                    title: 'Alpha Room',
                    version: 3,
                    membershipVersion: 2,
                    updatedAtMs: 4000,
                    allowChangeTag: true,
                  ),
                  members: <Map<String, Object?>>[
                    _relayMembershipJson(
                      roomId: groupId,
                      profileId: 'owner-1',
                      status: RoomMembershipStatus.active.value,
                      role: RoomMemberRole.owner.value,
                      tag: 'captain',
                      updatedAtMs: 4000,
                    ),
                    _relayMembershipJson(
                      roomId: groupId,
                      profileId: 'peer-1',
                      status: RoomMembershipStatus.active.value,
                      role: RoomMemberRole.member.value,
                      updatedAtMs: 4000,
                    ),
                  ],
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: await Ed25519().newKeyPair(),
          deviceId: 'owner-device',
          selfProfileId: 'owner-1',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        await controller.setOwnRoomTag(groupId: groupId, tag: '  captain  ');

        expect(captured, hasLength(2));
        expect(
          captured.map((request) => '${request.method} ${request.url.path}'),
          <String>[
            'POST /v1/rooms/${Uri.encodeComponent(groupId)}/member-tag',
            'GET /v1/rooms/${Uri.encodeComponent(groupId)}/members',
          ],
        );
        final requestBody =
            jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(requestBody['tag'], 'captain');

        final membershipState = await db.groupMembershipStateGet(
          groupId: groupId,
          profileId: 'owner-1',
        );
        expect(membershipState?.tag, 'captain');

        final members = await controller.listRoomMembersDetailed(groupId);
        final owner = members.firstWhere(
          (member) => member.profileId == 'owner-1',
        );
        expect(owner.tag, 'captain');

        final systemEvents = await _decodeSystemEventPayloads(
          controller,
          db,
          groupId,
        );
        expect(
          systemEvents.any(
            (event) => event.action == RoomSystemEventAction.memberTagUpdated,
          ),
          isTrue,
        );
      } finally {
        await db.close();
      }
    },
  );
}
