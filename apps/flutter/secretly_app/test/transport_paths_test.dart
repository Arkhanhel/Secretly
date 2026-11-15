// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:secretly_app/transport/resilient_http_client_io.dart';
import 'package:secretly_app/transport/transport_core.dart';
import 'package:secretly_app/transport/transport_paths.dart';

// Э1 (10.10.2026): оркестратор путей на Dart и перехват запросов. Сама
// библиотека проверяется в Rust; здесь — что клиент правильно говорит с ней
// и правильно переписывает запросы на loopback.

class _FakeCore implements TransportCoreApi {
  bool started = false;
  bool failStart = false;
  int starts = 0;
  String? lastPolicy;
  String? lastNetwork;
  int verifyCode = 0;
  String verifyDoc = '';

  @override
  String get version => 'fake';

  @override
  TransportStarted start(String policyJson) {
    if (failStart) throw const TransportCoreException(103, 'start');
    started = true;
    starts++;
    lastPolicy = policyJson;
    return const TransportStarted(port: 43211, token: 'tok-1');
  }

  @override
  void update(String policyJson) => lastPolicy = policyJson;

  @override
  void setNetwork(String networkId) => lastNetwork = networkId;

  @override
  String? statusJson() => started
      ? jsonEncode(<String, Object?>{
          'port': 43211,
          'current': 1,
          'current_kind': 'ip',
          'network_id': lastNetwork ?? '',
          'memory': <String, Object?>{
            'networks': <String, Object?>{
              'wifi:a': <String, Object?>{'last_ok': 1, 'last_ok_at_ms': 5},
            },
          },
          'issued_at_ms': 0,
        })
      : null;

  @override
  bool stop() {
    started = false;
    return true;
  }

  @override
  (int, String?) verifyEndpoints({
    required String signedJson,
    required String verifyingKeyB64,
    required int nowMs,
    required int currentIssuedAtMs,
  }) => (verifyCode, verifyCode == 0 ? verifyDoc : null);
}

final _keys = Uri.parse('https://keys.example.com');
final _relay = Uri.parse('https://relay.example.com');

TransportPaths _paths(_FakeCore core) => TransportPaths(
  core: core,
  keysBase: _keys,
  relayBase: _relay,
  bootstrapListJson: TransportPaths.bootstrapListJson(
    keysBase: _keys,
    relayBase: _relay,
    ipByHost: const <String, String>{'relay.example.com': '203.0.113.5'},
  ),
);

