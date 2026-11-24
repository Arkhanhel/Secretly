// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// В-1 (разбор медиа 22.11.2026): расшифровка частями по мере скачивания
// даёт РОВНО тот же файл, что расшифровка целиком, — при любом дроблении,
// с докачкой после обрыва; любой сбой — «не вышло» без выходного файла
// (вызывающий тогда расшифровывает прежним путём).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/attachments/attachment_service.dart';
import 'package:secretly_app/attachments/streaming_attachment_decrypt.dart';
import 'package:secretly_app/transport/blob_client.dart';

void main() {
  late Directory dir;
  late AttachmentService svc;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('secretly_stream_dec_');
    svc = AttachmentService(
      blobClient: BlobClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
    );
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  /// Шифротекст v1 и эталон — расшифровка целиком прежним путём.
  Future<({Uint8List cipher, String key, Uint8List whole})> fixture(
    int size, {
    int chunk = 64 * 1024,
  }) async {
    final plain = Uint8List.fromList(
      List<int>.generate(size, (i) => (i * 131 + 7) % 251),
    );
    final inFile = File('${dir.path}/in_$size.bin');
    await inFile.writeAsBytes(plain, flush: true);
    final bundle = await svc.encryptFileForUpload(
      inFile,
      tempDir: dir,
      chunkSize: chunk,
      mime: 'video/mp4',
    );
    final cipher = await bundle.ciphertextFile.readAsBytes();
    final wholeOut = File('${dir.path}/whole_$size.bin');
    await svc.decryptDownloadedFileToFile(
      bundle.ciphertextFile,
      fileKeyB64: bundle.fileKeyB64,
      outputFile: wholeOut,
    );
    final whole = await wholeOut.readAsBytes();
    expect(whole, plain);
    return (cipher: cipher, key: bundle.fileKeyB64, whole: whole);
  }

  test('по кускам любого размера = целиком', () async {
    final f = await fixture(300 * 1024 + 123);
    final rnd = Random(7);
    for (final maxPiece in [1, 17, 4096, 70000, 1 << 20]) {
      final key = base64Decode(f.key);
      final dec = AttachmentV1StreamDecryptor(key);
      final out = BytesBuilder(copy: true);
      var off = 0;
      while (off < f.cipher.length) {
        final n = min(f.cipher.length - off, 1 + rnd.nextInt(maxPiece));
        await dec.add(
          Uint8List.sublistView(f.cipher, off, off + n),
          (plain) async => out.add(plain),
        );
        off += n;
      }
      expect(dec.cleanEnd, isTrue, reason: 'кусок $maxPiece');
      expect(out.takeBytes(), f.whole, reason: 'кусок $maxPiece');
    }
  });

  Future<StreamingDecryptResult> streamFile({
    required Uint8List cipher,
    required String key,
    required File part,
    required File out,
    int alreadyOnDisk = 0,
    int step = 37 * 1024,
  }) async {
    // Как в контроллере: файл-кусок пишет скачивание, изолят идёт следом.
    if (alreadyOnDisk > 0) {
      await part.writeAsBytes(
        Uint8List.sublistView(cipher, 0, alreadyOnDisk),
        flush: true,
      );
    }
    final sink = part.openWrite(
      mode: alreadyOnDisk > 0 ? FileMode.append : FileMode.write,
    );
    StreamingAttachmentDecrypt? s;
    var received = alreadyOnDisk;
    while (received < cipher.length) {
      final n = min(step, cipher.length - received);
      sink.add(Uint8List.sublistView(cipher, received, received + n));
      received += n;
      s ??= StreamingAttachmentDecrypt.start(
        partPath: part.path,
        outPath: out.path,
        fileKeyB64: key,
      );
      s!.notifyAvailable(received);
      if (received % (3 * step) == 0) await sink.flush();
    }
    await sink.flush();
    await sink.close();
    return s!.finish(await part.length());
  }

  test('изолят следом за скачиванием: тот же файл', () async {
    final f = await fixture(1024 * 1024 + 5);
    final out = File('${dir.path}/stream_out.bin');
    final r = await streamFile(
      cipher: f.cipher,
      key: f.key,
      part: File('${dir.path}/part.bin'),
      out: out,
    );
    expect(r.ok, isTrue, reason: r.reason);
    expect(r.chunks, 17);
    expect(await out.readAsBytes(), f.whole);
  });

  test('докачка: начало от прошлой попытки уже на диске', () async {
    final f = await fixture(700 * 1024);
    final out = File('${dir.path}/resume_out.bin');
    final r = await streamFile(
      cipher: f.cipher,
      key: f.key,
      part: File('${dir.path}/part_resume.bin'),
      out: out,
      // Обрыв посреди куска — не на границе.
      alreadyOnDisk: 333333,
    );
    expect(r.ok, isTrue, reason: r.reason);
    expect(await out.readAsBytes(), f.whole);
  });

  test('испорченный кусок — «не вышло», выходного файла нет', () async {
    final f = await fixture(200 * 1024);
    final bad = Uint8List.fromList(f.cipher);
    bad[bad.length - 10] ^= 0x5a;
    final out = File('${dir.path}/bad_out.bin');
    final r = await streamFile(
      cipher: bad,
      key: f.key,
      part: File('${dir.path}/part_bad.bin'),
      out: out,
    );
    expect(r.ok, isFalse);
    expect(await out.exists(), isFalse);
  });

  test('лишние байты в конце — «не вышло» (как и целиком: ошибка)', () async {
    final f = await fixture(130 * 1024);
    final trailing = Uint8List.fromList([...f.cipher, 1, 2]);
    final out = File('${dir.path}/trail_out.bin');
    final r = await streamFile(
      cipher: trailing,
      key: f.key,
      part: File('${dir.path}/part_trail.bin'),
      out: out,
    );
    expect(r.ok, isFalse);
    expect(r.reason, 'trailing');
    expect(await out.exists(), isFalse);
  });

  test('не v1 (v0 целиком) — «не вышло», расшифрует прежний путь', () async {
    final bundle = await svc.encryptForUpload(
      Uint8List.fromList(List<int>.filled(4000, 3)),
    );
    final out = File('${dir.path}/v0_out.bin');
    final r = await streamFile(
      cipher: bundle.ciphertext,
      key: bundle.fileKeyB64,
      part: File('${dir.path}/part_v0.bin'),
      out: out,
    );
    expect(r.ok, isFalse);
    expect(r.reason, 'magic');
    expect(await out.exists(), isFalse);
  });

  test('обрыв скачивания: abort закрывает и удаляет выход', () async {
    final f = await fixture(400 * 1024);
    final part = File('${dir.path}/part_abort.bin');
    final out = File('${dir.path}/abort_out.bin');
    await part.writeAsBytes(Uint8List.sublistView(f.cipher, 0, 150000));
    final s = StreamingAttachmentDecrypt.start(
      partPath: part.path,
      outPath: out.path,
      fileKeyB64: f.key,
    )!;
    s.notifyAvailable(150000);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await s.abort();
    expect(await out.exists(), isFalse);
    // Кусок для докачки остаётся.
    expect(await part.length(), 150000);
  });

  test('ключ не того размера — сеанс не начинается', () {
    expect(
      StreamingAttachmentDecrypt.start(
        partPath: '${dir.path}/x',
        outPath: '${dir.path}/y',
        fileKeyB64: 'AAAA',
      ),
      isNull,
    );
  });
}
