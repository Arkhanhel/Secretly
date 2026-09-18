// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../version/app_package_info.dart';
import 'server_clock.dart';

class _ManagedWebSocketSink implements WebSocketSink {
  _ManagedWebSocketSink({
    required WebSocketSink delegate,
    required this.onClose,
  }) : _delegate = delegate;

  final WebSocketSink _delegate;
  final FutureOr<void> Function({required bool force}) onClose;

  @override
  Future get done => _delegate.done;

  @override
  void add(dynamic event) => _delegate.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _delegate.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) => _delegate.addStream(stream);

  @override
  Future close([int? closeCode, String? closeReason]) async {
    try {
      return await _delegate.close(closeCode, closeReason);
    } finally {
      await onClose(force: false);
    }
  }
}

class _ManagedWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  _ManagedWebSocketChannel({
    required WebSocketChannel delegate,
    required HttpClient client,
  }) : _delegate = delegate,
       _client = client {
    _sink = _ManagedWebSocketSink(
      delegate: delegate.sink,
      onClose: ({required bool force}) => _closeClient(force: force),
    );
    _ready = delegate.ready.then(
      (_) {
        _readyCompleted = true;
      },
      onError: (Object error, StackTrace stackTrace) {
        _readyCompleted = true;
        _closeClient(force: true);
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _stream = delegate.stream.transform(
      StreamTransformer<dynamic, dynamic>.fromHandlers(
        handleDone: (sink) {
          _closeClient(force: false);
          sink.close();
        },
      ),
    );
  }

  final WebSocketChannel _delegate;
  final HttpClient _client;
  late final WebSocketSink _sink;
  late final Future<void> _ready;
  late final Stream<dynamic> _stream;
  bool _readyCompleted = false;
  bool _clientClosed = false;

  Future<void> _closeClient({required bool force}) async {
    if (_clientClosed) return;
    _clientClosed = true;
    _client.close(force: force || !_readyCompleted);
  }

  @override
  int? get closeCode => _delegate.closeCode;

  @override
  String? get closeReason => _delegate.closeReason;

  @override
  String? get protocol => _delegate.protocol;

  @override
  Future<void> get ready => _ready;

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream get stream => _stream;
}

// DELIVERY FIX (2026-06-19): baked-in DNS fallbacks for the Secretly hosts.
// Field diagnosis on a Xiaomi/MIUI device showed the app's own DNS resolver
// intermittently failing ("ClientException with SocketException: Failed host
// lookup: 'keys.secretlyapp.com'") even though the OS resolver (curl/dig) on
// the same phone resolved fine — typical of Android background/Doze network
// throttling and IPv6/AAAA hiccups during network transitions. The result was
// pumpInbox + key-bundle fetch + reset-ping all dying, so inbound messages
// never landed. The resilient HTTP client already knows how to bypass a failed
// DNS lookup by connecting straight to a known IP while keeping TLS/SNI pinned
// to the original hostname — it was just never enabled. These defaults turn it
// on for ALL build paths (override via the dart-define if the infra IP moves;
// the fallback is ONLY used when the normal DNS lookup fails, so a stale entry
// is never worse than today). relay/keys/links are co-hosted on one VPS.
const String _httpDnsFallbacksEnv = String.fromEnvironment(
  'SECRETLY_HTTP_DNS_FALLBACKS',
  defaultValue:
      'relay.secretlyapp.com=116.203.129.95,'
      'keys.secretlyapp.com=116.203.129.95,'
      'links.secretlyapp.com=116.203.129.95',
);

const bool _enableHttpDnsFallbacksForWebSockets = bool.fromEnvironment(
  'SECRETLY_ENABLE_HTTP_DNS_FALLBACKS_FOR_WEBSOCKETS',
  defaultValue: true,
);

Map<String, String> _parseHttpDnsFallbacks(String raw) {
  final parsed = <String, String>{};
  for (final entry in raw.split(RegExp(r'[,;\n\r]+'))) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0 || separator == trimmed.length - 1) continue;
    final host = trimmed.substring(0, separator).trim().toLowerCase();
    final ip = trimmed.substring(separator + 1).trim();
    if (host.isEmpty || ip.isEmpty) continue;
    final address = InternetAddress.tryParse(ip);
    if (address == null || address.type == InternetAddressType.unix) continue;
    parsed[host] = address.address;
  }
  return parsed;
}

bool _isDnsLookupFailure(SocketException error) {
  final code = error.osError?.errorCode;
  if (code == 7 || code == 8 || code == 11001) {
    return true;
  }
  final message = error.message.toLowerCase();
  return message.contains('failed host lookup') ||
      message.contains('nodename nor servname provided') ||
      message.contains('temporary failure in name resolution') ||
      message.contains('name or service not known') ||
      message.contains('no address associated with hostname');
}

