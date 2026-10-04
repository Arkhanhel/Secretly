// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 СОРВАВШИЙСЯ ЗАПУСК — НЕ ВЕЧНЫЙ КРУЖОК (01.10.2026).
//
// Ошибка открытия базы или чтения ключа оставляла крутиться заставку вечно.
// Теперь: знак ошибки, «Повторить», «Открыть папку журнала»; затянувшийся
// запуск через минуту предлагает то же, не пряча кружка.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_splash.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

void main() {
  Future<void> pump(WidgetTester t, Widget splash) => t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(colors: kDColorsDark, child: splash),
        ),
      );

  testWidgets('обычный запуск — кружок и никаких кнопок', (t) async {
    await pump(t, DesktopSplash(onRetry: () {}, onOpenLogs: () {}));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
    expect(find.text('Открыть папку журнала'), findsNothing);
  });

  testWidgets('ошибка — кружок уходит, обе кнопки работают', (t) async {
    var retries = 0;
    var opens = 0;
    await pump(
      t,
      DesktopSplash(
        error: 'SqliteException: file is not a database',
        onRetry: () => retries++,
        onOpenLogs: () => opens++,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Не удалось запустить Secretly'), findsOneWidget);
    expect(find.text('SqliteException: file is not a database'), findsOneWidget);

    await t.tap(find.text('Повторить'));
    await t.tap(find.text('Открыть папку журнала'));
    expect(retries, 1);
    expect(opens, 1);
  });

  testWidgets('затянувшийся запуск — кружок остаётся, выход предложен',
      (t) async {
    await pump(
      t,
      DesktopSplash(slow: true, onRetry: () {}, onOpenLogs: () {}),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Запуск идёт дольше обычного'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Открыть папку журнала'), findsOneWidget);
  });

  test('запуск помнит свой номер и честно сообщает о задержке', () {
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    final boot = app.substring(
      app.indexOf('  Future<void> _boot() async {'),
      app.indexOf('  void _retryBoot()'),
    );
    expect(boot.contains('final gen = ++_bootGeneration;'), isTrue);
    expect(boot.contains('Timer(_kBootSlowAfter'), isTrue);
    expect(
      boot.contains('if (stale()) return;'),
      isTrue,
      reason: 'запуск, сменённый «Повторить», не трогает новый контроллер',
    );
    expect(app.contains('onRetry: _retryBoot,'), isTrue);
    expect(app.contains('openDesktopLogFolder()'), isTrue);
  });
}
