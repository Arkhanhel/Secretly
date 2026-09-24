// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// EntitlementRepository (TZ-MONETIZE-01 §C-1, R1).
//
// Responsibilities in R1 (UI does NOT change yet):
//   * Resolve the server kill-switch from signed /v1/config.
//   * When monetization is OFF (default) → fully-open state (pre-freemium).
//   * When ON → fetch the owner-only signed entitlement blob, verify its
//     Ed25519 signature (when a public key is baked in), cache it, and apply a
//     7-day offline grace window if the service is unreachable.
//   * Call /v1/entitlements/legacy_claim exactly once after an update to
//     grandfather $5.99 buyers, then cache the result.
//
// Billing FAILS OPEN: any error resolving entitlements yields full access
// (TZ §0.4 / §6). Security features are never gated through this module.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../messages/identity_flags.dart';
import '../messages/reliability_flags.dart';
import '../messages/room_flags.dart';
import '../messages/support_flags.dart';
import '../security/auth_signer.dart';
import '../transport/keys_client.dart';
import 'entitlement_models.dart';
import 'entitlement_signature.dart';
import '../version/app_update_info.dart';
import '../messages/handshake_flags.dart';
import '../transport/server_clock.dart';

/// Supplies the requester device id and Ed25519 signatures for owner-only
/// entitlement requests. The app wires a concrete implementation backed by the
/// device identity key pair; tests inject a fake.
abstract class EntitlementSigner {
  String get deviceId;
  Future<String> signB64(List<int> message);
}

/// Minimal persistent key/value store (the app backs this with
/// flutter_secure_storage; tests use an in-memory map).
abstract class EntitlementCache {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// DEV/DEMO premium override, toggled ONLY by the [SECRETLY_FORCE_PREMIUM]
/// dart-define (default false). It works in ANY build mode so a FAST release
/// demo build can run with premium unlocked (a debug build lags badly under
/// JIT). It is safe by construction:
///   * The store build scripts (tools/macos_build_*_release.sh) NEVER set it,
///     so production store builds are unaffected.
///   * It only ever GRANTS access (raises entitlement to lifetime) — it never
///     locks or gates a feature, so a leak would be a revenue concern, never a
///     security one (security still fails CLOSED; this is an extreme fail-OPEN).
/// Enable for a demo build with:
///   --dart-define=SECRETLY_FORCE_PREMIUM=true
const bool _kForcePremiumEnv = bool.fromEnvironment('SECRETLY_FORCE_PREMIUM');
bool get _forcePremiumActive => _kForcePremiumEnv;

/// The lifetime-premium snapshot applied by the debug force-premium override:
/// monetization ON so the premium TIER/badge shows, paid tier so
/// `unlockEverything` is true, all features + premium size ceilings.
EntitlementState _debugForcedPremiumState() => const EntitlementState(
      monetizationEnabled: true,
      tier: EntitlementTier.lifetime,
      source: 'debug-force',
      features: EntitlementFeatures.all,
      limits: EntitlementLimits.premium,
      signatureVerified: true,
    );

class EntitlementRepository {
  EntitlementRepository({
    required KeysClient keysClient,
    required EntitlementSigner signer,
    required EntitlementCache cache,
    Future<bool> Function()? repairDeviceAuth,
    int Function()? nowMs,
  })  : _keys = keysClient,
        _signer = signer,
        _cache = cache,
        _repairDeviceAuth = repairDeviceAuth,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final KeysClient _keys;
  final EntitlementSigner _signer;
  final EntitlementCache _cache;

  /// Self-heals a keys DEVICE-AUTH 401 (a churned/unregistered `device_id` —
  /// e.g. after an iOS reinstall wiped SharedPreferences while the Keychain
  /// identity key survived). Re-registers the current device on the keys server
  /// and returns whether it succeeded; the caller then retries the request once.
  /// Injected by the app controller (`_repairKeysIdentityForSendOnce`), which
  /// owns the registration/publish flow. Null in tests that don't exercise it.
  final Future<bool> Function()? _repairDeviceAuth;

