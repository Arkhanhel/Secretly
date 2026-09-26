// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

class ClientMsg {
  static String hello({required String deviceId, String clientBuild = ''}) =>
      jsonEncode({
        'type': 'hello',
        'device_id': deviceId,
        if (clientBuild.isNotEmpty) 'client_build': clientBuild,
      });

  /// 🔴 [clientBuild] здесь — почин измерителя раскатки (22.08.2026).
  ///
  /// Номер сборки ездил только в заголовке ПОДПИСАННЫХ HTTP-запросов, а
  /// активность устройства отмечается в четырёх местах, три из которых —
  /// WebSocket. Устройство, живущее на сокете, отмечалось активным и при этом
  /// НИКОГДА не называло свою сборку: в замере такие попадали в «версии нет»,
  /// и по этой графе (29% парка) невозможно было отличить необновившегося от
  /// обычного пользователя на свежей сборке. Решение о раскатке Э-4 упиралось
  /// ровно в это.
  ///
  /// Поле НЕ входит в подписываемое сообщение — как и заголовок, и по той же
  /// причине: подписываемый вид общий с сервером, менять его ради счётчика
  /// значит ломать совместимость со всеми существующими сборками. Сервер не
  /// принимает по нему никаких решений.
  static String helloAuth({
    required String deviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    String clientBuild = '',
  }) {
    return jsonEncode({
      'type': 'hello_auth',
      'device_id': deviceId,
      'ts_ms': tsMs,
      'nonce_b64': nonceB64,
      'signature_b64': signatureB64,
      if (clientBuild.isNotEmpty) 'client_build': clientBuild,
    });
  }

  static String ping() => jsonEncode({'type': 'ping'});

  static String send({
    required String toDeviceId,
    required String msgId,
    required String ciphertextB64,
    required int ttlSeconds,
    String? transportMetaJson,
    // SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): relay release time; omitted
    // / 0 = deliver immediately (default for every normal message).
    int deliverAtMs = 0,
    // П-4 (25.09.2026): «только тем, кто на связи» — для «печатает». Поле
    // уходит только когда true: иначе кадр побайтово прежний.
    bool onlineOnly = false,
    // П-1 (25.09.2026): сводка росписи адресата — только если задана.
    String? rcptDigest,
  }) {
    return jsonEncode({
      'type': 'send',
      'to_device_id': toDeviceId,
      'msg_id': msgId,
      'ciphertext_b64': ciphertextB64,
      'ttl_seconds': ttlSeconds,
      if (transportMetaJson != null && transportMetaJson.trim().isNotEmpty)
        'transport_meta_json': transportMetaJson.trim(),
      if (deliverAtMs > 0) 'deliver_at_ms': deliverAtMs,
      if (onlineOnly) 'online_only': true,
      if (rcptDigest != null && rcptDigest.isNotEmpty) 'rcpt_digest': rcptDigest,
    });
  }

  static String ack({
    required String deviceId,
    required int seq,
    required String msgId,
  }) {
    return jsonEncode({
      'type': 'ack',
      'device_id': deviceId,
      'seq': seq,
      'msg_id': msgId,
    });
  }

  static String fetchPending({required String deviceId, required int fromSeq}) {
    return jsonEncode({
      'type': 'fetch_pending',
      'device_id': deviceId,
      'from_seq': fromSeq,
    });
  }
}

