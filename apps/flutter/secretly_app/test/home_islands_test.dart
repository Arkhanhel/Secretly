// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Острова v3 главного экрана: раскладка на любом телефоне, слияние от
// листания, поиск (поле над клавиатурой, крестик на месте Комнат), выбор
// раздела, общий поиск по чатам/комнатам/контактам. `SECRETLY_SHOTS=папка` —
// настоящие снимки (настоящие шапки разделов, острова и панель поиска).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/main.dart'
    show appLightBackgroundColors, buildSecretlyThemeForTest;
import 'package:secretly_app/search/smart_search.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:secretly_app/ui/chats_screen.dart';
import 'package:secretly_app/ui/contacts_screen.dart';
import 'package:secretly_app/ui/groups_screen.dart';
import 'package:secretly_app/ui/home/home_islands.dart';
import 'package:secretly_app/ui/home/home_search_panel.dart';
import 'package:secretly_app/ui/home/home_shell_scope.dart';
import 'package:secretly_app/ui/home/home_top_islands.dart';
import 'package:secretly_app/ui/theme_presets.dart';
import 'package:secretly_app/ui/widgets/app_background.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester t, String name) async {
  final dir = _shots;
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    final b =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _now = 1763600000000;

/// Контроллер с беседами и контактами — для поиска с настоящими данными.
class _FakeController extends AppController {
  @override
  Future<List<Conversation>> listConversations() async => [
    _c('mira', 'Мира Орлова', unread: 2, minutes: 5),
    _c('alexey', 'Алексей Ким', unread: 1, minutes: 30),
    _c('mama', 'Мама', minutes: 90),
    _c('oleg', 'Олег Миронов', minutes: 3000),
    _c('group:design', 'Дизайн-ревью', unread: 4, minutes: 1),
    _c('group:family', 'Семья', minutes: 200),
    _c('group:run', 'Бег по субботам', minutes: 5000),
  ];

  @override
  Future<List<Contact>> listContacts() async => const [
    Contact(profileId: 'mira', displayName: 'Мира Орлова'),
    Contact(profileId: 'marina_k', displayName: 'Марина Коваль'),
    Contact(profileId: 'max_ivanov', displayName: 'Максим Иванов'),
  ];

  final List<String> added = <String>[];

  @override
  Future<List<UserLookupResult>> lookupUsers(
    String query, {
    int limit = 20,
  }) async => [
    if ('новый друг'.contains(query.toLowerCase()) ||
        'new_friend'.contains(query.toLowerCase()))
      const UserLookupResult(
        profileId: 'new_friend',
        nickname: 'Новый Друг',
        alreadyInContacts: false,
      ),
  ];

  @override
  Future<void> addContact({
    required String profileId,
    String? displayName,
    bool displayNameIsCustom = false,
  }) async {
    added.add(profileId);
  }

  @override
  Future<String?> searchChatFirstMatch({
    required String convoId,
    required String query,
  }) async {
    if (convoId == 'alexey' && 'тестировал сборку'.contains(query)) {
      return 'Тестировал сборку, всё ок';
    }
    return null;
  }

  static Conversation _c(
    String id,
    String title, {
    int unread = 0,
    int minutes = 0,
  }) => Conversation(
    convoId: id,
    peerProfileId: id.startsWith('group:') ? null : id,
    title: title,
    avatarPath: null,
    lastEventAtMs: _now - minutes * 60000,
    pinnedAtMs: null,
    muted: false,
    archivedAtMs: null,
    autoDeleteSeconds: null,
    emoji: null,
    unreadCount: unread,
  );
}

