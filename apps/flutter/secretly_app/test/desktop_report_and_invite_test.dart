// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Две дыры из §5.6 ТЗ: жалоба и приглашение в комнату.
//
// 🔴 ЖАЛОБА. Окно `report_abuse_sheet` написано, переведено на восемь языков и
// умеет жаловаться и на комнату, и на профиль. На телефоне у него был ровно
// один вход — меню комнаты. На десктопе не было НИ ОДНОГО: у человека, которого
// травят в комнате, из компьютера не было выхода вообще.
//
// 🔴 ПРИГЛАШЕНИЕ. Ссылку-приглашение десктоп показывал — но только ГОТОВУЮ. У
// комнаты, где её ещё не заводили, строки не было вовсе, и позвать человека с
// компьютера было нельзя ничем: ни ссылки, ни кнопки, ни подсказки, что это
// делается с телефона.
//
// Проверка текстовая: обе точки входа живут в панелях, которые тянут за собой
// контроллер, базу и сеть. Сторожить здесь надо не раскладку, а то, ЧЕМ
// открывается окно и ПРИ КАКОМ условии показывается пункт.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final room = File(
    'lib/ui/desktop/chat/details/room_details_view.dart',
  ).readAsStringSync();
  final contact = File(
    'lib/ui/desktop/chat/details/contact_details_view.dart',
  ).readAsStringSync();

  group('жалоба', () {
    test('🔴 комната и собеседник открывают ОБЩЕЕ окно жалобы', () {
      for (final entry in <String, String>{
        'комната': room,
        'собеседник': contact,
      }.entries) {
        expect(
          entry.value.contains('showReportAbuseSheet'),
          isTrue,
          reason:
              'у «${entry.key}» нет входа в жалобу — писать вторую реализацию '
              'юридически значимого текста нельзя',
        );
      }
    });

    test('цель жалобы названа правильно', () {
      expect(room.contains('ReportAbuseTargetType.room'), isTrue);
      expect(contact.contains('ReportAbuseTargetType.profile'), isTrue);
    });

    test('подпись пункта — из общей локализации, а не своя', () {
      // Свой текст рядом означал бы второй перевод и русскую строку в
      // английском интерфейсе — ровно то, чего избегали при подключении
      // сверки кодов.
      expect(room.contains('reportAbuseMenuLabel(context)'), isTrue);
      expect(contact.contains('reportAbuseMenuLabel(context)'), isTrue);
      expect(
        room.contains("'Пожаловаться'"),
        isFalse,
        reason: 'литерал вместо локализации',
      );
      expect(contact.contains("'Пожаловаться'"), isFalse);
    });

    test('🔴 блокировку по итогам жалобы выполняет вызвавший', () {
      // Окно только ВОЗВРАЩАЕТ согласие (`blockTarget`) — само оно не
      // блокирует никого. Забыть это значит показать галочку, которая
      // молча ничего не делает.
      expect(contact.contains('result.blockTarget'), isTrue);
      expect(contact.contains('setProfileBlocked'), isTrue);
    });
  });

  group('приглашение в комнату', () {
    test('🔴 ссылка ЗАВОДИТСЯ, если её ещё нет', () {
      // 14.09.2026: порядок действий переехал в общую `copyRoomInviteLink` —
      // ту же последовательность повторяет кнопка «Пригласить» в окне
      // созвона, и разъехаться им нельзя.
      final share = File(
        'lib/ui/desktop/chat/details/room_invite_share.dart',
      ).readAsStringSync();
      expect(
        share.contains('createRoomInviteLink'),
        isTrue,
        reason:
            'без этого комната без готовой ссылки остаётся без входа с '
            'компьютера',
      );
      expect(
        room.contains('copyRoomInviteLink('),
        isTrue,
        reason: 'панель подробностей обязана звать общую последовательность',
      );
      expect(
        share.contains('requiresApproval: requiresApproval'),
        isTrue,
        reason:
            'новая ссылка наследует «вступление по подтверждению»: не '
            'унаследовать значит тихо открыть комнату, которую владелец '
            'закрыл',
      );
    });

    test('🔴 годной считается не отозванная, не просроченная, не исчерпанная',
        () {
      final share = File(
        'lib/ui/desktop/chat/details/room_invite_share.dart',
      ).readAsStringSync();
      final i = share.indexOf('RoomInviteLink? bestRoomInviteLink(');
      expect(i, greaterThan(0));
      final body = share.substring(i, (i + 700).clamp(0, share.length));
      for (final check in <String>[
        'link.revoked',
        'exp <= now',
        'link.useCount >= maxUses',
      ]) {
        expect(
          body.contains(check),
          isTrue,
          reason: 'пропустить любую из трёх причин — значит дать человеку '
              'ссылку, по которой никто не войдёт',
        );
      }
    });

    test('пункт показывается только тому, кому это разрешено', () {
      expect(room.contains('_canManageInvites'), isTrue);
      expect(room.contains('policy.canManageInviteLinks'), isTrue);
      expect(
        room.contains('if (_canManageInvites)'),
        isTrue,
        reason: 'кнопка, которая всегда отвечает отказом, — не кнопка',
      );
    });

    test('🔴 отказ комнаты говорится словами, а не текстом исключения', () {
      expect(room.contains('tryRoomPolicyErrorText'), isTrue);
    });

    test('одобрение вступления наследуется у комнаты', () {
      // Ссылка, заведённая мимо настройки комнаты, впустила бы людей без
      // одобрения там, где комната его требует.
      expect(room.contains('joinApprovalRequired'), isTrue);
    });
  });
}
