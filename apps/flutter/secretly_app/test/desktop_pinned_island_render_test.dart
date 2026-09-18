// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Островок закреплённого рисуется живьём и имеет форму островка.
//
// Проверка по ДЕРЕВУ, а не по исходнику: у `BoxDecoration` со скруглением
// рамка обязана быть однородной, иначе Flutter валится в отладочной сборке.
// Полоса раньше была без скругления и с рамкой только снизу — при переезде в
// островок это как раз то место, где легко получить исключение вместо плашки.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/radii.dart';

const _pinned = MessageData(
  id: 'm1',
  payloadId: 'p1',
  authorName: 'Игорь',
  text: 'Дедлайн по 1.4 — 30 сентября',
  time: '14:19',
);

void main() {
  testWidgets('· закреплённое рисуется островком и не падает', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: SizedBox(
              width: 900,
              height: 700,
              child: ChatThreadPanel(
                header: const ChatHeader(name: 'тест 2'),
                messages: const [_pinned],
                pinnedPayloadEventId: 'p1',
                onTogglePinMessage: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();

    expect(testerException, isNull);
    expect(find.text('Закреплённое сообщение'), findsOneWidget);
    expect(find.text('Дедлайн по 1.4 — 30 сентября'), findsWidgets);

    // Форма островка: скругление есть, рамка однородная.
    final box = t.widget<Container>(
      find
          .ancestor(
            of: find.text('Закреплённое сообщение'),
            matching: find.byType(Container),
          )
          .last,
    );
    final d = box.decoration! as BoxDecoration;
    expect(d.borderRadius, BorderRadius.circular(DRadii.lg));
    expect((d.border! as Border).isUniform, isTrue);
    expect(d.color, kDColorsDark.accentPrimary.withValues(alpha: 0.08));

    // И «Открепить» на месте, а стрелки «следующее» нет.
    expect(find.byIcon(FluentIcons.dismiss_24_regular), findsWidgets);
    expect(find.byIcon(FluentIcons.chevron_down_24_regular), findsNothing);
  });
}

Object? get testerException =>
    (TestWidgetsFlutterBinding.instance).takeException();
