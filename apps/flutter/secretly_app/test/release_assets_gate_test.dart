// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 Android 1.9.0 (761) собралась без 44 стикеров: копия проекта для сборки
// держала прежние ресурсы (25.11.2026). Ресурсы догоняются всегда, а сборка
// без любого из них не выпускается.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('🔴 копия для сборки догоняет ресурсы всегда', () {
    for (final p in [
      'tools/run_sanitized_flutter.sh',
      'tools/run_ios_sanitized_build.sh',
    ]) {
      final s = File(p).readAsStringSync();
      expect(s.contains('Keeping cached assets'), isFalse, reason: p);
      expect(
        s.contains(r'rsync -a --delete "$app_dir/assets/" "$mirror_dir/assets/"'),
        isTrue,
        reason: p,
      );
      expect(s.contains(r'SECRETLY_SANITIZED_SYNC_ASSETS:-0}" != "1" ] && [ -d "$mirror_dir/assets" ]'), isFalse);
    }
  });

  test('🔴 APK, AAB и IPA проверяются на полноту ресурсов до выпуска', () {
    // В выкладке открытого репозитория сценариев выпуска может не быть.
    final android = File('../../../tools/macos_build_android_release.sh');
    final ios = File('../../../tools/macos_build_ios_release.sh');
    if (!android.existsSync() || !ios.existsSync()) return;
    final a = android.readAsStringSync();
    expect(a.contains(r'check_release_assets.py" "$source_aab"'), isTrue);
    expect(a.contains(r'check_release_assets.py" "$source_apk"'), isTrue);
    expect(
      ios.readAsStringSync().contains(r'check_release_assets.py" "$mirror_ipa"'),
      isTrue,
    );
  });

  test('🔴 проверка ловит и пропавший, и устаревший файл', () async {
    final tool = File('../../../tools/check_release_assets.py');
    if (!tool.existsSync()) return;
    final dir = await Directory.systemTemp.createTemp('assets_gate');
    addTearDown(() => dir.delete(recursive: true));
    Directory('${dir.path}/app/assets/a').createSync(recursive: true);
    File('${dir.path}/app/pubspec.yaml').writeAsStringSync(
      'name: x\nflutter:\n  assets:\n    - assets/a/\n  fonts:\n    - family: F\n',
    );
    File('${dir.path}/app/assets/a/один два.txt').writeAsStringSync('1');
    File('${dir.path}/app/assets/a/b.txt').writeAsStringSync('2');
    Future<ProcessResult> check(Map<String, String> files) async {
      final make = File('${dir.path}/make.py')
        ..writeAsStringSync(
          'import sys, zipfile\n'
          'z = zipfile.ZipFile(sys.argv[1], "w")\n'
          'for i in range(2, len(sys.argv), 2):\n'
          '    z.writestr("assets/flutter_assets/" + sys.argv[i], sys.argv[i + 1])\n'
          'z.close()\n',
        );
      final zip = '${dir.path}/x.apk';
      await Process.run('python3', [
        make.path,
        zip,
        for (final e in files.entries) ...[e.key, e.value],
      ]);
      return Process.run('python3', [tool.path, zip, '${dir.path}/app']);
    }

    final coded = 'assets/a/${Uri.encodeComponent('один два.txt')}';
    expect((await check({coded: '1', 'assets/a/b.txt': '2'})).exitCode, 0);
    final gone = await check({coded: '1'});
    expect(gone.exitCode, 1);
    expect('${gone.stdout}', contains('b.txt'));
    expect((await check({coded: '1', 'assets/a/b.txt': 'старое'})).exitCode, 1);
  });
}
