// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// «ПРИЛОЖИТЬ ЖУРНАЛ» — ТОЛЬКО ПОСЛЕ РАЗМЕРА, ПРОСМОТРА И СОГЛАСИЯ (01.10.2026).
//
// 🔴 Кнопка прикладывала до 900 КБ журнала к письму в поддержку молча: ни
// размера, ни способа заглянуть внутрь. Журнал уходит чужим людям — человек
// вправе видеть, что именно.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final log = utf8.encode(
    List.generate(3000, (i) => 'строка журнала №$i relay.ok').join('\n'),
  );

  Future<bool?> run(WidgetTester t, Future<void> Function() steps) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    bool? answer;
    await t.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: desktopMaterialTheme(kDColorsDark, dark: true),
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async => answer = await confirmDesktopSupportLog(
                ctx,
                log,
                sizeText: '0,1 МБ',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await steps();
    return answer;
  }

  testWidgets('🔴 размер назван, внутрь можно заглянуть, отказ — не прикладывать',
      (t) async {
    final answer = await run(t, () async {
      expect(find.text(ru.desktopSupportLogConfirmBody('0,1 МБ')),
          findsOneWidget);
      await t.tap(find.text(ru.desktopSupportLogView));
      await t.pumpAndSettle();
      expect(find.text(ru.desktopSupportLogViewTitle), findsOneWidget);
      expect(find.text('строка журнала №0 relay.ok'), findsOneWidget);
      // Список ленивый: тысячи строк не раскладываются разом.
      expect(find.text('строка журнала №2999 relay.ok'), findsNothing);
      await t.tap(find.text(ru.close));
      await t.pumpAndSettle();
      expect(find.text(ru.desktopSupportLogViewTitle), findsNothing);
      await t.tap(find.text(ru.cancel));
      await t.pumpAndSettle();
    });
    expect(answer, isFalse);
  });

  testWidgets('согласие — прикладывать', (t) async {
    final answer = await run(t, () async {
      await t.tap(find.text(ru.desktopSupportLogAttachConfirm));
      await t.pumpAndSettle();
    });
    expect(answer, isTrue);
  });

  test('кнопка «Приложить журнал» прикладывает только после согласия', () {
    final src = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();
    final body = src.substring(
      src.indexOf('Future<void> _attachLog() async {'),
      src.indexOf('static const int _limitBytes'),
    );
    final ask = body.indexOf('confirmDesktopSupportLog(');
    final attach = body.indexOf('_attachment = DesktopSupportAttachment(');
    expect(ask, greaterThan(0));
    expect(attach, greaterThan(ask));
  });
}
