// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// В-1 (разбор медиа 22.11.2026): расшифровка вложения ПО МЕРЕ скачивания.
///
/// Раньше шифротекст качался целиком, и только потом весь файл
/// расшифровывался в изоляте — ролик в 100 МБ после 100 % ждал ещё 2–4 с
/// (≈29 МБ/с на Mac, на телефоне медленнее). Формат v1 — независимые куски
/// по 64 КБ (одноразовое число = префикс + номер куска), поэтому каждый
/// докачанный кусок расшифровывается сразу.
///
/// Как устроено:
///  • скачивание, как и прежде, пишет шифротекст в файл-кусок (с докачкой);
///  • отдельный изолят читает ЭТОТ ЖЕ файл с начала — вместе с тем, что
///    осталось от прошлой оборванной попытки, — и пишет открытый текст во
///    временный файл; главный поток только сообщает «на диске уже N байт»;
///  • после скачивания изолят дочитывает хвост и отвечает «готово».
///
/// Любой сбой (не v1, неверная метка, лишние байты в конце, изолят не
/// поднялся) — ответ «не вышло», и вызывающий расшифровывает файл целиком
/// прежним путём: результат и ошибки ровно те же, что были. Протокол и
/// формат не меняются.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Выключатель В-1. `false` — прежний путь: скачать целиком, потом
/// расшифровать.
const bool kStreamingDecrypt = true;

/// Мельче — выигрыша нет (весь файл расшифровывается за миллисекунды), а
/// изолят всё равно поднимать.
const int kStreamingDecryptMinBytes = 1024 * 1024;

const int _nonceLen = 24;
const int _macLen = 16;
const int _noncePrefixLen = 16;
const int _headerLen = 5 + 1 + 4 + _noncePrefixLen;
const int _readBlock = 512 * 1024;

/// Не формат v1 (или испорченный заголовок) — частями не расшифровать.
class AttachmentNotStreamable implements Exception {
  const AttachmentNotStreamable(this.reason);
  final String reason;
  @override
  String toString() => 'AttachmentNotStreamable($reason)';
}

/// Расшифровка v1 по кускам из потока байтов — без файлов и изолятов,
/// поэтому проверяется напрямую. Байты подаются [add] в любом дроблении;
/// каждый целый кусок расшифровывается и отдаётся в `write` по порядку.
class AttachmentV1StreamDecryptor {
  AttachmentV1StreamDecryptor(List<int> key)
    : _key = SecretKey(List<int>.of(key));

  final SecretKey _key;
  final Xchacha20 _algo = Xchacha20.poly1305Aead();

  Uint8List _carry = Uint8List(0);
  Uint8List? _noncePrefix;
  int _counter = 0;
  int _chunkSize = 0;

  /// Размер куска из заголовка (0 — заголовок ещё не прочитан). В-2: по нему
  /// и длине шифротекста считается точная длина открытого текста.
  int get chunkSize => _chunkSize;

  int chunksDecoded = 0;
  int bytesWritten = 0;

  /// Заголовок прочитан, и после последнего целого куска ничего не осталось.
  bool get cleanEnd => _noncePrefix != null && _carry.isEmpty;

  Future<void> add(
    List<int> data,
    Future<void> Function(List<int> plain) write,
  ) async {
    if (data.isEmpty) return;
    final buf = Uint8List(_carry.length + data.length)
      ..setRange(0, _carry.length, _carry)
      ..setRange(_carry.length, _carry.length + data.length, data);
    var off = 0;
    if (_noncePrefix == null) {
      if (buf.length < _headerLen) {
        _carry = buf;
        return;
      }
      if (!(buf[0] == 0x53 &&
          buf[1] == 0x41 &&
          buf[2] == 0x54 &&
          buf[3] == 0x54 &&
          buf[4] == 0x31)) {
        throw const AttachmentNotStreamable('magic');
      }
      if (buf[5] != 0x01) throw const AttachmentNotStreamable('version');
      final chunkSize = ByteData.sublistView(buf, 6, 10).getUint32(0, Endian.big);
      if (chunkSize <= 0 || chunkSize > 4 * 1024 * 1024) {
        throw const AttachmentNotStreamable('chunk_size');
      }
      _chunkSize = chunkSize;
      _noncePrefix = Uint8List.fromList(buf.sublist(10, _headerLen));
      off = _headerLen;
    }
    while (buf.length - off >= 4) {
      final plainLen = ByteData.sublistView(buf, off, off + 4).getUint32(0, Endian.big);
      final frameLen = 4 + _macLen + plainLen;
      if (buf.length - off < frameLen) break;
      final mac = Uint8List.fromList(buf.sublist(off + 4, off + 4 + _macLen));
      final ct = Uint8List.sublistView(buf, off + 4 + _macLen, off + frameLen);
      final nonce = Uint8List(_nonceLen)..setRange(0, _noncePrefixLen, _noncePrefix!);
      final c = ByteData(8)..setUint64(0, _counter, Endian.big);
      nonce.setRange(_noncePrefixLen, _nonceLen, c.buffer.asUint8List());
      _counter++;
      final plain = await _algo.decrypt(
        SecretBox(ct, nonce: nonce, mac: Mac(mac)),
        secretKey: _key,
      );
      await write(plain);
      chunksDecoded++;
      bytesWritten += plain.length;
      off += frameLen;
    }
    _carry = off == 0 ? buf : Uint8List.fromList(buf.sublist(off));
  }
}

