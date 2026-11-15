// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// П4 (разбор медиа 15.11.2026): «Хранить медиа на устройстве».
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/app/app_controller.dart';

void main() {
  test('🔴 по умолчанию — всегда; чужие значения — тоже «всегда»', () {
    expect(AppController.normalizeKeepMediaDays(null), 0);
    expect(AppController.normalizeKeepMediaDays(3), 0);
    expect(AppController.normalizeKeepMediaDays(7), 7);
    expect(AppController.normalizeKeepMediaDays(30), 30);
  });

  test('удаляются только файлы старше срока, папки не трогаются', () async {
    final dir = Directory.systemTemp.createTempSync('keep_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final old = File(p.join(dir.path, 'old.jpg'))..writeAsStringSync('o');
    final fresh = File(p.join(dir.path, 'new.jpg'))..writeAsStringSync('n');
    final sub = Directory(p.join(dir.path, 'sub'))..createSync();
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 40)));
    final removed = await AppController.sweepFilesOlderThan(
      dir,
      DateTime.now().subtract(const Duration(days: 30)),
    );
    expect(removed, 1);
    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
    expect(sub.existsSync(), isTrue);
  });
}
