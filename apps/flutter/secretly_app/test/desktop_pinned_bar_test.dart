// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · Закреплённое — ОСТРОВОК синей плёнки, а не полоса во всю ширину.
//
// ЧТО БЫЛО. Сперва полоса красилась `elevated` — тем же тоном, что баннер
// поиска и всплывающие карточки, — и под шапкой читалась как «ещё одна
// полоска интерфейса». Синяя плёнка это поправила, но форма осталась полосой:
// закреплённое по-прежнему выглядело частью оконной обвязки, а не сообщением,
// которое кто-то поднял НАД разговором.
//
// Островок ставит его в один ряд с плашкой созвона сверху: обе одной формы и
// разного цвета по смыслу — синий «закреплено», зелёный «говорят». Полосы во
// всю ширину остались только у настоящей обвязки: шапки, полосы тем, поиска.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

void main() {
  final panel = File(
    'lib/ui/desktop/chat/chat_thread_panel.dart',
  ).readAsStringSync();

  test('· островок: плёнка в 8 %, скругление и поля', () {
    final i = panel.indexOf('class _PinnedBar');
    final body = panel.substring(i, (i + 2600).clamp(0, panel.length));
    expect(body.contains('c.accentPrimary.withValues(alpha: 0.08)'), isTrue);
    expect(body.contains('color: c.elevated,'), isFalse);
    expect(body.contains('BorderRadius.circular(DRadii.lg)'), isTrue);
    expect(
      body.contains('EdgeInsets.fromLTRB(DSpace.l, DSpace.m, DSpace.l, 0)'),
      isTrue,
      reason: 'те же поля, что у островка созвона над ним',
    );
    // Полосы во всю ширину больше нет: нижняя черта ушла вместе с ней.
    expect(body.contains('border: Border(\n          bottom:'), isFalse);
  });

  test('🔴 «1 из 2» и стрелки «следующее» нет: закреплённое ОДНО', () {
    // В настройках комнаты лежит одно поле `pinned_message_event_id`, второго
    // не бывает ни на телефоне, ни на сервере. Счётчик и стрелка из макета
    // обещали бы список, которого нет.
    final code = panel
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code.contains('из 2'), isFalse);
    expect(code.contains('expand_more'), isFalse);
    // Вместо стрелки — настоящее действие, и только тому, кому комната его
    // позволяет.
    expect(panel.contains("tooltip: 'Открепить'"), isTrue);
    expect(panel.contains('if (onUnpin != null)'), isTrue);
  });

  test('островок созвона той же формы, что закреплённое', () {
    // Переход у одного островка и ровный тон у соседнего читались бы как два
    // разных вида плашек.
    final banner = File(
      'lib/ui/desktop/chat/room_call_banner.dart',
    ).readAsStringSync();
    expect(banner.contains('BorderRadius.circular(DRadii.lg)'), isTrue);
    expect(banner.contains('color: c.success.withValues(alpha: 0.12)'), isTrue);
    expect(banner.contains('gradient: LinearGradient'), isFalse);
    expect(
      banner.contains('EdgeInsets.fromLTRB(DSpace.l, DSpace.m, DSpace.l, 0)'),
      isTrue,
    );
  });

  test('🔴 подпись светлее заливки, а не тем же акцентом', () {
    // Сам `accentPrimary` на своей же заливке в 8 % почти сливается с ней:
    // это цвет для сплошного, а не для текста поверх собственной тени.
    final i = panel.indexOf("'Закреплённое сообщение'");
    final body = panel.substring(i, i + 420);
    expect(body.contains('color: c.accentSoft'), isTrue);
    expect(body.contains('fontSize: 11.5'), isTrue);
    expect(body.contains('fontWeight: FontWeight.w700'), isTrue);
  });

  test('светлый акцент — токен, а не хекс на месте', () {
    expect(kDColorsDark.accentSoft.toARGB32(), 0xFF9AC5FA);
    // И в светлой теме он свой: там светлее фона не бывает.
    expect(kDColorsLight.accentSoft == kDColorsDark.accentSoft, isFalse);
  });
}
