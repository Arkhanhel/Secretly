// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Чат под скрепкой — неподвижной картинкой (25.11.2026, замер iPhone 14).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_attachment_picker_sheet.dart'
    show kSheetGridTop, kSheetHeaderHeight, kSheetHeaderTop;
import 'package:secretly_app/ui/widgets/secretly_glass_sheet.dart';
import 'package:secretly_app/ui/widgets/still_under_sheet.dart';

class _Painted extends CustomPainter {
  _Painted(this.onPaint, {super.repaint});
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) => onPaint();
  @override
  bool shouldRepaint(_Painted old) => true;
}

void main() {
  testWidgets('🔴 под листом страница не рисуется и анимации стоят; '
      'обновление снимает заново; после — снова живая', (t) async {
    final c = StillUnderSheetController();
    var paints = 0;
    final anim = AnimationController(
      vsync: t,
      duration: const Duration(seconds: 1),
    );
    var builds = 0;
    await t.pumpWidget(
      MaterialApp(
        home: StillUnderSheet(
          controller: c,
          child: Builder(
            builder: (context) {
              builds++;
              return Stack(
                children: [
                  const CircularProgressIndicator(),
                  CustomPaint(
                    size: const Size(50, 50),
                    painter: _Painted(() => paints++, repaint: anim),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    anim.repeat();
    await t.pump(const Duration(milliseconds: 16));
    final live = paints;
    await t.pump(const Duration(milliseconds: 16));
    expect(paints, greaterThan(live), reason: 'без листа — живая');

    c.freeze();
    await t.pump(const Duration(milliseconds: 16));
    final frozen = paints;
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(paints, frozen, reason: 'под листом рисуется только картинка');
    expect(
      TickerMode.valuesOf(
        t.element(find.byType(CircularProgressIndicator)),
      ).enabled,
      isFalse,
    );
    expect(builds, 1, reason: 'заморозка не перестраивает страницу');

    c
      ..refresh()
      ..refresh();
    await t.pump(const Duration(milliseconds: 450));
    await t.pump();
    expect(paints, frozen + 1, reason: 'сто изменений — один новый снимок');

    c.thaw();
    await t.pump(const Duration(milliseconds: 16));
    final again = paints;
    await t.pump(const Duration(milliseconds: 16));
    expect(paints, greaterThan(again));
    anim.dispose();
    await t.pumpWidget(const SizedBox());
    c.dispose();
    c
      ..freeze()
      ..refresh()
      ..thaw();
  });

  testWidgets('🔴 лист скрепки — без размытия на весь экран', (t) async {
    Widget sheet(bool solid) => MaterialApp(
      home: SecretlyGlassSheetSurface(
        solid: solid,
        child: const SizedBox.expand(),
      ),
    );
    await t.pumpWidget(sheet(false));
    expect(find.byType(BackdropFilter), findsOneWidget);
    await t.pumpWidget(sheet(true));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  test('🔴 подключено: чат замирает под скрепкой и оживает при любом исходе', () {
    final s = File('lib/ui/chat_screen.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _attach() async {');
    final body = s.substring(at, at + 2400);
    expect(body.contains('_underSheet.freeze();'), isTrue);
    expect(body.contains('onSettled: _underSheet.freeze,'), isTrue);
    expect(body.contains('} finally {\n      _underSheet.thaw();'), isTrue);
    expect(s.contains('child: StillUnderSheet(\n      controller: _underSheet,'), isTrue);
    final p = File('lib/ui/chat_attachment_picker_sheet.dart').readAsStringSync();
    expect(p.contains('flushToEdges: true,\n          solid: true,'), isTrue);
    expect(p.contains('widget.onSettled?.call();'), isTrue);
  });

  test('🔴 в шапке скрепки нет «закрыть», снимки ближе к краю', () {
    final p = File('lib/ui/chat_attachment_picker_sheet.dart').readAsStringSync();
    final at = p.indexOf('Widget _buildSheetHeader() {');
    final header = p.substring(at, p.indexOf('Widget _buildAlbumsMenu()'));
    expect(header.contains('AppIcons.close'), isFalse);
    expect(header.contains('cancelButtonLabel'), isFalse);
    expect(header.contains("ValueKey('sendflow:albums')"), isTrue);
    expect(kSheetGridTop, lessThanOrEqualTo(46), reason: 'было 66');
    expect(kSheetGridTop, greaterThanOrEqualTo(kSheetHeaderTop + kSheetHeaderHeight));
    // Закрыть по-прежнему можно: смахнуть, коснуться мимо, «назад».
    final show = p.substring(p.indexOf('showChatAttachmentPickerSheet('));
    expect(show.contains('isDismissible: true'), isTrue);
    expect(show.contains('enableDrag: true'), isTrue);
  });
}
