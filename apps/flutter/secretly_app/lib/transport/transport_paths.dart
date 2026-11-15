// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'transport_core.dart';

/// Пути к серверам под блокировками (Э1, 10.10.2026).
///
/// Держит работающий локальный прокси из библиотеки транспорта и отвечает на
/// один вопрос HTTP-клиента: «этот запрос к нашим серверам? — тогда вот
/// адрес на loopback и два заголовка». Всё остальное (какой путь, какой
/// SNI, Tor или нет) решает библиотека.
///
/// Если библиотека не загрузилась или прокси не поднялся, [active] ложно, и
/// клиент ходит напрямую, как раньше. Любой сбой здесь — не ошибка
/// доставки, а возврат к прежнему поведению.
class TransportPaths {
  TransportPaths({
    required TransportCoreApi core,
    required Uri keysBase,
    required Uri relayBase,
    required String bootstrapListJson,
    String memoryJson = '',
    String networkId = '',
    bool allowTor = false,
    String proxyHost = '',
    int proxyPort = 443,
    String socksAddr = '',
    bool healDeadListener = false,
    Future<bool> Function(int port)? probe,
  }) : _core = core,
       _healDeadListener = healDeadListener,
       _probe = probe ?? _probeLoopback,
       _keysOrigin = _origin(keysBase),
       _relayOrigin = _origin(relayBase),
       _listJson = bootstrapListJson,
       _memoryJson = memoryJson,
       _networkId = networkId,
       _allowTor = allowTor,
       _proxyHost = proxyHost.trim(),
       _proxyPort = proxyPort,
       _socksAddr = socksAddr.trim();

  /// Единственный экземпляр на изолят; `null` — транспорт не используется.
  static TransportPaths? instance;

  static const String headerUpstream = 'x-secretly-upstream';
  static const String headerToken = 'x-secretly-proxy-token';
  static const String headerPath = 'x-secretly-path';

  final TransportCoreApi _core;
  // Сервер узнаётся по хосту И порту: при разработке и в демо ключи и реле
  // живут на одном 127.0.0.1 на разных портах, и сравнение по одному хосту
  // отправляло все запросы реле на ключи (10.10.2026).
  final String _keysOrigin;
  final String _relayOrigin;

  static String _origin(Uri uri) {
    final secure = uri.scheme == 'https' || uri.scheme == 'wss';
    final port = uri.hasPort ? uri.port : (secure ? 443 : 80);
    return '${uri.host.toLowerCase()}:$port';
  }
  String _listJson;
  String _memoryJson;
  String _networkId;
  bool _allowTor;

  /// Пути, которые задал сам человек (ссылка `secretly://proxy#…`, экран
  /// «Сеть»). Добавляются к любому списку — встроенному или с сервера.
  String _proxyHost;
  int _proxyPort;
  String _socksAddr;

  String get proxyHost => _proxyHost;
  String get socksAddr => _socksAddr;

  int _port = 0;
  String _token = '';
  int _issuedAtMs = 0;

  bool get active => _port > 0 && _token.isNotEmpty;
  int get port => _port;
  int get issuedAtMs => _issuedAtMs;
  String get networkId => _networkId;

  String _policyJson() => jsonEncode(<String, Object?>{
    'list': effectiveList(),
    'memory': _memoryJson.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(_memoryJson),
    'network_id': _networkId,
    'allow_tor': _allowTor,
    'allow_socks': _socksAddr.isNotEmpty,
  });

  /// Список путей с добавленными пользовательскими прокси и SOCKS.
  Map<String, Object?> effectiveList() {
    final list = Map<String, Object?>.from(
      jsonDecode(_listJson) as Map<String, dynamic>,
    );
    final paths = List<Object?>.from(list['paths'] as List? ?? const []);
    bool has(bool Function(Map<String, dynamic>) test) => paths.any(
      (p) => p is Map<String, dynamic> && test(p),
    );
    if (_proxyHost.isNotEmpty &&
        !has((p) => p['kind'] == 'proxy' && p['host'] == _proxyHost)) {
      paths.add(<String, Object?>{
        'kind': 'proxy',
        'host': _proxyHost,
        'port': _proxyPort,
      });
    }
    if (_socksAddr.isNotEmpty &&
        !has((p) => p['kind'] == 'socks' && p['addr'] == _socksAddr)) {
      paths.add(<String, Object?>{'kind': 'socks', 'addr': _socksAddr});
    }
    list['paths'] = paths;
    return list;
  }

