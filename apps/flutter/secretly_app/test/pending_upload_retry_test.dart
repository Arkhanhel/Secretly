// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// О2 (разбор медиа 15.11.2026): сорвавшаяся по сети отправка не исчезает —
// пузырь «не отправлено» с повтором; бесполезный повтор не предлагается.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/pending_attachment_upload.dart';
import 'package:secretly_app/attachments/attachment_failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('что повторяемо, а что нет', () {
    bool r(AttachmentFailureCode c) =>
        AppController.pendingUploadFailureIsRetryable(AttachmentFailure(c));
    expect(r(AttachmentFailureCode.serviceUnavailable), isTrue);
    expect(r(AttachmentFailureCode.uploadTimedOut), isTrue);
    expect(r(AttachmentFailureCode.serverStorageFull), isTrue);
    expect(r(AttachmentFailureCode.tooLarge), isFalse);
    expect(r(AttachmentFailureCode.contactBlocked), isFalse);
    expect(r(AttachmentFailureCode.metadataScrubFailed), isFalse);
    expect(r(AttachmentFailureCode.uploadCanceled), isFalse);
    // Сообщение уже записано и может уйти само — повтор дал бы второе.
    expect(r(AttachmentFailureCode.finalizeTimedOut), isFalse);
    expect(
      AppController.pendingUploadFailureIsRetryable(
        StateError('blob upload failed: 502 bad gateway'),
      ),
      isTrue,
    );
  });

  test('🔴 сбой — пузырь остаётся «не отправлено»; повтор снова в очереди',
      () async {
    final dir = Directory.systemTemp.createTempSync('retry_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File(p.join(dir.path, 'doc.pdf'))..writeAsBytesSync([1, 2, 3]);
    final controller = AppController();
    final pending = PendingPhotoUpload(
      id: 'u1',
      filePath: f.path,
      mime: 'application/pdf',
      caption: '',
      totalBytes: 3,
      convoId: 'C',
      targetId: 'PEER',
      filename: 'doc.pdf',
      asFile: true,
    );
    final errors = <Object>[];
    final sub = controller.attachmentUploadErrors.listen((e) => errors.add(e));
    addTearDown(sub.cancel);

    controller.enqueuePhotoUpload(pending);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Без базы и сети отправка падает «не готово» — это повторяемый сбой.
    expect(controller.pendingPhotoUploadsFor('C'), [pending]);
    expect(pending.failed, isTrue);
    expect(errors, hasLength(1), reason: 'причина всё равно сообщается');

    expect(controller.retryPhotoUpload('C', 'u1'), isTrue);
    expect(pending.failed, isFalse, reason: 'сразу после нажатия — снова идёт');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(pending.failed, isTrue);
    expect(controller.pendingPhotoUploadsFor('C'), [pending]);

    expect(controller.retryPhotoUpload('C', 'нет-такого'), isFalse);
  });

  test('отказ, который повтор не исправит, — пузырь уходит, как раньше',
      () async {
    final controller = AppController();
    final pending = PendingPhotoUpload(
      id: 'u2',
      filePath: '/нет/такого/файла.pdf',
      mime: 'application/pdf',
      caption: '',
      totalBytes: 3,
      convoId: 'C2',
      targetId: 'PEER',
      asFile: true,
    );
    controller.enqueuePhotoUpload(pending);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(controller.pendingPhotoUploadsFor('C2'), isEmpty);
  });

  test('отмена — пузырь уходит молча, без сообщения об ошибке', () async {
    final dir = Directory.systemTemp.createTempSync('cancel_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File(p.join(dir.path, 'a.pdf'))..writeAsBytesSync([1]);
    final controller = AppController();
    final errors = <Object>[];
    final sub = controller.attachmentUploadErrors.listen(errors.add);
    addTearDown(sub.cancel);
    final pending = PendingPhotoUpload(
      id: 'u3',
      filePath: f.path,
      mime: 'application/pdf',
      caption: '',
      totalBytes: 1,
      convoId: 'C3',
      targetId: 'PEER',
      asFile: true,
    )..cancelToken.cancel();
    controller.enqueuePhotoUpload(pending);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(controller.pendingPhotoUploadsFor('C3'), isEmpty);
    expect(errors, isEmpty);
  });

  test('О2: запись «не отправлено» читается обратно без потерь', () {
    final u = PendingPhotoUpload(
      id: 'u9',
      filePath: '/x/clip.mp4',
      mime: 'video/mp4',
      caption: '',
      totalBytes: 99,
      convoId: 'G',
      targetId: 'G',
      isGroup: true,
      topicId: 't1',
      filename: 'clip.mp4',
      waveform: const [1, 2, 3],
      durationMs: 1200,
    );
    final back = AppController.failedUploadFromJson(
      AppController.failedUploadToJson(u),
    )!;
    expect(back.id, 'u9');
    expect(back.filePath, '/x/clip.mp4');
    expect(back.mime, 'video/mp4');
    expect(back.isGroup, isTrue);
    expect(back.topicId, 't1');
    expect(back.filename, 'clip.mp4');
    expect(back.waveform, [1, 2, 3]);
    expect(back.durationMs, 1200);
    expect(AppController.failedUploadFromJson({'id': 1}), isNull);
  });
}
