// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 О1 (30.09.2026, владелец: «динамические обои и стандартные обои с
// узорами при расширении чата растягиваются, а в Telegram они как будто
// генеративно расширяются»).
//
// Было: узор ложился «по покрытию», и на широком окне масштаб решала ширина —
// дудл вдвое-вчетверо крупнее, чем на телефоне. Плюс каждое изменение ширины
// окна заново декодировало картинку — мигание.
//
// Стало, как в Telegram Desktop: масштаб по ВЫСОТЕ, колонки от центра,
// нечётным числом; декодирование — один раз на плотность пикселей. Здесь
// закреплено и это, и то, что телефон не тронут.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/ui/chat_wallpapers.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_wallpaper.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_wallpaper_picker.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_wallpaper_tiling.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/widgets/telegram_wallpaper.dart'
    show kTelegramWallpaperMaskAsset;

import 'art_assets_availability.dart';

/// Картинка из памяти, которая считает, сколько раз её декодировали.
class _CountingImage extends ImageProvider<_CountingImage> {
  _CountingImage(this.bytes);

  final Uint8List bytes;
  int loads = 0;

  @override
  Future<_CountingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_CountingImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _CountingImage key,
    ImageDecoderCallback decode,
  ) {
    loads++;
    return OneFrameImageStreamCompleter(_load(decode));
  }

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }
}

/// Узор-подделка 90×160 (пропорция обоев 9:16): горизонтальный градиент,
/// чтобы было видно отражение, и белый квадрат-«дудл» 10×10 в (40, 70).
Uint8List _patternPng() {
  final im = img.Image(width: 90, height: 160);
  for (var y = 0; y < 160; y++) {
    for (var x = 0; x < 90; x++) {
      final marker = x >= 40 && x < 50 && y >= 70 && y < 80;
      im.setPixelRgba(
        x,
        y,
        marker ? 255 : 20 + x * 2,
        marker ? 255 : 40,
        marker ? 255 : 60 + y,
        255,
      );
    }
  }
  return img.encodePng(im);
}

