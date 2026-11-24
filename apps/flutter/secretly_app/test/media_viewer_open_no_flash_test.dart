// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// О-1 (разбор медиа 22.11.2026): мигание при ОТКРЫТИИ медиа.
//
// Пока просмотр готовит перелёт (файл, пропорция, декод — до 450 мс),
// страница снимка рисовалась поверх чата на прозрачном фоне: размытая копия
// во весь экран и крутилка в центре. Потом она пропадала, и стартовал перелёт
// из миниатюры. Теперь в подготовке страница скрыта: на экране только чат с
// миниатюрой, затем — перелёт.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/media_viewer/media_flight.dart';
import 'package:secretly_app/ui/media_viewer/media_viewer_screen.dart';

const String _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  tearDown(() => MediaFlightAnchors.hidden.value = null);

  testWidgets('в подготовке страница снимка не видна поверх чата', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final file = Completer<File>();
    final entry = MediaViewerEntry(
      id: 'p1',
      kind: MediaViewerKind.photo,
      loadFile: () => file.future,
      knownAspect: 1.5,
      // Размытая миниатюра отправителя — её копия и мигала во весь экран.
      thumbBytes: base64Decode(_png1x1),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 200),
                const MediaFlightAnchor(
                  tag: 'p1',
                  child: SizedBox(width: 120, height: 90),
                ),
                TextButton(
                  onPressed: () => openMediaViewer(
                    context,
                    entries: [entry],
                    initialIndex: 0,
                    hapticsEnabled: () => false,
                  ),
                  child: const Text('open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    double pageOpacity() => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(const ValueKey<String>('mv-page-p1')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    await tester.tap(find.text('open'));
    await tester.pump(); // маршрут
    await tester.pump(); // подготовка началась
    await tester.pump(const Duration(milliseconds: 100));
    // Файл ещё не готов — идёт подготовка: страница скрыта, миниатюра в чате
    // ещё на месте (не скрыта раньше перелёта).
    expect(pageOpacity(), 0);
    expect(MediaFlightAnchors.hidden.value, isNull);

    // Подготовка не дождалась файла (450 мс) — открывается «появлением»:
    // миниатюра скрыта в том же кадре, где стартует перелёт.
    await tester.pump(const Duration(milliseconds: 400));
    expect(MediaFlightAnchors.hidden.value, 'p1');
    expect(pageOpacity(), 0, reason: 'во время перелёта видна летящая копия');

    // Перелёт закончился — страница видна.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(pageOpacity(), 1);
  });
}
