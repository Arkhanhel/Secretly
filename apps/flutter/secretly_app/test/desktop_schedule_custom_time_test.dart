// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 «ВЫБРАТЬ ВРЕМЯ…»: ЗАКРЫЛИ ВЫБОР ВРЕМЕНИ — ЗНАЧИТ, ПЕРЕДУМАЛИ (30.09.2026).
//
// Дата выбрана, а выбор времени закрыли — и сообщение всё равно
// откладывалось: на выбранный день, в час и минуту, которых никто не
// выбирал.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/schedule_send_dialog.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

void main() {
  testWidgets('🔴 отмена выбора времени ничего не откладывает', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    // День заведомо в будущем: иначе отказ «в прошлое» спрятал бы ошибку.
    final base = DateTime.now().add(const Duration(days: 2));
    var done = false;
    DateTime? picked;
    showScheduleSendDialog(ctx, now: base).then((v) {
      done = true;
      picked = v;
    });
    await t.pumpAndSettle();
    await t.tap(find.text('Выбрать время…'));
    await t.pumpAndSettle();

    final material = MaterialLocalizations.of(
      t.element(find.byType(DatePickerDialog)),
    );
    await t.tap(find.text(material.okButtonLabel));
    await t.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await t.tap(find.text(material.cancelButtonLabel));
    await t.pumpAndSettle();

    expect(done, isFalse, reason: 'окно «Отправить позже» осталось открытым');
    expect(find.text('Отправить позже'), findsOneWidget);
    expect(picked, isNull);
  });
}
