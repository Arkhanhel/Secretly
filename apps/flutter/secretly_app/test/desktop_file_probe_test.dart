// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 НАЛИЧИЕ ФАЙЛА НЕ СПРАШИВАЕТСЯ У ДИСКА НА КАЖДУЮ ПЕРЕРИСОВКУ (01.10.2026).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_file_probe.dart';

void main() {
  late Directory dir;
  var now = 0;

  setUp(() {
    DesktopFileProbe.reset();
    now = 1000;
    DesktopFileProbe.nowMs = () => now;
    dir = Directory.systemTemp.createTempSync('probe');
  });

  tearDown(() {
    DesktopFileProbe.reset();
    dir.deleteSync(recursive: true);
  });

  test('ответ помнится: сотня перерисовок — одно обращение к диску', () {
    final f = File('${dir.path}/a.jpg')..writeAsStringSync('x');
    for (var i = 0; i < 100; i++) {
      expect(DesktopFileProbe.exists(f.path), isTrue);
    }
    expect(DesktopFileProbe.diskChecks, 1);
  });

  test('«нет» живёт недолго: докачанный файл виден через пару секунд', () {
    final f = File('${dir.path}/late.jpg');
    expect(DesktopFileProbe.exists(f.path), isFalse);
    f.writeAsStringSync('x');
    expect(DesktopFileProbe.exists(f.path), isFalse, reason: 'ещё помнится');
    now += DesktopFileProbe.missingFor.inMilliseconds;
    expect(DesktopFileProbe.exists(f.path), isTrue);
  });

  test('«есть» тоже истекает: удалённый файл перестаёт числиться', () {
    final f = File('${dir.path}/gone.jpg')..writeAsStringSync('x');
    expect(DesktopFileProbe.exists(f.path), isTrue);
    f.deleteSync();
    now += DesktopFileProbe.presentFor.inMilliseconds;
    expect(DesktopFileProbe.exists(f.path), isFalse);
  });

  test('forget заставляет спросить диск сразу', () {
    final f = File('${dir.path}/b.jpg');
    expect(DesktopFileProbe.exists(f.path), isFalse);
    f.writeAsStringSync('x');
    DesktopFileProbe.forget(f.path);
    expect(DesktopFileProbe.exists(f.path), isTrue);
  });

  test('пустой путь — нет, и диск не трогается', () {
    expect(DesktopFileProbe.exists('  '), isFalse);
    expect(DesktopFileProbe.diskChecks, 0);
  });

  test('в build горячих мест больше нет existsSync', () {
    for (final path in <String>[
      'lib/ui/desktop/primitives/avatar.dart',
      'lib/ui/desktop/chat/room_invite_card.dart',
      'lib/ui/desktop/chat/new_chat_picker.dart',
      'lib/ui/desktop/chat/desktop_wallpaper.dart',
      'lib/ui/desktop/chat/details/room_details_view.dart',
      'lib/ui/desktop/chat/details/contact_details_view.dart',
    ]) {
      expect(
        File(path).readAsStringSync().contains('existsSync()'),
        isFalse,
        reason: path,
      );
    }
  });
}
