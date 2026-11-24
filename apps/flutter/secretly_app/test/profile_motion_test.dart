// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Система движения профиля (макет «Profile Motion») на трёх экранах и
// спокойный чат (макет «Chat Diagnosis»).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/cosmetic_catalog.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:secretly_app/ui/profile/pattern_cover.dart';
import 'package:secretly_app/ui/profile/profile_motion.dart';
import 'package:secretly_app/ui/profile/avatar_radial_menu.dart';

String _src(String path) => File(path).readAsStringSync();

class _Host extends StatefulWidget {
  const _Host({required this.onReady});
  final void Function(ProfileHeroDriver) onReady;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  late final ProfileHeroDriver driver = ProfileHeroDriver(
    vsync: this,
    onChanged: () => setState(() {}),
    hapticsEnabled: () => false,
  );

  @override
  void initState() {
    super.initState();
    widget.onReady(driver);
  }

  @override
  void dispose() {
    driver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  test('резинка: сопротивление растёт, обратная — точная', () {
    expect(profileRubber(100, 520), lessThan(100 * 0.55 + 1));
    final a = profileRubber(100, 520) - profileRubber(0, 520);
    final b = profileRubber(400, 520) - profileRubber(300, 520);
    expect(b, lessThan(a)); // чем сильнее тянешь, тем туже
    for (final px in [10.0, 80.0, 108.0, 200.0]) {
      expect(
        profileRubber(profileRubberInverse(px, 520), 520),
        closeTo(px, 0.01),
      );
    }
    expect(profilePullFraction(0, 240), 0);
    expect(profilePullFraction(100000, 240), 1);
  });

  testWidgets('порог 45 % — фото раскрывается само, пружиной', (t) async {
    late ProfileHeroDriver d;
    await t.pumpWidget(_Host(onReady: (x) => d = x));
    // Тянем по чуть-чуть, пока не перешли порог.
    var steps = 0;
    while (!d.isAnimating && d.expand < 0.45 && steps < 200) {
      d.pull(6);
      steps++;
    }
    expect(d.isAnimating, isTrue, reason: 'на пороге — пружина к раскрытию');
    // Дальнейшее движение пальца её не сбивает.
    d.pull(-50);
    await t.pumpAndSettle();
    expect(d.expand, 1);
    expect(d.isOpen, isTrue);
  });

  testWidgets('раскрытое: вниз — растяжение, вверх 50 px — сворачивание',
      (t) async {
    late ProfileHeroDriver d;
    await t.pumpWidget(_Host(onReady: (x) => d = x));
    d.animateTo(1);
    await t.pumpAndSettle();
    d.dragOpen(80);
    expect(d.stretchPx, greaterThan(0));
    expect(d.stretchPx, lessThan(80)); // резинка
    d.release();
    await t.pumpAndSettle();
    expect(d.stretchRaw, 0);
    // Вверх 40 — ещё раскрыто; ещё 15 — сворачивается.
    d.dragOpen(-40);
    expect(d.isAnimating, isFalse);
    d.dragOpen(-15);
    expect(d.isAnimating, isTrue);
    await t.pumpAndSettle();
    expect(d.expand, 0);
    expect(d.pullRaw, 0);
  });

  testWidgets('недотянул и отпустил — назад; обложка знает натяжение',
      (t) async {
    late ProfileHeroDriver d;
    await t.pumpWidget(_Host(onReady: (x) => d = x));
    d.pull(60);
    expect(d.motion.value.pullPx, greaterThan(0));
    expect(d.expand, lessThan(0.45));
    d.release();
    await t.pumpAndSettle();
    expect(d.expand, 0);
    d.setScroll(85);
    expect(d.motion.value.collapse, closeTo(0.5, 1e-9));
  });

  test('шапка: имя причаливает за последние 28 px', () {
    expect(ProfileDockedHeader.dockProgress(0, 100), 0);
    expect(ProfileDockedHeader.dockProgress(86, 100), closeTo(0.5, 1e-9));
    expect(ProfileDockedHeader.dockProgress(150, 100), 1);
    expect(profileAvatarScrollScale(170), closeTo(0.3, 1e-9));
    expect(profileAvatarScrollOpacity(0), 1);
    expect(profileAvatarScrollOpacity(170), 0);
  });

  test('обложки-узоры — в каталоге и бесплатные; старый id не ломается', () {
    // Третья серия (23.11.2026) — не бесплатная: новогодние платные, а
    // обложки команды вне каталога (test/staff_covers_test.dart).
    final third = {...kStaffPatternCoverStyles, ...kNewYearPatternCoverStyles};
    for (final s in PatternCoverStyle.values) {
      final id = patternCoverId(s);
      expect(RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(id), isTrue, reason: id);
      if (third.contains(s)) continue;
      expect(coverById(id), isNotNull, reason: id);
      expect(kFreeProfileCoverIds, contains(id));
    }
    // Старые сборки нового id не знают: у них coverById → null → без обложки.
    expect(coverById('pattern_unknown'), isNull);
  });

  group('🔴 три экрана — один двигатель, кнопки не тронуты', () {
    for (final f in [
      'lib/ui/profile_screen.dart',
      'lib/ui/contact_details_screen.dart',
      'lib/ui/room_details_screen.dart',
    ]) {
      test(f, () {
        final s = _src(f);
        expect(s.contains('late final ProfileHeroDriver _hero'), isTrue);
        expect(s.contains('double get _pullExpand => _hero.expand;'), isTrue);
        expect(s.contains('_pullSnapController'), isFalse);
        expect(s.contains('ProfileCoverParallax('), isTrue);
        expect(s.contains('ProfileMotionScope('), isTrue);
        expect(s.contains('expandedImageHeight + _hero.stretchPx'), isTrue);
        expect(s.contains('_scrollController.addListener(_onHeroScroll)'), isTrue);
      });
    }
  });

  test('🔴 чат: входящие — оттенок темы, канты тише, время тише', () {
    final s = _src('lib/ui/chat_screen.dart');
    expect(s.contains('darkGlassTint: cs.surface.withValues(alpha: 0.61),'), isTrue);
    expect(s.contains('Colors.white.withValues(alpha: isDark ? 0.14 : 0.30)'), isFalse);
    expect(s.contains('? Colors.white.withValues(alpha: 0.24)\n          : Colors.white.withValues(alpha: 0.42);\n      island'), isFalse);
    expect(s.contains('fontWeight: FontWeight.w600,\n                  height: 1,\n                  color: color.withValues(alpha: 0.72),'), isFalse);
    // Новых наборов пузырей нет.
    final presets = _src('lib/ui/theme_presets.dart');
    expect(
      RegExp(r"ChatBubbleStylePreset\(\s*id: '").allMatches(presets).length,
      greaterThanOrEqualTo(20),
    );
  });

  testWidgets('🔴 пока пружина ведёт фото — палец не сбивает, листать нельзя',
      (t) async {
    late ProfileHeroDriver d;
    await t.pumpWidget(_Host(onReady: (x) => d = x));
    d.animateTo(1);
    await t.pumpAndSettle();
    expect(d.blocksScroll, isTrue); // раскрыто — страница стоит
    d.dragOpen(-60); // свайп вверх — сворачивается
    expect(d.isAnimating, isTrue);
    expect(d.blocksScroll, isTrue); // и пока сворачивается — тоже
    // Прокрутка/натяжение посреди сворачивания раньше останавливали пружину.
    d.pull(-30);
    d.pull(40);
    expect(d.isAnimating, isTrue);
    await t.pumpAndSettle();
    expect(d.expand, 0);
    expect(d.blocksScroll, isFalse);
  });

  testWidgets('магнитная привязка: к ближней точке, ниже галереи — свободно',
      (t) async {
    final controller = ScrollController();
    final snapper = ProfileScrollSnapper(controller: controller)
      ..dockAt = 120
      ..headerBottom = 100;
    await t.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: controller,
          children: [
            const SizedBox(height: 400),
            SizedBox(key: snapper.galleryKey, height: 0),
            const SizedBox(height: 50),
            ProfileSnapSpacer(snapper: snapper),
          ],
        ),
      ),
    );
    await t.pump();
    await t.pump();
    // Пустое место дало галерее дойти до шапки (400 − 100 = 300).
    expect(controller.position.maxScrollExtent, greaterThanOrEqualTo(299));
    controller.jumpTo(40);
    snapper.onScrollEnd();
    await t.pumpAndSettle();
    expect(controller.offset, 0);
    controller.jumpTo(90);
    snapper.onScrollEnd();
    await t.pumpAndSettle();
    expect(controller.offset, 120);
    controller.jumpTo(250);
    await t.pump();
    snapper.onScrollEnd();
    await t.pumpAndSettle();
    expect(controller.offset, closeTo(300, 1));
    snapper.dispose();
  });

  test('🔴 профиль: прокрутка не будит поиск, страница стоит во время анимации',
      () {
    final own = _src('lib/ui/profile_screen.dart');
    expect(own.contains('_handleProfilePull(n);\n                return true;'), isTrue);
    for (final f in [
      'lib/ui/profile_screen.dart',
      'lib/ui/contact_details_screen.dart',
      'lib/ui/room_details_screen.dart',
    ]) {
      final s = _src(f);
      expect(s.contains('ProfileHeroScrollPhysics('), isTrue, reason: f);
      expect(s.contains('ProfileHeroGestureLayer('), isTrue, reason: f);
      expect(s.contains('_handleCollapseDrag'), isFalse, reason: f);
      expect(s.contains('SizedBox(key: _snap.galleryKey, height: 0)'), isTrue, reason: f);
      expect(s.contains('ProfileSnapSpacer(snapper: _snap)'), isTrue, reason: f);
      expect(s.contains('_snap.onScrollEnd()'), isTrue, reason: f);
    }
    // В острове рядом с именем — статус и знак.
    final c = _src('lib/ui/contact_details_screen.dart');
    final h = c.indexOf('ProfileMiniIsland(');
    expect(c.substring(h, h + 1500).contains('EliteBadgeMark('), isTrue);
    expect(c.substring(h, h + 1500).contains('NotoStatusEmoji('), isTrue);
  });

  testWidgets('🔴 чуть потянул, отпустил — вторая попытка подхватывает',
      (t) async {
    late ProfileHeroDriver d;
    await t.pumpWidget(_Host(onReady: (x) => d = x));
    d.pull(40);
    final first = d.expand;
    d.release(); // пружина возвращает недотянутое
    await t.pump(const Duration(milliseconds: 60));
    expect(d.isAnimating, isTrue);
    expect(d.blocksScroll, isFalse, reason: 'возврат не запирает страницу');
    final mid = d.expand;
    d.pull(30); // палец снова — подхватили с места, не с нуля и не с конца
    expect(d.isAnimating, isFalse);
    expect(d.expand, greaterThan(mid));
    await t.pump(const Duration(milliseconds: 600));
    expect(d.expand, greaterThan(0), reason: 'старый ход не доехал до нуля');
    expect(first, greaterThan(0));
    d.release();
    await t.pumpAndSettle();
    expect(d.expand, 0);
  });

  testWidgets('долгое нажатие на аватар: меню, наведение, выбор', (t) async {
    String? picked;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AvatarRadialMenu(
              hapticsEnabled: () => false,
              items: [
                AvatarMenuItem(
                  icon: Icons.photo_camera,
                  label: 'Фото',
                  onSelected: () => picked = 'photo',
                ),
                AvatarMenuItem(
                  icon: Icons.circle_outlined,
                  label: 'Рамка',
                  onSelected: () => picked = 'frame',
                ),
                AvatarMenuItem(
                  icon: Icons.wallpaper,
                  label: 'Обложка',
                  onSelected: () => picked = 'cover',
                ),
              ],
              child: const SizedBox.square(
                key: ValueKey('av'),
                dimension: 112,
                child: ColoredBox(color: Colors.indigo),
              ),
            ),
          ),
        ),
      ),
    );
    final center = t.getCenter(find.byKey(const ValueKey('av')));
    final g = await t.startGesture(center);
    await t.pump(const Duration(milliseconds: 420));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Рамка'), findsOneWidget);
    // Ведём к нижней кнопке («Рамка»: под аватаром) и отпускаем.
    await g.moveTo(center + const Offset(0, 56 + 56));
    await t.pump(const Duration(milliseconds: 100));
    await g.up();
    await t.pumpAndSettle();
    expect(picked, 'frame');
    expect(find.text('Рамка'), findsNothing);
  });

  testWidgets('отпустил мимо — меню закрывается без действия', (t) async {
    var picked = false;
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: AvatarRadialMenu(
            hapticsEnabled: () => false,
            items: [
              AvatarMenuItem(
                icon: Icons.photo_camera,
                label: 'Фото',
                onSelected: () => picked = true,
              ),
            ],
            child: const SizedBox.square(
              key: ValueKey('av'),
              dimension: 112,
              child: ColoredBox(color: Colors.indigo),
            ),
          ),
        ),
      ),
    );
    final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('av'))));
    await t.pump(const Duration(milliseconds: 500));
    await g.up();
    await t.pumpAndSettle();
    expect(picked, isFalse);
  });

  test('🔴 профиль сворачивается в свой остров (три экрана)', () {
    final own = _src('lib/ui/profile_screen.dart');
    expect(own.contains('ProfileMiniIdentity('), isTrue);
    expect(own.contains('AvatarRadialMenu('), isTrue);
    expect(own.contains('ProfileFadeUnderHeader.hidden('), isTrue); // шестерёнка
    expect(own.contains('Theme(data: profileCardTheme(context)'), isTrue);
    for (final f in [
      'lib/ui/profile_screen.dart',
      'lib/ui/contact_details_screen.dart',
      'lib/ui/room_details_screen.dart',
    ]) {
      final s = _src(f);
      // Один аватар: в странице прячется, летит слоем поверх шапки.
      expect(s.contains('ProfileHideWhileFlying('), isTrue, reason: f);
      expect(s.contains('ProfileFlyingAvatar('), isTrue, reason: f);
      expect(s.contains('ProfileAvatarFlight('), isFalse, reason: f);
      expect(s.contains('ProfileTextCollapse('), isTrue, reason: f);
      expect(s.contains('ProfileFadeUnderHeader('), isTrue, reason: f);
      expect(s.contains('ProfileTopFade('), isTrue, reason: f);
      expect(s.contains('ProfileDockedHeader('), isFalse, reason: f);
    }
    for (final f in [
      'lib/ui/contact_details_screen.dart',
      'lib/ui/room_details_screen.dart',
    ]) {
      expect(_src(f).contains('ProfileMiniIsland('), isTrue, reason: f);
    }
  });

  group('🔴 аватар садится РОВНО в остров на любом экране', () {
    for (final (name, size, safeTop) in const [
      ('iPhone SE', Size(320, 568), 20.0),
      ('iPhone 15', Size(393, 852), 59.0),
      ('Pro Max', Size(430, 932), 59.0),
      ('Android', Size(412, 915), 24.0),
    ]) {
      test(name, () {
        // Под шапкой: статус-бар + шапка + 8 + половина аватара.
        final rest = Offset(size.width / 2, safeTop + kToolbarHeight + 8 + 56);
        final island = Offset(6.0 + 7 + 17, safeTop + kToolbarHeight / 2);
        expect(
          profileFlightRect(
            scroll: 0,
            expand: 0,
            restCenter: rest,
            islandCenter: island,
          ),
          isNull,
          reason: 'наверху аватар в странице, не летит',
        );
        final mid = profileFlightRect(
          scroll: 85,
          expand: 0,
          restCenter: rest,
          islandCenter: island,
        )!;
        expect(mid.width, inExclusiveRange(34, 112));
        // Сперва вверх, потом влево (x по степени 1,6 отстаёт от y).
        final ky = (rest.dy - mid.center.dy) / (rest.dy - island.dy);
        final kx = (rest.dx - mid.center.dx) / (rest.dx - island.dx);
        expect(kx, lessThan(ky));
        for (final scroll in [170.0, 400.0]) {
          final r = profileFlightRect(
            scroll: scroll,
            expand: 0,
            restCenter: rest,
            islandCenter: island,
          )!;
          expect(r.center.dx, closeTo(island.dx, 0.01));
          expect(r.center.dy, closeTo(island.dy, 0.01));
          expect(r.width, closeTo(34, 0.01));
        }
      });
    }
  });

  test('🔴 вкладки галереи занимают ряд островов шапки (свой профиль)', () {
    final s = _src('lib/ui/profile_screen.dart');
    expect(s.contains('_hideWhenTabsPinned('), isTrue);
    expect(
      RegExp(r'_hideWhenTabsPinned\(').allMatches(s).length,
      greaterThanOrEqualTo(3), // метод + левый и правый острова
    );
    expect(s.contains('..headerBottom = safeTop - kToolbarHeight + (kToolbarHeight - 44) / 2;'), isTrue);
    expect(s.contains('hidden: _tabsPinned,'), isTrue);
    // В острове — пустое место под прилетающий аватар, не второй аватар.
    final i = s.indexOf('child: ProfileMiniIdentity(');
    expect(s.substring(i, i + 900).contains('avatar: const SizedBox.shrink()'), isTrue);
    expect(s.substring(i, i + 900).contains('ghost: true'), isTrue);
  });

  testWidgets('🔴 фото раскрывается — свайп вверх сворачивает сразу', (t) async {
    late ProfileHeroDriver d;
    await t.pumpWidget(_Host(onReady: (x) => d = x));
    d.animateTo(1);
    await t.pump(const Duration(milliseconds: 40)); // ещё раскрывается
    expect(d.isAnimating, isTrue);
    expect(d.ownsDrag, isTrue, reason: 'жест страницы уже принимается');
    d.dragOpen(-20); // вверх, не дожидаясь конца раскрытия
    await t.pumpAndSettle();
    expect(d.expand, 0);
  });

  testWidgets('имя летит в остров и садится справа от аватара', (t) async {
    late ProfileHeroDriver d;
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            _Host(onReady: (x) => d = x),
          ],
        ),
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            _Host(onReady: (x) => d = x),
            Positioned.fill(
              child: ProfileFlyingLabel(
                driver: d,
                restTop: 250,
                restCenterX: 195,
                targetLeft: 55,
                targetCenterY: 87,
                targetMaxWidth: 150,
                child: SizedBox(key: key, width: 120, height: 30),
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(key), findsNothing); // наверху — не летит
    d.setScroll(400);
    await t.pump();
    final r = t.getRect(find.byKey(key));
    // Масштаб 16/24 вокруг центра: левый край — у места в острове.
    expect(r.left, closeTo(55, 0.6));
    expect(r.center.dy, closeTo(87, 0.6));
    expect(r.width, closeTo(80, 0.6));
  });

  test('🔴 галерея: «+» и пустые рамки, «Пока пусто» нет', () {
    final s = _src('lib/ui/profile_screen.dart');
    expect(s.contains('ProfileGalleryAddTile('), isTrue);
    expect(s.contains('const ProfileGalleryEmptyTile()'), isTrue);
    final pane = s.indexOf('Widget _buildImageCategoryPane(');
    expect(s.substring(pane, pane + 2500).contains("ru: 'Пока пусто'"), isFalse);
    expect(s.contains('(gallery ? 5 : 3) - paths.length'), isTrue);
  });

  test('🔴 под шапкой страница начинается ниже — геометрия от неё', () {
    for (final f in [
      'lib/ui/profile_screen.dart',
      'lib/ui/contact_details_screen.dart',
      'lib/ui/room_details_screen.dart',
    ]) {
      final s = _src(f);
      expect(s.contains('safeTop + kToolbarHeight + 8 + 56'), isTrue, reason: f);
      expect(s.contains('ProfileFlyingLabel('), isTrue, reason: f);
      expect(s.contains('..dockAt = kProfileScrollCollapse'), isTrue, reason: f);
    }
  });

  group('🔴 без задержки: фото перехватывается в любой момент', () {
    Widget page(ProfileHeroDriver d, ScrollController c) => MaterialApp(
      home: ProfileHeroGestureLayer(
        driver: d,
        scrollController: c,
        child: ListView(
          controller: c,
          physics: ProfileHeroScrollPhysics(
            frozen: () => d.heroActive,
            parent: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
          ),
          children: const [SizedBox(height: 2000)],
        ),
      ),
    );

    testWidgets('потянул до порога и сразу повёл вверх — сворачивается '
        'тем же пальцем', (t) async {
      late ProfileHeroDriver d;
      final c = ScrollController();
      await t.pumpWidget(Stack(textDirection: TextDirection.ltr, children: [
        _Host(onReady: (x) => d = x),
      ]));
      await t.pumpWidget(Stack(textDirection: TextDirection.ltr, children: [
        _Host(onReady: (x) => d = x),
        Positioned.fill(child: page(d, c)),
      ]));
      final g = await t.startGesture(const Offset(200, 300));
      for (var i = 0; i < 30; i++) {
        await g.moveBy(const Offset(0, 10));
        await t.pump(const Duration(milliseconds: 8));
      }
      expect(d.isAnimating || d.isOpen, isTrue, reason: 'порог — раскрытие');
      // Тот же палец, не отпуская, — вверх.
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(0, -12));
        await t.pump(const Duration(milliseconds: 8));
      }
      expect(d.expand, lessThan(0.9), reason: 'фото пошло за пальцем сразу');
      await g.up();
      await t.pumpAndSettle();
      expect(d.expand, 0);
      // Пока фото было «в игре», страница стояла; закрылось под пальцем —
      // остаток движения листает страницу, как обычно.
      expect(c.offset, lessThan(30));
    });

    testWidgets('сворачивается — палец вниз перехватывает и раскрывает',
        (t) async {
      late ProfileHeroDriver d;
      final c = ScrollController();
      await t.pumpWidget(Stack(textDirection: TextDirection.ltr, children: [
        _Host(onReady: (x) => d = x),
      ]));
      await t.pumpWidget(Stack(textDirection: TextDirection.ltr, children: [
        _Host(onReady: (x) => d = x),
        Positioned.fill(child: page(d, c)),
      ]));
      d.animateTo(1);
      await t.pumpAndSettle();
      d.animateTo(0);
      await t.pump(const Duration(milliseconds: 50)); // ещё сворачивается
      final g = await t.startGesture(const Offset(200, 300));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(0, 8));
        await t.pump(const Duration(milliseconds: 8));
      }
      expect(d.isAnimating, isFalse, reason: 'перехвачено пальцем');
      await g.up();
      await t.pumpAndSettle();
      expect(d.expand, 1, reason: 'палец вёл вниз — раскрылось');
    });

    testWidgets('вбок (галерея) — фото не трогается', (t) async {
      late ProfileHeroDriver d;
      final c = ScrollController();
      await t.pumpWidget(Stack(textDirection: TextDirection.ltr, children: [
        _Host(onReady: (x) => d = x),
      ]));
      await t.pumpWidget(Stack(textDirection: TextDirection.ltr, children: [
        _Host(onReady: (x) => d = x),
        Positioned.fill(child: page(d, c)),
      ]));
      final g = await t.startGesture(const Offset(300, 400));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(-15, 3));
        await t.pump(const Duration(milliseconds: 8));
      }
      await g.up();
      await t.pumpAndSettle();
      expect(d.expand, 0);
    });
  });

  test('🔴 остров «аватар + имя» не наезжает на «назад»', () {
    expect(kProfileMiniIslandLeft, greaterThanOrEqualTo(8 + 48 + 8));
    for (final f in [
      'lib/ui/contact_details_screen.dart',
      'lib/ui/room_details_screen.dart',
    ]) {
      final s = _src(f);
      expect(s.contains('left: kProfileMiniIslandLeft,'), isTrue, reason: f);
      expect(s.contains('Offset(kProfileMiniIslandLeft + 7 + 17,'), isTrue, reason: f);
    }
    final m = _src('lib/ui/profile/profile_motion.dart');
    expect(m.contains('Offset(-10 * (1 - mk), 0)'), isFalse);
  });

  test('🔴 круглой «+» в профиле больше нет', () {
    final s = _src('lib/ui/profile_screen.dart');
    expect(s.contains('floatingActionButton:'), isFalse);
    expect(s.contains('_inlineAddMediaButton('), isFalse);
    expect(s.contains('ProfileGalleryAddTile('), isTrue);
  });

  testWidgets('🔴 после сворачивания страница свободна сразу', (t) async {
    late ProfileHeroDriver d;
    await t.pumpWidget(_Host(onReady: (x) => d = x));
    d.animateTo(1);
    await t.pumpAndSettle();
    d.animateTo(0);
    var freeAtMs = -1;
    for (var ms = 0; ms <= 600; ms += 10) {
      await t.pump(const Duration(milliseconds: 10));
      if (freeAtMs < 0 && !d.freezesScroll) freeAtMs = ms;
      if (!d.isAnimating) break;
    }
    // Круг уже виден — страница отпущена задолго до конца пружины.
    expect(freeAtMs, inInclusiveRange(0, 320));
    await t.pumpAndSettle();
    expect(d.expand, 0);
    expect(d.freezesScroll, isFalse);
  });

  test('🔴 физика страницы читает «хвост сворачивания»', () {
    for (final f in [
      'lib/ui/profile_screen.dart',
      'lib/ui/contact_details_screen.dart',
      'lib/ui/room_details_screen.dart',
    ]) {
      expect(_src(f).contains('frozen: () => _hero.freezesScroll,'), isTrue, reason: f);
    }
  });
}
