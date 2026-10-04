// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ШАПКА ПЕРЕПИСКИ НЕ ВЫЛЕЗАЕТ ЗА КРАЙ (30.09.2026).
//
// Нашлось, когда предпросмотр «Внешнего вида» стал настоящей лентой: блок
// «портрет + имя + статус» стоял в ряду своей натуральной ширины, и у узкой
// переписки кнопки уезжали за край; а жёсткая высота 48 обрезала имя и статус
// при крупном тексте (130–150 %). То же самое было и в окне переписки.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Future<void> _pump(WidgetTester t, {required double width, double scale = 1}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
      child: child ?? const SizedBox.shrink(),
    ),
    home: DColors(
      colors: kDColorsDark,
      child: Scaffold(
        body: ChatThreadPanel(
          header: const ChatHeader(
            name: 'Очень длинное название комнаты дизайнеров и разработчиков',
            status: '128 участников, 64 в сети',
            description: 'Обсуждаем обои, пузыри и всё остальное подряд',
          ),
          isDirect: false,
          onCall: () {},
          onVideoCall: () {},
          onToggleSearch: () {},
          onToggleDetails: () {},
          messages: const [
            MessageData(
              id: 'm1',
              authorName: 'Пётр',
              authorSeed: 'dev-petr',
              text: 'привет',
              time: '12:00',
            ),
          ],
        ),
      ),
    ),
  ));
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('узкая переписка: длинное имя — многоточием, кнопки на месте',
      (t) async {
    await _pump(t, width: 380);
    expect(t.takeException(), isNull);
  });

  testWidgets('крупный текст 150 %: шапка растёт, а не режет имя', (t) async {
    await _pump(t, width: 900, scale: 1.5);
    expect(t.takeException(), isNull);
  });

  testWidgets('обычный текст: шапка по-прежнему 48', (t) async {
    await _pump(t, width: 1200);
    final name = find.textContaining('Очень длинное');
    expect(name, findsOneWidget);
    // Остров шапки — ближайший предок-контейнер с минимальной высотой 48.
    final box = t.renderObject<RenderBox>(
      find.ancestor(of: name, matching: find.byType(Container)).first,
    );
    expect(box.size.height, lessThanOrEqualTo(48.5));
  });
}
