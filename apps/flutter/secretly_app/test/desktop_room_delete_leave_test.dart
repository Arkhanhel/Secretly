// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 «УДАЛИТЬ» У КОМНАТЫ В СПИСКЕ — «УДАЛИТЬ И ПОКИНУТЬ» (30.09.2026, ТЗ
// «ПК как Telegram» §2, ошибка 2).
//
// Раньше стирались только записи на этом компьютере, а человек оставался
// участником на реле: сообщения шли дальше, и первое же новое возвращало
// «удалённую» комнату в список.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/app/desktop_chats_section.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_deleted_chats.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/shell/desktop_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRooms extends AppController {
  _FakeRooms({required this.member});

  final bool member;
  final List<String> calls = <String>[];

  @override
  String get profileId => 'me';

  @override
  Future<List<Conversation>> listConversations() async => const [
    Conversation(
      convoId: 'group:team',
      peerProfileId: null,
      title: 'Команда',
      avatarPath: null,
      lastEventAtMs: 1757700000000,
      pinnedAtMs: null,
      muted: false,
      archivedAtMs: null,
      autoDeleteSeconds: null,
      emoji: null,
    ),
  ];

  @override
  Future<RoomPolicyState> getRoomPolicyState(
    String groupId, {
    String? profileIdOverride,
    int? nowMs,
  }) async => evaluateRoomPolicyState(
    settings: RoomSettings.defaults(ownerProfileId: 'someone-else'),
    isMember: member,
    role: RoomMemberRole.member,
    lastOwnMessageAtMs: null,
  );

  @override
  Future<void> leaveRoom(String groupId) async => calls.add('leave:$groupId');

  @override
  Future<void> clearChatHistory({required String convoId}) async =>
      calls.add('clear:$convoId');

  @override
  Future<void> deleteChat({required String convoId}) async =>
      calls.add('delete:$convoId');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
    // Снос прошлого теста помнится в памяти — без сброса комната пропала бы
    // из списка следующего.
    DesktopDeletedChats.resetForTest();
  });

  Future<void> pumpRooms(WidgetTester t, AppController ctrl) async {
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final vm = DesktopAppViewModel(controller: ctrl);
    addTearDown(vm.dispose);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: DesktopChatsSection(
              vm: vm,
              filter: ConversationFilter.groups,
              shellApi: DesktopShellApi(
                detailsOpen: false,
                toggleDetails: () {},
                openDetails: () {},
                closeDetails: () {},
                selectSection: (_) {},
                listWidth: 320,
                onListResize: (_) {},
                findRequests: ValueNotifier<int>(0),
                chatCycle: ValueNotifier<int>(0),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openRowMenu(WidgetTester t) async {
    await t.tapAt(
      t.getCenter(find.text('Команда').first),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await t.pumpAndSettle();
  }

  final l10n = lookupAppLocalizations(const Locale('ru'));

  testWidgets('участник: пункт «Удалить и покинуть» — выход, потом снос', (
    t,
  ) async {
    final ctrl = _FakeRooms(member: true);
    await pumpRooms(t, ctrl);
    await openRowMenu(t);
    expect(find.text(l10n.desktopRoomDeleteLeaveMenu), findsOneWidget);
    expect(find.text(l10n.delete), findsNothing);
    await t.tap(find.text(l10n.desktopRoomDeleteLeaveMenu));
    await t.pumpAndSettle();
    expect(find.text(l10n.desktopRoomDeleteLeaveTitle('Команда')), findsOneWidget);
    await t.tap(find.text(l10n.desktopRoomDeleteLeaveAction));
    await t.pumpAndSettle();
    expect(ctrl.calls, [
      'leave:group:team',
      'clear:group:team',
      'delete:group:team',
    ]);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('передумал — ничего не трогаем', (t) async {
    final ctrl = _FakeRooms(member: true);
    await pumpRooms(t, ctrl);
    await openRowMenu(t);
    await t.tap(find.text(l10n.desktopRoomDeleteLeaveMenu));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.cancel));
    await t.pumpAndSettle();
    expect(ctrl.calls, isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('уже не участник — только снос, без выхода', (t) async {
    final ctrl = _FakeRooms(member: false);
    await pumpRooms(t, ctrl);
    await openRowMenu(t);
    await t.tap(find.text(l10n.desktopRoomDeleteLeaveMenu));
    await t.pumpAndSettle();
    expect(ctrl.calls, ['clear:group:team', 'delete:group:team']);
    await t.pumpWidget(const SizedBox());
  });
}
