// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
enum CallNetworkPolicy { p2pPreferred, relayPreferred, relayOnly }

class CallIceServerConfig {
  const CallIceServerConfig({
    required this.urls,
    this.username,
    this.credential,
  });

  final List<String> urls;
  final String? username;
  final String? credential;

  bool get isTurn =>
      urls.any((value) => value.startsWith('turn:') || value.startsWith('turns:'));

  bool get isStun => urls.any((value) => value.startsWith('stun:'));

  Map<String, Object?> toRtcMap() {
    final cleanUrls = urls.where((value) => value.trim().isNotEmpty).toList(
      growable: false,
    );
    return <String, Object?>{
      'urls': cleanUrls.length == 1 ? cleanUrls.first : cleanUrls,
      if ((username ?? '').trim().isNotEmpty) 'username': username!.trim(),
      if ((credential ?? '').trim().isNotEmpty)
        'credential': credential!.trim(),
    };
  }

  factory CallIceServerConfig.fromJson(Map<String, dynamic> json) {
    final dynamic rawUrls = json['urls'];
    final urls = <String>[];
    if (rawUrls is String && rawUrls.trim().isNotEmpty) {
      urls.add(rawUrls.trim());
    } else if (rawUrls is Iterable) {
      for (final value in rawUrls) {
        final text = (value as Object?)?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          urls.add(text);
        }
      }
    }
    return CallIceServerConfig(
      urls: urls,
      username: (json['username'] as String?)?.trim(),
      credential: (json['credential'] as String?)?.trim(),
    );
  }
}

class CallIceConfigSnapshot {
  const CallIceConfigSnapshot({
    required this.policy,
    required this.iceServers,
    this.expiresAtMs,
  });

  const CallIceConfigSnapshot.empty()
    : policy = CallNetworkPolicy.p2pPreferred,
      iceServers = const <CallIceServerConfig>[],
      expiresAtMs = null;

  final CallNetworkPolicy policy;
  final List<CallIceServerConfig> iceServers;
  final int? expiresAtMs;

  bool isExpired({int? nowMs}) {
    // 🔴 ПУСТОЙ СНИМОК — ЭТО «КОНФИГУРАЦИИ ЕЩЁ НЕТ», А НЕ «ОНА ВЕЧНО СВЕЖАЯ»
    // (22.08.2026).
    //
    // Кэш живёт только в памяти, поэтому после каждого холодного старта он
    // пуст, а у пустого снимка `expiresAtMs == null`. Прежняя проверка
    // отвечала на это «не истёк», и `AppController.getCallIceConfig` честно
    // возвращала пустую конфигурацию, НЕ СХОДИВ НА СЕРВЕР. Дальше в неё
    // подмешивались запасные STUN — и звонок уходил в сеть без единого TURN,
    // с политикой по умолчанию, хотя реле отдаёт `relay_preferred` и три
    // TURN-адреса.
    //
    // Замер поля 22.08: `call.ice_no_turn_servers policy=p2pPreferred
    // totalIceServers=2 stunOnly=true` — первый же звонок после запуска.
    // Между двумя NAT такой звонок либо не соединяется, либо соединяется без
    // звука; TURN подтягивался только после провала ICE, когда восстановление
    // просило принудительное обновление. Отсюда «при плохой сети о звонках
    // можно забыть».
    //
    // Снимок БЕЗ серверов бесполезен по определению, поэтому он всегда
    // «истёк»: пусть первый же вызов сходит за настоящим.
    if (iceServers.isEmpty) return true;
    final expires = expiresAtMs;
    if (expires == null) return false;
    return (nowMs ?? DateTime.now().millisecondsSinceEpoch) >= expires;
  }

  String get rtcIceTransportPolicy =>
      policy == CallNetworkPolicy.relayOnly ? 'relay' : 'all';

  bool get hasConfiguredIceServers => iceServers.any(
    (value) => value.urls.any((url) => url.trim().isNotEmpty),
  );

