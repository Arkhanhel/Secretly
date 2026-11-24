// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Единое меню iPhone: открывается у кнопки, целиком внутри безопасной зоны
// на маленьком, обычном и большом экране и на iPad; выбор возвращается;
// на Android — прежнее меню Material. Окна (showAppDialog) открываются и
// закрываются. `SECRETLY_SHOTS=папка` — снимки.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/motion/app_dialogs.dart';
import 'package:secretly_app/ui/widgets/apple_menu.dart';

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
    final b = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _sizes = <(String, Size, EdgeInsets)>[
  ('se', Size(320, 568), EdgeInsets.only(top: 20)),
  ('pro', Size(393, 852), EdgeInsets.only(top: 59, bottom: 34)),
  ('max', Size(440, 956), EdgeInsets.only(top: 62, bottom: 34)),
  ('ipad', Size(1024, 1366), EdgeInsets.only(top: 24, bottom: 20)),
];

String? _picked;

Widget _app(Brightness b, Alignment buttonAt) => MaterialApp(
  theme: ThemeData(brightness: b, fontFamily: 'Inter'),
  builder: (context, child) => RepaintBoundary(key: _shotKey, child: child),
  home: Scaffold(
    backgroundColor: b == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF2F2F7),
    body: SafeArea(
      child: Align(
        alignment: buttonAt,
        child: AppPopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz),
          onSelected: (v) => _picked = v,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'mute', child: Text('Без звука')),
            PopupMenuItem(value: 'pin', child: Text('Закрепить')),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Text('Удалить чат', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(_loadFonts);

  for (final (tag, size, pad) in _sizes) {
    for (final at in [Alignment.topRight, Alignment.bottomLeft]) {
      testWidgets('меню iPhone внутри экрана ($tag, $at)', (t) async {
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        t.view.padding = FakeViewPadding(
          top: pad.top * 3,
          bottom: pad.bottom * 3,
        );
        addTearDown(t.view.reset);
        _picked = null;
        await t.pumpWidget(_app(Brightness.dark, at));
        await t.tap(find.byIcon(Icons.more_horiz));
        await t.pumpAndSettle();
        final panel = t.getRect(find.byType(AppleMenuPanel));
        expect(panel.left, greaterThanOrEqualTo(8 - 0.01));
        expect(panel.right, lessThanOrEqualTo(size.width - 8 + 0.01));
        expect(panel.top, greaterThanOrEqualTo(pad.top + 8 - 0.01));
        expect(
          panel.bottom,
          lessThanOrEqualTo(size.height - pad.bottom - 8 + 0.01),
        );
        expect(panel.width, inInclusiveRange(200, 280));
        await _shoot(t, 'menu_${tag}_${at.x > 0 ? 'tr' : 'bl'}');
        await t.tap(find.text('Закрепить'));
        await t.pumpAndSettle();
        expect(_picked, 'pin');
        expect(find.byType(AppleMenuPanel), findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }

  testWidgets('меню iPhone, светлая тема и крупный шрифт', (t) async {
    t.view.physicalSize = const Size(393, 852) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_app(Brightness.light, Alignment.topRight));
    await t.tap(find.byIcon(Icons.more_horiz));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await _shoot(t, 'menu_light_bigtext');
    await t.tapAt(const Offset(20, 800));
    await t.pumpAndSettle();
    expect(find.byType(AppleMenuPanel), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android — прежнее меню Material', (t) async {
    await t.pumpWidget(_app(Brightness.dark, Alignment.topRight));
    await t.tap(find.byIcon(Icons.more_horiz));
    await t.pumpAndSettle();
    expect(find.byType(AppleMenuPanel), findsNothing);
    expect(find.text('Закрепить'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('окно открывается и закрывается ($p)', (t) async {
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold();
            },
          ),
        ),
      );
      final f = showAppDialog<bool>(
        context: ctx,
        builder: (c) => AlertDialog(
          title: const Text('Удалить?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Да'),
            ),
          ],
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final mid = t.widget<Opacity>(
        find.ancestor(of: find.byType(AlertDialog), matching: find.byType(Opacity)).first,
      );
      expect(mid.opacity, inExclusiveRange(0, 1));
      await t.pumpAndSettle();
      await t.tap(find.text('Да'));
      await t.pumpAndSettle();
      expect(await f, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    }, variant: TargetPlatformVariant.only(p));
  }

  for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('выпадающий список ($p)', (t) async {
      int? value = 30;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, set) => AppDropdownButton<int>(
                  value: value,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Сразу')),
                    DropdownMenuItem(value: 30, child: Text('30 секунд')),
                    DropdownMenuItem(value: 60, child: Text('1 минута')),
                  ],
                  onChanged: (v) => set(() => value = v),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('30 секунд'), findsOneWidget);
      await t.tap(find.text('30 секунд'));
      await t.pumpAndSettle();
      if (p == TargetPlatform.iOS) {
        expect(find.byType(AppleMenuPanel), findsOneWidget);
      }
      await t.tap(find.text('1 минута').last);
      await t.pumpAndSettle();
      expect(value, 60);
      expect(find.text('1 минута'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(p));
  }
}
