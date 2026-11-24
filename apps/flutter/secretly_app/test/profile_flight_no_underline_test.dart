// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Буквы летящего аватара без жёлтых полосок (23.11.2026).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/profile/profile_motion.dart';

void main() {
  testWidgets('🔴 буквы мини-аватара вне Material — без подчёркивания', (
    t,
  ) async {
    // Как в слое полёта: над Scaffold, без Material и без стиля текста.
    await t.pumpWidget(
      Theme(
        data: ThemeData.dark(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.square(
              dimension: 60,
              child: ProfileMiniPhoto(path: null, seed: 'X', name: 'Тестеры'),
            ),
          ),
        ),
      ),
    );
    final rich = t.widget<RichText>(find.byType(RichText));
    final decoration = rich.text.style?.decoration;
    expect(
      decoration == null || decoration == TextDecoration.none,
      isTrue,
      reason: 'запасной стиль Flutter рисует двойное жёлтое подчёркивание',
    );
  });
}
