// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../diagnostics/diag_log.dart';
import '../security/auth_signer.dart';
import '../security/device_keys.dart';
import '../security/secure_secrets.dart';
import '../storage/app_db.dart';
import '../transport/relay_protocol.dart' show isOnlineOnlyOutboxRow;
import '../transport/resilient_http_client.dart';
import 'background_inbox_fetcher.dart';
import 'clock_retry.dart';

/// ANDROID DELIVERY RELIABILITY (2026-07-17): a periodic WorkManager task that
/// runs even when the app is backgrounded / Doze-frozen / killed (but not
/// force-stopped by an OEM). It is the safety net that closes the two
/// "phone-asleep" gaps FCM alone can't:
///   * SEND: the outbox pump is a Dart timer that Doze freezes, so a message
///     that didn't leave immediately (network blip, screen off) sat on the
///     sender's phone until it next woke (proven in prod: batches on wake).
///     Here we flush ALREADY-ENCRYPTED outbox rows to the relay.
///   * RECEIVE: a top-up fetch in case a high-priority FCM wake was dropped
///     (quota) — reuses the inbound fetcher.
///
/// ZERO-DUPLICATE by construction:
///   * SEND re-uses the SAME msg_id already in the outbox row. The relay
///     dedups on UNIQUE(device_id, msg_id) and the recipient on inbox_seen, so
///     even if the foreground pump and this task both send a row, the recipient
///     sees it once. We never re-encrypt (no ratchet in this isolate) — the
///     ciphertext is verbatim, so the wire bytes are identical.
///   * RECEIVE stages into quarantine (dedup by msg_id) — same as the FCM
///     fetcher.
///   * A main-isolate liveness gate skips the whole task when the foreground
///     app is active, so the two never race in the first place.
///
/// iOS uses the NSE instead (this task is registered on Android only).
class BackgroundWorker {
  BackgroundWorker._();

  static const String periodicTaskName = 'secretly_bg_sync_v1';
  static const String _periodicUniqueName = 'secretly_bg_sync_v1_unique';

