// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 «ВНЕШНИЙ ВИД» ПО МАКЕТУ ВЛАДЕЛЬЦА (29.09.2026).
//
// Владелец: «сделай страницы настроек в таком стиле… подключи все настройки
// грамотно и профессионально». Здесь проверяется не вид, а ПОСЛЕДСТВИЯ: что
// каждая новая настройка сохраняется, доходит до ленты переписки и что
// готовые наборы и «По умолчанию» ставят ровно то, что обещают. Настройка,
// которая сохраняется, но ничего не меняет, — худшее, что может быть в
// настройках (правило P-5 окна).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/entitlements/cosmetic_catalog.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/chat_wallpapers.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/chat/bubble_look.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_wallpaper_picker.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/tokens.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/appearance_pane.dart';
import 'package:secretly_app/ui/desktop/workspace/appearance_preview.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_style.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:secretly_app/ui/theme_presets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(colors: kDColorsDark, child: Scaffold(body: child)),
);

MessageData _msg(String id, String text, {bool self = false}) => MessageData(
  id: id,
  payloadId: id,
  authorName: self ? 'Вы' : 'Пётр',
  authorSeed: self ? null : 'dev-petr',
  text: text,
  time: '12:00',
  isSelf: self,
);

Future<void> _pumpThread(WidgetTester t, {String nickname = 'accent'}) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    _app(
      ChatThreadPanel(
        header: const ChatHeader(name: 'Комната'),
        isDirect: false,
        wallpaperId: 'midnight',
        nicknameStylePresetId: nickname,
        messages: [
          _msg('m1', 'привет от Петра'),
          _msg('m2', 'мой ответ', self: true),
        ],
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 400));
}

