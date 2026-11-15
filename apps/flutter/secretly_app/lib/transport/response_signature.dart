// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/diag_log.dart';
import '../entitlements/entitlement_signature.dart'
    show kConfigPublicKeyB64, kConfigPublicKeyNextB64;

/// Б3 (25.10.2026): подпись ответов keys (docs/TZ_SERVER_AUTH_B3_2026-10-25.md).
///
/// Посредник с «правильным» TLS-сертификатом может переслать ответ, но не
/// изменить его: на подписываемый запрос сервер отвечает заголовком с
/// подписью над методом, путём с запросом, нашим одноразовым `nonce`, кодом и
/// хэшем тела. Э1 только проверяет и считает — ничего не отвергает.

const String kResponseNonceHeader = 'x-secretly-resp-nonce';
const String kResponseSignatureHeader = 'x-secretly-resp-sig';

/// Ключ, которым keys подписывает ответы, — тот же, что подписывает
/// `/v1/config`.
const String kResponseKeyIdConfig = 'cfg1';

/// Метка следующего ключа подписи конфигурации (15.11.2026): когда сервер
/// перейдёт на него, ответы подписываются с `kid=cfg2`.
const String kResponseKeyIdConfigNext = 'cfg2';

enum ResponseAuthOutcome {
  /// Подпись сошлась.
  ok,

  /// Подписываемый ответ пришёл без подписи (старый сервер или посредник).
  missing,

  /// Подпись есть, но не сходится, битая или чужим ключом.
  bad,

  /// Проверить нечем: в сборке нет ключа (отладочные сборки).
  noKey,
}

/// Зеркало Rust `resp_signing_message`. Заморожено: договор с сервером
/// побайтово.
String responseSigningMessage({
  required String kid,
  required String method,
  required String path,
  required String nonce,
  required int tsMs,
  required int status,
  required String bodySha256B64,
}) {
  return 'SECRETLY-RESP-V1\n'
      'kid=$kid\n'
      'method=$method\n'
      'path=$path\n'
      'nonce=$nonce\n'
      'ts_ms=$tsMs\n'
      'status=$status\n'
      'body_sha256_b64=$bodySha256B64\n';
}

/// Зеркало Rust `resp_signed_route`: ответы, по которым решается, на чей
/// ключ шифровать и кого добавить.
bool responseSignedPath(String method, String path) {
  if (method.toUpperCase() != 'GET') return false;
  final p = path.startsWith('/') ? path.substring(1) : path;
  final s = p.split('/');
  if (s.length < 3 || s[0] != 'v1') return false;
  bool id(String v) => v.isNotEmpty;
  if (s.length == 4 && s[1] == 'keys' && s[2] == 'bundle') return id(s[3]);
  if (s[1] == 'device') {
    if (s.length == 4 && (s[3] == 'bundle' || s[3] == 'identity')) {
      return id(s[2]);
    }
    if (s.length == 3) {
      return id(s[2]) && s[2] != 'challenge' && s[2] != 'self_status';
    }
    return false;
  }
  if (s[1] == 'profile') {
    if (s.length == 3) return s[2] == 'search';
    if (s.length == 4 && (s[3] == 'devices' || s[3] == 'own_devices')) {
      return id(s[2]);
    }
  }
  return false;
}

/// Б3 Э3: зеркало Rust `resp_signed_route` реле — ответы, по которым
/// решается про состав комнаты, созвон, устройства собеседника и TURN.
bool relayResponseSignedPath(String method, String path) {
  if (method.toUpperCase() != 'GET') return false;
  final p = path.startsWith('/') ? path.substring(1) : path;
  final s = p.split('/');
  if (s.length < 3 || s[0] != 'v1') return false;
  if (s[1] == 'rooms') {
    if (s[2].isEmpty) return false;
    if (s.length == 3) return true;
    if (s.length == 4) return s[3] == 'members' || s[3] == 'call';
    return s.length == 5 && s[3] == 'call' && s[4] == 'e2ee_readiness';
  }
  if (s[1] == 'active_devices') {
    return s.length == 4 && s[2].isNotEmpty && s[3].isNotEmpty;
  }
  if (s[1] == 'ice') return s.length == 3 && s[2].isNotEmpty;
  return false;
}

/// Б3 Э3: ключи подписи ответов реле — из проверенного блока `server_auth`
/// (`AppController` кладёт их сюда при каждом разборе конфига). Пусто —
/// проверить нечем (`noKey`): реле ещё не подписывает или конфиг не пришёл.
class RelayResponseKeys {
  RelayResponseKeys._();

  static Map<String, String> _keys = const <String, String>{};

  static Map<String, String> get current => _keys;

  static void set(String kid, String pubB64) {
    _keys = kid.isEmpty || pubB64.isEmpty
        ? const <String, String>{}
        : <String, String>{kid: pubB64};
  }
}

/// Б3 Э3: обёртка HTTP-клиента реле. На подписываемые GET добавляет
/// одноразовый `nonce`, проверяет подпись ключом реле и считает исход.
/// Отвергает только при включённом отказе (Э2, [ServerAuthEnforcement]);
/// иначе ответ возвращается побайтово тем же.
class SignedResponseClient extends http.BaseClient {
  SignedResponseClient(this._inner, {Map<String, String> Function()? keys})
      : _keys = keys ?? (() => RelayResponseKeys.current);

