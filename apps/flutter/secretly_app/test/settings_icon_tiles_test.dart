// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secretly_app/ui/settings_icons/settings_glyph_tile.dart';
import 'package:secretly_app/ui/settings_icons/settings_glyphs.dart';
import 'package:secretly_app/ui/settings_icons/settings_icon_style.dart';

/// Все знаки во всех стилях рисуются без ошибок, а выбор стиля
/// сохраняется и читается обратно.
///
/// `SECRETLY_ICON_SHEET=/путь/лист.png flutter test test/settings_icon_tiles_test.dart`
/// дополнительно сохраняет лист всех плиток — для сверки с макетом.
void main() {
  testWidgets('every glyph paints in every style, light and dark', (
    tester,
  ) async {
    final key = GlobalKey();
    Widget sheet(Brightness b) => Container(
      color: b == Brightness.dark
          ? const Color(0xFF0E1320)
          : const Color(0xFFF2F2F7),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final style in SettingsIconStyle.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final g in SettingsGlyph.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: SettingsGlyphTile(
                        glyph: g,
                        style: style,
                        size: 40,
                        brightness: b,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    tester.view.physicalSize = const Size(1800, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: RepaintBoundary(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [sheet(Brightness.light), sheet(Brightness.dark)],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byType(SettingsGlyphTile),
      findsNWidgets(SettingsIconStyle.values.length * SettingsGlyph.values.length * 2),
    );

    final out = Platform.environment['SECRETLY_ICON_SHEET'];
    if (out != null && out.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ImageByteFormat.png);
        File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });

  test('style choice persists and unknown values fall back', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsIconStylePrefs.prefsKey: 'neon',
    });
    SettingsIconStylePrefs.debugReset();
    await SettingsIconStylePrefs.load();
    expect(SettingsIconStylePrefs.style.value, SettingsIconStyle.neon);

    await SettingsIconStylePrefs.set(SettingsIconStyle.clay);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SettingsIconStylePrefs.prefsKey), 'clay');

    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsIconStylePrefs.prefsKey: 'something-from-a-newer-build',
    });
    SettingsIconStylePrefs.debugReset();
    await SettingsIconStylePrefs.load();
    expect(
      SettingsIconStylePrefs.style.value,
      SettingsIconStylePrefs.platformDefault,
    );
  });
}
