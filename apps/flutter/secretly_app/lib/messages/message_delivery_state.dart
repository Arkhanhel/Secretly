// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
class MessageLocalState {
  MessageLocalState._();

  // Current production states.
  static const String received = 'received';
  static const String pending = 'pending';
  static const String sending = 'sending';
  static const String retry = 'retry';
  static const String sent = 'sent';
  static const String delivered = 'delivered';
  static const String read = 'read';
  static const String failed = 'failed';

  // Planned reliability states.
  static const String queuedLocal = 'queued_local';
  static const String encrypting = 'encrypting';
  static const String queuedRemote = 'queued_remote';
  static const String retryWait = 'retry_wait';
  static const String sentToServer = 'sent_to_server';
  static const String deliveredToAnyDevice = 'delivered_to_any_device';
  static const String deliveredToAllKnownDevices =
      'delivered_to_all_known_devices';
  static const String failedRetryable = 'failed_retryable';
  static const String failedPermanent = 'failed_permanent';
  static const String cancelled = 'cancelled';
  static const String scheduled = 'scheduled';

  static String normalize(String value) => value.trim().toLowerCase();

  static bool isOutgoingInFlight(String value) {
    final state = normalize(value);
    return state == pending ||
        state == sending ||
        state == retry ||
        state == scheduled;
  }

  static bool isOutgoingActionable(String value) {
    final state = normalize(value);
    return state == pending ||
        state == sending ||
        state == retry ||
        state == failed;
  }

  static bool isTerminal(String value) {
    final state = normalize(value);
    return state == failed || state == read;
  }

  /// Разрешён ли переход состояния исходящего сообщения.
  ///
  /// 🔴 ПОЧЕМУ ЭТО НЕ ФОРМАЛЬНОСТЬ (02.09.2026, полевая жалоба: «галочка
  /// сменилась на часики снова, потом опять на галочку»).
  ///
  /// Сообщение 1:1 разлетается по ВСЕМ устройствам собеседника — их бывает до
  /// восьми, — и каждая копия ведёт свою строку очереди с общим `event_id_ref`.
  /// Правило «побеждает первый успех» уже применено к подтверждению реле
  /// (`outboxMarkSent`), поэтому галочка появляется, как только конверт принят
  /// хотя бы для одного устройства. Но копия для второго устройства продолжает
  /// свои попытки, и `outboxMarkSending` откатывал событие обратно в
  /// «отправляется» — часы поверх уже показанной галочки. Дальше вторая копия
  /// подтверждалась, и галочка возвращалась. Индикатор скакал вперёд-назад
  /// столько раз, сколько устройств у собеседника.
  ///
  /// Прежняя редакция заканчивалась `return true`, то есть РАЗРЕШАЛА любой
  /// переход, который не описан явно, — включая любой откат назад. Единственной
  /// защитой была самодельная проверка внутри `outboxMarkSending`, и она
  /// покрывала лишь `delivered` и терминальные состояния; `sent` не покрывал
  /// никто.
  ///
  /// Правило теперь одно: индикатор показывает ЛУЧШЕЕ достигнутое состояние и
  /// назад не ходит. Незавершённость рассылки видна там, где ей и место, — в
  /// снимке диагностики, а досылкой занимается очередь.
  static bool canPromote({required String from, required String to}) {
    final current = normalize(from);
    final next = normalize(to);
    if (current == next) return true;
    // Первое присвоение: события нет или состояние ещё не проставлено.
    if (current.isEmpty) return true;
    if (next == sent) {
      return isOutgoingInFlight(current);
    }
    if (next == delivered) {
      // 🔴 `failed` В СПИСКЕ НАМЕРЕННО. Квитанция от собеседника — прямое
      // доказательство, что конверт у него; локальная пометка о провале рядом
      // с ней всего лишь наше предположение, и оно проиграло. Без этой ветки
      // сообщение, которое отправитель считал неотправленным (истёк ожидание,
      // оборвалась сеть в момент подтверждения), навсегда оставалось бы
      // красной галочкой — при том, что собеседник его уже читает.
      return current == pending ||
          current == sending ||
          current == retry ||
          current == sent ||
          current == failed;
    }
    if (next == read) {
      // Прочтение — сильнейшее свидетельство: применимо из любого состояния,
      // включая `failed`, по той же причине, что и доставка.
      return current != read;
    }
    if (next == failed) {
      // Провал имеет смысл, пока собеседник не подтвердил получение. После
      // квитанции о доставке или о прочтении сообщение у него УЖЕ есть —
      // объявлять его неотправленным было бы прямой ложью.
      return current != delivered && current != read;
    }
    if (isOutgoingInFlight(next)) {
      // Возврат в «в процессе» допустим только из такого же состояния (смена
      // ступени внутри отправки) или из провала — это ручной повтор. Из
      // `sent`, `delivered` и `read` — никогда: ровно этот откат и показывал
      // часы поверх готовой галочки.
      return isOutgoingInFlight(current) || current == failed;
    }
    return true;
  }
}

