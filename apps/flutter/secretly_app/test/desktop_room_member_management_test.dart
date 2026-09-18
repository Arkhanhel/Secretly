// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Управление участниками комнаты на компьютере.
//
// 🔴 ЧЕГО НЕ БЫЛО (13.09.2026). В шапке панели стояло «member management is
// mobile-only by design». Решением это не было: человек стучался в комнату, а
// владелец за компьютером об этом не узнавал ВОВСЕ — заявку можно было увидеть
// и принять только с телефона. Роль, исключение, блокировка и передача
// владения — то же самое.
//
// Проверка текстовая: панель тянет за собой контроллер, базу и сеть. Сторожить
// надо не раскладку, а два правила, без которых всё остальное опасно:
//
//   1) каждое действие показывается ТОЛЬКО тому, кому комната его разрешает —
//      меню, которое всегда отвечает отказом, обманывает;
//   2) отказ говорится словами, и словами ОБЩИМИ с телефоном, а не вторым
//      переводом, который разъедется на первой же правке.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final view = File(
    'lib/ui/desktop/chat/details/room_details_view.dart',
  ).readAsStringSync();
  final shared = File('lib/ui/room_membership_error_text.dart');
  final mobile = File('lib/ui/room_details_screen.dart').readAsStringSync();

  test('🔴 все действия с участником подключены', () {
    for (final api in const <String>[
      'setRoomMemberRole',
      'removeGroupMember',
      'banRoomMember',
      'unbanRoomMember',
      'transferRoomOwnership',
      'approveRoomJoinRequest',
      'declineRoomJoinRequest',
    ]) {
      expect(
        view.contains(api),
        isTrue,
        reason: '«$api» с компьютера недоступен',
      );
    }
  });

  test('🔴 заявки на вступление ВИДНЫ', () {
    expect(view.contains('listRoomJoinRequestsDetailed'), isTrue);
    expect(view.contains('_PendingSection'), isTrue);
    expect(
      view.contains('canApproveJoinRequests'),
      isTrue,
      reason: 'раздел заявок без проверки права — обещание, которое отклонят',
    );
  });

  test('заблокированных можно РАЗБЛОКИРОВАТЬ, а не только заблокировать', () {
    expect(view.contains('listRoomBannedMembersDetailed'), isTrue);
    expect(view.contains('_BannedSection'), isTrue);
  });

  test('🔴 каждое действие закрыто правом', () {
    for (final right in const <String>[
      'canManageMemberRoles',
      'canRemoveMembers',
      'canBanMembers',
      'canApproveJoinRequests',
      'canManageInviteLinks',
    ]) {
      expect(view.contains(right), isTrue, reason: 'право «$right» не спрошено');
    }
    expect(
      view.contains('policy.isOwner'),
      isTrue,
      reason: 'передача владения — только владельцем',
    );
  });

  test('🔴 себя и владельца не трогают', () {
    // Исключить себя кнопкой «исключить» или разжаловать владельца — это не
    // ошибка сервера, а дыра в раскладке: сервер откажет, но человек успеет
    // нажать и получить отказ там, где действия не должно быть вовсе.
    expect(view.contains('member.isOwner'), isTrue);
    expect(view.contains('widget.controller.profileId.trim()'), isTrue);
  });

  test('необратимое действие спрашивает подтверждение', () {
    // Передача владения возвращается только через нового владельца.
    final idx = view.indexOf('Future<void> _transferOwnership(');
    expect(idx, greaterThan(0));
    final body = view.substring(idx, idx + 900);
    expect(body.contains('_confirm('), isTrue);
  });

  group('тексты отказов — общие с телефоном', () {
    test('🔴 разбор переехал в общий файл', () {
      expect(
        shared.existsSync(),
        isTrue,
        reason: 'без общего файла десктоп завёл бы второй перевод',
      );
      expect(
        shared.readAsStringSync().contains('RoomMembershipFailureCode.ownerOnly'),
        isTrue,
      );
    });

    test('телефон зовёт ЕГО ЖЕ, а не свою копию', () {
      expect(mobile.contains("import 'room_membership_error_text.dart';"), isTrue);
      expect(
        mobile.contains('RoomMembershipFailureCode.cannotBanOwner'),
        isFalse,
        reason: 'копия текста осталась в мобильном экране — тексты разъедутся',
      );
    });

    test('десктоп разбирает ОБА вида отказа', () {
      // Правила комнаты и действия с участниками — разные наборы кодов, и ни
      // один не покрывает другой.
      expect(view.contains('tryRoomPolicyErrorText'), isTrue);
      expect(view.contains('tryRoomMembershipErrorText'), isTrue);
    });
  });
}
