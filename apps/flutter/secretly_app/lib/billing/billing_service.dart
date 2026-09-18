// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Billing (TZ-MONETIZE-01 §C-2).
//
// Thin wrapper over `in_app_purchase` that:
//   * queries the three store products and exposes them as priced [PaywallSku]s
//     (localized store price strings) for the paywall,
//   * listens to `purchaseStream` from app start so pending iOS transactions are
//     always finished (StoreKit requirement),
//   * runs an injected verifier (S-2 `/redeem`) on a purchased/restored item,
//     then always calls `completePurchase`.
//
// Safe before stores are configured: if billing is unavailable or a product is
// not found, the paywall falls back to the TZ reference prices and nothing
// crashes. Security is never gated here (Appendix B) — this module is only
// imported by the paywall and app bootstrap.

import 'dart:async';
import 'restore_outcome.dart';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'pending_purchase_notice.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../ui/paywall_screen.dart'
    show PaywallSku, defaultPaywallSkus, premiumPerMonthSuffix;

/// FREE-TRIAL MASTER SWITCH (2026-07-17). Turn the 7-day free trial on/off in
/// ONE place — reversible by design (flip back to `true` to restore it). When
/// `false`:
///   * billing stops selecting the store's free-trial offer, so a purchase goes
///     straight to the paid base plan (no trial) even if the intro offer still
///     exists in App Store Connect / Play Console;
///   * the launch upsell (`premium_trial_sheet.dart`) advertises buying Premium
///     directly, with no "free" / trial wording.
/// NOTE: to remove the trial for REAL you must also delete the introductory
/// offer on the subscription in App Store Connect AND Play Console — this flag
/// only stops the app from asking for it.
const bool kFreeTrialEnabled = false;

/// Store product identifiers. Identical on App Store and Google Play.
/// Apple permanently reserves deleted IDs, hence `_life` (not `_lifetime`).
const String kProductMonthly = 'secretly_premium_monthly';
const String kProductYearly = 'secretly_premium_yearly';
const String kProductLifetime = 'secretly_premium_life';

const Set<String> kBillingProductIds = {
  kProductMonthly,
  kProductYearly,
  kProductLifetime,
};

/// Maps the resolved store [products] onto the paywall's reference SKU list,
/// replacing the placeholder price with the localized store price string.
/// Pure + UI-free so it is unit-testable without the platform channel.
/// Falls back to the reference SKU for any id the store didn't return.
List<PaywallSku> paywallSkusFromProducts(
  Map<String, ProductDetails> products, {
  String localeTag = 'en',
}) {
  final defaults = defaultPaywallSkus(localeTag: localeTag);
  if (products.isEmpty) return defaults;

  // Build the per-month figures, yearly discount %, and struck-through original
  // (12× monthly) from the LIVE store prices in the user's REAL currency — so
  // the cards never show a hardcoded "$1.25" or a bare number without the
  // currency. Falls back to the reference labels when raw prices are missing.
  final monthly = products[kProductMonthly];
  final yearly = products[kProductYearly];
  final suffix = premiumPerMonthSuffix(localeTag);

  String? monthlyPerMonth;
  if (monthly != null && monthly.rawPrice > 0) {
    // Use the store's OWN localized price string for the monthly per-month so it
    // matches the lifetime card's currency formatting EXACTLY (currency on the
    // locale-correct side, proper spacing) instead of a NumberFormat rebuild that
    // could place the code/symbol on the wrong side or glue it to the digits.
    // suffix is a slash form ("/мес") → concatenate WITHOUT a space.
    monthlyPerMonth = '${monthly.price}$suffix';
  }

  String? yearlyBadge;
  String? yearlyPerMonth;
  String? yearlyOriginal;
  if (yearly != null && yearly.rawPrice > 0) {
    yearlyPerMonth =
        '${_moneyLikeStore(yearly, yearly.rawPrice / 12.0)}$suffix';
    if (monthly != null && monthly.rawPrice > 0) {
      final original = monthly.rawPrice * 12.0;
      if (original > yearly.rawPrice) {
        final pct = ((1 - (yearly.rawPrice / original)) * 100).round();
        if (pct > 0) yearlyBadge = '−$pct%';
        yearlyOriginal = _moneyLikeStore(yearly, original);
      }
    }
  }

  return defaults.map((d) {
    final p = products[d.productId];
    if (p == null) return d; // store didn't return it → keep the reference SKU
    final id = d.productId;
    return PaywallSku(
      productId: id,
      title: d.title,
      priceLabel: p.price,
      subtitle: d.subtitle,
      highlighted: d.highlighted,
      badge: id == kProductYearly ? (yearlyBadge ?? d.badge) : d.badge,
      perMonthLabel: id == kProductMonthly
          ? (monthlyPerMonth ?? d.perMonthLabel)
          : (id == kProductYearly
                ? (yearlyPerMonth ?? d.perMonthLabel)
                : d.perMonthLabel),
      originalPriceLabel: id == kProductYearly
          ? (yearlyOriginal ?? d.originalPriceLabel)
          : d.originalPriceLabel,
    );
  }).toList(growable: false);
}

