// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Оформление» v2 (20.11.2026): ползунки по умолчанию не меняют ни пикселя
// переписки, пузыри перестраиваются при движении ползунка, фон сохраняется,
// а переключатель стекла перестраивает ВСЁ дерево (раньше — только нижнюю
// панель, остальное оставалось прежним до случайной перестройки).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ui/app_backdrop.dart';
import 'package:secretly_app/ui/chat_look_prefs.dart';
import 'package:secretly_app/ui/liquid_glass_flags.dart';

class _Probe extends StatelessWidget {
  const _Probe(this.onBuild);
  final void Function(BuildContext) onBuild;
  @override
  Widget build(BuildContext context) {
    onBuild(context);
    return const SizedBox();
  }
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ChatLookPrefs.debugReset();
  });

  testWidgets('defaults equal the old hard-coded bubble look', (t) async {
    late BorderRadius me, them;
    late double font;
    await t.pumpWidget(
      ChatLookScope(
        child: _Probe((c) {
          me = chatBubbleRadius(c, true);
          them = chatBubbleRadius(c, false);
          font = chatMessageFontSize(c);
        }),
      ),
    );
    expect(font, 16);
    expect(
      me,
      const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(8),
      ),
    );
    expect(
      them,
      const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(20),
      ),
    );
  });

  testWidgets('bubbles rebuild when a slider moves, and only then', (t) async {
    var builds = 0;
    double? font;
    await t.pumpWidget(
      ChatLookScope(
        child: _Probe((c) {
          builds++;
          font = chatMessageFontSize(c);
        }),
      ),
    );
    expect(builds, 1);
    await ChatLookPrefs.setFontSize(19, persist: false);
    await t.pump();
    expect(builds, 2);
    expect(font, 19);
    // Небольшой радиус ограничивает и «хвост».
    await ChatLookPrefs.setRadius(4, persist: false);
    await t.pump();
    final r = chatBubbleRadius(t.element(find.byType(_Probe)), true);
    expect(r.bottomRight, const Radius.circular(4));
    // Значения вне диапазона не принимаются.
    await ChatLookPrefs.setFontSize(99);
    expect(ChatLookPrefs.fontSize.value, ChatLookPrefs.maxFontSize);
  });

  test('slider values persist on release and reset clears them', () async {
    await ChatLookPrefs.setFontSize(18);
    await ChatLookPrefs.setRadius(12);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(ChatLookPrefs.fontSizeKey), 18);
    ChatLookPrefs.debugReset();
    await ChatLookPrefs.load();
    expect(ChatLookPrefs.radius.value, 12);
    await ChatLookPrefs.reset();
    expect(prefs.getDouble(ChatLookPrefs.radiusKey), isNull);
    expect(ChatLookPrefs.fontSize.value, ChatLookPrefs.defaultFontSize);
  });

  testWidgets('glass switch rebuilds widgets that only read the flag', (
    t,
  ) async {
    var builds = 0;
    // const-родитель: именно так `main.dart` держал приложение, и именно
    // поэтому островки не узнавали о переключении.
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _Probe((_) => builds++),
      ),
    );
    expect(builds, 1);
    await GlassPrefs.setEnabled(!GlassPrefs.enabled.value);
    await t.pump();
    expect(builds, 2);
    await GlassPrefs.setEnabled(!GlassPrefs.enabled.value);
  });

  test('choosing light or dark by hand turns Auto off', () async {
    final c = AppController();
    await c.setFollowSystemTheme(true);
    expect(c.followSystemTheme, isTrue);
    await c.setDarkModeByUser(!c.darkMode);
    expect(c.followSystemTheme, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('follow_system_theme_v1'), isFalse);
  });

  testWidgets('switching the background keeps the state below it', (t) async {
    final key = GlobalKey<_CounterState>();
    Widget host(AppBackdropPreset? p) => Directionality(
      textDirection: TextDirection.ltr,
      child: AppBackdropLayer(preset: p, dark: true, child: _Counter(key: key)),
    );
    await t.pumpWidget(host(null));
    key.currentState!.value = 7;
    await t.pumpWidget(host(kAppBackdropPresets.first));
    expect(key.currentState?.value, 7);
    await t.pumpWidget(host(null));
    expect(key.currentState?.value, 7);
  });

  test('background choice persists; unknown ids fall back to theme', () async {
    final c = AppController();
    expect(c.appBackdropId, kAppBackdropTheme);
    await c.setAppBackdropId('ocean');
    expect(c.appBackdropId, 'ocean');
    await c.setAppBackdropId('not-a-backdrop');
    expect(c.appBackdropId, 'ocean');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_backdrop_v1'), 'ocean');
    await c.setAppBackdropId(kAppBackdropTheme);
    expect(prefs.getString('app_backdrop_v1'), isNull);
    expect(resolveAppBackdrop(kAppBackdropTheme), isNull);
    expect(kAppBackdropPresets.length, 9);
  });
}
