// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// B-2: ДИАГНОСТИКА ДОСТАВКИ НА КОМПЬЮТЕРЕ.
//
// 🔴 ЧЕГО НЕ ХВАТАЛО. Когда сообщения не идут, смотреть было не на что и
// присылать в поддержку нечего: экран переписки молчит одинаково и когда всё
// отправлено, и когда очередь стоит.
//
// 🔴 ПОЧЕМУ НЕ ПЕРЕНЕСЛИ ТЕЛЕФОННЫЙ ЭКРАН. Он почти весь про причины, которых
// на компьютере нет: экономия батареи, Data Saver, автозапуск MIUI, «Фоновое
// обновление» iOS. Список проверок, ни одна из которых не относится к машине
// человека, хуже пустоты — он потратит время и решит, что дело не в нас.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/workspace/delivery_diagnostics.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: SizedBox(width: 720, child: SingleChildScrollView(child: child)),
    ),
  ),
);

const _busy = <String, int>{
  'outbox_pending': 4,
  'quarantined': 2,
  'nacked': 1,
  'receipts_queued': 7,
};

void main() {
  testWidgets('числа очередей показываются как есть', (t) async {
    await t.pumpWidget(_host(DesktopDeliveryDiagnostics(
      healthLoader: () async => _busy,
      clockOffsetMs: 0,
    )));
    await t.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('когда ничего не застряло — так и написано', (t) async {
    await t.pumpWidget(_host(DesktopDeliveryDiagnostics(
      healthLoader: () async => const <String, int>{},
      clockOffsetMs: 0,
    )));
    await t.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(find.text(l10n.desktopDiagNothingStuck), findsOneWidget);
  });

  testWidgets('🔴 сбитые часы названы прямо', (t) async {
    await t.pumpWidget(_host(DesktopDeliveryDiagnostics(
      healthLoader: () async => const <String, int>{},
      clockOffsetMs: 95 * 1000,
    )));
    await t.pumpAndSettle();
    // Сбитые часы заставляют сервер отвечать отказом — это уже случалось в
    // поле, и человек должен увидеть причину словами, а не гадать.
    expect(find.textContaining('Часы компьютера сбиты'), findsOneWidget);
  });

  testWidgets('падение загрузчика не оставляет пустоту', (t) async {
    await t.pumpWidget(_host(DesktopDeliveryDiagnostics(
      healthLoader: () async => throw StateError('база недоступна'),
      clockOffsetMs: 0,
    )));
    await t.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    // Диагностика, которая сама падает, бесполезна вдвойне: показываем нули,
    // а не пустоту, чтобы человек видел — считать пробовали.
    expect(find.text(l10n.desktopDiagOutbox), findsOneWidget);
    expect(find.text(l10n.desktopDiagNothingStuck), findsOneWidget);
  });

  testWidgets('сводка ложится в буфер по нажатию', (t) async {
    String? copied;
    await t.pumpWidget(_host(DesktopDeliveryDiagnostics(
      healthLoader: () async => _busy,
      clockOffsetMs: 1500,
      onCopy: (s) => copied = s,
    )));
    await t.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    await t.tap(find.text(l10n.desktopDiagCopy));
    await t.pumpAndSettle();
    expect(copied, isNotNull);
    expect(copied, contains('outbox_pending=4'));
    expect(copied, contains('clock_offset_ms=1500'));
    expect(find.text(l10n.copied), findsOneWidget);
  });

  group('сводка для поддержки', () {
    test('🔴 НИЧЕГО ЛИЧНОГО: только счётчики и часы', () {
      final report = DesktopDeliveryDiagnosticsReport.build(_busy, -2000);
      // Человек отправляет это нам, не читая. Значит внутри не должно быть
      // ничего, о чём он мог бы пожалеть: ни собеседников, ни текстов.
      for (final line in report.split('\n')) {
        expect(
          RegExp(r'^[a-z_]+=-?\d+$').hasMatch(line),
          isTrue,
          reason: 'строка «$line» не похожа на «имя=число»',
        );
      }
      expect(report, contains('clock_offset_ms=-2000'));
    });

    test('расхождение часов читается словами, а не в миллисекундах', () {
      expect(DesktopDeliveryDiagnosticsReport.formatSkew(45 * 1000), '45 s');
      expect(DesktopDeliveryDiagnosticsReport.formatSkew(95 * 1000), '2 min');
      expect(
        DesktopDeliveryDiagnosticsReport.formatSkew(3 * 3600 * 1000),
        '3 h',
      );
      expect(DesktopDeliveryDiagnosticsReport.formatSkew(-45 * 1000), '45 s');
    });
  });
}
