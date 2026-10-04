// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 FFMPEG У ПК — ПОД GPL, И ЭТО СКАЗАНО ВЕЗДЕ, КУДА ОН ЕДЕТ (30.09.2026).
//
// В сборку едет FFmpegKit «full-gpl» (x264, Xvid, vid.stab), а экран лицензий
// показывал только LGPL из пакета; в сборке Windows не было ни текста GPL,
// ни сведений об исходниках.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/desktop/ffmpeg_license.dart';

void main() {
  final notice = File('licenses/ffmpeg/FFmpeg-NOTICE.txt');
  final gpl = File('licenses/ffmpeg/FFmpeg-COPYING.GPLv3.txt');

  test('🔴 экран лицензий показывает ровно те тексты, что едут в сборку', () {
    expect(kFfmpegNoticeText, notice.readAsStringSync());
    expect(kGplV3LicenseText, gpl.readAsStringSync());
  });

  test('текст GPL — дословно с gnu.org', () {
    expect(
      sha256.convert(gpl.readAsBytesSync()).toString(),
      '3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986',
    );
  });

  test('🔴 уведомление: лицензия, что именно едет, исходники, куда писать', () {
    final s = notice.readAsStringSync();
    for (final must in const [
      'GNU General Public License, version 3',
      'FFmpeg 8.0',
      'ffmpeg_kit_flutter_new 4.2.1',
      'releases/tag/8.0.0-full-gpl\n',
      'releases/tag/8.0.0-full-gpl-windows',
      'https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz',
      'legal@secretlyapp.com',
    ]) {
      expect(s, contains(must));
    }
  });

  test('версии в уведомлении — те, что собираются', () {
    final lock = File('pubspec.lock').readAsStringSync();
    expect(
      RegExp(
        r'ffmpeg_kit_flutter_new:[^\n]*\n(?:\s+[^\n]*\n)*?\s+version: "4\.2\.1"',
      ).hasMatch(lock),
      isTrue,
      reason: 'поднимете пакет — поправьте licenses/ffmpeg/FFmpeg-NOTICE.txt',
    );
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    expect(cmake, contains('set(FFMPEGKIT_VARIANT "full-gpl")'));
    expect(cmake, contains('set(FFMPEGKIT_RELEASE "8.0.0")'));
  });

  test('🔴 оба файла едут в сборку Windows и в Resources на Mac', () {
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    expect(cmake, contains('/../licenses/ffmpeg/FFmpeg-NOTICE.txt"'));
    expect(cmake, contains('/../licenses/ffmpeg/FFmpeg-COPYING.GPLv3.txt"'));
    expect(cmake, contains(r'DESTINATION "${CMAKE_INSTALL_PREFIX}/licenses"'));
    final pbx = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(pbx, contains('/* FFmpeg-NOTICE.txt in Resources */,'));
    expect(pbx, contains('/* FFmpeg-COPYING.GPLv3.txt in Resources */,'));
  });

  test(
    'запись экрана лицензий — FFmpeg и пакет, с текстом GPL; только ПК',
    () async {
      LicenseRegistry.reset();
      addTearDown(LicenseRegistry.reset);
      registerDesktopFfmpegLicense();

      final entries = await LicenseRegistry.licenses.toList();
      expect(entries, hasLength(1));
      expect(
        entries.single.packages,
        containsAll(<String>['FFmpeg', 'ffmpeg_kit_flutter_new']),
      );
      final text = entries.single.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('GNU GENERAL PUBLIC LICENSE'));
      expect(text, contains('legal@secretlyapp.com'));

      expect(
        File('lib/main_desktop.dart').readAsStringSync(),
        contains('registerDesktopFfmpegLicense();'),
      );
      expect(
        File('lib/main.dart').readAsStringSync(),
        isNot(contains('ffmpeg_license')),
        reason: 'телефон заморожен',
      );
    },
  );
}
