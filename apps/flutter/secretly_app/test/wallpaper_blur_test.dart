// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Тесты «матового стекла» входящих пузырей: WallpaperBlurController готовит
// одну крошечную размытую текстуру обоев на чат (Telegram-подход), пузыри
// рисуют в неё «окна». Здесь проверяем контроллер: размеры текстуры,
// дедупликацию по ключу, троттлинг анимированных кадров и матрицу насыщенности.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/wallpaper_blur.dart';

// Небольшой валидный PNG для проверки still-пайплайна (декод → блюр →
// мини-текстура) без бандл-ассетов: рисуем и кодируем прямо в тесте.
Future<Uint8List> makeTestPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 32, 32),
    ui.Paint()..color = const Color(0xFF336699),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(32, 32);
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

const _loop = <Offset>[
  Offset(0.18, 0.10),
  Offset(0.55, 0.06),
  Offset(0.86, 0.24),
  Offset(0.92, 0.60),
  Offset(0.80, 0.90),
  Offset(0.45, 0.94),
  Offset(0.12, 0.78),
  Offset(0.06, 0.40),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saturationColorMatrix(1.0) is identity', () {
    final m = saturationColorMatrix(1.0);
    const identity = <double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
    for (var i = 0; i < identity.length; i++) {
      expect(m[i], closeTo(identity[i], 1e-9), reason: 'index $i');
    }
  });

  test('wallpaperLoopAnchor interpolates along the loop', () {
    const size = Size(100, 200);
    // phase 0, blob 0 → ровно первый якорь петли.
    final a = wallpaperLoopAnchor(loop: _loop, phase: 0, blob: 0, size: size);
    expect(a.dx, closeTo(_loop[0].dx * size.width, 1e-9));
    expect(a.dy, closeTo(_loop[0].dy * size.height, 1e-9));
    // Середина между якорями 0 и 1.
    final b = wallpaperLoopAnchor(loop: _loop, phase: 0.5, blob: 0, size: size);
    expect(
      b.dx,
      closeTo((_loop[0].dx + _loop[1].dx) / 2 * size.width, 1e-9),
    );
    // blob-сдвиг = +2 шага петли.
    final c = wallpaperLoopAnchor(loop: _loop, phase: 0, blob: 1, size: size);
    expect(c.dx, closeTo(_loop[2].dx * size.width, 1e-9));
  });

  test('configureGradient builds a downscaled texture and dedups by key',
      () async {
    final controller = WallpaperBlurController();
    var notified = 0;
    controller.addListener(() => notified++);

    controller.configureGradient(
      cacheKey: 'solid:test',
      colors: const <Color>[Color(0xFF112233), Color(0xFF445566)],
      viewportSize: const Size(400, 800),
      devicePixelRatio: 2.0,
    );
    // Нотификация уходит микротаском.
    await Future<void>.delayed(Duration.zero);
    final texture = controller.texture;
    expect(texture, isNotNull);
    expect(notified, 1);
    // 400×2 / 16 = 50, 800×2 / 16 = 100.
    expect(texture!.width, 50);
    expect(texture.height, 100);

    // Повторный вызов с тем же ключом — no-op (та же текстура, без нотификаций).
    controller.configureGradient(
      cacheKey: 'solid:test',
      colors: const <Color>[Color(0xFF112233), Color(0xFF445566)],
      viewportSize: const Size(400, 800),
      devicePixelRatio: 2.0,
    );
    await Future<void>.delayed(Duration.zero);
    expect(identical(controller.texture, texture), isTrue);
    expect(notified, 1);

    controller.dispose();
  });

  test('animated frames render synthetically and skip repeated phases',
      () async {
    final controller = WallpaperBlurController();
    controller.configureAnimated(
      cacheKey: 'anim:test',
      viewportSize: const Size(400, 800),
      devicePixelRatio: 2.0,
    );
    const colors = <Color>[
      Color(0xFFD25F92),
      Color(0xFFD25F92),
      Color(0xFF5A55C8),
      Color(0xFF5A55C8),
    ];

    controller.pushAnimatedFrame(
      colors: colors,
      blobOpacity: 1.0,
      loop: _loop,
      phase: 0.0,
    );
    await Future<void>.delayed(Duration.zero);
    final first = controller.texture;
    expect(first, isNotNull);
    expect(first!.width, 50);

    // Та же фаза → кадр не перерисовывается.
    controller.pushAnimatedFrame(
      colors: colors,
      blobOpacity: 1.0,
      loop: _loop,
      phase: 0.0,
    );
    await Future<void>.delayed(Duration.zero);
    expect(identical(controller.texture, first), isTrue);

    controller.dispose();
  });

  testWidgets('configureStill decodes, blurs and swaps the texture',
      (tester) async {
    await tester.runAsync(() async {
      final controller = WallpaperBlurController();
      controller.configureStill(
        cacheKey: 'mem:test',
        provider: MemoryImage(await makeTestPng()),
        viewportSize: const Size(320, 640),
        devicePixelRatio: 3.0,
      );
      // Декод асинхронный — подождём реального завершения future.
      for (var i = 0; i < 50 && controller.texture == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final texture = controller.texture;
      expect(texture, isNotNull);
      // 320×3 / 16 = 60, 640×3 / 16 = 120.
      expect(texture!.width, 60);
      expect(texture.height, 120);
      controller.dispose();
    });
  });
}
