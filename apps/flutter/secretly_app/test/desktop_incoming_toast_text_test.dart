// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · «Текстом» во входящем звонке.
//
// 🔴 ЭТО НЕ ТРЕТИЙ СПОСОБ ОТКЛОНИТЬ. Между «взять трубку» и «сбросить» есть
// третий настоящий ответ — «сейчас не могу, напишу»: на совещании, в наушниках
// с музыкой, рядом со спящим ребёнком. Без него человек либо берёт трубку
// молча, либо сбрасывает, и звонивший не знает, что случилось.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/calls/incoming_call_toast.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('· кнопка есть, когда есть кому писать', (t) async {
    await t.pumpWidget(
      host(
        IncomingCallToast(
          callerName: 'Игорь',
          subtitle: 'Входящий звонок',
          onAccept: () {},
          onDecline: () {},
          onReplyWithText: () {},
        ),
      ),
    );
    expect(find.text('Текстом'), findsOneWidget);
    expect(find.text('Ответить'), findsOneWidget);
  });

  testWidgets('🔴 некому писать — кнопки нет вовсе', (t) async {
    // Кнопка, которая никуда не ведёт, хуже её отсутствия.
    await t.pumpWidget(
      host(
        IncomingCallToast(
          callerName: 'Игорь',
          subtitle: 'Входящий звонок',
          onAccept: () {},
          onDecline: () {},
        ),
      ),
    );
    expect(find.text('Текстом'), findsNothing);
    expect(find.text('Ответить'), findsOneWidget);
  });

  testWidgets('нажатие зовёт свой обработчик, а не «Ответить»', (t) async {
    var text = 0;
    var accept = 0;
    await t.pumpWidget(
      host(
        IncomingCallToast(
          callerName: 'Игорь',
          subtitle: 'Входящий звонок',
          onAccept: () => accept++,
          onDecline: () {},
          onReplyWithText: () => text++,
        ),
      ),
    );
    await t.tap(find.text('Текстом'));
    await t.pump();
    expect(text, 1);
    expect(accept, 0);
  });

  group('правила', () {
    final toast = File(
      'lib/ui/desktop/calls/incoming_call_toast.dart',
    ).readAsStringSync();
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();

    test('«Текстом» приглушена, «Ответить» — сплошная', () {
      // Это не главное действие всплывашки, а третий честный ответ рядом.
      final i = toast.indexOf('label: l10n.desktopCallAnswerText');
      final body = toast.substring(i, (i + 400).clamp(0, toast.length));
      expect(body.contains("Colors.white.withValues(alpha: 0.06)"), isTrue);
      expect(body.contains('fg: c.textSecondary'), isTrue);
    });

    test('🔴 звонок сбрасывается ТЕМ ЖЕ путём, что «Отклонить»', () {
      // Иначе у звонящего осталась бы висеть трубка.
      final i = app.indexOf('onReplyWithText:');
      final body = app.substring(i, (i + 600).clamp(0, app.length));
      expect(body.contains('cm.declineIncoming()'), isTrue);
      expect(body.contains('_openProfileChatByDeepLink'), isTrue);
    });

    test('🔴 приложение НЕ пишет за человека', () {
      // «Сейчас не могу» бывает разным, и подставлять слова значит говорить
      // за него. Открываем переписку — дальше он пишет сам.
      final code = toast
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
          .join('\n');
      expect(code.contains('sendMessage'), isFalse);
      expect(code.contains('Не могу говорить'), isFalse);
    });
  });
}
