// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;

import '../diagnostics/diag_log.dart';
import '../transport/blob_client.dart';

class AttachmentService {
  AttachmentService({required this.blobClient});

  final BlobClient blobClient;

  static const int _fileKeyLen = 32;
  static const int _blobAccessTokenLen = 32;
  static const int _nonceLen = 24;
  static const int _macLen = 16;

  static const int _v1NoncePrefixLen = 16;
  static const List<int> _magic = [0x53, 0x41, 0x54, 0x54, 0x31]; // 'SATT1'

  /// v0: per-attachment file key (32 bytes) + XChaCha20-Poly1305.
  ///
  /// Format: nonce(24) + mac(16) + ciphertext(N)
  Future<AttachmentUploadBundle> encryptForUpload(
    Uint8List plaintext, {
    String? mime,
  }) async {
    final key = _randomBytes(_fileKeyLen);
    final algo = Xchacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    final box = await algo.encrypt(plaintext, secretKey: secretKey);

    final out = BytesBuilder(copy: false);
    out.add(box.nonce);
    out.add(box.mac.bytes);
    out.add(box.cipherText);

    return AttachmentUploadBundle(
      fileKeyB64: base64Encode(key),
      ciphertext: out.takeBytes(),
      plaintextSizeBytes: plaintext.length,
      mime: mime,
    );
  }

  /// v1: chunked file encryption to avoid loading large files into memory.
  ///
  /// Format:
  /// - magic 'SATT1' (5)
  /// - version u8 (1) = 1
  /// - chunk_size u32 BE (4)
  /// - nonce_prefix(16)
  /// - repeated chunks:
  ///   - plain_len u32 BE
  ///   - mac(16)
  ///   - ciphertext(plain_len)
  Future<AttachmentEncryptedFileBundle> encryptFileForUpload(
    File plaintextFile, {
    required Directory tempDir,
    int chunkSize = 64 * 1024,
    String? mime,
  }) async {
    final plainLen = await plaintextFile.length();
    final key = _randomBytes(_fileKeyLen);
    final secretKey = SecretKey(key);
    final algo = Xchacha20.poly1305Aead();

    final outPath = pJoin(
      tempDir.path,
      'secretly_att_${DateTime.now().millisecondsSinceEpoch}_${_randTag()}.bin',
    );
    final outFile = File(outPath);
    final out = await outFile.open(mode: FileMode.write);

    final digestSink = AccumulatorSink<crypto.Digest>();
    final hashSink = crypto.sha256.startChunkedConversion(digestSink);

    Future<void> writeAll(List<int> bytes) async {
      hashSink.add(bytes);
      await out.writeFrom(bytes);
    }

    final noncePrefix = _randomBytes(_v1NoncePrefixLen);
    final header = BytesBuilder(copy: false);
    header.add(_magic);
    header.add([0x01]);
    final cs = ByteData(4)..setUint32(0, chunkSize, Endian.big);
    header.add(cs.buffer.asUint8List());
    header.add(noncePrefix);
    await writeAll(header.takeBytes());

    final inFile = await plaintextFile.open();
    try {
      var counter = 0;
      while (true) {
        final plain = await inFile.read(chunkSize);
        if (plain.isEmpty) break;

        final nonce = Uint8List(_nonceLen);
        nonce.setRange(0, _v1NoncePrefixLen, noncePrefix);
        final cBytes = ByteData(8)..setUint64(0, counter, Endian.big);
        nonce.setRange(
          _v1NoncePrefixLen,
          _nonceLen,
          cBytes.buffer.asUint8List(),
        );
        counter++;

        final box = await algo.encrypt(
          plain,
          secretKey: secretKey,
          nonce: nonce,
        );

        final lenBytes = ByteData(4)..setUint32(0, plain.length, Endian.big);
        await writeAll(lenBytes.buffer.asUint8List());
        await writeAll(box.mac.bytes);
        await writeAll(box.cipherText);
      }
    } finally {
      await inFile.close();
      await out.close();
      hashSink.close();
    }

    final digest = digestSink.events.single;
    final cipherLen = await outFile.length();
    return AttachmentEncryptedFileBundle(
      fileKeyB64: base64Encode(key),
      ciphertextFile: outFile,
      plaintextSizeBytes: plainLen,
      ciphertextSizeBytes: cipherLen,
      sha256B64: base64Encode(digest.bytes),
      mime: mime,
    );
  }

