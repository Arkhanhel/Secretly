// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// О4 (разбор медиа 15.11.2026): сбой одного файла альбома не срывает альбом.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/attachments/attachment_failure.dart';
import 'package:secretly_app/transport/blob_client.dart';

void main() {
  const fast = Duration.zero;

  test('сбой сети — один повтор, и файл уходит', () async {
    var calls = 0;
    final failed = <int>[];
    final r = await AppController.uploadAlbumItem<String>(
      index: 3,
      retryDelay: fast,
      onItemFailed: (i, _) => failed.add(i),
      upload: () async {
        calls++;
        if (calls == 1) {
          throw AttachmentFailure(AttachmentFailureCode.serviceUnavailable);
        }
        return 'ok';
      },
    );
    expect(r, 'ok');
    expect(calls, 2);
    expect(failed, isEmpty);
  });

  test('🔴 не помог повтор — файл пропущен, причина сообщена, без исключения',
      () async {
    var calls = 0;
    final failed = <int>[];
    final r = await AppController.uploadAlbumItem<String>(
      index: 1,
      retryDelay: fast,
      onItemFailed: (i, _) => failed.add(i),
      upload: () async {
        calls++;
        throw StateError('blob upload failed: 502 bad gateway');
      },
    );
    expect(r, isNull);
    expect(calls, 2);
    expect(failed, [1]);
  });

  test('не сетевой сбой (файл велик) — без повтора, пропуск', () async {
    var calls = 0;
    final failed = <int>[];
    final r = await AppController.uploadAlbumItem<String>(
      index: 0,
      retryDelay: fast,
      onItemFailed: (i, _) => failed.add(i),
      upload: () async {
        calls++;
        throw StateError('blob upload failed: 413 blob too large');
      },
    );
    expect(r, isNull);
    expect(calls, 1);
    expect(failed, [0]);
  });

  test('отмена — просто выпадает, не «сбой»', () async {
    final failed = <int>[];
    final r = await AppController.uploadAlbumItem<String>(
      index: 0,
      retryDelay: fast,
      onItemFailed: (i, _) => failed.add(i),
      upload: () async =>
          throw AttachmentFailure(AttachmentFailureCode.uploadCanceled),
    );
    expect(r, isNull);
    expect(failed, isEmpty);
  });

  test('отменили во время паузы перед повтором — без повтора', () async {
    final token = BlobUploadCancelToken();
    var calls = 0;
    final r = await AppController.uploadAlbumItem<String>(
      index: 0,
      cancelToken: token,
      retryDelay: fast,
      onItemFailed: (_, _) {},
      upload: () async {
        calls++;
        token.cancel();
        throw AttachmentFailure(AttachmentFailureCode.uploadTimedOut);
      },
    );
    expect(r, isNull);
    expect(calls, 1);
  });

  test('без onItemFailed — прежнее поведение: сбой пробрасывается сразу',
      () async {
    var calls = 0;
    await expectLater(
      AppController.uploadAlbumItem<String>(
        index: 0,
        retryDelay: fast,
        upload: () async {
          calls++;
          throw StateError('blob upload failed: 502');
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, 1);
  });
}
