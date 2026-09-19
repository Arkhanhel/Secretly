// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Закреплённое сообщение на компьютере ПОКАЗЫВАЕТСЯ и ЗАКРЕПЛЯЕТСЯ.
//
// 🔴 Дефект, который сторожит этот тест (13.09.2026). Закрепление в комнатах
// работало ровно наполовину: состояние комнаты несёт `pinnedMessageEventId`,
// телефон его ставит и показывает — а на компьютере не было ни плашки, ни
// пункта меню. Пункт при этом выглядел написанным: `MessageContextMenu` знает
// «Закрепить»/«Открепить», и панель даже передавала `canPin: true`. Но
// обработчик `onPin` не передавал никто, а меню молча выбрасывает пункты без
// обработчика — то есть код читался как рабочий, а закрепить было нельзя.
//
// Проверяем ровно две вещи, без которых всё остальное бессмысленно: плашка
// рисуется по идентификатору закреплённого и нажатие ведёт к самому сообщению,
// а пункт меню появляется только когда действие вправду доступно.

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

MessageData _msg(String id, String text) => MessageData(
  id: id,
  payloadId: id,
  authorName: 'Пётр',
  text: text,
  time: '12:00',
  timestampMs: 1757700000000,
  isSelf: false,
);

Future<void> _pump(
  WidgetTester tester, {
  String? pinnedPayloadEventId,
  void Function(MessageData, bool)? onTogglePin,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: ChatThreadPanel(
            header: const ChatHeader(name: 'Комната'),
            isDirect: false,
            messages: <MessageData>[
              _msg('m1', 'Первое'),
              _msg('m2', 'Читайте правила комнаты'),
            ],
            pinnedPayloadEventId: pinnedPayloadEventId,
            onTogglePinMessage: onTogglePin,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('🔴 закреплённое сообщение видно плашкой', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _pump(tester, pinnedPayloadEventId: 'm2');

    expect(find.text('Закреплённое сообщение'), findsOneWidget);
    // По вхождению: в самой ленте у абзаца в конце стоит невидимый пролёт под
    // подпись времени, и точное равенство с ним не совпадает.
    expect(
      find.textContaining('Читайте правила комнаты'),
      findsNWidgets(2),
      reason: 'и в плашке, и в самой ленте',
    );
  });

  testWidgets('ничего не закреплено — плашки нет', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _pump(tester);

    expect(find.text('Закреплённое сообщение'), findsNothing);
  });

  testWidgets('🔴 закреплённое, выпавшее из ленты, не обещает перехода', (
    tester,
  ) async {
    // Плашка — это кнопка «перейти». Если сообщения в загруженном окне нет,
    // переходить некуда, и честнее промолчать, чем показать мёртвую кнопку.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _pump(tester, pinnedPayloadEventId: 'ушло-за-горизонт');

    expect(find.text('Закреплённое сообщение'), findsNothing);
  });

  testWidgets('🔴 открепить может тот, кому это разрешено', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    MessageData? target;
    bool? pinRequested;
    await _pump(
      tester,
      pinnedPayloadEventId: 'm2',
      onTogglePin: (m, pin) {
        target = m;
        pinRequested = pin;
      },
    );

    await tester.tap(find.byTooltip('Открепить'));
    await tester.pump();

    expect(target?.payloadId, 'm2');
    expect(pinRequested, isFalse);
  });

  testWidgets('без права закреплять крестика нет', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _pump(tester, pinnedPayloadEventId: 'm2');

    expect(find.byTooltip('Открепить'), findsNothing);
  });
}
