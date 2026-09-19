// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · Метрики ленты, сверенные с макетом.
//
// Четыре числа, каждое само по себе «·», но вместе они и есть ощущение, что
// лента «не та»: пузырь у края, дата обведена как кнопка, чужое сообщение
// ломается раньше своего.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/radii.dart';
import 'package:secretly_app/ui/desktop/design/spacing.dart';

void main() {
  test('· боковой отступ ленты — 24, а не 20', () {
    // Пузырь стоял ближе к краю окна, чем к соседнему столбцу, и лента
    // читалась прижатой.
    final src = File(
      'lib/ui/desktop/chat/message_bubble.dart',
    ).readAsStringSync();
    expect(DSpace.xl2, 24);
    expect(src.contains('        DSpace.xl2,\n        m.continuation'), isTrue);
    expect(src.contains('          DSpace.xl2,\n          m.continuation'), isTrue);
  });

  test('· чужой пузырь шире своего: 660 против 600', () {
    expect(kBubbleMaxWidthSelf, 600);
    expect(kBubbleMaxWidthPeer, 660);
  });

  test('· у разделителя даты нет рамки', () {
    // Рамка поверх заливки делала из даты кнопку: в ленте, где ничего больше
    // не обведено, обводка читается как «сюда можно нажать».
    final panel = File(
      'lib/ui/desktop/chat/chat_thread_panel.dart',
    ).readAsStringSync();
    final i = panel.indexOf('class _DateSeparator');
    // Окно по числу знаков сползало от добавленных строк: берём весь класс.
    final next = panel.indexOf('\nclass ', i + 1);
    final body = panel.substring(i, next < 0 ? panel.length : next);
    expect(body.contains('border: Border.all(color: palette.borderSubtle)'), isFalse);
    expect(body.contains('Colors.white.withValues(alpha: 0.05)'), isTrue);
    expect(body.contains('BorderRadius.circular(DRadii.r9)'), isTrue);
    expect(DRadii.r9, 9);
  });

  test('· плитка значка в плашке созвона — радиус 12', () {
    final banner = File(
      'lib/ui/desktop/chat/room_call_banner.dart',
    ).readAsStringSync();
    expect(banner.contains('BorderRadius.circular(DRadii.r12)'), isTrue);
    expect(DRadii.r12, 12);
  });
}
