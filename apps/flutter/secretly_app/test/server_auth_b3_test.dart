// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secretly_app/app/contact_action_failure.dart';
import 'package:secretly_app/entitlements/entitlement_models.dart';
import 'package:secretly_app/entitlements/entitlement_repository.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/server_auth_flags.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:secretly_app/transport/response_signature.dart';

// Б3 Э1 (25.10.2026): подпись ответов keys — проверка и счёт, без отказа.

// Вектор закреплён и в Rust (`resp_signature_cross_language_vector`): ключ из
// 32 байт 13, ответ `{"ok":true}`.
const _pub = 'kaKKC3Q4FZOk2UaVeSCJJq/IrYLIg5t2RDWbnrqaSzo=';
const _sig =
    '1a4S5zmdkXoR720SaCm0ibXR4cVe6TfpFHGEcgOW1fC1OuFN6q2UB0cOzs9fMAFpGjwcOcWZtSjwD99BnRYRAg==';
const _nonce = 'AAAAAAAAAAAAAAAAAAAAAA==';
const _target = '/v1/profile/search?query=al+ice&limit=5';
const _ts = 1760000000123;
final _body = Uint8List.fromList(utf8.encode('{"ok":true}'));
const _keys = <String, String>{'cfg1': _pub};

Future<ResponseAuthOutcome> _verify({
  String target = _target,
  String nonce = _nonce,
  int status = 200,
  Uint8List? body,
  String? header = 'v1;kid=cfg1;ts=$_ts;sig=$_sig',
  Map<String, String> keys = _keys,
}) =>
    verifyResponseSignature(
      method: 'GET',
      target: target,
      nonce: nonce,
      status: status,
      body: body ?? _body,
      header: header,
      trustedKeys: keys,
    );

Future<String> _signHeader({
  required String target,
  required String nonce,
  required int status,
  required List<int> body,
}) async {
  final kp = await Ed25519().newKeyPairFromSeed(List<int>.filled(32, 13));
  final msg = responseSigningMessage(
    kid: 'cfg1',
    method: 'GET',
    path: target,
    nonce: nonce,
    tsMs: 7,
    status: status,
    bodySha256B64: base64Encode(sha256.convert(body).bytes),
  );
  final sig = await Ed25519().sign(utf8.encode(msg), keyPair: kp);
  return 'v1;kid=cfg1;ts=7;sig=${base64Encode(sig.bytes)}';
}

