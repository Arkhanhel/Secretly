// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

/// Отметка «Play/App Store ждёт доплаты», живущая на диске.
///
/// 🔴 ЗАЧЕМ ОНА ЕСТЬ. Прод, 24.07.2026: заказ из Малайзии на
/// `secretly_premium_yearly` висел со статусом «Ожидается оплата». Мы вели себя
/// правильно — премиум за неоплаченный заказ не выдали, это проверено и на
/// сервере, и на клиенте. Но покупателю не сказали НИЧЕГО: событие уходило в
/// поток, на который никто не подписан, и текста про ожидание не было ни на
/// одном языке. Человек не заплатил, потому что не знал, что от него ждут.
///
/// Отложенная оплата (наличными в магазине, через оператора) длится ДНЯМИ и
/// обязана переживать перезапуск — поэтому отметка на диске, а не в потоке.
class PendingPurchaseNotice {
  const PendingPurchaseNotice({
    required this.productId,
    required this.startedAtMs,
    required this.toastShown,
  });

  final String productId;
  final int startedAtMs;

  /// Всплывающую подсказку показываем РОВНО ОДИН РАЗ на заказ.
  ///
  /// Тихая полоска на экране премиума остаётся, пока ожидание не кончится, —
  /// это и есть «не надоедает»: напоминание там, где человек сам его ищет, а не
  /// выскакивающее при каждом запуске.
  final bool toastShown;

  /// Сколько ждём, прежде чем забыть отметку самостоятельно.
  ///
  /// Play отменяет неоплаченный заказ примерно через трое суток. Берём неделю с
  /// запасом: плашка, которая не умеет исчезнуть, превращается ровно в то, чего
  /// просили избежать.
  static const int maxAgeMs = 7 * 24 * 60 * 60 * 1000;

  bool isExpired(int nowMs) => nowMs - startedAtMs >= maxAgeMs;

  PendingPurchaseNotice markToastShown() => PendingPurchaseNotice(
        productId: productId,
        startedAtMs: startedAtMs,
        toastShown: true,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'product_id': productId,
        'started_at_ms': startedAtMs,
        'toast_shown': toastShown,
      };

  /// Разбор терпим к мусору: испорченная отметка не должна ломать экран оплаты.
  static PendingPurchaseNotice? tryDecode(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      final pid = ((json['product_id'] as Object?)?.toString() ?? '').trim();
      final started = (json['started_at_ms'] as num?)?.toInt() ?? 0;
      if (pid.isEmpty || started <= 0) return null;
      return PendingPurchaseNotice(
        productId: pid,
        startedAtMs: started,
        toastShown: json['toast_shown'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}