  final int Function() _nowMs;

  static const String cacheKey = 'secretly_entitlement_state_v1';
  static const String legacyClaimDoneKey = 'secretly_legacy_claim_done_v1';

  /// `source` marker for a bounded local premium grace applied when the STORE
  /// confirmed a purchase but OUR verify server could not credit it yet (billing
  /// fails OPEN). `refresh()` preserves it over a server-free tier until a
  /// server-PAID tier supersedes it or its grace window expires.
  static const String storeFailOpenSource = 'store_failopen';

  /// 7-day offline grace: a cached entitlement keeps applying while the service
  /// is unreachable, up to this age.
  static const int graceWindowMs = 7 * 24 * 60 * 60 * 1000;

  final ValueNotifier<EntitlementState> _state =
      ValueNotifier<EntitlementState>(
    _forcePremiumActive ? _debugForcedPremiumState() : EntitlementState.open,
  );

  /// UI-facing stream of the resolved entitlement. Defaults to fully open.
  ValueListenable<EntitlementState> get state => _state;
  EntitlementState get current => _state.value;

  // Advisory "a newer build exists" hint from the (UNSIGNED) /v1/config fields
  // `latest_build` + `update_url`. Used only for a dismissible update nudge —
  // never to block the app (see AppUpdateInfo doc).
  AppUpdateInfo _updateInfo = AppUpdateInfo.none;
  AppUpdateInfo get updateInfo => _updateInfo;

  // Delivery-reliability kill-switches from the SIGNED `reliability` block of
  // the same /v1/config response (this repo is simply the one place that
  // fetches it — same arrangement as _updateInfo above). Deliberately NOT tied
  // to `monetizationEnabled`: reliability is never gated by billing, and these
  // are resolved even when monetization is off. Defaults stay ON unless a
  // verified block says otherwise.
  ReliabilityFlags _reliabilityFlags = ReliabilityFlags.defaults;
  ReliabilityFlags get reliabilityFlags => _reliabilityFlags;

  IdentityFlags _identityFlags = IdentityFlags.defaults;
  IdentityFlags get identityFlags => _identityFlags;

  RoomFlags _roomFlags = RoomFlags.defaults;
  RoomFlags get roomFlags => _roomFlags;

  HandshakeFlags _handshakeFlags = HandshakeFlags.defaults;
  HandshakeFlags get handshakeFlags => _handshakeFlags;

  bool _handshakeFlagsResolved = false;
  bool get handshakeFlagsResolved => _handshakeFlagsResolved;

  /// С-2: выключатель отказов проверки подписи рукопожатия; `null` — блок не
  /// пришёл или не проверен, и тогда ничего не меняется.
  bool? _handshakeAuthEnforceDisabled;
  bool? get handshakeAuthEnforceDisabled => _handshakeAuthEnforceDisabled;

  bool _roomFlagsResolved = false;
  bool get roomFlagsResolved => _roomFlagsResolved;

  Rooms2Flags _rooms2Flags = Rooms2Flags.defaults;
  Rooms2Flags get rooms2Flags => _rooms2Flags;

  SupportConfig _supportConfig = SupportConfig.defaults;
  SupportConfig get supportConfig => _supportConfig;

  /// True once a /v1/config response was actually received this session (the
  /// identity block parsed, verified or not). The controller only writes the
  /// И-1 flag cache when this is set — a network failure must not overwrite a
  /// previously verified ON with the constructor default.
  bool _identityFlagsResolved = false;
  bool get identityFlagsResolved => _identityFlagsResolved;

  void dispose() => _state.dispose();

  void _emit(EntitlementState next) {
    _state.value = next;
  }

