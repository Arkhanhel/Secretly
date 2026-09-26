// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 16 КБ (26.09.2026): Google Play отклонил 1.8.61 (630) — встроенный плагин
/// whisper с 06.09 собирал ggml, whisper и parakeet с выравниванием 4 КБ.
/// Держит это флаг в CMake плагина; сборочный скрипт проверяет готовый бандл,
/// а этот тест — что флаг не потерялся при следующем обновлении плагина.
void main() {
  test('🔴 плагин whisper: max-page-size=16384 для Android до add_subdirectory',
      () {
    final cmake = File(
      'third_party/whisper_cpp_flutter_plus/CMakeLists.txt',
    ).readAsStringSync();
    final flag = cmake.indexOf('-Wl,-z,max-page-size=16384');
    final sub = cmake.indexOf('add_subdirectory(');
    expect(flag, greaterThan(0));
    expect(sub, greaterThan(flag), reason: 'флаг обязан дойти до ggml/whisper');
    final block = cmake.substring(cmake.lastIndexOf('if(ANDROID)', flag), flag);
    expect(block.contains('CMAKE_SHARED_LINKER_FLAGS'), isTrue);
  });

  test('сборочный скрипт Android проверяет 16 КБ и бандла, и APK', () {
    final script = File('../../../tools/macos_build_android_release.sh');
    // В публичной выкладке сборочных скриптов нет — там проверять нечего.
    if (!script.existsSync()) return;
    final sh = script.readAsStringSync();
    expect('check_16kb_alignment.py'.allMatches(sh).length, 2);
    expect(File('../../../tools/check_16kb_alignment.py').existsSync(), isTrue);
  });
}
