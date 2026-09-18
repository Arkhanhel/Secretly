// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 РАЗДЕЛ ЧАТОВ НЕ ТРОГАЕТ ХРАНИЛИЩЕ ВЫБОРА, ПОКА ДЕРЕВО ЗАПЕРТО.
//
// Найдено 16.09.2026 ловушкой ошибок в журнале окна — шесть одинаковых
// записей подряд при переходе из «Чатов» с открытой перепиской:
//
//     while dispatching notifications for DesktopChatSelectionStore:
//     setState() or markNeedsBuild() called when widget tree was locked.
//
// Раздел в `dispose` очищал хранилище выбора, а `dispose` идёт, пока дерево
// снимается и заперто. Очистка будила слушателей хранилища (панель
// подробностей, хлебные крошки), и те просили перестройку посреди разборки.
// Ошибка была с мая и не проявлялась, пока перед сменой раздела не был открыт
// чат: пустое хранилище очистка не трогает вовсе.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart' show Conversation;
import 'package:secretly_app/ui/desktop/chat/details/desktop_selection_store.dart';

const _convo = Conversation(
  convoId: 'c1',
  peerProfileId: 'p1',
  title: 'Игорь',
  avatarPath: null,
  lastEventAtMs: 0,
  pinnedAtMs: null,
  muted: false,
  archivedAtMs: null,
  autoDeleteSeconds: null,
  emoji: null,
);

/// Раздел в миниатюре: очищает хранилище, когда его снимают.
class _Section extends StatefulWidget {
  const _Section({required this.store, required this.deferred});
  final DesktopChatSelectionStore store;
  final bool deferred;
  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  @override
  void dispose() {
    final store = widget.store;
    if (widget.deferred) {
      WidgetsBinding.instance.addPostFrameCallback((_) => store.clear());
    } else {
      store.clear();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget _host(DesktopChatSelectionStore store, {required Widget? section}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          // Слушатель хранилища, который переживает смену раздела, — как
          // панель подробностей.
          ListenableBuilder(
            listenable: store,
            builder: (ctx, _) => Text(store.selected?.title ?? '—'),
          ),
          ?section,
        ],
      ),
    );

void main() {
  testWidgets('очистка ПРЯМО в dispose роняет проверку запертого дерева', (
    t,
  ) async {
    final store = DesktopChatSelectionStore()..select(_convo);
    await t.pumpWidget(
      _host(store, section: _Section(store: store, deferred: false)),
    );
    await t.pumpWidget(_host(store, section: null));
    expect(
      t.takeException().toString(),
      contains('widget tree was locked'),
      reason: 'иначе этот тест не воспроизводит ошибку из журнала',
    );
  });

  testWidgets('🔴 очистка после кадра — без ошибки, и хранилище пусто', (
    t,
  ) async {
    final store = DesktopChatSelectionStore()..select(_convo);
    await t.pumpWidget(
      _host(store, section: _Section(store: store, deferred: true)),
    );
    await t.pumpWidget(_host(store, section: null));
    expect(t.takeException(), isNull);
    expect(store.selected, isNull);
    await t.pump();
    expect(find.text('—'), findsOneWidget);
  });

  test('раздел чатов очищает хранилище после кадра', () {
    final src = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    final i = src.indexOf('  void dispose() {');
    final body = src.substring(i, src.indexOf('\n  }\n', i));
    expect(
      body.contains(
        'WidgetsBinding.instance.addPostFrameCallback((_) => selection.clear());',
      ),
      isTrue,
    );
    expect(body.contains('widget.selection?.clear();'), isFalse);
  });
}
