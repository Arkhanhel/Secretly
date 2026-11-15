// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// П2 (разбор медиа 15.11.2026): медиа переписки на iPhone уезжают из
// «Документов» (видно в «Файлах» в обход замка) — и не теряется ни один файл.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/storage/attachment_cache_location.dart';

void main() {
  late Directory root;
  late Directory legacy;
  late Directory target;

  setUp(() {
    root = Directory.systemTemp.createTempSync('att_loc_');
    legacy = Directory(p.join(root.path, 'Documents', 'attachments'))
      ..createSync(recursive: true);
    target = Directory(p.join(root.path, 'Support', 'attachments'));
  });
  tearDown(() => root.deleteSync(recursive: true));

  File put(Directory d, String name, String body) {
    d.createSync(recursive: true);
    return File(p.join(d.path, name))..writeAsStringSync(body);
  }

  test('переносится только iPhone; ПК, Android, Mac — где были', () {
    expect(attachmentCacheLivesInAppSupport(TargetPlatform.iOS), isTrue);
    for (final other in [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(attachmentCacheLivesInAppSupport(other), isFalse, reason: '$other');
    }
  });

  test('🔴 все файлы переезжают с теми же именами и байтами; старая папка '
      'исчезает', () async {
    put(legacy, 'blobA.jpg', 'A');
    put(legacy, 'blobB.mp4', 'BBBB');
    final moved = await moveLegacyAttachmentFiles(
      legacyDir: legacy,
      targetDir: target,
    );
    expect(moved, 2);
    expect(File(p.join(target.path, 'blobA.jpg')).readAsStringSync(), 'A');
    expect(File(p.join(target.path, 'blobB.mp4')).readAsStringSync(), 'BBBB');
    expect(legacy.existsSync(), isFalse);
  });

  test('🔴 файл в обоих местах: новый не затирается; разный размер — старый '
      'откладывается, а не удаляется', () async {
    put(target, 'same.jpg', 'NEW1');
    put(legacy, 'same.jpg', 'OLD1');
    put(target, 'diff.jpg', 'NEW');
    put(legacy, 'diff.jpg', 'OLDER-AND-LONGER');
    await moveLegacyAttachmentFiles(legacyDir: legacy, targetDir: target);
    expect(File(p.join(target.path, 'same.jpg')).readAsStringSync(), 'NEW1');
    expect(File(p.join(legacy.path, 'same.jpg')).existsSync(), isFalse);
    expect(File(p.join(target.path, 'diff.jpg')).readAsStringSync(), 'NEW');
    // Разный размер: старая копия не удаляется, а уходит туда, где её не
    // видно в «Файлах»; старая папка пустеет и исчезает.
    expect(File(p.join(legacy.path, 'diff.jpg')).existsSync(), isFalse);
    expect(
      File(
        p.join(root.path, 'Support', kAttachmentCacheConflictsDirName, 'diff.jpg'),
      ).readAsStringSync(),
      'OLDER-AND-LONGER',
    );
    expect(legacy.existsSync(), isFalse);
  });

  test('по требованию: нужный файл забирается со старого места сразу', () async {
    put(legacy, 'blobC.png', 'C');
    final f = await adoptLegacyAttachmentFile(
      target: File(p.join(target.path, 'blobC.png')),
      legacyDir: legacy,
    );
    expect(f.readAsStringSync(), 'C');
    expect(File(p.join(legacy.path, 'blobC.png')).existsSync(), isFalse);
  });

  test('по требованию: нет нигде — просто «нет файла», без ошибок', () async {
    final f = await adoptLegacyAttachmentFile(
      target: File(p.join(target.path, 'none.png')),
      legacyDir: legacy,
    );
    expect(f.existsSync(), isFalse);
    final g = await adoptLegacyAttachmentFile(
      target: File(p.join(target.path, 'none.png')),
      legacyDir: null,
    );
    expect(g.existsSync(), isFalse);
  });

  test('нет старой папки — ничего не делаем', () async {
    legacy.deleteSync(recursive: true);
    expect(
      await moveLegacyAttachmentFiles(legacyDir: legacy, targetDir: target),
      0,
    );
    expect(target.existsSync(), isFalse);
  });
}
