// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_controller.dart';
import '../crypto/crypto_factory.dart';
import '../security/secure_secrets.dart';
import '../diagnostics/diag_log.dart';
import '../ratchet/session_manager_v3.dart';
import '../security/device_keys.dart';
import '../storage/app_db.dart';
import '../transport/keys_client.dart';
import 'background_inbound_processor.dart';
import 'background_inbox_fetcher.dart';

/// Glue that lets the background inbox isolate DECRYPT what it fetches instead
/// of only staging ciphertext (TZ_BG_DECRYPT_2026-07-23). Lives in its own file
/// so the fetcher does not import AppController directly — AppController already
/// imports the fetcher for its pref keys, and a mutual import is a smell.
///
/// The cross-isolate lease is taken HERE, around the whole pass: it is what
/// makes this isolate the sole ratchet writer while the main isolate sleeps.
/// Every obstacle — no keys URL yet, lease busy (main is active), any error —
/// returns null, and the caller falls back to the old download-only staging,
/// so this can only ADD delivery, never remove the safety net.
class BackgroundDecrypt {
  const BackgroundDecrypt._();

  static const String _leaseHolder = 'bg-inbox';
  static const int _leaseTtlMs = 2 * 60 * 1000;

  /// Attempt an in-background decrypt pass over [items] (relay `/v1/pending`
  /// rows: `{msg_id, ciphertext_b64}`). Returns a short status string on a real
  /// attempt, or null when the caller should stage instead.
  static Future<BackgroundInboundResult?> run({
    required AppDb db,
    required SharedPreferences prefs,
    required String profileId,
    required String deviceId,
    required String keysBaseUrlRaw,
    required List<Map<String, dynamic>> items,
    required int nowMs,
    /// Подтверждает приём реле. `null` — не подтверждать (прежнее поведение).
    Future<bool> Function({required int seq, required String msgId})? ack,
  }) async {
    final keysBase = Uri.tryParse(keysBaseUrlRaw.trim());
    if (keysBase == null || !keysBase.hasScheme) {
      // No keys-URL snapshot yet (first run before the foreground wrote it).
      return null;
    }

    // Sole-writer guarantee. If the main isolate — or another background pass —
    // holds the lease, do not touch the ratchet; stage instead.
    final gotLease = await db.acquireDecryptLease(
      holder: _leaseHolder,
      nowMs: nowMs,
      ttlMs: _leaseTtlMs,
    );
    if (!gotLease) {
      DiagLog.event('push', 'bg_decrypt_lease_busy', const {});
      return null;
    }

    // Re-check the main-isolate heartbeat UNDER the lease. The fetch that got us
    // here can take seconds, during which the app may have been opened; if the
    // foreground came alive in that gap it is about to write the ratchet, so we
    // must not. This closes the "foreground woke while I was fetching" window;
    // the foreground closes the mirror window by waiting on this lease.
    try {
      await prefs.reload();
    } catch (_) {}
    final aliveAt =
        prefs.getInt(BackgroundInboxFetcher.prefsMainIsolateAliveAtMsKey) ?? 0;
    if (nowMs - aliveAt < BackgroundInboxFetcher.mainIsolateFreshMs) {
      await db.releaseDecryptLease(_leaseHolder);
      DiagLog.event('push', 'bg_decrypt_yield_main_alive', const {});
      return null;
    }

    try {
      // F-CONTENTKEY-2 (2026-07-31): read-only, and a miss ABORTS the pass.
      //
      // This isolate is woken by a push, which routinely means a locked device
      // — precisely when the keychain reports a perfectly good item as missing.
      // Going through get-or-create here could mint a fresh content key and
      // orphan every local copy the main app had written. There is nothing to
      // gain by continuing without the key either: the pass would decrypt the
      // wire and then be unable to store the plaintext.
      final contentKey = await SecureSecrets.create().readCryptoKeyIfExists();
      if (contentKey == null) {
        // The lease is released by this method's `finally`, unlike the early
        // returns above, which sit outside the try.
        DiagLog.event('push', 'bg_decrypt_no_content_key', const {});
        return null;
      }
      final crypto = CryptoFactory.fromKey(contentKey);
      final keysClient = KeysClient(baseUrl: keysBase);
      final ratchet = RatchetSessionManagerV3(
        db: db,
        deviceKeys: DeviceKeys.create(),
        keysClient: keysClient,
        // fetchBundleAuthed omitted: a decrypt-only pass never initiates a
        // session, so it never fetches a peer bundle. Foreground owns sending.
      );
      final controller = AppController();
      await controller.bootstrapForBackgroundInbound(
        db: db,
        crypto: crypto,
        ratchetV3: ratchet,
        keys: keysClient,
        prefs: prefs,
        profileId: profileId,
        deviceId: deviceId,
      );

      final wires = <BackgroundInboundWire>[
        for (final it in items)
          BackgroundInboundWire(
            msgId: (it['msg_id'] as String?)?.trim() ?? '',
            ciphertextB64: it['ciphertext_b64'] as String? ?? '',
            // Номер из ответа реле. Раньше терялся здесь, и подтвердить приём
            // было нечем: он входит в подписываемое сообщение.
            seq: (it['seq'] as num?)?.toInt(),
          ),
      ];

      // No controller.dispose(): it would tear down the shared db handle the
      // caller still closes in its own finally, and this isolate is thrown away
      // the moment the pass returns.
      return await BackgroundInboundProcessor.applyWires(
        db: db,
        wires: wires,
        decrypt: controller.handleDeliveredInBackground,
        ack: ack,
        nowMs: nowMs,
      );
    } catch (e) {
      DiagLog.event('push', 'bg_decrypt_error', {'err': e.runtimeType.toString()});
      return null; // caller stages everything as before
    } finally {
      await db.releaseDecryptLease(_leaseHolder);
    }
  }
}
