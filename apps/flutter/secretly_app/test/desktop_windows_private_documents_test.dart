// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Windows: «Документы» приложения — в его папке, прежнее переносится один раз.
//
// 🔴 ЗАЧЕМ (30.09.2026). path_provider на Windows отвечает общими
// «Документами» человека, и туда ложились расшифрованные вложения и фото
// контактов с ID профилей в именах — а «Документы» синхронизирует OneDrive.
// Проверяется главное: переносится ТОЛЬКО созданное Secretly, чужие файлы
// человека не трогаются, повторный запуск ничего не делает, а на других
// системах подмены нет вовсе.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secretly_app/desktop/windows_private_documents.dart';

class _FakePlatform extends PathProviderPlatform {
  _FakePlatform({required this.support, required this.docs});

  final String support;
  final String docs;

  @override
  Future<String?> getApplicationSupportPath() async => support;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;

  @override
  Future<String?> getTemporaryPath() async => p.join(support, 'tmp');
}

void main() {
  late Directory root;
  late PathProviderPlatform original;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('secretly_docs_move_');
    original = PathProviderPlatform.instance;
  });

  tearDown(() async {
    PathProviderPlatform.instance = original;
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> put(String path, [String body = 'x']) async {
    final f = File(p.join(root.path, path));
    await f.parent.create(recursive: true);
    return f.writeAsString(body);
  }

  bool exists(String path) =>
      FileSystemEntity.typeSync(p.join(root.path, path)) !=
      FileSystemEntityType.notFound;

  group('что считается своим', () {
    test('папки и файлы Secretly — да', () {
      for (final dir in kLegacyDocumentsDirs) {
        expect(isLegacySecretlyDocumentsEntry(dir, isDirectory: true), isTrue);
      }
      for (final name in <String>[
        'my_avatar.png',
        'my_avatar_1727700000000123.png',
        'my_avatar_original_1727700000000123.img',
        'cover_custom_1727700000000.png',
        'cover_video_1727700000000.mp4',
        'cover_video_still_1727700000000.png',
        'avatar_video_1727700000000.mp4',
        'avatar_video_still_1727700000000.png',
        'cover_cache_abcdef0123456789_1727700000000.png',
        'support_thread_abcdef0123456789.json',
        'secretly_identity_journal.jsonl',
      ]) {
        expect(
          isLegacySecretlyDocumentsEntry(name, isDirectory: false),
          isTrue,
          reason: name,
        );
      }
    });

    test('чужое и каталог наборов — нет', () {
      for (final name in <String>[
        'my_avatar.jpg',
        'Отчёт.docx',
        'cover_custom_final.png',
        'support_thread_notes.txt',
        'attachments.zip',
      ]) {
        expect(
          isLegacySecretlyDocumentsEntry(name, isDirectory: false),
          isFalse,
          reason: name,
        );
      }
      for (final dir in <String>['stickers', 'cosmetics', 'Secretly', 'Work']) {
        expect(
          isLegacySecretlyDocumentsEntry(dir, isDirectory: true),
          isFalse,
          reason: dir,
        );
      }
    });
  });

  group('перенос', () {
    test('своё уезжает, чужое и наборы остаются, повтор — ничего', () async {
      await put('docs/attachments/blob1.jpg', 'secret-photo');
      await put('docs/contact_avatars/abcdef.png');
      await put('docs/my_avatar.png');
      await put('docs/cover_custom_1727700000000.png');
      await put('docs/secretly_identity_journal.jsonl');
      await put('docs/stickers/pack/1.webp');
      await put('docs/Отчёт.docx', 'mine');

      final r = await migrateLegacyDocuments(
        from: Directory(p.join(root.path, 'docs')),
        to: Directory(p.join(root.path, 'app', 'documents')),
      );

      expect(r.failed, 0);
      expect(r.moved, 5);
      expect(
        File(p.join(root.path, 'app/documents/attachments/blob1.jpg'))
            .readAsStringSync(),
        'secret-photo',
      );
      expect(exists('app/documents/contact_avatars/abcdef.png'), isTrue);
      expect(exists('app/documents/my_avatar.png'), isTrue);
      expect(exists('app/documents/cover_custom_1727700000000.png'), isTrue);
      expect(exists('app/documents/secretly_identity_journal.jsonl'), isTrue);
      // Из «Документов» ушло только своё.
      expect(exists('docs/attachments'), isFalse);
      expect(exists('docs/my_avatar.png'), isFalse);
      expect(exists('docs/Отчёт.docx'), isTrue);
      expect(exists('docs/stickers/pack/1.webp'), isTrue);
      expect(exists('app/documents/$kWindowsDocumentsMigratedMarker'), isTrue);

      // Второй запуск: метка на месте — ни одного обращения к старым файлам.
      await put('docs/attachments/late.jpg');
      final again = await migrateLegacyDocuments(
        from: Directory(p.join(root.path, 'docs')),
        to: Directory(p.join(root.path, 'app', 'documents')),
      );
      expect(again.moved, 0);
      expect(exists('docs/attachments/late.jpg'), isTrue);
    });

    test('в новой папке уже есть файл — он новее, старый не затирает', () async {
      await put('docs/attachments/same.jpg', 'old');
      await put('docs/attachments/other.jpg', 'other');
      await put('app/documents/attachments/same.jpg', 'new');

      final r = await migrateLegacyDocuments(
        from: Directory(p.join(root.path, 'docs')),
        to: Directory(p.join(root.path, 'app', 'documents')),
      );

      expect(r.moved, 1);
      expect(r.skipped, 1);
      expect(
        File(p.join(root.path, 'app/documents/attachments/same.jpg'))
            .readAsStringSync(),
        'new',
      );
      expect(exists('app/documents/attachments/other.jpg'), isTrue);
      // Пропущенный остаётся на старом месте — не теряется.
      expect(exists('docs/attachments/same.jpg'), isTrue);
    });

    test('«Документов» нет вовсе — просто новая папка и метка', () async {
      final r = await migrateLegacyDocuments(
        from: Directory(p.join(root.path, 'missing')),
        to: Directory(p.join(root.path, 'app', 'documents')),
      );
      expect(r.moved, 0);
      expect(exists('app/documents/$kWindowsDocumentsMigratedMarker'), isTrue);
    });
  });

  group('подмена path_provider', () {
    test('не Windows — ничего не подменяется', () async {
      final fake = _FakePlatform(
        support: p.join(root.path, 'app'),
        docs: p.join(root.path, 'docs'),
      );
      PathProviderPlatform.instance = fake;
      final r = await installWindowsPrivateDocuments(onWindows: false);
      expect(r, isNull);
      expect(identical(PathProviderPlatform.instance, fake), isTrue);
    });

    test('Windows — «Документы» становятся папкой приложения', () async {
      await put('docs/attachments/blob1.jpg');
      final fake = _FakePlatform(
        support: p.join(root.path, 'app'),
        docs: p.join(root.path, 'docs'),
      );
      PathProviderPlatform.instance = fake;

      final r = await installWindowsPrivateDocuments(onWindows: true);

      expect(r, isNotNull);
      expect(r!.moved, 1);
      final docs = await getApplicationDocumentsDirectory();
      expect(
        p.normalize(docs.path),
        p.normalize(p.join(root.path, 'app', kWindowsPrivateDocumentsDirName)),
      );
      // Остальные папки — как у настоящей реализации.
      final support = await getApplicationSupportDirectory();
      expect(p.normalize(support.path), p.normalize(p.join(root.path, 'app')));
      expect(
        File(p.join(docs.path, 'attachments', 'blob1.jpg')).existsSync(),
        isTrue,
      );

      // Повторный вызов не оборачивает подмену второй раз.
      final wrapped = PathProviderPlatform.instance;
      expect(await installWindowsPrivateDocuments(onWindows: true), isNull);
      expect(identical(PathProviderPlatform.instance, wrapped), isTrue);
    });
  });

  test('main_desktop ставит подмену после замка и до runApp', () {
    final src = File('lib/main_desktop.dart').readAsStringSync();
    final lock = src.indexOf('await guard.becomePrimary(');
    final install = src.indexOf('await installWindowsPrivateDocuments()');
    final run = src.indexOf('runApp(');
    expect(lock, greaterThan(0));
    expect(install, greaterThan(lock));
    expect(run, greaterThan(install));
  });
}