  final http.Client _inner;
  final Map<String, String> Function() _keys;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!relayResponseSignedPath(request.method, request.url.path)) {
      return _inner.send(request);
    }
    await ServerAuthEnforcement.ensureRestored();
    final nonce = newResponseNonce();
    request.headers[kResponseNonceHeader] = nonce;
    final resp = await _inner.send(request);
    if (resp.statusCode >= 500) return resp;
    final body = await resp.stream.toBytes();
    final target = responseSignedTarget(request.url);
    final outcome = await verifyResponseSignature(
      method: request.method,
      target: target,
      nonce: nonce,
      status: resp.statusCode,
      body: body,
      header: resp.headers[kResponseSignatureHeader],
      trustedKeys: _keys(),
    );
    ResponseAuthStats.record(outcome, target);
    if (ServerAuthEnforcement.shouldReject(outcome, resp.statusCode)) {
      throw ServerAuthEnforcement.reject(outcome, target);
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(body),
      resp.statusCode,
      contentLength: body.length,
      request: resp.request,
      headers: resp.headers,
      isRedirect: resp.isRedirect,
      persistentConnection: resp.persistentConnection,
      reasonPhrase: resp.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}

/// Путь с запросом ровно так, как его видит сервер (`path_and_query`).
String responseSignedTarget(Uri uri) =>
    uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;

String newResponseNonce() {
  final r = Random.secure();
  return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
}

/// Ключи для тестов: в тестовой сборке вшитого ключа нет.
@visibleForTesting
Map<String, String>? debugTrustedResponseKeys;

/// Проверяет подпись ответа. [trustedKeys] — `kid` → открытый ключ base64;
/// по умолчанию ключ конфига из сборки.
Future<ResponseAuthOutcome> verifyResponseSignature({
  required String method,
  required String target,
  required String nonce,
  required int status,
  required Uint8List body,
  required String? header,
  Map<String, String>? trustedKeys,
}) async {
  final keys = trustedKeys ??
      debugTrustedResponseKeys ??
      (kConfigPublicKeyB64.isEmpty
          ? const <String, String>{}
          : <String, String>{
              kResponseKeyIdConfig: kConfigPublicKeyB64,
              if (kConfigPublicKeyNextB64.isNotEmpty)
                kResponseKeyIdConfigNext: kConfigPublicKeyNextB64,
            });
  if (keys.isEmpty) return ResponseAuthOutcome.noKey;
  final raw = header?.trim() ?? '';
  if (raw.isEmpty) return ResponseAuthOutcome.missing;
  try {
    final parts = raw.split(';');
    if (parts.first != 'v1') return ResponseAuthOutcome.bad;
    final fields = <String, String>{};
    for (final part in parts.skip(1)) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      fields[part.substring(0, i)] = part.substring(i + 1);
    }
    final kid = fields['kid'] ?? '';
    final ts = int.tryParse(fields['ts'] ?? '');
    final sig = fields['sig'] ?? '';
    final pub = keys[kid];
    if (pub == null || ts == null || sig.isEmpty) return ResponseAuthOutcome.bad;
    final message = responseSigningMessage(
      kid: kid,
      method: method.toUpperCase(),
      path: target,
      nonce: nonce,
      tsMs: ts,
      status: status,
      bodySha256B64: base64Encode(sha256.convert(body).bytes),
    );
    final ok = await Ed25519().verify(
      utf8.encode(message),
      signature: Signature(
        base64Decode(sig),
        publicKey: SimplePublicKey(base64Decode(pub), type: KeyPairType.ed25519),
      ),
    );
    return ok ? ResponseAuthOutcome.ok : ResponseAuthOutcome.bad;
  } catch (_) {
    return ResponseAuthOutcome.bad;
  }
}

/// Б3 Э2 (25.10.2026): ответ с ключами или составом не прошёл проверку, а
/// для этого устройства отказ включён. Вызывающий видит обычный сбой запроса:
/// новый ключ, новое устройство или новый состав не принимаются, переписка в
/// существующих сессиях идёт — ей подпись сервера не нужна.
class ServerUnauthenticatedException implements Exception {
  const ServerUnauthenticatedException({
    required this.route,
    required this.outcome,
  });

  /// Вид маршрута без идентификаторов ([ResponseAuthStats.routeKind]).
  final String route;
  final ResponseAuthOutcome outcome;

  /// 🔴 Текст нейтральный, без кода и тела ответа. По тексту ошибок
  /// приложение узнаёт «устройство удалено» (вплоть до стирания данных),
  /// «нужна перерегистрация» и «повторить при 429» — ни одна из этих примет
  /// здесь не должна совпасть. Сторожит тест.
  @override
  String toString() =>
      'ServerUnauthenticatedException(route=$route, outcome=${outcome.name})';
}