void main() {
  tearDown(() => TransportPaths.instance = null);
  _userPathsAndLinks();
  _healDeadListener();

  test('встроенный список: прямой путь и запасной адрес', () {
    final json = jsonDecode(
      TransportPaths.bootstrapListJson(
        keysBase: Uri.parse('https://keys.example.com/'),
        relayBase: _relay,
        ipByHost: const <String, String>{'relay.example.com': '203.0.113.5'},
        proxyHost: 'vol.example.org',
        socksAddr: '127.0.0.1:9050',
      ),
    ) as Map<String, dynamic>;
    expect(json['v'], 1);
    expect(json['logical'], <String, String>{
      'keys': 'https://keys.example.com',
      'relay': 'https://relay.example.com',
    });
    final kinds = (json['paths'] as List).map((p) => p['kind']).toList();
    expect(kinds, <String>['direct', 'ip', 'proxy', 'socks']);
  });

  test('🔴 без библиотеки или при сбое старта — работаем напрямую', () {
    final core = _FakeCore()..failStart = true;
    final paths = _paths(core);
    expect(paths.start(), isFalse);
    expect(paths.active, isFalse);
    expect(paths.handles(Uri.parse('https://keys.example.com/v1/config')), isFalse);
  });

  test('перехватываются только наши серверы; адрес и заголовки', () {
    final core = _FakeCore();
    final paths = _paths(core)..start();
    expect(paths.active, isTrue);
    expect(paths.handles(Uri.parse('https://api.giphy.com/x')), isFalse);
    final keysUri = Uri.parse('https://keys.example.com/v1/config?x=1');
    expect(paths.handles(keysUri), isTrue);
    expect(
      paths.rewrite(keysUri).toString(),
      'http://127.0.0.1:43211/v1/config?x=1',
    );
    expect(
      paths.rewrite(Uri.parse('wss://relay.example.com/ws')).toString(),
      'ws://127.0.0.1:43211/ws',
    );
    expect(paths.headersFor(keysUri), <String, String>{
      TransportPaths.headerUpstream: 'keys',
      TransportPaths.headerToken: 'tok-1',
    });
    expect(
      paths.headersFor(Uri.parse('https://relay.example.com/ws'))[
          TransportPaths.headerUpstream],
      'relay',
    );
  });

  test('🔴 ключи и реле на одном хосте с разными портами не путаются', () {
    final keys = Uri.parse('http://127.0.0.1:8081');
    final relay = Uri.parse('http://127.0.0.1:8082');
    final paths = TransportPaths(
      core: _FakeCore(),
      keysBase: keys,
      relayBase: relay,
      bootstrapListJson: TransportPaths.bootstrapListJson(
        keysBase: keys,
        relayBase: relay,
        ipByHost: const <String, String>{},
      ),
    )..start();
    String? upstream(String url) =>
        paths.headersFor(Uri.parse(url))[TransportPaths.headerUpstream];
    expect(upstream('http://127.0.0.1:8081/v1/config'), 'keys');
    expect(upstream('http://127.0.0.1:8082/v1/pending/d1'), 'relay');
    expect(upstream('ws://127.0.0.1:8082/ws'), 'relay');
    expect(paths.handles(Uri.parse('http://127.0.0.1:9999/x')), isFalse);
    expect(paths.handles(Uri.parse('https://keys.example.com:443/x')), isFalse);
  });

  test('порт по умолчанию равен явному', () {
    final paths = _paths(_FakeCore())..start();
    expect(paths.handles(Uri.parse('https://keys.example.com:443/v1/config')), isTrue);
    expect(paths.handles(Uri.parse('wss://relay.example.com:443/ws')), isTrue);
    expect(paths.handles(Uri.parse('http://relay.example.com/ws')), isFalse);
  });

  test('поправка часов — только с прямых путей', () {
    expect(TransportPaths.trustsDateFrom(null), isTrue);
    expect(TransportPaths.trustsDateFrom('direct'), isTrue);
    expect(TransportPaths.trustsDateFrom('ip'), isTrue);
    for (final foreign in <String>['mirror', 'cdn', 'proxy', 'socks', 'tor']) {
      expect(TransportPaths.trustsDateFrom(foreign), isFalse, reason: foreign);
    }
  });

  test('смена сети и разрешения доходят до библиотеки', () {
    final core = _FakeCore();
    final paths = _paths(core)..start();
    paths.onNetworkChanged('cell:op1');
    expect(core.lastNetwork, 'cell:op1');
    paths.setAllowances(tor: true);
    expect(jsonDecode(core.lastPolicy!)['allow_tor'], isTrue);
  });

  test('🔴 подписанный список: принят — заменяет, отвергнут — не трогает', () {
    final core = _FakeCore();
    final paths = _paths(core)..start();
    core.verifyCode = 3; // подпись
    expect(
      paths.applySignedList(signedJson: '{}', verifyingKeyB64: 'k', nowMs: 1),
      isFalse,
    );
    expect(paths.issuedAtMs, 0);
    core.verifyCode = 0;
    core.verifyDoc = jsonEncode(<String, Object?>{
      'v': 1,
      'issued_at_ms': 777,
      'expires_at_ms': 999999,
      'logical': <String, String>{'keys': 'https://k', 'relay': 'https://r'},
      'paths': <Object?>[
        <String, Object?>{'kind': 'direct'},
      ],
    });
    expect(
      paths.applySignedList(signedJson: '{}', verifyingKeyB64: 'k', nowMs: 1),
      isTrue,
    );
    expect(paths.issuedAtMs, 777);
    expect(jsonDecode(core.lastPolicy!)['list']['issued_at_ms'], 777);
    expect(jsonDecode(core.lastPolicy!)['memory'], isEmpty,
        reason: 'индексы путей относятся к старому списку');
  });

  test('память путей читается из состояния библиотеки', () {
    final core = _FakeCore();
    final paths = _paths(core)..start();
    final status = paths.status();
    expect(status?.currentKind, 'ip');
    expect(jsonDecode(paths.snapshotMemoryJson()!)['networks'], contains('wifi:a'));
    paths.stop();
    expect(paths.active, isFalse);
    expect(core.started, isFalse);
  });

  group('переписывание запросов на loopback', () {
    late TransportPaths paths;
    setUp(() {
      paths = _paths(_FakeCore())..start();
    });

    test('Request: адрес, метод, тело, заголовки, без редиректов', () {
      final original = http.Request(
        'POST',
        Uri.parse('https://relay.example.com/v1/send'),
      )
        ..headers['x-secretly-client-build'] = '655'
        ..bodyBytes = utf8.encode('{"a":1}');
      final out = rewriteRequestToLoopback(original, paths) as http.Request;
      expect(out.url.toString(), 'http://127.0.0.1:43211/v1/send');
      expect(out.method, 'POST');
      expect(out.bodyBytes, utf8.encode('{"a":1}'));
      expect(out.headers['x-secretly-client-build'], '655');
      expect(out.headers[TransportPaths.headerUpstream], 'relay');
      expect(out.headers[TransportPaths.headerToken], 'tok-1');
      expect(out.followRedirects, isFalse);
    });

    test('StreamedRequest: тело доезжает потоком', () async {
      final original = http.StreamedRequest(
        'PUT',
        Uri.parse('https://relay.example.com/v1/blob/upload'),
      )..contentLength = 5;
      original.sink.add(<int>[1, 2, 3, 4, 5]);
      original.sink.close();
      final out = rewriteRequestToLoopback(original, paths) as http.StreamedRequest;
      expect(out.contentLength, 5);
      final bytes = await out.finalize().toBytes();
      expect(bytes, <int>[1, 2, 3, 4, 5]);
    });
  });
}

