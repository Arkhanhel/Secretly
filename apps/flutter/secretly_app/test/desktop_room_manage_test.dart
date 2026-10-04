// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 «НЕТ КНОПКИ ПОМЕНЯТЬ НАЗВАНИЕ ГРУППЫ У АДМИНА» (владелец, 28.09.2026).
//
// Протокол и контроллер умели всё давно: название, описание, фото,
// разрешения, удаление, передачу владения. На ПК не было ни одного входа.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/rooms/room_models.dart';
import 'package:secretly_app/ui/desktop/chat/details/room_manage_dialogs.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

final _ru = lookupAppLocalizations(const Locale('ru'));

RoomMember member(
  String id,
  String name, {
  RoomMemberRole role = RoomMemberRole.member,
  RoomMembershipStatus status = RoomMembershipStatus.active,
}) =>
    RoomMember(
      profileId: id,
      displayName: name,
      avatarPath: null,
      tag: null,
      role: role,
      isOnline: false,
      membershipStatus: status,
      membershipCreatedAtMs: 0,
      membershipUpdatedAtMs: 0,
    );

Widget host(Widget Function(BuildContext) open) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, child) => DColors(colors: kDColorsDark, child: child!),
      home: Scaffold(body: Builder(builder: open)),
    );

void main() {
  group('название группы', () {
    test('пустое и из пробелов — нельзя', () {
      expect(validateRoomTitle('', _ru), 'Введите название');
      expect(validateRoomTitle('   ', _ru), 'Введите название');
      expect(validateRoomTitle('Семья', _ru), isNull);
    });

    test('пределы — как у телефона', () {
      expect(kDesktopRoomTitleMaxLength, 96);
      expect(kDesktopRoomDescriptionMaxLength, 240);
    });
  });

  group('окно «Изменить группу»', () {
    testWidgets('сохраняет новое название и описание', (t) async {
      RoomEditResult? result;
      await t.pumpWidget(host((ctx) => TextButton(
            onPressed: () async {
              result = await showRoomEditDialog(
                ctx,
                groupId: 'group:1',
                title: 'Старое',
                description: '',
                avatarPath: null,
              );
            },
            child: const Text('открыть'),
          )));
      await t.tap(find.text('открыть'));
      await t.pumpAndSettle();
      expect(find.text('Изменить группу'), findsOneWidget);
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), '  Новое имя  ');
      await t.enterText(fields.at(1), 'Про кино');
      await t.tap(find.text('Сохранить'));
      await t.pumpAndSettle();
      expect(result?.title, 'Новое имя');
      expect(result?.description, 'Про кино');
      expect(result?.avatarBytes, isNull);
      expect(result?.clearAvatar, isFalse);
    });

    testWidgets('пустое название не закрывает окно и называет ошибку',
        (t) async {
      RoomEditResult? result;
      await t.pumpWidget(host((ctx) => TextButton(
            onPressed: () async {
              result = await showRoomEditDialog(
                ctx,
                groupId: 'group:1',
                title: 'Старое',
                description: '',
                avatarPath: null,
              );
            },
            child: const Text('открыть'),
          )));
      await t.tap(find.text('открыть'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), '   ');
      await t.tap(find.text('Сохранить'));
      await t.pumpAndSettle();
      expect(find.text('Введите название'), findsOneWidget);
      expect(result, isNull);
    });
  });

  group('разрешения', () {
    testWidgets('переключатели меняют настройки, медленный режим — ступенью',
        (t) async {
      RoomSettings? result;
      const base = RoomSettings(
        ownerProfileId: 'owner',
        description: null,
        reactionsMode: RoomReactionsMode.all,
        allowTextMessages: true,
        allowMedia: true,
        allowAddMembers: true,
        allowPinMessages: false,
        allowChangeGroupInfo: false,
        allowChangeTag: true,
        joinApprovalRequired: false,
        slowModeSeconds: 0,
        chatHistoryVisible: true,
        membershipVersion: 1,
        stateVersion: 1,
      );
      await t.pumpWidget(host((ctx) => TextButton(
            onPressed: () async {
              result = await showRoomPermissionsDialog(ctx, settings: base);
            },
            child: const Text('открыть'),
          )));
      await t.tap(find.text('открыть'));
      await t.pumpAndSettle();
      expect(find.text('Разрешения участников'), findsOneWidget);
      await t.ensureVisible(find.text('1 мин'));
      await t.pumpAndSettle();
      await t.tap(find.text('1 мин'));
      await t.pumpAndSettle();
      await t.tap(find.text('Сохранить'));
      await t.pumpAndSettle();
      expect(result?.slowModeSeconds, 60);
      expect(result?.ownerProfileId, 'owner');
    });

    test('подписи ступеней', () {
      expect(roomSlowModeLabel(0, _ru), 'Выкл.');
      expect(roomSlowModeLabel(30, _ru), '30 с');
      expect(roomSlowModeLabel(300, _ru), '5 мин');
      expect(roomSlowModeLabel(3600, _ru), '1 ч');
    });
  });

  group('выход владельца', () {
    test('кандидаты: без себя, без ушедших и гостей; админы первыми', () {
      final list = roomOwnershipCandidates(
        [
          member('me', 'Я', role: RoomMemberRole.owner),
          member('b', 'Борис'),
          member('a', 'Анна', role: RoomMemberRole.admin),
          member('g', 'Гость', role: RoomMemberRole.guest),
          member('x', 'Ушёл', status: RoomMembershipStatus.left),
        ],
        selfProfileId: 'me',
      );
      expect(list.map((m) => m.profileId), ['a', 'b']);
    });
  });

  group('🔴 вид группы подключён', () {
    final view = File('lib/ui/desktop/chat/details/room_details_view.dart')
        .readAsStringSync();

    test('карандаш у названия — тем, кому можно менять группу', () {
      expect(view, contains('onEdit: !isDemoRoomId(_groupId) &&'));
      expect(view, contains("(_policy?.canChangeGroupInfo ?? false)"));
      expect(view, contains('? _editRoom'));
    });

    test('в меню — «Изменить группу», «Разрешения», «Удалить группу»', () {
      expect(view, contains('label: l10n.desktopRoomEditTitle'));
      expect(view, contains('label: l10n.desktopRoomPermissionsMenu'));
      expect(view, contains('label: l10n.desktopRoomDelete'));
      expect(view, contains('if (policy.canManageSettings)'));
    });

    test('контроллер вызывается теми же методами, что у телефона', () {
      expect(view, contains('widget.controller.updateRoomProfile('));
      expect(view, contains('widget.controller.updateRoomSettings('));
      expect(view, contains('widget.controller.deleteRoom(_groupId)'));
    });

    test('владелец уходит через передачу или удаление, а не английскую ошибку',
        () {
      final leave = view.indexOf('Future<void> _leaveRoom() async {');
      final owner = view.indexOf('await _leaveAsOwner();', leave);
      expect(owner, greaterThan(leave));
      expect(view, contains('widget.controller.transferRoomOwnership('));
    });
  });
}