// MIUI/Doze (and a dead IPv6/AAAA route) can stall a brand-new outbound TCP+TLS
// handshake indefinitely even while an already-open socket (the relay WS, kept
// warm by its ping) keeps working — this is why text delivers but a fresh blob
// upload times out. Treat a connect timeout / unreachable host as eligible for
// the known-good IPv4 fallback, not just a DNS lookup failure.
bool _isConnectStallFailure(SocketException error) {
  final code = error.osError?.errorCode;
  // Linux/Android errno: ETIMEDOUT(110) ENETUNREACH(101) ECONNREFUSED(111)
  // EHOSTUNREACH(113); common Darwin: ETIMEDOUT(60) EHOSTUNREACH(65)
  // ECONNREFUSED(61) ENETUNREACH(64).
  if (code == 110 ||
      code == 101 ||
      code == 111 ||
      code == 113 ||
      code == 60 ||
      code == 65 ||
      code == 61 ||
      code == 64) {
    return true;
  }
  final message = error.message.toLowerCase();
  return message.contains('connection timed out') ||
      message.contains('establish timeout') ||
      message.contains('no route to host') ||
      message.contains('network is unreachable') ||
      message.contains('connection refused') ||
      message.contains('connection attempt failed');
}

bool _shouldTryIpFallback(SocketException error) =>
    _isDnsLookupFailure(error) || _isConnectStallFailure(error);

bool _isSecureScheme(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'https' || scheme == 'wss';
}

int _effectiveConnectionPort(Uri uri) {
  if (uri.hasPort && uri.port > 0) return uri.port;
  switch (uri.scheme.toLowerCase()) {
    case 'http':
    case 'ws':
      return 80;
    case 'https':
    case 'wss':
      return 443;
  }
  return uri.port;
}

int debugEffectiveConnectionPortForTest(Uri uri) =>
    _effectiveConnectionPort(uri);

bool debugHttpDnsFallbacksForWebSocketsEnabledForTest() =>
    _enableHttpDnsFallbacksForWebSockets;

bool debugShouldTryIpFallbackForTest(SocketException error) =>
    _shouldTryIpFallback(error);

void _drainSocketFutureAfterCancel(Future<Socket> socketFuture) {
  unawaited(
    socketFuture.then<void>(
      (socket) => socket.destroy(),
      onError: (Object _, StackTrace __) {},
    ),
  );
}

void _observeSocketFutureErrors(Future<Socket> socketFuture) {
  unawaited(
    socketFuture.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
  );
}

// Dart's HttpClient does NOT automatically wrap a Socket produced by
// `connectionFactory` with TLS when the request URL is https. If the factory
// returned a plain Socket for an https URL, HttpClient would send plaintext
// HTTP on an HTTPS port -> server responds with
// "400 Client sent an HTTP request to an HTTPS server". Hence the factory
// must establish the TLS handshake itself for secure schemes.
Future<ConnectionTask<Socket>> _startConnectCompatible({
  required Uri uri,
  required String connectHost,
  required String tlsHost,
  required int port,
}) async {
  if (_isSecureScheme(uri)) {
    final tcpTask = await Socket.startConnect(connectHost, port);
    final secureSocket = tcpTask.socket.then(
      (socket) => SecureSocket.secure(
        socket,
        host: tlsHost,
        context: SecurityContext.defaultContext,
      ),
    );
    _observeSocketFutureErrors(secureSocket);
    // `Future<SecureSocket>` is assignable to `Future<Socket>` (Future is
    // covariant), so fromSocket<Socket> accepts it. This preserves the
    // cancellation semantics of the original TCP task while keeping TLS
    // validation and SNI pinned to the original hostname, even when TCP falls
    // back to a literal IP address.
    return ConnectionTask.fromSocket<Socket>(secureSocket, tcpTask.cancel);
  }
  final task = await Socket.startConnect(connectHost, port);
  _observeSocketFutureErrors(task.socket);
  return task;
}