  /// Loads the last cached snapshot (if any) so the app starts with the same
  /// state it ended with, before any network refresh.
  Future<void> loadFromCache() async {
    if (_forcePremiumActive) return; // debug force-premium: keep the forced state
    try {
      final raw = await _cache.read(cacheKey);
      if (raw == null || raw.isEmpty) return;
      final json = _decode(raw);
      if (json != null) {
        _emit(EntitlementState.fromCacheJson(json));
      }
    } catch (_) {
      // Corrupt cache → keep the open default.
    }
  }

  /// Refreshes from the server. Always resolves to a usable state (fail open).
  Future<EntitlementState> refresh({required String profileId}) async {
    if (_forcePremiumActive) {
      // DEBUG force-premium: never touch the network; pin lifetime premium.
      _emit(_debugForcedPremiumState());
      return _state.value;
    }
    // 1) Kill-switch from /v1/config. Any failure → fully open.
    //
    // The flag is verified before it is trusted (audit §E/R3): in a release
    // build (verifying key baked in) we only honour `monetization_enabled=true`
    // when the Ed25519 config signature checks out. A forged/unsigned config
    // that tries to FLIP monetization on is rejected here and falls through to
    // the fully-open state — a forgery can only fail to lock features, never
    // succeed at locking them (fail-open direction). Debug/test builds have no
    // key, cannot verify, and so keep byte-for-byte the pre-R3 behaviour.
    bool monetizationEnabled;
    try {
      final config = await _keys.getConfig();
      final payload = config['payload'];
      // Сведения об обновлении берутся ТОЛЬКО из подписанного блока `update`.
      // Основной `payload` их больше не даёт: там они были бы вне подписи.
      _updateInfo = AppUpdateInfo.fromSignedConfig(
        config,
        verified: await verifyUpdateSignature(config),
      );
      // Reliability kill-switches ride the same response but are resolved
      // INDEPENDENTLY of monetization — billing must never gate delivery
      // self-healing. An unverifiable block leaves the machinery ON.
      _reliabilityFlags = ReliabilityFlags.fromConfigResponse(
        config,
        verified: await verifyReliabilitySignature(config),
      );
      // И-1 rotation switch: same ride, opposite polarity — only a VERIFIED
      // block can activate it; anything else keeps rotation dormant.
      _identityFlags = IdentityFlags.fromConfigResponse(
        config,
        verified: await verifyIdentitySignature(config),
      );
      _identityFlagsResolved = true;
      // Room sender-key SEND kill-switch: same ride, same OFF polarity as
      // identity. Only a VERIFIED block may permit sealing room messages under
      // the sender key; anything else leaves sending dormant and the ordinary
      // pairwise fanout carries the room, which every build can read
      // (F-ROOMSK-2, after the 1.7.4+416 field loss).
      _roomFlags = RoomFlags.fromConfigResponse(
        config,
        verified: await verifyRoomsSignature(config),
      );
      _roomFlagsResolved = true;
      // К-2 / К-5: the second rooms block, same OFF polarity.
      _rooms2Flags = Rooms2Flags.fromConfigResponse(
        config,
        verified: await verifyRooms2Signature(config),
      );
      _handshakeFlags = HandshakeFlags.fromConfigResponse(
        config,
        verified: await verifyHandshakeSignature(config),
      );
      _handshakeFlagsResolved = true;
      _handshakeAuthEnforceDisabled =
          await verifiedHandshakeAuthEnforceDisabled(config);
      // In-app Support key + flag: same ride, OFF polarity like identity — only
      // a VERIFIED block enables the page and supplies the key used to seal
      // support tickets.
      _supportConfig = SupportConfig.fromConfigResponse(
        config,
        verified: await verifySupportSignature(config),
      );
      monetizationEnabled =
          payload is Map && payload['monetization_enabled'] == true;
      if (monetizationEnabled && configSignatureEnforced) {
        final configVerified = await verifyConfigSignature(config);
        if (!configVerified) {
          // Unverifiable config in a signing-enabled build → treat as disabled
          // (open). Never lock anyone out on a bad/missing signature.
          monetizationEnabled = false;
        }
      }
    } catch (_) {
      _emit(EntitlementState.open);
      return _state.value;
    }

    if (!monetizationEnabled) {
      // Monetization is globally off → every FEATURE stays unlocked for everyone
      // (fail-open). But we still fetch the owner's signed entitlement so an
      // explicit server grant (comped tester / legacy / grandfathered buyer) is
      // honored for TIER DISPLAY — e.g. the premium badge. We keep
      // monetizationEnabled:false, so `unlockEverything` is true regardless of
      // tier and feature access is byte-for-byte unchanged; only the displayed
      // tier (and thus the badge) reflects reality. Any failure or a free/no
      // grant falls through to the plain open state, exactly as before.
      try {
        final blob = await _getEntitlementsHealed(profileId);
        final fetched = await _stateFromBlobEnforced(
          blob,
          monetizationEnabled: false,
        );
        // A null result means the blob's signature could not be verified in a
        // signing-enabled build → ignore the (possibly forged) grant and fall
        // through to the plain open state. Otherwise honour a paid tier for the
        // badge only (monetization stays off → unlockEverything regardless).
        if (fetched != null && fetched.tier.isPaid) {
          await _writeCache(fetched);
          _emit(fetched);
          return fetched;
        }
      } catch (_) {
        // Ignore — pre-launch entitlement is best-effort; fall through to open.
      }
      _emit(EntitlementState.open);
      return _state.value;
    }

    // 2) Owner-only signed entitlement blob.
    try {
      final blob = await _getEntitlementsHealed(profileId);
      final next = await _stateFromBlobEnforced(
        blob,
        monetizationEnabled: true,
      );
      if (next == null) {
        // Unverifiable blob in a signing-enabled build → fail OPEN (full
        // access), never apply a (possibly forged) gating blob.
        _emit(EntitlementState.open);
        return _state.value;
      }
      // BILLING FAILS OPEN: keep an active local store fail-open premium rather
      // than downgrading to a server-free tier — the buyer has a confirmed store
      // purchase our server hasn't granted yet (config still settling / a
      // transient verify outage). A server-PAID tier supersedes it below; the
      // grace-window expiry lets it downgrade if the purchase never validates.
      if (!next.tier.isPaid) {
        final failOpen = await _activeStoreFailOpenPremium();
        if (failOpen != null) {
          _emit(failOpen);
          return failOpen;
        }
      }
      await _writeCache(next);
      _emit(next);
      return next;
    } catch (_) {
      // Entitlement service unreachable: apply offline grace if a fresh-enough
      // cache exists, otherwise fail open.
      final cached = await _readCache();
      if (cached != null &&
          cached.fetchedAtMs > 0 &&
          _nowMs() - cached.fetchedAtMs <= graceWindowMs) {
        _emit(cached.copyWith(monetizationEnabled: true));
        return _state.value;
      }
      _emit(EntitlementState.open);
      return _state.value;
    }
  }

