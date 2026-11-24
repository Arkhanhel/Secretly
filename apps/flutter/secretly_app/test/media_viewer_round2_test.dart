// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Просмотр медиа, второй круг (22.11.2026):
//  С-9  — после удаления не мелькает сосед; дальний прыжок без пустого
//         экрана; видео не открылось — сообщение и «Повторить»;
//  С-11 — шапка и шторка при шрифте 2,0× без переполнения.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/media_viewer/media_edits_store.dart';
import 'package:secretly_app/ui/media_viewer/media_flight.dart';
import 'package:secretly_app/ui/media_viewer/media_viewer_screen.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mv_round2_');
    MediaEditsStore.instance.resetForTest();
    MediaEditsStore.instance.directoryOverride = () async => dir;
  });

  tearDown(() {
    MediaEditsStore.instance.resetForTest();
    MediaEditsStore.instance.directoryOverride = null;
    MediaFlightAnchors.hidden.value = null;
    dir.deleteSync(recursive: true);
  });

  /// Снимок, файл которого «качается» вечно — на экране заготовка.
  MediaViewerEntry photo(String id, {String? title}) => MediaViewerEntry(
    id: id,
    kind: MediaViewerKind.photo,
    loadFile: () => Completer<File>().future,
    title: title ?? 'Anna',
    time: DateTime.now().subtract(const Duration(days: 1)),
    own: true,
    knownAspect: 1.5,
  );

  Future<void> openViewer(
    WidgetTester tester, {
    required List<MediaViewerEntry> entries,
    int initialIndex = 0,
    double textScale = 1,
    MediaViewerActions? actions,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openMediaViewer(
                  context,
                  entries: entries,
                  initialIndex: initialIndex,
                  title: 'Чат',
                  hapticsEnabled: () => false,
                  actions:
                      actions ??
                      MediaViewerActions(
                        onReply: (e) async {},
                        onForward: (e) async {},
                        onShare: (e) async => null,
                        deleteInfo: (e) => const MediaViewerDeleteInfo(
                          own: true,
                          canDeleteForEveryone: true,
                          peerName: 'Анна Длинная-Фамилия',
                        ),
                        onDelete: (e, scope) async => true,
                      ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
  }

  bool hasPage(String id) =>
      find.byKey(ValueKey<String>('mv-page-$id')).evaluate().isNotEmpty;

  testWidgets('С-11: шрифт 2,0× — шапка, панель и шторка без переполнения', (
    tester,
  ) async {
    await openViewer(
      tester,
      textScale: 2.0,
      entries: [
        photo('p1', title: 'Анна Константиновна Длинная-Фамилия'),
        photo('p2'),
        photo('p3'),
        photo('p4'),
        photo('p5'),
      ],
      initialIndex: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('2 из 5'), findsOneWidget);
    // Шапка не ниже 48 и не обрезает строки.
    final header = tester.getSize(
      find
          .ancestor(
            of: find.textContaining('2 из 5'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(header.height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('Удалить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Отмена'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('С-9: после удаления в центр въезжает только новый снимок', (
    tester,
  ) async {
    await openViewer(
      tester,
      entries: [photo('p1'), photo('p2'), photo('p3')],
      initialIndex: 1,
    );
    expect(hasPage('p1'), isTrue);
    await tester.tap(find.text('Удалить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Удалить только у меня'));
    await tester.pump(); // ответ шторки
    await tester.pump(); // удаление
    await tester.pump(const Duration(milliseconds: 16));
    // Сосед слева больше не рисуется в центре на время въезда.
    expect(hasPage('p1'), isFalse);
    expect(hasPage('p3'), isTrue);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(hasPage('p1'), isTrue, reason: 'после въезда соседи снова строятся');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('С-9: дальний прыжок с ленты — ни одного пустого кадра', (
    tester,
  ) async {
    await openViewer(
      tester,
      entries: [for (var i = 1; i <= 6; i++) photo('p$i')],
    );
    expect(hasPage('p1'), isTrue);
    await tester.tap(find.byKey(const ValueKey<String>('mv-strip-p5')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final any = [for (var k = 1; k <= 6; k++) 'p$k'].any(hasPage);
      expect(any, isTrue, reason: 'кадр $i без страниц');
    }
    expect(hasPage('p5'), isTrue);
    expect(find.textContaining('5 из 6'), findsOneWidget);
  });

  testWidgets('С-9: видео не скачалось — сообщение и «Повторить»', (
    tester,
  ) async {
    var calls = 0;
    final video = MediaViewerEntry(
      id: 'v1',
      kind: MediaViewerKind.video,
      loadFile: () {
        calls++;
        if (calls == 1) return Future<File>.error(const SocketException('x'));
        return Completer<File>().future;
      },
      knownAspect: 16 / 9,
    );
    await openViewer(tester, entries: [video]);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Не удалось открыть видео'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, greaterThanOrEqualTo(2));
    expect(find.text('Не удалось открыть видео'), findsNothing);
  });
}
