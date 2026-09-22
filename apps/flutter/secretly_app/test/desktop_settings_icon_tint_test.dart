// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Цвета значков настроек: компьютер повторяет телефон, и ни один раздел не
// остаётся серым.
//
// 🔴 ЗАЧЕМ ЭТОТ ФАЙЛ. Цвет плитки работает как второе имя раздела: с телефона
// человек помнит, что «Уведомления» красные, а «Устройства» голубые, и в окне
// находит строку, не читая её. Обещание держится ровно до первого расхождения
// — а расходятся такие числа молча: их правят в одном файле и забывают про
// другой. Здесь сверка идёт ПО ИСХОДНИКУ обоих файлов, поэтому забыть нельзя.
//
// Общего файла у палитр нет сознательно: мобильная версия выпущена и заморожена
// (правки только в `lib/ui/desktop`), и тянуть `settings_screen.dart` в
// десктопные токены значило бы связать выпущенное с недоделанным.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

/// Достаёт `static const Color <имя> = Color(0xAARRGGBB);` из исходника.
Map<String, int> _colorConstants(String src, {required String prefix}) {
  final re = RegExp(
    r'static const Color (' + prefix + r'\w+)\s*=\s*Color\(0x([0-9A-Fa-f]{8})\)',
  );
  return <String, int>{
    for (final m in re.allMatches(src))
      m.group(1)!: int.parse(m.group(2)!, radix: 16),
  };
}

void main() {
  final mobileSrc = File('lib/ui/settings_screen.dart').readAsStringSync();
  final desktopSrc =
      File('lib/ui/desktop/workspace/settings_workspace.dart').readAsStringSync();

  test('🔴 семь цветов значков совпадают с телефоном поимённо', () {
    final phone = _colorConstants(mobileSrc, prefix: '_icon');
    // Телефон объявляет их как `_iconBlue`, `_iconOrange`… — отрезаем `_icon`
    // и сверяем с одноимённым полем десктопной палитры.
    const pairs = <String, Color>{
      '_iconBlue': DIconTint.blue,
      '_iconOrange': DIconTint.orange,
      '_iconGreen': DIconTint.green,
      '_iconRed': DIconTint.red,
      '_iconPurple': DIconTint.purple,
      '_iconCyan': DIconTint.cyan,
      '_iconAmber': DIconTint.amber,
    };
    for (final e in pairs.entries) {
      expect(
        phone[e.key],
        isNotNull,
        reason: 'на телефоне пропал ${e.key} — значит, палитру там правили, '
            'и десктопную надо править следом',
      );
      expect(
        e.value.toARGB32(),
        phone[e.key],
        reason: '${e.key} разошёлся: телефон '
            '0x${phone[e.key]!.toRadixString(16)}, окно '
            '0x${e.value.toARGB32().toRadixString(16)}',
      );
    }
  });

  test('🔴 у КАЖДОГО раздела настроек есть свой цвет', () {
    // Раздел без `tint` рисуется голым серым значком — в списке из семнадцати
    // цветных строк одна серая читается как сломанная, а не как «без цвета».
    // Только объявления разделов: `id:` встречается в файле и у обоев
    // («default»), и сверка по всему файлу ловила бы чужое.
    final start = desktopSrc.indexOf('List<WorkspaceSection> _sections(');
    expect(start, greaterThan(0));
    final body = desktopSrc.substring(start, desktopSrc.indexOf('\nclass _SignOutRow'));
    final ids = RegExp(r"^\s+id: '([a-z]+)',$", multiLine: true)
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toList();
    expect(ids.length, greaterThanOrEqualTo(17),
        reason: 'разделы перестали объявляться однострочным id — проверка '
            'ослепла, её надо чинить, а не удалять');
    for (final id in ids) {
      expect(
        RegExp("id: '$id',\\s*\\n(\\s*//[^\\n]*\\n)*\\s*tint: ")
            .hasMatch(body),
        isTrue,
        reason: 'раздел «$id» объявлен без tint',
      );
    }
  });

  test('🔴 колонка содержимого ограничена по ширине', () {
    // Без предела страница настроек растягивается на всю ширину окна: на
    // мониторе 3440 точек между подписью и переключателем остаётся полметра
    // пустоты. См. комментарий у `contentMaxWidth`.
    expect(desktopSrc.contains('contentMaxWidth: 760,'), isTrue);
  });
}
