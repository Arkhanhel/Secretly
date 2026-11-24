// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// В-2 (разбор медиа 22.11.2026): ролик играет ДО конца скачивания.
///
/// В-1 уже расшифровывает вложение по ходу скачивания во временный файл
/// открытого текста. Здесь этот растущий файл отдаётся плееру:
///
///  • [ProgressiveMediaFeed] — «во временном файле уже N байт», точная длина
///    открытого текста (по длине шифротекста и размеру куска — сверяется с
///    размером из сообщения), конец или сбой; после переименования в кэш —
///    новый путь;
///  • [LoopbackMediaServer] — HTTP только на 127.0.0.1, случайный порт и
///    случайная метка в пути; `Content-Length`, `Accept-Ranges`, ответ на
///    `Range` ждёт, пока расшифровка дойдёт до нужного байта. AVPlayer без
///    `Range` и длины не играет; ExoPlayer с HTTP надёжнее растущего файла;
///  • [detectMp4Layout] — только MP4/MOV, у которых `moov` раньше `mdat`
///    (`faststart`): иначе плееру нужен конец файла, и ждать всё равно
///    придётся — тогда как раньше.
///
/// Любой сбой — прежнее поведение: просмотр ждёт полный файл. Протокол и
/// формат не меняются — всё на этом устройстве.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../diagnostics/diag_log.dart';

/// Выключатель В-2. `false` — прежний путь: плеер открывается только на
/// полном файле.
const bool kProgressivePlayback = true;

/// Сколько первых байт смотреть в поисках `moov` (если раньше не решилось).
const int kProgressiveHeadScanBytes = 256 * 1024;

/// Ролик, который можно играть по ходу скачивания: MP4/MOV/M4V/3GP.
bool progressivePlaybackMime(String? mime) {
  final m = (mime ?? '').toLowerCase().trim();
  return m == 'video/mp4' ||
      m == 'video/quicktime' ||
      m == 'video/x-m4v' ||
      m == 'video/3gpp';
}

/// Только телефоны: на Windows переименовать открытый файл нельзя, а ПК
/// держит свой просмотр.
bool get progressivePlaybackPlatform =>
    kProgressivePlayback && !kIsWeb && (Platform.isAndroid || Platform.isIOS);

// ─── Порядок коробок ────────────────────────────────────────────────────────

enum Mp4Layout {
  /// `moov` раньше `mdat` — играть можно с начала файла.
  faststart,

  /// `mdat` (или фрагменты) раньше `moov` — плееру нужен конец файла.
  notFaststart,

  /// Не MP4/MOV.
  notMp4,

  /// Байтов пока мало, чтобы решить.
  unknown,
}

const Set<String> _topLevelBoxes = <String>{
  'ftyp', 'free', 'skip', 'wide', 'pdin', 'uuid', 'moov', 'mdat', 'styp', //
  'sidx', 'moof', 'mfra', 'meta', 'junk', 'pnot', 'prfl', 'PICT',
};

/// Порядок коробок верхнего уровня по первым байтам файла. Читает только
/// заголовки коробок (8 или 16 байт) и перескакивает их тела.
Mp4Layout detectMp4Layout(Uint8List head) {
  var off = 0;
  while (off + 8 <= head.length) {
    final bd = ByteData.sublistView(head, off, off + 8);
    var size = bd.getUint32(0, Endian.big);
    final type = String.fromCharCodes(head.sublist(off + 4, off + 8));
    // Незнакомая коробка (или вовсе не MP4) — не рискуем.
    if (!_topLevelBoxes.contains(type)) return Mp4Layout.notMp4;
    if (type == 'moov') return Mp4Layout.faststart;
    if (type == 'mdat' || type == 'moof') return Mp4Layout.notFaststart;
    var header = 8;
    if (size == 1) {
      if (off + 16 > head.length) return Mp4Layout.unknown;
      final big = ByteData.sublistView(head, off + 8, off + 16)
          .getUint64(0, Endian.big);
      if (big > 0x7fffffffffff) return Mp4Layout.notMp4;
      size = big;
      header = 16;
    } else if (size == 0) {
      // Коробка до конца файла, и это не moov — дальше ничего нет.
      return Mp4Layout.notFaststart;
    }
    if (size < header) return Mp4Layout.notMp4;
    off += size;
  }
  return Mp4Layout.unknown;
}

