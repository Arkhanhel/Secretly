// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ОТКРЫТИЕ ПОЛУЧЕННОГО ФАЙЛА ВНЕШНЕЙ ПРОГРАММОЙ.
//
// 🔴 Компьютер отдавал системе файл ПРЯМО ИЗ КЭША, а там он лежит под именем
// `<идентификатор>.bin`: система не понимала, чем его открыть, и человек
// получал либо «выберите программу», либо ничего. Вдобавок чужая программа
// получала путь внутрь нашего расшифрованного кэша.
//
// Теперь наружу уходит временная копия под настоящим именем, по подпапке на
// вложение, и прошлые копии стираются при следующем запуске.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/ui/desktop/chat/attachment_save.dart';

void main() {
  late Directory root;
  late File cached;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('open_copy');
    cached = File(p.join(root.path, 'blob-1.bin'))
      ..writeAsStringSync('содержимое');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('🔴 копия получает настоящее имя, а не «.bin»', () async {
    final copy = await attachmentOpenCopy(
      file: cached,
      suggestedName: 'Договор.docx',
      blobId: 'blob-1',
      root: root,
    );
    expect(p.basename(copy.path), 'Договор.docx');
    expect(copy.readAsStringSync(), 'содержимое');
    expect(
      copy.path.startsWith(attachmentOpenCopyDir(root: root).path),
      isTrue,
      reason: 'копия обязана лежать во временной папке, а не в кэше',
    );
  });

  test('🔴 имя прислал другой человек — путь наружу не уводит', () async {
    final copy = await attachmentOpenCopy(
      file: cached,
      suggestedName: '../../.ssh/authorized_keys',
      blobId: 'blob-1',
      root: root,
    );
    expect(p.basename(copy.path), 'authorized_keys');
    expect(
      p.dirname(copy.path).startsWith(attachmentOpenCopyDir(root: root).path),
      isTrue,
    );
  });

  test('одинаковые имена от разных вложений не затирают друг друга', () async {
    final other = File(p.join(root.path, 'blob-2.bin'))
      ..writeAsStringSync('другое содержимое');
    final first = await attachmentOpenCopy(
      file: cached,
      suggestedName: 'отчёт.pdf',
      blobId: 'blob-1',
      root: root,
    );
    final second = await attachmentOpenCopy(
      file: other,
      suggestedName: 'отчёт.pdf',
      blobId: 'blob-2',
      root: root,
    );
    expect(first.path == second.path, isFalse);
    expect(first.readAsStringSync(), 'содержимое');
    expect(second.readAsStringSync(), 'другое содержимое');
  });

  test('повторное открытие не копирует заново', () async {
    final first = await attachmentOpenCopy(
      file: cached,
      suggestedName: 'отчёт.pdf',
      blobId: 'blob-1',
      root: root,
    );
    final stampBefore = first.statSync().modified;
    final again = await attachmentOpenCopy(
      file: cached,
      suggestedName: 'отчёт.pdf',
      blobId: 'blob-1',
      root: root,
    );
    expect(again.path, first.path);
    expect(again.statSync().modified, stampBefore);
  });

  test('🔴 копии прошлого сеанса стираются', () async {
    await attachmentOpenCopy(
      file: cached,
      suggestedName: 'отчёт.pdf',
      blobId: 'blob-1',
      root: root,
    );
    expect(attachmentOpenCopyDir(root: root).existsSync(), isTrue);
    await clearAttachmentOpenCopies(root: root);
    expect(
      attachmentOpenCopyDir(root: root).existsSync(),
      isFalse,
      reason: 'расшифрованные файлы не должны переживать сеанс',
    );
  });

  test('уборка на пустом месте не падает', () async {
    await clearAttachmentOpenCopies(root: root);
    await clearAttachmentOpenCopies(root: root);
  });

  test('🔴 лента отдаёт наружу копию, а не файл из кэша', () {
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    final at = section.indexOf('Future<void> _openFile(');
    expect(at, greaterThan(0));
    final body = section.substring(at, at + 2000);
    final copyAt = body.indexOf('attachmentOpenCopy(');
    final launchAt = body.indexOf('launchUrl(');
    expect(copyAt, greaterThan(0), reason: 'копии нет — наружу уходит кэш');
    expect(copyAt < launchAt, isTrue);
  });
}