  /// Меняет пользовательские пути и передаёт библиотеке.
  void setUserPaths({String? proxyHost, int? proxyPort, String? socksAddr}) {
    _proxyHost = (proxyHost ?? _proxyHost).trim();
    _proxyPort = proxyPort ?? _proxyPort;
    _socksAddr = (socksAddr ?? _socksAddr).trim();
    _push();
  }

  /// Поднимает прокси. Ложь — работаем напрямую.
  bool start() {
    if (active) return true;
    try {
      final started = _core.start(_policyJson());
      _port = started.port;
      _token = started.token;
      _issuedAtMs = _issuedAtOf(_listJson);
      return active;
    } catch (_) {
      _port = 0;
      _token = '';
      return false;
    }
  }

  void stop() {
    if (!active) return;
    try {
      _core.stop();
    } catch (_) {}
    _port = 0;
    _token = '';
  }

  // 🔴 МЁРТВЫЙ СОКЕТ НА iOS (29.10.2026). iOS закрывает слушающие сокеты
  // приостановленного приложения (TN2277): после блокировки телефона прокси
  // числится запущенным, а каждый запрос на loopback получает «Connection
  // refused» — iPhone не отправлял и не забирал сообщения до перезапуска.
  // Библиотека этого не видит (accept просто ошибается с паузой), поэтому
  // проверяет приложение: при возврате и при первом отказе на loopback.
  final bool _healDeadListener;
  final Future<bool> Function(int port) _probe;
  Future<bool>? _healing;

  static Future<bool> _probeLoopback(int port) async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Проверяет, что прокси ещё слушает, и перезапускает его, если нет.
  /// Истина — перезапустили (порт и токен новые). Повторные вызовы во время
  /// проверки ждут ту же проверку.
  Future<bool> healIfDead() {
    if (!_healDeadListener || !active) return Future<bool>.value(false);
    return _healing ??= _heal().whenComplete(() => _healing = null);
  }

  Future<bool> _heal() async {
    if (await _probe(_port)) return false;
    // Память путей переносим в новый запуск: не перебирать пути заново.
    final memory = snapshotMemoryJson();
    if (memory != null && memory.isNotEmpty) _memoryJson = memory;
    stop();
    return start();
  }

  /// Запрос на loopback не дошёл до прокси — проверить его в фоне.
  void noteLoopbackFailure() {
    if (!_healDeadListener) return;
    healIfDead().ignore();
  }

  /// Наш ли это сервер.
  bool handles(Uri uri) {
    if (!active) return false;
    final origin = _origin(uri);
    return origin == _keysOrigin || origin == _relayOrigin;
  }

  String upstreamFor(Uri uri) => _origin(uri) == _keysOrigin ? 'keys' : 'relay';

  /// Адрес на loopback с тем же путём и строкой запроса.
  Uri rewrite(Uri uri) {
    final scheme = switch (uri.scheme.toLowerCase()) {
      'wss' || 'ws' => 'ws',
      _ => 'http',
    };
    return uri.replace(scheme: scheme, host: '127.0.0.1', port: _port);
  }

  Map<String, String> headersFor(Uri uri) => <String, String>{
    headerUpstream: upstreamFor(uri),
    headerToken: _token,
  };

  /// Можно ли учить поправку часов по `Date` из этого ответа: только с
  /// путей, где ответ пришёл от нашего сервера без чужих узлов посередине.
  static bool trustsDateFrom(String? pathHeader) {
    final p = (pathHeader ?? '').trim().toLowerCase();
    return p.isEmpty || p == 'direct' || p == 'ip';
  }

  /// Смена сети: библиотека забывает текущий путь и переберёт заново.
  void onNetworkChanged(String networkId) {
    _networkId = networkId;
    if (!active) return;
    try {
      _core.setNetwork(networkId);
    } catch (_) {}
  }

  void setAllowances({bool? tor}) {
    _allowTor = tor ?? _allowTor;
    _push();
  }

  /// Принимает подписанный список входов. Ложь — отвергнут (подпись, срок,
  /// не новее); текущий список остаётся.
  bool applySignedList({
    required String signedJson,
    required String verifyingKeyB64,
    required int nowMs,
  }) {
    final (code, doc) = _core.verifyEndpoints(
      signedJson: signedJson,
      verifyingKeyB64: verifyingKeyB64,
      nowMs: nowMs,
      currentIssuedAtMs: _issuedAtMs,
    );
    if (code != 0 || doc == null || doc.isEmpty) return false;
    _listJson = doc;
    _issuedAtMs = _issuedAtOf(doc);
    _memoryJson = '';
    _push();
    return true;
  }

