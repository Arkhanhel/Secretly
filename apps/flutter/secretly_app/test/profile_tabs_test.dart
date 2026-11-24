// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Вкладки «Мини-галереи» (гусеница, листание, высота, закреплённая копия).
// `SECRETLY_SHOTS=папка` — снимок полосы и листалки в тёмной и светлой теме.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/profile/profile_tabs.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];

const _labels = ['Галерея', 'Фоны', 'Музыка'];
const _heights = [100.0, 300.0, 50.0];

class _Host extends StatefulWidget {
  const _Host({this.onChanged, this.onController});

  final ValueChanged<int>? onChanged;
  final ValueChanged<ProfileTabsController>? onController;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  late final ProfileTabsController tabs = ProfileTabsController(
    vsync: this,
    length: 3,
    onChanged: widget.onChanged,
  );

  @override
  void initState() {
    super.initState();
    widget.onController?.call(tabs);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ProfileTabsBar(controller: tabs, labels: _labels),
        ),
        ProfileTabsPager(
          key: const ValueKey('pager'),
          controller: tabs,
          pages: [
            for (var i = 0; i < 3; i++)
              SizedBox(
                height: _heights[i],
                child: ColoredBox(
                  color: Colors.primaries[i * 4],
                  child: Center(child: Text('page$i')),
                ),
              ),
          ],
        ),
        const SizedBox(height: 1200),
      ],
    );
  }
}

Future<ProfileTabsController> _pump(
  WidgetTester t, {
  ValueChanged<int>? onChanged,
  Brightness brightness = Brightness.dark,
}) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  late ProfileTabsController c;
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: _Host(onChanged: onChanged, onController: (x) => c = x),
      ),
    ),
  );
  return c;
}

double _pagerHeight(WidgetTester t) =>
    t.getSize(find.byKey(const ValueKey('pager'))).height;