void main() {
  setUp(() {
    ResponseAuthStats.resetForTesting();
    ServerAuthEnforcement.resetForTesting();
  });
  tearDown(() {
    debugTrustedResponseKeys = null;
    ServerAuthEnforcement.resetForTesting();
  });

  test('сообщение подписи побайтово как у сервера', () {
    expect(
      responseSigningMessage(
        kid: 'cfg1',
        method: 'GET',
        path: '/v1/keys/bundle/p?x=1',
        nonce: 'bm9uY2U=',
        tsMs: 42,
        status: 200,
        bodySha256B64: 'aGFzaA==',
      ),
      'SECRETLY-RESP-V1\nkid=cfg1\nmethod=GET\npath=/v1/keys/bundle/p?x=1\n'
      'nonce=bm9uY2U=\nts_ms=42\nstatus=200\nbody_sha256_b64=aGFzaA==\n',
    );
  });

  test('вектор Rust сходится; любая подмена — bad, нет заголовка — missing',
      () async {
    expect(await _verify(), ResponseAuthOutcome.ok);
    expect(
        await _verify(body: Uint8List.fromList(utf8.encode('{"ok":false}'))),
        ResponseAuthOutcome.bad);
    expect(await _verify(target: '/v1/profile/search?query=bob&limit=5'),
        ResponseAuthOutcome.bad,
        reason: 'ответ на другой запрос');
    expect(await _verify(nonce: 'BBBBBBBBBBBBBBBBBBBBBB=='),
        ResponseAuthOutcome.bad,
        reason: 'повтор старого ответа');
    expect(await _verify(status: 404), ResponseAuthOutcome.bad);
    expect(await _verify(header: null), ResponseAuthOutcome.missing);
    expect(await _verify(header: ''), ResponseAuthOutcome.missing);
    expect(await _verify(header: 'garbage'), ResponseAuthOutcome.bad);
    expect(await _verify(header: 'v1;kid=other;ts=$_ts;sig=$_sig'),
        ResponseAuthOutcome.bad);
    expect(await _verify(header: 'v1;kid=cfg1;ts=$_ts;sig=%%%'),
        ResponseAuthOutcome.bad);
    expect(await _verify(keys: const {}), ResponseAuthOutcome.noKey);
  });

  test('путь с запросом — как его видит сервер', () {
    final uri = Uri.parse('https://keys.test/v1/profile/search')
        .replace(queryParameters: {'query': 'al ice', 'limit': '5'});
    expect(responseSignedTarget(uri), _target);
    expect(responseSignedTarget(Uri.parse('https://k/v1/keys/bundle/P')),
        '/v1/keys/bundle/P');
  });

  test('подписываемые маршруты — те же, что у сервера', () {
    for (final p in [
      '/v1/keys/bundle/p1',
      '/v1/device/d1/bundle',
      '/v1/device/d1/identity',
      '/v1/device/d1',
      '/v1/profile/p1/devices',
      '/v1/profile/p1/own_devices',
      '/v1/profile/search',
    ]) {
      expect(responseSignedPath('GET', p), isTrue, reason: p);
    }
    for (final p in [
      '/v1/config',
      '/v1/device/challenge',
      '/v1/device/self_status',
      '/v1/profile/p1',
      '/v1/profile/p1/meta',
      '/v1/keys/bundle/',
      '/health',
    ]) {
      expect(responseSignedPath('GET', p), isFalse, reason: p);
    }
    expect(responseSignedPath('POST', '/v1/keys/bundle/p1'), isFalse);
  });

  test('keys_client шлёт nonce только на подписываемые и считает исходы',
      () async {
    debugTrustedResponseKeys = _keys;
    final nonces = <String, String?>{};
    var tamper = false;
    final mock = MockClient((req) async {
      nonces[req.url.path] = req.headers[kResponseNonceHeader];
      final body = utf8.encode(jsonEncode({'devices': <Object>[]}));
      final nonce = req.headers[kResponseNonceHeader];
      final headers = <String, String>{'content-type': 'application/json'};
      if (nonce != null && !tamper) {
        headers[kResponseSignatureHeader] = await _signHeader(
          target: responseSignedTarget(req.url),
          nonce: nonce,
          status: 200,
          body: body,
        );
      }
      return http.Response.bytes(body, 200, headers: headers);
    });
    final keys =
        KeysClient(baseUrl: Uri.parse('https://keys.test'), httpClient: mock);

    await keys.fetchBundle('P');
    expect(nonces['/v1/keys/bundle/P'], isNotNull);
    expect(ResponseAuthStats.snapshot()['ok:keys.bundle'], 1);

    tamper = true;
    await keys.fetchBundle('P');
    expect(ResponseAuthStats.snapshot()['missing:keys.bundle'], 1,
        reason: 'ответ без подписи считается, но не отвергается');

    await keys.getConfig().catchError((_) => <String, dynamic>{});
    expect(nonces['/v1/config'], isNull, reason: 'конфиг подписан сам');
  });

  test('блок server_auth: подпись побайтово, отказ — по умолчанию', () {
    expect(
      serverAuthSigningMessage(
        enforceShare: 5,
        relayKid: 'relay1',
        relayPubB64: 'AAAA',
        issuedAtMs: 1760000000123,
      ),
      'secretly-server-auth-v1|5|relay1|AAAA|1760000000123',
    );
    final config = <String, dynamic>{
      'server_auth': {
        'enforce_share': 150,
        'relay_kid': 'relay1',
        'relay_pub_b64': '',
      },
    };
    expect(ServerAuthFlags.fromConfigResponse(config, verified: false),
        ServerAuthFlags.defaults);
    final f = ServerAuthFlags.fromConfigResponse(config, verified: true);
    expect(f.enforceShare, 100);
    expect(f.relayKid, '', reason: 'половина ключа реле — ни одной');
    expect(f.enforceFor('dev'), isTrue);
    expect(ServerAuthFlags.defaults.enforceFor('dev'), isFalse);
    const half = ServerAuthFlags(enforceShare: 50);
    final n =
        List.generate(1000, (i) => half.enforceFor('d$i')).where((x) => x);
    expect(n.length, inInclusiveRange(400, 600));
  });

  group('свежесть подписанного конфига', () {
    Map<String, dynamic> config(int issued) => {
          'payload': {
            'monetization_enabled': false,
            'free_limits': EntitlementLimits.free.toJson(),
            'premium_limits': EntitlementLimits.premium.toJson(),
            'desktop_trial_days': 14,
            'issued_at_ms': issued,
          },
          'signature': 'x',
          'alg': 'ed25519',
        };

    Future<(int, String?)> refresh(int issued, Map<String, String> store) async {
      var afterConfig = 0;
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/config') {
          return http.Response(jsonEncode(config(issued)), 200);
        }
        afterConfig++;
        return http.Response('{}', 404);
      });
      final repo = EntitlementRepository(
        keysClient:
            KeysClient(baseUrl: Uri.parse('https://keys.test'), httpClient: mock),
        signer: _Signer(),
        cache: _Cache(store),
        verifyConfigForFreshness: (_) async => true,
      );
      await repo.refresh(profileId: 'P');
      return (afterConfig, store[EntitlementRepository.kConfigMaxIssuedAtKey]);
    }

    test('новый запоминается, старый — как несостоявшийся запрос', () async {
      final store = <String, String>{};
      const t = 1760000000000;
      final (fresh, mark) = await refresh(t, store);
      expect(mark, '$t');
      expect(fresh, greaterThan(0), reason: 'свежий конфиг идёт дальше');

      final (inTolerance, _) = await refresh(t - 5 * 60 * 1000, store);
      expect(inTolerance, greaterThan(0), reason: 'сдвиг часов в пределах запаса');

      final (stale, mark2) = await refresh(t - 60 * 60 * 1000, store);
      expect(stale, 0, reason: 'старый подписанный конфиг ничего не применяет');
      expect(mark2, '$t');
    });
  });

  // ── Э3 (25.10.2026): подпись ответов реле ─────────────────────────────────

  test('подписываемые маршруты реле — те же, что у сервера', () {
    for (final p in [
      '/v1/rooms/r1',
      '/v1/rooms/r1/members',
      '/v1/rooms/r1/call',
      '/v1/rooms/r1/call/e2ee_readiness',
      '/v1/active_devices/d1/p1',
      '/v1/ice/d1',
    ]) {
      expect(relayResponseSignedPath('GET', p), isTrue, reason: p);
    }
    for (final p in [
      '/v1/rooms',
      '/v1/rooms/r1/topics',
      '/v1/rooms/r1/call/c1/media',
      '/v1/pending/d1',
      '/v1/blob/b1',
      '/v1/active_devices/d1',
      '/health',
    ]) {
      expect(relayResponseSignedPath('GET', p), isFalse, reason: p);
    }
    expect(relayResponseSignedPath('POST', '/v1/rooms/r1/members'), isFalse);
  });

  test('обёртка реле: nonce на нужные GET, тело то же, исходы считаются',
      () async {
    final seen = <String, String?>{};
    var sign = true;
    final body = utf8.encode(jsonEncode({'members': <Object>[]}));
    final mock = MockClient((req) async {
      final nonce = req.headers[kResponseNonceHeader];
      seen['${req.method} ${req.url.path}'] = nonce;
      final headers = <String, String>{'content-type': 'application/json'};
      if (nonce != null && sign) {
        final kp = await Ed25519().newKeyPairFromSeed(List<int>.filled(32, 13));
        final msg = responseSigningMessage(
          kid: 'relay1',
          method: req.method,
          path: responseSignedTarget(req.url),
          nonce: nonce,
          tsMs: 7,
          status: 200,
          bodySha256B64: base64Encode(sha256.convert(body).bytes),
        );
        final sig = await Ed25519().sign(utf8.encode(msg), keyPair: kp);
        headers[kResponseSignatureHeader] =
            'v1;kid=relay1;ts=7;sig=${base64Encode(sig.bytes)}';
      }
      return http.Response.bytes(body, 200, headers: headers);
    });
    var keys = <String, String>{'relay1': _pub};
    final client = SignedResponseClient(mock, keys: () => keys);

    final r1 = await client.get(Uri.parse('https://relay.test/v1/rooms/r1/members'));
    expect(seen['GET /v1/rooms/r1/members'], isNotNull);
    expect(r1.bodyBytes, body, reason: 'ответ побайтово тот же');
    expect(ResponseAuthStats.snapshot()['ok:rooms.members'], 1);

    sign = false;
    await client.get(Uri.parse('https://relay.test/v1/ice/d1'));
    expect(ResponseAuthStats.snapshot()['missing:ice'], 1);

    sign = true;
    keys = const {};
    await client.get(Uri.parse('https://relay.test/v1/active_devices/d1/p1?min_build=650'));
    expect(ResponseAuthStats.snapshot()['noKey:active_devices'], 1,
        reason: 'ключ реле ещё не раздан — проверить нечем');

    await client.post(Uri.parse('https://relay.test/v1/rooms/r1/members'));
    expect(seen['POST /v1/rooms/r1/members'], isNull);
    await client.get(Uri.parse('https://relay.test/v1/pending/d1'));
    expect(seen['GET /v1/pending/d1'], isNull);
  });

  test('ключ реле берётся из проверенного блока целиком', () {
    RelayResponseKeys.set('relay1', _pub);
    expect(RelayResponseKeys.current, {'relay1': _pub});
    RelayResponseKeys.set('relay1', '');
    expect(RelayResponseKeys.current, isEmpty);
  });

  // ── Э2 (25.10.2026): отказ по доле, липкий ────────────────────────────────

  group('отказ', () {
    MockClient keysServer({required bool sign, required List<int> body}) =>
        MockClient((req) async {
          final nonce = req.headers[kResponseNonceHeader];
          final headers = <String, String>{'content-type': 'application/json'};
          if (nonce != null && sign) {
            headers[kResponseSignatureHeader] = await _signHeader(
              target: responseSignedTarget(req.url),
              nonce: nonce,
              status: 200,
              body: body,
            );
          }
          return http.Response.bytes(body, 200, headers: headers);
        });

    final body = utf8.encode(jsonEncode({'devices': <Object>[]}));

    test('выключен — неподписанный ответ проходит, как в Э1', () async {
      debugTrustedResponseKeys = _keys;
      final keys = KeysClient(
          baseUrl: Uri.parse('https://keys.test'),
          httpClient: keysServer(sign: false, body: body));
      expect(await keys.fetchBundle('P'), isEmpty);
      expect(ServerAuthEnforcement.lastRejection.value, isNull);
    });

    test('включён — неподписанный и подменённый ответ отвергаются', () async {
      debugTrustedResponseKeys = _keys;
      ServerAuthEnforcement.resetForTesting(enforced: true);
      final unsigned = KeysClient(
          baseUrl: Uri.parse('https://keys.test'),
          httpClient: keysServer(sign: false, body: body));
      await expectLater(unsigned.fetchBundle('P'),
          throwsA(isA<ServerUnauthenticatedException>()));
      expect(ServerAuthEnforcement.lastRejection.value?.route, 'keys.bundle');
      expect(ServerAuthEnforcement.lastRejection.value?.outcome,
          ResponseAuthOutcome.missing);

      // Подпись от другого тела — подмена.
      final forged = KeysClient(
        baseUrl: Uri.parse('https://keys.test'),
        httpClient: MockClient((req) async {
          final h = await _signHeader(
            target: responseSignedTarget(req.url),
            nonce: req.headers[kResponseNonceHeader]!,
            status: 200,
            body: utf8.encode('{"devices":[]}'),
          );
          return http.Response('{"devices":[{"device_id":"evil"}]}', 200,
              headers: {kResponseSignatureHeader: h});
        }),
      );
      await expectLater(forged.fetchBundle('P'),
          throwsA(isA<ServerUnauthenticatedException>()));
      expect(ServerAuthEnforcement.lastRejection.value?.outcome,
          ResponseAuthOutcome.bad);

      // Честный ответ проходит.
      final honest = KeysClient(
          baseUrl: Uri.parse('https://keys.test'),
          httpClient: keysServer(sign: true, body: body));
      expect(await honest.fetchBundle('P'), isEmpty);
    });

    test('включён, но проверить нечем — не отвергается', () async {
      debugTrustedResponseKeys = const {};
      ServerAuthEnforcement.resetForTesting(enforced: true);
      final keys = KeysClient(
          baseUrl: Uri.parse('https://keys.test'),
          httpClient: keysServer(sign: false, body: body));
      expect(await keys.fetchBundle('P'), isEmpty);
    });

    test('реле: включён — неподписанный состав комнаты отвергается', () async {
      ServerAuthEnforcement.resetForTesting(enforced: true);
      final client = SignedResponseClient(
        MockClient((req) async => http.Response('{"members":[]}', 200)),
        keys: () => const {'relay1': _pub},
      );
      await expectLater(
          client.get(Uri.parse('https://relay.test/v1/rooms/r1/members')),
          throwsA(isA<ServerUnauthenticatedException>()));
      // Неподписываемый маршрут не трогается.
      expect(
          (await client.get(Uri.parse('https://relay.test/v1/pending/d1')))
              .statusCode,
          200);
    });

    test('429 не отвергается: по нему повторяют', () async {
      ServerAuthEnforcement.resetForTesting(enforced: true);
      final client = SignedResponseClient(
        MockClient((req) async => http.Response('rate_limited', 429)),
        keys: () => const {'relay1': _pub},
      );
      final r =
          await client.get(Uri.parse('https://relay.test/v1/rooms/r1/members'));
      expect(r.statusCode, 429);
      expect(ServerAuthEnforcement.lastRejection.value, isNull);
    });

    test('текст ошибки не совпадает с приметами, по которым приложение '
        'стирает данные, перерегистрирует устройство или повторяет', () {
      for (final outcome in ResponseAuthOutcome.values) {
        final text = ServerUnauthenticatedException(
          route: 'keys.bundle',
          outcome: outcome,
        ).toString().toLowerCase();
        for (final marker in const [
          'failed: 401',
          'unknown requester device',
          'bad signature',
          'bad requester device_id',
          'missing x-secretly-device-id',
          'requester device missing identity key',
          '429',
          'rate_limited',
          'profile not found',
          'no such secretly id',
          'no target devices',
          'no reachable devices',
          'transport blocked',
          'different server',
          'safety key',
          'identity key changed',
        ]) {
          expect(text.contains(marker), isFalse, reason: '$outcome: $marker');
        }
      }
    });

    test('обёртка ContactActionFailure хранит причину и не путает её с '
        '«профиля нет» или «нет устройств»', () {
      const e = ServerUnauthenticatedException(
        route: 'keys.bundle',
        outcome: ResponseAuthOutcome.bad,
      );
      final f = describeContactActionFailure(
        e,
        fallbackCode: ContactActionFailureCode.serviceUnavailable,
      );
      expect(f.cause, same(e));
      expect(f.code, ContactActionFailureCode.serviceUnavailable);
    });

    test('липкость: переживает перезапуск, снимает только проверенный блок',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ServerAuthEnforcement.resetForTesting(fromStorage: true);
      await ServerAuthEnforcement.applyVerified(true);
      expect(ServerAuthEnforcement.enforced, isTrue);

      // «Перезапуск»: в памяти пусто, состояние поднимается из хранилища
      // до первого подписываемого запроса.
      ServerAuthEnforcement.resetForTesting(fromStorage: true);
      expect(ServerAuthEnforcement.enforced, isFalse);
      await ServerAuthEnforcement.ensureRestored();
      expect(ServerAuthEnforcement.enforced, isTrue);

      await ServerAuthEnforcement.applyVerified(false);
      ServerAuthEnforcement.resetForTesting(fromStorage: true);
      await ServerAuthEnforcement.ensureRestored();
      expect(ServerAuthEnforcement.enforced, isFalse);
    });
  });
}

class _Signer implements EntitlementSigner {
  @override
  String get deviceId => 'device-test-1';

  @override
  Future<String> signB64(List<int> message) async => 'sig';
}

class _Cache implements EntitlementCache {
  _Cache(this.store);
  final Map<String, String> store;
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> write(String key, String value) async => store[key] = value;
}
