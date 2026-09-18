// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПОСЛЕ «ЧЕРНОВИК:» СТОИТ САМ ЧЕРНОВИК.
//
// Найдено 16.09.2026 при живой проверке превью ссылок: в демо-чате был
// черновик «Посмотри https://github.com», а строка списка показывала
// «Черновик: I see it, all there. Thanks!» — последнее сообщение собеседника.
// Строка знала только, ЧТО черновик есть, и подставляла обычное превью.
// Чужая фраза после «Черновик:» читается как недописанное своё.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_list_panel.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(List<ChatListItem> items) => MaterialApp(
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: SizedBox(
        width: 320,
        height: 600,
        child: ChatListPanel(items: items, selectedId: null, onSelect: (_) {}),
      ),
    ),
  ),
);

String _rowText(WidgetTester t) => t
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .firstWhere((s) => s.startsWith('Черновик: '), orElse: () => '');

void main() {
  testWidgets('🔴 строка показывает текст черновика, а не чужое сообщение', (
    t,
  ) async {
    await t.pumpWidget(
      _host(const [
        ChatListItem(
          id: 'c1',
          name: 'Nathan Ford',
          preview: 'I see it, all there. Thanks!',
          time: 'вс',
          draft: true,
          draftText: 'Посмотри\nhttps://github.com  ',
        ),
      ]),
    );
    await t.pump();
    expect(_rowText(t), 'Черновик: Посмотри https://github.com');
    expect(find.textContaining('I see it'), findsNothing);
  });

  testWidgets('без текста (старые данные) — прежнее поведение', (t) async {
    await t.pumpWidget(
      _host(const [
        ChatListItem(
          id: 'c1',
          name: 'Пётр',
          preview: 'привет',
          time: '12:00',
          draft: true,
        ),
      ]),
    );
    await t.pump();
    expect(_rowText(t), 'Черновик: привет');
  });

  group('хранилище черновиков будит список', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('🔴 правка текста — одним сигналом после паузы, не на '
        'каждую букву', (t) async {
      DesktopDraftStore.clear('c-draft');
      await t.pump(const Duration(seconds: 1));
      final start = DesktopDraftStore.revision.value;

      DesktopDraftStore.set('c-draft', 'П');
      // Черновик появился — это видно сразу.
      expect(DesktopDraftStore.revision.value, start + 1);
      DesktopDraftStore.set('c-draft', 'По');
      DesktopDraftStore.set('c-draft', 'Пос');
      expect(
        DesktopDraftStore.revision.value,
        start + 1,
        reason: 'список перерисовывается на каждую букву',
      );
      await t.pump(const Duration(milliseconds: 700));
      expect(DesktopDraftStore.revision.value, start + 2);
      expect(DesktopDraftStore.get('c-draft'), 'Пос');

      // Без правок пауза ничего не будит.
      await t.pump(const Duration(seconds: 1));
      expect(DesktopDraftStore.revision.value, start + 2);

      DesktopDraftStore.clear('c-draft');
      expect(DesktopDraftStore.revision.value, start + 3);
      await t.pump(const Duration(seconds: 1));
    });
  });
}
