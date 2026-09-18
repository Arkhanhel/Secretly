// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Opens the paywall (TZ-MONETIZE-01 §C-2/§C-4) wired to live billing.
//
// Lives in lib/billing/ (not paywall_screen.dart) so the paywall widget itself
// stays billing-free and the import graph is one-directional
// (billing → paywall, never the reverse).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/paywall_screen.dart';
import '../ui/wave1_l10n.dart';
import 'billing_service.dart';

const String _kPrivacyUrl = 'https://www.secretlyapp.com/privacy-policy';
const String _kTermsUrl = 'https://www.secretlyapp.com/terms-of-service';

/// Loads store prices, then pushes the paywall with purchase/restore wired to
/// [BillingService]. Falls back to reference prices when billing is unavailable
/// (pre-store-config / unsupported platform), so it is always safe to call.
Future<void> showPaywall(BuildContext context, PaywallTrigger trigger) async {
  final billing = BillingService.instance;
  // Best-effort price refresh; no-op if billing isn't available.
  await billing.loadProducts();
  if (!context.mounted) return;
  final localeTag = wave1LocaleTagFromContext(context);
  // Отложенная оплата: магазин создал заказ и ждёт доплаты. Экрану отдаём
  // простые данные, а не модель — он остаётся биллинг-независимым.
  final pending = await billing.pendingNoticeReader?.call();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PaywallScreen(
        trigger: trigger,
        pendingPayment: pending != null,
        pendingPaymentToastShown: pending?.toastShown ?? true,
        onPendingPaymentToastShown: () {
          unawaited(billing.pendingToastMarker?.call());
        },
        skus: billing.paywallSkus(localeTag: localeTag),
        onPurchase: (sku) => billing.buy(sku.productId),
        onRestore: billing.restore,
        onOpenTerms: () => _openUrl(_kTermsUrl),
        onOpenPrivacy: () => _openUrl(_kPrivacyUrl),
      ),
    ),
  );
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {/* ignore — links are best-effort */}
}
