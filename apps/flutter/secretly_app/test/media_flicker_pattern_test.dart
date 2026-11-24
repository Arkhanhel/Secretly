// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// П-1 / М5 (разбор медиа 22.11.2026): знак скачивания у входящего снимка
// мигал, а превью пересоздавалось на каждой перерисовке ленты.
//
// Воспроизведение (было в разборе, `_ImageAttachmentBubble`): FutureBuilder с
// НОВЫМ запросом файла в каждой сборке; повторный запрос во время скачивания
// сразу отвечал `null`; знак рисовался только «пока запрос не ответил»; три
// формы дерева без ключа. Здесь — тот же сценарий на том, что теперь стоит в
// ленте: [ChatMediaFileSlot] + [InflightRequests] + ход скачивания.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_media_slot.dart';

int previewInits = 0;

class Preview extends StatefulWidget {
  const Preview({super.key, required this.file});
  final File? file;
  @override
  State<Preview> createState() => _PreviewState();
}

class _PreviewState extends State<Preview> {
  @override
  void initState() {
    super.initState();
    previewInits++;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    height: 100,
    child: Text(
      widget.file == null ? 'EMPTY' : 'FILE',
      textDirection: TextDirection.ltr,
    ),
  );
}

void main() {
  late InflightRequests<File?> requests;
  late Completer<File?> download;
  late ValueNotifier<double?> progress;
  late int requestsStarted;
  File? memo;

  // Как `_ensureImagePreviewFile`: один запрос на blobId, пока идёт; итог —
  // в память ленты.
  Future<File?> ensurePreviewFile(String blobId) => requests.run(blobId, () {
    requestsStarted++;
    progress.value = 0; // скачивание началось (ensureCachedAttachmentFile)
    return download.future.then((f) {
      progress.value = null;
      memo = f;
      return f;
    });
  });

  Widget bubble(int tick) => Directionality(
    textDirection: TextDirection.ltr,
    child: ChatMediaFileSlot(
      key: const ValueKey('row'),
      slotKey: 'b1',
      known: memo,
      load: () => ensurePreviewFile('b1'),
      progress: progress,
      preview: (file) => Preview(file: file),
      progressMark: (p) => ValueListenableBuilder<double?>(
        valueListenable: p,
        builder: (context, v, _) => v == null
            ? const SizedBox.shrink()
            : const Text('MARK', textDirection: TextDirection.ltr),
      ),
      goneMark: const Text('GONE', textDirection: TextDirection.ltr),
      isGone: (e) => e is StateError,
    ),
  );

  // Внутри тела теста, а не в setUp: Future и Completer должны жить в зоне
  // testWidgets, иначе их продолжения не проходят через pump().
  void fresh() {
    previewInits = 0;
    requestsStarted = 0;
    memo = null;
    requests = InflightRequests<File?>();
    download = Completer<File?>();
    progress = ValueNotifier<double?>(null);
  }

  testWidgets('знак скачивания не мигает, превью не пересоздаётся', (
    tester,
  ) async {
    fresh();
    final log = <String>[];
    Future<void> frame(int tick) async {
      // Каждая — один тик `controller.changed`, пока снимок качается.
      await tester.pumpWidget(bubble(tick));
      log.add('tick$tick mark=${find.text('MARK').evaluate().isNotEmpty}');
      expect(find.text('MARK'), findsOneWidget, reason: log.join('\n'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('MARK'), findsOneWidget, reason: log.join('\n'));
      if (tick == 1) progress.value = 0.5;
    }

    for (var t = 0; t < 4; t++) {
      await frame(t);
    }
    expect(previewInits, 1, reason: 'превью — одно State на всё скачивание');
    expect(requestsStarted, 1, reason: 'один запрос файла на blobId');
    expect(find.text('EMPTY'), findsOneWidget);

    download.complete(File('/cache/b1.jpg'));
    await tester.pump();
    await tester.pump();
    expect(find.text('MARK'), findsNothing);
    expect(find.text('FILE'), findsOneWidget);
    // Следующие перерисовки — уже из памяти ленты, без запроса.
    await tester.pumpWidget(bubble(9));
    await tester.pump();
    expect(find.text('FILE'), findsOneWidget);
    expect(previewInits, 1, reason: 'файл пришёл — то же State, без пустого кадра');
    expect(requestsStarted, 1);
  });

  testWidgets('файла нет на сервере — знак «недоступно», та же форма', (
    tester,
  ) async {
    fresh();
    await tester.pumpWidget(bubble(0));
    download.completeError(StateError('gone'));
    progress.value = null;
    await tester.pump();
    await tester.pump();
    expect(find.text('GONE'), findsOneWidget);
    expect(find.text('MARK'), findsNothing);
    expect(previewInits, 1);
  });

  test('InflightRequests: один Future, пока идёт; затем — новый', () async {
    final r = InflightRequests<int>();
    final c = Completer<int>();
    var starts = 0;
    Future<int> start() {
      starts++;
      return c.future;
    }

    final a = r.run('k', start);
    final b = r.run('k', start);
    expect(identical(a, b), isTrue);
    expect(r.contains('k'), isTrue);
    c.complete(1);
    expect(await a, 1);
    await Future<void>.delayed(Duration.zero);
    expect(r.contains('k'), isFalse);
    final again = r.run('k', () => Future<int>.value(2));
    expect(identical(again, a), isFalse);
    expect(await again, 2);
    expect(starts, 1);
    // Ошибка снимает запись и не остаётся «без обработчика».
    final failing = r.run('e', () => Future<int>.error(StateError('x')));
    await expectLater(failing, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(r.contains('e'), isFalse);
  });
}
