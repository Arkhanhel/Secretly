// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ◆ «Свой цвет» акцента — пятая плитка полосы оформления.
//
// ЧТО БЫЛО. В полосе стояли одиннадцать готовых схем, и всё. Макет обещает
// двенадцатую плитку — пунктирный квадрат с пипеткой: цвет, которого в списке
// нет. ТЗ откладывало её с оговоркой «требует нового поля в AppController и
// правил генерации палитры из одного цвета».
//
// Оговорка оказалась о другой задаче. Окну от схемы нужны РОВНО ДВА цвета —
// акцент и его пара, — а `AppThemePreset` несёт два десятка, включая подложки
// и градиент шапки. Выводить их все из одного цвета значило бы придумать
// телефону внешний вид, которого никто не выбирал; выводить два — обычная
// арифметика по кругу цветов.
//
// Поэтому цвет живёт в настройках ОКНА, а не в общем контроллере. Вторая
// причина та же по духу: в `appThemePresetId` лежит ИМЯ схемы из списка, и
// произвольный цвет там не пройдёт проверку `isValidAppThemePresetId` —
// телефон, разворачивая резервную копию, молча откатился бы на схему по
// умолчанию, и человек нашёл бы свой цвет пропавшим без объяснения.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/theme_bridge.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/accent_color_picker.dart';

Widget host(Widget child) => MaterialApp(
  home: DColors(colors: kDColorsDark, child: Scaffold(body: child)),
);