  /// v0: encrypt whole file in-memory (MVP). Later: chunked streaming.
  Future<EncryptedAttachment> encryptAndUpload(
    Uint8List plaintext, {
    required int ttlSeconds,
    String? mime,
  }) async {
    final bundle = await encryptForUpload(plaintext, mime: mime);
    final blobAccessTokenB64 = base64Encode(_randomBytes(_blobAccessTokenLen));
    final upload = await blobClient.uploadCiphertext(
      bundle.ciphertext,
      ttlSeconds: ttlSeconds,
      accessTokenB64: blobAccessTokenB64,
    );
    return EncryptedAttachment(
      blobId: upload.blobId,
      ciphertextSizeBytes: upload.sizeBytes,
      expiresAtMs: upload.expiresAtMs,
      fileKeyB64: bundle.fileKeyB64,
      blobAccessTokenB64: blobAccessTokenB64,
      mime: mime,
      debugTag: _randTag(),
    );
  }

  Future<EncryptedAttachment> encryptFileAndUpload(
    File plaintextFile, {
    required Directory tempDir,
    required int ttlSeconds,
    String? mime,
    int chunkSize = 64 * 1024,
    void Function(int sentBytes, int totalBytes)? onUploadProgress,
    void Function(String stage)? onStage,
    BlobUploadCancelToken? cancelToken,
  }) async {
    if (!kReleaseMode) {
      developer.log(
        'ATTACH_FLOW encrypt.start ttl=$ttlSeconds chunk=$chunkSize',
        name: 'AttachmentService',
      );
    }
    final bundle = await encryptFileForUpload(
      plaintextFile,
      tempDir: tempDir,
      chunkSize: chunkSize,
      mime: mime,
    );
    if (!kReleaseMode) {
      developer.log(
        'ATTACH_FLOW encrypt.done cipher=${bundle.ciphertextSizeBytes}',
        name: 'AttachmentService',
      );
    }
    onStage?.call('uploading');
    if (!kReleaseMode) {
      developer.log('ATTACH_FLOW upload.start', name: 'AttachmentService');
    }
    final blobAccessTokenB64 = base64Encode(_randomBytes(_blobAccessTokenLen));
    // 🔴 `finally`, А НЕ УДАЛЕНИЕ ПОСЛЕ УСПЕХА (02.09.2026, аудит передачи
    // файлов). Временный шифртекст удалялся только на удачном пути. Любой
    // бросок — обрыв связи, отмена пользователем, таймаут заливки — оставлял
    // файл размером с вложение НАВСЕГДА: свипера на префикс `secretly_att_` в
    // проекте нет, он встречается в коде ровно один раз. Три отменённые
    // отправки двухсотмегабайтного видео — почти шестьсот мегабайт мусора,
    // который не уберёт никто.
    final BlobUploadResult upload;
    try {
      upload = await blobClient.uploadCiphertextFile(
        bundle.ciphertextFile,
        ttlSeconds: ttlSeconds,
        bodySha256B64: bundle.sha256B64,
        accessTokenB64: blobAccessTokenB64,
        onProgress: onUploadProgress,
        cancelToken: cancelToken,
      );
    } finally {
      // Шифртекст нужен только на время заливки: сервер его уже принял, а
      // повтор шифрует заново. Удаление намеренно без throw — потерять
      // temp-файл не так плохо, как заслонить настоящую ошибку заливки.
      try {
        await bundle.ciphertextFile.delete();
      } catch (_) {
        // ignore
      }
    }
    if (!kReleaseMode) {
      developer.log(
        'ATTACH_FLOW upload.done size=${upload.sizeBytes}',
        name: 'AttachmentService',
      );
    }

    return EncryptedAttachment(
      blobId: upload.blobId,
      ciphertextSizeBytes: upload.sizeBytes,
      expiresAtMs: upload.expiresAtMs,
      fileKeyB64: bundle.fileKeyB64,
      blobAccessTokenB64: blobAccessTokenB64,
      mime: mime,
      debugTag: _randTag(),
    );
  }

