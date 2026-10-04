// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Без звука…» со сроком на ПК (30.09.2026, ТЗ «ПК как Telegram» §2): было
// только «вкл/выкл», у телефона — «1 час / 8 часов / навсегда / только
// упоминания».

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/app/desktop_chats_section.dart';
import 'package:secretly_app/ui/desktop/chat/mute_choice.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_deleted_chats.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/shell/desktop_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMute extends AppController {
  _FakeMute({this.muted = false, this.room = false});

  final bool muted;
  final bool room;
  final List<String> calls = <String>[];
  int? lastUntilMs;

  String get _id => room ? 'group:team' : 'dm:anna';

  @override
  Future<List<Conversation>> listConversations() async => [
    Conversation(
      convoId: _id,
      peerProfileId: room ? null : 'anna',
      title: room ? 'Команда' : 'Анна',
      avatarPath: null,
      lastEventAtMs: 1757700000000,
      pinnedAtMs: null,
      muted: muted,
      archivedAtMs: null,
      autoDeleteSeconds: null,
      emoji: null,
    ),
  ];

  @override
  Future<void> setChatMuted({
    required String convoId,
    required bool muted,
  }) async => calls.add('muted:$convoId:$muted');

  @override
  Future<void> setChatMute({
    required String convoId,
    required int untilMs,
    bool mentionsOnly = false,
  }) async {
    lastUntilMs = untilMs;
    calls.add('mute:$convoId:${untilMs < 0 ? 'forever' : 'timed'}:$mentionsOnly');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
    DesktopDeletedChats.resetForTest();
  });

  final l10n = lookupAppLocalizations(const Locale('ru'));

  test('сроки: час, 8 часов, 2 дня; навсегда и упоминания — -1', () {
    const now = 1000000;
    expect(desktopMuteUntilMs(DesktopMuteChoice.hour, nowMs: now), now + 3600000);
    expect(
      desktopMuteUntilMs(DesktopMuteChoice.eightHours, nowMs: now),
      now + 8 * 3600000,
    );
    expect(
      desktopMuteUntilMs(DesktopMuteChoice.twoDays, nowMs: now),
      now + 2 * 86400000,
    );
    expect(desktopMuteUntilMs(DesktopMuteChoice.forever, nowMs: now), -1);
    expect(desktopMuteUntilMs(DesktopMuteChoice.mentionsOnly, nowMs: now), -1);
  });

  Future<void> pump(WidgetTester t, _FakeMute ctrl) async {
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
              filter: ctrl.room
                  ? ConversationFilter.groups
                  : ConversationFilter.directs,
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

  Future<void> rowMenu(WidgetTester t, String title) async {
    await t.tapAt(
      t.getCenter(find.text(title).first),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await t.pumpAndSettle();
  }

  testWidgets('«Без звука…» → «На 8 часов» — срок, а не навсегда', (t) async {
    final ctrl = _FakeMute();
    await pump(t, ctrl);
    await rowMenu(t, 'Анна');
    await t.tap(find.text(l10n.desktopMuteMenu));
    await t.pumpAndSettle();
    // Подменю открылось; в личной переписке «только упоминания» нет.
    expect(find.text(l10n.desktopMuteFor8h), findsOneWidget);
    expect(find.text(l10n.desktopMuteMentionsOnly), findsNothing);
    final before = DateTime.now().millisecondsSinceEpoch;
    await t.tap(find.text(l10n.desktopMuteFor8h));
    await t.pumpAndSettle();
    expect(ctrl.calls, ['mute:dm:anna:timed:false']);
    final hours = (ctrl.lastUntilMs! - before) / 3600000;
    expect(hours, closeTo(8, 0.01));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('«Пока не включу» — прежним путём, он доходит до других устройств', (
    t,
  ) async {
    final ctrl = _FakeMute();
    await pump(t, ctrl);
    await rowMenu(t, 'Анна');
    await t.tap(find.text(l10n.desktopMuteMenu));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.desktopMuteForever));
    await t.pumpAndSettle();
    expect(ctrl.calls, ['muted:dm:anna:true']);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('комната: «Только упоминания»', (t) async {
    final ctrl = _FakeMute(room: true);
    await pump(t, ctrl);
    await rowMenu(t, 'Команда');
    await t.tap(find.text(l10n.desktopMuteMenu));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.desktopMuteMentionsOnly));
    await t.pumpAndSettle();
    expect(ctrl.calls, ['mute:group:team:forever:true']);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('заглушённый — одним пунктом «Включить звук»', (t) async {
    final ctrl = _FakeMute(muted: true);
    await pump(t, ctrl);
    await rowMenu(t, 'Анна');
    expect(find.text(l10n.desktopMuteMenu), findsNothing);
    await t.tap(find.text(l10n.desktopChatsSoundOn));
    await t.pumpAndSettle();
    expect(ctrl.calls, ['muted:dm:anna:false']);
    await t.pumpWidget(const SizedBox());
  });
}