void main() {
  group('пара цветов из одного', () {
    test('◆ второй цвет — тот же тон, повёрнутый и поднятый к свету', () {
      const base = Color(0xFF3E8BF5);
      final alt = desktopAccentAlt(base);
      final a = HSVColor.fromColor(base);
      final b = HSVColor.fromColor(alt);
      expect(b.hue, closeTo((a.hue + 16) % 360, 1.5));
      expect(b.value, greaterThan(a.value));
      expect(b.saturation, lessThan(a.saturation));
    });

    test('поворот не выпадает за круг', () {
      // 350° + 16° — это 6°, а не 366°: иначе `withHue` бросит.
      final alt = desktopAccentAlt(
        HSVColor.fromAHSV(1, 350, 0.8, 0.8).toColor(),
      );
      expect(HSVColor.fromColor(alt).hue, closeTo(6, 1.5));
    });

    test('у белого поднимать некуда — и это не ломается', () {
      final alt = desktopAccentAlt(const Color(0xFFFFFFFF));
      expect(HSVColor.fromColor(alt).value, closeTo(1.0, 0.01));
    });
  });

  group('🔴 акцент остаётся видимым на подложке', () {
    test('почти чёрный на тёмной схеме поднимается до порога', () {
      final fixed = legibleAccent(const Color(0xFF0A0F14), dark: true);
      expect(HSVColor.fromColor(fixed).value, closeTo(0.45, 0.01));
    });

    test('слепяще светлый на светлой схеме приглушается', () {
      final fixed = legibleAccent(const Color(0xFFFFFFFF), dark: false);
      expect(HSVColor.fromColor(fixed).value, closeTo(0.90, 0.01));
    });

    test('двигается ТОЛЬКО яркость: «мой зелёный» остаётся зелёным', () {
      const green = Color(0xFF0B2A12);
      final fixed = legibleAccent(green, dark: true);
      final a = HSVColor.fromColor(green);
      final b = HSVColor.fromColor(fixed);
      expect(b.hue, closeTo(a.hue, 1.0));
      expect(b.saturation, closeTo(a.saturation, 0.02));
    });

    test('цвет внутри полосы не трогают вовсе', () {
      const ok = Color(0xFF3E8BF5);
      expect(legibleAccent(ok, dark: true), ok);
    });

    test('поле выбора нарисовано по тем же границам, что и подгонка', () {
      // Иначе в окне выбора был бы цвет, которого в окне не будет.
      expect(accentValueBand(dark: true).min, 0.45);
      expect(accentValueBand(dark: false).max, 0.90);
    });
  });

  group('свой цвет в палитре окна', () {
    test('◆ встаёт на место пары из схемы', () {
      const custom = Color(0xFFE0533C);
      final set = applyThemePreset(
        kDColorsDark,
        'ocean',
        customAccent: custom,
      );
      expect(set.accentPrimary, custom);
      expect(set.accentPrimaryAlt, desktopAccentAlt(custom));
    });

    test('без своего цвета всё как было — пара из схемы', () {
      final a = applyThemePreset(kDColorsDark, 'ocean');
      final b = applyThemePreset(kDColorsDark, 'ocean', customAccent: null);
      expect(a.accentPrimary, b.accentPrimary);
      expect(a.accentPrimaryAlt, b.accentPrimaryAlt);
    });

    test('🔴 счётчики непрочитанного своему цвету НЕ подчиняются', () {
      // Тема меняет настроение окна, а «тут не прочитано» — это сигнал.
      final set = applyThemePreset(
        kDColorsDark,
        'ocean',
        customAccent: const Color(0xFFE0533C),
      );
      expect(set.unreadDot, kDColorsDark.unreadDot);
      expect(set.unreadRoom, kDColorsDark.unreadRoom);
      expect(set.unreadRail, kDColorsDark.unreadRail);
    });

    test('выделение и подсветка упоминания идут за своим цветом', () {
      const custom = Color(0xFFE0533C);
      final set = applyThemePreset(
        kDColorsDark,
        'ocean',
        customAccent: custom,
      );
      expect(set.selected, custom.withValues(alpha: 0.16));
      expect(set.mentionBg, custom.withValues(alpha: 0.18));
    });

    test('на светлой схеме подгонка идёт по светлым границам', () {
      final set = applyThemePreset(
        kDColorsLight,
        'ocean',
        dark: false,
        customAccent: const Color(0xFFFFFFFF),
      );
      expect(HSVColor.fromColor(set.accentPrimary).value, closeTo(0.90, 0.01));
    });
  });

  group('настройка десктопная', () {
    setUp(DesktopUiPrefs.resetForTest);

    test('ноль означает «цвета нет»', () async {
      await DesktopUiPrefs.setCustomAccent(0);
      expect(DesktopUiPrefs.customAccentArgb.value, 0);
    });

    test('прозрачный цвет — это невидимая кнопка: непрозрачность вернут', () {
      DesktopUiPrefs.setCustomAccent(0x00E0533C);
      expect(DesktopUiPrefs.customAccentArgb.value, 0xFFE0533C);
    });

    test('🔴 в общий контроллер не пишем', () {
      final src = File(
        'lib/ui/desktop/services/desktop_ui_prefs.dart',
      ).readAsStringSync();
      // Ключ десктопный, как и все соседние.
      expect(src.contains("'desktop_custom_accent_v1'"), isTrue);
      final app = File('lib/app/app_controller.dart').readAsStringSync();
      expect(app.contains('customAccent'), isFalse);
    });
  });

  group('окно выбора', () {
    testWidgets('«Отмена» не возвращает ничего', (t) async {
      int? out = -1;
      await t.pumpWidget(
        host(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                out = await showAccentColorPicker(
                  ctx,
                  initial: const Color(0xFF3E8BF5),
                  dark: true,
                );
              },
              child: const Text('открыть'),
            ),
          ),
        ),
      );
      await t.tap(find.text('открыть'));
      await t.pumpAndSettle();
      expect(find.text('Свой цвет'), findsOneWidget);

      await t.tap(find.text('Отмена'));
      await t.pumpAndSettle();
      expect(out, isNull);
    });

    testWidgets('«Применить» возвращает непрозрачный цвет', (t) async {
      int? out;
      await t.pumpWidget(
        host(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                out = await showAccentColorPicker(
                  ctx,
                  initial: const Color(0xFF3E8BF5),
                  dark: true,
                );
              },
              child: const Text('открыть'),
            ),
          ),
        ),
      );
      await t.tap(find.text('открыть'));
      await t.pumpAndSettle();
      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      expect(out, 0xFF3E8BF5);
    });

    // 🔴 НАЙДЕНО НА ЖИВОМ ОКНЕ: щелчок по полю не делал ничего.
    //
    // `onPanDown` срабатывает не в момент нажатия, а когда протяжка выиграла
    // спор жестов — то есть после сдвига дальше порога. Щелчок без движения
    // распознаватель протяжки отклоняет сам. А по цветовому полю именно
    // щёлкают: попал глазами — нажал.
    testWidgets('🔴 ОДИН ЩЕЛЧОК по полю уже меняет цвет', (t) async {
      int? out;
      await t.pumpWidget(
        host(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                out = await showAccentColorPicker(
                  ctx,
                  initial: const Color(0xFF3E8BF5),
                  dark: true,
                );
              },
              child: const Text('открыть'),
            ),
          ),
        ),
      );
      await t.tap(find.text('открыть'));
      await t.pumpAndSettle();
      final before = _hexText(t);

      final field = t.getRect(find.byKey(const ValueKey('accentSvField')));
      await t.tapAt(Offset(field.left + 12, field.bottom - 12));
      await t.pumpAndSettle();
      expect(_hexText(t), isNot(before));

      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      expect(out, isNot(0xFF3E8BF5));
    });

    testWidgets('🔴 щелчок по полосе тона тоже слышен', (t) async {
      await t.pumpWidget(
        host(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showAccentColorPicker(
                ctx,
                initial: const Color(0xFF3E8BF5),
                dark: true,
              ),
              child: const Text('открыть'),
            ),
          ),
        ),
      );
      await t.tap(find.text('открыть'));
      await t.pumpAndSettle();
      final before = _hexText(t);

      final bar = t.getRect(find.byKey(const ValueKey('accentHueBar')));
      await t.tapAt(Offset(bar.left + 4, bar.center.dy));
      await t.pumpAndSettle();
      expect(_hexText(t), isNot(before));
    });

    testWidgets('🔴 движение по полю меняет цвет, а не только картинку', (
      t,
    ) async {
      int? out;
      await t.pumpWidget(
        host(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                out = await showAccentColorPicker(
                  ctx,
                  initial: const Color(0xFF3E8BF5),
                  dark: true,
                );
              },
              child: const Text('открыть'),
            ),
          ),
        ),
      );
      await t.tap(find.text('открыть'));
      await t.pumpAndSettle();
      final hexBefore = _hexText(t);

      // Тянем по полосе тона влево — к красному краю.
      final rect = t.getRect(find.byKey(const ValueKey('accentHueBar')));
      await t.dragFrom(rect.center, Offset(-rect.width / 2 + 2, 0));
      await t.pumpAndSettle();
      expect(_hexText(t), isNot(hexBefore));

      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      expect(out, isNotNull);
      expect(out! >> 24 & 0xFF, 0xFF, reason: 'цвет непрозрачный');
      expect(out, isNot(0xFF3E8BF5), reason: 'выбор доехал до результата');
    });
  });

  group('плитка в полосе', () {
    final src = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();

    test('◆ пунктир и пипетка — по макету', () {
      // 36×36, radius 12, border 1.5px dashed rgba(255,255,255,.18),
      // значок 18px.
      expect(src.contains('strokeWidth = 1.5'), isTrue);
      expect(
        src.contains('color: Colors.white.withValues(alpha: 0.18),\n'
            '                    radius: 12,'),
        isTrue,
      );
      expect(src.contains('FluentIcons.eyedropper_24_regular'), isTrue);
    });

    test('🔴 нажатие по схеме снимает свой цвет', () {
      // Иначе плитка схемы выглядела бы выбранной, а окно оставалось бы
      // прежнего цвета — выбор без последствий.
      final i = src.indexOf('Future<void> _selectPreset(');
      final body = src.substring(i, (i + 600).clamp(0, src.length));
      expect(body.contains('DesktopUiPrefs.setCustomAccent(0)'), isTrue);
    });

    test('пока свой цвет выбран, ни одна схема не отмечена', () {
      expect(src.contains('selected: custom == 0 && preset.id =='), isTrue);
    });
  });

  test('🔴 корень подписан на свой цвет отдельно от тика контроллера', () {
    // Настройка живёт не в контроллере, и `changed` о ней не знает: без
    // подписки цвет применялся бы только после перезапуска окна.
    final src = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    expect(
      src.contains('valueListenable: DesktopUiPrefs.customAccentArgb'),
      isTrue,
    );
    expect(src.contains('customAccent: DesktopUiPrefs.customAccentArgb'), isTrue);
  });
}

String _hexText(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '')
    .firstWhere((s) => s.startsWith('#'));
