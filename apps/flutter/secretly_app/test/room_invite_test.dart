// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/rooms/room_invite_failure.dart';
import 'package:secretly_app/rooms/room_system_event_text.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

Future<String> _roomAvatarHash(Uint8List bytes) async {
  final digest = await Sha256().hash(bytes);
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}

Uint8List _sampleAvatarImageBytes() {
  final image = img.Image(width: 12, height: 12);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 0x24 + x * 8, 0x6C, 0x8F + y * 6, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Future<RelayClient> _buildRelayClientForRoomTests({
  required AppDb db,
  required http.Client httpClient,
  required SimpleKeyPair identityKeyPair,
  String selfProfileId = 'owner-1',
  String deviceId = 'owner-device',
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

Map<String, Object?> _relayRoomMap({
  required String roomId,
  required int version,
  required int membershipVersion,
  String ownerProfileId = 'owner-1',
  String createdByDeviceId = 'owner-device',
  String title = 'Alpha Room',
  String? description,
  String reactionsMode = 'all',
  bool allowText = true,
  bool allowMedia = true,
  bool allowAddMembers = true,
  bool allowPinMessages = true,
  bool allowChangeGroupInfo = true,
  bool allowChangeTag = false,
  bool joinApprovalRequired = false,
  int slowModeSeconds = 0,
  bool chatHistoryVisible = false,
  int createdAtMs = 1000,
  int updatedAtMs = 2000,
}) {
  return <String, Object?>{
    'room_id': roomId,
    'version': version,
    'membership_version': membershipVersion,
    'owner_profile_id': ownerProfileId,
    'created_by_device_id': createdByDeviceId,
    'title': title,
    'description': description,
    'reactions_mode': reactionsMode,
    'allow_text': allowText,
    'allow_media': allowMedia,
    'allow_add_members': allowAddMembers,
    'allow_pin_messages': allowPinMessages,
    'allow_change_group_info': allowChangeGroupInfo,
    'allow_change_tag': allowChangeTag,
    'join_approval_required': joinApprovalRequired,
    'slow_mode_seconds': slowModeSeconds,
    'chat_history_visible': chatHistoryVisible,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
  };
}

Map<String, Object?> _relayMembershipMap({
  required String roomId,
  required String profileId,
  String status = 'active',
  String role = 'member',
  String? sourceLinkId,
  int createdAtMs = 1000,
  int updatedAtMs = 2000,
}) {
  return <String, Object?>{
    'room_id': roomId,
    'profile_id': profileId,
    'status': status,
    'role': role,
    'source_link_id': sourceLinkId,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
  };
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDocumentsDir;

  setUpAll(() async {
    tempDocumentsDir = await Directory.systemTemp.createTemp(
      'secretly-room-avatar-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationSupportDirectory':
            case 'getTemporaryDirectory':
              return tempDocumentsDir.path;
          }
          return tempDocumentsDir.path;
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    if (await tempDocumentsDir.exists()) {
      await tempDocumentsDir.delete(recursive: true);
    }
  });

  test('room invite deep link round-trips inviter and group hint', () {
    final link = buildRoomInviteDeepLink(
      slug: 'invite-alpha',
      createdByProfileId: 'owner-1',
      groupIdHint: 'group:alpha',
    );

    final parsed = tryParseRoomInviteUri(Uri.parse(link));

    expect(parsed, isNotNull);
    expect(parsed!.slug, 'invite-alpha');
    expect(parsed.inviterProfileId, 'owner-1');
    expect(parsed.groupIdHint, 'group:alpha');
  });

  test('room snapshot command materializes local room state', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
    );

    final controlText = AppController.encodeRoomInviteCommandForTesting(
      <String, Object?>{
        'v': 1,
        'action': 'snapshot',
        'groupId': 'group:alpha',
        'groupTitle': 'Alpha Room',
        'description': 'Release room',
        'ownerProfileId': 'owner-1',
        'reactionsMode': RoomReactionsMode.selected.value,
        'allowTextMessages': true,
        'allowMedia': false,
        'allowAddMembers': false,
        'allowPinMessages': false,
        'allowChangeGroupInfo': false,
        'allowChangeTag': false,
        'slowModeSeconds': 30,
        'chatHistoryVisible': true,
        'stateVersion': 4,
        'memberProfileIds': const <String>['owner-1', 'peer-1'],
        'adminProfileIds': const <String>['owner-1'],
        'inviteLinks': const <Map<String, Object?>>[
          <String, Object?>{
            'linkId': 'link-1',
            'groupId': 'group:alpha',
            'slug': 'invite-alpha',
            'createdByProfileId': 'owner-1',
            'expiresAtMs': 900000,
            'maxUses': 5,
            'useCount': 2,
            'requiresApproval': true,
            'allowedRole': 'guest',
            'revoked': false,
            'createdAtMs': 1000,
            'updatedAtMs': 1000,
          },
        ],
      },
    );
    final payload = E2ePayloadV1(
      senderDeviceId: 'owner-device',
      createdAtMs: 5000,
      events: [MsgEventV1(eventId: 'evt-1', text: controlText)],
    );

    try {
      final handled = await controller.handleDecryptedInboundPayloadForTesting(
        db: db,
        msgId: 'transport-1',
        ciphertextB64: 'AA==',
        plainBytes: Uint8List.fromList(payload.encode()),
        payload: payload,
        senderDeviceId: 'owner-device',
        senderProfileId: 'owner-1',
        nowMs: 6000,
      );

      expect(handled, isTrue);

      final convo = await db.convoGet('group:alpha');
      expect(convo?['kind'], 'group');
      expect(convo?['title'], 'Alpha Room');

      final members = await db.groupMembersList('group:alpha');
      expect(
        members
            .map((row) => row['member_profile_id'] as String?)
            .whereType<String>()
            .toList(),
        unorderedEquals(const <String>['owner-1', 'peer-1']),
      );

      final settings = await db.groupSettingsGet('group:alpha');
      expect(settings?['owner_profile_id'], 'owner-1');
      expect((settings?['allow_media'] as num?)?.toInt(), 0);
      expect((settings?['allow_add_members'] as num?)?.toInt(), 0);
      expect((settings?['slow_mode_seconds'] as num?)?.toInt(), 30);
      expect((settings?['chat_history_visible'] as num?)?.toInt(), 1);
      expect((settings?['state_version'] as num?)?.toInt(), 4);

      final invite = await db.groupInviteLinkGetBySlug(
        slug: 'invite-alpha',
        createdByProfileId: 'owner-1',
      );
      expect(invite, isNotNull);
      expect(invite?['group_id'], 'group:alpha');
      expect((invite?['is_revoked'] as num?)?.toInt(), 0);
      expect((invite?['expires_at_ms'] as num?)?.toInt(), 900000);
      expect((invite?['max_uses'] as num?)?.toInt(), 5);
      expect((invite?['use_count'] as num?)?.toInt(), 2);
      expect((invite?['requires_approval'] as num?)?.toInt(), 1);
      expect(invite?['allowed_role'], 'guest');
    } finally {
      await db.close();
    }
  });

  test(
    'room snapshot prunes hidden history older than viewer membership cutoff',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'peer-1',
        deviceId: 'peer-device',
      );

      try {
        await db.convoEnsureGroup(
          groupId: 'group:hidden-history',
          title: 'Hidden History',
        );
        await db.insertEvent(
          eventId: 'evt-room-old',
          convoId: 'group:hidden-history',
          type: 'msg',
          senderDeviceId: 'owner-device',
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
        );
        await db.insertEvent(
          eventId: 'evt-room-new',
          convoId: 'group:hidden-history',
          type: 'msg',
          senderDeviceId: 'owner-device',
          ciphertextB64: 'AA==',
          createdAtMs: 5000,
        );

        final snapshot = AppController.encodeRoomInviteCommandForTesting(
          <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:hidden-history',
            'groupTitle': 'Hidden History',
            'ownerProfileId': 'owner-1',
            'chatHistoryVisible': false,
            'stateVersion': 6,
            'membershipVersion': 6,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1'],
            'membershipStates': const <Map<String, Object?>>[
              <String, Object?>{
                'profileId': 'owner-1',
                'status': 'active',
                'role': 'admin',
                'createdAtMs': 500,
                'updatedAtMs': 500,
              },
              <String, Object?>{
                'profileId': 'peer-1',
                'status': 'active',
                'role': 'member',
                'createdAtMs': 4000,
                'updatedAtMs': 4000,
              },
            ],
          },
        );

        expect(
          await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-hidden-history',
            payloadEventId: 'evt-hidden-history-snapshot',
            controlText: snapshot,
            senderDeviceId: 'owner-device',
            senderProfileId: 'owner-1',
            payloadCreatedAtMs: 6000,
            receivedAtMs: 6100,
          ),
          isTrue,
        );

        final rows = await db.listEventsChronological(
          'group:hidden-history',
          limit: 20,
        );
        final eventIds = rows
            .map((row) => row['event_id'] as String?)
            .whereType<String>()
            .toSet();
        expect(eventIds.contains('evt-room-old'), isFalse);
        expect(eventIds.contains('evt-room-new'), isTrue);

        final convo = await db.convoGet('group:hidden-history');
        expect((convo?['last_event_at_ms'] as num?)?.toInt(), 5000);

        final conversations = await controller.listConversations();
        Conversation? hiddenHistoryConvo;
        for (final conversation in conversations) {
          if (conversation.convoId == 'group:hidden-history') {
            hiddenHistoryConvo = conversation;
            break;
          }
        }
        expect(hiddenHistoryConvo, isNotNull);
        expect(hiddenHistoryConvo?.lastEventAtMs, 5000);
        expect(hiddenHistoryConvo?.unreadCount, 1);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'newer room snapshot replaces invite link roster authoritatively',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );

      try {
        final firstSnapshot = AppController.encodeRoomInviteCommandForTesting(
          <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:replace-links',
            'groupTitle': 'Replace Links',
            'ownerProfileId': 'owner-1',
            'stateVersion': 2,
            'memberProfileIds': const <String>['owner-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[
              <String, Object?>{
                'linkId': 'link-old',
                'groupId': 'group:replace-links',
                'slug': 'invite-old',
                'createdByProfileId': 'owner-1',
                'revoked': false,
                'createdAtMs': 1000,
                'updatedAtMs': 1000,
              },
            ],
          },
        );
        final secondSnapshot = AppController.encodeRoomInviteCommandForTesting(
          <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:replace-links',
            'groupTitle': 'Replace Links',
            'ownerProfileId': 'owner-1',
            'stateVersion': 3,
            'memberProfileIds': const <String>['owner-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[
              <String, Object?>{
                'linkId': 'link-new',
                'groupId': 'group:replace-links',
                'slug': 'invite-new',
                'createdByProfileId': 'owner-1',
                'maxUses': 1,
                'useCount': 1,
                'requiresApproval': true,
                'allowedRole': 'restricted',
                'revoked': false,
                'createdAtMs': 2000,
                'updatedAtMs': 2000,
              },
            ],
          },
        );

        expect(
          await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-links-1',
            payloadEventId: 'evt-links-1',
            controlText: firstSnapshot,
            senderDeviceId: 'owner-device',
            senderProfileId: 'owner-1',
            payloadCreatedAtMs: 1000,
            receivedAtMs: 1100,
          ),
          isTrue,
        );
        expect(
          await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-links-2',
            payloadEventId: 'evt-links-2',
            controlText: secondSnapshot,
            senderDeviceId: 'owner-device',
            senderProfileId: 'owner-1',
            payloadCreatedAtMs: 2000,
            receivedAtMs: 2100,
          ),
          isTrue,
        );

        final oldInvite = await db.groupInviteLinkGetBySlug(
          slug: 'invite-old',
          createdByProfileId: 'owner-1',
        );
        final newInvite = await db.groupInviteLinkGetBySlug(
          slug: 'invite-new',
          createdByProfileId: 'owner-1',
        );

        expect(oldInvite, isNull);
        expect(newInvite, isNotNull);
        expect((newInvite?['max_uses'] as num?)?.toInt(), 1);
        expect((newInvite?['use_count'] as num?)?.toInt(), 1);
        expect((newInvite?['requires_approval'] as num?)?.toInt(), 1);
        expect(newInvite?['allowed_role'], 'restricted');
      } finally {
        await db.close();
      }
    },
  );

  test(
    'room snapshot builder omits invite links unless explicitly requested',
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
          title: 'Snapshot Privacy Room',
          memberProfileIds: const <String>['peer-1'],
        );
        final createdLink = await controller.createRoomInviteLink(groupId);

        final defaultSnapshot = await controller
            .buildRoomSnapshotPayloadForTesting(groupId);
        final adminSnapshot = await controller
            .buildRoomSnapshotPayloadForTesting(
              groupId,
              includeInviteLinks: true,
            );

        expect(defaultSnapshot.containsKey('inviteLinks'), isFalse);

        final inviteLinks =
            (adminSnapshot['inviteLinks'] as List?) ?? const <Object?>[];
        expect(inviteLinks, isNotEmpty);
        expect(
          inviteLinks
              .whereType<Map<Object?, Object?>>()
              .map((entry) => entry['slug'])
              .contains(createdLink.slug),
          isTrue,
        );
        expect(inviteLinks.length, greaterThanOrEqualTo(1));
      } finally {
        await db.close();
      }
    },
  );

  test(
    'authoritative room snapshot clears cached invite links after access loss',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'peer-1',
        deviceId: 'peer-device',
      );

      try {
        await controller.applyRoomSnapshotPayloadForTesting(
          db: db,
          payload: <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:invite-privacy',
            'groupTitle': 'Invite Privacy',
            'ownerProfileId': 'owner-1',
            'stateVersion': 1,
            'membershipVersion': 1,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1', 'peer-1'],
            'inviteLinks': const <Map<String, Object?>>[
              <String, Object?>{
                'linkId': 'link-visible',
                'groupId': 'group:invite-privacy',
                'slug': 'visible-link',
                'createdByProfileId': 'owner-1',
                'revoked': false,
                'createdAtMs': 1000,
                'updatedAtMs': 1000,
              },
            ],
          },
        );

        expect(
          await db.groupInviteLinkGetBySlug(
            slug: 'visible-link',
            createdByProfileId: 'owner-1',
          ),
          isNotNull,
        );

        await controller.applyRoomSnapshotPayloadForTesting(
          db: db,
          forceAuthoritative: true,
          payload: <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:invite-privacy',
            'groupTitle': 'Invite Privacy',
            'ownerProfileId': 'owner-1',
            'stateVersion': 2,
            'membershipVersion': 2,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1'],
          },
        );

        expect(
          await db.groupInviteLinkGetBySlug(
            slug: 'visible-link',
            createdByProfileId: 'owner-1',
          ),
          isNull,
        );
      } finally {
        await db.close();
      }
    },
  );

  test('local room invite preview exposes per-link policy metadata', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
    );

    try {
      final groupId = await controller.createGroup(
        title: 'Policy Room',
        memberProfileIds: const <String>['peer-1'],
      );
      final expiresAtMs = DateTime.now()
          .add(const Duration(days: 7))
          .millisecondsSinceEpoch;
      final link = await controller.createRoomInviteLink(
        groupId,
        expiresAtMs: expiresAtMs,
        maxUses: 5,
        requiresApproval: true,
        allowedRole: RoomMemberRole.guest,
      );

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'viewer-1',
        deviceId: 'viewer-device',
      );

      final preview = await controller.resolveRoomInviteTarget(
        RoomInviteTarget(
          slug: link.slug,
          inviterProfileId: 'owner-1',
          groupIdHint: groupId,
        ),
      );

      expect(preview.groupId, groupId);
      expect(preview.joinApprovalRequired, isTrue);
      expect(preview.allowedRole, RoomMemberRole.guest);
      expect(preview.maxUses, 5);
      expect(preview.remainingUses, 5);
      expect(preview.expiresAtMs, expiresAtMs);
      expect(preview.isAlreadyMember, isFalse);
    } finally {
      await db.close();
    }
  });

  test(
    'authoritative room invite preview applies room-level approval policy',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'viewer-approval',
        deviceId: 'viewer-approval-device',
      );

      try {
        final relay = await _buildRelayClientForRoomTests(
          db: db,
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/v1/room-invites/invite-room-approval') {
              return http.Response(
                jsonEncode(<String, Object?>{
                  'room': _relayRoomMap(
                    roomId: 'group:relay-approval',
                    version: 4,
                    membershipVersion: 4,
                    ownerProfileId: 'owner-1',
                    title: 'Relay Approval Room',
                    joinApprovalRequired: true,
                  ),
                  'invite_link': <String, Object?>{
                    'link_id': 'link-room-approval',
                    'room_id': 'group:relay-approval',
                    'slug': 'invite-room-approval',
                    'created_by_profile_id': 'owner-1',
                    'expires_at_ms': null,
                    'max_uses': null,
                    'use_count': 0,
                    'remaining_uses': null,
                    'requires_approval': false,
                    'allowed_role': 'member',
                    'revoked': false,
                    'created_at_ms': 1000,
                    'updated_at_ms': 2000,
                  },
                  'active_member_count': 3,
                  'availability': 'available',
                  'requester_membership': null,
                }),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
          identityKeyPair: await Ed25519().newKeyPair(),
          selfProfileId: 'viewer-approval',
          deviceId: 'viewer-approval-device',
        );
        controller.seedRelayRuntimeForTesting(relay: relay, relayOnline: true);

        final preview = await controller.resolveRoomInviteTarget(
          const RoomInviteTarget(
            slug: 'invite-room-approval',
            inviterProfileId: 'owner-1',
            groupIdHint: 'group:relay-approval',
          ),
        );

        expect(preview.groupId, 'group:relay-approval');
        expect(preview.joinApprovalRequired, isTrue);
        expect(preview.allowedRole, RoomMemberRole.member);
        expect(preview.isAlreadyMember, isFalse);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'local room invite preview rejects expired and exhausted links',
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
          title: 'Limits Room',
          memberProfileIds: const <String>['peer-1'],
        );
        final expiredLink = await controller.createRoomInviteLink(
          groupId,
          expiresAtMs: DateTime.now()
              .subtract(const Duration(minutes: 1))
              .millisecondsSinceEpoch,
        );
        final exhaustedLink = await controller.createRoomInviteLink(
          groupId,
          maxUses: 1,
        );
        await db.groupInviteLinkIncrementUseCount(exhaustedLink.linkId);

        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'viewer-2',
          deviceId: 'viewer-device-2',
        );

        await expectLater(
          controller.resolveRoomInviteTarget(
            RoomInviteTarget(
              slug: expiredLink.slug,
              inviterProfileId: 'owner-1',
              groupIdHint: groupId,
            ),
          ),
          throwsA(
            isA<RoomInviteFailure>().having(
              (error) => error.code,
              'code',
              RoomInviteFailureCode.inviteExpired,
            ),
          ),
        );

        await expectLater(
          controller.resolveRoomInviteTarget(
            RoomInviteTarget(
              slug: exhaustedLink.slug,
              inviterProfileId: 'owner-1',
              groupIdHint: groupId,
            ),
          ),
          throwsA(
            isA<RoomInviteFailure>().having(
              (error) => error.code,
              'code',
              RoomInviteFailureCode.inviteUsageLimitReached,
            ),
          ),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'room invite preview fails closed without authoritative relay for uncached invites',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'viewer-1',
        deviceId: 'viewer-device',
      );

      try {
        await expectLater(
          controller.resolveRoomInviteTarget(
            const RoomInviteTarget(
              slug: 'missing-invite',
              inviterProfileId: 'owner-1',
              groupIdHint: 'group:missing',
            ),
          ),
          throwsA(
            isA<RoomInviteFailure>().having(
              (error) => error.code,
              'code',
              RoomInviteFailureCode.inviteCreatorUnavailable,
            ),
          ),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'room invite join fails closed without authoritative relay when preview is already known',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'viewer-1',
        deviceId: 'viewer-device',
      );

      try {
        const target = RoomInviteTarget(
          slug: 'known-preview',
          inviterProfileId: 'owner-1',
          groupIdHint: 'group:known',
        );
        const preview = RoomInvitePreview(
          target: target,
          groupId: 'group:known',
          groupTitle: 'Known Room',
          description: 'Known preview without relay',
          inviterDisplayName: 'Owner',
          memberCount: 2,
          isAlreadyMember: false,
          joinApprovalRequired: false,
          viewerMembershipStatus: null,
          chatHistoryVisible: false,
          allowedRole: RoomMemberRole.member,
          expiresAtMs: null,
          maxUses: null,
          remainingUses: null,
          avatarPath: null,
          avatarHash: null,
          avatarBytes: null,
        );

        await expectLater(
          controller.joinRoomViaInvite(target, preview: preview),
          throwsA(
            isA<RoomInviteFailure>().having(
              (error) => error.code,
              'code',
              RoomInviteFailureCode.inviteCreatorUnavailable,
            ),
          ),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'authoritative membership state archives removed member without full snapshot',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'peer-1',
        deviceId: 'peer-device',
      );

      try {
        await controller.applyRoomSnapshotPayloadForTesting(
          db: db,
          payload: <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:terminal-state',
            'groupTitle': 'Terminal State Room',
            'ownerProfileId': 'owner-1',
            'stateVersion': 2,
            'membershipVersion': 2,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1', 'peer-1'],
            'inviteLinks': const <Map<String, Object?>>[
              <String, Object?>{
                'linkId': 'link-terminal',
                'groupId': 'group:terminal-state',
                'slug': 'terminal-link',
                'createdByProfileId': 'owner-1',
                'revoked': false,
                'createdAtMs': 1000,
                'updatedAtMs': 1000,
              },
            ],
          },
        );

        expect(
          await db.groupInviteLinkGetBySlug(
            slug: 'terminal-link',
            createdByProfileId: 'owner-1',
          ),
          isNotNull,
        );
        expect(
          await controller.getRoomMemberRole('group:terminal-state'),
          isNotNull,
        );

        final terminalState =
            AppController.encodeRoomInviteCommandForTesting(<String, Object?>{
              'v': 1,
              'action': 'authoritative_membership_state',
              'groupId': 'group:terminal-state',
              'groupTitle': 'Terminal State Room',
              'ownerProfileId': 'owner-1',
              'profileId': 'peer-1',
              'status': RoomMembershipStatus.removed.value,
              'role': RoomMemberRole.member.value,
              'createdAtMs': 2000,
              'updatedAtMs': 3000,
              'stateVersion': 4,
              'membershipVersion': 4,
            });

        expect(
          await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-terminal-membership',
            payloadEventId: 'evt-terminal-membership',
            controlText: terminalState,
            senderDeviceId: 'owner-device',
            senderProfileId: 'owner-1',
            payloadCreatedAtMs: 3000,
            receivedAtMs: 3100,
          ),
          isTrue,
        );

        final states = await controller.listRoomMembershipStates(
          'group:terminal-state',
          statuses: <RoomMembershipStatus>{RoomMembershipStatus.removed},
        );
        expect(states.map((state) => state.profileId), contains('peer-1'));

        final convo = await db.convoGet('group:terminal-state');
        expect((convo?['archived_at_ms'] as num?)?.toInt(), isNonZero);
        expect(
          await controller.getRoomMemberRole('group:terminal-state'),
          isNull,
        );
        expect(
          await controller.listGroupAdmins('group:terminal-state'),
          isNot(contains('peer-1')),
        );
        expect(
          await db.groupInviteLinkGetBySlug(
            slug: 'terminal-link',
            createdByProfileId: 'owner-1',
          ),
          isNull,
        );

        final settings = await controller.getRoomSettings(
          'group:terminal-state',
        );
        expect(settings.stateVersion, 4);
        expect(settings.membershipVersion, 4);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'room deleted control removes conversation and room-local state',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'peer-1',
        deviceId: 'peer-device',
      );

      try {
        await controller.applyRoomSnapshotPayloadForTesting(
          db: db,
          payload: <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:deleted-peer',
            'groupTitle': 'Deleted Peer Room',
            'ownerProfileId': 'owner-1',
            'stateVersion': 2,
            'membershipVersion': 2,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1', 'peer-1'],
            'inviteLinks': const <Map<String, Object?>>[
              <String, Object?>{
                'linkId': 'link-deleted-peer',
                'groupId': 'group:deleted-peer',
                'slug': 'deleted-peer-link',
                'createdByProfileId': 'owner-1',
                'revoked': false,
                'createdAtMs': 1000,
                'updatedAtMs': 1000,
              },
            ],
          },
        );
        await db.roomCallSnapshotReplace(
          groupId: 'group:deleted-peer',
          callId: 'call-deleted-peer',
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
              joinedAtMs: 1000,
              leftAtMs: null,
              updatedAtMs: 1000,
            ),
          ],
        );

        expect(await db.convoGet('group:deleted-peer'), isNotNull);
        expect(await db.groupSettingsGet('group:deleted-peer'), isNotNull);
        expect(
          await db.groupMembershipStatesList('group:deleted-peer'),
          isNotEmpty,
        );
        expect(
          await db.groupInviteLinkGetBySlug(
            slug: 'deleted-peer-link',
            createdByProfileId: 'owner-1',
          ),
          isNotNull,
        );
        expect(await db.roomCallSnapshotGet('group:deleted-peer'), isNotNull);

        final deleteCommand =
            AppController.encodeRoomInviteCommandForTesting(<String, Object?>{
              'v': 1,
              'action': 'room_deleted',
              'groupId': 'group:deleted-peer',
              'deletedByProfileId': 'owner-1',
            });

        expect(
          await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-room-deleted-1',
            payloadEventId: 'evt-room-deleted-1',
            controlText: deleteCommand,
            senderDeviceId: 'owner-device',
            senderProfileId: 'owner-1',
            payloadCreatedAtMs: 4000,
            receivedAtMs: 4100,
          ),
          isTrue,
        );

        expect(await db.convoGet('group:deleted-peer'), isNull);
        expect(await db.groupSettingsGet('group:deleted-peer'), isNull);
        expect(
          await db.groupMembershipStatesList('group:deleted-peer'),
          isEmpty,
        );
        expect(
          await controller.getRoomMemberRole('group:deleted-peer'),
          isNull,
        );
        expect(
          await db.groupInviteLinkGetBySlug(
            slug: 'deleted-peer-link',
            createdByProfileId: 'owner-1',
          ),
          isNull,
        );
        expect(await db.roomCallSnapshotGet('group:deleted-peer'), isNull);
      } finally {
        await db.close();
      }
    },
  );

  test('room deleted control ignores spoofed non-owner sender', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'peer-1',
      deviceId: 'peer-device',
    );

    try {
      await controller.applyRoomSnapshotPayloadForTesting(
        db: db,
        payload: <String, Object?>{
          'v': 1,
          'action': 'snapshot',
          'groupId': 'group:deleted-spoofed',
          'groupTitle': 'Deleted Spoof Room',
          'ownerProfileId': 'owner-1',
          'stateVersion': 2,
          'membershipVersion': 2,
          'memberProfileIds': const <String>['owner-1', 'peer-1'],
          'adminProfileIds': const <String>['owner-1'],
          'inviteLinks': const <Map<String, Object?>>[],
        },
      );

      final deleteCommand =
          AppController.encodeRoomInviteCommandForTesting(<String, Object?>{
            'v': 1,
            'action': 'room_deleted',
            'groupId': 'group:deleted-spoofed',
            'deletedByProfileId': 'owner-1',
          });

      expect(
        await _deliverInboundControl(
          controller: controller,
          db: db,
          transportMsgId: 'transport-room-deleted-2',
          payloadEventId: 'evt-room-deleted-2',
          controlText: deleteCommand,
          senderDeviceId: 'intruder-device',
          senderProfileId: 'intruder-1',
          payloadCreatedAtMs: 5000,
          receivedAtMs: 5100,
        ),
        isTrue,
      );

      expect(await db.convoGet('group:deleted-spoofed'), isNotNull);
      expect(await db.groupSettingsGet('group:deleted-spoofed'), isNotNull);
      expect(
        await controller.getRoomMemberRole('group:deleted-spoofed'),
        isNotNull,
      );
    } finally {
      await db.close();
    }
  });

  test(
    'legacy inbound room invite join request no longer mutates local membership state',
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
          title: 'Legacy Join Room',
          memberProfileIds: const <String>['peer-1'],
        );
        final inviteLink = await controller.createRoomInviteLink(groupId);

        final beforeMembers = await controller.listRoomMembershipStates(
          groupId,
        );
        expect(
          beforeMembers.map((state) => state.profileId),
          isNot(contains('viewer-legacy')),
        );

        final joinRequest =
            AppController.encodeRoomInviteCommandForTesting(<String, Object?>{
              'v': 1,
              'action': 'join_request',
              'requestId': 'legacy-join-1',
              'slug': inviteLink.slug,
              'groupIdHint': groupId,
              'requestorDisplayName': 'Legacy Viewer',
            });

        expect(
          await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-legacy-join-1',
            payloadEventId: 'evt-legacy-join-1',
            controlText: joinRequest,
            senderDeviceId: 'viewer-legacy-device',
            senderProfileId: 'viewer-legacy',
            payloadCreatedAtMs: 5000,
            receivedAtMs: 5100,
          ),
          isTrue,
        );

        final afterMembers = await controller.listRoomMembershipStates(groupId);
        expect(
          afterMembers.map((state) => state.profileId),
          isNot(contains('viewer-legacy')),
        );

        final settings = await controller.getRoomSettings(groupId);
        expect(settings.stateVersion, 2);
        expect(settings.membershipVersion, 1);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'group system command materializes structured room service event',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'peer-1',
        deviceId: 'peer-device',
        crypto: DartCryptoProvider(
          Uint8List.fromList(List<int>.generate(32, (index) => index + 11)),
        ),
      );

      try {
        final snapshot = AppController.encodeRoomInviteCommandForTesting(
          <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:alpha',
            'groupTitle': 'Alpha Room',
            'ownerProfileId': 'owner-1',
            'stateVersion': 2,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[],
          },
        );
        await _deliverInboundControl(
          controller: controller,
          db: db,
          transportMsgId: 'transport-snapshot-system',
          payloadEventId: 'evt-snapshot-system',
          controlText: snapshot,
          senderDeviceId: 'owner-device',
          senderProfileId: 'owner-1',
          payloadCreatedAtMs: 1000,
          receivedAtMs: 1100,
        );

        final systemCommand = AppController.encodeGroupMessageCommandForTesting(
          <String, Object?>{
            'groupId': 'group:alpha',
            'groupTitle': 'Alpha Room',
            'kind': 'system',
            'msgEventId': 'system-evt-1',
            'action': RoomSystemEventAction.ownerTransferred,
            'actorProfileId': 'owner-1',
            'actorDisplayName': 'Owner',
            'targetProfileId': 'peer-1',
            'targetDisplayName': 'Peer',
            'createdAtMs': 2000,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'text': 'Owner transferred room ownership to Peer.',
          },
        );

        expect(
          await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-system-1',
            payloadEventId: 'evt-system-1',
            controlText: systemCommand,
            senderDeviceId: 'owner-device',
            senderProfileId: 'owner-1',
            payloadCreatedAtMs: 2000,
            receivedAtMs: 2100,
          ),
          isTrue,
        );

        final rows = await db.listEventsChronological('group:alpha', limit: 10);
        expect(rows, hasLength(1));
        expect(rows.first['type'], 'sys');

        final payload = await controller.payloadEventForChatEvent(
          ChatEvent(
            eventId: (rows.first['event_id'] as String?) ?? '',
            createdAtMs: (rows.first['created_at_ms'] as num?)?.toInt() ?? 0,
            type: (rows.first['type'] as String?) ?? 'msg',
            ciphertextB64: (rows.first['ciphertext_b64'] as String?) ?? '',
            senderDeviceId: (rows.first['sender_device_id'] as String?) ?? '',
            localState: (rows.first['local_state'] as String?) ?? 'received',
            payloadEventId: rows.first['payload_event_id'] as String?,
            localCiphertextB64: rows.first['local_ciphertext_b64'] as String?,
          ),
        );

        expect(payload, isA<SystemEventV1>());
        final systemEvent = payload! as SystemEventV1;
        expect(systemEvent.action, RoomSystemEventAction.ownerTransferred);
        expect(systemEvent.actorProfileId, 'owner-1');
        expect(systemEvent.targetProfileId, 'peer-1');
      } finally {
        await db.close();
      }
    },
  );

  test('stale room snapshots do not overwrite newer room state', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();

    controller.seedRoomRuntimeForTesting(db: db, profileId: 'owner-1');

    try {
      final newestSnapshot = AppController.encodeRoomInviteCommandForTesting(
        <String, Object?>{
          'v': 1,
          'action': 'snapshot',
          'groupId': 'group:alpha',
          'groupTitle': 'Alpha Room',
          'ownerProfileId': 'owner-1',
          'allowMedia': false,
          'stateVersion': 5,
          'memberProfileIds': const <String>['owner-1', 'peer-1'],
          'adminProfileIds': const <String>['owner-1'],
          'inviteLinks': const <Map<String, Object?>>[],
        },
      );
      final staleSnapshot = AppController.encodeRoomInviteCommandForTesting(
        <String, Object?>{
          'v': 1,
          'action': 'snapshot',
          'groupId': 'group:alpha',
          'groupTitle': 'Stale Room',
          'ownerProfileId': 'owner-1',
          'allowMedia': true,
          'stateVersion': 4,
          'memberProfileIds': const <String>['owner-1'],
          'adminProfileIds': const <String>['owner-1'],
          'inviteLinks': const <Map<String, Object?>>[],
        },
      );

      expect(
        await _deliverInboundControl(
          controller: controller,
          db: db,
          transportMsgId: 'transport-snapshot-5',
          payloadEventId: 'evt-snapshot-5',
          controlText: newestSnapshot,
          senderDeviceId: 'owner-device',
          senderProfileId: 'owner-1',
          payloadCreatedAtMs: 5000,
          receivedAtMs: 6000,
        ),
        isTrue,
      );
      expect(
        await _deliverInboundControl(
          controller: controller,
          db: db,
          transportMsgId: 'transport-snapshot-4',
          payloadEventId: 'evt-snapshot-4',
          controlText: staleSnapshot,
          senderDeviceId: 'owner-device',
          senderProfileId: 'owner-1',
          payloadCreatedAtMs: 4000,
          receivedAtMs: 7000,
        ),
        isTrue,
      );

      final convo = await db.convoGet('group:alpha');
      expect(convo?['title'], 'Alpha Room');

      final members = await db.groupMembersList('group:alpha');
      expect(
        members
            .map((row) => row['member_profile_id'] as String?)
            .whereType<String>()
            .toList(),
        unorderedEquals(const <String>['owner-1', 'peer-1']),
      );

      final settings = await controller.getRoomSettings('group:alpha');
      expect(settings.stateVersion, 5);
      expect(settings.allowMedia, isFalse);
    } finally {
      await db.close();
    }
  });

  test(
    'forced authoritative room snapshot overwrites newer optimistic local room state',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(db: db, profileId: 'owner-1');

      try {
        await controller.applyRoomSnapshotPayloadForTesting(
          db: db,
          payload: <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:alpha',
            'groupTitle': 'Local Pending Title',
            'ownerProfileId': 'owner-1',
            'allowMedia': false,
            'stateVersion': 8,
            'membershipVersion': 8,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[],
          },
        );

        await controller.applyRoomSnapshotPayloadForTesting(
          db: db,
          forceAuthoritative: true,
          payload: <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:alpha',
            'groupTitle': 'Relay Truth Title',
            'ownerProfileId': 'owner-1',
            'allowMedia': true,
            'stateVersion': 4,
            'membershipVersion': 4,
            'memberProfileIds': const <String>['owner-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[],
          },
        );

        final convo = await db.convoGet('group:alpha');
        expect(convo?['title'], 'Relay Truth Title');

        final members = await db.groupMembersList('group:alpha');
        expect(
          members
              .map((row) => row['member_profile_id'] as String?)
              .whereType<String>()
              .toList(),
          unorderedEquals(const <String>['owner-1']),
        );

        final settings = await controller.getRoomSettings('group:alpha');
        expect(settings.stateVersion, 4);
        expect(settings.membershipVersion, 4);
        expect(settings.allowMedia, isTrue);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'reconnect room resync skips unchanged authoritative room versions without fetching memberships',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final identityKeyPair = await Ed25519().newKeyPair();
      final requests = <String>[];
      final relay = await _buildRelayClientForRoomTests(
        db: db,
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'GET' &&
              request.url.path == '/v1/rooms/group%3Aalpha') {
            return http.Response(
              jsonEncode(
                _relayRoomMap(
                  roomId: 'group:alpha',
                  version: 6,
                  membershipVersion: 9,
                  title: 'Alpha Room',
                  allowMedia: false,
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
      controller.seedRelayRuntimeForTesting(relay: relay);

      try {
        await controller.applyRoomSnapshotPayloadForTesting(
          db: db,
          payload: <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:alpha',
            'groupTitle': 'Alpha Room',
            'ownerProfileId': 'owner-1',
            'allowMedia': false,
            'stateVersion': 6,
            'membershipVersion': 9,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[],
          },
        );

        await controller.resyncKnownRoomsFromRelayBestEffortForTesting();

        expect(requests, <String>['GET /v1/rooms/group%3Aalpha']);
        expect(
          await controller.listGroupMembers('group:alpha'),
          unorderedEquals(const <String>['owner-1', 'peer-1']),
        );

        final settings = await controller.getRoomSettings('group:alpha');
        expect(settings.stateVersion, 6);
        expect(settings.membershipVersion, 9);
        expect(settings.allowMedia, isFalse);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'reconnect room resync reuses local memberships for state-only authoritative drift',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final identityKeyPair = await Ed25519().newKeyPair();
      final requests = <String>[];
      final relay = await _buildRelayClientForRoomTests(
        db: db,
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'GET' &&
              request.url.path == '/v1/rooms/group%3Aalpha') {
            return http.Response(
              jsonEncode(
                _relayRoomMap(
                  roomId: 'group:alpha',
                  version: 7,
                  membershipVersion: 9,
                  title: 'Relay Truth Title',
                  allowMedia: true,
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
      controller.seedRelayRuntimeForTesting(relay: relay);

      try {
        await controller.applyRoomSnapshotPayloadForTesting(
          db: db,
          payload: <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:alpha',
            'groupTitle': 'Local Pending Title',
            'ownerProfileId': 'owner-1',
            'allowMedia': false,
            'stateVersion': 6,
            'membershipVersion': 9,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[],
          },
        );

        await controller.resyncKnownRoomsFromRelayBestEffortForTesting();

        expect(requests, <String>['GET /v1/rooms/group%3Aalpha']);
        expect(
          await controller.listGroupMembers('group:alpha'),
          unorderedEquals(const <String>['owner-1', 'peer-1']),
        );

        final convo = await db.convoGet('group:alpha');
        expect(convo?['title'], 'Relay Truth Title');

        final settings = await controller.getRoomSettings('group:alpha');
        expect(settings.stateVersion, 7);
        expect(settings.membershipVersion, 9);
        expect(settings.allowMedia, isTrue);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'reconnect room resync force-applies relay truth when local room versions ran ahead',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      final identityKeyPair = await Ed25519().newKeyPair();
      final requests = <String>[];
      final room = _relayRoomMap(
        roomId: 'group:alpha',
        version: 4,
        membershipVersion: 4,
        title: 'Relay Truth Title',
        allowMedia: true,
      );
      final relay = await _buildRelayClientForRoomTests(
        db: db,
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'GET' &&
              request.url.path == '/v1/rooms/group%3Aalpha') {
            return http.Response(jsonEncode(room), 200);
          }
          if (request.method == 'GET' &&
              request.url.path == '/v1/rooms/group%3Aalpha/members') {
            return http.Response(
              jsonEncode(<String, Object?>{
                'room': room,
                'members': <Map<String, Object?>>[
                  _relayMembershipMap(
                    roomId: 'group:alpha',
                    profileId: 'owner-1',
                    role: 'owner',
                  ),
                ],
              }),
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
      controller.seedRelayRuntimeForTesting(relay: relay);

      try {
        await controller.applyRoomSnapshotPayloadForTesting(
          db: db,
          payload: <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:alpha',
            'groupTitle': 'Local Pending Title',
            'ownerProfileId': 'owner-1',
            'allowMedia': false,
            'stateVersion': 8,
            'membershipVersion': 8,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[],
          },
        );

        await controller.resyncKnownRoomsFromRelayBestEffortForTesting();

        expect(requests, <String>[
          'GET /v1/rooms/group%3Aalpha',
          'GET /v1/rooms/group%3Aalpha/members',
        ]);
        expect(
          await controller.listGroupMembers('group:alpha'),
          unorderedEquals(const <String>['owner-1']),
        );

        final convo = await db.convoGet('group:alpha');
        expect(convo?['title'], 'Relay Truth Title');

        final settings = await controller.getRoomSettings('group:alpha');
        expect(settings.stateVersion, 4);
        expect(settings.membershipVersion, 4);
        expect(settings.allowMedia, isTrue);
      } finally {
        await db.close();
      }
    },
  );

  test('planRoomRelayResync skips unchanged room versions', () {
    final plan = planRoomRelayResync(
      hasLocalRoomState: true,
      localStateVersion: 6,
      localMembershipVersion: 9,
      remoteStateVersion: 6,
      remoteMembershipVersion: 9,
    );

    expect(plan.shouldRefresh, isFalse);
    expect(plan.refreshMemberships, isFalse);
    expect(plan.forceAuthoritative, isFalse);
  });

  test(
    'planRoomRelayResync reuses local memberships for state-only change',
    () {
      final plan = planRoomRelayResync(
        hasLocalRoomState: true,
        localStateVersion: 6,
        localMembershipVersion: 9,
        remoteStateVersion: 7,
        remoteMembershipVersion: 9,
      );

      expect(plan.shouldRefresh, isTrue);
      expect(plan.refreshMemberships, isFalse);
      expect(plan.forceAuthoritative, isFalse);
    },
  );

  test(
    'planRoomRelayResync forces relay truth when local versions run ahead',
    () {
      final plan = planRoomRelayResync(
        hasLocalRoomState: true,
        localStateVersion: 8,
        localMembershipVersion: 8,
        remoteStateVersion: 4,
        remoteMembershipVersion: 4,
      );

      expect(plan.shouldRefresh, isTrue);
      expect(plan.refreshMemberships, isTrue);
      expect(plan.forceAuthoritative, isTrue);
    },
  );

  test(
    'planAuthoritativeRoomSyncHintResync skips unchanged hinted versions',
    () {
      final plan = planAuthoritativeRoomSyncHintResync(
        hasLocalRoomState: true,
        localStateVersion: 6,
        localMembershipVersion: 9,
        hintedStateVersion: 6,
        hintedMembershipVersion: 9,
      );

      expect(plan, isNotNull);
      expect(plan!.shouldRefresh, isFalse);
      expect(plan.refreshMemberships, isFalse);
      expect(plan.forceAuthoritative, isFalse);
    },
  );

  test(
    'planAuthoritativeRoomSyncHintResync keeps state-only reconcile when memberships are unchanged',
    () {
      final plan = planAuthoritativeRoomSyncHintResync(
        hasLocalRoomState: true,
        localStateVersion: 6,
        localMembershipVersion: 9,
        hintedStateVersion: 7,
        hintedMembershipVersion: 9,
      );

      expect(plan, isNotNull);
      expect(plan!.shouldRefresh, isTrue);
      expect(plan.refreshMemberships, isFalse);
      expect(plan.forceAuthoritative, isFalse);
    },
  );

  test(
    'planAuthoritativeRoomSyncHintResync falls back when hint omits versions',
    () {
      final plan = planAuthoritativeRoomSyncHintResync(
        hasLocalRoomState: true,
        localStateVersion: 6,
        localMembershipVersion: 9,
        hintedStateVersion: 0,
        hintedMembershipVersion: 0,
      );

      expect(plan, isNull);
    },
  );

  test('planAuthoritativeRoomSyncHintResync forces invite-link refresh', () {
    final plan = planAuthoritativeRoomSyncHintResync(
      hasLocalRoomState: true,
      localStateVersion: 6,
      localMembershipVersion: 9,
      hintedStateVersion: 6,
      hintedMembershipVersion: 9,
      includeInviteLinks: true,
    );

    expect(plan, isNotNull);
    expect(plan!.shouldRefresh, isTrue);
    expect(plan.refreshMemberships, isTrue);
    expect(plan.forceAuthoritative, isFalse);
  });

  test(
    'planAuthoritativeRoomSyncHintResync preserves force-authoritative refresh when local versions run ahead',
    () {
      final plan = planAuthoritativeRoomSyncHintResync(
        hasLocalRoomState: true,
        localStateVersion: 8,
        localMembershipVersion: 8,
        hintedStateVersion: 4,
        hintedMembershipVersion: 4,
      );

      expect(plan, isNotNull);
      expect(plan!.shouldRefresh, isTrue);
      expect(plan.refreshMemberships, isTrue);
      expect(plan.forceAuthoritative, isTrue);
    },
  );

  test('room snapshot command materializes avatar payload', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();
    final avatarBytes = _sampleAvatarImageBytes();
    final avatarHash = await _roomAvatarHash(avatarBytes);

    controller.seedRoomRuntimeForTesting(db: db, profileId: 'owner-1');

    try {
      final snapshot = AppController.encodeRoomInviteCommandForTesting(
        <String, Object?>{
          'v': 1,
          'action': 'snapshot',
          'groupId': 'group:avatar-room',
          'groupTitle': 'Avatar Room',
          'ownerProfileId': 'owner-1',
          'stateVersion': 3,
          'avatarHash': avatarHash,
          'avatarImageB64': base64Encode(avatarBytes),
          'memberProfileIds': const <String>['owner-1', 'peer-1'],
          'adminProfileIds': const <String>['owner-1'],
          'inviteLinks': const <Map<String, Object?>>[],
        },
      );

      expect(
        await _deliverInboundControl(
          controller: controller,
          db: db,
          transportMsgId: 'transport-avatar-snapshot',
          payloadEventId: 'evt-avatar-snapshot',
          controlText: snapshot,
          senderDeviceId: 'owner-device',
          senderProfileId: 'owner-1',
          payloadCreatedAtMs: 5000,
          receivedAtMs: 6000,
        ),
        isTrue,
      );

      final settings = await controller.getRoomSettings('group:avatar-room');
      expect(settings.avatarHash, avatarHash);
      expect(settings.avatarPath, isNotNull);
      expect(File(settings.avatarPath!).existsSync(), isTrue);

      final convo = (await controller.listConversations()).firstWhere(
        (conversation) => conversation.convoId == 'group:avatar-room',
      );
      expect(convo.avatarPath, settings.avatarPath);
    } finally {
      await db.close();
    }
  });

  test(
    'authoritative room snapshots prevent removed members from reappearing via group fanout',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: DartCryptoProvider(
          Uint8List.fromList(List<int>.generate(32, (index) => index)),
        ),
      );

      try {
        final snapshot = AppController.encodeRoomInviteCommandForTesting(
          <String, Object?>{
            'v': 1,
            'action': 'snapshot',
            'groupId': 'group:alpha',
            'groupTitle': 'Alpha Room',
            'ownerProfileId': 'owner-1',
            'stateVersion': 3,
            'memberProfileIds': const <String>['owner-1', 'peer-1'],
            'adminProfileIds': const <String>['owner-1'],
            'inviteLinks': const <Map<String, Object?>>[],
          },
        );
        await _deliverInboundControl(
          controller: controller,
          db: db,
          transportMsgId: 'transport-snapshot',
          payloadEventId: 'evt-snapshot',
          controlText: snapshot,
          senderDeviceId: 'owner-device',
          senderProfileId: 'owner-1',
          payloadCreatedAtMs: 3000,
          receivedAtMs: 4000,
        );

        final removedMemberMessage =
            AppController.encodeGroupMessageCommandForTesting(<String, Object?>{
              'groupId': 'group:alpha',
              'groupTitle': 'Removed Member Room',
              'kind': 'message',
              'msgEventId': 'group-msg-1',
              'text': 'late fanout from removed member',
              'createdAtMs': 5000,
              'memberProfileIds': const <String>[
                'owner-1',
                'peer-1',
                'removed-1',
              ],
            });

        expect(
          await _deliverInboundControl(
            controller: controller,
            db: db,
            transportMsgId: 'transport-removed-fanout',
            payloadEventId: 'evt-removed-fanout',
            controlText: removedMemberMessage,
            senderDeviceId: 'removed-device',
            senderProfileId: 'removed-1',
            payloadCreatedAtMs: 5000,
            receivedAtMs: 6000,
          ),
          isTrue,
        );

        final convo = await db.convoGet('group:alpha');
        expect(convo?['title'], 'Alpha Room');

        final members = await db.groupMembersList('group:alpha');
        expect(
          members
              .map((row) => row['member_profile_id'] as String?)
              .whereType<String>()
              .toList(),
          unorderedEquals(const <String>['owner-1', 'peer-1']),
        );

        final events = await db.listEventsChronological(
          'group:alpha',
          limit: 10,
        );
        expect(events, isEmpty);
      } finally {
        await db.close();
      }
    },
  );

  test('local room mutations bump authoritative state version', () async {
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
      expect((await controller.getRoomSettings(groupId)).stateVersion, 1);

      await controller.updateRoomBasics(
        groupId: groupId,
        title: 'Alpha Room Prime',
        description: 'Release room',
      );
      expect((await controller.getRoomSettings(groupId)).stateVersion, 2);

      final updatedSettings = await controller.getRoomSettings(groupId);
      await controller.updateRoomSettings(
        groupId: groupId,
        settings: updatedSettings.copyWith(allowMedia: false),
      );
      expect((await controller.getRoomSettings(groupId)).stateVersion, 3);

      await controller.addGroupMembers(
        groupId: groupId,
        memberProfileIds: const <String>['peer-2'],
      );
      expect((await controller.getRoomSettings(groupId)).stateVersion, 4);

      final link = (await controller.listRoomInviteLinks(groupId)).first;
      await controller.setRoomInviteLinkRevoked(
        linkId: link.linkId,
        revoked: true,
      );
      expect((await controller.getRoomSettings(groupId)).stateVersion, 5);
    } finally {
      await db.close();
    }
  });

  test('local room avatar mutations update avatar state and version', () async {
    final controller = AppController();
    final db = await AppDb.openForTesting();
    final avatarBytes = _sampleAvatarImageBytes();

    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
    );

    try {
      final groupId = await controller.createGroup(
        title: 'Avatar Room',
        memberProfileIds: const <String>['peer-1'],
      );

      await controller.setRoomAvatarFromImageBytes(
        groupId: groupId,
        bytes: avatarBytes,
      );

      final withAvatar = await controller.getRoomSettings(groupId);
      final avatarPath = withAvatar.avatarPath;
      expect(withAvatar.stateVersion, 2);
      expect(withAvatar.avatarHash, isNotNull);
      expect(withAvatar.avatarHash, isNotEmpty);
      expect(avatarPath, isNotNull);
      expect(File(avatarPath!).existsSync(), isTrue);

      final convoWithAvatar = (await controller.listConversations()).firstWhere(
        (conversation) => conversation.convoId == groupId,
      );
      expect(convoWithAvatar.avatarPath, avatarPath);

      await controller.removeRoomAvatar(groupId: groupId);

      final withoutAvatar = await controller.getRoomSettings(groupId);
      expect(withoutAvatar.stateVersion, 3);
      expect(withoutAvatar.avatarHash, isNull);
      expect(withoutAvatar.avatarPath, isNull);
      expect(File(avatarPath).existsSync(), isFalse);

      final convoWithoutAvatar = (await controller.listConversations())
          .firstWhere((conversation) => conversation.convoId == groupId);
      expect(convoWithoutAvatar.avatarPath, isNull);
    } finally {
      await db.close();
    }
  });
}