  /// R1 one-shot: grandfather an existing buyer via legacy_claim. Idempotent and
  /// safe to call on every launch — it no-ops once a result is recorded.
  Future<void> maybeClaimLegacyOnce({required String profileId}) async {
    try {
      final done = await _cache.read(legacyClaimDoneKey);
      if (done == 'done') return;
    } catch (_) {
      // If we can't read the flag, attempt the claim anyway (idempotent server).
    }

    try {
      final (status, json) = await _legacyClaim(profileId);
      if (status == 410) {
        // Window closed — never retry.
        await _safeWrite(legacyClaimDoneKey, 'done');
        return;
      }
      if (status >= 200 && status < 300 && json != null) {
        final next = await _stateFromBlobEnforced(
          json,
          monetizationEnabled: _state.value.monetizationEnabled,
        );
        if (next != null) {
          await _writeCache(next);
          _emit(next);
        }
        // Record the claim as done regardless: a successful (200) server reply
        // means the window was honoured. An unverifiable blob just fails open
        // (we keep the prior open/cached state) rather than retrying forever.
        await _safeWrite(legacyClaimDoneKey, 'done');
        return;
      }
      // Other non-success (e.g. 5xx) → leave the flag unset to retry later.
    } catch (_) {
      // Transient/offline → retry on a future launch.
    }
  }

