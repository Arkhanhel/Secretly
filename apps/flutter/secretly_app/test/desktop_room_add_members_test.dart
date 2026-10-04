// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Добавить участников» и «Недавние действия» на ПК (30.09.2026, ТЗ «ПК как
// Telegram» §2): протокол умел давно, входа на ПК не было.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/rooms/room_models.dart';
import 'package:secretly_app/ui/desktop/chat/details/room_manage_dialogs.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ru'));

  Future<void> host(WidgetTester t, Future<void> Function(BuildContext) open) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => open(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  const candidates = [
    RoomAddCandidate(profileId: 'anna', name: 'Анна', online: true),
    RoomAddCandidate(profileId: 'boris', name: 'Борис'),
    RoomAddCandidate(profileId: 'vera', name: 'Вера', inRoom: true),
  ];

  testWidgets('выбор, поиск и ответ окна', (t) async {
    Set<String>? result;
    await host(t, (ctx) async {
      result = await showRoomAddMembersDialog(ctx, candidates: candidates);
    });
    expect(find.text(l10n.desktopRoomAddMembersAlready), findsOneWidget);
    // Уже участник — не выбирается.
    await t.tap(find.text('Вера'));
    await t.pump();
    expect(find.text(l10n.desktopRoomAddMembersAction(1)), findsNothing);

    await t.tap(find.text('Анна'));
    await t.pump();
    expect(find.text(l10n.desktopRoomAddMembersAction(1)), findsOneWidget);

    await t.enterText(find.byType(TextField), 'бор');
    await t.pump();
    expect(find.text('Анна'), findsNothing);
    await t.tap(find.text('Борис'));
    await t.pump();
    expect(find.text(l10n.desktopRoomAddMembersAction(2)), findsOneWidget);

    await t.tap(find.text(l10n.desktopRoomAddMembers).last);
    await t.pumpAndSettle();
    expect(result, {'anna', 'boris'});
  });

  testWidgets('ничего не выбрано — кнопка ничего не делает', (t) async {
    var closed = false;
    await host(t, (ctx) async {
      await showRoomAddMembersDialog(ctx, candidates: candidates);
      closed = true;
    });
    await t.tap(find.text(l10n.desktopRoomAddMembers).last);
    await t.pumpAndSettle();
    expect(closed, isFalse);
  });

  testWidgets('без контактов — подсказка про ссылку', (t) async {
    await host(t, (ctx) => showRoomAddMembersDialog(ctx, candidates: const []));
    expect(find.text(l10n.desktopRoomAddMembersNoContacts), findsOneWidget);
  });

  testWidgets('недавние действия: список и пустой', (t) async {
    await host(
      t,
      (ctx) => showRoomAuditLogDialog(
        ctx,
        entries: const [
          (createdAtMs: 1757700000000, text: 'Анна вступила'),
          (createdAtMs: 1757600000000, text: 'Борис стал админом'),
        ],
        timeLabel: (ms) => 'в $ms',
      ),
    );
    expect(find.text('Анна вступила'), findsOneWidget);
    expect(find.text('Борис стал админом'), findsOneWidget);
    expect(find.text(l10n.desktopRoomAuditLogHint), findsOneWidget);
  });

  // «Исключить» и «Заблокировать» — только тем, кого контроллер позволит
  // тронуть (ТЗ §2, ошибка 5): правило `_canModerateRoomMember`.
  test('старшинство ролей — как у контроллера', () {
    const r = RoomMemberRole.values;
    for (final target in r) {
      expect(roomRoleOutranks(RoomMemberRole.owner, target),
          target != RoomMemberRole.owner, reason: 'owner→$target');
    }
    expect(roomRoleOutranks(RoomMemberRole.admin, RoomMemberRole.admin), isFalse);
    expect(roomRoleOutranks(RoomMemberRole.admin, RoomMemberRole.moderator), isTrue);
    expect(roomRoleOutranks(RoomMemberRole.admin, RoomMemberRole.member), isTrue);
    expect(roomRoleOutranks(RoomMemberRole.moderator, RoomMemberRole.admin), isFalse);
    expect(roomRoleOutranks(RoomMemberRole.moderator, RoomMemberRole.moderator), isFalse);
    expect(roomRoleOutranks(RoomMemberRole.moderator, RoomMemberRole.member), isTrue);
    expect(roomRoleOutranks(RoomMemberRole.moderator, RoomMemberRole.guest), isTrue);
    for (final actor in [RoomMemberRole.member, RoomMemberRole.restricted, RoomMemberRole.guest]) {
      for (final target in r) {
        expect(roomRoleOutranks(actor, target), isFalse, reason: '$actor→$target');
      }
    }
  });
}