  /// Register the periodic task. Android minimum interval is 15 minutes.
  static Future<void> ensureRegistered() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().initialize(
        _callbackDispatcher,
        isInDebugMode: false,
      );
      await Workmanager().registerPeriodicTask(
        _periodicUniqueName,
        periodicTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
    } catch (_) {
      // Non-fatal: FCM + the foreground pump remain the primary paths.
    }
  }

  /// Уникальное имя отложенного повтора. Одно на всё приложение — этим пачка
  /// пробуждений схлопывается в ОДИН повтор, а не в десять.
  static const String _standDownRetryUniqueName = 'secretly_bg_standdown_v1';
  static const String _standDownRetryLastAtMsKey = 'bg_standdown_retry_at_ms';

  /// Не чаще одного заказа в минуту на всё приложение.
  static const int standDownRetryMinIntervalMs = 60 * 1000;

  /// Чистое решение ограничителя — вынесено, чтобы его можно было проверить
  /// тестом: сама [scheduleStandDownRetry] за платформенной защитой и на
  /// настольном прогоне не выполняется.
  static bool shouldScheduleStandDownRetry({
    required int lastAtMs,
    required int nowMs,
  }) =>
      nowMs - lastAtMs >= standDownRetryMinIntervalMs;

  /// Заказать один повторный проход через [delay].
  ///
  /// 🔴 ЗАЧЕМ. Фоновый проход уступает главному изоляту, пока отметка живости
  /// свежа. Если главный ЗАМЁРЗ (не закрылся — именно замёрз), отметка ещё
  /// какое-то время выглядит свежей, проход уходит ни с чем, а к моменту её
  /// протухания будить уже нечем: пуши кончились, и дедуп реле не даст
  /// разбудить теми же конвертами. Замер 12.08.2026: смс пролежали четыре
  /// минуты и разобрались лишь потому, что отправитель создал новые конверты.
  ///
  /// Тело повтора — тот же [_run], со своей задвижкой по живости. Если главный
  /// к тому времени вернулся, повтор просто ничего не сделает.
  ///
  /// ⚠️ Срок НЕ гарантирован: в Doze система вправе отложить работу до своего
  /// окна. Это страховка, а не расписание — основным путём остаётся пуш.
  ///
  /// 🔴 ОГРАНИЧИТЕЛЬ ОБЯЗАТЕЛЕН. Уступка случается и при честно открытом
  /// приложении: у живого главного изолята отметка всегда свежа. Без предела
  /// каждый пуш в активной переписке заказывал бы работу, а Android за частые
  /// заказы душит планировщик целиком — и первой пострадала бы уже работающая
  /// 15-минутная страховка. Лечение не должно съесть то, что уже лечит.
  static Future<void> scheduleStandDownRetry({
    required SharedPreferences prefs,
    required Duration delay,
  }) async {
    if (!Platform.isAndroid) return; // на iOS этот путь — нативный NSE
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastAt = prefs.getInt(_standDownRetryLastAtMsKey) ?? 0;
    if (!shouldScheduleStandDownRetry(lastAtMs: lastAt, nowMs: now)) return;
    try {
      await prefs.setInt(_standDownRetryLastAtMsKey, now);
    } catch (_) {}
    try {
      await Workmanager().registerOneOffTask(
        _standDownRetryUniqueName,
        periodicTaskName,
        initialDelay: delay,
        constraints: Constraints(networkType: NetworkType.connected),
        // keep, а НЕ replace: replace отодвигал бы срок с каждым новым пушем,
        // и пачка пробуждений откладывала бы повтор бесконечно.
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
      DiagLog.event('push', 'bg_standdown_retry_scheduled', {
        'delay_ms': delay.inMilliseconds,
      });
    } catch (_) {
      // Плагин мог не подняться в чужом изоляте. Тогда мы просто там же, где
      // были до этой правки, — хуже не становится.
    }
  }

  /// The whole task body, exposed for the headless entry point. Never throws.
  static Future<bool> _run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}

      final now = DateTime.now().millisecondsSinceEpoch;
      final aliveAt =
          prefs.getInt(BackgroundInboxFetcher.prefsMainIsolateAliveAtMsKey) ?? 0;
      if (now - aliveAt < BackgroundInboxFetcher.mainIsolateFreshMs) {
        // Foreground app is active — it owns both drain and outbox flush.
        return true;
      }

      // RECEIVE top-up (idempotent; skips itself if main alive too).
      try {
        await BackgroundInboxFetcher.runFromPushWake();
      } catch (_) {}

      // SEND flush of already-encrypted outbox rows.
      await _flushOutbox(prefs);
      return true;
    } catch (_) {
      return true; // never signal a retry storm; the next tick retries
    }
  }

  /// Send every due, already-encrypted outbox row to the relay over HTTP.
  /// Verbatim ciphertext + existing msg_id → the relay dedups, so this can
  /// never duplicate a message the foreground pump also sent. Marks rows sent
  /// on a 2xx (or on a relay dedup, which is also a success).
  static Future<void> _flushOutbox(SharedPreferences prefs) async {
    final baseRaw =
        (prefs.getString(BackgroundInboxFetcher.prefsBaseUrlKey) ?? '').trim();
    final deviceId = (prefs.getString('device_id') ?? '').trim();
    final profileId = (prefs.getString('profile_id') ?? '').trim();
    if (baseRaw.isEmpty || deviceId.isEmpty || profileId.isEmpty) return;
    final base = Uri.tryParse(baseRaw);
    if (base == null) return;

    final dbPass = await SecureSecrets.create().readDbPassphraseIfExists();
    if (dbPass == null) return;

    final identityKeyPair = await DeviceKeys.create().loadIdentityKeyPair(
      profileId: profileId,
      deviceId: deviceId,
    );

    final db = await AppDb.open(passphrase: dbPass);
    final client = createResilientHttpClient();
    var sent = 0;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Bounded, due, still-unsent rows. No lease/worker columns — this isolate
      // is gated to run only when the foreground app is NOT active.
      final rows = await db.rawQueryOutboxDueForBackground(nowMs: now, limit: 50);
      for (final row in rows) {
        final msgId = (row['msg_id'] as String?)?.trim() ?? '';
        final toDeviceId = (row['to_device_id'] as String?)?.trim() ?? '';
        final ciphertextB64 = (row['ciphertext_b64'] as String?) ?? '';
        if (msgId.isEmpty || toDeviceId.isEmpty || ciphertextB64.isEmpty) {
          continue;
        }
        final ttlSeconds = (row['ttl_seconds'] as num?)?.toInt() ?? 604800;
        final transportMetaJson = row['transport_meta_json'] as String?;
        final deliverAtMs = (row['deliver_at_ms'] as num?)?.toInt() ?? 0;

        try {
          // Отказ по времени (поправка в изоляте стартует с нуля) — один
          // повтор с поправкой из ответа, см. sendSignedWithClockRetry.
          final resp = await sendSignedWithClockRetry((tsMs, _) async {
            final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
            final msg = AuthSigner.relayHttpSendMessage(
              fromDeviceId: deviceId,
              toDeviceId: toDeviceId,
              msgId: msgId,
              ciphertextB64: ciphertextB64,
              ttlSeconds: ttlSeconds,
              transportMetaJson: transportMetaJson,
              tsMs: tsMs,
              nonceB64: nonceB64,
            );
            final sigB64 = await AuthSigner.signEd25519B64(
              identityKeyPair: identityKeyPair,
              message: msg,
            );
            return client
                .post(
                  base.resolve('/v1/send'),
                  headers: {
                    'content-type': 'application/json',
                    'x-secretly-device-id': deviceId,
                    'x-secretly-ts-ms': tsMs.toString(),
                    'x-secretly-nonce-b64': nonceB64,
                    'x-secretly-signature-b64': sigB64,
                  },
                  body: jsonEncode({
                    'to_device_id': toDeviceId,
                    'msg_id': msgId,
                    'ciphertext_b64': ciphertextB64,
                    'ttl_seconds': ttlSeconds,
                    if (transportMetaJson != null &&
                        transportMetaJson.trim().isNotEmpty)
                      'transport_meta_json': transportMetaJson.trim(),
                    if (deliverAtMs > 0) 'deliver_at_ms': deliverAtMs,
                    // П-4: строка «только на связи» несёт поле и здесь.
                    if (isOnlineOnlyOutboxRow(row)) 'online_only': true,
                  }),
                )
                .timeout(const Duration(seconds: 8));
            // Задача WorkManager не зажата 12 секундами, как проход по пушу.
          }, retryOnlyWithin: const Duration(seconds: 8));
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            await db.outboxMarkSent(msgId);
            sent++;
          }
          // Non-2xx: leave the row for the foreground pump / next tick — never
          // mark failed here (avoid a background isolate exhausting retries).
        } catch (_) {
          // network error — leave the row; next tick retries
        }
      }
    } finally {
      client.close();
      await db.close();
    }
    if (sent > 0) {
      DiagLog.event('send', 'bg_outbox_flushed', {'sent': sent});
    }
  }
}

/// Headless entry point. MUST be a top-level function with the vm:entry-point
/// pragma so the WorkManager background isolate can find it.
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return BackgroundWorker._run();
  });
}
