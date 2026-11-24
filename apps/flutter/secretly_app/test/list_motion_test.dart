// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// М3: список чатов. Новая строка вырастает, поднявшаяся — переезжает,
// смена папки (много изменений) и первая загрузка — без анимации.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/motion/list_motion.dart';

class _Host extends StatefulWidget {
  const _Host({required this.ctrl, required this.ids});
  final ListMotionController ctrl;
  final List<String> ids;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    widget.ctrl.update(widget.ids);
    return MaterialApp(
      home: ListView.builder(
        itemCount: widget.ids.length,
        findChildIndexCallback: (key) => key is ValueKey<String>
            ? widget.ctrl.indexOf(key.value)
            : null,
        itemBuilder: (context, i) => ListMotionItem(
          key: ValueKey<String>(widget.ids[i]),
          controller: widget.ctrl,
          id: widget.ids[i],
          child: SizedBox(height: 60, child: Text(widget.ids[i])),
        ),
      ),
    );
  }
}

double _y(WidgetTester t, String id) => t.getTopLeft(find.text(id)).dy;

void main() {
  testWidgets('чат поднялся наверх — переезжает, а не прыгает', (t) async {
    final ctrl = ListMotionController();
    await t.pumpWidget(_Host(ctrl: ctrl, ids: const ['a', 'b', 'c', 'd']));
    expect(_y(t, 'd'), 180);
    await t.pumpWidget(_Host(ctrl: ctrl, ids: const ['d', 'a', 'b', 'c']));
    // Первый кадр: «d» ещё на старом месте, «a» — на своём.
    expect(_y(t, 'd'), closeTo(180, 0.5));
    expect(_y(t, 'a'), closeTo(0, 0.5));
    await t.pump(const Duration(milliseconds: 150));
    expect(_y(t, 'd'), inExclusiveRange(0, 180));
    await t.pumpAndSettle();
    expect(_y(t, 'd'), 0);
    expect(_y(t, 'a'), 60);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('новый чат вырастает по высоте', (t) async {
    final ctrl = ListMotionController();
    await t.pumpWidget(_Host(ctrl: ctrl, ids: const ['a', 'b']));
    await t.pumpWidget(_Host(ctrl: ctrl, ids: const ['n', 'a', 'b']));
    await t.pump(const Duration(milliseconds: 100));
    // Строка «n» ещё не во всю высоту — «a» ниже 0, но выше 60.
    expect(_y(t, 'a'), inExclusiveRange(0, 60));
    await t.pumpAndSettle();
    expect(_y(t, 'a'), 60);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('смена папки и первая загрузка — без анимации', (t) async {
    final ctrl = ListMotionController();
    await t.pumpWidget(_Host(ctrl: ctrl, ids: const ['a', 'b']));
    expect(_y(t, 'b'), 60);
    final many = [for (var i = 0; i < 10; i++) 'x$i', 'b'];
    await t.pumpWidget(_Host(ctrl: ctrl, ids: many));
    await t.pump();
    expect(_y(t, 'x0'), 0);
    expect(_y(t, 'x1'), 60);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('🔴 компьютер — без обёрток', (t) async {
    final ctrl = ListMotionController();
    await t.pumpWidget(_Host(ctrl: ctrl, ids: const ['a']));
    expect(
      find.descendant(
        of: find.byType(ListMotionItem),
        matching: find.byType(FractionalTranslation),
      ),
      findsNothing,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
