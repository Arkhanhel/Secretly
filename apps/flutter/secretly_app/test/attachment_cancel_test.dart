// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// О1 (разбор медиа 15.11.2026): ✕ на фото — фото не уходит.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/attachments/attachment_failure.dart';
import 'package:secretly_app/transport/blob_client.dart';
import 'package:secretly_app/ui/chat_attachment_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 отменённое фото не отправляется (короткий путь до 24 МБ)', () async {
    final controller = AppController();
    final token = BlobUploadCancelToken()..cancel();
    await expectLater(
      controller.sendAttachment(
        peerProfileId: 'PEER',
        bytes: Uint8List.fromList(List<int>.filled(16, 7)),
        mime: 'application/octet-stream',
        cancelToken: token,
      ),
      throwsA(
        isA<AttachmentFailure>().having(
          (e) => e.code,
          'code',
          AttachmentFailureCode.uploadCanceled,
        ),
      ),
    );
  });

  test('О9: несколько документов — пути и имена парами, один вид результата',
      () {
    final r = ChatAttachmentPickerResult.files([
      (path: '/a/report.pdf', name: 'report.pdf'),
      (path: '/a/table.xlsx', name: 'table.xlsx'),
    ]);
    expect(r.kind, ChatAttachmentPickerResultKind.file);
    expect(r.filePaths, ['/a/report.pdf', '/a/table.xlsx']);
    expect(r.fileNames, ['report.pdf', 'table.xlsx']);
    final one = ChatAttachmentPickerResult.file('/a/x.zip', fileName: ' x.zip ');
    expect(one.filePaths, ['/a/x.zip']);
    expect(one.fileNames, ['x.zip']);
    expect(one.fileName, 'x.zip');
  });
}