  Future<Uint8List> decryptDownloaded(
    Uint8List ciphertext, {
    required String fileKeyB64,
  }) async {
    final key = base64Decode(fileKeyB64);
    if (key.length != _fileKeyLen) {
      throw StateError('bad file_key');
    }

    // v1 magic.
    if (ciphertext.length >= 5 + 1 + 4 + _v1NoncePrefixLen) {
      final isMagic = _hasV1Magic(ciphertext);
      if (isMagic) {
        final v = ciphertext[5];
        if (v != 0x01) {
          throw StateError('unsupported attachment version: $v');
        }
        final chunkSize = ByteData.sublistView(
          ciphertext,
          6,
          10,
        ).getUint32(0, Endian.big);
        if (chunkSize <= 0 || chunkSize > 4 * 1024 * 1024) {
          throw StateError('bad chunk size');
        }

        final noncePrefix = ciphertext.sublist(10, 10 + _v1NoncePrefixLen);
        var off = 10 + _v1NoncePrefixLen;
        var counter = 0;
        final algo = Xchacha20.poly1305Aead();
        final out = BytesBuilder(copy: false);
        while (off < ciphertext.length) {
          if (off + 4 + _macLen > ciphertext.length) {
            throw StateError('truncated attachment');
          }
          final plainLen = ByteData.sublistView(
            ciphertext,
            off,
            off + 4,
          ).getUint32(0, Endian.big);
          off += 4;
          final macBytes = ciphertext.sublist(off, off + _macLen);
          off += _macLen;
          if (off + plainLen > ciphertext.length) {
            throw StateError('truncated attachment');
          }
          // 🔴 ВИД, А НЕ КОПИЯ (02.09.2026, аудит передачи файлов). `sublist`
          // копировал каждый кусок целиком, и на время расшифровки в памяти
          // жили ОБА: исходный шифртекст и копия куска. На вложении в 24 МБ,
          // которое целиком лежит в памяти на буферном пути, это лишние
          // мегабайты на ровном месте — при том, что расшифровка вход только
          // читает и никогда не меняет.
          //
          // Заголовочные поля рядом (префикс одноразового числа, метка
          // подлинности) остаются копиями намеренно: они по шестнадцать байт,
          // выигрыш нулевой, а `nonce.setRange` ниже ждёт обычный список.
          final ct = Uint8List.sublistView(ciphertext, off, off + plainLen);
          off += plainLen;

          final nonce = Uint8List(_nonceLen);
          nonce.setRange(0, _v1NoncePrefixLen, noncePrefix);
          final cBytes = ByteData(8)..setUint64(0, counter, Endian.big);
          nonce.setRange(
            _v1NoncePrefixLen,
            _nonceLen,
            cBytes.buffer.asUint8List(),
          );
          counter++;

          final box = SecretBox(ct, nonce: nonce, mac: Mac(macBytes));
          final plain = await algo.decrypt(box, secretKey: SecretKey(key));
          out.add(plain);
        }
        return out.takeBytes();
      }
    }

    // v0 fallback.
    if (ciphertext.length < _nonceLen + _macLen) {
      throw StateError('ciphertext too short');
    }

    final nonce = ciphertext.sublist(0, _nonceLen);
    final macBytes = ciphertext.sublist(_nonceLen, _nonceLen + _macLen);
    final ct = ciphertext.sublist(_nonceLen + _macLen);

    final algo = Xchacha20.poly1305Aead();
    final box = SecretBox(ct, nonce: nonce, mac: Mac(macBytes));
    final plain = await algo.decrypt(box, secretKey: SecretKey(key));
    return Uint8List.fromList(plain);
  }