void main() {
  testWidgets('касание вкладки — страница и onChanged, отклик selection', (
    t,
  ) async {
    final haptics = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final changes = <int>[];
    final c = await _pump(t, onChanged: changes.add);
    expect(c.index, 0);
    await t.tap(find.text('Фоны').first);
    await t.pumpAndSettle();
    expect(changes, [1]);
    expect(c.index, 1);
    expect(c.page, 1);
    expect(c.indicatorLeft, 1);
    expect(c.indicatorRight, 2);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    // Отклик выключен — тишина.
    c.hapticsEnabled = () => false;
    await t.tap(find.text('Музыка').first);
    await t.pumpAndSettle();
    expect(changes, [1, 2]);
    expect(haptics.length, 1);
  });

  testWidgets('гусеница: ведущий край быстрее отстающего', (t) async {
    final c = await _pump(t);
    await t.tap(find.text('Музыка').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    final movedRight = c.indicatorRight - 1;
    final movedLeft = c.indicatorLeft - 0;
    expect(movedRight, greaterThan(0));
    expect(movedRight, greaterThan(movedLeft));
    // Плашка растянулась шире ячейки.
    expect(c.indicatorRight - c.indicatorLeft, greaterThan(1));
    await t.pumpAndSettle();
    expect(c.indicatorLeft, 2);

    // Обратно — роли меняются: теперь быстрее левый.
    await t.tap(find.text('Галерея').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(2 - c.indicatorLeft, greaterThan(3 - c.indicatorRight));
    await t.pumpAndSettle();
    expect(c.index, 0);
  });

  testWidgets('бросок — на соседнюю, малый сдвиг — назад', (t) async {
    final changes = <int>[];
    final c = await _pump(t, onChanged: changes.add);
    final pager = find.byKey(const ValueKey('pager'));
    // 60 px за 600 мс — медленно и мало: возврат.
    await t.timedDrag(
      pager,
      const Offset(-60, 0),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(c.index, 0);
    expect(c.page, 0);
    expect(changes, isEmpty);
    // 100 px броском (1 px/мс > 0,7): на следующую, хотя меньше половины.
    await t.fling(pager, const Offset(-100, 0), 1000);
    await t.pumpAndSettle();
    expect(c.index, 1);
    expect(c.page, 1);
    expect(changes, [1]);
    // Бросок вправо — на предыдущую.
    await t.fling(pager, const Offset(100, 0), 1000);
    await t.pumpAndSettle();
    expect(c.index, 0);
  });

  testWidgets('резинка у краёв и возврат', (t) async {
    final c = await _pump(t);
    final pager = find.byKey(const ValueKey('pager'));
    final g = await t.startGesture(t.getCenter(pager));
    // Сперва за порог жеста, затем ещё 300 px вправо — за первую страницу.
    await g.moveBy(const Offset(20, 0));
    await t.pump();
    final before = c.page;
    await g.moveBy(const Offset(300, 0));
    await t.pump();
    final w = t.getSize(pager).width;
    expect(c.page, lessThan(0));
    // Сопротивление: ушли меньше, чем палец.
    expect(c.page, greaterThan(before - 300 / w));
    expect(c.isDragging, isTrue);
    await t.pump(const Duration(seconds: 1));
    await g.up();
    await t.pumpAndSettle();
    expect(c.page, 0);
    expect(c.index, 0);

    expect(profileTabsRubber(0, 400), 0);
    expect(profileTabsRubber(100000, 400), lessThan(400));
    expect(profileTabsRubber(400, 400), closeTo(400 * (1 - 1 / 1.55), 1e-9));
  });

  testWidgets('высота листалки — по странице', (t) async {
    final c = await _pump(t);
    expect(_pagerHeight(t), 100);
    // Палец на полпути между 0 и 1 — высота посередине.
    final pager = find.byKey(const ValueKey('pager'));
    final w = t.getSize(pager).width;
    final g = await t.startGesture(t.getCenter(pager));
    await g.moveBy(const Offset(-20, 0));
    await t.pump();
    await g.moveBy(Offset(-(w / 2 - (c.page * w)), 0));
    await t.pump();
    expect(c.page, closeTo(0.5, 0.01));
    expect(_pagerHeight(t), closeTo(200, 3));
    await t.pump(const Duration(seconds: 1));
    await g.up();
    await t.pumpAndSettle();
    await t.tap(find.text('Фоны').first);
    await t.pumpAndSettle();
    expect(_pagerHeight(t), 300);
    await t.tap(find.text('Музыка').first);
    await t.pumpAndSettle();
    expect(_pagerHeight(t), 50);
    expect(find.text('page2'), findsOneWidget);
  });

  testWidgets('уменьшенное движение — сразу на место', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late ProfileTabsController c;
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            disableAnimations: true,
          ),
          child: Scaffold(body: _Host(onController: (x) => c = x)),
        ),
      ),
    );
    await t.tap(find.text('Фоны').first);
    await t.pump();
    expect(c.page, 1);
    expect(c.indicatorLeft, 1);
    expect(c.isAnimating, isFalse);
  });

  testWidgets('закреплённая копия под шапкой', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final haptics = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final inListKey = GlobalKey();
    late ProfileTabsController c;
    const headerBottom = 100.0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _StickyHost(
            scroll: scroll,
            inListKey: inListKey,
            headerBottom: headerBottom,
            onController: (x) => c = x,
          ),
        ),
      ),
    );
    await t.pump();
    expect(c.pinned, isFalse);
    expect(find.byType(ProfileTabsBar), findsOneWidget);

    // Полоса (y = 300) уходит выше линии шапки (100).
    scroll.jumpTo(250);
    await t.pump();
    await t.pump();
    expect(c.pinned, isTrue);
    expect(find.byType(ProfileTabsBar), findsNWidgets(2));
    final sticky = find.descendant(
      of: find.byType(ProfileStickyTabs),
      matching: find.byType(ProfileTabsBar),
    );
    expect(t.getTopLeft(sticky).dy, headerBottom);
    // Полоса в списке спрятана, но держит место.
    final hidden = t.widget<Visibility>(
      find.descendant(
        of: find.byKey(inListKey),
        matching: find.byType(Visibility),
      ),
    );
    expect(hidden.visible, isFalse);
    expect(haptics, ['HapticFeedbackType.lightImpact']);

    // Касание закреплённой копии — тот же контроллер.
    await t.tap(
      find.descendant(of: sticky, matching: find.text('Музыка')).first,
    );
    await t.pumpAndSettle();
    expect(c.index, 2);

    scroll.jumpTo(0);
    await t.pump();
    await t.pump();
    expect(c.pinned, isFalse);
    expect(find.byType(ProfileTabsBar), findsOneWidget);
    expect(haptics.where((h) => h.contains('lightImpact')).length, 2);
  });

  testWidgets('снимок полосы и листалки (обе темы)', (t) async {
    final dir = _shots;
    t.view.physicalSize = const Size(840, 520);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    final ctrls = <ProfileTabsController>[];
    await t.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Row(
            children: [
              for (final b in Brightness.values)
                Expanded(
                  child: Theme(
                    data: ThemeData(
                      brightness: b,
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: b == Brightness.dark
                            ? const Color(0xFF53B7F4)
                            : const Color(0xFF1E96D6),
                        brightness: b,
                      ),
                    ),
                    child: Builder(
                      builder: (context) => ColoredBox(
                        color: b == Brightness.dark
                            ? const Color(0xFF151E27)
                            : const Color(0xFFF1F4F7),
                        child: Scaffold(
                          backgroundColor: Colors.transparent,
                          body: _Host(onController: ctrls.add),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    // Тёмная — в покое на «Фонах», светлая — посреди перехода (растяжка).
    ctrls[0].jumpTo(1);
    await t.tap(find.text('Музыка').last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 48));
    expect(t.takeException(), isNull);
    if (dir != null && dir.isNotEmpty) {
      await t.runAsync(() async {
        final rb =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await rb.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$dir/profile_tabs.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await t.pumpAndSettle();
  });
}

class _StickyHost extends StatefulWidget {
  const _StickyHost({
    required this.scroll,
    required this.inListKey,
    required this.headerBottom,
    required this.onController,
  });

  final ScrollController scroll;
  final GlobalKey inListKey;
  final double headerBottom;
  final ValueChanged<ProfileTabsController> onController;

  @override
  State<_StickyHost> createState() => _StickyHostState();
}

class _StickyHostState extends State<_StickyHost>
    with TickerProviderStateMixin {
  late final ProfileTabsController tabs = ProfileTabsController(
    vsync: this,
    length: 3,
  );

  @override
  void initState() {
    super.initState();
    widget.onController(tabs);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          controller: widget.scroll,
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 300),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ProfileTabsBar(
                key: widget.inListKey,
                controller: tabs,
                labels: _labels,
                hideWhenPinned: true,
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: widget.headerBottom,
          child: const ColoredBox(color: Colors.black26),
        ),
        Positioned(
          top: widget.headerBottom,
          left: 16,
          right: 16,
          child: ProfileStickyTabs(
            controller: tabs,
            labels: _labels,
            inListKey: widget.inListKey,
            headerBottom: widget.headerBottom,
            scroll: widget.scroll,
          ),
        ),
      ],
    );
  }
}
