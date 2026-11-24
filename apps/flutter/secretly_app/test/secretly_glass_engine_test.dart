// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Движок SecretlyGlass (план стекла, 23.11.2026): уровни качества, шейдер и
// договор его параметров с пластиной.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/glass/glass_category_strip.dart';
import 'package:secretly_app/ui/glass/glass_quality.dart';
import 'package:secretly_app/ui/glass/secretly_glass_plate.dart';
import 'package:secretly_app/ui/widgets/frosted_header_island.dart';

void main() {
  test('уровни качества: температура и пропуски кадров', () {
    expect(
      glassQualityFor(thermalState: 0, framesDropping: false),
      GlassQuality.full,
    );
    expect(
      glassQualityFor(thermalState: 0, framesDropping: true),
      GlassQuality.balanced,
    );
    expect(
      glassQualityFor(thermalState: 1, framesDropping: false),
      GlassQuality.balanced,
    );
    expect(
      glassQualityFor(thermalState: 2, framesDropping: false),
      GlassQuality.edge,
    );
    expect(
      glassQualityFor(thermalState: 3, framesDropping: false),
      GlassQuality.flat,
    );
  });

  test('🔴 шейдер грузится, и параметров ровно 19 — как их пишет пластина', () async {
    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/secretly_glass.frag',
    );
    final shader = program.fragmentShader();
    // u_size 2, u_origin 2, u_plate 2, u_radius 1, u_thumb 4, u_lift 1,
    // u_dpr 1, u_quality 1, u_tint 4, u_sat 1 = 19.
    for (var i = 0; i < 19; i++) {
      shader.setFloat(i, 0);
    }
    expect(() => shader.setFloat(19, 0), throwsA(anything));
    shader.dispose();
  });

  test('тинт: тёмная и светлая тема', () {
    expect(RenderGlassBackdrop.tintFor(dark: true), hasLength(4));
    expect(RenderGlassBackdrop.tintFor(dark: false).first, 1.0);
  });

  testWidgets('без Impeller (проверки, Skia) — прежняя пластина', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassCategoryStrip(
            items: const [
              GlassStripItem(label: 'A'),
              GlassStripItem(label: 'B'),
            ],
            selected: 0,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await t.pump();
    expect(secretlyGlassEngineActive, isFalse);
    // 23.11.2026: полоса — пластина основных островков, не свой движок.
    expect(
      find.byType(SecretlyGlassPlate),
      kGlassStripUsesEngine ? findsOneWidget : findsNothing,
    );
    expect(find.byType(FrostedHeaderIsland), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('🔴 источники сдвига: прокрутка всех предков и переход экрана', (
    t,
  ) async {
    late BuildContext inner;
    final outer = ScrollController();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: outer,
            children: [
              const SizedBox(height: 300),
              SizedBox(
                height: 200,
                child: PageView(
                  children: [
                    Builder(
                      builder: (c) {
                        inner = c;
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final sources = repositionSourcesOf(inner);
    // Страница (PageView), список профиля и обе анимации маршрута.
    expect(sources, contains(outer.position));
    expect(sources.whereType<ScrollPosition>(), hasLength(2));
    final route = ModalRoute.of(inner)!;
    expect(sources, contains(route.animation));
    expect(sources, contains(route.secondaryAnimation));
  });

  test('🔴 прокрутка предка перерисовывает пластину (блик едет следом)', () async {
    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/secretly_glass.frag',
    );
    final moved = ChangeNotifier();
    final box = _CountingBackdrop(program.fragmentShader(), moved);
    box.attach(PipelineOwner());
    final before = box.repaints;
    moved.notifyListeners();
    moved.notifyListeners();
    expect(box.repaints - before, 2, reason: 'каждый сдвиг — перерисовка');
    box.detach();
    final detached = box.repaints;
    moved.notifyListeners();
    expect(box.repaints, detached, reason: 'отсоединена — не слушает');
    // Смена источника: старый больше не слушается.
    final other = ChangeNotifier();
    box.attach(PipelineOwner());
    box.reposition = other;
    final afterSwap = box.repaints;
    moved.notifyListeners();
    expect(box.repaints, afterSwap);
    other.notifyListeners();
    expect(box.repaints, afterSwap + 1);
    box.detach();
    box.dispose();
  });
}

class _CountingBackdrop extends RenderGlassBackdrop {
  _CountingBackdrop(ui.FragmentShader shader, Listenable moved)
    : super(
        shader: shader,
        radius: 20,
        quality: GlassQuality.full,
        dark: true,
        dpr: 3,
        thumb: null,
        lift: null,
        reposition: moved,
        thumbOffset: Offset.zero,
      );

  int repaints = 0;

  @override
  void markNeedsPaint() {
    repaints++;
    super.markNeedsPaint();
  }
}
