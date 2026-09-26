// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Длина путей ресурсов после установки на Windows (26.09.2026).
//
// Flutter кладёт ресурсы на диск под именами в кодировке URL: значок
// «icons8-конфиденциальность.svg» превращается в 119 знаков вида %D0%BA….
// Windows без включённых длинных путей не открывает и не создаёт файлы длиннее
// 259 знаков. Первая сборка установщика упала именно на этом, хотя в папке CI
// путь был всего на знак длиннее предела.
//
// Установщик ставит программу в %LOCALAPPDATA%\Programs\Secretly. Самый длинный
// префикс у человека — `C:\Users\` + 20 знаков имени (предел Windows для имени
// учётной записи) + `\AppData\Local\Programs\Secretly\data\flutter_assets\`.
// Тест не даёт добавить ресурс, который в таком месте не поместится.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('🔴 путь каждого ресурса после установки на Windows ≤ 259 знаков', () {
    const installedPrefix =
        r'C:\Users\' '12345678901234567890' r'\AppData\Local\Programs\Secretly\data\flutter_assets\';
    const maxPath = 259;
    final tooLong = <String>[];
    var longest = 0;
    for (final entity in Directory('assets').listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = entity.path.replaceAll(r'\', '/');
      final onDisk = Uri.encodeFull(relative);
      final total = installedPrefix.length + onDisk.length;
      if (total > longest) longest = total;
      if (total > maxPath) tooLong.add('$total  $relative');
    }
    expect(longest, greaterThan(installedPrefix.length),
        reason: 'ресурсы не найдены — тест ничего не проверил');
    expect(
      tooLong,
      isEmpty,
      reason: 'Эти ресурсы не поместятся в путь Windows после установки. '
          'Дайте файлу короткое латинское имя.',
    );
  });
}
