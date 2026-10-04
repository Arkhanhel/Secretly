// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 КЛАВИШИ И ЩЕЛЧКИ КАК В TELEGRAM DESKTOP (30.09.2026, ТЗ «ПК как
// Telegram» §8).
//
//   · ⌃Tab / ⌃⇧Tab — следующий и предыдущий чат;
//   · ⌥⇧↓ / ⌥⇧↑ — следующий и предыдущий непрочитанный;
//   · Ctrl⇧↓ / Ctrl⇧↑ — соседняя папка;
//   · ⌘⇧M / Ctrl⇧M — звук открытого чата;
//   · Escape — сначала правая панель, потом сам чат;
//   · двойной щелчок по сообщению (мимо текста) — ответ; выключается.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/app/desktop_chats_section.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/details/desktop_selection_store.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/shell/desktop_shell.dart';
import 'package:secretly_app/ui/desktop/shell/shortcuts_help.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _press(
  WidgetTester t,
  LogicalKeyboardKey key, {
  bool control = false,
  bool shift = false,
  bool alt = false,
  bool meta = false,
}) async {
  final mods = <LogicalKeyboardKey>[
    if (control) LogicalKeyboardKey.controlLeft,
    if (shift) LogicalKeyboardKey.shiftLeft,
    if (alt) LogicalKeyboardKey.altLeft,
    if (meta) LogicalKeyboardKey.metaLeft,
  ];
  for (final m in mods) {
    await t.sendKeyDownEvent(m);
  }
  await t.sendKeyEvent(key);
  for (final m in mods.reversed) {
    await t.sendKeyUpEvent(m);
  }
  await t.pump();
}

MessageData _msg(String id, String text, {bool self = false, int at = 0}) =>
    MessageData(
      id: id,
      payloadId: id,
      authorName: self ? 'Вы' : 'Пётр',
      text: text,
      time: '12:0$at',
      timestampMs: 1757700000000 + at,
      isSelf: self,
      isTextMessage: true,
    );

Conversation _convo(String id, {int unread = 0, int at = 0}) => Conversation(
  convoId: id,
  peerProfileId: 'peer-$id',
  title: 'Чат $id',
  avatarPath: null,
  lastEventAtMs: 1757700000000 - at,
  pinnedAtMs: null,
  muted: false,
  archivedAtMs: null,
  autoDeleteSeconds: null,
  emoji: null,
  unreadCount: unread,
);

/// Контроллер без базы: список переписок и запись звука — в памяти.
class _FakeChats extends AppController {
  _FakeChats(this.convos);

  final List<Conversation> convos;
  final List<({String convoId, bool muted})> muteCalls =
      <({String convoId, bool muted})>[];

  @override
  Future<List<Conversation>> listConversations() async => convos;