  // ── internals ────────────────────────────────────────────────────────────

  /// Parses a signed entitlement blob and ENFORCES its Ed25519 signature
  /// (audit §E/R3). Returns the resolved state, or `null` when the blob cannot
  /// be trusted and the caller must fall back to the fully-open state.
  ///
  /// Fail-open by construction:
  ///   * No verifying key baked in (debug/test, R0/R1) → cannot verify, so we
  ///     do NOT enforce and return the parsed state unchanged (pre-R3
  ///     behaviour, `signatureVerified=false`).
  ///   * Key baked in (release, R3) + signature verifies → trusted state with
  ///     `signatureVerified=true`.
  ///   * Key baked in + signature missing/invalid → `null` (untrusted). The
  ///     caller drops to the open state (full access), so a forged/unsigned
  ///     blob can only fail to unlock, never gate a feature or lock a user out.
  Future<EntitlementState?> _stateFromBlobEnforced(
    Map<String, dynamic> blob, {
    required bool monetizationEnabled,
  }) async {
    final verified = await verifyEntitlementSignature(blob);
    if (configSignatureEnforced && !verified) {
      return null;
    }
    return EntitlementState.fromEntitlementJson(
      blob,
      monetizationEnabled: monetizationEnabled,
      signatureVerified: verified,
      fetchedAtMs: _nowMs(),
    );
  }

  Future<Map<String, dynamic>> _getEntitlements(String profileId) async {
    // Подпись — временем сервера (сбитые часы давали 401 и срыв покупки).
    final tsMs = ServerClock.instance.nowMs();
    final nonceB64 = AuthSigner.randomNonceB64();
    final message = AuthSigner.keysEntitlementsGetMessage(
      requesterDeviceId: _signer.deviceId,
      profileId: profileId,
      tsMs: tsMs,
      nonceB64: nonceB64,
    );
    final signatureB64 = await _signer.signB64(message);
    return _keys.getEntitlements(
      profileId,
      requesterDeviceId: _signer.deviceId,
      tsMs: tsMs,
      nonceB64: nonceB64,
      signatureB64: signatureB64,
    );
  }

  /// Fetches the signed entitlement blob, self-healing a keys DEVICE-AUTH 401 (a
  /// churned/unregistered `device_id` — e.g. an iOS reinstall wiped prefs while
  /// the Keychain kept the identity key). On that error we re-register the
  /// current device once and retry, so an admin/purchased grant becomes
  /// fetchable instead of silently failing open to the free-display state.
  Future<Map<String, dynamic>> _getEntitlementsHealed(String profileId) async {
    try {
      return await _getEntitlements(profileId);
    } catch (e) {
      if (_repairDeviceAuth != null && _isKeysDeviceAuthError(e)) {
        if (await _repairDeviceAuth()) {
          return await _getEntitlements(profileId);
        }
      }
      rethrow;
    }
  }

  /// True when a keys request failed because our current device is not
  /// registered / its signature was rejected — a device-auth desync a
  /// re-registration heals. Mirrors the server's 401 reason strings.
  static bool _isKeysDeviceAuthError(Object error) {
    final m = error.toString().toLowerCase();
    return m.contains('unknown requester device') ||
        m.contains('bad requester device_id') ||
        m.contains('requester device missing identity key') ||
        m.contains('missing x-secretly-device-id') ||
        m.contains('bad signature') ||
        m.contains('failed: 401');
  }

