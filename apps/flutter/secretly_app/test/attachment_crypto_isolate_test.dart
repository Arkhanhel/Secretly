// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 14.11.2026: вложения больше 256 КБ шифруются и расшифровываются в
// отдельном изоляте — результат и ошибки те же, что при расчёте на месте.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/attachments/attachment_service.dart';
import 'package:secretly_app/transport/blob_client.dart';

void main() {
  final svc = AttachmentService(
    blobClient: BlobClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
  );

  test('large v0 attachment round-trips through the worker', () async {
    final plain = Uint8List.fromList(
      List<int>.generate(3 * 1024 * 1024, (i) => (i * 7) % 251),
    );
    expect(plain.length, greaterThan(AttachmentService.offMainThreadMinBytes));
    final bundle = await svc.encryptForUpload(plain, mime: 'image/jpeg');
    final out = await svc.decryptDownloaded(
      bundle.ciphertext,
      fileKeyB64: bundle.fileKeyB64,
    );
    expect(out, plain);
  });

  test('tampered large attachment fails exactly like before', () async {
    final plain = Uint8List(1024 * 1024);
    final bundle = await svc.encryptForUpload(plain, mime: 'image/jpeg');
    final bad = Uint8List.fromList(bundle.ciphertext);
    bad[bad.length - 1] ^= 0x01;
    Object? onWorker;
    try {
      await svc.decryptDownloaded(bad, fileKeyB64: bundle.fileKeyB64);
    } catch (e) {
      onWorker = e;
    }
    expect(onWorker, isNotNull);
    // Тот же тип ошибки, что даёт расшифровка маленького файла на месте.
    final small = await svc.encryptForUpload(Uint8List(64));
    final badSmall = Uint8List.fromList(small.ciphertext);
    badSmall[badSmall.length - 1] ^= 0x01;
    Object? inPlace;
    try {
      await svc.decryptDownloaded(badSmall, fileKeyB64: small.fileKeyB64);
    } catch (e) {
      inPlace = e;
    }
    expect(onWorker.runtimeType, inPlace.runtimeType);
  });
}
