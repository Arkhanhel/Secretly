// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Новый просмотр медиа (макет «Просмотр медиа», 22.11.2026): модель правок,
// хранилище, расчёт перелёта и живой сценарий — открыть из миниатюры,
// листать, приблизить двойным касанием, удалить без закрытия, закрыть.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/media_viewer/media_edits.dart';
import 'package:secretly_app/ui/media_viewer/media_edits_store.dart';
import 'package:secretly_app/ui/media_viewer/media_flight.dart';
import 'package:secretly_app/ui/media_viewer/media_viewer_screen.dart';
import 'package:secretly_app/ui/media_viewer/media_viewer_video.dart';

void main() {
  group('модель правок', () {
    test('выпрямление увеличивает ровно до закрытия пустых углов', () {
      expect(coverScale(CropRect.full, 400, 300, 0), 1);
      final s = coverScale(CropRect.full, 400, 300, 10);
      // Угол (200,150) после поворота на 10° должен остаться внутри снимка.
      expect(s, greaterThan(1));
      expect(s, closeTo(1.2163, 1e-3));
    });

    test('1:1 вписывается по центру прежней рамки', () {
      final c = aspectCrop(1, CropRect.full, 4 / 3);
      expect(c.w * 4 / 3, closeTo(c.h, 1e-9));
      expect(c.x + c.w / 2, closeTo(.5, 1e-9));
    });

    test('угол рамки не уже 12 % и не выходит за снимок', () {
      final c = applyCrop(CropHandle.br, CropRect.full, -2, -2, null, 1.5);
      expect(c.w, closeTo(.12, 1e-9));
      expect(c.h, closeTo(.12, 1e-9));
      final m = applyCrop(CropHandle.move, const CropRect(.2, .2, .5, .5), 1, 1, null, 1);
      expect(m.x, closeTo(.5, 1e-9));
      expect(m.y, closeTo(.5, 1e-9));
    });

    test('с заданной пропорцией сторона двигает рамку, а не меняет её', () {
      const c0 = CropRect(.1, .1, .5, .5);
      final c = applyCrop(CropHandle.t, c0, .1, .1, 1, 1);
      expect(c.w, c0.w);
      expect(c.h, c0.h);
      expect(c.x, closeTo(.2, 1e-9));
    });

    test('поворот на четверть переворачивает пропорцию итогового снимка', () {
      const e = MediaEdits(rotation: -90);
      expect(e.k, 3);
      expect(e.outputAspect(2), closeTo(.5, 1e-9));
    });

    test('правки переживают сохранение в текст', () {
      final e = MediaEdits(
        crop: const CropRect(.1, .2, .5, .4),
        rotation: -180,
        flip: true,
        angle: 3.5,
        adjust: const Adjustments(brightness: .2, vignette: .4),
        strokes: const [
          DrawStroke(
            id: 's1',
            tool: StrokeTool.neon,
            color: Color(0xFFFF5A5F),
            width: 12,
            points: [Offset(10, 20), Offset(30.25, 40)],
          ),
        ],
        texts: const [
          TextItem(
            id: 't1',
            center: Offset(.5, .5),
            text: 'Привет',
            color: Color(0xFFFFFFFF),
            background: true,
            fontFraction: .06,
          ),
          TextItem(
            id: 't2',
            center: Offset(.2, .2),
            text: '   ',
            color: Color(0xFFFFFFFF),
            fontFraction: .06,
          ),
        ],
      );
      final back = MediaEdits.decode(e.encode())!;
      expect(back.sameAs(e), isTrue);
      expect(back.texts, hasLength(1), reason: 'пустой текст не сохраняется');
      expect(back.strokes.single.tool, StrokeTool.neon);
      expect(back.k, 2);
      expect(MediaEdits.decode('{не json'), isNull);
      expect(MediaEdits.identity.isIdentity, isTrue);
    });
  });

  group('хранилище правок', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('mv_edits_');
      MediaEditsStore.instance.resetForTest();
      MediaEditsStore.instance.directoryOverride = () async => dir;
      MediaEditsStore.instance.overlayOverride = true;
    });

    tearDown(() {
      MediaEditsStore.instance.resetForTest();
      MediaEditsStore.instance.directoryOverride = null;
      MediaEditsStore.instance.overlayOverride = null;
      dir.deleteSync(recursive: true);
    });

    test('сохранить, прочитать после перезапуска, удалить', () async {
      const e = MediaEdits(angle: 7, flip: true);
      await MediaEditsStore.instance.save('blob-1', e);
      expect(MediaEditsStore.instance.peek('blob-1')?.angle, 7);

      MediaEditsStore.instance.resetForTest();
      MediaEditsStore.instance.directoryOverride = () async => dir;
      final read = await MediaEditsStore.instance.read('blob-1');
      expect(read?.flip, isTrue);
      expect(await MediaEditsStore.instance.read('blob-2'), isNull);

      await MediaEditsStore.instance.forget('blob-1');
      MediaEditsStore.instance.resetForTest();
      MediaEditsStore.instance.directoryOverride = () async => dir;
      expect(await MediaEditsStore.instance.read('blob-1'), isNull);
    });

    test('пустые правки не пишутся', () async {
      await MediaEditsStore.instance.save('blob-3', MediaEdits.identity);
      expect(MediaEditsStore.instance.peek('blob-3'), isNull);
    });
  });

  group('перелёт', () {
    test('поза миниатюры — формула прототипа thumbTf', () {
      const f = Rect.fromLTWH(0, 292, 390, 260);
      const t = Rect.fromLTWH(10, 500, 135, 180);
      final pose = FlightPose.toThumb(f, t, BorderRadius.circular(4));
      final s = [t.width / f.width, t.height / f.height].reduce((a, b) => a > b ? a : b);
      final ix = (f.width - t.width / s) / 2, iy = (f.height - t.height / s) / 2;
      expect(pose.scale, closeTo(s, 1e-9));
      expect(pose.clip.left, closeTo(ix, 1e-9));
      expect(pose.clip.top, closeTo(iy, 1e-9));
      expect(pose.translate.dx, closeTo(t.left - f.left - s * ix, 1e-9));
      expect(pose.translate.dy, closeTo(t.top - f.top - s * iy, 1e-9));
      expect(pose.radius.topLeft.x, closeTo(4 / s, 1e-9));
    });

    test('уменьшение вокруг центра снимка', () {
      final p = FlightPose.centered(const Size(390, 260), .7, const Offset(5, 40));
      expect(p.translate.dx, closeTo(.3 * 195 + 5, 1e-9));
      expect(p.translate.dy, closeTo(.3 * 130 + 40, 1e-9));
    });
  });

  test('скорость видео по кругу и подпись с запятой', () {
    expect(nextMediaVideoSpeed(1), 1.5);
    expect(nextMediaVideoSpeed(2), .5);
    expect(nextMediaVideoSpeed(.5), 1);
    expect(mediaVideoSpeedLabel(1.5, ','), '1,5×');
    expect(mediaVideoSpeedLabel(2, ','), '2×');
    expect(formatMediaTime(const Duration(seconds: 65)), '1:05');
  });

  group('живой сценарий', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('mv_viewer_');
      MediaEditsStore.instance.resetForTest();
      MediaEditsStore.instance.directoryOverride = () async => dir;
    });

    tearDown(() {
      MediaEditsStore.instance.resetForTest();
      MediaEditsStore.instance.directoryOverride = null;
      MediaFlightAnchors.hidden.value = null;
      dir.deleteSync(recursive: true);
    });

    testWidgets('открыть, листать, приблизить, удалить, закрыть', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final deleted = <String>[];
      MediaViewerEntry entry(String id) => MediaViewerEntry(
        id: id,
        kind: MediaViewerKind.photo,
        loadFile: () async => File('${dir.path}/$id.png'),
        title: 'Anna',
        own: true,
        knownAspect: 1.5,
      );
      final entries = [entry('p1'), entry('p2'), entry('p3')];

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
                  MediaFlightAnchor(
                    tag: 'p1',
                    borderRadius: BorderRadius.circular(16),
                    child: const SizedBox(
                      key: ValueKey('thumb-p1'),
                      width: 120,
                      height: 90,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ),
                  TextButton(
                    onPressed: () => openMediaViewer(
                      context,
                      entries: entries,
                      initialIndex: 0,
                      title: 'Chat',
                      hapticsEnabled: () => false,
                      actions: MediaViewerActions(
                        canEdit: true,
                        onSendEdited: (e, f) async => true,
                        onShare: (e) async => 'shared',
                        deleteInfo: (e) => const MediaViewerDeleteInfo(
                          own: true,
                          canDeleteForEveryone: true,
                          peerName: 'Anna',
                        ),
                        onDelete: (e, scope) async {
                          deleted.add('${e.id}:${scope.name}');
                          return true;
                        },
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      // Кадр маршрута, подготовка (не дольше 450 мс), перелёт 340 мс.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      // Миниатюра в ленте скрыта, пока её снимок открыт.
      expect(MediaFlightAnchors.hidden.value, 'p1');
      final thumbOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('thumb-p1')),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(thumbOpacity.opacity, 0);
      // Панель действий: «Изменить» есть у фото.
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Листание влево — второй снимок.
      await tester.dragFrom(const Offset(300, 420), const Offset(-220, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('2 of 3'), findsOneWidget);
      expect(MediaFlightAnchors.hidden.value, 'p2');

      // Двойное касание — 2,5× и плашка масштаба.
      await tester.tapAt(const Offset(195, 422));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(195, 422));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('2.5×'), findsOneWidget);
      final state = tester.state<MediaViewerScreenState>(
        find.byType(MediaViewerScreen),
      );
      expect(state.debugZoomScale, closeTo(2.5, 1e-6));
      // Повторное — обратно.
      await tester.tapAt(const Offset(195, 422));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(195, 422));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.debugZoomScale, closeTo(1, 1e-6));
      await tester.pump(const Duration(milliseconds: 1000));

      // Оформление пряталось при приближении — одно касание показывает его.
      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 400));

      // Удалить: шторка со своим — «у меня и у …» / «только у меня».
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Delete photo?'), findsOneWidget);
      expect(find.text('Delete for me and Anna'), findsOneWidget);
      await tester.tap(find.text('Delete only for me'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(deleted, ['p2:me']);
      // Просмотр остался открытым на соседнем снимке.
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Photo deleted'), findsOneWidget);

      // Назад — закрытие перелётом.
      await tester.tap(find.bySemanticsLabel('Back'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Anna'), findsNothing);
      expect(MediaFlightAnchors.hidden.value, isNull);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