/// Точная длина открытого текста v1 по длине шифротекста: заголовок 26 байт,
/// каждый кусок — 4 байта длины + 16 байт метки + данные. Формула верна и
/// тогда, когда в конце стоит пустой кусок.
int? attachmentV1PlainLength(int ciphertextBytes, int chunkSize) {
  const header = 5 + 1 + 4 + 16;
  const overhead = 4 + 16;
  if (chunkSize <= 0 || ciphertextBytes < header) return null;
  final body = ciphertextBytes - header;
  if (body == 0) return 0;
  final frames = (body + chunkSize + overhead - 1) ~/ (chunkSize + overhead);
  final plain = body - overhead * frames;
  return plain < 0 ? null : plain;
}

// ─── Растущий файл ──────────────────────────────────────────────────────────

/// Временный файл открытого текста, который пишет изолят В-1.
class ProgressiveMediaFeed {
  ProgressiveMediaFeed({
    required this.blobId,
    required this.mime,
    required String path,
    required this.declaredBytes,
    int? totalBytes,
  }) : _path = path,
       _totalBytes = totalBytes;

  final String blobId;
  final String? mime;

  /// Размер из сообщения (от отправителя). Сверяется с вычисленным.
  final int declaredBytes;

  String _path;
  int? _totalBytes;
  int? _ciphertextTotal;
  int _chunkSize = 0;
  int _available = 0;
  bool _complete = false;
  bool _failed = false;
  bool _mismatchLogged = false;
  final List<({int need, Completer<bool> done})> _waiters =
      <({int need, Completer<bool> done})>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Где сейчас лежит файл (после скачивания — в кэше вложений).
  String get path => _path;

  /// Точная длина открытого текста, если уже известна.
  int? get totalBytes => _totalBytes;
  int get available => _available;
  bool get isComplete => _complete;
  bool get isFailed => _failed;

  /// Любое изменение: байты, длина, конец, сбой.
  Stream<void> get changes => _changes.stream;

  /// Скачано [received] из [total] байт шифротекста (длина от сервера).
  void reportCiphertextTotal(int? total) {
    if (total == null || total <= 0 || _ciphertextTotal == total) return;
    _ciphertextTotal = total;
    _resolveTotal();
  }

  /// Изолят: в файле уже [plainBytes] байт, размер куска [chunkSize].
  void reportDecrypted(int plainBytes, int chunkSize) {
    if (_complete || _failed) return;
    if (chunkSize > 0 && _chunkSize != chunkSize) {
      _chunkSize = chunkSize;
      _resolveTotal();
    }
    if (plainBytes <= _available) return;
    _available = plainBytes;
    _wake();
  }

  void _resolveTotal() {
    final ct = _ciphertextTotal;
    if (ct == null || _chunkSize <= 0 || _totalBytes != null) return;
    final plain = attachmentV1PlainLength(ct, _chunkSize);
    if (plain == null || plain <= 0) return;
    _totalBytes = plain;
    if (declaredBytes > 0 && declaredBytes != plain && !_mismatchLogged) {
      // Старые сборки считали размер до очистки метаданных (П13). Верим
      // шифротексту: ровно столько байт расшифруется.
      _mismatchLogged = true;
      DiagLog.event('media', 'progressive_size_mismatch', {
        'shorter': plain < declaredBytes,
      });
    }
    _wake();
  }

  /// Скачано и переименовано: файл целиком лежит по [finalPath].
  void complete(String finalPath, {int? length}) {
    if (_complete || _failed) return;
    _path = finalPath;
    _complete = true;
    if (length != null) {
      _available = length;
      _totalBytes ??= length;
    } else if (_totalBytes != null) {
      _available = _totalBytes!;
    }
    _wake();
  }

  /// Скачивание или расшифровка частями сорвались.
  void fail() {
    if (_complete || _failed) return;
    _failed = true;
    _wake();
  }

  /// Дождаться, пока в файле будет не меньше [need] байт. `false` — сбой
  /// (или файл кончился раньше).
  Future<bool> waitFor(int need) {
    if (_failed) return Future<bool>.value(false);
    if (_available >= need) return Future<bool>.value(true);
    if (_complete) return Future<bool>.value(false);
    final c = Completer<bool>();
    _waiters.add((need: need, done: c));
    return c.future;
  }

