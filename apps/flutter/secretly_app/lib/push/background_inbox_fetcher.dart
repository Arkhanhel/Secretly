// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/diag_log.dart';
import '../security/auth_signer.dart';
import '../security/device_keys.dart';
import '../security/secure_secrets.dart';
import '../storage/app_db.dart';
import 'background_decrypt.dart';
import '../transport/resilient_http_client.dart';
import '../version/app_package_info.dart';
import 'background_worker.dart';
import '../transport/attested_senders.dart';
import '../transport/server_clock.dart';
import 'clock_retry.dart';

/// BACKGROUND DRAIN (2026-07-16, delivery-wake audit, client P0).
///
/// The FCM/APNs background handler used to only write a SharedPreferences
/// "wake hint" — the message body was fetched no earlier than the next
/// foreground open. This fetcher runs INSIDE the push-wake execution window
/// (~10-20s on Android high-priority FCM, ~30s on iOS content-available) and
/// stages the pending mailbox locally so that opening the app shows the
/// messages instantly — even with no network at that moment (elevator,
/// basement): "зашёл в приложение — и всё уже там".
///
/// Design: DECRYPT-AND-APPLY when it is safe to, STAGE otherwise
/// (TZ_BG_DECRYPT_2026-07-23). Originally this isolate only staged ciphertext,
/// which meant nothing was shown until the app was next opened by hand — on a
/// phone the OS keeps killed, that was hours of "notifications but no messages".
///   * It now DECRYPTS via [BackgroundDecrypt], which runs the real delivery
///     path (`_handleDelivered`) under the cross-isolate decrypt lease, then
///     persists and posts a notification with the decrypted preview.
///   * The Double Ratchet must have exactly ONE writer at a time. That is the
///     lease: the foreground holds it while alive, so this isolate cannot take
///     it until the app has been dead long enough to expire it; and the pass
///     re-checks the main-isolate heartbeat under the lease, so a foreground
///     that woke mid-fetch makes it yield. The clobber race that caused the
///     2026-07-08 message loss is thus structurally excluded, not merely
///     avoided by timing.
///   * On ANY obstacle — lease busy, no keys-URL snapshot yet, any error — it
///     falls back to the old STAGE path (`inboxQuarantineUpsert`), whose replay
///     driver applies rows idempotently on the next foreground open. So the
///     change can only ADD delivery and never removes the safety net.
///   * A staged (not decrypted) row is left un-acked so the relay redelivers
///     it; a decrypted row is marked seen so neither the next pass nor the
///     foreground re-processes it. Nothing is dropped, nothing is reordered.
///
/// Concurrency safety:
///   * Skipped entirely while the main isolate is provably alive (heartbeat
///     pref, see [prefsMainIsolateAliveAtMsKey]) — a live app drains itself.
///   * The DB is WAL with busy_timeout=7000; the lease is the logical guard on
///     top of that file-level serialization.
///   * The DB passphrase is read STRICTLY read-only
///     ([SecureSecrets.readDbPassphraseIfExists]) — a glitching keystore read
///     in the background must never rotate/delete the main app's passphrase.
class BackgroundInboxFetcher {
  BackgroundInboxFetcher._();

  /// Written by the main isolate whenever relay endpoints are (re)resolved —
  /// including per-profile server-binding overrides that a dart-define
  /// constant would miss.
  static const String prefsBaseUrlKey = 'bg_fetch_relay_http_base_url';
  // Keys-server base URL, so the background isolate can build the ratchet's
  // KeysClient (TZ_BG_DECRYPT_2026-07-23). A decrypt-only pass does not call the
  // keys network, but the client must point somewhere real, not a placeholder.
  static const String prefsKeysBaseUrlKey = 'bg_fetch_keys_http_base_url';

  /// Heartbeat stamped by the main isolate's pump timer (throttled). Fresh
  /// value ⇒ the main isolate owns draining and this fetcher stands down.
  static const String prefsMainIsolateAliveAtMsKey = 'main_isolate_alive_at_ms';

  /// Fresh-enough window for the heartbeat. The main-isolate stamp is written
  /// at least every ~10s while it is actually running (foreground or alive
  /// background), so 25s of silence ⇒ it is dead or frozen and cannot drain.
  static const int mainIsolateFreshMs = 25000;

  static const Duration _overallBudget = Duration(seconds: 12);
  static const Duration _httpTimeout = Duration(seconds: 8);

  /// Таймаут повтора после отказа по времени. Ожидание главного изолята
  /// оставляет на работу [_workReserve] (7 с): первый отказ укладывается в 3 с
  /// (`sendSignedWithClockRetry`), повтор — в 4.
  static const Duration _retryHttpTimeout = Duration(seconds: 4);
  static const int _fetchLimit = 200;

