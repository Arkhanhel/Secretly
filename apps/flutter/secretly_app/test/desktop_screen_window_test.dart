// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 МОБИЛЬНЫЕ ЭКРАНЫ НА ПК — ОКНОМ ПОСЕРЕДИНЕ (30.09.2026, ТЗ «ПК как
// Telegram» §8): «Создать группу», «Вступить», сверка кодов, набор
// восстановления открывались во всё окно приложения.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_screen_window.dart';

/// Экран «как на телефоне»: своя полоса и кнопка «Готово» с ответом.
class _PhoneScreen extends StatelessWidget {
  const _PhoneScreen();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Новая группа')),
      body: Column(
        children: [
          Text('ширина ${size.width.round()}'),
          TextButton(
            onPressed: () => Navigator.of(context).pop('group:new'),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

void main() {
  late Future<String?> result;

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () => result = showDesktopScreenWindow<String>(
                    ctx,
                    builder: (_) => const _PhoneScreen(),
                  ),
                  child: const Text('открыть'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();
  }

  testWidgets('окно посередине, экран видит размер окна, а не приложения', (
    t,
  ) async {
    await open(t);
    final rect = t.getRect(find.byType(_PhoneScreen));
    expect(rect.width, 520);
    expect(rect.center.dx, closeTo(800, 1));
    expect(find.text('ширина 520'), findsOneWidget);
    // Приложение под окном не пропало — оно затемнено, а не заменено.
    expect(find.text('открыть', skipOffstage: false), findsOneWidget);
  });

  testWidgets('крестик, а не стрелка назад', (t) async {
    await open(t);
    expect(find.byType(CloseButton), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    expect(find.byType(_PhoneScreen), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('ответ экрана — ответ окна', (t) async {
    await open(t);
    await t.tap(find.text('Готово'));
    await t.pumpAndSettle();
    expect(await result, 'group:new');
  });

  testWidgets('Escape закрывает окно', (t) async {
    await open(t);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(_PhoneScreen), findsNothing);
  });

  test('на ПК мобильные экраны не открываются во всё окно', () {
    const screens = [
      'NewGroupScreen',
      'RoomInviteJoinScreen',
      'VerifyContactScreen',
      'RecoveryKitScreen',
    ];
    final files = Directory('lib/ui/desktop')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final name in screens) {
        final fullPage = RegExp(
          'MaterialPageRoute<[^>]*>\\(\\s*builder: \\(_\\) => $name\\(',
        );
        expect(
          fullPage.hasMatch(src),
          isFalse,
          reason: '${f.path}: $name — через showDesktopScreenWindow',
        );
      }
    }
  });
}