  void _wake() {
    if (_waiters.isNotEmpty) {
      final keep = <({int need, Completer<bool> done})>[];
      for (final w in _waiters) {
        if (_failed) {
          w.done.complete(false);
        } else if (_available >= w.need) {
          w.done.complete(true);
        } else if (_complete) {
          w.done.complete(false);
        } else {
          keep.add(w);
        }
      }
      _waiters
        ..clear()
        ..addAll(keep);
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Первые байты файла (не больше [max] и не больше расшифрованного).
  Future<Uint8List> readHead(int max) async {
    final n = math.min(max, _available);
    if (n <= 0) return Uint8List(0);
    final raf = await File(_path).open();
    try {
      return await raf.read(n);
    } finally {
      await raf.close();
    }
  }
}

/// Растущие файлы, которые качаются прямо сейчас, по blobId.
class ProgressiveMediaFeeds {
  ProgressiveMediaFeeds._();

  static final Map<String, ProgressiveMediaFeed> _feeds =
      <String, ProgressiveMediaFeed>{};
  static final StreamController<String> _added =
      StreamController<String>.broadcast();

  /// Контроллер: скачивание вложения началось, расшифровка идёт частями.
  /// `null` — не ролик, не телефон, выключено или этот blob уже отдаётся.
  static ProgressiveMediaFeed? begin({
    required String blobId,
    required String? mime,
    required String path,
    required int declaredBytes,
  }) {
    if (!progressivePlaybackPlatform) return null;
    final key = blobId.trim();
    if (key.isEmpty || !progressivePlaybackMime(mime)) return null;
    if (_feeds.containsKey(key)) return null;
    final feed = ProgressiveMediaFeed(
      blobId: key,
      mime: mime,
      path: path,
      declaredBytes: declaredBytes,
    );
    register(feed);
    return feed;
  }

  /// Положить файл в реестр (и для тестов).
  @visibleForTesting
  static void register(ProgressiveMediaFeed feed) {
    _feeds[feed.blobId] = feed;
    // Кончился или сорвался — из реестра (новый просмотр возьмёт файл);
    // уже открытый сервер держит объект сам.
    late final StreamSubscription<void> sub;
    sub = feed.changes.listen((_) {
      if (feed.isComplete || feed.isFailed) {
        if (identical(_feeds[feed.blobId], feed)) _feeds.remove(feed.blobId);
        unawaited(sub.cancel());
      }
    });
    if (!_added.isClosed) _added.add(feed.blobId);
  }

  static ProgressiveMediaFeed? of(String blobId) => _feeds[blobId.trim()];

  @visibleForTesting
  static void clear() => _feeds.clear();

  /// Дождаться, пока появится файл для [blobId]; `null`, если раньше
  /// закончилось [until] (файл скачан, сбой или скачивание шло без частей).
  static Future<ProgressiveMediaFeed?> waitFor(
    String blobId, {
    required Future<void> until,
  }) {
    final key = blobId.trim();
    final now = _feeds[key];
    if (now != null) return Future<ProgressiveMediaFeed?>.value(now);
    final c = Completer<ProgressiveMediaFeed?>();
    late final StreamSubscription<String> sub;
    sub = _added.stream.listen((id) {
      if (id != key || c.isCompleted) return;
      c.complete(_feeds[key]);
      unawaited(sub.cancel());
    });
    unawaited(until.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (c.isCompleted) return;
      c.complete(_feeds[key]);
      unawaited(sub.cancel());
    }));
    return c.future;
  }
}

/// Решить, можно ли играть [feed] по ходу скачивания: длина известна и
/// `moov` раньше `mdat`. Ждёт байтов, пока не решится; `null` — нельзя
/// (тогда как раньше).
Future<({Mp4Layout layout, String? reason})> resolveProgressiveLayout(
  ProgressiveMediaFeed feed, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    if (feed.isFailed) return (layout: Mp4Layout.unknown, reason: 'failed');
    if (feed.isComplete) {
      return (layout: Mp4Layout.unknown, reason: 'complete');
    }
    if (feed.totalBytes != null && feed.available > 0) {
      final head = await feed.readHead(kProgressiveHeadScanBytes);
      final layout = detectMp4Layout(head);
      if (layout != Mp4Layout.unknown) return (layout: layout, reason: null);
      if (head.length >= kProgressiveHeadScanBytes) {
        return (layout: Mp4Layout.notFaststart, reason: 'no_moov_in_head');
      }
    }
    final left = deadline.difference(DateTime.now());
    if (left <= Duration.zero) {
      return (layout: Mp4Layout.unknown, reason: 'timeout');
    }
    // Новые байты, длина, конец или сбой — что-то из этого сдвинет решение.
    final moved = Completer<void>();
    final sub = feed.changes.listen((_) {
      if (!moved.isCompleted) moved.complete();
    });
    try {
      await moved.future.timeout(left, onTimeout: () {});
    } finally {
      await sub.cancel();
    }
  }
}