Future<ConnectionTask<Socket>> _startConnectWithDnsFallback({
  required Uri uri,
  required String originalHost,
  required String fallbackIp,
  required int port,
}) async {
  late final ConnectionTask<Socket> primaryTask;
  try {
    primaryTask = await _startConnectCompatible(
      uri: uri,
      connectHost: originalHost,
      tlsHost: originalHost,
      port: port,
    );
  } on SocketException catch (error) {
    if (!_shouldTryIpFallback(error)) {
      rethrow;
    }
    return _startConnectCompatible(
      uri: uri,
      connectHost: fallbackIp,
      tlsHost: originalHost,
      port: port,
    );
  }

  ConnectionTask<Socket>? fallbackTask;
  var canceled = false;

  // The primary socket future can still fail with a DNS lookup error: name
  // resolution completes while the ConnectionTask's socket resolves, not in
  // the synchronous startConnect above. Handle it with a typed async helper
  // and try/catch instead of Future.catchError + an async callback — the
  // latter's inferred return type tripped a runtime ArgumentError ("The error
  // handler of Future.catchError must return a value of the future's type")
  // the first time this fallback path was actually exercised in the field
  // (2026-06-19). try/catch keeps the return type unambiguously Future<Socket>.
  Future<Socket> useFallback() async {
    fallbackTask = await _startConnectCompatible(
      uri: uri,
      connectHost: fallbackIp,
      tlsHost: originalHost,
      port: port,
    );
    if (canceled) {
      fallbackTask!.cancel();
      _drainSocketFutureAfterCancel(fallbackTask!.socket);
      throw const SocketException('connection canceled during fallback');
    }
    return await fallbackTask!.socket;
  }

  Future<Socket> connectWithDnsFallback() async {
    try {
      // Bound the cold handshake: MIUI/Doze (a dead IPv6 route, or a hung
      // Private-DNS lookup) can hang a brand-new connect indefinitely while the
      // warm WS keeps working. A healthy handshake completes in well under a
      // second, so a short cap is safe; on timeout, abandon it and race the
      // known-good literal IPv4 (TLS/SNI still pinned to the hostname, so the
      // literal IP needs no DNS and bypasses the stalled IPv6 path).
      return await primaryTask.socket.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      if (canceled) rethrow;
      primaryTask.cancel();
      _drainSocketFutureAfterCancel(primaryTask.socket);
      // Cap the fallback too so a wedged network fails fast instead of hanging.
      return await useFallback().timeout(const Duration(seconds: 10));
    } on SocketException catch (error) {
      if (canceled || !_shouldTryIpFallback(error)) rethrow;
      return await useFallback().timeout(const Duration(seconds: 10));
    }
  }

  final socket = connectWithDnsFallback();
  _observeSocketFutureErrors(socket);

  return ConnectionTask.fromSocket<Socket>(socket, () async {
    canceled = true;
    primaryTask.cancel();
    fallbackTask?.cancel();
    _drainSocketFutureAfterCancel(socket);
    final fallbackSocket = fallbackTask?.socket;
    if (fallbackSocket != null) {
      _drainSocketFutureAfterCancel(fallbackSocket);
    }
  });
}

HttpClient _createResilientIoHttpClient(Map<String, String> fallbackByHost) {
  final client = HttpClient();
  client
      .connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
    // Proxied connections: deliver a raw TCP Socket; HttpClient will establish
    // the CONNECT tunnel and TLS handshake over the proxy itself.
    if (proxyHost != null && proxyHost.isNotEmpty && proxyPort != null) {
      return Socket.startConnect(proxyHost, proxyPort);
    }

    final originalHost = uri.host;
    final fallbackIp = fallbackByHost[originalHost.toLowerCase()] ?? '';
    final port = _effectiveConnectionPort(uri);
    if (fallbackIp.isEmpty) {
      return _startConnectCompatible(
        uri: uri,
        connectHost: originalHost,
        tlsHost: originalHost,
        port: port,
      );
    }
    return _startConnectWithDnsFallback(
      uri: uri,
      originalHost: originalHost,
      fallbackIp: fallbackIp,
      port: port,
    );
  };
  return client;
}

/// Добавляет `x-secretly-client-build` КАЖДОМУ исходящему запросу.
///
/// 🔴 ЗАЧЕМ ОБЁРТКА, А НЕ ЗАГОЛОВОК НА МЕСТАХ ВЫЗОВА (12.08.2026).
///
/// Замер раскатки показал 0 из 2001 устройства с известной сборкой — и это гейт
/// для ТЗ номера безопасности. Первая попытка починки провалилась: заголовок
/// добавляет общая функция подписи, но заголовки в relay_client собираются
/// ВРУЧНУЮ ещё в десяти местах, включая путь отправки. То есть на сервер он
/// почти никогда не приходил, хотя код «был».
///
/// Одно горло вместо одиннадцати. Заголовок НАМЕРЕННО вне подписи: подписать его
/// значило бы сломать совместимость со всеми существующими сборками ради
/// счётчика. Сервер по нему никаких решений не принимает — только считает доли.
class _HardenedClient extends http.BaseClient {
  _HardenedClient(this._inner, this._build);

  final http.Client _inner;