/// Итог расшифровки частями.
class StreamingDecryptResult {
  const StreamingDecryptResult({
    required this.ok,
    this.reason,
    this.chunks = 0,
    this.bytes = 0,
  });

  /// `true` — выходной файл полон и верен. Иначе его нет, и вызывающий
  /// расшифровывает целиком.
  final bool ok;
  final String? reason;
  final int chunks;
  final int bytes;
}

/// Сеанс: изолят, который идёт следом за скачиванием по файлу-куску.
class StreamingAttachmentDecrypt {
  StreamingAttachmentDecrypt._();

  final ReceivePort _fromWorker = ReceivePort();
  final ReceivePort _onExit = ReceivePort();
  final Completer<StreamingDecryptResult> _result =
      Completer<StreamingDecryptResult>();
  SendPort? _toWorker;
  Isolate? _isolate;
  int _avail = 0;
  int? _finish;
  bool _abort = false;
  void Function(int plainBytes, int chunkSize)? _onDecrypted;
  void Function()? _onFailed;

  /// Поднять изолят. `null` — ключ не того размера (расшифрует прежний
  /// путь и сообщит ту же ошибку).
  ///
  /// [onDecrypted] (В-2): «во временном файле уже N байт открытого текста»
  /// и размер куска из заголовка — для воспроизведения до конца скачивания.
  static StreamingAttachmentDecrypt? start({
    required String partPath,
    required String outPath,
    required String fileKeyB64,
    void Function(int plainBytes, int chunkSize)? onDecrypted,
    void Function()? onFailed,
  }) {
    final Uint8List key;
    try {
      key = base64Decode(fileKeyB64);
    } catch (_) {
      return null;
    }
    if (key.length != 32) return null;
    final s = StreamingAttachmentDecrypt._()
      .._onDecrypted = onDecrypted
      .._onFailed = onFailed;
    s._fromWorker.listen(s._onMessage);
    s._onExit.listen((_) => s._done(
      const StreamingDecryptResult(ok: false, reason: 'isolate_exit'),
    ));
    unawaited(
      Isolate.spawn<List<Object?>>(
        _workerMain,
        <Object?>[s._fromWorker.sendPort, partPath, outPath, key],
        debugName: 'attachment-stream-decrypt',
        onExit: s._onExit.sendPort,
        errorsAreFatal: true,
      ).then((iso) {
        s._isolate = iso;
      }, onError: (Object e) {
        s._done(StreamingDecryptResult(
          ok: false,
          reason: 'spawn:${e.runtimeType}',
        ));
      }),
    );
    return s;
  }

  void _onMessage(Object? msg) {
    if (msg is SendPort) {
      _toWorker = msg;
      if (_abort) {
        msg.send(const <Object?>['x']);
        return;
      }
      if (_avail > 0) msg.send(<Object?>['a', _avail]);
      final f = _finish;
      if (f != null) msg.send(<Object?>['f', f]);
      return;
    }
    if (msg is List && msg.length >= 3 && msg[0] == 'p') {
      final cb = _onDecrypted;
      if (cb != null && !_result.isCompleted) {
        try {
          cb(msg[1] as int, msg[2] as int);
        } catch (_) {}
      }
      return;
    }
    if (msg is List && msg.isNotEmpty && msg[0] == 'r') {
      _done(StreamingDecryptResult(
        ok: msg[1] as bool,
        reason: msg[2] as String?,
        chunks: msg[3] as int,
        bytes: msg[4] as int,
      ));
    }
  }

  void _done(StreamingDecryptResult r) {
    if (_result.isCompleted) return;
    // В-2: плееру — сразу, а не после скачивания: выходного файла уже нет.
    if (!r.ok) {
      try {
        _onFailed?.call();
      } catch (_) {}
    }
    _result.complete(r);
    _fromWorker.close();
    _onExit.close();
  }

  /// На диске файла-куска уже [bytes] байт (с учётом прошлой попытки).
  void notifyAvailable(int bytes) {
    if (bytes <= _avail || _result.isCompleted) return;
    _avail = bytes;
    _toWorker?.send(<Object?>['a', bytes]);
  }

  /// Скачивание закончено, длина файла-куска — [totalBytes]. Ждёт изолят.
  Future<StreamingDecryptResult> finish(int totalBytes) {
    if (!_result.isCompleted) {
      _finish = totalBytes;
      _toWorker?.send(<Object?>['f', totalBytes]);
    }
    return _result.future;
  }

