// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПОВТОР ПОДПИСАННОГО ЗАПРОСА ПОСЛЕ ОТКАЗА ПО ВРЕМЕНИ.
//
// Фоновый изолят начинает с нулевой поправкой часов. Поле 17.09.2026: реле за
// сутки отвергло 1999 запросов 154 устройств с `timestamp out of range`, самое
// шумное — дата на день вперёд. Тесты сторожат, что повтор бывает ровно тогда,
// когда отказ про время, и ровно один.

import 'dart:io' show HttpDate;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:secretly_app/push/clock_retry.dart';
import 'package:secretly_app/transport/server_clock.dart';

/// Сервер, чьи часы сдвинуты на [shift] относительно устройства. Как реле,
/// отвергает метку, разошедшуюся с его временем больше чем на пять минут.
class _Server {
  _Server(this.shift, {this.rejectAll = false});

  final Duration shift;
  final bool rejectAll;
  final stamps = <int>[];

  Future<http.Response> send(int tsMs, bool isRetry) async {
    stamps.add(tsMs);
    final now = DateTime.now().toUtc().add(shift);
    final headers = {'date': HttpDate.format(now)};
    final stale = (tsMs - now.millisecondsSinceEpoch).abs() > 5 * 60 * 1000;
    if (stale || rejectAll) return http.Response('', 401, headers: headers);
    return http.Response('{"items":[]}', 200, headers: headers);
  }
}

void main() {
  setUp(() => ServerClock.instance.resetForTest());
  tearDown(() => ServerClock.instance.resetForTest());

  test('здоровые часы — один запрос, без повтора', () async {
    final server = _Server(Duration.zero);
    final resp = await sendSignedWithClockRetry(server.send);
    expect(resp.statusCode, 200);
    expect(server.stamps, hasLength(1));
  });

  test('🔴 дата на день вперёд (поле 17.09) — повтор проходит', () async {
    // Устройство спешит на 24 ч 03,6 мин — сервер «отстаёт» на столько же.
    final server = _Server(
      const Duration(hours: -24, minutes: -3, seconds: -36),
    );
    final resp = await sendSignedWithClockRetry(server.send);
    expect(resp.statusCode, 200, reason: 'повтор с поправкой должен пройти');
    expect(server.stamps, hasLength(2));
    expect(ServerClock.instance.hasSkew, isTrue);
  });

  test('часы отстали на час — повтор проходит', () async {
    final server = _Server(const Duration(hours: 1));
    final resp = await sendSignedWithClockRetry(server.send);
    expect(resp.statusCode, 200);
    expect(server.stamps, hasLength(2));
  });

  test('отказ не про время — без повтора', () async {
    // Метка сошлась с сервером: 401 значит «неизвестное устройство» или
    // подпись, и новая метка тут не поможет.
    final server = _Server(Duration.zero, rejectAll: true);
    final resp = await sendSignedWithClockRetry(server.send);
    expect(resp.statusCode, 401);
    expect(server.stamps, hasLength(1));
  });

  test('🔴 повтор ровно один, даже если и он отвергнут', () async {
    final server = _Server(const Duration(hours: 1), rejectAll: true);
    final resp = await sendSignedWithClockRetry(server.send);
    expect(resp.statusCode, 401);
    expect(server.stamps, hasLength(2));
  });

  test('сдвиг больше недели — повтор бесполезен и не делается', () async {
    final server = _Server(const Duration(days: 8));
    final resp = await sendSignedWithClockRetry(server.send);
    expect(resp.statusCode, 401);
    expect(server.stamps, hasLength(1));
    expect(ServerClock.instance.offsetMs, 0);
  });

  test('401 без заголовка Date — без повтора', () async {
    var calls = 0;
    final resp = await sendSignedWithClockRetry((tsMs, isRetry) async {
      calls++;
      return http.Response('', 401);
    });
    expect(resp.statusCode, 401);
    expect(calls, 1);
  });

  test('🔴 медленный отказ — без повтора: бюджет прохода важнее', () async {
    var calls = 0;
    final serverNow = DateTime.now().toUtc().add(const Duration(hours: 1));
    final resp = await sendSignedWithClockRetry(
      (tsMs, isRetry) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 60));
        return http.Response('', 401, headers: {'date': HttpDate.format(serverNow)});
      },
      retryOnlyWithin: const Duration(milliseconds: 20),
    );
    expect(resp.statusCode, 401);
    expect(calls, 1);
  });

  test('повтор помечен — фоновый проход сокращает ему таймаут', () async {
    final flags = <bool>[];
    final server = _Server(const Duration(hours: 1));
    await sendSignedWithClockRetry((tsMs, isRetry) {
      flags.add(isRetry);
      return server.send(tsMs, isRetry);
    });
    expect(flags, [false, true]);
  });

  test('выученная поправка сразу идёт в следующий запрос изолята', () async {
    final server = _Server(const Duration(minutes: 30));
    await sendSignedWithClockRetry(server.send);
    final next = await sendSignedWithClockRetry(server.send);
    expect(next.statusCode, 200);
    expect(
      server.stamps,
      hasLength(3),
      reason: 'второй вызов должен уйти сразу с поправкой, без отказа',
    );
  });
}