/// Скачок цвета на стыке повтора против того же скачка в обычных местах
/// картинки: полосы по 24 px по обе стороны, наибольший из трёх каналов,
/// среднее по строкам. Картинка — уже в масштабе чата (высота 900).
double _repeatSeamRatio(Uint8List rgba, int w, int h) {
  double band(int x0, int x1, int y, int c) {
    var sum = 0;
    for (var x = x0; x < x1; x++) {
      sum += rgba[(y * w + x) * 4 + c];
    }
    return sum / (x1 - x0);
  }

  // Полоса [left, left + 24) против полосы [right, right + 24).
  double jump(int left, int right) {
    var total = 0.0, rows = 0;
    for (var y = 0; y < h; y += 3) {
      var worst = 0.0;
      for (var c = 0; c < 3; c++) {
        final d = (band(left, left + 24, y, c) - band(right, right + 24, y, c))
            .abs();
        if (d > worst) worst = d;
      }
      total += worst;
      rows++;
    }
    return total / rows;
  }

  // Стык повтора: правый край картинки встречается с левым.
  final seam = jump(w - 26, 2);
  var base = 0.0, n = 0;
  for (var x = 60; x < w - 60; x += 13) {
    base += jump(x - 26, x + 2);
    n++;
  }
  return seam / (base / n);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('раскладка: масштаб по высоте, колонки от центра', () {
    const jpeg = Size(1440, 2560); // статичные обои
    const mask = Size(1620, 2880); // маска живых обоев

    test('🔴 дудл одного размера при ширине 700, 1400 и 1900', () {
      for (final image in [jpeg, mask]) {
        final sizes = <double>{};
        final columns = <double>{};
        for (final w in <double>[700, 1400, 1900]) {
          final t = desktopPatternTiling(area: Size(w, 900), image: image);
          // Дудл 100 px картинки на экране — в логических пикселях.
          sizes.add(100 * t.scale);
          columns.add(t.columnWidth);
        }
        expect(sizes, hasLength(1),
            reason: 'ширина окна не должна менять размер дудла ($image)');
        expect(columns, hasLength(1));
        expect(sizes.single, closeTo(100 * 900 / image.height, 1e-9),
            reason: 'масштаб — высота области / высота картинки');
      }
    });

    test('шире окно — больше колонок, как у Telegram', () {
      int cols(double w) =>
          desktopPatternTiling(area: Size(w, 900), image: jpeg).columns;
      // Колонка обоев 1440×2560 при высоте 900 — 506,25 px.
      expect(cols(700), 3);
      expect(cols(1400), 3);
      expect(cols(1900), 5);
      expect(cols(300), 1);
    });

    test('нечётное число колонок, центральная посередине, ширина закрыта', () {
      for (final image in [jpeg, mask]) {
        for (final w in <double>[
          120, 300, 506, 507, 700, 1012, 1013, 1400, 1519, 1900, 3000,
        ]) {
          final area = Size(w, 900);
          final t = desktopPatternTiling(area: area, image: image);
          expect(t.columns.isOdd, isTrue, reason: 'w=$w');
          expect(t.originX + t.columnWidth / 2, closeTo(w / 2, 1e-9),
              reason: 'центральная колонка — ровно посередине');
          expect(t.firstColumnX, lessThanOrEqualTo(1e-9), reason: 'w=$w');
          expect(
            t.firstColumnX + t.columns * t.columnWidth,
            greaterThanOrEqualTo(w - 1e-9),
            reason: 'колонки закрывают всю ширину, w=$w',
          );
          // Формула Telegram Desktop (chat_theme.cpp).
          final cx = (w / t.columnWidth).ceil();
          expect(t.columns, (cx ~/ 2) * 2 + 1);
        }
      }
    });

    test('масштаб следует за высотой', () {
      for (final h in <double>[600, 900, 1200]) {
        final t = desktopPatternTiling(area: Size(1400, h), image: jpeg);
        expect(t.scale, closeTo(h / 2560, 1e-12));
        expect(t.columnWidth, closeTo(h * 1440 / 2560, 1e-9));
      }
    });

    test('размер декодирования на раскладку не влияет', () {
      // Та же картинка при 100 % (до высоты 1600) и при 200 % (целиком).
      final small =
          desktopPatternTiling(area: const Size(1400, 900), image: const Size(900, 1600));
      final full = desktopPatternTiling(area: const Size(1400, 900), image: jpeg);
      expect(small.columnWidth, closeTo(full.columnWidth, 1e-9));
      expect(small.originX, closeTo(full.originX, 1e-9));
      expect(small.columns, full.columns);
    });

    test('пустая область — рисовать нечего', () {
      expect(desktopPatternTiling(area: Size.zero, image: jpeg).columns, 0);
      expect(
        desktopPatternTiling(area: const Size(700, 900), image: Size.zero).columns,
        0,
      );
    });

    test('🔴 стык: живые — повтор, картинки — повтор только при совпадении '
        'краёв по цвету', () {
      // Зеркало непрерывно, но у каждого стыка даёт пары дудлов-близнецов «как
      // в калейдоскопе». Повтор их не даёт; у живых обоев цвет рисуют пятна на
      // всю область, поэтому «шторы» на стыке не бывает.
      expect(kDesktopLiveWallpaperTileMode, TileMode.repeated);
      for (final name in const [
        'wallpaper_light_mint.jpg',
        'wallpaper_light_peach.jpg',
        'wallpaper_light_sky.jpg',
      ]) {
        expect(
          desktopWallpaperTileModeFor('assets/Background/improved_light/$name'),
          TileMode.repeated,
          reason: name,
        );
      }
      for (final path in const [
        'assets/Background/wallpaper_dark_navy.jpg',
        'assets/Background/wallpaper_dark_graphite.jpg',
        'assets/Background/wallpaper_dark_teal.jpg',
        'assets/Background/wallpaper_dark_plum.jpg',
        'assets/Background/wallpaper_dark_wine.jpg',
        'assets/Background/chat_default.jpg',
        'assets/Background/improved_light/chat_default.jpg',
        'assets/Background/improved_light/wallpaper_light_lavender.jpg',
        'assets/Background/improved_light/wallpaper_light_sunset.jpg',
      ]) {
        expect(desktopWallpaperTileModeFor(path), TileMode.mirror, reason: path);
      }
    });

    testWidgets('🔴 список «повтор» сверен с самими картинками', (t) async {
      // Повтор — только тем, у кого стык по цвету не резче обычного места
      // картинки: иначе на каждом стыке видна вертикальная «штора» (у тёмных —
      // в 4–5 раз резче). Поменяли картинки — тест скажет, кому какой стык.
      final files = [
        ...Directory('assets/Background').listSync(),
        ...Directory('assets/Background/improved_light').listSync(),
      ].whereType<File>().where((f) => f.path.endsWith('.jpg')).toList();
      expect(files, hasLength(12));
      for (final file in files) {
        late Uint8List rgba;
        late int w, h;
        await t.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
            file.readAsBytesSync(),
            targetHeight: 900,
          );
          final image = (await codec.getNextFrame()).image;
          w = image.width;
          h = image.height;
          final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          rgba = data!.buffer.asUint8List();
          image.dispose();
        });
        final ratio = _repeatSeamRatio(rgba, w, h);
        final name = file.uri.pathSegments.last;
        expect(
          kDesktopWallpaperRepeatAssets.contains(name),
          ratio <= 1.0,
          reason: '${file.path}: стык повтора ${ratio.toStringAsFixed(2)} от '
              'обычного',
        );
      }
    }, skip: artAssetsArePlaceholders);
  });

  group('декодирование — один раз на плотность пикселей', () {
    test('высота декодирования зависит только от плотности', () {
      expect(desktopWallpaperDecodeHeight(devicePixelRatio: 1), 1600);
      expect(desktopWallpaperDecodeHeight(devicePixelRatio: 1.25), 2000);
      expect(desktopWallpaperDecodeHeight(devicePixelRatio: 2), 3200);
      expect(desktopWallpaperDecodeHeight(devicePixelRatio: double.nan), 1600);
      expect(desktopWallpaperDecodeHeight(devicePixelRatio: 0), 1600);
      expect(
        desktopWallpaperDecodeHeight(devicePixelRatio: 2, preview: true),
        kDesktopWallpaperPreviewDecodeHeight,
      );
    });

    test('🔴 ключ кэша маски не зависит от ширины окна', () {
      const layout = DesktopTiledPatternLayout();
      const mask = AssetImage(kTelegramWallpaperMaskAsset);
      ImageProvider at(Size size, double dpr) => layout.maskProvider(
        mask,
        MediaQueryData(size: size, devicePixelRatio: dpr),
      );
      expect(at(const Size(700, 900), 2), at(const Size(1900, 900), 2));
      expect(at(const Size(700, 900), 2), at(const Size(1900, 1200), 2));
      expect(at(const Size(700, 900), 2), isNot(at(const Size(700, 900), 1)),
          reason: 'другой монитор — другая плотность, новый декод законен');
    });

    Future<void> resizeTo(WidgetTester t, Size size) async {
      t.view.physicalSize = size;
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
    }

    testWidgets('🔴 растягивание окна не декодирует картинку заново',
        (t) async {
      imageCache.clear();
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final source = _CountingImage(_patternPng());
      await resizeTo(t, const Size(700, 900));
      await t.pumpWidget(
        MaterialApp(home: DesktopTiledWallpaperImage(image: source)),
      );
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      expect(source.loads, 1);
      for (final size in const [Size(1400, 900), Size(1900, 900), Size(1900, 640)]) {
        await resizeTo(t, size);
        expect(source.loads, 1, reason: 'окно $size — тот же декод');
      }
      t.view.devicePixelRatio = 2;
      await resizeTo(t, const Size(3800, 1280));
      expect(source.loads, 2, reason: 'другая плотность — новый декод');
    });

    testWidgets('🔴 живые обои ПК: маска не декодируется заново по ширине',
        (t) async {
      imageCache.clear();
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final mask = _CountingImage(_patternPng());
      await resizeTo(t, const Size(700, 900));
      await t.pumpWidget(
        MaterialApp(
          home: TelegramWallpaper(
            mask: mask,
            mode: ChatWallpaperAnimMode.off,
            patternLayout: const DesktopTiledPatternLayout(),
          ),
        ),
      );
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      expect(mask.loads, 1);
      await resizeTo(t, const Size(1900, 900));
      expect(mask.loads, 1);
    });

    testWidgets('телефон как был: маска по ширине экрана', (t) async {
      // Закреплено, что ветка телефона не тронута: без раскладки маска, как и
      // раньше, декодируется по ширине экрана и перечитывается при повороте.
      imageCache.clear();
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final mask = _CountingImage(_patternPng());
      await resizeTo(t, const Size(400, 800));
      await t.pumpWidget(
        MaterialApp(
          home: TelegramWallpaper(mask: mask, mode: ChatWallpaperAnimMode.off),
        ),
      );
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      expect(mask.loads, 1);
      await resizeTo(t, const Size(800, 400));
      expect(mask.loads, 2);
    });
  });

  group('рисунок', () {
    Future<Uint8List> shoot(WidgetTester t, Widget child, Size size) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(key: key, child: child),
        ),
      );
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await t.pump();
      late Uint8List rgba;
      await t.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        rgba = data!.buffer.asUint8List();
        image.dispose();
      });
      return rgba;
    }

    int px(Uint8List rgba, int w, int x, int y) {
      final i = (y * w + x) * 4;
      return (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
    }

    testWidgets(
        '🔴 центральная колонка одинакова при любой ширине, «дудл» — того же '
        'размера, зеркальный стык непрерывен', (t) async {
      imageCache.clear();
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final source = _CountingImage(_patternPng());
      // Высота 320 → масштаб 2, колонка 180 px; ширины подобраны так, чтобы
      // центральная колонка начиналась на целом пикселе.
      const h = 320;
      List<int>? centre;
      for (final w in const [400, 800, 1100]) {
        final rgba = await shoot(
          t,
          // Плитка выбора: картинка по высоте плитки (раскладка О1). В
          // переписке плитка постоянного размера — см. группу «ряды».
          DesktopTiledWallpaperImage(image: source, preview: true),
          Size(w.toDouble(), h.toDouble()),
        );
        final origin = (w - 180) ~/ 2;
        final crop = <int>[
          for (var y = 0; y < h; y++)
            for (var x = 0; x < 180; x++) px(rgba, w, origin + x, y),
        ];
        centre ??= crop;
        expect(crop, centre, reason: 'ширина $w: центральная колонка другая');

        // «Дудл» 10×10 при масштабе 2 — 20×20 на экране при любой ширине.
        var minX = w, maxX = -1, minY = h, maxY = -1;
        for (var y = 0; y < h; y++) {
          for (var x = origin; x < origin + 180; x++) {
            // Белый: и синий, и зелёный яркие (у фона зелёный — 40).
            if ((px(rgba, w, x, y) & 0xFF) > 150 &&
                ((px(rgba, w, x, y) >> 8) & 0xFF) > 150) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        expect(maxX - minX + 1, inInclusiveRange(19, 21), reason: 'w=$w');
        expect(maxY - minY + 1, inInclusiveRange(19, 21), reason: 'w=$w');

        // Зеркальный стык: столбцы по обе стороны от края центральной
        // колонки совпадают — ни шва, ни скачка цвета.
        for (var y = 0; y < h; y += 7) {
          expect(px(rgba, w, origin - 1, y), px(rgba, w, origin, y),
              reason: 'левый стык, w=$w, y=$y');
          expect(px(rgba, w, origin + 180, y), px(rgba, w, origin + 179, y),
              reason: 'правый стык, w=$w, y=$y');
        }
      }
      expect(source.loads, 1);
    });

    testWidgets('повтор: соседняя колонка — та же картинка, не отражённая',
        (t) async {
      imageCache.clear();
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final source = _CountingImage(_patternPng());
      const w = 800, h = 320;
      final rgba = await shoot(
        t,
        DesktopTiledWallpaperImage(
          image: source,
          tileMode: TileMode.repeated,
          preview: true,
        ),
        const Size(800, 320),
      );
      const origin = (w - 180) ~/ 2;
      // Сравниваем середину колонок: у самого края повтор, как и положено,
      // сглаживает стык с соседней колонкой.
      for (var y = 0; y < h; y += 5) {
        for (var x = 4; x < 176; x += 3) {
          expect(px(rgba, w, origin + 180 + x, y), px(rgba, w, origin + x, y),
              reason: 'правая колонка, x=$x, y=$y');
          expect(px(rgba, w, origin - 180 + x, y), px(rgba, w, origin + x, y),
              reason: 'левая колонка, x=$x, y=$y');
        }
      }
    });

    testWidgets('🔴 поле волны разложено теми же колонками и стыком, что и '
        'маска', (t) async {
      // Поле 27×48 (пропорция маски) с градиентом по X.
      late ui.Image field;
      await t.runAsync(() async {
        final im = img.Image(width: 27, height: 48);
        for (var y = 0; y < 48; y++) {
          for (var x = 0; x < 27; x++) {
            im.setPixelRgba(x, y, x * 9, y * 5, 0, 255);
          }
        }
        final codec = await ui.instantiateImageCodec(img.encodePng(im));
        field = (await codec.getNextFrame()).image;
      });
      addTearDown(field.dispose);
      const area = Size(1400, 900);
      final (composed, src) = desktopPatternFieldSource(
        field,
        area,
        tileMode: TileMode.mirror,
      );
      final tiling = desktopPatternTiling(area: area, image: const Size(27, 48));
      final n = composed.width ~/ 27;
      expect(n.isOdd, isTrue);
      expect(n, greaterThanOrEqualTo(tiling.columns));
      expect(composed.height, 48);
      // Экранная точка x ложится в поле по src: X = src.left + x / W × src.width.
      double fieldX(double x) => src.left + x / area.width * src.width;
      // Край центральной колонки маски — край центральной колонки поля.
      expect(fieldX(tiling.originX), closeTo((n ~/ 2) * 27, 1e-9));
      expect(fieldX(tiling.originX + tiling.columnWidth),
          closeTo((n ~/ 2 + 1) * 27, 1e-9));
      expect(src.top, 0);
      expect(src.height, 48);

      Future<Uint8List> pixels(ui.Image image) async {
        late Uint8List rgba;
        await t.runAsync(() async {
          final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          rgba = data!.buffer.asUint8List();
        });
        return rgba;
      }

      // Зеркало: центральная колонка поля — как есть, соседние — отражены.
      var rgba = await pixels(composed);
      int red(int x, int y) => rgba[(y * composed.width + x) * 4];
      final c0 = (n ~/ 2) * 27;
      for (final y in const [0, 20, 47]) {
        for (var i = 0; i < 27; i++) {
          expect(red(c0 + i, y), i * 9, reason: 'центр, x=$i');
          expect(red(c0 - 1 - i, y), i * 9, reason: 'левое отражение, x=$i');
          expect(red(c0 + 27 + i, y), (26 - i) * 9, reason: 'правое, x=$i');
        }
      }

      // Повтор (живые обои): соседние колонки — та же картинка поля.
      final (repeated, _) = desktopPatternFieldSource(
        field,
        area,
        tileMode: TileMode.repeated,
      );
      expect(repeated.width, composed.width);
      rgba = await pixels(repeated);
      int red2(int x, int y) => rgba[(y * repeated.width + x) * 4];
      for (final y in const [0, 20, 47]) {
        for (var i = 0; i < 27; i++) {
          expect(red2(c0 + i, y), i * 9, reason: 'центр, x=$i');
          expect(red2(c0 - 27 + i, y), i * 9, reason: 'левая колонка, x=$i');
          expect(red2(c0 + 27 + i, y), i * 9, reason: 'правая колонка, x=$i');
        }
      }
    });
  });

  group('подключено', () {
    Future<Widget> build(
      WidgetTester t,
      String id, {
      bool preview = false,
    }) async {
      late Widget out;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              out = buildDesktopChatWallpaper(
                context,
                wallpaperId: id,
                palette: kDColorsDark,
                animMode: ChatWallpaperAnimMode.off,
                preview: preview,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return out;
    }

    testWidgets('картинки набора — по высоте, колонками', (t) async {
      final w = await build(
        t,
        encodeAssetChatWallpaperId(kDarkThemeStandardChatWallpaperAssetPath),
      );
      expect(w, isA<DesktopTiledWallpaperImage>());
      expect((w as DesktopTiledWallpaperImage).preview, isFalse);
      expect(w.tileMode, TileMode.mirror, reason: 'у «Ночного синего» края разного цвета');
      final p = await build(
        t,
        encodeAssetChatWallpaperId(kDarkThemeStandardChatWallpaperAssetPath),
        preview: true,
      );
      expect((p as DesktopTiledWallpaperImage).preview, isTrue);
      final mint = await build(
        t,
        encodeAssetChatWallpaperId(kLightThemeStandardChatWallpaperAssetPath),
      );
      expect((mint as DesktopTiledWallpaperImage).tileMode, TileMode.repeated);
    });

    testWidgets('живые обои ПК — с раскладкой, телефон — без', (t) async {
      final desk = await build(t, 'anim:aurora');
      expect(desk, isA<TelegramWallpaper>());
      expect(
        (desk as TelegramWallpaper).patternLayout,
        const DesktopTiledPatternLayout(),
      );
      // Плитка выбора — та же раскладка и тот же декод маски, что у чата:
      // тонкие линии маски при мелком декоде рассыпаются в искры.
      final tile = await build(t, 'anim:aurora', preview: true);
      expect(
        (tile as TelegramWallpaper).patternLayout,
        const DesktopTiledPatternLayout(),
      );
      expect(tile.mode, ChatWallpaperAnimMode.off);

      // Телефон: общий построитель раскладку не передаёт — «по покрытию».
      late Widget phone;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              phone = buildChatWallpaperBackground(context, 'anim:aurora');
              return const SizedBox();
            },
          ),
        ),
      );
      expect((phone as TelegramWallpaper).patternLayout, isNull);
      expect(const TelegramWallpaper().patternLayout, isNull);
    });

    testWidgets('однотонные и «Классика» не тронуты', (t) async {
      expect(await build(t, 'midnight'), isA<ColoredBox>());
      expect(await build(t, 'default'), isA<DecoratedBox>());
    });
  });

  group('превью', () {
    test('вытянутая плитка — как есть, плоская — полоса окна 4:3', () {
      expect(desktopWallpaperPreviewHeight(const Size(124, 165)), 165);
      expect(desktopWallpaperPreviewHeight(const Size(92, 123)), 123);
      expect(desktopWallpaperPreviewHeight(const Size(250, 64)), 187.5);
    });

    testWidgets('плоская карточка набора рисует обои для окна 4:3', (t) async {
      Future<void> pumpTile(Size size) => t.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.fromSize(
              size: size,
              child: const DesktopWallpaperPreview(wallpaperId: 'midnight'),
            ),
          ),
        ),
      );
      await pumpTile(const Size(250, 64));
      expect(find.byType(OverflowBox), findsOneWidget);
      expect(
        t.getSize(find.descendant(
          of: find.byType(DesktopWallpaperPreview),
          matching: find.byType(ColoredBox),
        )).height,
        187.5,
      );
      await pumpTile(const Size(124, 165));
      expect(find.byType(OverflowBox), findsNothing);
    });
  });

  // 🔴 01.10.2026, владелец: «фоны генеративно расширяются, не растягиваются —
  // увеличивается количество узоров». В переписке плитка узора постоянного
  // размера: выше окно — больше рядов, а не крупнее дудлы.
  group('ряды: плитка постоянного размера', () {
    const image = Size(1080, 1920);
    test('масштаб не зависит от высоты окна', () {
      final scales = <double>{
        for (final h in const [420.0, 700.0, 900.0, 1300.0, 2100.0])
          desktopPatternTiling(
            area: Size(1200, h),
            image: image,
            tileHeight: kDesktopWallpaperTileHeight,
          ).scale,
      };
      expect(scales, {kDesktopWallpaperTileHeight / image.height});
    });

    test('ряды растут от низа: у поля ввода узор стоит на месте', () {
      for (final h in const [420.0, 900.0, 1300.0]) {
        final t = desktopPatternTiling(
          area: Size(1200, h),
          image: image,
          tileHeight: kDesktopWallpaperTileHeight,
        );
        expect(t.originY, h - kDesktopWallpaperTileHeight);
        final m = desktopPatternMatrix(t, Offset.zero);
        // Низ плитки — на низе области при любой высоте.
        expect(m[13] + image.height * t.scale, closeTo(h, 1e-9));
      }
    });

    test('без tileHeight — прежняя раскладка по высоте (плитки выбора)', () {
      final t = desktopPatternTiling(area: const Size(700, 320), image: image);
      expect(t.scale, 320 / image.height);
      expect(t.originY, 0);
    });

    test('живые обои и картинки в переписке идут рядами', () {
      final src = File(
        'lib/ui/desktop/chat/desktop_wallpaper_tiling.dart',
      ).readAsStringSync();
      expect(src.contains('tileHeight: kDesktopWallpaperTileHeight,'), isTrue);
      expect(src.contains('rowTileMode: kDesktopLiveWallpaperTileMode,'), isTrue);
      expect(
        src.contains('rowTileMode: preview ? TileMode.clamp : TileMode.mirror,'),
        isTrue,
      );
    });
  });
}
