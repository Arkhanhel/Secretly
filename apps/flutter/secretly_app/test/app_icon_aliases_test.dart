// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 Значок приложения на Android — это activity-alias. Выбор значка выключает
// все остальные alias, и Android помнит это и после обновления. Если сборка
// (в том числе откатная!) лишится alias выбранного значка, у человека
// пропадёт ярлык запуска, а кнопка «Открыть» в Play перестанет работать.
// Поэтому: набор только растёт, и каждый вариант из списка есть везде —
// в манифесте, в MainActivity, в каталоге значков iOS и в настройках сборки.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/premium/app_icon_picker.dart';

String _cap(String s) => '${s[0].toUpperCase()}${s.substring(1)}';

final bool _rastersShipped =
    File('assets/app_ui/icons/Settings/w11-notifications.png').existsSync();

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final activity = File(
    'android/app/src/main/kotlin/com/secretly/secretly_app/MainActivity.kt',
  ).readAsStringSync();
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  test('the alias set never shrinks (rollback safety)', () {
    // Выпущенные варианты. Удалять отсюда нельзя — только добавлять.
    const shipped = <String>[
      'default',
      'midnight',
      'ocean',
      'sunset',
      'emerald',
      'graphite',
      'light',
    ];
    final keys = kAppIconOptions.map((o) => o.key).toSet();
    for (final k in shipped) {
      expect(keys, contains(k), reason: 'icon "$k" was removed');
    }
  });

  for (final option in kAppIconOptions) {
    final key = option.key;
    test('icon "$key" exists on Android and iOS', () {
      expect(
        manifest.contains('android:name=".MainActivity${_cap(key)}"'),
        isTrue,
        reason: 'no activity-alias for $key',
      );
      expect(
        activity.contains('"$key" to "MainActivity${_cap(key)}"'),
        isTrue,
        reason: 'MainActivity does not know $key',
      );
      // Превью значка — растр; в открытом репозитории растров нет (белый
      // список выкладки), там проверка молчит по отсутствию самих файлов.
      if (_rastersShipped) expect(File(option.asset).existsSync(), isTrue);
      if (key == 'default') return;
      final set = Directory(
        'ios/Runner/Assets.xcassets/AltIcon${_cap(key)}.appiconset',
      );
      expect(set.existsSync(), isTrue, reason: 'no iOS icon set for $key');
      // Без этой настройки Xcode не кладёт запасные значки в приложение, и
      // setAlternateIconName молча отказывает (так было до 20.11.2026).
      final line = RegExp(
        r'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "([^"]*)"',
      ).allMatches(pbx).toList();
      expect(line.length, 3, reason: 'all three Runner configurations');
      for (final m in line) {
        expect(m.group(1)!.split(' '), contains('AltIcon${_cap(key)}'));
      }
    });
  }
}