/// Скругление своего пузыря — у контейнера с формой пузыря.
BorderRadius? _selfBubbleRadius(WidgetTester t) {
  final containers = t.widgetList<Container>(
    find.descendant(
      of: find.ancestor(
        of: find.textContaining('мой ответ'),
        matching: find.byType(MessageBubble),
      ),
      matching: find.byType(Container),
    ),
  );
  for (final c in containers) {
    final d = c.decoration;
    if (d is BoxDecoration && d.borderRadius is BorderRadius) {
      return d.borderRadius! as BorderRadius;
    }
  }
  return null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
  });

  group('настройки окна: плотность, форма, затемнение, цвет имён', () {
    test('по умолчанию — ровно прежний вид', () {
      expect(DesktopUiPrefs.messageDensity.value, 'cozy');
      expect(DesktopUiPrefs.bubbleShape.value, 'medium');
      expect(DesktopUiPrefs.wallpaperDim.value, 0);
      expect(DesktopUiPrefs.senderNameColors.value, 'person');
    });

    test('мусор в значениях не ломает окно', () async {
      await DesktopUiPrefs.setMessageDensity('огромная');
      await DesktopUiPrefs.setBubbleShape('треугольные');
      await DesktopUiPrefs.setSenderNameColors('?');
      expect(DesktopUiPrefs.messageDensity.value, 'cozy');
      expect(DesktopUiPrefs.bubbleShape.value, 'medium');
      expect(DesktopUiPrefs.senderNameColors.value, 'person');
      // Затемнение — шагом 5 и не больше 70: полностью чёрные обои — это
      // «без обоев», а не ползунок до упора.
      expect(DesktopUiPrefs.normalizeWallpaperDim(33), 35);
      expect(DesktopUiPrefs.normalizeWallpaperDim(-10), 0);
      expect(DesktopUiPrefs.normalizeWallpaperDim(500), 70);
      expect(DesktopUiPrefs.normalizeWallpaperDim(double.nan), 0);
    });

    test('🔴 выбор переживает перезапуск', () async {
      await DesktopUiPrefs.setMessageDensity('compact');
      await DesktopUiPrefs.setBubbleShape('round');
      await DesktopUiPrefs.setWallpaperDim(40);
      await DesktopUiPrefs.setSenderNameColors('preset');
      DesktopUiPrefs.resetForTest();
      expect(DesktopUiPrefs.bubbleShape.value, 'medium');
      await DesktopUiPrefs.load();
      expect(DesktopUiPrefs.messageDensity.value, 'compact');
      expect(DesktopUiPrefs.bubbleShape.value, 'round');
      expect(DesktopUiPrefs.wallpaperDim.value, 40);
      expect(DesktopUiPrefs.senderNameColors.value, 'preset');
    });

    test('🔴 ключи — десктопные: общий контроллер телефона не трогаем', () {
      final src = File(
        'lib/ui/desktop/services/desktop_ui_prefs.dart',
      ).readAsStringSync();
      for (final key in [
        'desktop_message_density_v1',
        'desktop_bubble_shape_v1',
        'desktop_wallpaper_dim_v1',
        'desktop_sender_name_colors_v1',
      ]) {
        expect(src.contains("'$key'"), isTrue, reason: key);
      }
      final ctl = File('lib/app/app_controller.dart').readAsStringSync();
      expect(ctl.contains('messageDensity'), isFalse);
      expect(ctl.contains('bubbleShape'), isFalse);
    });
  });

  group('форма и плотность пузыря', () {
    test('🔴 «Средние» и «Уютная» — ровно прежние числа', () {
      // Тем, кто ничего не выбирал, лента не должна сдвинуться ни на точку.
      final medium = DesktopBubbleLook.radiiFor('medium');
      expect(medium.main, DRadii.r16);
      expect(medium.tail, DRadii.sm);
      const cozy = DesktopBubbleLook(child: SizedBox.shrink());
      expect(cozy.gapAbove(continuation: false), DSpace.m);
      expect(cozy.gapAbove(continuation: true), 2);
      expect(cozy.textPadding, const EdgeInsets.fromLTRB(13, 10, 13, 8));
    });

    test('острые острее, круглые круглее; плотная — теснее', () {
      final sharp = DesktopBubbleLook.radiiFor('sharp');
      final round = DesktopBubbleLook.radiiFor('round');
      expect(sharp.main, lessThan(DRadii.r16));
      expect(round.main, greaterThan(DRadii.r16));
      const compact = DesktopBubbleLook(compact: true, child: SizedBox.shrink());
      expect(compact.gapAbove(continuation: false), lessThan(DSpace.m));
      expect(compact.textPadding.vertical, lessThan(18));
    });

    testWidgets('🔴 форма доходит до ленты и меняется сразу', (t) async {
      await _pumpThread(t);
      expect(_selfBubbleRadius(t)?.topLeft, const Radius.circular(DRadii.r16));
      await DesktopUiPrefs.setBubbleShape('round');
      await t.pump();
      expect(
        _selfBubbleRadius(t)?.topLeft,
        Radius.circular(DesktopBubbleLook.radiiFor('round').main),
      );
      await DesktopUiPrefs.setBubbleShape('sharp');
      await t.pump();
      expect(
        _selfBubbleRadius(t)?.topLeft,
        Radius.circular(DesktopBubbleLook.radiiFor('sharp').main),
      );
    });

    testWidgets('🔴 плотная лента — пузыри ближе друг к другу', (t) async {
      await _pumpThread(t);
      double gap() =>
          t.getTopLeft(find.textContaining('мой ответ')).dy -
          t.getBottomLeft(find.textContaining('привет от Петра')).dy;
      final cozy = gap();
      await DesktopUiPrefs.setMessageDensity('compact');
      await t.pump();
      expect(gap(), lessThan(cozy));
    });
  });

  group('затемнение обоев', () {
    testWidgets('🔴 ползунок доходит до ленты: 0 — слоя нет', (t) async {
      await _pumpThread(t);
      expect(find.byKey(const ValueKey('wallpaperDim')), findsNothing);
      await DesktopUiPrefs.setWallpaperDim(30);
      await t.pump();
      final dim = t.widget<ColoredBox>(
        find.byKey(const ValueKey('wallpaperDim')),
      );
      expect(dim.color.a, closeTo(0.30, 0.01));
    });
  });

  group('цвет имён в группах', () {
    testWidgets('по умолчанию у каждого свой, как у телефона', (t) async {
      await _pumpThread(t, nickname: 'amber');
      final name = t.widget<Text>(find.text('Пётр').first);
      expect(
        name.style?.color,
        isNot(desktopSenderNameColor(
          presetId: 'amber',
          accent: kDColorsDark.accentPrimary,
          dark: true,
        )),
      );
    });

    testWidgets('🔴 «один цвет на всех» — имя этим цветом', (t) async {
      await DesktopUiPrefs.setSenderNameColors('preset');
      await _pumpThread(t, nickname: 'amber');
      final name = t.widget<Text>(find.text('Пётр').first);
      expect(
        name.style?.color,
        desktopSenderNameColor(
          presetId: 'amber',
          accent: kDColorsDark.accentPrimary,
          dark: true,
        ),
      );
    });

    test('«Акцент» — это акцент окна, а не голубой из набора телефона', () {
      const accent = Color(0xFF23A55A);
      expect(
        desktopSenderNameColor(presetId: 'accent', accent: accent, dark: true),
        accent,
      );
    });

    test('на светлой схеме пастельные имена затемняются до читаемых', () {
      final c = desktopSenderNameColor(
        presetId: 'amber',
        accent: Colors.blue,
        dark: false,
      );
      expect(HSLColor.fromColor(c).lightness, lessThanOrEqualTo(0.42 + 1e-6));
    });
  });

  group('«По клику по фону» и шаг узора на отправку', () {
    test('🔴 лента передаёт щелчок по фону обоям (раньше не делала ничего)',
        () {
      final src = File(
        'lib/ui/desktop/chat/chat_thread_panel.dart',
      ).readAsStringSync();
      expect(src.contains('onPointerUp: _onListPointerUp'), isTrue);
      expect(
        src.contains('ChatWallpaperAnimMode.tap) return;'),
        isTrue,
        reason: 'щелчок оживляет узор только в режиме «По клику»',
      );
      expect(src.contains('_wallpaperKey.currentState?.shimmer()'), isTrue);
    });
  });

  group('готовые наборы', () {
    test('🔴 «Классика» и «Лес» — без подписки', () {
      // Набор не должен требовать подписки за то, что можно выбрать и так.
      for (final id in ['classic', 'forest']) {
        final p = desktopAppearancePresets().firstWhere((x) => x.id == id);
        for (final dark in [true, false]) {
          expect(
            (p.customAccent != null ||
                    isCosmeticFree(CosmeticKind.theme, p.themeId)) &&
                isCosmeticFree(CosmeticKind.wallpaper, p.wallpaper(dark: dark)) &&
                isCosmeticFree(CosmeticKind.bubbleStyle, p.bubbleId) &&
                isCosmeticFree(CosmeticKind.indicatorColor, p.indicatorId),
            isTrue,
            reason: '$id (${dark ? 'тёмная' : 'светлая'})',
          );
        }
      }
    });

    test('каждый набор ссылается на существующие варианты', () {
      for (final p in desktopAppearancePresets()) {
        expect(isValidAppThemePresetId(p.themeId), isTrue, reason: p.id);
        expect(isValidChatBubbleStylePresetId(p.bubbleId), isTrue, reason: p.id);
        expect(
          kIndicatorColorPresets.any((i) => i.id == p.indicatorId),
          isTrue,
          reason: p.id,
        );
        expect(
          p.names == 'person' || isValidNicknameStylePresetId(p.names),
          isTrue,
          reason: p.id,
        );
        for (final dark in [true, false]) {
          expect(
            isValidChatWallpaperId(p.wallpaper(dark: dark)),
            isTrue,
            reason: '${p.id}: ${p.wallpaper(dark: dark)}',
          );
        }
      }
    });

    test('🔴 «Классика» — ровно то, что даёт «По умолчанию»', () {
      final classic = desktopAppearancePresets().first;
      expect(classic.id, 'classic');
      expect(classic.themeId, 'flutter_dash');
      expect(classic.customAccent, isNull);
      expect(classic.wallpaper(dark: true),
          themeStandardChatWallpaperId(darkMode: true));
      expect(classic.wallpaper(dark: false),
          themeStandardChatWallpaperId(darkMode: false));
      expect(classic.bubbleId, normalizeChatBubbleStylePresetId('flutter_dash'));
      expect(classic.indicatorId, 'theme');
      expect(classic.names, 'person');
    });
  });

  group('раздел «Внешний вид»', () {
    late DesktopAppViewModel vm;
    setUp(() => vm = DesktopAppViewModel(controller: AppController()));
    tearDown(() => vm.dispose());

    Future<void> open(WidgetTester t, {double width = 1640}) async {
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(SettingsWorkspace(vm: vm, initialSectionId: 'appearance')),
      );
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Тема и текст'));
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('три вкладки, и каждая показывает своё', (t) async {
      await open(t);
      expect(find.text('ГОТОВЫЕ НАБОРЫ'), findsOneWidget);
      expect(find.text('СХЕМА'), findsOneWidget);
      await t.tap(find.text('Фон чата'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Затемнение'), findsOneWidget);
      expect(find.text('АНИМАЦИЯ УЗОРА'), findsOneWidget);
      await t.tap(find.text('Сообщения').first);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Форма'), findsOneWidget);
      expect(find.text('Разноцветные'), findsOneWidget);
    });

    testWidgets('🔴 предпросмотр справа — когда есть место, иначе его нет',
        (t) async {
      await open(t);
      expect(find.byType(DesktopAppearancePreview), findsOneWidget);
      await open(t, width: 1000);
      expect(find.byType(DesktopAppearancePreview), findsNothing);
      // Узко — настройки остаются доступны целиком.
      expect(find.text('ГОТОВЫЕ НАБОРЫ'), findsOneWidget);
    });

    testWidgets('🔴 предпросмотр — НАСТОЯЩАЯ лента переписки, а не её рисунок',
        (t) async {
      // Владелец 30.09: «превью… не те, что у нас на самом деле». Шапка, поле
      // ввода, пузыри, черта непрочитанного — те же виджеты, что в чате.
      await open(t);
      final preview = find.byType(DesktopAppearancePreview);
      expect(
        find.descendant(of: preview, matching: find.byType(ChatThreadPanel)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.byType(MessageBubble)),
        findsWidgets,
      );
    });

    testWidgets('🔴 плитки живых обоев — сами обои, а не пятно двух цветов',
        (t) async {
      await open(t);
      await t.tap(find.text('Фон чата'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Живые'));
      await t.pump(const Duration(milliseconds: 300));
      final tiles = find.byType(DesktopWallpaperTile);
      expect(tiles, findsNWidgets(WallpaperStyles.all.length));
      expect(
        find.descendant(of: tiles, matching: find.byType(TelegramWallpaper)),
        findsNWidgets(WallpaperStyles.all.length),
      );
      await t.tap(find.text('Тема и текст'));
      await t.pump(const Duration(milliseconds: 300));
    });

    testWidgets('🔴 набор «Лес» ставит все свои части', (t) async {
      await open(t);
      await t.tap(find.text('Лес'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 300));
      final ctrl = vm.controller;
      final forest =
          desktopAppearancePresets().firstWhere((p) => p.id == 'forest');
      expect(DesktopUiPrefs.customAccentArgb.value,
          forest.customAccent!.toARGB32());
      expect(ctrl.defaultChatWallpaperId, forest.wallpaper(dark: true));
      expect(normalizeChatBubbleStylePresetId(ctrl.chatBubbleStylePresetId),
          'mint');
      expect(ctrl.indicatorColorPresetId, 'emerald');
      expect(DesktopUiPrefs.senderNameColors.value, 'person');
    });

    testWidgets('🔴 «По умолчанию» возвращает всё, «Вернуть» — отменяет',
        (t) async {
      await open(t);
      await t.tap(find.text('Ночь'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Компактная'));
      await t.pump(const Duration(milliseconds: 300));
      final ctrl = vm.controller;
      final night =
          desktopAppearancePresets().firstWhere((p) => p.id == 'night');
      expect(ctrl.defaultChatWallpaperId, night.wallpaper(dark: true));
      expect(DesktopUiPrefs.messageDensity.value, 'compact');

      await t.tap(find.text('По умолчанию'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 300));
      expect(DesktopUiPrefs.customAccentArgb.value, 0);
      expect(ctrl.appThemePresetId, 'flutter_dash');
      expect(ctrl.defaultChatWallpaperId,
          themeStandardChatWallpaperId(darkMode: true));
      expect(ctrl.indicatorColorPresetId, 'theme');
      expect(DesktopUiPrefs.messageDensity.value, 'cozy');
      expect(DesktopUiPrefs.senderNameColors.value, 'person');
      expect(DesktopUiPrefs.themeMode.value, 'dark');

      await t.tap(find.text('Вернуть'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 300));
      expect(ctrl.defaultChatWallpaperId, night.wallpaper(dark: true));
      expect(DesktopUiPrefs.customAccentArgb.value,
          night.customAccent!.toARGB32());
      expect(DesktopUiPrefs.messageDensity.value, 'compact');
      expect(ctrl.indicatorColorPresetId, 'violet');
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('🔴 при 150 % все три вкладки без переполнения', (t) async {
      // Шапка раздела держала рядом с заголовком «Сохраняется автоматически»
      // и «По умолчанию» — при крупном тексте они вылезали за край на 136
      // точек (поймал `desktop_text_scale_test`). Теперь пояснение уходит, а
      // кнопки предпросмотра остаются значками.
      t.view.physicalSize = const Size(3440, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(
            textScaler: const TextScaler.linear(1.5),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: SettingsWorkspace(vm: vm, initialSectionId: 'appearance'),
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      for (final tab in ['Тема и текст', 'Фон чата', 'Сообщения']) {
        await t.tap(find.text(tab).first);
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull, reason: 'вкладка «$tab»');
      }
      await t.tap(find.text('Тема и текст'));
      await t.pump(const Duration(milliseconds: 400));
    });

    testWidgets('схема, плотность и форма — одним нажатием', (t) async {
      await open(t);
      await t.tap(find.text('Светлая'));
      await t.pump(const Duration(milliseconds: 300));
      expect(DesktopUiPrefs.themeMode.value, 'light');
      await t.tap(find.text('Компактная'));
      await t.pump(const Duration(milliseconds: 300));
      expect(DesktopUiPrefs.messageDensity.value, 'compact');
      await t.tap(find.text('Сообщения').first);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Круглые'));
      await t.pump(const Duration(milliseconds: 300));
      expect(DesktopUiPrefs.bubbleShape.value, 'round');
      // «Янтарь» есть и среди пузырей — фишка имён идёт в разделе последней.
      await t.tap(find.text('Янтарь').last);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 300));
      expect(DesktopUiPrefs.senderNameColors.value, 'preset');
      expect(vm.controller.nicknameStylePresetId, 'amber');
    });
  });

  group('палитра настроек', () {
    test('🔴 меняются поверхности и текст, а выбор человека — нет', () {
      final app = applyTestAccent(kDColorsDark);
      final set = settingsColorSet(app, SettingsPalette.darkPalette);
      expect(set.bg, SettingsPalette.darkPalette.main);
      expect(set.sidebar, SettingsPalette.darkPalette.side);
      expect(set.textPrimary, SettingsPalette.darkPalette.head);
      // Акцент, пузыри и индикаторы остаются цветами окна.
      expect(set.accentPrimary, app.accentPrimary);
      expect(set.bubbleSelfStart, app.bubbleSelfStart);
      expect(set.deliveryIndicator, app.deliveryIndicator);
      expect(set.success, app.success);
    });

    test('значок светлой колонки темнее, тёмной — светлее', () {
      const tint = DIconTint.amber;
      final onDark = SettingsPalette.darkPalette.glyph(tint);
      final onLight = SettingsPalette.lightPalette.glyph(tint);
      expect(
        HSLColor.fromColor(onDark).lightness,
        greaterThan(HSLColor.fromColor(onLight).lightness),
      );
    });
  });
}

/// Палитра окна с «чужим» акцентом — чтобы подмена не могла его потерять
/// незаметно (у палитры по умолчанию он и так совпадал бы).
DColorSet applyTestAccent(DColorSet base) => base.copyWith(
  accentPrimary: const Color(0xFF23A55A),
  bubbleSelfStart: const Color(0xFF123456),
  deliveryIndicator: const Color(0xFFABCDEF),
);
