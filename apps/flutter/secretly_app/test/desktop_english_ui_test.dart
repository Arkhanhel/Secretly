// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Проверка того самого обещания, ради которого включён
// `kDesktopUiLocalized`: выбрал английский — получил английское окно.
//
// Ратчет считает литералы в ИСХОДНИКЕ, и этого мало: подпись могла уехать в
// ARB, но остаться русской во всех восьми файлах. Здесь окно поднимается
// по-настоящему, и тест читает то, что нарисовано.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/rooms/room_call_state.dart';
import 'package:secretly_app/ui/desktop/calls/incoming_call_toast.dart';
import 'package:secretly_app/ui/desktop/chat/attachments_drop_zone.dart';
import 'package:secretly_app/ui/desktop/chat/room_call_banner.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';

final _cyrillic = RegExp(r'[а-яА-ЯёЁ]');

CachedRoomCall _call() => const CachedRoomCall(
  roomId: 'group:core',
  callId: 'c1',
  state: 'active',
  mediaType: 'audio',
  createdByProfileId: 'igor',
  createdByDeviceId: 'igor-1',
  stateVersion: 7,
  startedAtMs: 0,
  updatedAtMs: 0,
  endedAtMs: null,
  expiresAtMs: 3600000,
  participants: <CachedRoomCallParticipant>[],
  selfParticipant: null,
);

Widget _host(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 900, height: 900, child: child)),
  ),
);

/// Весь текст, который окно нарисовало, — как его видит человек.
List<String> _texts(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
    .where((s) => s.trim().isNotEmpty)
    .toList(growable: false);

/// Подсказки на английском тоже обязаны быть английскими: половина подписей
/// десктопа живёт именно в них.
List<String> _tooltips(WidgetTester t) => t
    .widgetList<Tooltip>(find.byType(Tooltip))
    .map((w) => w.message ?? '')
    .where((s) => s.trim().isNotEmpty)
    .toList(growable: false);

void main() {
  final cases = <String, Widget Function()>{
    'рейка': () => DesktopSidebar(
      active: DesktopSection.chats,
      onSelect: (_) {},
      connectionStatus: ConnectionStatus.connected,
      selfName: 'Yurii',
      unreadByTab: const {},
    ),
    'перетаскивание файлов': () =>
        const AttachmentsDropZone(visible: true),
    'плашка созвона в комнате': () =>
        DesktopRoomCallBanner(call: _call(), onJoin: () {}),
    'всплывашка входящего': () => IncomingCallToast(
      callerName: 'Yurii',
      onAccept: () {},
      onDecline: () {},
      onReplyWithText: () {},
    ),
  };

  for (final entry in cases.entries) {
    testWidgets('по-английски ${entry.key} — без русских слов', (t) async {
      await t.pumpWidget(_host(entry.value(), const Locale('en')));
      await t.pump();
      final russian = [
        ..._texts(t),
        ..._tooltips(t),
      ].where(_cyrillic.hasMatch).toList();
      expect(
        russian,
        isEmpty,
        reason:
            'переключатель языка обещает английское окно, а здесь осталось '
            'русское: $russian',
      );
    });

    testWidgets('по-русски ${entry.key} всё ещё по-русски', (t) async {
      // Обратная половина правила: английский не должен победить везде.
      await t.pumpWidget(_host(entry.value(), const Locale('ru')));
      await t.pump();
      expect(
        [..._texts(t), ..._tooltips(t)].any(_cyrillic.hasMatch),
        isTrue,
      );
    });
  }
}
