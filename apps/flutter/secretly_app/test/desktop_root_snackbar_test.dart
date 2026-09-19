// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Корень приложения должен уметь СКАЗАТЬ человеку, что не вышло.
//
// 🔴 Дефект, который здесь закреплён, дважды притворялся исправленным.
//
// Корень строит `MaterialApp`, поэтому его собственный контекст лежит ВЫШЕ
// навигатора и слоя. `Overlay.of` ищет слой среди ПРЕДКОВ — и не находит:
//
//   • контекст корня                → предков-слоёв нет вовсе;
//   • `navigatorKey.currentContext` → навигатор ВЫШЕ своего слоя;
//   • контекст самого `Overlay`     → тоже выше, слой это его потомок.
//
// Все три падают «No Overlay widget found», причём МОЛЧА: вызов асинхронный,
// исключение уходит в неперехваченные, и снаружи это выглядит ровно как
// прежнее отсутствие ответа — кнопка нажата, ничего не произошло. То есть
// починка молчания сама молчала о том, что не работает.
//
// Нашлось только запуском приложения с захватом вывода. Отсюда и тест: он
// показывает сообщение ИЗ ТОЙ ЖЕ позиции, что и корень.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_snackbar.dart';

void main() {
  testWidgets('🔴 сообщение показывается из-за пределов навигатора', (t) async {
    final navKey = GlobalKey<NavigatorState>();

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorKey: navKey,
        home: DColors(
          colors: kDColorsDark,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    // Ровно то, что делает корень: слой берём У НАВИГАТОРА, а не ищем по
    // контексту.
    final overlay = navKey.currentState?.overlay;
    expect(overlay, isNotNull, reason: 'навигатор обязан отдать свой слой');

    DesktopSnackbar.showIn(overlay!, message: 'Переписка не найдена');
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(t.takeException(), isNull);
    expect(find.text('Переписка не найдена'), findsOneWidget);

    // Сообщение снимает себя само по таймеру. Досматриваем до конца: иначе
    // проверка завершится с висящим таймером, и тест упадёт не на том, что
    // проверяет.
    await t.pump(const Duration(seconds: 6));
    expect(find.text('Переписка не найдена'), findsNothing);
  });

  testWidgets('🔴 контекст навигатора для поиска слоя НЕ годится', (t) async {
    // Закрепляем саму ловушку: если кто-то «упростит» вызов обратно на
    // `show(navigatorKey.currentContext)`, он снова упрётся в это.
    final navKey = GlobalKey<NavigatorState>();

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorKey: navKey,
        home: DColors(
          colors: kDColorsDark,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    expect(
      () => DesktopSnackbar.show(navKey.currentContext!, message: 'так нельзя'),
      throwsA(isA<FlutterError>()),
      reason: 'контекст навигатора лежит выше его слоя — это и есть ловушка',
    );
  });

  test('🔴 корень показывает отказ через слой навигатора', () {
    // Поведение живёт в корне приложения — виджете, который тянет за собой
    // контроллер, базу и сеть. Сторожим не раскладку, а ОДИН способ доступа,
    // без которого сообщение падает молча.
    final source = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    final start = source.indexOf('_reportOpenChatFailed(String');
    expect(start, greaterThan(0), reason: 'метод переименован — перепиши');
    final body = source.substring(start, start + 900);

    expect(
      body.contains('currentState?.overlay'),
      isTrue,
      reason: 'слой надо брать у навигатора напрямую',
    );
    expect(
      body.contains('DesktopSnackbar.showIn'),
      isTrue,
      reason: '`show` по контексту отсюда не работает — см. шапку файла',
    );
  });
}