  /// Entry point for the push background handler. Never throws; never runs
  /// longer than [_overallBudget].
  static Future<void> runFromPushWake() async {
    try {
      final outcome = await _run().timeout(_overallBudget);
      DiagLog.event('push', 'bg_fetch_done', {'outcome': outcome});
    } on TimeoutException {
      DiagLog.event('push', 'bg_fetch_timeout', const {});
    } catch (e) {
      DiagLog.event('push', 'bg_fetch_failed', {
        'err_type': '${e.runtimeType}',
      });
    }
  }

  /// Test-only window onto [_run]'s outcome codes (guards are pure prefs
  /// logic and must stay covered without plugin mocks).
  @visibleForTesting
  static Future<String> debugRunForTest() => _run();

  /// Сколько оставляем прохода на саму работу после ожидания.
  ///
  /// Бюджет прохода 12 секунд, и в поле он уже не всегда выдерживается. Ждать
  /// дольше — значит успеть дождаться и не успеть забрать, то есть поменять
  /// одну неудачу на другую.
  static const Duration _workReserve = Duration(seconds: 7);

  /// Ждёт, пока отметка «главный изолят жив» протухнет.
  ///
  /// Возвращает `true`, если главного больше нет и работать можно.
  ///
  /// 🔴 ПОСЛЕ ОЖИДАНИЯ ОТМЕТКА ПЕРЕЧИТЫВАЕТСЯ. Если главный за это время подал
  /// признак жизни — уступаем, как и раньше. Иначе мы бы дождались протухания,
  /// которого уже нет, и полезли в ратчет вторым писателем.
  static Future<bool> _awaitMainIsolateStandDown(SharedPreferences prefs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final aliveAt = prefs.getInt(prefsMainIsolateAliveAtMsKey) ?? 0;
    final ageMs = now - aliveAt;
    if (ageMs >= mainIsolateFreshMs) return true;

    // Сколько отметке осталось жить, плюс небольшой запас на разъезд часов.
    final remainingMs = mainIsolateFreshMs - ageMs + 500;
    final budgetMs = _overallBudget.inMilliseconds - _workReserve.inMilliseconds;
    if (remainingMs > budgetMs) {
      // Не влезает: уступаем как раньше. Ждать дольше бюджета бессмысленно —
      // проход всё равно оборвут, и мы потеряем ещё и время на работу.
      //
      // 🔴 НО УСТУПАЕМ НЕ В ПУСТОТУ. Заказываем один проход на момент, когда
      // отметка протухнет. Без этого именно здесь сообщения и оставались
      // лежать: пуши кончались раньше, чем истекала живость.
      DiagLog.event('push', 'bg_fetch_skip_main_alive', {
        'age_ms': ageMs,
        'need_ms': remainingMs,
      });
      await BackgroundWorker.scheduleStandDownRetry(
        prefs: prefs,
        delay: Duration(milliseconds: remainingMs + 2000),
      );
      return false;
    }

    DiagLog.event('push', 'bg_wait_main_standdown', {
      'age_ms': ageMs,
      'wait_ms': remainingMs,
    });
    await Future<void>.delayed(Duration(milliseconds: remainingMs));

    try {
      await prefs.reload();
    } catch (_) {}
    final afterNow = DateTime.now().millisecondsSinceEpoch;
    final afterAlive = prefs.getInt(prefsMainIsolateAliveAtMsKey) ?? 0;
    final afterAge = afterNow - afterAlive;
    if (afterAge < mainIsolateFreshMs) {
      // Главный ожил, пока мы ждали. Это удача, а не потеря: он и вычерпает.
      DiagLog.event('push', 'bg_wait_main_revived', {'age_ms': afterAge});
      return false;
    }
    return true;
  }