  @override
  Future<void> setChatMuted({
    required String convoId,
    required bool muted,
  }) async {
    muteCalls.add((convoId: convoId, muted: muted));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
  });

  group('оболочка: сочетания доходят до разделов', () {
    late DesktopShellApi api;

    Future<void> pumpShell(WidgetTester t) async {
      t.view.physicalSize = const Size(1600, 1000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(
            colors: kDColorsDark,
            child: DesktopShell(
              sidebarBuilder: (ctx, active, onSelect) =>
                  const SizedBox(width: kRailWidth),
              contentBuilder: (ctx, section, a) {
                api = a;
                return const SizedBox.expand();
              },
              detailsBuilder: (ctx, section, a) => const ColoredBox(
                key: ValueKey('details'),
                color: Colors.blueGrey,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('⌃Tab и ⌃⇧Tab — следующий и предыдущий чат', (t) async {
      await pumpShell(t);
      final start = api.chatCycle.value;
      await _press(t, LogicalKeyboardKey.tab, control: true);
      expect(api.chatCycle.value, start + 1);
      await _press(t, LogicalKeyboardKey.tab, control: true, shift: true);
      expect(api.chatCycle.value, start);
    });

    testWidgets('⌥⇧↓ / ⌥⇧↑ — непрочитанные, не обычный перебор', (t) async {
      await pumpShell(t);
      final chats = api.chatCycle.value;
      await _press(t, LogicalKeyboardKey.arrowDown, alt: true, shift: true);
      expect(api.unreadCycle!.value, 1);
      await _press(t, LogicalKeyboardKey.arrowUp, alt: true, shift: true);
      expect(api.unreadCycle!.value, 0);
      expect(api.chatCycle.value, chats);
    });

    testWidgets('Ctrl⇧↓ / Ctrl⇧↑ — папки', (t) async {
      await pumpShell(t);
      await _press(
        t,
        LogicalKeyboardKey.arrowDown,
        control: true,
        shift: true,
      );
      expect(api.folderCycle!.value, 1);
      await _press(t, LogicalKeyboardKey.arrowUp, control: true, shift: true);
      expect(api.folderCycle!.value, 0);
    });

    testWidgets('⌘⇧M и Ctrl⇧M — звук чата', (t) async {
      await pumpShell(t);
      await _press(t, LogicalKeyboardKey.keyM, control: true, shift: true);
      expect(api.muteRequests!.value, 1);
      await _press(t, LogicalKeyboardKey.keyM, meta: true, shift: true);
      expect(api.muteRequests!.value, 2);
    });

    testWidgets('Escape: сначала правая панель, потом чат', (t) async {
      await pumpShell(t);
      api.openDetails();
      await t.pumpAndSettle();
      expect(api.detailsOpen, isTrue);

      await _press(t, LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(api.detailsOpen, isFalse);
      expect(api.closeChatRequests!.value, 0);

      await _press(t, LogicalKeyboardKey.escape);
      expect(api.closeChatRequests!.value, 1);
    });
  });

  testWidgets('справка называет новые сочетания', (t) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: const Scaffold(
            body: SingleChildScrollView(child: ShortcutsList()),
          ),
        ),
      ),
    );
    final l10n = lookupAppLocalizations(const Locale('ru'));
    for (final label in [
      l10n.desktopShortcutsUnread,
      l10n.desktopShortcutsFolders,
      l10n.desktopShortcutsMute,
      l10n.desktopShortcutsCloseChat,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // ⌃Tab стоит второй строкой рядом с ⌥↑/↓ — то же действие.
    expect(find.text(l10n.desktopShortcutsPrevNext), findsNWidgets(2));
  });

  group('двойной щелчок по сообщению', () {
    Future<void> pumpThread(WidgetTester t) async {
      t.view.physicalSize = const Size(1200, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(
            colors: kDColorsDark,
            child: Scaffold(
              body: ChatThreadPanel(
                header: const ChatHeader(name: 'Пётр'),
                isDirect: true,
                onSend: (_) {},
                messages: [
                  _msg('m1', 'Первое сообщение', at: 1),
                  _msg('m2', 'Второе сообщение', at: 2),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
    }

    /// Пузырь без текста: место в самом пузыре справа от строки текста,
    /// под временем нет — берём поле пузыря над текстом.
    Offset onBubbleBesideText(WidgetTester t, String text) {
      final r = t.getRect(find.textContaining(text));
      return Offset(r.left + 4, r.top - 5);
    }

    Future<void> doubleClick(WidgetTester t, Offset at) async {
      for (var i = 0; i < 2; i++) {
        await t.tapAt(at, kind: PointerDeviceKind.mouse);
        await t.pump(const Duration(milliseconds: 60));
      }
      await t.pump(const Duration(milliseconds: 100));
    }

    final replyCard = lookupAppLocalizations(
      const Locale('ru'),
    ).desktopComposerReplyTo('Пётр');

    testWidgets('по пузырю мимо текста — ответ', (t) async {
      await pumpThread(t);
      expect(find.text(replyCard), findsNothing);
      await doubleClick(t, onBubbleBesideText(t, 'Второе'));
      expect(find.text(replyCard), findsOneWidget);
    });

    testWidgets('одиночный щелчок ответа не начинает', (t) async {
      await pumpThread(t);
      await t.tapAt(
        onBubbleBesideText(t, 'Второе'),
        kind: PointerDeviceKind.mouse,
      );
      await t.pump(const Duration(milliseconds: 700));
      expect(find.text(replyCard), findsNothing);
    });

    testWidgets('по тексту — выделение слова, не ответ', (t) async {
      await pumpThread(t);
      await doubleClick(t, t.getCenter(find.textContaining('Второе')));
      expect(find.text(replyCard), findsNothing);
    });

    testWidgets('выключено в настройках — ничего', (t) async {
      DesktopUiPrefs.doubleClickReply.value = false;
      await pumpThread(t);
      await doubleClick(t, onBubbleBesideText(t, 'Второе'));
      expect(find.text(replyCard), findsNothing);
    });
  });

  group('раздел чатов отвечает на сочетания', () {
    final unread = ValueNotifier<int>(0);
    final folders = ValueNotifier<int>(0);
    final mute = ValueNotifier<int>(0);
    final close = ValueNotifier<int>(0);
    late _FakeChats fake;
    late DesktopAppViewModel vm;
    late DesktopChatSelectionStore store;

    setUp(() {
      unread.value = 0;
      folders.value = 0;
      mute.value = 0;
      close.value = 0;
      fake = _FakeChats([
        _convo('a', at: 1),
        _convo('b', unread: 2, at: 2),
        _convo('c', at: 3),
        _convo('d', unread: 1, at: 4),
      ]);
      vm = DesktopAppViewModel(controller: fake);
      store = DesktopChatSelectionStore();
    });
    tearDown(() {
      vm.dispose();
      store.dispose();
    });

    Future<void> pumpSection(WidgetTester t) async {
      t.view.physicalSize = const Size(1600, 1000);
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
              body: DesktopChatsSection(
                vm: vm,
                selection: store,
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
                  unreadCycle: unread,
                  folderCycle: folders,
                  muteRequests: mute,
                  closeChatRequests: close,
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

    testWidgets('⌥⇧↓ — по непрочитанным сверху вниз и по кругу', (t) async {
      await pumpSection(t);
      expect(store.selected, isNull);
      unread.value += 1;
      await t.pump();
      expect(store.selectedConvoId, 'b');
      unread.value += 1;
      await t.pump();
      expect(store.selectedConvoId, 'd');
      // После последнего — снова первый непрочитанный.
      unread.value += 1;
      await t.pump();
      expect(store.selectedConvoId, 'b');
      // ⌥⇧↑ — назад, тоже по кругу.
      unread.value -= 1;
      await t.pump();
      expect(store.selectedConvoId, 'd');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('⌘⇧M — звук открытого чата и подтверждение', (t) async {
      await pumpSection(t);
      mute.value += 1; // чат не открыт — ничего
      await t.pump();
      expect(fake.muteCalls, isEmpty);

      unread.value += 1;
      await t.pump();
      mute.value += 1;
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(fake.muteCalls.single, (convoId: 'b', muted: true));
      final l10n = lookupAppLocalizations(const Locale('ru'));
      expect(find.text(l10n.desktopChatMutedToast), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Escape без панели — чат закрывается', (t) async {
      await pumpSection(t);
      unread.value += 1;
      await t.pump();
      expect(store.selectedConvoId, 'b');
      close.value += 1;
      await t.pump();
      await t.pump();
      expect(store.selected, isNull);
      await t.pumpWidget(const SizedBox());
    });
  });

  // Во время записи голосового поле ввода убрано; без своей клавиши Escape
  // доставался окну и закрывал переписку, обрывая запись молча. Запись в
  // тесте не поднять (плагин записи), поэтому сторож — по исходнику.
  test('Escape во время записи — отмена записи, Enter — отправка', () {
    final src = File('lib/ui/desktop/chat/composer.dart').readAsStringSync();
    final i = src.indexOf('Widget _recordingBar(DColorSet c) {');
    expect(i, greaterThan(0));
    final body = src.substring(i, i + 1400);
    expect(
      body.contains(
        'SingleActivator(LogicalKeyboardKey.escape): () =>\n'
        '            unawaited(_stopRecording(send: false))',
      ),
      isTrue,
    );
    expect(body.contains('autofocus: true'), isTrue);
  });
}
