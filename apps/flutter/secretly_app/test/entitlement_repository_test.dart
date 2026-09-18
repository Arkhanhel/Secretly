// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:secretly_app/entitlements/entitlement_models.dart';
import 'package:secretly_app/entitlements/entitlement_repository.dart';
import 'package:secretly_app/transport/keys_client.dart';

class _FakeSigner implements EntitlementSigner {
  @override
  String get deviceId => 'device-test-1';

  @override
  Future<String> signB64(List<int> message) async => 'sig-${message.length}';
}

class _MemCache implements EntitlementCache {
  final Map<String, String> store = {};
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> write(String key, String value) async => store[key] = value;
}

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> _configBody({required bool enabled}) => {
      'payload': {
        'monetization_enabled': enabled,
        'free_limits': EntitlementLimits.free.toJson(),
        'premium_limits': EntitlementLimits.premium.toJson(),
        'desktop_trial_days': 14,
        'issued_at_ms': 1,
      },
      'signature': '',
      'alg': 'ed25519',
    };

Map<String, dynamic> _entitlementBody({
  required String tier,
  required String source,
}) =>
    {
      'profile_id': 'P',
      'tier': tier,
      'source': source,
      'expires_at_ms': null,
      'grace_until_ms': null,
      'features':
          tier == 'free' ? EntitlementFeatures.none.toJson() : EntitlementFeatures.all.toJson(),
      'limits': tier == 'free'
          ? EntitlementLimits.free.toJson()
          : EntitlementLimits.premium.toJson(),
      'issued_at_ms': 1,
      'signature': '',
      'alg': 'ed25519',
    };

EntitlementRepository _repo(MockClient mock, _MemCache cache,
    {int Function()? nowMs, Future<bool> Function()? repairDeviceAuth}) {
  final keys = KeysClient(
    baseUrl: Uri.parse('https://keys.test'),
    httpClient: mock,
  );
  return EntitlementRepository(
    keysClient: keys,
    signer: _FakeSigner(),
    cache: cache,
    repairDeviceAuth: repairDeviceAuth,
    nowMs: nowMs,
  );
}