void _userPathsAndLinks() {
  test('пользовательские прокси и SOCKS добавляются к любому списку', () {
    final core = _FakeCore();
    final paths = TransportPaths(
      core: core,
      keysBase: _keys,
      relayBase: _relay,
      bootstrapListJson: TransportPaths.bootstrapListJson(
        keysBase: _keys,
        relayBase: _relay,
        ipByHost: const <String, String>{},
      ),
      proxyHost: 'vol.example.org',
      proxyPort: 8443,
    )..start();
    var kinds = (jsonDecode(core.lastPolicy!)['list']['paths'] as List)
        .map((p) => p['kind'])
        .toList();
    expect(kinds, <String>['direct', 'proxy']);
    expect(jsonDecode(core.lastPolicy!)['allow_socks'], isFalse);
    paths.setUserPaths(socksAddr: '127.0.0.1:9050');
    final policy = jsonDecode(core.lastPolicy!);
    kinds = (policy['list']['paths'] as List).map((p) => p['kind']).toList();
    expect(kinds, <String>['direct', 'proxy', 'socks']);
    expect(policy['allow_socks'], isTrue);
    expect((policy['list']['paths'] as List)[1]['port'], 8443);
    paths.setUserPaths(proxyHost: '');
    kinds = (jsonDecode(core.lastPolicy!)['list']['paths'] as List)
        .map((p) => p['kind'])
        .toList();
    expect(kinds, <String>['direct', 'socks']);
  });

  test('🔴 ссылка прокси: только имя хоста, порт по желанию', () {
    expect(
      tryParseTransportProxyUri(Uri.parse('secretly://proxy#Vol.Example.org')),
      ('vol.example.org', 443),
    );
    expect(
      tryParseTransportProxyUri(Uri.parse('secretly://proxy#vol.example.org:8443')),
      ('vol.example.org', 8443),
    );
    expect(
      tryParseTransportProxyUri(
        Uri.parse('https://links.secretlyapp.com/proxy#vol.example.org'),
      ),
      ('vol.example.org', 443),
    );
    for (final bad in <String>[
      'secretly://proxy#',
      'secretly://proxy#not a host',
      'secretly://proxy#localhost',
      'secretly://proxy#vol.example.org:99999',
      'secretly://proxy#evil.example.org/path',
      'secretly://profile#vol.example.org',
      'https://evil.example/proxy#vol.example.org',
    ]) {
      expect(tryParseTransportProxyUri(Uri.parse(bad)), isNull, reason: bad);
    }
  });

  test('ссылка списка входов распаковывается, мусор — нет', () {
    final signed = jsonEncode(<String, String>{'doc': '{"v":1}', 'sig_b64': 'AA=='});
    final link = 'secretly://endpoints#${base64Url.encode(utf8.encode(signed))}';
    expect(tryParseTransportEndpointsUri(Uri.parse(link)), signed);
    expect(tryParseTransportEndpointsUri(Uri.parse('secretly://endpoints#%%%')), isNull);
    expect(
      tryParseTransportEndpointsUri(
        Uri.parse('secretly://endpoints#${base64Url.encode(utf8.encode('{"x":1}'))}'),
      ),
      isNull,
    );
  });
}

