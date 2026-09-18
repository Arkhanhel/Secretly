// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;

import '../transport/server_clock.dart';

/// Насколько метка может разойтись с `Date` ответа, чтобы отказ ещё не
/// считался отказом по времени. Сервер терпит пять минут; минута запаса —
/// на точность заголовка (секунды) и дорогу до сервера. Исправленная метка
/// расходится с `Date` на секунды.
const int _stampTrustedDriftMs = 4 * 60 * 1000;

/// Подписанный запрос фонового прохода с одним повтором после отказа по времени.
///
/// 🔴 ЗАЧЕМ. Фоновый изолят начинает с нулевой поправкой часов: памяти главного
/// изолята у него нет. Устройство со сбитыми часами получало на первый же
/// запрос 401 `timestamp out of range`, и на этом проход заканчивался: пуш будил
/// телефон впустую, конверты лежали на реле до открытия приложения. Поле
/// 17.09.2026: 154 устройства за сутки, сдвиги от 10 минут до суток.
///
/// [send] подписывает запрос переданной меткой и отправляет его; `isRetry`
/// говорит, что это повтор (фоновому проходу — повод сократить таймаут).
/// Повтор — ровно один и только когда:
/// * ответ 401 пришёл не дольше чем за [retryOnlyWithin] — медленный отказ
///   значит плохую сеть, и повтор лишь съел бы бюджет прохода;
/// * в ответе есть `Date`;
/// * метка первого запроса разошлась с `Date` больше чем на четыре минуты, то
///   есть отказ действительно про время, а не про устройство или подпись;
/// * поправка из этого `Date` принята и новая метка с ним сходится (сдвиг
///   больше границы [ServerClock] не принимается — тогда повтор бесполезен).
Future<http.Response> sendSignedWithClockRetry(
  Future<http.Response> Function(int tsMs, bool isRetry) send, {
  Duration retryOnlyWithin = const Duration(seconds: 3),
}) async {
  final clock = ServerClock.instance;
  final firstTsMs = clock.nowMs();
  final watch = Stopwatch()..start();
  final first = await send(firstTsMs, false);
  if (first.statusCode != 401) return first;
  if (watch.elapsed > retryOnlyWithin) return first;

  final raw = first.headers['date'];
  if (raw == null || raw.isEmpty) return first;
  final DateTime serverTime;
  try {
    serverTime = HttpDate.parse(raw);
  } catch (_) {
    return first;
  }
  final serverMs = serverTime.millisecondsSinceEpoch;
  if ((firstTsMs - serverMs).abs() <= _stampTrustedDriftMs) return first;

  // Обёртка HTTP уже учла этот `Date`. Повторное наблюдение того же ответа
  // ничего не портит, а помощнику не нужно полагаться на обёртку.
  clock.observeServerDate(serverTime);
  final retryTsMs = clock.nowMs();
  if ((retryTsMs - serverMs).abs() > _stampTrustedDriftMs) return first;
  return send(retryTsMs, true);
}