  Future<File> decryptDownloadedFileToFile(
    File ciphertextFile, {
    required String fileKeyB64,
    required File outputFile,
  }) async {
    final key = base64Decode(fileKeyB64);
    if (key.length != _fileKeyLen) {
      throw StateError('bad file_key');
    }

    final input = await ciphertextFile.open();
    try {
      final header = await input.read(5 + 1 + 4 + _v1NoncePrefixLen);
      if (header.length == 5 + 1 + 4 + _v1NoncePrefixLen &&
          _hasV1Magic(header)) {
        final v = header[5];
        if (v != 0x01) {
          throw StateError('unsupported attachment version: $v');
        }
        final chunkSize = ByteData.sublistView(
          header,
          6,
          10,
        ).getUint32(0, Endian.big);
        if (chunkSize <= 0 || chunkSize > 4 * 1024 * 1024) {
          throw StateError('bad chunk size');
        }

        final noncePrefix = header.sublist(10, 10 + _v1NoncePrefixLen);
        final algo = Xchacha20.poly1305Aead();
        await outputFile.parent.create(recursive: true);
        final output = await outputFile.open(mode: FileMode.write);
        var failed = false;
        var chunksDecoded = 0;
        var bytesWritten = 0;
        try {
          var counter = 0;
          while (true) {
            final lenBytes = await _readExactOrNull(input, 4);
            if (lenBytes == null) break;
            final plainLen = ByteData.sublistView(
              lenBytes,
            ).getUint32(0, Endian.big);
            final macBytes = await _readExact(input, _macLen);
            final ct = await _readExact(input, plainLen);

            final nonce = Uint8List(_nonceLen);
            nonce.setRange(0, _v1NoncePrefixLen, noncePrefix);
            final cBytes = ByteData(8)..setUint64(0, counter, Endian.big);
            nonce.setRange(
              _v1NoncePrefixLen,
              _nonceLen,
              cBytes.buffer.asUint8List(),
            );
            counter++;

            final box = SecretBox(ct, nonce: nonce, mac: Mac(macBytes));
            final plain = await algo.decrypt(box, secretKey: SecretKey(key));
            await output.writeFrom(plain);
            chunksDecoded++;
            bytesWritten += plain.length;
          }
        } catch (e) {
          failed = true;
          // PR-D (Bug 15): emit a breadcrumb so field reports of «вложение
          // не открывается» become diagnosable. The output file is still
          // deleted in `finally` to avoid leaving a half-decrypted blob.
          DiagLog.event('attachment', 'decrypt_failed', {
            'reason': e.runtimeType.toString(),
            'chunks_ok': chunksDecoded,
            'bytes_written': bytesWritten,
          });
          rethrow;
        } finally {
          await output.close();
          if (failed) {
            try {
              if (await outputFile.exists()) {
                await outputFile.delete();
              }
            } catch (_) {}
          }
        }
        return outputFile;
      }
    } finally {
      await input.close();
    }

    final plain = await decryptDownloaded(
      await ciphertextFile.readAsBytes(),
      fileKeyB64: fileKeyB64,
    );
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(plain, flush: true);
    return outputFile;
  }

  static String _randTag() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

class AttachmentEncryptedFileBundle {
  const AttachmentEncryptedFileBundle({
    required this.fileKeyB64,
    required this.ciphertextFile,
    required this.plaintextSizeBytes,
    required this.ciphertextSizeBytes,
    required this.sha256B64,
    this.mime,
  });

  final String fileKeyB64;
  final File ciphertextFile;
  final int plaintextSizeBytes;
  final int ciphertextSizeBytes;
  final String sha256B64;
  final String? mime;
}

String pJoin(String a, String b) {
  if (a.endsWith(Platform.pathSeparator)) return '$a$b';
  return '$a${Platform.pathSeparator}$b';
}

class EncryptedAttachment {
  const EncryptedAttachment({
    required this.blobId,
    required this.ciphertextSizeBytes,
    required this.expiresAtMs,
    required this.fileKeyB64,
    required this.blobAccessTokenB64,
    this.mime,
    required this.debugTag,
  });

  final String blobId;
  final int ciphertextSizeBytes;
  final int expiresAtMs;
  final String fileKeyB64;
  final String blobAccessTokenB64;
  final String? mime;
  final String debugTag;
}

class AttachmentUploadBundle {
  const AttachmentUploadBundle({
    required this.fileKeyB64,
    required this.ciphertext,
    required this.plaintextSizeBytes,
    this.mime,
  });

  final String fileKeyB64;
  final Uint8List ciphertext;
  final int plaintextSizeBytes;
  final String? mime;
}

Uint8List _randomBytes(int n) {
  final r = Random.secure();
  final out = Uint8List(n);
  for (var i = 0; i < out.length; i++) {
    out[i] = r.nextInt(256);
  }
  return out;
}

bool _hasV1Magic(List<int> bytes) {
  return bytes.length >= 5 &&
      bytes[0] == 0x53 &&
      bytes[1] == 0x41 &&
      bytes[2] == 0x54 &&
      bytes[3] == 0x54 &&
      bytes[4] == 0x31;
}

Future<Uint8List> _readExact(RandomAccessFile file, int byteCount) async {
  final bytes = await file.read(byteCount);
  if (bytes.length != byteCount) {
    throw StateError('truncated attachment');
  }
  return bytes;
}

Future<Uint8List?> _readExactOrNull(
  RandomAccessFile file,
  int byteCount,
) async {
  final bytes = await file.read(byteCount);
  if (bytes.isEmpty) {
    return null;
  }
  if (bytes.length != byteCount) {
    throw StateError('truncated attachment');
  }
  return bytes;
}
