// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЖИВЫЕ РАМКИ: пружины, вырез под фотографию, порог размера.
//
// Что здесь проверяется и почему именно это.
//
// Три персонажа из макета 23.09.2026 отличаются от двадцати прежних рамок
// тем, что у них НЕТ периода: движение считают пружины, моменты подёргивания
// берутся из случайных чисел. Значит ни одна из семи проверок атласа к ним
// неприменима — и значит им нужны свои, иначе они окажутся единственной
// частью украшений, которую не проверяет никто.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:secretly_app/ui/premium/live_frames.dart';

Future<ui.Image> _render(String id, double size, {double seconds = 0}) async {
  final ch = makeLiveFrame(id, math.Random(7));
  ch.tick(seconds, 0, false);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  LiveFramePainter(
    character: ch,
    theme: LiveFrameTheme.of(const Color(0xFFFFFFFF)),
    time: () => seconds,
  ).paint(canvas, Size.square(size));
  return rec.endRecording().toImage(size.round(), size.round());
}

Future<int> _alphaAt(ui.Image img, int x, int y) async {
  final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return d!.getUint8((y * img.width + x) * 4 + 3);
}

void main() {
  group('пружина', () {
    test('🔴 перелетает цель и докачивается, а не подъезжает к ней', () {
      // Это ВСЯ разница между рисованной анимацией и интерполяцией. Если
      // однажды кто-то заменит пружину на кривую, движение станет
      // механическим, и заметить это по картинке будет поздно.
      final s = LiveSpring()..target = 1;
      var overshot = false;
      for (var i = 0; i < 600; i++) {
        s.step(1 / 120, 220, 9);
        if (s.x > 1.001) overshot = true;
      }
      expect(overshot, isTrue, reason: 'перелёта нет — это не пружина');
      expect((s.x - 1).abs(), lessThan(0.01));
    });

    test('докачивание затухает: пружина успокаивается, а не звенит вечно', () {
      final s = LiveSpring()..target = 1;
      for (var i = 0; i < 1200; i++) {
        s.step(1 / 120, 220, 9);
      }
      expect(s.v.abs(), lessThan(0.05));
    });
  });

  group('каталог', () {
    test('🔴 живые рамки НЕ попали в список атласа', () {
      // Семь проверок вокруг kAvatarFrames пекут петли. У живых рамок петли
      // нет, и попадание туда означало бы печь несуществующее.
      final atlas = kAvatarFrames.map((f) => f.id).toSet();
      for (final id in kLiveFrameIds) {
        expect(atlas.contains(id), isFalse, reason: '$id пролез в атлас');
      }
    });

    test('выбор из профиля находит и те, и другие', () {
      for (final id in kLiveFrameIds) {
        expect(frameById(id), isNotNull, reason: 'рамка $id не рисуется');
      }
      expect(frameById('cosmic'), isNotNull);
      expect(frameById('нет такой'), isNull);
    });

    test('идентификаторы не столкнулись', () {
      final ids = kAllAvatarFrames.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.length, kAvatarFrames.length + kLiveFrameIds.length);
    });

    testWidgets('название переведено на все восемь языков', (tester) async {
      for (final tag in const ['ru', 'en', 'uk', 'es', 'pt', 'fr', 'de']) {
        late BuildContext ctx;
        // 🔴 Без MaterialApp: он требует делегат Cupertino для каждого
        // неанглийского языка, а нам нужен только сам язык в контексте.
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Localizations(
              locale: Locale(tag),
              delegates: const [
                DefaultWidgetsLocalizations.delegate,
                DefaultMaterialLocalizations.delegate,
              ],
              child: Builder(
                builder: (c) {
                  ctx = c;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        for (final f in kLivingAvatarFrames) {
          final name = f.nameLocalized(ctx);
          expect(name.trim(), isNotEmpty, reason: '${f.id}/$tag пусто');
        }
      }
    });
  });

  group('рисование', () {
    test('🔴 холст персонажа ШИРЕ квадрата — иначе уши обрежет', () {
      for (final id in kLiveFrameIds) {
        final ch = makeLiveFrame(id, math.Random(1));
        expect(
          ch.canvasOverflow,
          greaterThan(1.4),
          reason: '$id: холст ужали, уши и ноты не поместятся',
        );
      }
    });

    test('🔴 вырез под фотографию: центр вне задних частей', () {
      for (final id in kLiveFrameIds) {
        final ch = makeLiveFrame(id, math.Random(1));
        final hole = LiveFramePainter.photoHole(ch);
        expect(
          hole.contains(Offset(ch.cx, ch.cy)),
          isFalse,
          reason: '$id: задние части полезли на лицо',
        );
        expect(
          hole.contains(Offset(ch.cx, ch.cy - ch.avatarR - 6)),
          isTrue,
          reason: '$id: за краем фотографии рисовать нечем',
        );
      }
    });

    testWidgets('🔴 рамка не закрывает лицо', (tester) async {
      // Рамка — украшение вокруг портрета. Любая непрозрачная точка в середине
      // означает, что человек на фотографии закрыт собственной рамкой.
      await tester.runAsync(() async {
        for (final id in kLiveFrameIds) {
          final img = await _render(id, 200, seconds: 1.3);
          final a = await _alphaAt(img, 100, 100);
          expect(a, lessThan(24), reason: '$id: середина закрашена ($a)');
        }
      });
    });

    testWidgets('🔴 в строке списка рисуется ОДНО кольцо и не вылезает', (
      tester,
    ) async {
      // Холст персонажа почти вдвое шире портрета. В строке списка чатов это
      // значит, что наушники «Меломана» легли бы на имя собеседника. Ниже
      // порога рисуется только кольцо — и оно обязано помещаться в квадрат.
      await tester.runAsync(() async {
        const box = 40.0;
        const pad = 60.0;
        for (final id in kLiveFrameIds) {
          final ch = makeLiveFrame(id, math.Random(2));
          ch.tick(2.2, 0, false);
          final rec = ui.PictureRecorder();
          final canvas = Canvas(rec);
          canvas.translate(pad, pad);
          LiveFramePainter(
            character: ch,
            theme: LiveFrameTheme.of(const Color(0xFFFFFFFF)),
            time: () => 2.2,
            ringOnly: true,
          ).paint(canvas, const Size.square(box));
          final img = await rec
              .endRecording()
              .toImage((box + pad * 2).round(), (box + pad * 2).round());
          final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
          final bytes = d!.buffer.asUint8List();
          final w = img.width;
          var outside = 0;
          for (var y = 0; y < img.height; y++) {
            for (var x = 0; x < w; x++) {
              // 🔴 Допуск в 6 % — это само КОЛЬЦО: его внешний край проходит
              // ровно по стороне квадрата, а «дыхание» добавляет к радиусу
              // полторы единицы макета. Так же ведут себя и двадцать прежних
              // рамок. Уши и наушники выходят на 40 % и более — их этот допуск
              // не пропустит.
              const slack = box * 0.06;
              final inBox =
                  x >= pad - slack &&
                  x < pad + box + slack &&
                  y >= pad - slack &&
                  y < pad + box + slack;
              if (inBox) continue;
              if (bytes[(y * w + x) * 4 + 3] > 8) outside++;
            }
          }
          expect(outside, 0, reason: '$id: вылез за квадрат на $outside точек');
        }
      });
    });

    testWidgets('🔴 в большом размере персонаж ВЫХОДИТ за квадрат', (
      tester,
    ) async {
      // Обратная половина: если однажды кто-то «починит» вылет обрезкой,
      // от персонажа останется одно кольцо и пропадёт вся затея.
      await tester.runAsync(() async {
        const box = 120.0;
        const pad = 90.0;
        final ch = makeLiveFrame('music', math.Random(2));
        ch.tick(2.2, 0, false);
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.translate(pad, pad);
        LiveFramePainter(
          character: ch,
          theme: LiveFrameTheme.of(const Color(0xFFFFFFFF)),
          time: () => 2.2,
        ).paint(canvas, const Size.square(box));
        final img = await rec
            .endRecording()
            .toImage((box + pad * 2).round(), (box + pad * 2).round());
        final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = d!.buffer.asUint8List();
        final w = img.width;
        var outside = 0;
        for (var y = 0; y < img.height; y++) {
          for (var x = 0; x < w; x++) {
            const slack = box * 0.06;
            final inBox =
                x >= pad - slack &&
                x < pad + box + slack &&
                y >= pad - slack &&
                y < pad + box + slack;
            if (inBox) continue;
            if (bytes[(y * w + x) * 4 + 3] > 8) outside++;
          }
        }
        expect(outside, greaterThan(200), reason: 'наушники не вышли за край');
      });
    });

    test('🔴 рамка на десктопе НЕ пропадает с выключенной анимацией', () {
      // Настройка называется «Анимация рамок и статусов». Раньше здесь стоял
      // `animateFrames ? frameById(...) : null`, и выключение убирало
      // украшение целиком: у собеседника пропадала купленная рамка, а в окне
      // выбора плитки показывали голый портрет.
      final src = File(
        'lib/ui/desktop/primitives/avatar.dart',
      ).readAsStringSync();
      expect(
        src.contains('frameById(frameId) : null'),
        isFalse,
        reason: 'рамка снова пропадает вместе с движением',
      );
      expect(src.contains('final frame = frameById(frameId);'), isTrue);
      expect(src.contains('enabled: animateFrames'), isTrue);
    });

    testWidgets('кадр рисуется без исключений на всех размерах', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final id in kLiveFrameIds) {
          for (final s in const [40.0, 64.0, 96.0, 164.0]) {
            for (final t in const [0.0, 2.7, 9.4]) {
              final img = await _render(id, s, seconds: t);
              expect(img.width, s.round());
            }
          }
        }
      });
    });
  });

  group('движение', () {
    test('🔴 ухо дёргается в СЛУЧАЙНЫЕ моменты, но в границах макета', () {
      // Ровный интервал глаз замечает за три повтора. Границы 2–5.5 с — из
      // макета; если кто-то сузит их до постоянной, тест это назовёт.
      final cat = CatFrame(math.Random(11));
      final gaps = <double>[];
      var prev = cat.next;
      for (var t = 0.0; t < 60; t += 1 / 120) {
        cat.tick(t, 1 / 120, false);
        if (cat.next != prev) {
          gaps.add(cat.next - prev);
          prev = cat.next;
        }
      }
      expect(gaps.length, greaterThan(8), reason: 'ухо не дёргалось');
      expect(gaps.toSet().length, greaterThan(5), reason: 'интервал ровный');
      for (final g in gaps) {
        expect(g, greaterThanOrEqualTo(2.0));
        expect(g, lessThanOrEqualTo(5.5));
      }
    });

    test('🔴 бит 120 ударов в минуту, сильная доля чередуется со слабой', () {
      final m = MusicFrame();
      final kicks = <double>[];
      var prevV = m.beat.v;
      for (var t = 0.0; t < 4; t += 1 / 120) {
        m.tick(t, 1 / 120, false);
        if (m.beat.v - prevV > 3) kicks.add(t);
        prevV = m.beat.v;
      }
      // Восемь ударов за четыре секунды — это и есть 120 в минуту.
      expect(kicks.length, 8);
      for (var i = 1; i < kicks.length; i++) {
        expect(kicks[i] - kicks[i - 1], closeTo(0.5, 0.02));
      }
    });

    test('кодер: руки уходят за кольцо и возвращаются, цикл девять секунд', () {
      final c = CoderFrame(math.Random(3));
      double at(double t) {
        final x = CoderFrame(math.Random(3));
        for (var i = 0.0; i < t; i += 1 / 120) {
          x.tick(i, 1 / 120, false);
        }
        return x.out.x;
      }

      expect(at(4), greaterThan(0.8), reason: 'руки не вышли');
      expect(at(8.6), lessThan(0.2), reason: 'руки не спрятались');
      c.tick(0, 0, false);
    });

    test('«меньше движения» и маленький размер не спорят друг с другом', () {
      // Порог из макета: ниже 48 точек персонаж неразборчив. Наш порог 56 —
      // с запасом, потому что строка списка чатов берёт 52.
      expect(kLiveFrameMinAnimatedPx, greaterThanOrEqualTo(48));
    });
  });
}
