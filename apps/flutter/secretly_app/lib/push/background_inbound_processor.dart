// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../transport/attested_senders.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/diag_log.dart';
import '../storage/app_db.dart';

/// One wire fetched from the relay: its transport id and ciphertext.
@immutable
class BackgroundInboundWire {
  const BackgroundInboundWire({
    required this.msgId,
    required this.ciphertextB64,
    this.seq,
  });
  final String msgId;
  final String ciphertextB64;

  /// Номер в ящике реле. Нужен, чтобы ПОДТВЕРДИТЬ приём.
  ///
  /// 🔴 Реле его отдаёт (`PendingItem { seq, msg_id, ciphertext_b64 }`), а
  /// сборщик раньше терял при сборке конверта — и подтвердить было нечем:
  /// номер входит в ПОДПИСЫВАЕМОЕ сообщение, угадать его нельзя.
  ///
  /// `null` допустим: старый вызов без номера просто не подтверждает, как и
  /// раньше. Молча не подтвердить — безопасно, реле пришлёт снова.
  final int? seq;
}

/// What a background pass did, so the caller can log and decide whether to
/// raise a summary notification / whether it is worth waking the main isolate.
@immutable
class BackgroundInboundResult {
  const BackgroundInboundResult({
    required this.applied,
    required this.staged,
    required this.skipped,
    this.acked = 0,
    this.ackFailed = 0,
  });
  final int applied; // decrypted + persisted (+ notified) in the background
  final int staged; // could not decrypt now → parked for the foreground
  final int skipped; // already seen

  /// 🔴 ДОШЕДШИЕ подтверждения, а не попытки. Разница принципиальна: 11.08 я
  /// принял «acked=10» за доказательство работы, а реле не приняло ни одного —
  /// клиент HTTP к тому моменту был закрыт. Замер, который не умеет
  /// провалиться, не замер.
  final int acked;
  final int ackFailed;

  int get total => applied + staged + skipped;
}

/// Decrypts fetched wires INSIDE the background isolate, so a message shows the
/// moment it arrives instead of waiting for the user to open the app.
///
/// The decrypt itself is injected ([decrypt]) rather than built here: in
/// production it is `AppController.handleDeliveredInBackground`, which runs the
/// exact foreground delivery path; in tests it is a fake, so this orchestration
/// — mark-seen on success, park on failure, never double-process — is provable
/// without standing up a full ratchet session.
///
/// SAFETY: the caller MUST hold the cross-isolate decrypt lease
/// (`AppDb.acquireDecryptLease`) around [applyWires]. The lease is what keeps
/// this isolate the sole writer into the ratchet while the main isolate is
/// asleep (TZ_BG_DECRYPT_2026-07-23, Б-1). This function does not take it
/// itself because the caller also owns building the runtime the decrypt needs.
class BackgroundInboundProcessor {
  const BackgroundInboundProcessor._();

  /// Сколько подтверждений отсылаем за один проход.
  ///
  /// 🔴 БЮДЖЕТ ПРОХОДА 12 СЕКУНД, и в поле он уже не всегда выдерживается (два
  /// `push.bg_fetch_timeout` в замере 11.08). Каждое подтверждение — это подпись
  /// и сетевой запрос. Что не влезло, уходит в очередь `pending_acks` и
  /// досылается следующим проходом или передним планом.
  static const int maxAcksPerPass = 24;