class OutboxSendState {
  OutboxSendState._();

  static const String pending = 'pending';
  static const String sending = 'sending';
  static const String retry = 'retry';
  static const String sent = 'sent';
  static const String failed = 'failed';

  static String normalize(String value) => value.trim().toLowerCase();

  static bool isDueState(String value) {
    final state = normalize(value);
    return state == pending || state == sending || state == retry;
  }
}

class MessageReceiptState {
  MessageReceiptState._();

  static const String delivered = 'delivered';
  static const String read = 'read';

  /// TZ Epic A (2026-07-18): NEGATIVE receipt — the recipient's device fetched
  /// a wire it could NOT decrypt even after trying the archived sessions, and
  /// parked it in quarantine. `ReceiptEventV1.refEventId` carries the RELAY
  /// `msg_id` (decrypt never happened, so no payload event id exists) with
  /// `refKind == 'msg_id'`. The sender reacts with a targeted rekey + resend —
  /// replacing the "no delivered receipt yet" guesswork with a positive
  /// failure signal. Rank stays 0: a NACK NEVER promotes/demotes the
  /// delivered/read progression, and pre-Epic-A clients ignore the status
  /// entirely (their consumption switch has no branch for it — verified +
  /// regression-tested 2026-07-18).
  static const String nackUndecryptable = 'nack_undecryptable';

  static String normalize(String value) => value.trim().toLowerCase();

  static int rank(String value) {
    switch (normalize(value)) {
      case delivered:
        return 1;
      case read:
        return 2;
      default:
        return 0;
    }
  }

  static bool canPromote({required String from, required String to}) {
    return rank(to) >= rank(from);
  }
}

class MessageFailureReason {
  MessageFailureReason._();

  static const String cancelled = 'cancelled';
  static const String manualRetry = 'manual_retry';
  static const String retryExhausted = 'retry_exhausted';
  static const String noDeliverableTarget = 'no_deliverable_target';
  static const String sendStallTimeout = 'send_stall_timeout';
  static const String networkOffline = 'network_offline';
  static const String relayUnavailable = 'relay_unavailable';
  static const String keysUnavailable = 'keys_unavailable';
  static const String recipientNoDevices = 'recipient_no_devices';
  static const String recipientBlocked = 'recipient_blocked';
  static const String ttlExpired = 'ttl_expired';
  static const String localPayloadMissing = 'local_payload_missing';
  // AUD-2026-04-25 D4: relay-side per-`msg_id` rejection codes (mirrors
  // `ServerMsg::SendError.code` from `server/relay/src/main.rs`).
  static const String relayRejectedBadRequest = 'relay_bad_request';
  static const String relayRejectedBadCiphertext = 'relay_bad_ciphertext';
  static const String relayRejectedAuthFailed = 'relay_auth_failed';
  static const String relayRejectedUnknownRecipient = 'relay_unknown_recipient';
  static const String relayRejectedOverCapacity = 'relay_over_capacity';
  static const String relayRejectedStoreError = 'relay_store_error';

  /// Classify a relay `send_error` code into the canonical reason string and
  /// whether the failure is permanent (true) or transient/retryable (false).
  /// Used by [transport.RelayClient] to decide between `outboxMarkFailed` and
  /// `outboxMarkSending` on per-`msg_id` WebSocket rejections.
  static ({String reason, bool permanent}) classifyRelaySendError(String code) {
    switch (code) {
      case 'bad_request':
        return (reason: relayRejectedBadRequest, permanent: true);
      case 'bad_ciphertext':
        return (reason: relayRejectedBadCiphertext, permanent: true);
      case 'auth_failed':
        return (reason: relayRejectedAuthFailed, permanent: true);
      case 'blocked':
        return (reason: recipientBlocked, permanent: true);
      // `unknown recipient device` typically means the recipient rotated their
      // device and we hold a stale device list. Mark permanent so the message
      // visibly fails; the next `refreshContactDevices` will recover the
      // outbox row's logical event on user re-send.
      case 'unknown_recipient':
        return (reason: relayRejectedUnknownRecipient, permanent: true);
      case 'over_capacity':
        return (reason: relayRejectedOverCapacity, permanent: false);
      case 'store_error':
        return (reason: relayRejectedStoreError, permanent: false);
      default:
        return (reason: relayUnavailable, permanent: false);
    }
  }
}