  bool get hasUsableRelayServers => iceServers.any((value) => value.isTurn);

  List<Map<String, Object?>> toRtcIceServers() {
    final servers = iceServers.where((value) => value.urls.isNotEmpty).toList(
      growable: false,
    );
    if (servers.isEmpty) return const <Map<String, Object?>>[];

    late final List<CallIceServerConfig> ordered;
    switch (policy) {
      case CallNetworkPolicy.p2pPreferred:
        ordered = <CallIceServerConfig>[
          ...servers.where((value) => value.isStun),
          ...servers.where((value) => !value.isStun),
        ];
        break;
      case CallNetworkPolicy.relayPreferred:
        ordered = <CallIceServerConfig>[
          ...servers.where((value) => value.isTurn),
          ...servers.where((value) => !value.isTurn),
        ];
        break;
      case CallNetworkPolicy.relayOnly:
        ordered = <CallIceServerConfig>[
          ...servers.where((value) => value.isTurn),
        ];
        break;
    }
    return ordered.map((value) => value.toRtcMap()).toList(growable: false);
  }

  CallIceConfigSnapshot pruneExpiredCredentials({int? nowMs}) {
    if (!isExpired(nowMs: nowMs)) {
      return this;
    }
    // BUG-FIX (ICE-STALE-CACHE 2026-05-29):
    //
    // Previously this method set `expiresAtMs: null` on the pruned
    // snapshot, which marked the STUN-only fallback as «never expires».
    // After the very first credential expiry the client would forever
    // refuse to re-fetch fresh TURN credentials from the relay because
    // `isExpired()` always returned `false` — and any subsequent call
    // between NAT'd peers would silently fail at ICE connectivity
    // checks (RTCIceConnectionStateDisconnected, no media, see the
    // 2026-05-28 reproduction in journalctl + adb logcat).
    //
    // We now carry the **original** `expiresAtMs` forward. The pruned
    // snapshot stays «expired» so the next `AppController.getCallIceConfig`
    // call will issue a refresh against `GET /v1/ice/{device_id}` and
    // pick up new short-lived TURN credentials. If the refresh itself
    // fails (relay offline), `getCallIceConfig`'s catch-arm still
    // returns this pruned snapshot as a graceful STUN-only fallback —
    // so a transient outage doesn't make calls impossible, but a
    // recovered relay immediately restores TURN.
    final preservedExpiresAtMs = expiresAtMs;
    if (policy == CallNetworkPolicy.relayOnly) {
      return CallIceConfigSnapshot(
        policy: CallNetworkPolicy.relayOnly,
        iceServers: const <CallIceServerConfig>[],
        expiresAtMs: preservedExpiresAtMs,
      );
    }
    return CallIceConfigSnapshot(
      policy: CallNetworkPolicy.p2pPreferred,
      iceServers: iceServers.where((value) => value.isStun).toList(
        growable: false,
      ),
      expiresAtMs: preservedExpiresAtMs,
    );
  }

  static CallNetworkPolicy parsePolicy(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'relay_preferred':
        return CallNetworkPolicy.relayPreferred;
      case 'relay_only':
        return CallNetworkPolicy.relayOnly;
      case 'p2p_preferred':
      default:
        return CallNetworkPolicy.p2pPreferred;
    }
  }

  factory CallIceConfigSnapshot.fromJson(Map<String, dynamic> json) {
    final rawServers = (json['ice_servers'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CallIceServerConfig.fromJson)
        .where((value) => value.urls.isNotEmpty)
        .toList(growable: false);
    final rawExpiry = json['expires_at_ms'];
    final expiresAtMs = rawExpiry is num ? rawExpiry.toInt() : null;
    return CallIceConfigSnapshot(
      policy: parsePolicy(json['policy'] as String?),
      iceServers: rawServers,
      expiresAtMs: expiresAtMs,
    );
  }
}