/// Открыть ролик [blobId] для плеера по ходу скачивания. `null` — нельзя
/// или незачем (файл уже скачан, не `faststart`, не ролик, выключено):
/// вызывающий ждёт полный файл, как раньше.
Future<LoopbackMediaServer?> openProgressivePlayback(
  String blobId, {
  required Future<void> until,
}) async {
  if (!progressivePlaybackPlatform) return null;
  return openProgressivePlaybackForTest(blobId, until: until);
}

@visibleForTesting
Future<LoopbackMediaServer?> openProgressivePlaybackForTest(
  String blobId, {
  required Future<void> until,
}) async {
  try {
    final feed = await ProgressiveMediaFeeds.waitFor(blobId, until: until);
    if (feed == null || feed.isComplete || feed.isFailed) return null;
    final sw = Stopwatch()..start();
    final r = await resolveProgressiveLayout(feed);
    if (r.layout != Mp4Layout.faststart) {
      DiagLog.event('media', 'progressive_skip', {
        'layout': r.layout.name,
        if (r.reason != null) 'reason': r.reason,
      });
      return null;
    }
    final server = await LoopbackMediaServer.start(feed);
    DiagLog.event('media', 'progressive_start', {
      'head_ms': sw.elapsedMilliseconds,
      'ready_pct': feed.totalBytes == null || feed.totalBytes == 0
          ? 0
          : (feed.available * 100 ~/ feed.totalBytes!),
    });
    return server;
  } catch (e) {
    DiagLog.event('media', 'progressive_skip', {
      'reason': e.runtimeType.toString(),
    });
    return null;
  }
}

// ─── Локальный HTTP ─────────────────────────────────────────────────────────

/// HTTP на 127.0.0.1 для одного растущего файла.
class LoopbackMediaServer {
  LoopbackMediaServer._(this._server, this.feed, this._token, this._ext);

  final HttpServer _server;
  final ProgressiveMediaFeed feed;
  final String _token;
  final String _ext;
  final Completer<void> _closed = Completer<void>();
  final Set<Socket> _sockets = <Socket>{};
  int _waitingCount = 0;

  /// Хоть один ответ сейчас ждёт расшифровки — для знака буферизации.
  final ValueNotifier<bool> waiting = ValueNotifier<bool>(false);

  static const int _block = 256 * 1024;