  /// Текущий список (для кэша между запусками).
  String get listJson => _listJson;

  /// Память путей для кэша между запусками (из состояния библиотеки).
  String? snapshotMemoryJson() {
    final status = this.status();
    return status?.memoryJson;
  }

  TransportStatus? status() {
    if (!active) return null;
    try {
      return TransportStatus.parse(_core.statusJson());
    } catch (_) {
      return null;
    }
  }

  void _push() {
    if (!active) return;
    try {
      _core.update(_policyJson());
    } catch (_) {}
  }

  static int _issuedAtOf(String listJson) {
    try {
      final m = jsonDecode(listJson) as Map<String, dynamic>;
      return (m['issued_at_ms'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Встроенный список на первый запуск: прямой путь и запасные адреса, те
  /// же, что раньше были зашиты в HTTP-клиент. Пользовательские прокси и
  /// SOCKS добавляются поверх.
  static String bootstrapListJson({
    required Uri keysBase,
    required Uri relayBase,
    required Map<String, String> ipByHost,
    String proxyHost = '',
    int proxyPort = 443,
    String socksAddr = '',
  }) {
    final paths = <Map<String, Object?>>[
      <String, Object?>{'kind': 'direct'},
    ];
    final ip =
        ipByHost[relayBase.host.toLowerCase()] ??
        ipByHost[keysBase.host.toLowerCase()] ??
        '';
    if (ip.isNotEmpty) {
      paths.add(<String, Object?>{'kind': 'ip', 'ip': ip});
    }
    if (proxyHost.trim().isNotEmpty) {
      paths.add(<String, Object?>{
        'kind': 'proxy',
        'host': proxyHost.trim(),
        'port': proxyPort,
      });
    }
    if (socksAddr.trim().isNotEmpty) {
      paths.add(<String, Object?>{'kind': 'socks', 'addr': socksAddr.trim()});
    }
    return jsonEncode(<String, Object?>{
      'v': 1,
      'issued_at_ms': 0,
      'expires_at_ms': 4102444800000, // 2100-01-01: встроенный список не устаревает
      'logical': <String, String>{
        'keys': _base(keysBase),
        'relay': _base(relayBase),
      },
      'paths': paths,
    });
  }

  static String _base(Uri u) =>
      u.replace(path: '', query: null, fragment: null).toString().replaceAll(
        RegExp(r'/+$'),
        '',
      );
}

/// Имя хоста прокси волонтёра (буквы, цифры, точки, дефисы), необязательно с
/// портом. Ничего другого ссылка нести не может.
final RegExp _proxyHostPattern = RegExp(
  r'^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?)+(:[0-9]{2,5})?$',
);

/// `secretly://proxy#host[:port]` или `https://links.secretlyapp.com/proxy#host`
/// → `(host, port)`; `null` — не та ссылка или мусор.
(String, int)? tryParseTransportProxyUri(Uri uri) {
  final isScheme = uri.scheme == 'secretly' && uri.host == 'proxy';
  final isLink =
      uri.scheme == 'https' &&
      uri.host == 'links.secretlyapp.com' &&
      uri.path.replaceAll(RegExp(r'/+$'), '') == '/proxy';
  if (!isScheme && !isLink) return null;
  final raw = uri.fragment.trim().toLowerCase();
  if (raw.isEmpty || !_proxyHostPattern.hasMatch(raw)) return null;
  final colon = raw.lastIndexOf(':');
  if (colon > 0) {
    final port = int.tryParse(raw.substring(colon + 1));
    if (port == null || port < 1 || port > 65535) return null;
    return (raw.substring(0, colon), port);
  }
  return (raw, 443);
}

/// `secretly://endpoints#<base64url(подписанный JSON списка)>` → сам JSON;
/// подпись проверяет библиотека, здесь только распаковка.
String? tryParseTransportEndpointsUri(Uri uri) {
  if (uri.scheme != 'secretly' || uri.host != 'endpoints') return null;
  final raw = uri.fragment.trim();
  if (raw.isEmpty || raw.length > 16384) return null;
  try {
    final normalized = base64Url.normalize(raw);
    final json = utf8.decode(base64Url.decode(normalized));
    final decoded = jsonDecode(json);
    if (decoded is! Map || decoded['doc'] is! String || decoded['sig_b64'] is! String) {
      return null;
    }
    return json;
  } catch (_) {
    return null;
  }
}
