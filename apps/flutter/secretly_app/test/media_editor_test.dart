// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Редактор фото нового просмотра медиа: поворот, отмена с шторкой, линия
// рисунка, отмена и повтор, ползунок коррекции, пропорция 1:1.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/media_viewer/editor/media_editor_screen.dart';
import 'package:secretly_app/ui/media_viewer/media_edits.dart';

const double _aspect = 40 / 30;

final Uint8List _png = Uint8List.fromList(
  img.encodePng(
    img.Image(width: 40, height: 30)..clear(img.ColorRgb8(90, 140, 200)),
  ),
);

class _Harness {
  MediaEdits? result;
  bool closed = false;
}

Future<_Harness> _open(
  WidgetTester tester, {
  MediaEditorTab tab = MediaEditorTab.crop,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final h = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(brightness: brightness),
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () {
              openMediaEditor(
                context,
                image: MemoryImage(_png),
                sourceAspect: _aspect,
                initial: MediaEdits.identity,
                initialTab: tab,
                hapticsEnabled: () => false,
              ).then((r) {
                h.result = r;
                h.closed = true;
              });
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byKey(kMediaEditorWorkAreaKey), findsOneWidget);
  return h;
}

Future<void> _tapDone(WidgetTester tester) async {
  // Первая — «Готово» в шапке (вторая — в поле текста, если оно открыто).
  await tester.tap(find.text('Done').first);
  await tester.pumpAndSettle();
}

Future<void> _drawLine(WidgetTester tester) async {
  final c = tester.getCenter(find.byKey(kMediaEditorWorkAreaKey));
  final g = await tester.startGesture(c - const Offset(60, 20));
  for (var i = 1; i <= 8; i++) {
    await g.moveBy(const Offset(15, 5));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rotate → Done returns rotation −90', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.byTooltip('Rotate'));
    await tester.pumpAndSettle();
    await _tapDone(tester);
    expect(h.closed, isTrue);
    expect(h.result, isNotNull);
    expect(h.result!.rotation, -90);
    expect(h.result!.k, 3);
  });

  testWidgets('Cancel with changes asks, then returns null', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.byTooltip('Flip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(h.closed, isFalse);
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(h.closed, isTrue);
    expect(h.result, isNull);
    expect(find.byKey(kMediaEditorWorkAreaKey), findsNothing);
  });

  testWidgets('Cancel without changes closes at once', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(h.closed, isTrue);
    expect(h.result, isNull);
  });

  testWidgets('a drag on the draw tab adds one stroke', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    await _drawLine(tester);
    await _tapDone(tester);
    expect(h.result!.strokes, hasLength(1));
    final s = h.result!.strokes.single;
    expect(s.tool, StrokeTool.pen);
    expect(s.points.length, greaterThan(2));
    // Линия — в единицах снимка: x ∈ 0…1000, y ∈ 0…1000/aspect.
    for (final p in s.points) {
      expect(p.dx, inInclusiveRange(0, 1000));
      expect(p.dy, inInclusiveRange(0, 1000 / _aspect));
    }
  });

  testWidgets('undo removes the stroke', (tester) async {
    final h = await _open(tester, tab: MediaEditorTab.draw);
    await _drawLine(tester);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    await _tapDone(tester);
    expect(h.result!.strokes, isEmpty);
  });

  testWidgets('undo then redo restores the stroke', (tester) async {
    final h = await _open(tester, tab: MediaEditorTab.draw);
    await _drawLine(tester);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    await _tapDone(tester);
    expect(h.result!.strokes, hasLength(1));
  });

  testWidgets('an adjust slider drag changes brightness', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('+'), findsWidgets);
    await _tapDone(tester);
    expect(h.result!.adjust.brightness, greaterThan(0));
    expect(h.result!.adjust.contrast, 0);
  });

  testWidgets('aspect 1:1 gives a square crop in image space', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();
    await _tapDone(tester);
    final c = h.result!.crop;
    expect(c.w * _aspect, closeTo(c.h, 1e-9));
    expect(c.h, closeTo(1, 1e-9));
  });

  testWidgets('dragging a crop corner shrinks the crop', (tester) async {
    final h = await _open(tester);
    final area = tester.getRect(find.byKey(kMediaEditorWorkAreaKey));
    // Снимок 4:3 «contain» в коробке с отступом 28: правый нижний угол рамки.
    final box = Rect.fromLTWH(
      area.left + 28,
      area.top + 28,
      area.width - 56,
      area.height - 56,
    );
    final w = box.width, hgt = w / _aspect;
    final br = Offset(box.right, box.center.dy + hgt / 2);
    await tester.dragFrom(br - const Offset(2, 2), const Offset(-60, -40));
    await tester.pumpAndSettle();
    await _tapDone(tester);
    final c = h.result!.crop;
    expect(c.x, 0);
    expect(c.y, 0);
    expect(c.w, lessThan(1));
    expect(c.h, lessThan(1));
  });

  testWidgets('straighten ruler drag sets a positive angle', (tester) async {
    final h = await _open(tester);
    expect(find.text('0°'), findsOneWidget);
    final area = tester.getRect(find.byKey(kMediaEditorWorkAreaKey));
    final ruler = Offset(area.center.dx, area.bottom + 6 + 36);
    await tester.dragFrom(ruler, const Offset(-35, 0));
    await tester.pumpAndSettle();
    await _tapDone(tester);
    expect(h.result!.angle, greaterThan(0));
    expect(h.result!.angle, lessThanOrEqualTo(5));
  });

  testWidgets('text tool: tap adds text, typing and Done keep it',
      (tester) async {
    final h = await _open(tester, tab: MediaEditorTab.draw);
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byKey(kMediaEditorWorkAreaKey)));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await _tapDone(tester);
    expect(h.result!.texts, hasLength(1));
    expect(h.result!.texts.single.text, 'Hi');
  });

  testWidgets('empty text is dropped', (tester) async {
    final h = await _open(tester, tab: MediaEditorTab.draw);
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byKey(kMediaEditorWorkAreaKey)));
    await tester.pumpAndSettle();
    await _tapDone(tester);
    expect(h.result!.texts, isEmpty);
  });

  testWidgets('eraser removes the whole stroke in one step', (tester) async {
    final h = await _open(tester, tab: MediaEditorTab.draw);
    await _drawLine(tester);
    await tester.tap(find.text('Eraser'));
    await tester.pumpAndSettle();
    await _drawLine(tester);
    await _tapDone(tester);
    expect(h.result!.strokes, isEmpty);
  });

  testWidgets('light theme: every tab renders, neon stroke is kept',
      (tester) async {
    final h = await _open(tester, brightness: Brightness.light);
    final area = tester.getRect(find.byKey(kMediaEditorWorkAreaKey));
    await tester.dragFrom(
      Offset(area.center.dx, area.bottom + 6 + 36),
      const Offset(-20, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neon'));
    await tester.pumpAndSettle();
    await _drawLine(tester);
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    final g = await tester.startGesture(tester.getCenter(find.text('Compare')));
    await tester.pump();
    expect(find.text('Original'), findsOneWidget);
    await g.up();
    await tester.pump();
    expect(find.text('Compare'), findsOneWidget);
    await _tapDone(tester);
    expect(tester.takeException(), isNull);
    expect(h.result!.strokes.single.tool, StrokeTool.neon);
    expect(h.result!.angle, greaterThan(0));
  });
}
