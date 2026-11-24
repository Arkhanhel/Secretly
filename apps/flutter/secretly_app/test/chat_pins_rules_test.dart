// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Закреплённые (22.11.2026, Д-3, Д-5, Д-6, Д-7, Д-9, G-3): правила приёма.
// Формат команды не меняется — проверяется, что старая команда разбирается
// как раньше, а решения принимает получатель.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/chat_pins_logic.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/rooms/room_models.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  test('выключатели включены', () {
    expect(kPinJumpV2, isTrue);
    expect(kPinSyncChecksV2, isTrue);
  });

  group('Д-7: первый список после обновления в личном чате', () {
    const local = [
      PinnedRef(eventId: 'mine', previewText: 'моё', pinnedAtMs: 10),
      PinnedRef(eventId: 'both', previewText: 'старое', pinnedAtMs: 5),
    ];
    const inbound = [
      PinnedRef(eventId: 'theirs', previewText: 'их', pinnedAtMs: 20),
      PinnedRef(eventId: 'both', previewText: 'новое', pinnedAtMs: 6),
    ];

    test('ревизия 0 и свои закрепления — объединяем', () {
      expect(
        needsFirstAdoptionMerge(
          isGroup: false,
          localRevision: 0,
          localPins: local,
        ),
        isTrue,
      );
      final merged = mergeChatPins(local: local, inbound: inbound);
      expect(merged.map((p) => p.eventId), ['theirs', 'mine', 'both']);
      // Подпись — из пришедшего.
      expect(merged.last.previewText, 'новое');
      expect(mergeAddsPins(merged, inbound), isTrue);
    });

    test('ревизия известна, комната или своих нет — заменяем, как раньше', () {
      expect(
        needsFirstAdoptionMerge(isGroup: false, localRevision: 7, localPins: local),
        isFalse,
      );
      expect(
        needsFirstAdoptionMerge(isGroup: true, localRevision: 0, localPins: local),
        isFalse,
      );
      expect(
        needsFirstAdoptionMerge(isGroup: false, localRevision: 0, localPins: const []),
        isFalse,
      );
      final same = mergeChatPins(local: const [], inbound: inbound);
      expect(mergeAddsPins(same, inbound), isFalse);
    });
  });

  group('Д-3: удалённое у всех', () {
    test('уходит с плашки; без удалённых — тот же список', () {
      final pins = ['a', 'b', 'c'];
      expect(pinsWithoutDeleted(pins, (p) => p, {'b'}), ['a', 'c']);
      expect(identical(pinsWithoutDeleted(pins, (p) => p, {'x'}), pins), isTrue);
      expect(identical(pinsWithoutDeleted(pins, (p) => p, {}), pins), isTrue);
    });
  });

  group('Д-6: кто вправе прислать список комнаты', () {
    final allow = RoomSettings.defaults(ownerProfileId: 'OWNER');
    final deny = allow.copyWith(allowPinMessages: false);

    test('своё устройство — всегда', () {
      expect(
        roomPinAuthorAllowed(isOwn: true, authorRole: null, settings: null),
        isTrue,
      );
    });

    test('неизвестный автор — нет', () {
      expect(
        roomPinAuthorAllowed(isOwn: false, authorRole: null, settings: allow),
        isFalse,
      );
    });

    test('по роли и настройке комнаты — как кнопка «Закрепить»', () {
      bool ok(RoomMemberRole r, RoomSettings s) =>
          roomPinAuthorAllowed(isOwn: false, authorRole: r, settings: s);
      expect(ok(RoomMemberRole.owner, deny), isTrue);
      expect(ok(RoomMemberRole.admin, deny), isTrue);
      expect(ok(RoomMemberRole.moderator, deny), isTrue);
      expect(ok(RoomMemberRole.member, allow), isTrue);
      expect(ok(RoomMemberRole.member, deny), isFalse);
      expect(ok(RoomMemberRole.restricted, allow), isFalse);
      expect(ok(RoomMemberRole.guest, allow), isFalse);
    });
  });

  group('G-3: ревизия из будущего', () {
    const now = 1000000000;
    test('обычная — как есть, из будущего — время сообщения', () {
      expect(trustedPinFreshnessMs(now - 5, now), now - 5);
      expect(trustedPinFreshnessMs(0, now), 0);
      const far = now + 365 * 24 * 3600 * 1000;
      expect(trustedPinFreshnessMs(far, now, messageAtMs: now - 50), now - 50);
      expect(
        trustedPinFreshnessMs(far, now),
        now + kPinRevisionFutureSkewMs,
      );
      // Команда старой сборки (без ревизии) разбирается как раньше.
      final legacy = parsePinSyncCommand(
        buildPinSyncCommand(const [PinnedRef(eventId: 'p')]),
      )!;
      expect(trustedPinFreshnessMs(legacy.freshnessMs(77), now), 77);
    });
  });

  group('🔴 провода', () {
    final c = _src('lib/app/app_controller.dart');
    final s = _src('lib/ui/chat_screen.dart');

    test('Д-5: пустой список тоже повторяется', () {
      expect(c.contains('if (pins.isEmpty || revision <= 0) return;'), isFalse);
      final at = c.indexOf('Future<void> maybeResendChatPins(');
      final body = c.substring(at, at + 1200);
      expect(body.contains('if (revision <= 0) return;'), isTrue);
    });

    test('Д-6: приём в комнате проверяет автора — и контроллер, и экран', () {
      expect(c.contains('isOwn: inboundIsOwnSend,'), isTrue);
      expect(c.contains('senderProfileId: senderProfile,'), isTrue);
      expect(c.contains("'author_not_allowed'"), isTrue);
      expect(s.contains('widget.controller.canRoomMemberPin('), isTrue);
      expect(s.contains('_rejectedPinSyncAtMs.add(adoptedAtMs)'), isTrue);
    });

    test('Д-7: объединённый список рассылается обратно', () {
      final at = c.indexOf('Future<bool> _adoptInboundChatPins(');
      final body = c.substring(at, at + 3600);
      expect(body.contains('needsFirstAdoptionMerge('), isTrue);
      expect(body.contains('_sendChatPinsCommand(convoId: convoId'), isTrue);
    });

    test('Д-3 и Д-9 на экране', () {
      expect(s.contains('_notePinDeletedIds(deletedPayloadIds)'), isTrue);
      expect(s.contains('pinsWithoutDeleted(pins, (p) => p.eventId, _pinDeletedIds)'), isTrue);
      expect(s.contains('kPinSyncChecksV2 && _appliedPinSyncAtMs > 0'), isTrue);
      expect(s.contains('? (kPinSyncChecksV2 ? null : _groupPinnedMessageEventId)'), isTrue);
    });

    test('G-5: открытие не затирает только что принятый список', () {
      expect(s.contains('if (adoptedMeanwhile) return;'), isTrue);
    });
  });
}