  /// Номер сборки для справочного заголовка. Пустая строка — не ставим.
  final String _build;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // 🔴 SEC-13: ЗА РЕДИРЕКТОМ НЕ ХОДИМ (26.08.2026).
    //
    // По умолчанию `package:http` идёт за редиректом молча. Наши эндпоинты их
    // не возвращают — проверено по коду обоих серверов, — поэтому редирект
    // здесь означает ровно одно: ответ пришёл не от нас.
    //
    // Перехвата так не устроить: TLS для нового адреса проверяется честно. Но
    // уводить запрос можно КУДА УГОДНО, где у уводящего есть валидный
    // сертификат, — то есть на любой его собственный домен. А запрос уносит с
    // собой подпись устройства и тело.
    //
    // Проверка `if` обязательна и не является украшением: у уже финализованного
    // запроса сеттер бросает StateError. Повторная отправка того же объекта в
    // этом коде реальна — ею занимается очередь повторов, — и на второй заход
    // значение уже `false`, так что до присваивания дело не доходит.
    if (request.followRedirects) {
      request.followRedirects = false;
    }

    // 🔴 СПРАВОЧНЫЙ ЗАГОЛОВОК НЕ ИМЕЕТ ПРАВА СТОИТЬ ЗАПРОСА.
    //
    // `putIfAbsent` на НЕИЗМЕНЯЕМОЙ карте бросает UnsupportedError — проверено
    // экспериментом — причём ДАЖЕ когда ключ уже на месте. А заголовки запроса
    // становятся неизменяемыми после finalize(), то есть при повторной отправке
    // того же объекта. Одна строка счётчика уронила бы подтверждение доставки.
    //
    // Отсюда: containsKey вместо putIfAbsent (не трогаем карту, если значение
    // уже есть) и глухая защита сверху. Направление отказа — «не поставить
    // заголовок», никогда «не отправить запрос».
    try {
      if (_build.isNotEmpty &&
          !request.headers.containsKey('x-secretly-client-build')) {
        request.headers['x-secretly-client-build'] = _build;
      }
    } catch (_) {
      // Запрос уходит без заголовка — это правильная сторона отказа.
    }
    // 🔴 ПОПРАВКУ К ЧАСАМ УЧИМ ЗДЕСЬ, А НЕ В КАЖДОМ ВЫЗОВЕ (12.09.2026).
    //
    // `ServerClock` существовал с 26.08, но подхватывал время только на пути
    // сервера ключей — и то не везде. Путь реле подписывал запросы СЫРЫМ
    // временем устройства, поэтому телефон с отставшими часами регистрировался
    // на ключах и не мог ничего на реле. Замер 12.09: 13 отказов подряд, все до
    // единого «отстаёт», спешащих ноль.
    //
    // Точек отправки больше двадцати; дописывать наблюдение в каждую — верный
    // способ что-то пропустить. Обёртка проходит ВСЕ запросы обоих серверов,
    // поэтому поправка учится одним местом и не может быть забыта.
    //
    // Учим по ЛЮБОМУ ответу, включая отказ: заголовок `Date` есть и в 401, а
    // именно 401 приходит устройству, чьи часы сбились. Иначе оно никогда бы не
    // узнало поправку — заколдованный круг.
    return _inner.send(request).then((resp) {
      try {
        final raw = resp.headers['date'];
        if (raw != null && raw.isNotEmpty) {
          ServerClock.instance.observeServerDate(HttpDate.parse(raw));
        }
      } catch (_) {
        // Неразобранная дата — поправка просто не изменится. Ответ при этом
        // обязан дойти до вызывающего нетронутым.
      }
      return resp;
    });
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

http.Client createResilientHttpClient() {
  final fallbackByHost = _parseHttpDnsFallbacks(_httpDnsFallbacksEnv);
  // Fast path: no DNS fallbacks, use the stock http.Client whose TLS handling
  // is fully managed by Dart without any connectionFactory override. This
  // avoids any risk of regressing TLS on the default code path.
  final http.Client base = fallbackByHost.isEmpty
      ? http.Client()
      : IOClient(_createResilientIoHttpClient(fallbackByHost));

  // 🔴 ОБЁРТКА БЕЗУСЛОВНА (26.08.2026, при разборе SEC-13).
  //
  // Раньше при пустом номере сборки возвращался голый клиент — обёртка нужна
  // была только ради справочного заголовка, и без него смысла не имела. Теперь
  // она несёт защиту, а защита, включающаяся по наличию номера версии, — это
  // не защита. Отладочные сборки (номер пуст) ходили бы за редиректом.
  return _HardenedClient(base, AppPackageInfo.buildNumberFromEnv);
}

WebSocketChannel connectResilientWebSocket(
  Uri uri, {
  Duration? pingInterval,
  Duration? connectTimeout,
}) {
  final fallbackByHost = _parseHttpDnsFallbacks(_httpDnsFallbacksEnv);
  if (fallbackByHost.isEmpty || !_enableHttpDnsFallbacksForWebSockets) {
    return WebSocketChannel.connect(uri);
  }

  final client = _createResilientIoHttpClient(fallbackByHost);
  final channel = IOWebSocketChannel.connect(
    uri,
    pingInterval: pingInterval,
    connectTimeout: connectTimeout,
    customClient: client,
  );
  return _ManagedWebSocketChannel(delegate: channel, client: client);
}
