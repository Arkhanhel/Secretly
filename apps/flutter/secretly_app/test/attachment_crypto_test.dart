// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/attachments/attachment_service.dart';
import 'package:secretly_app/transport/blob_client.dart';

void main() {
  test('Attachment encrypt/decrypt roundtrip', () async {
    // BlobClient is not used for this pure crypto test.
    final svc = AttachmentService(blobClient: BlobClient(baseUrl: Uri.parse('http://127.0.0.1:1')));
    final plain = Uint8List.fromList(List<int>.generate(1024, (i) => i % 251));

    final bundle = await svc.encryptForUpload(plain, mime: 'application/octet-stream');
    expect(bundle.ciphertext.length, greaterThan(plain.length));
    expect(bundle.fileKeyB64, isNotEmpty);

    final out = await svc.decryptDownloaded(bundle.ciphertext, fileKeyB64: bundle.fileKeyB64);
    expect(out, plain);
  });

  test('Attachment v1 chunked file encrypt/decrypt roundtrip', () async {
    final svc = AttachmentService(blobClient: BlobClient(baseUrl: Uri.parse('http://127.0.0.1:1')));
    final dir = await Directory.systemTemp.createTemp('secretly_att_test_');
    try {
      final plain = Uint8List.fromList(List<int>.generate(250000, (i) => (i * 31) % 251));
      final inFile = File('${dir.path}${Platform.pathSeparator}in.bin');
      await inFile.writeAsBytes(plain, flush: true);

      final bundle = await svc.encryptFileForUpload(inFile, tempDir: dir, chunkSize: 64 * 1024, mime: 'application/octet-stream');
      final cipherBytes = await bundle.ciphertextFile.readAsBytes();
      final out = await svc.decryptDownloaded(cipherBytes, fileKeyB64: bundle.fileKeyB64);
      expect(out, plain);
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('Attachment v1 chunked file decrypts directly to file', () async {
    final svc = AttachmentService(blobClient: BlobClient(baseUrl: Uri.parse('http://127.0.0.1:1')));
    final dir = await Directory.systemTemp.createTemp('secretly_att_file_test_');
    try {
      final plain = Uint8List.fromList(List<int>.generate(280000, (i) => (i * 17) % 251));
      final inFile = File('${dir.path}${Platform.pathSeparator}in.bin');
      final outFile = File('${dir.path}${Platform.pathSeparator}out.bin');
      await inFile.writeAsBytes(plain, flush: true);

      final bundle = await svc.encryptFileForUpload(
        inFile,
        tempDir: dir,
        chunkSize: 64 * 1024,
        mime: 'application/octet-stream',
      );

      final decryptedFile = await svc.decryptDownloadedFileToFile(
        bundle.ciphertextFile,
        fileKeyB64: bundle.fileKeyB64,
        outputFile: outFile,
      );

      expect(await decryptedFile.readAsBytes(), plain);
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  });
}
