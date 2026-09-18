// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/widgets/composer_glyph_morph.dart';

// Морф значка в кнопке композера (09.08.2026).
//
// Жалобы владельца: значки «меняются плоско», и кнопка при этом «меняет размер».
// Оба здесь и проверяются — второе важнее, потому что дёрганый размер видно даже
// краем глаза.

Widget host(Widget child, {double box = 23}) => MaterialApp(
  home: Scaffold(
    body: Center(child: ComposerGlyphMorph(box: box, child: child)),
  ),
);

Size morphSize(WidgetTester tester) =>
    tester.getSize(find.byType(ComposerGlyphMorph));

void main() {
  testWidgets('🔴 размер НЕ меняется, каким бы ни был значок', (tester) async {
    // Ровно та жалоба: «почему-то у нас кнопка меняет размер».
    await tester.pumpWidget(
      host(const Icon(Icons.mic, key: ValueKey<String>('mic'), size: 19)),
    );
    final before = morphSize(tester);
    expect(before, const Size(23, 23));

    // Подсовываем заведомо больший значок — раньше разница 18 против 20 сама по
    // себе двигала кнопку.
    await tester.pumpWidget(
      host(const Icon(Icons.videocam, key: ValueKey<String>('cam'), size: 64)),
    );
    // И на середине перехода, когда в дереве ОБА значка.
    await tester.pump(const Duration(milliseconds: 130));
    expect(morphSize(tester), before);

    await tester.pumpAndSettle();
    expect(morphSize(tester), before);
  });

  testWidgets('🔴 смена значка идёт переходом, а не рывком', (tester) async {
    await tester.pumpWidget(
      host(const Icon(Icons.mic, key: ValueKey<String>('mic'), size: 19)),
    );
    await tester.pumpWidget(
      host(const Icon(Icons.videocam, key: ValueKey<String>('cam'), size: 19)),
    );
    await tester.pump(const Duration(milliseconds: 120));

    // Оба значка на экране одновременно — значит уходящий ещё виден, то есть
    // переход есть. При рывке остался бы только новый.
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.videocam), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.videocam), findsOneWidget);
  });

  testWidgets('🔴 значок ПОВОРАЧИВАЕТСЯ и растёт, а не просто проявляется', (
    tester,
  ) async {
    // Иначе это обычное растворение, а просили превращение.
    await tester.pumpWidget(
      host(const Icon(Icons.mic, key: ValueKey<String>('mic'), size: 19)),
    );
    await tester.pumpWidget(
      host(const Icon(Icons.videocam, key: ValueKey<String>('cam'), size: 19)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final rotations = tester.widgetList<RotationTransition>(
      find.byType(RotationTransition),
    );
    expect(rotations, isNotEmpty);
    // Хотя бы один значок в этот момент повёрнут.
    expect(
      rotations.any((r) => r.turns.value.abs() > 0.001),
      isTrue,
      reason: 'на середине перехода поворота нет — это растворение',
    );

    final scales = tester.widgetList<ScaleTransition>(
      find.byType(ScaleTransition),
    );
    expect(scales.any((s) => s.scale.value < 0.999), isTrue);
  });

  testWidgets('🔴 масштаб никогда не перелетает за единицу', (tester) async {
    // Перелёт — это и была «кнопка меняет размер»: прежняя кривая easeOutBack
    // раздувала значок больше своего размера и осаживала обратно.
    await tester.pumpWidget(
      host(const Icon(Icons.mic, key: ValueKey<String>('mic'), size: 19)),
    );
    await tester.pumpWidget(
      host(const Icon(Icons.videocam, key: ValueKey<String>('cam'), size: 19)),
    );
    for (var ms = 0; ms <= 300; ms += 20) {
      await tester.pump(const Duration(milliseconds: 20));
      for (final s in tester.widgetList<ScaleTransition>(
        find.byType(ScaleTransition),
      )) {
        expect(
          s.scale.value,
          lessThanOrEqualTo(1.0001),
          reason: 'перелёт масштаба на $ms мс',
        );
      }
    }
  });

  testWidgets('одинаковый значок не запускает переход', (tester) async {
    // Иначе любая перерисовка композера крутила бы значок без повода.
    await tester.pumpWidget(
      host(const Icon(Icons.mic, key: ValueKey<String>('mic'), size: 19)),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      host(const Icon(Icons.mic, key: ValueKey<String>('mic'), size: 19)),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
