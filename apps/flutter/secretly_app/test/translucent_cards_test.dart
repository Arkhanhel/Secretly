// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Настройка «Прозрачные плашки» (23.11.2026).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/apple_glass.dart';
import 'package:secretly_app/ui/profile/profile_motion.dart';
import 'package:secretly_app/ui/widgets/app_background.dart';
import 'package:secretly_app/ui/widgets/island_backdrop.dart';

const _cardBg = Color(0xFF26282E);
const _surface = Color(0xFF141821);
const _page = Color(0xFF000000);

Future<BuildContext> _ctx(WidgetTester t) async {
  late BuildContext ctx;
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(surface: _surface),
        cardTheme: const CardThemeData(color: _cardBg),
      ),
      home: AppBackground(
        gradient: const LinearGradient(colors: [_page, _page]),
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return ctx;
}

void main() {
  tearDown(() => PanelPrefs.translucentCards.value = true);

  testWidgets('включено — прозрачная панель с тонкой кромкой', (t) async {
    PanelPrefs.translucentCards.value = true;
    final d = panelDecoration(await _ctx(t));
    expect(d.color, AppleGlass.fill(true));
    expect(d.color!.a, lessThan(0.2), reason: 'просвечивает');
    expect(d.shape, isA<AppleGlassBorder>());
  });

  testWidgets('🔴 выключено — плотная плашка, чуть светлее прежнего профиля', (
    t,
  ) async {
    PanelPrefs.translucentCards.value = false;
    final ctx = await _ctx(t);
    final d = panelDecoration(ctx);
    final want = Color.lerp(_page, _surface, kOpaquePanelLift)!;
    expect(d.color, want);
    expect(d.color!.a, 1.0, reason: 'не просвечивает');
    // Прежний профиль — середина пути от фона к поверхности; теперь светлее,
    // но всё ещё ближе к фону, чем к поверхности («не выделяется»).
    final oldProfile = Color.lerp(_page, _surface, 0.5)!;
    expect(want.computeLuminance(), greaterThan(oldProfile.computeLuminance()));
    expect(kOpaquePanelLift, inInclusiveRange(0.55, 0.7));
    final shape = d.shape as RoundedRectangleBorder;
    expect(
      (shape.borderRadius as BorderRadius).topLeft.x,
      18,
      reason: 'скругление карточек своего профиля',
    );
    // Заливка плашек, заданных вручную, — тот же цвет.
    expect(appleGlassFillOr(ctx, Colors.red), want);
    // И карточки своего профиля — тот же цвет, что настройки и всё прочее.
    expect(profileCardTheme(ctx).cardTheme.color, want);
  });

  testWidgets('включено — профиль не перекрашивает карточки (прозрачные)', (
    t,
  ) async {
    PanelPrefs.translucentCards.value = true;
    final ctx = await _ctx(t);
    expect(
      profileCardTheme(ctx).cardTheme.color,
      Theme.of(ctx).cardTheme.color,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('выключено — в нижнем листе плашка светлее листа, не «дыра»', (
    t,
  ) async {
    PanelPrefs.translucentCards.value = false;
    final ctx = await _ctx(t);
    late BuildContext sheetCtx;
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: const Color(0xFF1C1C1F),
      builder: (c) {
        sheetCtx = c;
        return const SizedBox(height: 100);
      },
    );
    await t.pumpAndSettle();
    final inSheet = opaqueCardColor(sheetCtx);
    final onPage = opaqueCardColor(ctx);
    expect(inSheet.a, 1.0);
    expect(
      inSheet.computeLuminance(),
      greaterThan(onPage.computeLuminance()),
      reason: 'в листе плашка не темнее листа',
    );
  });

  testWidgets('плашка поверх ленты на Android остаётся прежней', (t) async {
    final ctx = await _ctx(t);
    expect(
      appleGlassFillOr(ctx, Colors.red, androidToo: false),
      Colors.red,
    );
    expect(appleGlassFillOr(ctx, Colors.red), isNot(Colors.red));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