/// Formats [value] in the SAME visual style as the store's own [p.price] string
/// — currency symbol on the same side, the same decimal/group separators, and
/// the same spacing. The store price is the source of truth for the user's
/// locale formatting (e.g. "144,99 ₴"); we only swap in the derived magnitude.
///
/// This is why the yearly per-month and the struck "12× monthly" original now
/// match the monthly card exactly, instead of `NumberFormat.currency` placing
/// the symbol before the digits with a dot decimal ("₴41.67").
String _moneyLikeStore(ProductDetails p, double value) {
  final ref = p.price.trim();
  final symbol = p.currencySymbol.isNotEmpty ? p.currencySymbol : p.currencyCode;
  // Numeric run in the store string, incl. group/decimal separators. `\s` also
  // matches the no-break (U+00A0) / narrow (U+202F) spaces ru/uk use as the
  // thousands separator.
  final m = RegExp(r'\d[\d\s.,]*\d|\d').firstMatch(ref);
  if (m == null) {
    return '${value.toStringAsFixed(2)} $symbol'.trim();
  }
  final numRun = m.group(0)!;
  final compact = numRun.replaceAll(RegExp(r'\s'), '');
  // Decimal separator = the , or . immediately before the final two digits.
  final decSep = RegExp(r'([.,])\d{2}$').firstMatch(compact)?.group(1) ?? '.';
  // Group separator the store uses between thousands: a space if present, else
  // the other of . , ; empty when the reference has no grouping.
  final otherSep = decSep == ',' ? '.' : ',';
  final grpSep = RegExp(r'\d\s\d').hasMatch(numRun)
      ? '\u00A0'
      : (numRun.contains(otherSep) ? otherSep : '');
  final neg = value < 0;
  final abs = value.abs();
  final intPart = abs.truncate();
  final frac = ((abs - intPart) * 100).round().toString().padLeft(2, '0');
  var intStr = intPart.toString();
  if (grpSep.isNotEmpty && intStr.length > 3) {
    final buf = StringBuffer();
    for (var i = 0; i < intStr.length; i++) {
      if (i > 0 && (intStr.length - i) % 3 == 0) buf.write(grpSep);
      buf.write(intStr[i]);
    }
    intStr = buf.toString();
  }
  final numOut = '${neg ? '-' : ''}$intStr$decSep$frac';
  // Preserve the symbol side + spacing exactly: swap the numeric run in place.
  return ref.replaceRange(m.start, m.end, numOut);
}

/// Outcome of a purchase/restore, surfaced to the UI for a snackbar/banner.
enum BillingOutcome { pending, purchased, restored, canceled, error }

class BillingEvent {
  const BillingEvent(this.outcome, {this.productId, this.message});
  final BillingOutcome outcome;
  final String? productId;
  final String? message;
}

/// Called for a purchased/restored item before it is completed. Returns true if
/// the entitlement was accepted (S-2 `/redeem`). Until S-2 ships, the injected
/// default returns true so sandbox/testing purchases still finish cleanly.
typedef BillingVerifier = Future<bool> Function(PurchaseDetails details);

/// Re-pulls the latest server entitlement (signed /v1/config + entitlement blob)
/// into the client and reports whether a PAID tier is now active. Wired from the
/// app controller so "Restore" also surfaces grants that never came through the
/// store stream — an admin/comped grant, a webhook credit, or a purchase that
/// was credited server-side in a past session.
typedef EntitlementRefresher = Future<bool> Function();

