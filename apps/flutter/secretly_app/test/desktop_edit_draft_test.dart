// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПРАВКА НЕ ЧЕРНОВИК (30.09.2026).
//
// «Изменить» писало текст правимого сообщения в черновик переписки. Ушёл в
// другой чат посреди правки — вернулся к «черновику» без карточки правки, и
// Enter отправлял старый текст ВТОРЫМ сообщением. Escape стирал поле — вместе
// с тем, что человек набрал до правки. А крестик у карточки ОТВЕТА стирал
// набранный ответ, хотя Escape его бережёт.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

const _mine = MessageData(
  id: 'm1',
  payloadId: 'm1',
  authorName: 'Вы',
  text: 'Старый текст',
  time: '12:00',
  timestampMs: 1757700000000,
  isSelf: true,
  isTextMessage: true,
);

class _Harness {
  final drafts = <String>[];
  final sent = <DesktopComposerSubmission>[];
}

Future<_Harness> _pump(WidgetTester t, {String? draft}) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  final h = _Harness();
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
            messages: const [_mine],
            initialDraft: draft,
            onDraftChanged: h.drafts.add,
            onSend: h.sent.add,
          ),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 400));
  return h;
}

String _field(WidgetTester t) =>
    t.widget<TextField>(find.byType(TextField).last).controller!.text;

Future<void> _menu(WidgetTester t, String item) async {
  // Лента стоит выше поля ввода: первым найдётся пузырь, а не поле и не
  // карточка правки с тем же текстом.
  await t.tap(
    find.textContaining('Старый текст').first,
    buttons: kSecondaryButton,
  );
  await t.pumpAndSettle();
  await t.tap(find.text(item));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('🔴 правка не попадает в черновик; Escape возвращает набранное', (
    t,
  ) async {
    final h = await _pump(t, draft: 'Черновик');
    expect(_field(t), 'Черновик');
    await _menu(t, 'Редактировать');
    expect(_field(t), 'Старый текст');
    expect(
      h.drafts.contains('Старый текст'),
      isFalse,
      reason: 'иначе после смены чата он уйдёт вторым сообщением',
    );

    await t.tap(find.byType(TextField).last);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(_field(t), 'Черновик');
    expect(h.drafts.contains('Старый текст'), isFalse);
  });

  testWidgets('🔴 правка ушла — одно сообщение-правка, черновик на месте', (
    t,
  ) async {
    final h = await _pump(t, draft: 'Черновик');
    await _menu(t, 'Редактировать');
    await t.enterText(find.byType(TextField).last, 'Новый текст');
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(h.sent, hasLength(1));
    expect(h.sent.single.editPayloadEventId, 'm1');
    expect(h.sent.single.text, 'Новый текст');
    expect(_field(t), 'Черновик');
    expect(h.drafts.contains('Новый текст'), isFalse);
  });

  testWidgets('крестик у правки — как Escape', (t) async {
    await _pump(t, draft: 'Черновик');
    await _menu(t, 'Редактировать');
    await t.tap(find.byTooltip('Отменить'));
    await t.pumpAndSettle();
    expect(_field(t), 'Черновик');
  });

  testWidgets('🔴 крестик у ОТВЕТА не стирает набранный ответ', (t) async {
    final h = await _pump(t);
    await _menu(t, 'Ответить');
    await t.enterText(find.byType(TextField).last, 'Мой ответ');
    await t.tap(find.byTooltip('Отменить'));
    await t.pumpAndSettle();
    expect(_field(t), 'Мой ответ');
    await t.tap(find.byType(TextField).last);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(
      h.sent.single.replyToPayloadEventId,
      isNull,
      reason: 'карточка ответа снята — уходит обычным сообщением',
    );
  });

  testWidgets('ответ посреди правки — текст правимого ответом не уходит', (
    t,
  ) async {
    await _pump(t, draft: 'Черновик');
    await _menu(t, 'Редактировать');
    await _menu(t, 'Ответить');
    expect(_field(t), 'Черновик');
  });
}
