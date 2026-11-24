// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Окно эмодзи-статуса (23.11.2026): полоса разделов во всю ширину; переход
// к ДАЛЬНЕМУ разделу (сетка ленивая — раньше молча не срабатывал); капля
// показывает раздел, видимый в сетке.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/emoji/emoji_status_picker.dart';
import 'package:secretly_app/ui/glass/glass_category_strip.dart';

void main() {
  testWidgets('нажатие на последний раздел листает к нему, капля там же', (
    t,
  ) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(showEmojiStatusPicker(ctx));
    await t.pumpAndSettle();
    final strip = t.widget<GlassCategoryStrip>(find.byType(GlassCategoryStrip));
    expect(strip.selected, 0);
    final last = strip.items.length - 1;
    strip.onSelect(last);
    await t.pumpAndSettle();
    final grid = t.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(grid.position.pixels, greaterThan(1000), reason: 'долистал вниз');
    final after = t.widget<GlassCategoryStrip>(find.byType(GlassCategoryStrip));
    expect(after.selected, greaterThanOrEqualTo(last - 1));
    expect(t.takeException(), isNull);
  });
}