class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  // Lazily resolved so merely touching `BillingService.instance` (e.g. the
  // launch-time recovery retry) does NOT eagerly construct the platform
  // InAppPurchase client. That construction opens a native billing channel,
  // which throws a channel-error under unit tests and pollutes sibling tests.
  // Only resolved once billing is actually used (after start()/isAvailable).
  InAppPurchase? _iap;
  @visibleForTesting
  set iap(InAppPurchase value) => _iap = value;
  InAppPurchase get iap => _iap ??= InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  BillingVerifier? _verify;
  EntitlementRefresher? _refreshEntitlement;
  bool _started = false;
  bool _available = false;

  final Map<String, ProductDetails> _products = <String, ProductDetails>{};

  /// Broadcast of purchase/restore outcomes for the paywall to react to.
  /// Вызывается, когда Play/App Store создал заказ и ЖДЁТ доплаты.
  ///
  /// Отдельный обработчик, а не только поток: поток живёт, пока жив слушатель, а
  /// отложенная оплата длится днями и должна переживать перезапуск.
  Future<void> Function(String productId)? onPendingPurchase;

  /// Вызывается, когда ожидание закончилось — оплатой, отказом или ошибкой.
  Future<void> Function(String productId)? onPendingResolved;

  /// Читает отметку ожидания. Живёт здесь, чтобы экран оплаты остался
  /// биллинг-независимым: граф импортов односторонний (billing → paywall).
  Future<PendingPurchaseNotice?> Function()? pendingNoticeReader;

  /// Помечает, что тихую подсказку уже показали — она полагается ОДИН раз.
  Future<void> Function()? pendingToastMarker;

  final StreamController<BillingEvent> _events =
      StreamController<BillingEvent>.broadcast();
  Stream<BillingEvent> get events => _events.stream;

  /// True once the platform billing client reported itself available.
  bool get isAvailable => _available;

  Map<String, ProductDetails> get products => Map.unmodifiable(_products);

  /// Idempotent. Subscribes to `purchaseStream` (so pending iOS transactions are
  /// finished) and loads products. Swallows all errors — billing must never
  /// block app boot, and a missing store config is a normal pre-launch state.
  Future<void> start({
    BillingVerifier? verify,
    EntitlementRefresher? refreshEntitlement,
  }) async {
    _verify = verify ?? _verify;
    _refreshEntitlement = refreshEntitlement ?? _refreshEntitlement;
    if (_started) return;
    _started = true;
    try {
      _available = await iap.isAvailable();
    } catch (_) {
      _available = false;
    }
    if (!_available) return;
    _sub = iap.purchaseStream.listen(
      _onPurchases,
      onDone: () => _sub?.cancel(),
      onError: (Object e) =>
          _events.add(BillingEvent(BillingOutcome.error, message: '$e')),
    );
    await loadProducts();
    // RECOVERY (paid-but-not-credited): re-deliver any unfinished / owned
    // purchases so a grant that was lost last session (network/5xx/app killed
    // before redeem, or a purchase that was acknowledged WITHOUT a grant by the
    // old code) is re-verified and credited now. Subscribing already re-delivers
    // unfinished transactions, but an already-acknowledged-yet-ungranted owned
    // purchase only comes back via restore — so we always restore once on start.
    // Silent (no UI) and idempotent server-side (redeem is keyed by store tx).
    unawaited(retryUnfinishedPurchases());
  }

  /// Re-triggers delivery of unfinished / owned purchases for a redeem retry.
  /// Safe to call repeatedly (on start, after the entitlement repo becomes
  /// ready, on app foreground, or on connectivity regain) — only purchases that
  /// still need crediting do any work; the grant is idempotent server-side.
  Future<void> retryUnfinishedPurchases() async {
    if (!_available) return;
    try {
      await iap.restorePurchases();
    } catch (_) {
      // best-effort; the next launch's stream re-delivery is the backstop
    }
  }

  /// (Re)queries store product details. No-op when billing is unavailable.
  Future<List<ProductDetails>> loadProducts() async {
    if (!_available) return const <ProductDetails>[];
    try {
      final resp = await iap.queryProductDetails(kBillingProductIds);
      _products
        ..clear()
        ..addEntries(resp.productDetails.map((p) => MapEntry(p.id, p)));
      return resp.productDetails;
    } catch (_) {
      return const <ProductDetails>[];
    }
  }

  /// Priced SKUs for the paywall (real store prices, else reference fallback).
  List<PaywallSku> paywallSkus({String localeTag = 'en'}) =>
      paywallSkusFromProducts(_products, localeTag: localeTag);

  /// The lowest effective per-month price label (the yearly plan's per-month,
  /// with currency + localized "per month"), in the user's REAL store currency
  /// when products are loaded — else the reference fallback. Used by the trial
  /// teaser so it never shows a hardcoded "$1.25/mo".
  String? lowestPerMonthLabel({String localeTag = 'en'}) {
    final skus = paywallSkus(localeTag: localeTag);
    for (final s in skus) {
      if (s.productId == kProductYearly && s.perMonthLabel != null) {
        return s.perMonthLabel;
      }
    }
    return null;
  }

  /// Starts a purchase. All three products (2 subs + lifetime) go through
  /// `buyNonConsumable`. Returns false if billing/product is unavailable.
  Future<bool> buy(String productId) async {
    if (!_available) return false;
    final product = _products[productId];
    if (product == null) return false;
    try {
      return await iap.buyNonConsumable(
        purchaseParam: _buildPurchaseParam(product),
      );
    } catch (e) {
      _events.add(BillingEvent(BillingOutcome.error,
          productId: productId, message: '$e'));
      return false;
    }
  }

  /// Builds the purchase param so the FREE TRIAL actually applies.
  ///
  /// On Android (Play Billing v5) a subscription has a base plan plus offers,
  /// and the 7-day free trial is one of those offers. Buying with a plain
  /// [PurchaseParam] lets Play fall back to the base plan → no trial → the user
  /// is charged immediately. We explicitly pick the offer whose pricing has a
  /// free phase (priceAmountMicros == 0) and pass its offerToken. On iOS,
  /// StoreKit auto-applies the eligible introductory offer, so the plain param
  /// is correct there.
  PurchaseParam _buildPurchaseParam(ProductDetails product) {
    // TRIAL OFF (kFreeTrialEnabled == false): skip the free-trial offer entirely
    // so Play bills the base plan immediately. On iOS StoreKit would still
    // auto-apply an eligible intro offer if one exists in App Store Connect —
    // remove it there to fully disable the trial.
    if (kFreeTrialEnabled && product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers != null) {
        for (final offer in offers) {
          final hasFreeTrial =
              offer.pricingPhases.any((p) => p.priceAmountMicros == 0);
          if (hasFreeTrial) {
            return GooglePlayPurchaseParam(
              productDetails: product,
              offerToken: offer.offerIdToken,
            );
          }
        }
      }
    }
    return PurchaseParam(productDetails: product);
  }

  /// Restores previous purchases (Apple/Google account-bound) AND re-pulls the
  /// server entitlement, so it also surfaces NON-store grants — an admin/comped
  /// grant, a webhook credit, or a purchase that was credited server-side in a
  /// past session (the "paid but never showed up on this device" case). Returns
  /// whether a PAID tier is active afterwards (drives the UI feedback).
  Future<RestoreOutcome> restore() async {
    final seenBefore = _purchasesSeen;
    if (_available) {
      try {
        await iap.restorePurchases();
      } catch (e) {
        _events.add(BillingEvent(BillingOutcome.error, message: '$e'));
      }
    }
    final refresh = _refreshEntitlement;
    if (refresh == null) return RestoreOutcome.nothingToRestore;

    // Poll rather than guess a delay. This used to wait a flat 700 ms and read
    // the entitlement once, but the work it waits on is a store round trip
    // followed by our server verifying the receipt WITH Google — routinely
    // longer than that. The wait ended first, the read said "not paid", and a
    // buyer whose purchase was landing that very second was told there was
    // nothing to restore.
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    var backoff = const Duration(milliseconds: 250);
    while (true) {
      try {
        if (await refresh()) return RestoreOutcome.restored;
      } catch (_) {
        // A failed read is not an answer — keep waiting for the real one.
      }
      if (!DateTime.now().isBefore(deadline)) break;
      await Future<void>.delayed(backoff);
      if (backoff < const Duration(seconds: 2)) backoff *= 2;
    }

    // Nothing became paid. Whether the store had anything to give decides which
    // of the two honest answers the person deserves.
    return _purchasesSeen > seenBefore
        ? RestoreOutcome.purchaseNotApplied
        : RestoreOutcome.nothingToRestore;
  }

  /// Purchases the store has handed back this session (see [RestoreOutcome]).
  int _purchasesSeen = 0;

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final pd in purchases) {
      switch (pd.status) {
        case PurchaseStatus.pending:
          // Not done yet (e.g. "ask to buy"/SCA) — never complete a pending txn.
          //
          // 🔴 ОТЛОЖЕННАЯ ОПЛАТА — ЭТО НЕ ОШИБКА, А ОЖИДАНИЕ (12.08.2026).
          // В Play есть способы оплаты с отсрочкой: наличными в магазине, через
          // оператора. Google создаёт заказ и ждёт доплаты. Прод, 24.07.2026:
          // заказ из Малайзии на secretly_premium_yearly висел неоплаченным —
          // «Ожидается оплата». Мы вели себя ПРАВИЛЬНО (премиум не выдали), но
          // покупателю не сказали НИЧЕГО: событие уходило в поток, на который
          // никто не подписан. Человек заплатить не смог, потому что не знал,
          // что от него ждут. Отметку кладём НА ДИСК — только так о ней можно
          // рассказать после перезапуска.
          _events.add(
              BillingEvent(BillingOutcome.pending, productId: pd.productID));
          await onPendingPurchase?.call(pd.productID);
          break;
        case PurchaseStatus.canceled:
          _events.add(
              BillingEvent(BillingOutcome.canceled, productId: pd.productID));
          // Ожидание закончилось отказом — плашку убрать, иначе она останется
          // висеть навсегда и станет ровно тем, чего просили избежать.
          await onPendingResolved?.call(pd.productID);
          // A canceled txn carries no entitlement; finish it so it clears the
          // queue and does not re-deliver forever.
          await _completeIfNeeded(pd);
          break;
        case PurchaseStatus.error:
          _events.add(BillingEvent(BillingOutcome.error,
              productId: pd.productID, message: pd.error?.message));
          await onPendingResolved?.call(pd.productID);
          await _completeIfNeeded(pd);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // The store owns a purchase for this account. Counting it lets a
          // restore tell "you never bought this" apart from "you bought it and
          // it did not land" — two situations that need opposite advice.
          _purchasesSeen++;
          // Оплата дошла — снять отметку ожидания.
          await onPendingResolved?.call(pd.productID);
          // Attempt the durable server grant (idempotent) and emit the outcome.
          await _deliver(pd);
          // ...then ALWAYS acknowledge/finish a genuine, completed store purchase
          // — decoupled from whether the server grant resolved paid.
          //
          // Google Play MANDATES acknowledge within 3 days for ANY completed
          // purchase; withholding it does NOT protect the buyer — Google
          // AUTO-CANCELS the subscription (its native "Confirm plan / developer
          // hasn't confirmed your purchase" state). The previous code gated
          // acknowledge on a PAID server grant, so a server that could not verify
          // (monetization flag/service-account misconfig, or a 5xx/outage)
          // silently let the buyer's valid subscription auto-cancel and never
          // credited premium. The entitlement grant is retried independently
          // (restore / retryUnfinishedPurchases / webhook / admin), and the
          // verifier grants premium LOCALLY fail-open when the store confirms a
          // purchase but our server can't verify it (CLAUDE.md: "billing fails
          // OPEN"). Acknowledging a real store purchase can never gate a security
          // feature, so this is strictly safe.
          await _completeIfNeeded(pd);
          break;
      }
    }
  }

  Future<void> _completeIfNeeded(PurchaseDetails pd) async {
    // Every finished transaction MUST be completed (iOS finishTransaction /
    // Android acknowledge) so the store stops re-delivering it.
    if (pd.pendingCompletePurchase) {
      try {
        await iap.completePurchase(pd);
      } catch (_) {/* best-effort */}
    }
  }

  /// Runs the injected verifier (S-2 `/redeem`) and returns whether the
  /// entitlement was actually granted. Defaults to FALSE when no verifier is
  /// wired yet (repo still bootstrapping) so the caller leaves the purchase
  /// unfinished for a later retry instead of consuming it without a grant.
  Future<bool> _deliver(PurchaseDetails pd) async {
    bool ok = false;
    final verify = _verify;
    if (verify != null) {
      try {
        ok = await verify(pd);
      } catch (_) {
        ok = false;
      }
    }
    _events.add(BillingEvent(
      pd.status == PurchaseStatus.restored
          ? BillingOutcome.restored
          : BillingOutcome.purchased,
      productId: pd.productID,
      message: ok ? null : 'verify_failed',
    ));
    return ok;
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
