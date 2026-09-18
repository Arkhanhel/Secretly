// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:secretly_app/billing/billing_service.dart';

ProductDetails _pd(String id, String price) => ProductDetails(
      id: id,
      title: id,
      description: '',
      price: price,
      rawPrice: 0,
      currencyCode: 'USD',
    );

ProductDetails _pdFull(
  String id,
  String price,
  double rawPrice, {
  String currencyCode = 'UAH',
  String currencySymbol = '₴', // ₴
}) =>
    ProductDetails(
      id: id,
      title: id,
      description: '',
      price: price,
      rawPrice: rawPrice,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
    );

void main() {
  group('paywallSkusFromProducts (C-2)', () {
    test('yearly per-month + struck original match the store price FORMAT '
        '(symbol side, comma decimal, grouping) — not "₴90.92"', () {
      final products = <String, ProductDetails>{
        kProductMonthly: _pdFull(kProductMonthly, '144,99 ₴', 144.99),
        kProductYearly: _pdFull(kProductYearly, '1 090,99 ₴', 1090.99),
      };
      final skus = paywallSkusFromProducts(products, localeTag: 'ru');
      final yearly = skus.firstWhere((s) => s.productId == kProductYearly);
      final perMonth = yearly.perMonthLabel!;
      // 1090.99 / 12 ≈ 90.92 → "90,92 ₴…" : comma decimal, symbol AFTER the
      // number (like the monthly card) — NOT NumberFormat's "₴90.92".
      expect(perMonth, contains('90,92'));
      expect(perMonth, isNot(contains('90.92')));
      expect(perMonth.indexOf('₴'), greaterThan(perMonth.indexOf('90,92')));
      // Struck original = 12× monthly = 1739.88 → grouped "1 739,88".
      expect(yearly.originalPriceLabel, contains('739,88'));
    });

    test('no store products -> three reference SKUs with fallback prices', () {
      final skus = paywallSkusFromProducts(const {}, localeTag: 'en');
      expect(skus.length, 3);
      expect(
        skus.map((s) => s.productId).toList(),
        [kProductMonthly, kProductYearly, kProductLifetime],
      );
      expect(
        skus.firstWhere((s) => s.productId == kProductYearly).priceLabel,
        r'$14.99',
      );
    });

    test('store prices override reference; missing product falls back', () {
      final products = {
        kProductMonthly: _pd(kProductMonthly, 'RUB 199'),
        kProductYearly: _pd(kProductYearly, 'RUB 1 990'),
        // lifetime intentionally absent from the store response
      };
      final skus = paywallSkusFromProducts(products, localeTag: 'ru');
      expect(
        skus.firstWhere((s) => s.productId == kProductMonthly).priceLabel,
        'RUB 199',
      );
      expect(
        skus.firstWhere((s) => s.productId == kProductYearly).priceLabel,
        'RUB 1 990',
      );
      // Not returned by the store -> keep the TZ reference price.
      expect(
        skus.firstWhere((s) => s.productId == kProductLifetime).priceLabel,
        r'$29.99',
      );
    });

    test('yearly stays highlighted regardless of price source', () {
      final withStore = paywallSkusFromProducts(
        {kProductYearly: _pd(kProductYearly, '€9')},
        localeTag: 'en',
      );
      expect(
        withStore.firstWhere((s) => s.productId == kProductYearly).highlighted,
        isTrue,
      );
      final fallback = paywallSkusFromProducts(const {}, localeTag: 'en');
      expect(
        fallback.firstWhere((s) => s.productId == kProductYearly).highlighted,
        isTrue,
      );
    });

    test('product id set matches the three store SKUs', () {
      expect(kBillingProductIds,
          {kProductMonthly, kProductYearly, kProductLifetime});
    });
  });
}
