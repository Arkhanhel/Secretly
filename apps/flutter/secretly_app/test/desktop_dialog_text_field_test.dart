// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// В окне-диалоге должно работать поле ввода.
//
// 🔴 Это не теоретическая проверка. Диалог создания темы падал ровно на этом
// и НИКОГДА не работал: `TextField` ищет `Material` среди предков, а диалог
// открывается отдельным маршрутом поверх дерева и `Material` от приложения с
// собой не приносит.
//
// Заметить это по коду невозможно — разметка диалога выглядит совершенно
// обычной, и падает он только когда окно реально открыли руками. Поэтому
// основание диалога и сторожится тестом: следующий диалог с полем не должен
// повторить ту же историю и обнаружиться так же поздно.

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_dialog.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_text_field.dart';

void main() {
  testWidgets('🔴 поле ввода в диалоге не падает', (t) async {
    final ctl = TextEditingController();
    addTearDown(ctl.dispose);

    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    unawaitedShow(ctx, ctl);
    await t.pumpAndSettle();

    expect(
      t.takeException(),
      isNull,
      reason:
          'без Material в основании диалога TextField бросает '
          '«No Material widget found» — именно так и жил диалог создания темы',
    );
    expect(find.byType(DesktopTextField), findsOneWidget);
  });

  testWidgets('в диалоге можно ПЕЧАТАТЬ, а не только его открыть', (t) async {
    // Отрисовался — ещё не значит работает: поле без Material падало именно
    // при построении, но проверять стоит и ввод, раз уж окно открыто.
    final ctl = TextEditingController();
    addTearDown(ctl.dispose);

    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    unawaitedShow(ctx, ctl);
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'Релиз 1.4');
    await t.pump();

    expect(ctl.text, 'Релиз 1.4');
    expect(t.takeException(), isNull);
  });
}

/// Открывает диалог с полем ввода — ровно так, как это делает создание темы.
void unawaitedShow(BuildContext ctx, TextEditingController ctl) {
  DesktopDialog.show<String>(
    ctx,
    title: 'Новая тема',
    size: DDialogSize.small,
    body: DesktopTextField(
      controller: ctl,
      hintText: 'Название темы',
      autofocus: true,
    ),
    primary: DDialogAction(label: 'Сохранить', onPressed: () {}),
  );
}