/// Б3 Э2: включён ли отказ на этом устройстве.
///
/// 🔴 **Липкий.** Посредник может не пропустить конфиг или вырезать из него
/// блок `server_auth`; если бы отказ держался только на последнем конфиге,
/// так его можно было бы выключить. Поэтому:
/// * состояние хранится между запусками и поднимается до первого
///   подписываемого запроса ([ensureRestored]);
/// * меняет его только **проверенный** блок ([applyVerified]); блок, которого
///   нет или чья подпись не сошлась, не меняет ничего;
/// * старый подписанный конфиг отсекает проверка свежести в репозитории.
class ServerAuthEnforcement {
  ServerAuthEnforcement._();

  static const String prefsKey = 'server_auth_enforced_v1';

  static bool _enforced = false;
  static Future<void>? _restoring;

  /// Последний отказ — для предупреждения в интерфейсе.
  static final ValueNotifier<ServerUnauthenticatedException?> lastRejection =
      ValueNotifier<ServerUnauthenticatedException?>(null);

  static bool get enforced => _enforced;

  static Future<void> ensureRestored() => _restoring ??= _restore();

  static Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enforced = _enforced || (prefs.getBool(prefsKey) ?? false);
    } catch (_) {
      // Нет хранилища (тесты, ранний старт) — как было в памяти.
    }
  }

  /// Только из проверенного блока `server_auth`: [enforce] — входит ли это
  /// устройство в долю.
  static Future<void> applyVerified(bool enforce) async {
    await ensureRestored();
    if (_enforced == enforce) return;
    _enforced = enforce;
    if (!enforce) lastRejection.value = null;
    DiagLog.event('server_auth', enforce ? 'enforce_on' : 'enforce_off',
        <String, Object?>{});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, enforce);
    } catch (_) {}
  }

  /// Отвергать ли ответ с таким исходом и кодом.
  /// * Нечем проверить ([ResponseAuthOutcome.noKey]) — нет: отказ без ключа
  ///   отрезал бы людей ни за что.
  /// * 429 — нет: вызывающий код повторяет по нему (ответ на звонок,
  ///   очередь сообщений), а поддельный 429 даёт посреднику лишь задержку,
  ///   которую он может устроить и так.
  static bool shouldReject(ResponseAuthOutcome outcome, int status) =>
      _enforced &&
      status != 429 &&
      (outcome == ResponseAuthOutcome.missing ||
          outcome == ResponseAuthOutcome.bad);

  /// Записывает отказ и возвращает исключение для броска.
  static ServerUnauthenticatedException reject(
    ResponseAuthOutcome outcome,
    String target,
  ) {
    final e = ServerUnauthenticatedException(
      route: ResponseAuthStats.routeKind(target),
      outcome: outcome,
    );
    lastRejection.value = e;
    DiagLog.event('server_auth', 'rejected', <String, Object?>{
      'route': e.route,
      'outcome': outcome.name,
    });
    return e;
  }

  /// [fromStorage] — забыть, что состояние уже поднято, чтобы следующий
  /// запрос прочитал его из хранилища (как после перезапуска).
  @visibleForTesting
  static void resetForTesting({bool enforced = false, bool fromStorage = false}) {
    _enforced = enforced;
    _restoring = fromStorage ? null : Future<void>.value();
    lastRejection.value = null;
  }
}

/// Счётчики Э1 по исходам и видам ответов. В `DiagLog` уходит первый случай
/// каждого «не ок» за запуск — замер для решения о включении отказа (Э2).
class ResponseAuthStats {
  ResponseAuthStats._();

  static final Map<String, int> _counts = <String, int>{};
  static final Set<String> _logged = <String>{};

  static Map<String, int> snapshot() => Map<String, int>.unmodifiable(_counts);

  static void record(ResponseAuthOutcome outcome, String target) {
    final route = routeKind(target);
    final key = '${outcome.name}:$route';
    _counts[key] = (_counts[key] ?? 0) + 1;
    if (outcome == ResponseAuthOutcome.ok ||
        outcome == ResponseAuthOutcome.noKey) {
      return;
    }
    if (_logged.add(key)) {
      DiagLog.event('server_auth', outcome.name, <String, Object?>{
        'route': route,
      });
    }
  }

  /// Вид маршрута без идентификаторов: в журнал не попадают номера профилей.
  static String routeKind(String target) {
    final path = target.split('?').first;
    final s = (path.startsWith('/') ? path.substring(1) : path).split('/');
    if (s.length >= 3 && s[1] == 'keys') return 'keys.bundle';
    if (s.length >= 3 && s[1] == 'device') {
      return s.length == 4 ? 'device.${s[3]}' : 'device.lookup';
    }
    if (s.length >= 3 && s[1] == 'profile') {
      return s.length == 3 ? 'profile.search' : 'profile.${s[3]}';
    }
    if (s.length >= 3 && s[1] == 'rooms') {
      return s.length == 3 ? 'rooms.room' : 'rooms.${s.sublist(3).join('.')}';
    }
    if (s.length >= 3 && s[1] == 'active_devices') return 'active_devices';
    if (s.length >= 3 && s[1] == 'ice') return 'ice';
    return 'other';
  }

  static void resetForTesting() {
    _counts.clear();
    _logged.clear();
  }
}