  /// Скачивание сорвалось: изолят закрывает файлы, удаляет неполный выход.
  Future<void> abort() async {
    if (_result.isCompleted) return;
    _abort = true;
    _toWorker?.send(const <Object?>['x']);
    try {
      await _result.future.timeout(const Duration(seconds: 2));
    } catch (_) {
      _isolate?.kill(priority: Isolate.immediate);
      _done(const StreamingDecryptResult(ok: false, reason: 'abort'));
    }
  }
}

Future<void> _workerMain(List<Object?> args) async {
  final toMain = args[0] as SendPort;
  final partPath = args[1] as String;
  final outPath = args[2] as String;
  final key = args[3] as Uint8List;
  final inbox = ReceivePort();
  final worker = _Worker(partPath, outPath, key, toMain);
  final finished = Completer<List<Object?>>();
  inbox.listen((Object? msg) {
    if (msg is! List || msg.isEmpty) return;
    switch (msg[0]) {
      case 'a':
        worker.avail = msg[1] as int;
      case 'f':
        worker.finishAt = msg[1] as int;
      case 'x':
        worker.aborted = true;
    }
    worker.pump(finished);
  });
  toMain.send(inbox.sendPort);
  final reply = await finished.future;
  inbox.close();
  Isolate.exit(toMain, reply);
}

class _Worker {
  _Worker(this.partPath, this.outPath, List<int> key, this.toMain)
    : decryptor = AttachmentV1StreamDecryptor(key);

  final SendPort toMain;
  final String partPath;
  final String outPath;
  final AttachmentV1StreamDecryptor decryptor;

  int avail = 0;
  int? finishAt;
  bool aborted = false;

  RandomAccessFile? _in;
  RandomAccessFile? _out;
  int _pos = 0;
  bool _running = false;
  bool _kicked = false;

  /// Новое сообщение от главного потока: прогнать цикл (или ещё раз — после
  /// текущего прохода, если он уже идёт).
  void pump(Completer<List<Object?>> finished) {
    if (finished.isCompleted) return;
    if (_running) {
      _kicked = true;
      return;
    }
    _running = true;
    _kicked = false;
    unawaited(
      _loop(finished).whenComplete(() {
        _running = false;
        if (_kicked) pump(finished);
      }),
    );
  }

  Future<void> _loop(Completer<List<Object?>> finished) async {
    try {
      while (true) {
        if (aborted) {
          await _closeAndDelete();
          finished.complete(_reply(false, 'abort'));
          return;
        }
        final end = finishAt ?? avail;
        if (_pos < end) {
          final input = _in ??= await File(partPath).open();
          _out ??= await File(outPath).open(mode: FileMode.write);
          await input.setPosition(_pos);
          final want = end - _pos;
          final bytes = await input.read(want < _readBlock ? want : _readBlock);
          if (bytes.isEmpty) {
            // Ещё не на диске (запись главного потока идёт следом).
            if (finishAt != null) {
              await _closeAndDelete();
              finished.complete(_reply(false, 'short_read'));
              return;
            }
            return;
          }
          _pos += bytes.length;
          final out = _out!;
          final before = decryptor.bytesWritten;
          await decryptor.add(bytes, (plain) => out.writeFrom(plain));
          // В-2: открытый текст уже в файле (writeFrom дошёл до ОС) — главный
          // поток может отдавать его плееру.
          if (decryptor.bytesWritten != before) {
            toMain.send(<Object?>[
              'p',
              decryptor.bytesWritten,
              decryptor.chunkSize,
            ]);
          }
          continue;
        }
        if (finishAt != null) {
          if (!decryptor.cleanEnd) {
            await _closeAndDelete();
            finished.complete(_reply(false, 'trailing'));
            return;
          }
          _out ??= await File(outPath).open(mode: FileMode.write);
          await _in?.close();
          await _out?.close();
          _in = null;
          _out = null;
          finished.complete(_reply(true, null));
          return;
        }
        return;
      }
    } on AttachmentNotStreamable catch (e) {
      await _closeAndDelete();
      if (!finished.isCompleted) finished.complete(_reply(false, e.reason));
    } catch (e) {
      await _closeAndDelete();
      if (!finished.isCompleted) {
        finished.complete(_reply(false, e.runtimeType.toString()));
      }
    }
  }

  List<Object?> _reply(bool ok, String? reason) => <Object?>[
    'r',
    ok,
    reason,
    decryptor.chunksDecoded,
    decryptor.bytesWritten,
  ];

  Future<void> _closeAndDelete() async {
    try {
      await _in?.close();
    } catch (_) {}
    try {
      await _out?.close();
    } catch (_) {}
    _in = null;
    _out = null;
    try {
      final f = File(outPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