  Future<(int, Map<String, dynamic>?)> _legacyClaim(String profileId) async {
    // Подпись — временем сервера (сбитые часы давали 401 и срыв покупки).
    final tsMs = ServerClock.instance.nowMs();
    final nonceB64 = AuthSigner.randomNonceB64();
    final message = AuthSigner.keysLegacyClaimMessage(
      requesterDeviceId: _signer.deviceId,
      profileId: profileId,
      tsMs: tsMs,
      nonceB64: nonceB64,
    );
    final signatureB64 = await _signer.signB64(message);
    return _keys.legacyClaim(
      profileId,
      requesterDeviceId: _signer.deviceId,
      tsMs: tsMs,
      nonceB64: nonceB64,
      signatureB64: signatureB64,
    );
  }

  /// C-2: redeem a verified store purchase, then apply the returned signed
  /// entitlement. Returns true if the server accepted and granted/updated the
  /// tier. Fails soft (returns false) on any error — billing must never crash.
  Future<bool> redeemPurchase({
    required String profileId,
    required String platform,
    String? jws,
    String? purchaseToken,
    String? productId,
  }) async {
    try {
      var (status, json) = await _redeemSigned(
        profileId: profileId,
        platform: platform,
        jws: jws,
        purchaseToken: purchaseToken,
        productId: productId,
      );
      if (status == 401 && _repairDeviceAuth != null) {
        // A 401 on /redeem is ALWAYS a keys device-auth failure (a rejected
        // receipt is 4xx-non-401; a misconfigured verifier is 503). Re-register
        // the current device once and retry — this heals a churned/unregistered
        // device_id (e.g. an iOS reinstall wiped SharedPreferences but the
        // Keychain kept the identity key, so the client mints a NEW device_id
        // the keys server has never seen). A 401 is NOT fail-open (a definitive
        // rejection must never grant premium); we just retry with a now-
        // registered device.
        if (await _repairDeviceAuth()) {
          final retried = await _redeemSigned(
            profileId: profileId,
            platform: platform,
            jws: jws,
            purchaseToken: purchaseToken,
            productId: productId,
          );
          status = retried.$1;
          json = retried.$2;
        }
      }
      if (status >= 200 && status < 300 && json != null) {
        final next = await _stateFromBlobEnforced(
          json,
          monetizationEnabled: _state.value.monetizationEnabled,
        );
        if (next == null) {
          // Unverifiable blob in a signing-enabled build → don't apply it.
          // Fail soft: the purchase flow keeps the prior (open) state.
          return false;
        }
        await _writeCache(next);
        _emit(next);
        // PAID-BUT-NOT-CREDITED hardening (2026-06-25): a receipt redeem counts
        // as "granted" — which tells the caller to ACKNOWLEDGE/finish the store
        // purchase — ONLY when the server actually resolved a PAID tier. A 2xx
        // signed blob that comes back FREE/open means the purchase was NOT
        // credited: e.g. a one-time (lifetime) purchase still settling on
        // Google's side resolves to free during the Play-API replication window,
        // or monetization is disabled server-side. Acknowledging then would
        // consume the purchase without premium (the exact bug class we fixed).
        // Returning false leaves the Play/StoreKit transaction UNFINISHED so the
        // 3-day auto-refund stays armed and restore/stream re-delivers it for
        // another redeem once it settles (or the flag flips on). The server's
        // current entitlement state is still adopted above (writeCache + emit).
        return next.tier.isPaid;
      }
      // Non-2xx from OUR verify server. Distinguish "cannot verify right now"
      // (5xx / gateway / timeout — server misconfigured or unreachable) from a
      // definitive "receipt rejected" (4xx). BILLING FAILS OPEN: the store has
      // already confirmed a real purchase, so when OUR side can't verify it we
      // grant premium locally with a bounded grace instead of blocking the
      // buyer. A 4xx means the receipt was rejected → never grant.
      if (_serverCannotVerify(status)) {
        await _applyStoreFailOpenPremium();
        return true;
      }
      return false;
    } catch (_) {
      // Reaching our verify server threw (network/timeout) — NOT a store
      // rejection. Same fail-open path as a 5xx.
      await _applyStoreFailOpenPremium();
      return true;
    }
  }