  static Future<String> _run() async {
    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences caches per isolate; make sure we read the MAIN
    // isolate's latest heartbeat/config, not a stale snapshot.
    try {
      await prefs.reload();
    } catch (_) {}

    // 🔴 УСТУПАЯ — ПОДОЖДАТЬ, А НЕ БРОСИТЬ (12.08.2026).
    //
    // Замер: главный изолят замёрз в 00:59:42, пуши пришли на 13-й, 17-й и 22-й
    // секунде — все внутри окна живости в 25 с, и проход трижды ушёл ни с чем.
    // На 25-й секунде отметка протухла, но будить стало НЕЧЕМ: пуши кончились, а
    // дедуп реле не даст разбудить теми же конвертами. Сообщения пролежали
    // четыре минуты и разобрались лишь когда переотправка отправителя создала
    // новые конверты.
    //
    // Сама уступка ПРАВИЛЬНА и остаётся: за время выборки человек может открыть
    // приложение, и тогда ратчет тронет главный изолят. Мы чиним не право, а то,
    // что уступка ничем не заканчивалась.
    //
    // Ждать надо не фиксированные 25 секунд, а СКОЛЬКО ОСТАЛОСЬ отметке жить:
    // она обновляется раз в 10 с, поэтому её возраст в момент пуша — случайная
    // величина, и в замере не хватало всего 3–12 секунд.
    final waited = await _awaitMainIsolateStandDown(prefs);
    if (!waited) return 'skip_main_alive';

    final baseRaw = (prefs.getString(prefsBaseUrlKey) ?? '').trim();
    final deviceId = (prefs.getString('device_id') ?? '').trim();
    final profileId = (prefs.getString('profile_id') ?? '').trim();
    if (baseRaw.isEmpty || deviceId.isEmpty || profileId.isEmpty) {
      DiagLog.event('push', 'bg_fetch_skip_unconfigured', {
        'has_base': baseRaw.isNotEmpty,
        'has_dev': deviceId.isNotEmpty,
      });
      return 'skip_unconfigured';
    }
    final base = Uri.tryParse(baseRaw);
    if (base == null) return 'skip_bad_base_url';
    final fromSeq = prefs.getInt('relay_next_seq') ?? 1;

    // Authed GET /v1/pending — same signature scheme as the main pump. The
    // relay MIN-clamps from_seq, so even a stale cursor returns every unacked
    // row.
    final identityKeyPair = await DeviceKeys.create().loadIdentityKeyPair(
      profileId: profileId,
      deviceId: deviceId,
    );
    List<Map<String, dynamic>> items;
    final client = createResilientHttpClient();
    try {
      final uri = base.resolve(
        '/v1/pending/$deviceId?from_seq=$fromSeq&limit=$_fetchLimit',
      );
      // Поправка часов в этом изоляте стартует с нуля: при отказе по времени
      // запрос подписывается заново и уходит ещё раз (sendSignedWithClockRetry).
      final resp = await sendSignedWithClockRetry((tsMs, isRetry) async {
        final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
        final sigB64 = await AuthSigner.signEd25519B64(
          identityKeyPair: identityKeyPair,
          message: AuthSigner.relayHttpPendingMessage(
            deviceId: deviceId,
            fromSeq: fromSeq,
            limit: _fetchLimit,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
        );
        return client
            .get(
              uri,
              headers: {
                'x-secretly-device-id': deviceId,
                'x-secretly-ts-ms': tsMs.toString(),
                'x-secretly-nonce-b64': nonceB64,
                'x-secretly-signature-b64': sigB64,
                // 🔴 Номер сборки для замера раскатки. Фоновый изолят собирает
                // заголовки вручную и не проходит через _signedRelayHeaders, из-за
                // чего устройства, живущие в фоне, в замер не попадали вовсе.
                if (AppPackageInfo.buildNumberFromEnv.isNotEmpty)
                  'x-secretly-client-build': AppPackageInfo.buildNumberFromEnv,
              },
            )
            .timeout(isRetry ? _retryHttpTimeout : _httpTimeout);
      });
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        DiagLog.event('push', 'bg_fetch_http_status', {
          'status': resp.statusCode,
        });
        return 'http_${resp.statusCode}';
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      items = (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      // ИД-1 / С-1: the relay's word on who sent each wire, for the
      // background decrypt in this isolate and for the park below.
      for (final it in items) {
        AttestedSenders.record(it['msg_id'] as String?, it['from_device_id']);
      }
    } catch (_) {
      client.close();
      rethrow;
    }
    // 🔴 КЛИЕНТ ЗАКРЫВАТЬ ЗДЕСЬ НЕЛЬЗЯ. Ниже им же уходят подтверждения, и
    // закрытие в этом месте (12.08.2026) обесценивало их ВСЕ: каждый POST падал
    // мгновенно на «клиент уже закрыт», ящик реле не пустел, и реле бесконечно
    // будило телефон по тем же самым конвертам. Замер: 0 принятых подтверждений
    // у устройства при seq, выросшем с 271 до 285.
    if (items.isEmpty) {
      client.close();
      return 'empty';
    }

    // Stage ciphertexts. Passphrase strictly read-only: no key present (fresh
    // install pre-registration, keystore hiccup) ⇒ skip silently.
    final dbPass = await SecureSecrets.create().readDbPassphraseIfExists();
    if (dbPass == null) {
      client.close();
      DiagLog.event('push', 'bg_fetch_skip_no_passphrase', const {});
      return 'skip_no_passphrase';
    }
    final AppDb db;
    try {
      db = await AppDb.open(passphrase: dbPass);
    } catch (_) {
      client.close();
      rethrow;
    }
    try {
      // TZ_BG_DECRYPT_2026-07-23: try to DECRYPT here, so the message shows the
      // moment it arrives instead of waiting for the user to open the app. The
      // decrypt pass takes the cross-isolate lease and falls back to staging on
      // any obstacle (lease busy = main isolate active, no keys URL yet, error),
      // so it can only ADD delivery over the old download-only behaviour.
      final keysBaseRaw = (prefs.getString(prefsKeysBaseUrlKey) ?? '').trim();
      // 🔴 ПОДТВЕРЖДЕНИЕ ИЗ ФОНА (12.08.2026).
      //
      // Раньше фоновый проход применял сообщение и не говорил об этом реле:
      // в комментарии стояло допущение «подтвердит следующий насос переднего
      // плана». Верно — но только когда человек ОТКРОЕТ приложение. До тех пор
      // конверт висит в ящике реле (замер 11.08: остаток 6 → 7 → 7 → 7, ноль
      // подтверждений за 25 минут).
      //
      // Подписываем тем же ключом и той же схемой, что и выборку выше.
      Future<bool> ackOne({required int seq, required String msgId}) async {
        try {
          // Время сервера, как у выборки выше: сырое время устройства со
          // сбитыми часами делало КАЖДОЕ фоновое подтверждение недействительным,
          // и реле снова будило телефон по тем же конвертам.
          final ackTsMs = ServerClock.instance.nowMs();
          final ackNonceB64 = AuthSigner.randomNonceB64(bytes: 16);
          final ackSigB64 = await AuthSigner.signEd25519B64(
            identityKeyPair: identityKeyPair,
            message: AuthSigner.relayHttpAckMessage(
              deviceId: deviceId,
              seq: seq,
              tsMs: ackTsMs,
              nonceB64: ackNonceB64,
            ),
          );
          final resp = await client
              .post(
                base.resolve('/v1/ack'),
                headers: <String, String>{
                  'content-type': 'application/json',
                  'x-secretly-device-id': deviceId,
                  'x-secretly-ts-ms': ackTsMs.toString(),
                  'x-secretly-nonce-b64': ackNonceB64,
                  'x-secretly-signature-b64': ackSigB64,
                  if (AppPackageInfo.buildNumberFromEnv.isNotEmpty)
                    'x-secretly-client-build':
                        AppPackageInfo.buildNumberFromEnv,
                },
                body: jsonEncode(<String, Object?>{
                  'device_id': deviceId,
                  'seq': seq,
                  'msg_id': msgId,
                }),
              )
              .timeout(const Duration(seconds: 4));
          return resp.statusCode >= 200 && resp.statusCode < 300;
        } catch (_) {
          // Отказ подписи на заблокированном телефоне, обрыв сети, таймаут.
          // Вызывающий положит подтверждение в очередь; реле пришлёт снова.
          return false;
        }
      }

      final decrypted = await BackgroundDecrypt.run(
        db: db,
        prefs: prefs,
        profileId: profileId,
        deviceId: deviceId,
        keysBaseUrlRaw: keysBaseRaw,
        items: items,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        ack: ackOne,
      );
      if (decrypted != null) {
        DiagLog.event('push', 'bg_fetch_decrypted', {
          'applied': decrypted.applied,
          'staged': decrypted.staged,
          'skipped': decrypted.skipped,
          'from_seq': fromSeq,
        });
        return 'decrypted_${decrypted.applied}_staged_${decrypted.staged}';
      }

      // Fallback: the download-only path. Stage ciphertext for the foreground to
      // decrypt on its next wake — unchanged from before background decrypt.
      var staged = 0;
      for (final it in items) {
        final msgId = (it['msg_id'] as String?)?.trim() ?? '';
        final ciphertextB64 = it['ciphertext_b64'] as String? ?? '';
        if (msgId.isEmpty || ciphertextB64.isEmpty) continue;
        if (await db.inboxHasSeen(msgId)) continue;
        await db.inboxQuarantineUpsert(
          attestedFromDeviceId: it['from_device_id'] as String?,
          msgId: msgId,
          senderDeviceId: null,
          ciphertextB64: ciphertextB64,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
        staged++;
      }
      DiagLog.event('push', 'bg_fetch_staged', {
        'staged': staged,
        'fetched': items.length,
        'from_seq': fromSeq,
      });
      return 'staged_$staged';
    } finally {
      client.close();
      await db.close();
    }
  }
}
