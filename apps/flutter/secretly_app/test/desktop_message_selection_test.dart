// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ВЫДЕЛЕНИЕ НЕСКОЛЬКИХ СООБЩЕНИЙ — КАК НА ТЕЛЕФОНЕ.
//
// На телефоне сообщения выделяются долгим нажатием и копируются, пересылаются,
// сохраняются и удаляются пачкой. На компьютере пункт «Выделить» в меню был
// написан, но не подключён — и потому не показывался вовсе. Десять сообщений
// пересылались десятью заходами в меню.
//
// Указание владельца 16.09.2026: «при зажатии левой кнопкой мыши на пустое
// место от пузыря оно должно выделяться».

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

MessageData _msg(String id, String text, {bool self = false, int at = 0}) =>
    MessageData(
      id: id,
      payloadId: id,
      authorName: self ? 'Вы' : 'Пётр',
      text: text,
      time: '12:00',
      timestampMs: 1757700000000 + at,
      isSelf: self,
    );

final _messages = <MessageData>[
  _msg('m1', 'Первое', at: 1),
  _msg('m2', 'Второе', self: true, at: 2),
  _msg('m3', 'Третье', at: 3),
];

class _Calls {
  List<MessageData>? forwarded;
  List<MessageData>? saved;
  List<MessageData>? deleted;
}

Future<_Calls> _pump(
  WidgetTester t, {
  List<MessageData>? messages,
}) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  final calls = _Calls();
  await t.pumpWidget(
    MaterialApp(
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: ChatThreadPanel(
            header: const ChatHeader(name: 'Пётр'),
            isDirect: true,
            messages: messages ?? _messages,
            onDeleteMessage: (_) {},
            onForwardMessage: (_) {},
            onSaveMessage: (_) {},
            onForwardMessages: (l) => calls.forwarded = l,
            onSaveMessages: (l) => calls.saved = l,
            onDeleteMessages: (l) => calls.deleted = l,
          ),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 400));
  return calls;
}

Future<void> _selectViaMenu(WidgetTester t, String text) async {
  await t.tap(find.textContaining(text), buttons: kSecondaryButton);
  await t.pumpAndSettle();
  expect(find.text('Выделить'), findsOneWidget, reason: 'пункт не подключён');
  await t.tap(find.text('Выделить'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('🔴 «Выделить» в меню начинает выделение с этого сообщения', (
    t,
  ) async {
    await _pump(t);
    await _selectViaMenu(t, 'Второе');
    expect(find.text('Выбрано: 1'), findsOneWidget);
    // Шапка переписки уступила место панели действий.
    expect(find.byTooltip('Переслать'), findsOneWidget);
    expect(find.byTooltip('Удалить'), findsOneWidget);
  });

  testWidgets('🔴 зажатие на ПУСТОМ месте строки начинает выделение', (
    t,
  ) async {
    await _pump(t);
    // Чужой пузырь прижат влево — справа от него в строке пусто.
    final bubble = t.getRect(find.textContaining('Первое'));
    final empty = Offset(bubble.right + 300, bubble.center.dy);
    final gesture = await t.startGesture(empty);
    await t.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await t.pumpAndSettle();
    expect(find.text('Выбрано: 1'), findsOneWidget);
  });

  testWidgets('короткий щелчок по пустому месту выделения не начинает', (
    t,
  ) async {
    await _pump(t);
    final bubble = t.getRect(find.textContaining('Первое'));
    await t.tapAt(Offset(bubble.right + 300, bubble.center.dy));
    await t.pumpAndSettle();
    expect(find.textContaining('Выбрано'), findsNothing);
  });

  testWidgets('в режиме щелчок по строке отмечает и снимает отметку', (
    t,
  ) async {
    await _pump(t);
    await _selectViaMenu(t, 'Первое');
    await t.tap(find.textContaining('Третье'));
    await t.pumpAndSettle();
    expect(find.text('Выбрано: 2'), findsOneWidget);
    await t.tap(find.textContaining('Первое'));
    await t.pumpAndSettle();
    expect(find.text('Выбрано: 1'), findsOneWidget);
    // Сняли последнюю — режим закончился сам.
    await t.tap(find.textContaining('Третье'));
    await t.pumpAndSettle();
    expect(find.textContaining('Выбрано'), findsNothing);
  });

  testWidgets('🔴 пачка уходит В ПОРЯДКЕ ПЕРЕПИСКИ, режим снимается', (
    t,
  ) async {
    final calls = await _pump(t);
    // Отмечаем в обратном порядке — отдать обязаны от старых к новым.
    await _selectViaMenu(t, 'Третье');
    await t.tap(find.textContaining('Первое'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Переслать'));
    await t.pumpAndSettle();
    expect(calls.forwarded?.map((m) => m.id), ['m1', 'm3']);
    expect(find.textContaining('Выбрано'), findsNothing);
  });

  testWidgets('«Сохранить» и «Удалить» получают то же выделенное', (t) async {
    final calls = await _pump(t);
    await _selectViaMenu(t, 'Второе');
    await t.tap(find.byTooltip('Сохранить'));
    await t.pumpAndSettle();
    expect(calls.saved?.map((m) => m.id), ['m2']);

    await _selectViaMenu(t, 'Первое');
    await t.tap(find.byTooltip('Удалить'));
    await t.pumpAndSettle();
    expect(calls.deleted?.map((m) => m.id), ['m1']);
  });

  testWidgets('🔴 «Копировать» кладёт «Автор: текст» построчно', (t) async {
    final copied = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(t);
    await _selectViaMenu(t, 'Первое');
    await t.tap(find.textContaining('Второе'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Копировать'));
    await t.pumpAndSettle();
    expect(copied.last, 'Пётр: Первое\nВы: Второе');
    expect(find.textContaining('Выбрано'), findsNothing);
    // Всплывашка «Скопировано» гаснет по таймеру — даём ему истечь.
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('Escape снимает выделение', (t) async {
    await _pump(t);
    await _selectViaMenu(t, 'Первое');
    expect(find.text('Выбрано: 1'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.textContaining('Выбрано'), findsNothing);
  });

  testWidgets('в режиме щелчок по пузырю не открывает его меню', (t) async {
    await _pump(t);
    await _selectViaMenu(t, 'Первое');
    await t.tap(find.textContaining('Третье'), buttons: kSecondaryButton);
    await t.pumpAndSettle();
    expect(find.text('Выделить'), findsNothing);
  });

  testWidgets('🔴 удалённое сообщение само уходит из выделения', (t) async {
    await _pump(t);
    await _selectViaMenu(t, 'Первое');
    await t.tap(find.textContaining('Третье'));
    await t.pumpAndSettle();
    expect(find.text('Выбрано: 2'), findsOneWidget);
    // Третье удалили — на этом устройстве или на другом.
    await _pump(t, messages: _messages.take(2).toList());
    expect(find.text('Выбрано: 1'), findsOneWidget);
  });
}