  static Future<BackgroundInboundResult> applyWires({
    required AppDb db,
    required List<BackgroundInboundWire> wires,
    required Future<bool> Function({
      required String msgId,
      required String ciphertextB64,
    }) decrypt,
    required int nowMs,
    /// Подтверждает приём реле. Возвращает `true`, если реле подтвердило.
    ///
    /// `null` — не подтверждать вовсе (прежнее поведение).
    Future<bool> Function({required int seq, required String msgId})? ack,
  }) async {
    var applied = 0;
    var staged = 0;
    var skipped = 0;
    // 🔴 СЧИТАТЬ НАДО ДОШЕДШИЕ, А НЕ ПОПЫТКИ. Прежний счётчик рос ДО отправки,
    // и 11.08 показал мне «acked=10» при нуле принятых реле — я счёл правку
    // проверенной, а она не работала вовсе. Замер обязан уметь провалиться.
    var acksSent = 0;
    var acksAttempted = 0;

    /// 🔴 ПОДТВЕРЖДЕНИЕ — ЭТО РАЗРЕШЕНИЕ РЕЛЕ ЗАБЫТЬ СООБЩЕНИЕ.
    ///
    /// Поэтому зовётся ТОЛЬКО для того, что действительно применено или было
    /// применено раньше. Для сложенного в карантин — никогда: там сообщение ещё
    /// не разобрано, и «забудь» означало бы потерю.
    Future<void> ackApplied(int? seq, String msgId) async {
      if (ack == null || seq == null || seq < 0) return;
      if (acksAttempted >= maxAcksPerPass) return;
      acksAttempted++;
      var ok = false;
      try {
        ok = await ack(seq: seq, msgId: msgId);
      } catch (_) {
        // Отказ подписи на заблокированном телефоне, обрыв сети, что угодно.
        // Молчим: неподтверждённое сообщение реле пришлёт снова, и это
        // безопасная сторона отказа.
        ok = false;
      }
      if (ok) {
        acksSent++;
        return;
      }
      // Не дошло — паркуем, как это делает главный изолят, иначе разовый сбой
      // сети превращается в вечный повтор.
      try {
        await db.pendingAckUpsert(msgId: msgId, seq: seq, nowMs: nowMs);
      } catch (_) {
        // best-effort: реле всё равно пришлёт снова
      }
    }

    for (final w in wires) {
      final msgId = w.msgId.trim();
      final cipher = w.ciphertextB64;
      if (msgId.isEmpty || cipher.isEmpty) continue;

      // Already applied on a previous pass (or by the foreground): the seen set
      // is the cross-pass dedup, so a redelivered wire never double-notifies.
      if (await db.inboxHasSeen(msgId)) {
        skipped++;
        // 🔴 ПРОПУЩЕННОЕ ПОДТВЕРЖДАТЬ ОБЯЗАТЕЛЬНО. Это уже применённое ранее
        // сообщение, которое реле всё ещё держит: замер 11.08 показал
        // `applied=0 skipped=7` — семь штук висели в ящике, будучи давно
        // применёнными. Без этого они не уйдут оттуда никогда.
        await ackApplied(w.seq, msgId);
        continue;
      }

      bool ok = false;
      try {
        ok = await decrypt(msgId: msgId, ciphertextB64: cipher);
      } catch (_) {
        // A decrypt that throws is treated as not-applied: the wire is parked,
        // never dropped. Same fail-closed posture as the foreground drain.
        ok = false;
      }

      if (ok) {
        // Mirror what the transport does after a successful apply: mark seen so
        // neither the next background pass nor the foreground re-processes it.
        // Раньше здесь стояло допущение «реле всё ещё держит строку, и
        // подтвердит следующий насос переднего плана». Верно — но только когда
        // человек ОТКРОЕТ приложение. До тех пор конверт висит в ящике.
        await db.inboxMarkSeen(msgId);
        applied++;
        // Подтверждаем СРАЗУ, а не пачкой в конце: проход обрывается по
        // таймауту, и подтверждение в конце отрезало бы ровно этот шаг.
        await ackApplied(w.seq, msgId);
      } else {
        // Could not decrypt right now (session not ready, out-of-order, a
        // genuine failure). Park the ciphertext exactly as the download-only
        // path did before, so the foreground's recovery machinery — session
        // reset, NACK, replay — takes over on its next wake. No ack, so the
        // relay keeps re-offering it until it truly lands.
        try {
          await db.inboxQuarantineUpsert(
            attestedFromDeviceId: AttestedSenders.lookup(msgId),
            msgId: msgId,
            senderDeviceId: null,
            ciphertextB64: cipher,
            nowMs: nowMs,
          );
          staged++;
        } catch (_) {
          // best-effort: if even staging fails the relay still redelivers.
        }
      }
    }

    // acksAttempted в условии: проход, где всё уже применено раньше
    // (applied=0 staged=0 skipped=8), в поле встречается ЧАЩЕ прочих — именно
    // он вычищает залежавшийся ящик, и он же был не виден в журнале.
    if (applied > 0 || staged > 0 || acksAttempted > 0) {
      DiagLog.event('push', 'bg_decrypt_pass', {
        'applied': applied,
        'staged': staged,
        'skipped': skipped,
        'acked': acksSent,
        'ack_fail': acksAttempted - acksSent,
      });
    }
    return BackgroundInboundResult(
      applied: applied,
      staged: staged,
      skipped: skipped,
      acked: acksSent,
      ackFailed: acksAttempted - acksSent,
    );
  }
}
