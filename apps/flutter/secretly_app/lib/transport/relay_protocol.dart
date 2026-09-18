// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

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
      'sent_ok' => SentOk(msgId: m['msg_id'] as String),
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

class SentOk extends ServerMsg {
  SentOk({required this.msgId});

  final String msgId;
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