  /// One signed `/redeem` round-trip. Extracted so `redeemPurchase` can retry it
  /// after a device-auth self-heal without duplicating the signing (fresh
  /// ts/nonce/signature each call).
  Future<(int, Map<String, dynamic>?)> _redeemSigned({
    required String profileId,
    required String platform,
    String? jws,
    String? purchaseToken,
    String? productId,
  }) async {
    // Подпись — временем сервера (сбитые часы давали 401 и срыв покупки).
    final tsMs = ServerClock.instance.nowMs();
    final nonceB64 = AuthSigner.randomNonceB64();
    final message = AuthSigner.keysRedeemMessage(
      requesterDeviceId: _signer.deviceId,
      profileId: profileId,
      tsMs: tsMs,
      nonceB64: nonceB64,
    );
    final signatureB64 = await _signer.signB64(message);
    return _keys.redeem(
      profileId,
      platform: platform,
      jws: jws,
      purchaseToken: purchaseToken,
      productId: productId,
      requesterDeviceId: _signer.deviceId,
      tsMs: tsMs,
      nonceB64: nonceB64,
      signatureB64: signatureB64,
    );
  }

  /// A non-2xx `/redeem` status that means OUR server could not verify the
  /// receipt right now (misconfigured / unreachable / timeout) — as opposed to a
  /// 4xx that definitively rejected it. Drives the fail-open grant. A 401
  /// (device-auth) is deliberately EXCLUDED — it is healed+retried, never
  /// fail-opened.
  static bool _serverCannotVerify(int status) =>
      status == 0 || status == 408 || status >= 500;

  /// BILLING FAILS OPEN: apply a bounded local premium grace when the STORE has
  /// confirmed a purchase but OUR server can't verify it yet. Superseded by the
  /// next successful server refresh (a PAID tier wins; a still-free tier after
  /// the grace expires downgrades). Never applied on a 4xx rejection.
  Future<void> _applyStoreFailOpenPremium() async {
    final failOpen = _storeFailOpenPremiumState();
    await _writeCache(failOpen);
    _emit(failOpen);
  }

  EntitlementState _storeFailOpenPremiumState() => EntitlementState(
        monetizationEnabled: _state.value.monetizationEnabled,
        tier: EntitlementTier.premium,
        source: storeFailOpenSource,
        features: EntitlementFeatures.all,
        limits: EntitlementLimits.premium,
        expiresAtMs: _nowMs() + graceWindowMs,
        fetchedAtMs: _nowMs(),
      );

  /// Returns the persisted store fail-open premium if still within its grace
  /// window, else null (expired/absent → let the server tier apply).
  Future<EntitlementState?> _activeStoreFailOpenPremium() async {
    final cached = await _readCache();
    if (cached == null || cached.source != storeFailOpenSource) return null;
    final until = cached.expiresAtMs;
    if (until == null || _nowMs() >= until) return null;
    return cached.copyWith(monetizationEnabled: true);
  }

  Future<void> _writeCache(EntitlementState state) async {
    await _safeWrite(cacheKey, _encode(state.toJson()));
  }

  Future<EntitlementState?> _readCache() async {
    try {
      final raw = await _cache.read(cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final json = _decode(raw);
      return json == null ? null : EntitlementState.fromCacheJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _cache.write(key, value);
    } catch (_) {
      // Best-effort.
    }
  }

  static String _encode(Map<String, dynamic> json) => jsonEncode(json);
  static Map<String, dynamic>? _decode(String raw) {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
