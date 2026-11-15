// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ЗАКРЫТЫЕ ТЕМЫ (06.10.2026, docs/TZ_ROOM_PRIVATE_TOPICS_2026-10-06.md).
//
// Закрытая тема — отдельная комната со своим составом и ключом, привязанная к
// основной. Здесь — клиентская половина: разбор ответа реле, хранение связи,
// список чатов, полоса тем и то, что старые ответы читаются как раньше.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/security/auth_signer.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';

Conversation _c(String id, {int at = 0, int unread = 0, int? pinned}) =>
    Conversation(
      convoId: id,
      peerProfileId: null,
      title: id,
      avatarPath: null,
      lastEventAtMs: at,
      pinnedAtMs: pinned,
      muted: false,
      archivedAtMs: null,
      autoDeleteSeconds: null,
      emoji: null,
      unreadCount: unread,
    );

Map<String, dynamic> _roomJson([Map<String, dynamic> extra = const {}]) => {
  'room_id': 'group:r1',
  'version': 1,
  'membership_version': 1,
  'owner_profile_id': 'P1',
  'created_by_device_id': 'D1',
  'title': 'Команда',
  ...extra,
};

void main() {
  group('ответ реле', () {
    test('🔴 старое реле без полей — обычная комната', () {
      final room = RelayRoom.fromJson(_roomJson());
      expect(room.kind, kRelayRoomKindRoom);
      expect(room.parentRoomId, isNull);
      expect(room.isTopic, isFalse);
      expect(room.allowMembersCreateTopics, isFalse);
    });

    test('закрытая ветка: вид и родитель', () {
      final room = RelayRoom.fromJson(
        _roomJson({
          'kind': 'topic',
          'parent_room_id': 'group:parent',
          'allow_members_create_topics': true,
        }),
      );
      expect(room.isTopic, isTrue);
      expect(room.parentRoomId, 'group:parent');
      expect(room.allowMembersCreateTopics, isTrue);
    });

    test('неизвестный вид — обычная комната', () {
      final room = RelayRoom.fromJson(
        _roomJson({'kind': 'channel', 'parent_room_id': 'group:x'}),
      );
      expect(room.isTopic, isFalse);
    });
  });

  group('подпись создания ветки', () {
    test('🔴 формат — ровно как у реле (CREATE-TOPIC-V1)', () {
      final bytes = AuthSigner.relayHttpRoomCreateTopicMessage(
        deviceId: 'dev',
        roomId: 'group:t1',
        parentRoomId: 'group:room',
        title: 'Совет',
        tsMs: 42,
        nonceB64: 'n0',
      );
      expect(
        utf8.decode(bytes),
        'SECRETLY-RELAY-HTTP-ROOM-CREATE-TOPIC-V1\n'
        'device_id=dev\n'
        'room_id=group:t1\n'
        'parent_room_id=group:room\n'
        'title=Совет\n'
        'ts_ms=42\n'
        'nonce_b64=n0\n',
      );
    });

    test('без родителя — прежняя подпись комнаты', () {
      final src = File('lib/transport/relay_client.dart').readAsStringSync();
      expect(
        src.contains('cleanedParent.isEmpty\n          ? AuthSigner.relayHttpRoomCreateMessage('),
        isTrue,
      );
    });
  });

  group('настройка «участники создают закрытые темы»', () {
    List<int> sign({bool? flag}) =>
        AuthSigner.relayHttpRoomSettingsUpdateMessage(
          deviceId: 'dev_1',
          roomId: 'room_parent',
          reactionsMode: 'all',
          allowText: true,
          allowMedia: true,
          allowAddMembers: false,
          allowPinMessages: true,
          allowChangeGroupInfo: true,
          allowChangeTag: false,
          joinApprovalRequired: false,
          slowModeSeconds: 30,
          chatHistoryVisible: true,
          tsMs: 1700000000000,
          nonceB64: 'bm9uY2U=',
          allowMembersCreateTopics: flag,
        );

    test('🔴 с флагом — V2 ровно как у реле', () {
      expect(
        utf8.decode(sign(flag: true)),
        'SECRETLY-RELAY-HTTP-ROOM-SETTINGS-UPDATE-V2\ndevice_id=dev_1\n'
        'room_id=room_parent\nreactions_mode=all\nallow_text=1\n'
        'allow_media=1\nallow_add_members=0\nallow_pin_messages=1\n'
        'allow_change_group_info=1\nallow_change_tag=0\n'
        'join_approval_required=0\nslow_mode_seconds=30\n'
        'chat_history_visible=1\nallow_members_create_topics=1\n'
        'ts_ms=1700000000000\nnonce_b64=bm9uY2U=\n',
      );
    });

    test('🔴 без флага — прежняя V1, байт в байт', () {
      final text = utf8.decode(sign());
      expect(text.startsWith('SECRETLY-RELAY-HTTP-ROOM-SETTINGS-UPDATE-V1\n'),
          isTrue);
      expect(text.contains('allow_members_create_topics'), isFalse);
    });

    test('у закрытой темы нет ссылок-приглашений', () {
      const topic = RoomSettings(
        ownerProfileId: 'P1',
        description: null,
        reactionsMode: RoomReactionsMode.all,
        allowTextMessages: true,
        allowMedia: true,
        allowAddMembers: true,
        allowPinMessages: true,
        allowChangeGroupInfo: true,
        allowChangeTag: false,
        joinApprovalRequired: false,
        slowModeSeconds: 0,
        chatHistoryVisible: false,
        membershipVersion: 1,
        stateVersion: 1,
        parentRoomId: 'group:room',
        roomKind: kRoomKindTopic,
      );
      final policy = evaluateRoomPolicyState(
        settings: topic,
        isMember: true,
        role: RoomMemberRole.owner,
        lastOwnMessageAtMs: null,
      );
      expect(policy.canManageInviteLinks, isFalse);
      final room = evaluateRoomPolicyState(
        settings: topic.copyWith(roomKind: kRoomKindRoom),
        isMember: true,
        role: RoomMemberRole.owner,
        lastOwnMessageAtMs: null,
      );
      expect(room.canManageInviteLinks, isTrue);
    });
  });

  group('список чатов', () {
    test('ветка прячется в комнату, непрочитанное складывается', () {
      final out = foldPrivateTopicConversations(
        [_c('group:room', at: 10, unread: 1), _c('group:t1', at: 5, unread: 3)],
        {'group:t1': 'group:room'},
      );
      expect(out.map((c) => c.convoId), ['group:room']);
      expect(out.single.unreadCount, 4);
    });

    test('свежая ветка поднимает комнату на своё место', () {
      final out = foldPrivateTopicConversations(
        [
          _c('group:t1', at: 30),
          _c('direct:a', at: 20),
          _c('group:room', at: 10),
        ],
        {'group:t1': 'group:room'},
      );
      expect(out.map((c) => c.convoId), ['group:room', 'direct:a']);
      expect(out.first.lastEventAtMs, 30);
    });

    test('🔴 комнаты нет в списке — ветка остаётся отдельной строкой', () {
      // Потерять переписку хуже, чем показать лишнюю строку.
      final out = foldPrivateTopicConversations(
        [_c('group:t1', at: 5, unread: 2)],
        {'group:t1': 'group:gone'},
      );
      expect(out.single.convoId, 'group:t1');
      expect(out.single.unreadCount, 2);
    });

    test('без веток список не трогается', () {
      final list = [_c('group:room'), _c('direct:a')];
      expect(identical(foldPrivateTopicConversations(list, const {}), list),
          isTrue);
    });
  });

  group('хранение', () {
    Future<void> upsert(
      AppDb db, {
      String? parent,
      String? kind,
      bool? allow,
    }) => db.groupSettingsUpsert(
      groupId: 'group:t1',
      ownerProfileId: 'P1',
      reactionsMode: 'all',
      allowText: true,
      allowMedia: true,
      allowAddMembers: true,
      allowPinMessages: true,
      allowChangeGroupInfo: true,
      allowChangeTag: false,
      joinApprovalRequired: false,
      slowModeSeconds: 0,
      chatHistoryVisible: false,
      membershipVersion: 1,
      stateVersion: 1,
      parentRoomId: parent,
      roomKind: kind,
      allowMembersCreateTopics: allow,
    );

    test('связь с комнатой сохраняется и находится', () async {
      final db = await AppDb.openForTesting();
      try {
        await upsert(db, parent: 'group:room', kind: 'topic');
        expect(await db.groupSettingsChildRoomIds('group:room'), ['group:t1']);
        expect(await db.groupSettingsTopicParents(), {
          'group:t1': 'group:room',
        });
      } finally {
        await db.close();
      }
    });

    test('🔴 запись без новых полей не стирает связь', () async {
      // Запись идёт через REPLACE всеми колонками: вызов, который о ветках
      // не знает, иначе превратил бы ветку в обычную комнату.
      final db = await AppDb.openForTesting();
      try {
        await upsert(db, parent: 'group:room', kind: 'topic', allow: true);
        await upsert(db);
        final row = await db.groupSettingsGet('group:t1');
        expect(row!['parent_room_id'], 'group:room');
        expect(row['room_kind'], 'topic');
        expect(row['allow_members_create_topics'], 1);
      } finally {
        await db.close();
      }
    });

    test('ветки не входят в предел комнат тарифа', () async {
      final db = await AppDb.openForTesting();
      try {
        await upsert(db, parent: 'group:room', kind: 'topic');
        expect(await db.groupOwnedCount('P1'), 0);
      } finally {
        await db.close();
      }
    });
  });

  group('где это включено', () {
    final ctrl = File('lib/app/app_controller.dart').readAsStringSync();

    test('🔴 «я — ветка такой-то комнаты» принимается только от реле', () {
      // Снимок от участника мог бы подсунуть ложного родителя и спрятать
      // чужую комнату из списка чатов.
      expect(ctrl.contains('fromRelay && payload.containsKey(\'parentRoomId\')'),
          isTrue);
      expect(ctrl.contains('fromRelay && payload.containsKey(\'roomKind\')'),
          isTrue);
      final relayApply = ctrl.indexOf('Future<void> _applyRelayRoomSnapshot(');
      expect(
        ctrl.indexOf('fromRelay: true', relayApply),
        greaterThan(relayApply),
      );
    });

    test('список чатов сворачивает ветки', () {
      expect(ctrl.contains('.then(_foldPrivateTopicsIntoRooms)'), isTrue);
    });

    test('телефон и компьютер показывают ветки в полосе тем', () {
      final mobile = File('lib/ui/chat_screen.dart').readAsStringSync();
      final desktop = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(mobile.contains('for (final topic in _privateTopics)'), isTrue);
      expect(desktop.contains('privateTopics: _privateTopics'), isTrue);
      expect(mobile.contains('showNewRoomTopicSheet('), isTrue);
      expect(desktop.contains('showDesktopNewTopicDialog('), isTrue);
    });

    test('предел веток — 20 (Р-4)', () {
      expect(kRoomPrivateTopicsMax, 20);
    });
  });
}