// 29.10.2026: iOS закрывает слушающий сокет приостановленного приложения —
// прокси надо проверить и поднять заново, иначе iPhone молчит до перезапуска.
void _healDeadListener() {
  TransportPaths healing(_FakeCore core, {
    required bool heal,
    required Future<bool> Function(int port) probe,
  }) => TransportPaths(
    core: core,
    keysBase: _keys,
    relayBase: _relay,
    bootstrapListJson: TransportPaths.bootstrapListJson(
      keysBase: _keys,
      relayBase: _relay,
      ipByHost: const <String, String>{},
    ),
    healDeadListener: heal,
    probe: probe,
  );

  test('без лечения (Android, ПК) порт даже не проверяется', () async {
    final core = _FakeCore();
    var probes = 0;
    final paths = healing(core, heal: false, probe: (_) async {
      probes++;
      return false;
    });
    expect(paths.start(), isTrue);
    expect(await paths.healIfDead(), isFalse);
    paths.noteLoopbackFailure();
    await Future<void>.delayed(Duration.zero);
    expect(probes, 0);
    expect(core.starts, 1);
  });

  test('живой порт не трогаем', () async {
    final core = _FakeCore();
    final paths = healing(core, heal: true, probe: (_) async => true);
    expect(paths.start(), isTrue);
    expect(await paths.healIfDead(), isFalse);
    expect(core.starts, 1);
    expect(paths.active, isTrue);
  });

  test('мёртвый порт: перезапуск с памятью путей', () async {
    final core = _FakeCore();
    final ports = <int>[];
    final paths = healing(core, heal: true, probe: (port) async {
      ports.add(port);
      return false;
    });
    expect(paths.start(), isTrue);
    expect(await paths.healIfDead(), isTrue);
    expect(ports, <int>[43211]);
    expect(core.starts, 2);
    expect(paths.active, isTrue);
    final policy = jsonDecode(core.lastPolicy!) as Map<String, dynamic>;
    expect(
      (policy['memory'] as Map<String, dynamic>)['networks'],
      contains('wifi:a'),
      reason: 'память путей переносится в новый запуск',
    );
  });

  test('отказы подряд — одна проверка и один перезапуск', () async {
    final core = _FakeCore();
    var probes = 0;
    final paths = healing(core, heal: true, probe: (_) async {
      probes++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return false;
    });
    expect(paths.start(), isTrue);
    paths.noteLoopbackFailure();
    paths.noteLoopbackFailure();
    expect(await paths.healIfDead(), isTrue);
    expect(probes, 1);
    expect(core.starts, 2);
  });

  test('не поднялся — работаем напрямую, как раньше', () async {
    final core = _FakeCore();
    final paths = healing(core, heal: true, probe: (_) async => false);
    expect(paths.start(), isTrue);
    core.failStart = true;
    expect(await paths.healIfDead(), isFalse);
    expect(paths.active, isFalse);
    expect(paths.handles(Uri.parse('https://relay.example.com/v1/inbox')), isFalse);
  });
}
