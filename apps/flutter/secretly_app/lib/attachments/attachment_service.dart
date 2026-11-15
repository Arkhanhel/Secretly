// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;

import '../diagnostics/diag_log.dart';
import '../security/auth_signer.dart';
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
    final ciphertext = await _offMainThread(
      plaintext.length,
      () => _encryptV0Pure(plaintext, key),
    );
    return AttachmentUploadBundle(
      fileKeyB64: base64Encode(key),
      ciphertext: ciphertext,
      plaintextSizeBytes: plaintext.length,
      mime: mime,
    );
  }

  /// Шифрование v0 в памяти: nonce(24) + mac(16) + шифртекст. Без состояния —
  /// годится для изолята.
  static Future<Uint8List> _encryptV0Pure(
    Uint8List plaintext,
    Uint8List key,
  ) async {
    final algo = Xchacha20.poly1305Aead();
    final box = await algo.encrypt(plaintext, secretKey: SecretKey(key));
    final out = BytesBuilder(copy: false);
    out.add(box.nonce);
    out.add(box.mac.bytes);
    out.add(box.cipherText);
    return out.takeBytes();
  }

  /// Порог, начиная с которого шифрование и расшифровка в памяти уходят в
  /// отдельный изолят (14.11.2026). Чистый Dart считает XChaCha20 синхронно:
  /// снимок в 24 МБ занимал главный поток на секунды — кадры не рисовались,
  /// Android показывал «приложение не отвечает». Мелочь дешевле посчитать на
  /// месте, чем копировать в изолят.
  static const int offMainThreadMinBytes = 256 * 1024;

  /// Считает [work] в отдельном изоляте, а при любом сбое там — на месте.
  /// Ошибка самой криптографии (неверная метка подлинности) поэтому всегда
  /// приходит из расчёта на месте — с тем же типом и текстом, что и раньше.
  static Future<Uint8List> _offMainThread(
    int size,
    Future<Uint8List> Function() work,
  ) async {
    if (size < offMainThreadMinBytes || kIsWeb) return work();
    try {
      return await Isolate.run(work, debugName: 'attachment-crypto');
    } catch (e) {
      DiagLog.event('attachments', 'crypto_isolate_fallback', {
        'bytes': size,
        'reason': e.runtimeType.toString(),
      });
      return work();
    }
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

    final outPath = pJoin(
      tempDir.path,
      'secretly_att_${DateTime.now().millisecondsSinceEpoch}_${_randTag()}.bin',
    );
    final outFile = File(outPath);
    final noncePrefix = _randomBytes(_v1NoncePrefixLen);
    final inPath = plaintextFile.path;

    // О12 (разбор медиа 15.11.2026): шифрование файла частями — тоже вне
    // главного потока, как шифрование в памяти с 14.11. Чистый Dart считает
    // XChaCha20 синхронно: ролик в сотни МБ держал интерфейс. Сбой изолята —
    // считаем на месте, с чистого листа.
    Uint8List digestBytes;
    if (kIsWeb) {
      digestBytes = await _encryptFileV1Pure(
        inPath,
        outPath,
        key,
        noncePrefix,
        chunkSize,
      );
    } else {
      try {
        digestBytes = await Isolate.run(
          () => _encryptFileV1Pure(inPath, outPath, key, noncePrefix, chunkSize),
          debugName: 'attachment-crypto-file',
        );
      } catch (e) {
        DiagLog.event('attachments', 'crypto_isolate_fallback', {
          'bytes': plainLen,
          'reason': e.runtimeType.toString(),
          'file': true,
        });
        try {
          if (await outFile.exists()) await outFile.delete();
        } catch (_) {}
        digestBytes = await _encryptFileV1Pure(
          inPath,
          outPath,
          key,
          noncePrefix,
          chunkSize,
        );
      }
    }

    final cipherLen = await outFile.length();
    return AttachmentEncryptedFileBundle(
      fileKeyB64: base64Encode(key),
      ciphertextFile: outFile,
      plaintextSizeBytes: plainLen,
      ciphertextSizeBytes: cipherLen,
      sha256B64: base64Encode(digestBytes),
      mime: mime,
    );
  }

  /// Формат v1 частями (см. [encryptFileForUpload]); возвращает SHA-256
  /// шифротекста. Статическая и без `this` — выполняется в изоляте.
  static Future<Uint8List> _encryptFileV1Pure(
    String inPath,
    String outPath,
    Uint8List key,
    Uint8List noncePrefix,
    int chunkSize,
  ) async {
    final secretKey = SecretKey(key);
    final algo = Xchacha20.poly1305Aead();
    final out = await File(outPath).open(mode: FileMode.write);
    final digestSink = AccumulatorSink<crypto.Digest>();
    final hashSink = crypto.sha256.startChunkedConversion(digestSink);

    Future<void> writeAll(List<int> bytes) async {
      hashSink.add(bytes);
      await out.writeFrom(bytes);
    }

    final header = BytesBuilder(copy: false);
    header.add(_magic);
    header.add([0x01]);
    final cs = ByteData(4)..setUint32(0, chunkSize, Endian.big);
    header.add(cs.buffer.asUint8List());
    header.add(noncePrefix);

    final inFile = await File(inPath).open();
    try {
      await writeAll(header.takeBytes());
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
    return Uint8List.fromList(digestSink.events.single.bytes);
  }

  /// Расшифровка формата v1 в файл. Без `this` — выполняется в изоляте.
  /// Сбой: выходной файл удаляется, бросается [_DecryptFailure] с исходной
  /// ошибкой и счётчиками для журнала.
  static Future<void> _decryptFileV1Pure(
    String inPath,
    String outPath,
    Uint8List key,
    Uint8List noncePrefix,
    int headerLen,
  ) async {
    final algo = Xchacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    final input = await File(inPath).open();
    final output = await File(outPath).open(mode: FileMode.write);
    var failed = false;
    var chunksDecoded = 0;
    var bytesWritten = 0;
    try {
      await input.setPosition(headerLen);
      var counter = 0;
      while (true) {
        final lenBytes = await _readExactOrNull(input, 4);
        if (lenBytes == null) break;
        final plainLen = ByteData.sublistView(lenBytes).getUint32(0, Endian.big);
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
        final plain = await algo.decrypt(box, secretKey: secretKey);
        await output.writeFrom(plain);
        chunksDecoded++;
        bytesWritten += plain.length;
      }
    } catch (e, st) {
      failed = true;
      throw _DecryptFailure(e, st, chunksDecoded, bytesWritten);
    } finally {
      await input.close();
      await output.close();
      if (failed) {
        try {
          final f = File(outPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  /// v0: encrypt whole file in-memory (MVP). Later: chunked streaming.
  Future<EncryptedAttachment> encryptAndUpload(
    Uint8List plaintext, {
    required int ttlSeconds,
    String? mime,
    // Отправка частями с докачкой (флаг `media`, 15.11.2026): ход загрузки и
    // отмена — как у больших файлов. Без флага — прежний один запрос.
    bool resumable = false,
    void Function(int sentBytes, int totalBytes)? onUploadProgress,
    BlobUploadCancelToken? cancelToken,
  }) async {
    final bundle = await encryptForUpload(plaintext, mime: mime);
    final blobAccessTokenB64 = base64Encode(_randomBytes(_blobAccessTokenLen));
    final cipher = bundle.ciphertext;
    BlobUploadResult? viaSession;
    if (resumable) {
      try {
        viaSession = await blobClient.uploadCiphertextResumable(
          length: cipher.length,
          read: (offset, n) async => Uint8List.sublistView(
            cipher,
            offset,
            offset + n,
          ),
          ttlSeconds: ttlSeconds,
          bodySha256B64: await AuthSigner.sha256B64(cipher),
          accessTokenB64: blobAccessTokenB64,
          onProgress: onUploadProgress,
          cancelToken: cancelToken,
        );
      } on BlobResumableUnsupported {
        viaSession = null;
      }
    }
    final upload =
        viaSession ??
        await blobClient.uploadCiphertext(
          cipher,
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
    bool resumable = false,
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
    BlobUploadResult? upload;
    try {
      if (resumable) {
        final raf = await bundle.ciphertextFile.open();
        try {
          upload = await blobClient.uploadCiphertextResumable(
            length: bundle.ciphertextSizeBytes,
            read: (offset, n) async {
              await raf.setPosition(offset);
              return raf.read(n);
            },
            ttlSeconds: ttlSeconds,
            bodySha256B64: bundle.sha256B64,
            accessTokenB64: blobAccessTokenB64,
            onProgress: onUploadProgress,
            cancelToken: cancelToken,
          );
        } on BlobResumableUnsupported {
          upload = null;
        } finally {
          await raf.close();
        }
      }
      upload ??= await blobClient.uploadCiphertextFile(
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
    return _offMainThread(
      ciphertext.length,
      () => _decryptDownloadedPure(ciphertext, key),
    );
  }

  /// Расшифровка вложения в памяти (v1 по кускам или v0). Без состояния —
  /// годится для изолята.
  static Future<Uint8List> _decryptDownloadedPure(
    Uint8List ciphertext,
    Uint8List key,
  ) async {

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
        await outputFile.parent.create(recursive: true);
        final inPath = ciphertextFile.path;
        final outPath = outputFile.path;
        const headerLen = 5 + 1 + 4 + _v1NoncePrefixLen;
        // О12 (разбор медиа 15.11.2026): расшифровка частями — вне главного
        // потока. Сбой в изоляте (в том числе неверная метка подлинности) —
        // повтор на месте: ошибка и запись в журнал приходят оттуда, с тем же
        // типом и текстом, что и раньше.
        if (!kIsWeb) {
          try {
            await Isolate.run(
              () => _decryptFileV1Pure(
                inPath,
                outPath,
                key,
                noncePrefix,
                headerLen,
              ),
              debugName: 'attachment-crypto-file',
            );
            return outputFile;
          } catch (_) {
            // На месте — ниже.
          }
        }
        try {
          await _decryptFileV1Pure(inPath, outPath, key, noncePrefix, headerLen);
        } on _DecryptFailure catch (f) {
          DiagLog.event('attachment', 'decrypt_failed', {
            'reason': f.cause.runtimeType.toString(),
            'chunks_ok': f.chunksDecoded,
            'bytes_written': f.bytesWritten,
          });
          Error.throwWithStackTrace(f.cause, f.stackTrace);
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

/// Сбой расшифровки v1 со счётчиками для журнала (см. [AttachmentService]).
class _DecryptFailure implements Exception {
  _DecryptFailure(this.cause, this.stackTrace, this.chunksDecoded, this.bytesWritten);

  final Object cause;
  final StackTrace stackTrace;
  final int chunksDecoded;
  final int bytesWritten;
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
