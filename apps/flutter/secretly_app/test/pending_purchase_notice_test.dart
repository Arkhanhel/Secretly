// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/billing/pending_purchase_notice.dart';

// Отметка «ожидается оплата». Прод 24.07.2026: заказ из Малайзии висел
// неоплаченным, премиум мы правильно не выдали — но покупателю не сказали
// ничего, и он не заплатил, потому что не знал, что от него ждут.
void main() {
  test('переживает запись и чтение', () {
    const n = PendingPurchaseNotice(
      productId: 'secretly_premium_yearly',
      startedAtMs: 1700000000000,
      toastShown: false,
    );
    final back = PendingPurchaseNotice.tryDecode(n.encode())!;
    expect(back.productId, 'secretly_premium_yearly');
    expect(back.startedAtMs, 1700000000000);
    expect(back.toastShown, isFalse);
  });

  test('🔴 подсказка показывается ОДИН раз', () {
    // Иначе она полезет при каждом запуске — ровно то, чего просили избежать.
    const n = PendingPurchaseNotice(
      productId: 'p',
      startedAtMs: 1,
      toastShown: false,
    );
    expect(n.toastShown, isFalse);
    expect(n.markToastShown().toastShown, isTrue);
    // Отметка о показе тоже обязана переживать перезапуск.
    expect(
      PendingPurchaseNotice.tryDecode(n.markToastShown().encode())!.toastShown,
      isTrue,
    );
  });

  test('🔴 умеет исчезнуть сама', () {
    // Play отменяет неоплаченный заказ примерно через трое суток. Плашка,
    // которая не истекает, превращается в вечный мусор на экране.
    const n = PendingPurchaseNotice(
      productId: 'p',
      startedAtMs: 0,
      toastShown: true,
    );
    expect(n.isExpired(PendingPurchaseNotice.maxAgeMs - 1), isFalse);
    expect(n.isExpired(PendingPurchaseNotice.maxAgeMs), isTrue);
  });

  test('мусор не ломает экран оплаты', () {
    expect(PendingPurchaseNotice.tryDecode(null), isNull);
    expect(PendingPurchaseNotice.tryDecode(''), isNull);
    expect(PendingPurchaseNotice.tryDecode('не json'), isNull);
    expect(PendingPurchaseNotice.tryDecode('[]'), isNull);
    expect(PendingPurchaseNotice.tryDecode('{"product_id":""}'), isNull);
    expect(
      PendingPurchaseNotice.tryDecode('{"product_id":"p","started_at_ms":0}'),
      isNull,
    );
  });
}
