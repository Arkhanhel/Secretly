// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/full_bleed_zoom.dart';

/// 🔴 «Увеличивается только внутри своей коробки» (полевой отчёт 02.08.2026).
///
/// `InteractiveViewer` обрезает по СВОЕМУ размеру. Пока он был размером с кадр,
/// горизонтальное фото на вертикальном экране увеличивалось внутри узкой полосы
/// посередине, а чёрные поля сверху и снизу так и оставались чёрными.
///
/// Проверяется именно РАЗМЕР ОБЛАСТИ ЗУМА — на глаз эту разницу видно, а вот
/// поймать её иначе, чем измерением, нечем: сама картинка в обоих случаях
/// нарисована одинаково, отличается только то, куда ей разрешено расти.
void main() {
  /// Экран телефона (вертикальный) и заведомо горизонтальный кадр 16:9 —
  /// худший случай, ровно тот, на который пожаловались.
  // Влезает в тестовую поверхность 800x600 — иначе Center обрежет высоту и
  // измерение станет бессмысленным.
  const screen = Size(360, 560);

  Future<void> pumpIn(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: screen.width, height: screen.height, child: child),
        ),
      ),
    );
  }

  Widget landscapeFrame() => Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(color: const Color(0xFF224466)),
        ),
      );

  /// 🔴 ТАК БЫЛО. Оставлено как измерение дефекта: область зума ужималась до
  /// самого кадра, поэтому расти было некуда.
  testWidgets('🔴 старая схема ужимала область зума до кадра', (tester) async {
    await pumpIn(
      tester,
      Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(color: const Color(0xFF224466)),
          ),
        ),
      ),
    );
    final zoomArea = tester.getSize(find.byType(InteractiveViewer));
    expect(zoomArea.width, screen.width);
    expect(zoomArea.height, closeTo(screen.width * 9 / 16, 0.5),
        reason: 'область зума была высотой всего в кадр, а не во весь экран');
    expect(zoomArea.height, lessThan(screen.height / 2));
  });

  /// 🔴 ТАК СТАЛО: увеличивать можно во весь экран.
  testWidgets('🔴 область зума занимает весь экран', (tester) async {
    await pumpIn(tester, FullBleedZoom(child: landscapeFrame()));
    expect(tester.getSize(find.byType(InteractiveViewer)), screen);
  });

  /// Кадр при этом НЕ растягивается: его пропорции остаются 16:9, он просто
  /// центрирован в полноэкранной области зума.
  testWidgets('кадр вписан по ширине и не растянут', (tester) async {
    await pumpIn(tester, FullBleedZoom(child: landscapeFrame()));
    final frame = tester.getSize(find.byType(AspectRatio));
    expect(frame.width, screen.width, reason: 'вписан по всей ширине экрана');
    expect(frame.height, closeTo(screen.width * 9 / 16, 0.5),
        reason: 'высота выведена из пропорций, а не подогнана под экран');
  });

  /// Фото передаётся напрямую как `fit: BoxFit.contain` и получает ЖЁСТКИЕ
  /// размеры во весь прямоугольник — именно поэтому небольшой снимок теперь
  /// открывается во всю ширину, а не марочкой посередине.
  testWidgets('фото получает весь прямоугольник, а contain вписывает его',
      (tester) async {
    await pumpIn(
      tester,
      const FullBleedZoom(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(width: 1600, height: 900),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FittedBox)), screen,
        reason: 'у слоя с contain должен быть весь экран, чтобы было куда расти');
  });

  /// Вертикальный кадр вписывается по высоте — растягивать его по ширине было
  /// бы искажением, а этого просили НЕ делать.
  testWidgets('вертикальный кадр вписан по высоте, без растягивания',
      (tester) async {
    await pumpIn(
      tester,
      FullBleedZoom(
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 21,
            child: Container(color: const Color(0xFF224466)),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(InteractiveViewer)), screen);
    final frame = tester.getSize(find.byType(AspectRatio));
    expect(frame.height, screen.height);
    expect(frame.width, closeTo(screen.height * 9 / 21, 0.5));
    expect(frame.width, lessThan(screen.width));
  });
}