void main() {
  test('default state is fully open before any refresh', () {
    final repo = _repo(MockClient((_) async => _json({})), _MemCache());
    expect(repo.current.unlockEverything, isTrue);
    expect(repo.current.monetizationEnabled, isFalse);
  });

  test('monetization disabled -> open; owner entitlement fetched once for '
      'tier/badge display (access unchanged)', () async {
    var entitlementHits = 0;
    final mock = MockClient((req) async {
      if (req.url.path == '/v1/config') {
        return _json(_configBody(enabled: false));
      }
      if (req.url.path.contains('/entitlements')) {
        entitlementHits++;
      }
      return _json({}, 404);
    });
    final repo = _repo(mock, _MemCache());
    final state = await repo.refresh(profileId: 'P');
    expect(state.unlockEverything, isTrue);
    expect(state.monetizationEnabled, isFalse);
    // Intentional (entitlement_repository.dart refresh, monetization-off branch):
    // the owner's signed entitlement IS fetched once so an explicit grant
    // (comped/legacy/grandfathered) shows the premium badge. unlockEverything
    // stays true regardless, so feature access is byte-for-byte unchanged.
    expect(entitlementHits, 1);
  });

  test('monetization enabled + premium entitlement -> premium state', () async {
    final mock = MockClient((req) async {
      if (req.url.path == '/v1/config') {
        return _json(_configBody(enabled: true));
      }
      if (req.url.path == '/v1/profile/P/entitlements') {
        expect(req.headers['x-secretly-device-id'], 'device-test-1');
        expect(req.headers['x-secretly-signature-b64'], isNotNull);
        return _json(_entitlementBody(tier: 'premium', source: 'appstore'));
      }
      return _json({}, 404);
    });
    final cache = _MemCache();
    final repo = _repo(mock, cache, nowMs: () => 1000);
    final state = await repo.refresh(profileId: 'P');
    expect(state.monetizationEnabled, isTrue);
    expect(state.tier, EntitlementTier.premium);
    expect(state.unlockEverything, isTrue);
    // cached for offline use
    expect(cache.store[EntitlementRepository.cacheKey], isNotNull);
  });

  test('monetization enabled + free entitlement -> gated state', () async {
    final mock = MockClient((req) async {
      if (req.url.path == '/v1/config') {
        return _json(_configBody(enabled: true));
      }
      if (req.url.path == '/v1/profile/P/entitlements') {
        return _json(_entitlementBody(tier: 'free', source: 'none'));
      }
      return _json({}, 404);
    });
    final repo = _repo(mock, _MemCache());
    final state = await repo.refresh(profileId: 'P');
    expect(state.tier, EntitlementTier.free);
    expect(state.unlockEverything, isFalse);
    expect(state.desktopUnlocked, isFalse);
  });

  // Signature enforcement (audit §E/R3) is keyed off a baked-in public key,
  // which is empty under test (`configSignatureEnforced == false`). So these
  // tests verify the FAIL-OPEN side: with no key, unsigned config + unsigned
  // blobs must behave byte-for-byte as the pre-R3 build (never a lockout). The
  // production "forged signature -> drop to open" branch can only be exercised
  // in a build with the key compiled in via --dart-define and is covered by
  // verifyConfigSignature unit tests in entitlement_signature_test.dart.
  test('unsigned config + unsigned blob still resolve (no baked key)', () async {
    final mock = MockClient((req) async {
      if (req.url.path == '/v1/config') {
        return _json(_configBody(enabled: true)); // signature: ''
      }
      if (req.url.path == '/v1/profile/P/entitlements') {
        return _json(_entitlementBody(tier: 'premium', source: 'appstore'));
      }
      return _json({}, 404);
    });
    final repo = _repo(mock, _MemCache());
    final state = await repo.refresh(profileId: 'P');
    // No key baked in → enforcement inert → unsigned blob is honoured.
    expect(state.monetizationEnabled, isTrue);
    expect(state.tier, EntitlementTier.premium);
    expect(state.signatureVerified, isFalse);
    expect(state.unlockEverything, isTrue);
  });

  test('config unreachable -> fail open', () async {
    final mock = MockClient((req) async => _json({}, 500));
    final repo = _repo(mock, _MemCache());
    final state = await repo.refresh(profileId: 'P');
    expect(state.unlockEverything, isTrue);
    expect(state.monetizationEnabled, isFalse);
  });

  test('entitlement fetch fails but fresh cache exists -> grace applies',
      () async {
    final cache = _MemCache();
    // Seed a recently-cached premium entitlement.
    final cached = EntitlementState.fromEntitlementJson(
      _entitlementBody(tier: 'premium', source: 'appstore'),
      monetizationEnabled: true,
      fetchedAtMs: 1000,
    );
    cache.store[EntitlementRepository.cacheKey] = jsonEncode(cached.toJson());

    final mock = MockClient((req) async {
      if (req.url.path == '/v1/config') {
        return _json(_configBody(enabled: true));
      }
      // Entitlement endpoint is down.
      return _json({}, 503);
    });
    // now within the 7-day grace window of fetchedAtMs=1000.
    final repo = _repo(mock, cache, nowMs: () => 1000 + 60 * 1000);
    final state = await repo.refresh(profileId: 'P');
    expect(state.tier, EntitlementTier.premium);
    expect(state.unlockEverything, isTrue);
  });

  test('entitlement fetch fails and cache is stale -> fail open', () async {
    final cache = _MemCache();
    final cached = EntitlementState.fromEntitlementJson(
      _entitlementBody(tier: 'free', source: 'none'),
      monetizationEnabled: true,
      fetchedAtMs: 1000,
    );
    cache.store[EntitlementRepository.cacheKey] = jsonEncode(cached.toJson());

    final mock = MockClient((req) async {
      if (req.url.path == '/v1/config') {
        return _json(_configBody(enabled: true));
      }
      return _json({}, 503);
    });
    // now far beyond the grace window.
    final repo = _repo(mock, cache,
        nowMs: () => 1000 + EntitlementRepository.graceWindowMs + 1);
    final state = await repo.refresh(profileId: 'P');
    expect(state.unlockEverything, isTrue);
  });

  test('loadFromCache restores last snapshot', () async {
    final cache = _MemCache();
    final cached = EntitlementState.fromEntitlementJson(
      _entitlementBody(tier: 'legacy', source: 'legacy'),
      monetizationEnabled: true,
      fetchedAtMs: 1,
    );
    cache.store[EntitlementRepository.cacheKey] = jsonEncode(cached.toJson());
    final repo = _repo(MockClient((_) async => _json({})), cache);
    await repo.loadFromCache();
    expect(repo.current.tier, EntitlementTier.legacy);
  });

  group('redeemPurchase (C-2)', () {
    test('applies the returned signed entitlement on success', () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['platform'], 'appstore');
          expect(body['jws'], 'JWS123');
          expect(body['profile_id'], 'P');
          return _json(_entitlementBody(tier: 'premium', source: 'appstore'));
        }
        return _json({}, 404);
      });
      final repo = _repo(mock, _MemCache());
      final ok = await repo.redeemPurchase(
        profileId: 'P',
        platform: 'appstore',
        jws: 'JWS123',
      );
      expect(ok, isTrue);
      expect(repo.current.tier, EntitlementTier.premium);
    });

    test('returns false on rejection (4xx) and keeps the prior state', () async {
      final mock = MockClient((req) async => _json({'error': 'bad'}, 400));
      final repo = _repo(mock, _MemCache());
      final ok = await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 'tok',
        productId: 'secretly_premium_monthly',
      );
      expect(ok, isFalse);
      expect(repo.current.tier, EntitlementTier.free);
    });

    // PAID-BUT-NOT-CREDITED hardening (2026-06-25): a 2xx signed blob that
    // resolves to a NON-PAID tier (a one-time purchase still settling on
    // Google's side, or monetization disabled server-side) must NOT count as
    // granted — the caller must leave the store purchase UNFINISHED for a later
    // retry/restore instead of acknowledging it without premium. The server's
    // state is still adopted; only the acknowledge is withheld.
    test('returns false when redeem resolves to FREE (purchase not credited yet)',
        () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          return _json(_entitlementBody(tier: 'free', source: 'none'));
        }
        return _json({}, 404);
      });
      final repo = _repo(mock, _MemCache());
      final ok = await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 'tok',
        productId: 'secretly_premium_life',
      );
      expect(ok, isFalse,
          reason: 'a free resolution must not acknowledge the purchase');
      expect(repo.current.tier, EntitlementTier.free); // server state adopted
    });

    test('returns true when redeem resolves to a PAID tier (lifetime)', () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          return _json(_entitlementBody(tier: 'lifetime', source: 'play'));
        }
        return _json({}, 404);
      });
      final repo = _repo(mock, _MemCache());
      final ok = await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 'tok',
        productId: 'secretly_premium_life',
      );
      expect(ok, isTrue);
      expect(repo.current.tier, EntitlementTier.lifetime);
    });
  });

  group('maybeClaimLegacyOnce', () {
    test('success caches result and records done flag', () async {
      var claimHits = 0;
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/legacy_claim') {
          claimHits++;
          return _json(_entitlementBody(tier: 'legacy', source: 'legacy'));
        }
        return _json({}, 404);
      });
      final cache = _MemCache();
      final repo = _repo(mock, cache, nowMs: () => 5);
      await repo.maybeClaimLegacyOnce(profileId: 'P');
      expect(claimHits, 1);
      expect(cache.store[EntitlementRepository.legacyClaimDoneKey], 'done');
      expect(repo.current.tier, EntitlementTier.legacy);

      // Second call must no-op (no extra HTTP).
      await repo.maybeClaimLegacyOnce(profileId: 'P');
      expect(claimHits, 1);
    });

    test('410 Gone records done and does not change state', () async {
      var claimHits = 0;
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/legacy_claim') {
          claimHits++;
          return http.Response('gone', 410);
        }
        return _json({}, 404);
      });
      final cache = _MemCache();
      final repo = _repo(mock, cache);
      await repo.maybeClaimLegacyOnce(profileId: 'P');
      expect(claimHits, 1);
      expect(cache.store[EntitlementRepository.legacyClaimDoneKey], 'done');
      expect(repo.current.unlockEverything, isTrue); // still open default
    });

    test('transient 500 leaves flag unset for retry', () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/legacy_claim') {
          return http.Response('boom', 500);
        }
        return _json({}, 404);
      });
      final cache = _MemCache();
      final repo = _repo(mock, cache);
      await repo.maybeClaimLegacyOnce(profileId: 'P');
      expect(cache.store[EntitlementRepository.legacyClaimDoneKey], isNull);
    });
  });

  // Regression for the iOS/Android purchase->redeem receipt routing. The prior
  // Apple-rejection risk was an iOS receipt-shape mismatch; these lock the
  // CLIENT request contract so a refactor can't silently send the wrong proof.
  group('redeemPurchase request shape', () {
    test('iOS sends platform=appstore + StoreKit2 JWS, no Play token', () async {
      Map<String, dynamic>? sent;
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _json(_entitlementBody(tier: 'premium', source: 'iap'));
        }
        return _json({});
      });
      final ok = await _repo(mock, _MemCache()).redeemPurchase(
        profileId: 'P',
        platform: 'appstore',
        jws: 'TEST_STOREKIT2_JWS',
      );
      expect(ok, isTrue);
      expect(sent, isNotNull);
      expect(sent!['platform'], 'appstore');
      expect(sent!['jws'], 'TEST_STOREKIT2_JWS');
      expect(sent!.containsKey('purchase_token'), isFalse);
      expect(sent!.containsKey('product_id'), isFalse);
    });

    test('Android sends platform=play + purchase_token + product_id, no jws',
        () async {
      Map<String, dynamic>? sent;
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _json(_entitlementBody(tier: 'premium', source: 'iap'));
        }
        return _json({});
      });
      final ok = await _repo(mock, _MemCache()).redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 'PLAY_TOKEN_123',
        productId: 'secretly_premium_yearly',
      );
      expect(ok, isTrue);
      expect(sent!['platform'], 'play');
      expect(sent!['purchase_token'], 'PLAY_TOKEN_123');
      expect(sent!['product_id'], 'secretly_premium_yearly');
      expect(sent!.containsKey('jws'), isFalse);
    });
  });

  group('billing fails OPEN — store fail-open premium (Fix C)', () {
    const productId = 'secretly_premium_monthly';

    test('redeem 5xx (server cannot verify) grants premium fail-open', () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          return _json({'error': 'play service account not configured'}, 503);
        }
        return _json({}, 404);
      });
      final repo = _repo(mock, _MemCache(), nowMs: () => 1000);
      final granted = await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 'tok-1',
        productId: productId,
      );
      // The store already confirmed a real purchase; our server just can't
      // verify → billing fails OPEN, buyer keeps premium locally.
      expect(granted, isTrue);
      expect(repo.current.tier, EntitlementTier.premium);
      expect(repo.current.unlockEverything, isTrue);
      expect(repo.current.source, EntitlementRepository.storeFailOpenSource);
      expect(repo.current.expiresAtMs, isNotNull);
    });

    test('redeem 4xx (receipt rejected) never grants — no fail-open', () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          return _json({'error': 'receipt rejected'}, 400);
        }
        return _json({}, 404);
      });
      final repo = _repo(mock, _MemCache(), nowMs: () => 1000);
      final granted = await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 'forged',
        productId: productId,
      );
      expect(granted, isFalse);
      expect(repo.current.tier, EntitlementTier.free);
      expect(
        repo.current.source,
        isNot(EntitlementRepository.storeFailOpenSource),
      );
    });

    test('refresh keeps active fail-open premium over a server-free tier',
        () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') return _json({}, 503);
        if (req.url.path == '/v1/config') {
          return _json(_configBody(enabled: true));
        }
        if (req.url.path == '/v1/profile/P/entitlements') {
          return _json(_entitlementBody(tier: 'free', source: 'none'));
        }
        return _json({}, 404);
      });
      final repo = _repo(mock, _MemCache(), nowMs: () => 1000);
      await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 't',
        productId: productId,
      );
      final refreshed = await repo.refresh(profileId: 'P');
      // Server still says free, but the buyer's confirmed store purchase wins
      // while the grace window is active — no downgrade.
      expect(refreshed.tier, EntitlementTier.premium);
      expect(refreshed.unlockEverything, isTrue);
      expect(refreshed.source, EntitlementRepository.storeFailOpenSource);
    });

    test('a real server-PAID grant supersedes the fail-open marker', () async {
      var serverTier = 'free';
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') return _json({}, 503);
        if (req.url.path == '/v1/config') {
          return _json(_configBody(enabled: true));
        }
        if (req.url.path == '/v1/profile/P/entitlements') {
          return _json(_entitlementBody(
            tier: serverTier,
            source: serverTier == 'free' ? 'none' : 'play',
          ));
        }
        return _json({}, 404);
      });
      final repo = _repo(mock, _MemCache(), nowMs: () => 1000);
      await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 't',
        productId: productId,
      );
      expect(repo.current.source, EntitlementRepository.storeFailOpenSource);
      // Server config gets fixed → it now returns a genuine premium grant.
      serverTier = 'premium';
      final refreshed = await repo.refresh(profileId: 'P');
      expect(refreshed.tier, EntitlementTier.premium);
      expect(refreshed.source, 'play'); // server grant, not the fail-open marker
    });

    test('fail-open premium downgrades once its grace window expires', () async {
      var now = 1000;
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') return _json({}, 503);
        if (req.url.path == '/v1/config') {
          return _json(_configBody(enabled: true));
        }
        if (req.url.path == '/v1/profile/P/entitlements') {
          return _json(_entitlementBody(tier: 'free', source: 'none'));
        }
        return _json({}, 404);
      });
      final repo = _repo(mock, _MemCache(), nowMs: () => now);
      await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 't',
        productId: productId,
      );
      expect(repo.current.tier, EntitlementTier.premium);
      // Jump past the 7-day grace → the still-free server tier now applies.
      now = 1000 + EntitlementRepository.graceWindowMs + 1;
      final refreshed = await repo.refresh(profileId: 'P');
      expect(refreshed.tier, EntitlementTier.free);
    });
  });

  group('keys device-auth self-heal (iOS device_id churn)', () {
    const productId = 'secretly_premium_monthly';

    test('redeem 401 → re-register current device + retry → premium granted',
        () async {
      var redeemCalls = 0;
      var repairCalls = 0;
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          redeemCalls++;
          if (redeemCalls == 1) {
            return _json({'error': 'unknown requester device'}, 401);
          }
          return _json(_entitlementBody(tier: 'premium', source: 'play'));
        }
        return _json({}, 404);
      });
      final repo = _repo(
        mock,
        _MemCache(),
        nowMs: () => 1000,
        repairDeviceAuth: () async {
          repairCalls++;
          return true; // re-registration succeeded
        },
      );
      final granted = await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 't',
        productId: productId,
      );
      expect(granted, isTrue);
      expect(repo.current.tier, EntitlementTier.premium);
      expect(redeemCalls, 2, reason: 'original + one retry after repair');
      expect(repairCalls, 1);
    });

    test('redeem 401 but repair fails → NOT granted and NOT fail-open',
        () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          return _json({'error': 'unknown requester device'}, 401);
        }
        return _json({}, 404);
      });
      final repo = _repo(
        mock,
        _MemCache(),
        nowMs: () => 1000,
        repairDeviceAuth: () async => false,
      );
      final granted = await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 't',
        productId: productId,
      );
      expect(granted, isFalse);
      expect(repo.current.tier, EntitlementTier.free);
      // A 401 is a definitive response — it must NEVER fail-open into a local
      // premium grant (unlike a 5xx "cannot verify").
      expect(
        repo.current.source,
        isNot(EntitlementRepository.storeFailOpenSource),
      );
    });

    test('entitlements GET 401 → re-register + retry → premium fetchable',
        () async {
      var entCalls = 0;
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/config') {
          return _json(_configBody(enabled: true));
        }
        if (req.url.path == '/v1/profile/P/entitlements') {
          entCalls++;
          if (entCalls == 1) {
            return _json({'error': 'unknown requester device'}, 401);
          }
          return _json(_entitlementBody(tier: 'premium', source: 'manual'));
        }
        return _json({}, 404);
      });
      final repo = _repo(
        mock,
        _MemCache(),
        nowMs: () => 1000,
        repairDeviceAuth: () async => true,
      );
      final state = await repo.refresh(profileId: 'P');
      // Without the heal the 401 would silently fail-open to the free-display
      // "open" state and the admin/purchased grant would be unfetchable.
      expect(state.tier, EntitlementTier.premium);
      expect(state.unlockEverything, isTrue);
      expect(entCalls, 2, reason: 'original + one retry after repair');
    });

    test('no repair callback wired → a 401 is left unhealed (returns false)',
        () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/v1/entitlements/redeem') {
          return _json({'error': 'unknown requester device'}, 401);
        }
        return _json({}, 404);
      });
      final repo = _repo(mock, _MemCache(), nowMs: () => 1000);
      final granted = await repo.redeemPurchase(
        profileId: 'P',
        platform: 'play',
        purchaseToken: 't',
        productId: productId,
      );
      expect(granted, isFalse);
    });
  });
}