sealed class ServerMsg {
  static ServerMsg parse(String text) {
    final m = jsonDecode(text) as Map<String, dynamic>;
    final t = m['type'] as String?;
    return switch (t) {
      'welcome' => Welcome(
        deviceId: m['device_id'] as String,
        nextSeq: (m['next_seq'] as num).toInt(),
      ),
      'sent_ok' => SentOk(
        msgId: m['msg_id'] as String,
        delivery: m['delivery'] is String ? m['delivery'] as String : null,
        deviceSetStale: m['device_set_stale'] == true,
        deviceIds: m['device_ids'] is List
            ? (m['device_ids'] as List).whereType<String>().toList()
            : null,
      ),
      'deliver' => Deliver(
        deviceId: m['device_id'] as String,
        seq: (m['seq'] as num).toInt(),
        msgId: m['msg_id'] as String,
        ciphertextB64: m['ciphertext_b64'] as String,
        fromDeviceId: m['from_device_id'] is String
            ? m['from_device_id'] as String
            : null,
      ),
      'error' => ErrorMsg(
        code: m['code'] as String? ?? 'unknown',
        message: m['message'] as String? ?? '',
      ),
      // AUD-2026-04-25 D4: per-`msg_id` send error from relay so the client
      // can deterministically transition that exact outbox row instead of
      // leaving the user with a stuck "часики" indicator.
      'send_error' => SendErrorMsg(
        msgId: m['msg_id'] as String? ?? '',
        code: m['code'] as String? ?? 'unknown',
        message: m['message'] as String? ?? '',
      ),
      'pong' => Pong(),
      _ => Unknown(raw: m),
    };
  }
}

class Welcome extends ServerMsg {
  Welcome({required this.deviceId, required this.nextSeq});

  final String deviceId;
  final int nextSeq;
}

/// П-4 (25.09.2026): метка строки исходящих «только тем, кто на связи».
/// Столбец `transport_hint` уже есть — миграции не нужно.
const String onlineOnlyTransportHint = 'online_only';

/// Строка исходящих помечена «только на связи» — все три пути отправки
/// (сокет, HTTP, фоновый воркер) обязаны нести поле `online_only`.
bool isOnlineOnlyOutboxRow(Map<String, Object?> row) =>
    (row['transport_hint'] as String?) == onlineOnlyTransportHint;

class SentOk extends ServerMsg {
  SentOk({
    required this.msgId,
    this.delivery,
    this.deviceSetStale = false,
    this.deviceIds,
  });

  final String msgId;

  /// П-4: только для посылок `online_only` — `dropped_offline` (получатель
  /// не на связи, ничего не записано) или `realtime`. Иначе null.
  final String? delivery;

  /// П-1: сводка росписи отправителя устарела; [deviceIds] — настоящий
  /// список «кому слать» адресата.
  final bool deviceSetStale;
  final List<String>? deviceIds;
}

/// 🔴 П-1 (25.09.2026): сводка множества устройств — hex первых 16 байт
/// sha256("md-set-v1\n" + отсортированные номера через "\n", без повторов).
/// ОБЯЗАНА совпадать с сервером ключей (`device_set_digest`) — закреплено
/// одинаковыми значениями с обеих сторон. Сортировка Dart (по UTF-16) и Rust
/// (по байтам UTF-8) совпадают для номеров устройств: это ASCII.
String deviceSetDigest(Iterable<String> ids) {
  final sorted = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
    ..sort();
  final digest = crypto.sha256.convert(
    utf8.encode('md-set-v1\n${sorted.join('\n')}'),
  );
  final b = digest.bytes.sublist(0, 16);
  return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

class Deliver extends ServerMsg {
  Deliver({
    required this.deviceId,
    required this.seq,
    required this.msgId,
    required this.ciphertextB64,
    this.fromDeviceId,
  });

  final String deviceId;
  final int seq;
  final String msgId;
  final String ciphertextB64;

  /// Отправитель по словам реле (ИД-1 / С-1). null — реле его не назвало.
  final String? fromDeviceId;
}

class ErrorMsg extends ServerMsg {
  ErrorMsg({required this.code, required this.message});

  final String code;
  final String message;
}

/// Per-`msg_id` send error from relay (AUD-2026-04-25 D4). Sent on the
/// WebSocket transport in addition to a legacy [ErrorMsg] companion so that
/// new clients can route the failure to the exact outbox row, while older
/// clients keep working off the generic [ErrorMsg] event.
class SendErrorMsg extends ServerMsg {
  SendErrorMsg({
    required this.msgId,
    required this.code,
    required this.message,
  });

  final String msgId;
  final String code;
  final String message;
}

class Unknown extends ServerMsg {
  Unknown({required this.raw});

  final Map<String, dynamic> raw;
}

class Pong extends ServerMsg {}