  static Future<LoopbackMediaServer> start(ProgressiveMediaFeed feed) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final rnd = math.Random.secure();
    final token = List<String>.generate(
      16,
      (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final mime = (feed.mime ?? '').toLowerCase();
    final ext = mime == 'video/quicktime'
        ? '.mov'
        : mime == 'video/x-m4v'
        ? '.m4v'
        : mime == 'video/3gpp'
        ? '.3gp'
        : '.mp4';
    final s = LoopbackMediaServer._(server, feed, token, ext);
    server.listen(
      (req) => unawaited(s._handle(req)),
      onError: (Object _) {},
      cancelOnError: false,
    );
    return s;
  }

  bool get isClosed => _closed.isCompleted;
  int get port => _server.port;

  /// Адрес для плеера: случайный порт и случайная метка в пути.
  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/$_token/media$_ext');

  String get _contentType {
    final m = (feed.mime ?? '').trim();
    return m.isEmpty ? 'video/mp4' : m;
  }

  void _setWaiting(int delta) {
    _waitingCount += delta;
    final w = _waitingCount > 0;
    if (!isClosed && waiting.value != w) waiting.value = w;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      res.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      if (req.uri.path != '/$_token/media$_ext') {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      final isHead = req.method == 'HEAD';
      if (req.method != 'GET' && !isHead) {
        res.statusCode = HttpStatus.methodNotAllowed;
        await res.close();
        return;
      }
      final total = feed.totalBytes;
      if (total == null || total <= 0 || feed.isFailed) {
        res.statusCode = HttpStatus.serviceUnavailable;
        await res.close();
        return;
      }
      final range = parseByteRange(
        req.headers.value(HttpHeaders.rangeHeader),
        total,
      );
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      res.headers.contentType = ContentType.parse(_contentType);
      if (range == null) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
        res.contentLength = 0;
        await res.close();
        return;
      }
      final start = range.start, end = range.end;
      if (range.partial) {
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$total',
        );
      } else {
        res.statusCode = HttpStatus.ok;
      }
      res.contentLength = end - start + 1;
      if (isHead) {
        await res.close();
        return;
      }
      await _stream(res, start, end);
    } catch (_) {
      // Плеер оборвал соединение или сервер закрыт — молча.
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _stream(HttpResponse res, int start, int end) async {
    // Заголовки — сразу (плеер узнаёт длину, даже если байтов ещё ждать), а
    // тело пишем в сокет сами: так обрыв — честный обрыв соединения, а не
    // ответ «короче обещанного». Соединение одноразовое.
    res.persistentConnection = false;
    final socket = await res.detachSocket(writeHeaders: true);
    _sockets.add(socket);
    // Плеер бросил соединение (перемотка, закрытие) — перестать ждать.
    final gone = Completer<bool>();
    unawaited(socket.done.then<void>((_) {
      if (!gone.isCompleted) gone.complete(false);
    }, onError: (Object _) {
      if (!gone.isCompleted) gone.complete(false);
    }));
    socket.listen((_) {}, onError: (Object _) {}, onDone: () {
      if (!gone.isCompleted) gone.complete(false);
    }, cancelOnError: true);
    RandomAccessFile? raf;
    var ok = false;
    try {
      var pos = start;
      while (pos <= end) {
        if (gone.isCompleted || isClosed) return;
        if (feed.available <= pos) {
          _setWaiting(1);
          final bool more;
          try {
            more = await Future.any<bool>([
              feed.waitFor(pos + 1),
              _closed.future.then((_) => false),
              gone.future,
            ]);
          } finally {
            _setWaiting(-1);
          }
          if (!more) return;
          continue;
        }
        // Дескриптор переживает переименование в кэш (POSIX); новый запрос
        // откроет уже новый путь.
        raf ??= await File(feed.path).open();
        final upto = math.min(end + 1, feed.available);
        final n = math.min(_block, upto - pos);
        await raf.setPosition(pos);
        final bytes = await raf.read(n);
        if (bytes.isEmpty) {
          if (feed.isComplete) return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          continue;
        }
        socket.add(bytes);
        await socket.flush();
        pos += bytes.length;
      }
      ok = true;
    } catch (_) {
      // Плеер оборвал соединение или сервер закрыт.
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
      _sockets.remove(socket);
      if (ok) {
        try {
          await socket.close();
        } catch (_) {
          socket.destroy();
        }
      } else {
        socket.destroy();
      }
    }
  }

  /// Закрыть сервер и все соединения (просмотр закрыт или ролик сменился).
  Future<void> close() async {
    if (_closed.isCompleted) return;
    _closed.complete();
    waiting.value = false;
    for (final sk in _sockets.toList()) {
      sk.destroy();
    }
    _sockets.clear();
    try {
      await _server.close(force: true);
    } catch (_) {}
  }
}

/// Разбор `Range: bytes=…` для файла длиной [total]. Без заголовка — весь
/// файл (`partial: false`). `null` — диапазон вне файла (416). Несколько
/// диапазонов не поддерживаем — отдаём первый.
({int start, int end, bool partial})? parseByteRange(String? header, int total) {
  if (header == null || header.trim().isEmpty) {
    return (start: 0, end: total - 1, partial: false);
  }
  final h = header.trim().toLowerCase();
  if (!h.startsWith('bytes=')) return (start: 0, end: total - 1, partial: false);
  final spec = h.substring(6).split(',').first.trim();
  final dash = spec.indexOf('-');
  if (dash < 0) return null;
  final a = spec.substring(0, dash).trim();
  final b = spec.substring(dash + 1).trim();
  if (a.isEmpty) {
    // Последние N байт.
    final n = int.tryParse(b);
    if (n == null || n <= 0) return null;
    final start = math.max(0, total - n);
    return (start: start, end: total - 1, partial: true);
  }
  final start = int.tryParse(a);
  if (start == null || start < 0 || start >= total) return null;
  var end = b.isEmpty ? total - 1 : (int.tryParse(b) ?? -1);
  if (end < start) return null;
  if (end >= total) end = total - 1;
  return (start: start, end: end, partial: true);
}