Widget _app(Widget home, Brightness b, {Locale locale = const Locale('ru')}) {
  final preset = resolveAppThemePreset(AppController.kDefaultAppThemePresetId);
  final theme = buildSecretlyThemeForTest(
    b,
    appPreset: preset,
    bubblePreset: resolveChatBubbleStylePreset(
      AppController.kDefaultBubbleStylePresetId,
    ),
    nicknamePreset: resolveNicknameStylePreset('accent'),
    indicatorPreset: resolveIndicatorColorPreset('theme'),
  );
  final dark = b == Brightness.dark;
  final gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? [preset.darkBgTop, preset.darkBgMid, preset.darkBgBottom]
        : appLightBackgroundColors(preset),
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
    ),
    builder: (context, nav) => RepaintBoundary(
      key: _shotKey,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: AppBackground(gradient: gradient, dark: dark, child: nav!),
      ),
    ),
    home: home,
  );
}

/// Та же сборка, что у оболочки телефона: раздел, затемнение, панель поиска,
/// острова (в поиске — над клавиатурой).
class _Shell extends StatefulWidget {
  const _Shell({required this.controller, required this.islands});

  final AppController controller;
  final HomeIslandsController islands;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  HomeTab tab = HomeTab.chats;

  @override
  Widget build(BuildContext context) {
    final page = switch (tab) {
      HomeTab.chats => ChatsScreen(controller: widget.controller),
      HomeTab.rooms => GroupsScreen(controller: widget.controller),
      _ => ContactsScreen(controller: widget.controller),
    };
    return HomeShellScope(
      tab: tab,
      select: (t) => setState(() => tab = t),
      islands: widget.islands,
      child: ListenableBuilder(
        listenable: widget.islands,
        builder: (context, _) {
          final searching = widget.islands.searching;
          final kb = searching ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
          return Scaffold(
            resizeToAvoidBottomInset: false,
            body: Stack(
              children: [
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      widget.islands.handleScroll(n);
                      return false;
                    },
                    child: page,
                  ),
                ),
                if (searching)
                  Positioned.fill(
                    child: HomeSearchPanel(
                      controller: widget.controller,
                      islands: widget.islands,
                      boostKind: SmartSearchKind.chat,
                      bottomReserve: 96,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: kb > 0 ? kb + 10 : 30,
                  child: HomeBottomIslands(
                    controller: widget.islands,
                    tab: tab,
                    onSelect: (t) => setState(() => tab = t),
                    glass: false,
                    searchHint: 'Поиск по чатам',
                    chatsBadge: 3,
                    roomsBadge: 2,
                    roomLive: true,
                    avatarFrame: kAllAvatarFrames.first.builder,
                    avatar: const ColoredBox(
                      color: Color(0xFF7C6CF2),
                      child: Center(
                        child: Text(
                          'АС',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _phone(WidgetTester t, Size size, {double top = 59, double bottom = 34}) {
  t.view.physicalSize = size * 3;
  t.view.devicePixelRatio = 3;
  t.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
  addTearDown(t.view.reset);
}

Future<void> _settle(WidgetTester t, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Rect _rect(WidgetTester t, String key) =>
    t.getRect(find.byKey(ValueKey(key)));

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('раскладка на любом телефоне', () {
    for (final w in [320.0, 360.0, 375.0, 393.0, 430.0, 440.0]) {
      test('ширина $w', () {
        final g = HomeIslandsGeometry.forWidth(w);
        expect(g.size, inInclusiveRange(48, 62));
        // Покой: профиль | поиск ... [Чаты|Комнаты], без наложений.
        expect(g.profileLeft + g.size + g.gap,
            closeTo(g.searchIdleLeft, 0.01));
        expect(g.searchIdleLeft + g.size, lessThan(g.tabsLeft));
        expect(g.tabsLeft + g.tabsWidth, closeTo(w - g.margin, 0.01));
        // Ползунок — ровно две половины переключателя.
        expect(g.roomsKnobLeft + g.knobWidth + g.knobInset,
            closeTo(g.tabsLeft + g.tabsWidth, 0.01));
        // Слияние доходит до переключателя, поиск — до крестика.
        expect(g.margin + g.mergedWidth + g.gap, closeTo(g.tabsLeft, 0.01));
        expect(g.margin + g.searchWidth, lessThan(g.cancelLeft));
        expect(g.mergedWidth, greaterThan(g.size * 2));
      });
    }
    test('макет 5C: 393 pt', () {
      final g = HomeIslandsGeometry.forWidth(393);
      expect(g.size, closeTo(58, 0.01));
      expect(g.tabsHeight, closeTo(62, 0.01));
      expect(g.knobWidth, closeTo(77, 0.01));
      expect(g.knobHeight, closeTo(52, 0.01));
      expect(g.tabsWidth, closeTo(164, 0.01));
      expect(g.tabsLeft, closeTo(213, 0.01));
      expect(g.mergedWidth, closeTo(187, 0.01));
      expect(g.cancelLeft, closeTo(315, 0.01));
    });
  });

  testWidgets('листание сливает поиск с профилем и разделяет обратно', (
    t,
  ) async {
    final c = HomeIslandsController();
    addTearDown(c.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            c.handleScroll(n);
            return false;
          },
          child: ListView(
            children: [
              for (var i = 0; i < 60; i++) SizedBox(height: 60, child: Text('$i')),
            ],
          ),
        ),
      ),
    );
    expect(c.mode, HomeIslandsMode.idle);
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(c.mode, HomeIslandsMode.merged);
    await t.drag(find.byType(ListView), const Offset(0, 120));
    await t.pumpAndSettle();
    expect(c.mode, HomeIslandsMode.idle);
    // Дрожь пальца — не повод.
    await t.drag(find.byType(ListView), const Offset(0, -8));
    await t.pumpAndSettle();
    expect(c.mode, HomeIslandsMode.idle);
  });

  for (final (p, tag) in [
    (TargetPlatform.iOS, 'ios'),
    (TargetPlatform.android, 'android'),
  ]) {
    for (final b in [Brightness.dark, Brightness.light]) {
      final bt = b == Brightness.dark ? 'dark' : 'light';
      testWidgets('острова: покой, слияние, поиск ($tag, $bt)', (t) async {
        _phone(t, const Size(393, 852));
        final islands = HomeIslandsController();
        addTearDown(islands.dispose);
        final controller = _FakeController();
        await t.pumpWidget(
          _app(_Shell(controller: controller, islands: islands), b),
        );
        await _settle(t);
        expect(t.takeException(), isNull);

        // Покой: профиль и поиск — круги, Чаты|Комнаты — один островок.
        final search = _rect(t, 'island-search');
        final tabs = _rect(t, 'island-tabs');
        final profile = _rect(t, 'island-profile');
        expect(profile.left, closeTo(16, 0.5));
        expect(search.width, closeTo(58, 0.5));
        expect(tabs.left, closeTo(213, 0.5));
        expect(tabs.width, closeTo(164, 0.5));
        expect(tabs.right, closeTo(393 - 16, 0.5));
        expect(tabs.bottom, lessThanOrEqualTo(852 - 30 + 0.5));
        expect(find.text('Чаты'), findsWidgets); // крупный заголовок
        await _shoot(t, 'islands_${tag}_${bt}_1_idle');

        // Слияние.
        islands.handleScroll(
          ScrollUpdateNotification(
            metrics: FixedScrollMetrics(
              minScrollExtent: 0,
              maxScrollExtent: 2000,
              pixels: 300,
              viewportDimension: 800,
              axisDirection: AxisDirection.down,
              devicePixelRatio: 3,
            ),
            context: t.element(find.byType(_Shell)),
            scrollDelta: 30,
          ),
        );
        await _settle(t);
        expect(islands.mode, HomeIslandsMode.merged);
        final merged = _rect(t, 'island-search');
        expect(merged.left, closeTo(16, 0.5));
        expect(merged.width, closeTo(187, 0.5));
        expect(find.text('Search'), findsWidgets);
        await _shoot(t, 'islands_${tag}_${bt}_2_merged');

        // Поиск: поле над клавиатурой, крестик вместо Комнат.
        await t.tap(find.byKey(const ValueKey('island-search')));
        await t.pump();
        t.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
        addTearDown(t.view.resetViewInsets);
        await _settle(t);
        expect(islands.searching, isTrue);
        final field = _rect(t, 'island-search');
        expect(field.width, closeTo(293, 1));
        expect(field.bottom, closeTo(852 - 336 - 10 - 3, 0.5));
        // Островок Чаты|Комнаты сжался в круг крестика.
        final x0 = _rect(t, 'island-tabs');
        expect(x0.width, closeTo(62, 0.5));
        expect(x0.left, closeTo(315, 0.5));
        await _shoot(t, 'islands_${tag}_${bt}_3_search_empty');

        // Общий поиск: раскладка «vbhf» → «мира», чат и контакт сразу.
        await t.enterText(find.byType(TextField).last, 'vbh');
        await _settle(t, 10);
        expect(find.text('Мира Орлова'), findsWidgets);
        await _shoot(t, 'islands_${tag}_${bt}_4_search_layout');

        await t.enterText(find.byType(TextField).last, 'ма');
        await _settle(t, 10);
        expect(find.text('Марина Коваль'), findsOneWidget);
        expect(find.textContaining('Мама'), findsWidgets);
        await _shoot(t, 'islands_${tag}_${bt}_5_search_people');

        await t.enterText(find.byType(TextField).last, 'тестир');
        await _settle(t, 12);
        expect(find.textContaining('Тестировал'), findsOneWidget);
        await _shoot(t, 'islands_${tag}_${bt}_6_search_messages');

        // Крестик на месте Комнат закрывает поиск.
        final x = _rect(t, 'tab-rooms').center;
        await t.tapAt(x);
        t.view.resetViewInsets();
        await _settle(t);
        expect(islands.searching, isFalse);
        expect(find.byType(HomeSearchPanel), findsNothing);

        // Комнаты: капля переезжает, верхний «+» — комнатный.
        await t.tapAt(_rect(t, 'tab-rooms').center);
        await t.pump();
        await t.pump(const Duration(milliseconds: 200));
        await _shoot(t, 'islands_${tag}_${bt}_7_drop_midflight');
        await _settle(t);
        expect(find.byType(GroupsScreen), findsOneWidget);
        await _shoot(t, 'islands_${tag}_${bt}_8_rooms');

        // Контакты — кнопкой в верхнем островке.
        await t.tap(find.bySemanticsLabel('Контакты').first);
        await _settle(t);
        expect(find.byType(ContactsScreen), findsOneWidget);
        await _shoot(t, 'islands_${tag}_${bt}_9_contacts');
        await t.pumpWidget(const SizedBox());
        await _settle(t, 3);
      }, variant: TargetPlatformVariant.only(p));
    }
  }

  testWidgets('стекло iPhone: все состояния без ошибок', (t) async {
    _phone(t, const Size(393, 852));
    final islands = HomeIslandsController();
    addTearDown(islands.dispose);
    var tab = HomeTab.chats;
    late StateSetter set;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, s) {
              set = s;
              return Align(
                alignment: Alignment.bottomCenter,
                child: HomeBottomIslands(
                  controller: islands,
                  tab: tab,
                  onSelect: (v) => s(() => tab = v),
                  glass: true,
                  searchHint: 'Поиск',
                  avatar: const ColoredBox(color: Colors.purple),
                ),
              );
            },
          ),
        ),
      ),
    );
    await _settle(t);
    for (final next in [HomeTab.rooms, HomeTab.contacts, HomeTab.chats]) {
      set(() => tab = next);
      await t.pump();
      await _settle(t, 6);
    }
    islands.openSearch();
    await _settle(t);
    islands.closeSearch();
    await _settle(t);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Контакты: свои контакты целиком и люди с сервера по нику', (
    t,
  ) async {
    _phone(t, const Size(393, 852));
    final islands = HomeIslandsController();
    addTearDown(islands.dispose);
    final controller = _FakeController();
    islands.openSearch();
    await t.pumpWidget(
      _app(
        Scaffold(
          body: HomeSearchPanel(
            controller: controller,
            islands: islands,
            boostKind: SmartSearchKind.contact,
            bottomReserve: 96,
          ),
        ),
        Brightness.dark,
      ),
    );
    await _settle(t, 3);
    // Мира — и контакт, и чат: в Контактах она в разделе контактов.
    islands.text.text = 'мир';
    await _settle(t, 6);
    expect(find.text('Контакты'), findsOneWidget);
    expect(find.text('Мира Орлова'), findsOneWidget);
    // Новый человек — из глобального поиска, с кнопкой «Добавить».
    islands.text.text = 'новый';
    await _settle(t, 8);
    expect(find.text('Глобальный поиск'), findsOneWidget);
    expect(find.text('Новый Друг'), findsOneWidget);
    await _shoot(t, 'contacts_global_search');
    await t.tap(find.byType(FilledButton).last);
    await _settle(t, 6);
    expect(controller.added, ['new_friend']);
  });

  testWidgets('Чаты: на сервер запрос не уходит', (t) async {
    final islands = HomeIslandsController();
    addTearDown(islands.dispose);
    islands.openSearch();
    await t.pumpWidget(
      _app(
        Scaffold(
          body: HomeSearchPanel(
            controller: _FakeController(),
            islands: islands,
            boostKind: SmartSearchKind.chat,
            bottomReserve: 96,
          ),
        ),
        Brightness.dark,
      ),
    );
    islands.text.text = 'новый';
    await _settle(t, 8);
    expect(find.text('Глобальный поиск'), findsNothing);
  });

  testWidgets('🔴 спрятанный слой раздела гаснет до конца (баг 702)', (
    t,
  ) async {
    var tab = 0;
    late StateSetter set;
    await t.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, s) {
            set = s;
            return Stack(
              children: [
                HomeTabLayer(on: tab == 0, child: const Text('чаты')),
                HomeTabLayer(on: tab == 2, child: const Text('профиль')),
              ],
            );
          },
        ),
      ),
    );
    double opacityOf(String text) => t
        .renderObject<RenderAnimatedOpacity>(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity
        .value;

    expect(opacityOf('чаты'), 1);
    expect(opacityOf('профиль'), 0);
    // В профиль: чаты обязаны погаснуть полностью.
    set(() => tab = 2);
    await t.pumpAndSettle();
    expect(opacityOf('чаты'), 0);
    expect(opacityOf('профиль'), 1);
    // Обратно: профиль обязан погаснуть полностью.
    set(() => tab = 0);
    await t.pumpAndSettle();
    expect(opacityOf('профиль'), 0);
    expect(opacityOf('чаты'), 1);
    // Спрятанный слой не тикает.
    expect(
      TickerMode.valuesOf(t.element(find.text('профиль'))).enabled,
      isFalse,
    );
  });

  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('шапка: название раздела посередине без переполнений на '
          'всех языках (ширина $width, шрифт $scale)', (t) async {
        _phone(t, Size(width, 852));
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final islands = HomeIslandsController();
        addTearDown(islands.dispose);
        for (final lang in ['ru', 'uk', 'en', 'es', 'pt', 'fr', 'de']) {
          for (final tab in [HomeTab.chats, HomeTab.rooms]) {
            final c = _FakeController();
            final page = tab == HomeTab.chats
                ? ChatsScreen(controller: c)
                : GroupsScreen(controller: c);
            await t.pumpWidget(
              _app(
                HomeShellScope(
                  tab: tab,
                  select: (_) {},
                  islands: islands,
                  child: page,
                ),
                Brightness.dark,
                locale: Locale(lang),
              ),
            );
            await _settle(t, 4);
            expect(t.takeException(), isNull, reason: '$lang $tab');
            // Метки «Premium» в шапке нет.
            expect(find.text('Premium'), findsNothing);
            final center = find.byType(HomeSectionIsland);
            expect(center, findsOneWidget);
            // Островок внутри экрана (или скрыт на совсем узком месте).
            final texts = find.descendant(
              of: center,
              matching: find.byType(Text),
            );
            if (texts.evaluate().isNotEmpty) {
              final r = t.getRect(texts.first);
              expect(r.left, greaterThanOrEqualTo(0));
              expect(r.right, lessThanOrEqualTo(width));
            }
            if (lang == 'de' && width == 393 && scale == 1.0) {
              await _shoot(t, 'header_${lang}_${tab.name}');
            }
            if (lang == 'ru' && width == 393 && scale == 1.0) {
              await _shoot(t, 'header_${lang}_${tab.name}');
            }
          }
        }
        await t.pumpWidget(const SizedBox());
        await _settle(t, 3);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }

  // 🔴 21.11.2026: после шапки с островком посередине выделение чатов и
  // комнат ломалось — левый островок держал «до половины» ширины, правый
  // в выделении растёт до действий (300/256), вместе не помещались.
  for (final width in [375.0, 393.0]) {
    for (final lang in ['ru', 'de']) {
      testWidgets('выделение: острова перетекают в действия без переполнений '
          '(ширина $width, $lang)', (t) async {
        _phone(t, Size(width, 852));
        final islands = HomeIslandsController();
        addTearDown(islands.dispose);
        for (final tab in [HomeTab.chats, HomeTab.rooms]) {
          final c = _FakeController();
          await t.pumpWidget(
            _app(
              HomeShellScope(
                tab: tab,
                select: (_) {},
                islands: islands,
                child: tab == HomeTab.chats
                    ? ChatsScreen(controller: c)
                    : GroupsScreen(controller: c),
              ),
              Brightness.dark,
              locale: Locale(lang),
            ),
          );
          await _settle(t, 4);
          final title = tab == HomeTab.chats ? 'Мира Орлова' : 'Дизайн-ревью';
          await t.longPress(find.text(title).first);
          // Каждый кадр перехода — без переполнений.
          for (var i = 0; i < 12; i++) {
            await t.pump(const Duration(milliseconds: 40));
            expect(t.takeException(), isNull, reason: '$tab кадр $i');
          }
          await _settle(t, 4);
          expect(t.takeException(), isNull, reason: '$tab');
          // Посередине пусто — островок раздела погас.
          final center = find.byType(HomeSectionIsland);
          if (center.evaluate().isNotEmpty) {
            final op = t.widgetList<Opacity>(
              find.ancestor(of: center, matching: find.byType(Opacity)),
            );
            expect(op.every((o) => o.opacity <= 0.01), isTrue);
          }
          if (width == 393) await _shoot(t, 'select_${lang}_${tab.name}');
          await t.pumpWidget(const SizedBox());
          await _settle(t, 3);
        }
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }

  testWidgets('маленький экран (SE) и крупный шрифт — без переполнений', (
    t,
  ) async {
    _phone(t, const Size(320, 568), top: 20, bottom: 0);
    t.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final islands = HomeIslandsController();
    addTearDown(islands.dispose);
    await t.pumpWidget(
      _app(_Shell(controller: _FakeController(), islands: islands),
          Brightness.dark),
    );
    await _settle(t);
    expect(t.takeException(), isNull);
    final tabs = _rect(t, 'island-tabs');
    expect(tabs.right, lessThanOrEqualTo(320));
    islands.openSearch();
    await _settle(t);
    expect(t.takeException(), isNull);
    await _shoot(t, 'islands_se_search');
    await t.pumpWidget(const SizedBox());
    await _settle(t, 3);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
