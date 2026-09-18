// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/resilient_http_client.dart';

// SEC-13 (26.08.2026). `package:http` по умолчанию идёт за редиректом молча.
//
// Наши эндпоинты редиректов не возвращают — проверено по коду обоих серверов, —
// поэтому редирект означает ровно одно: ответ пришёл не от нас. Перехвата так
// не устроить (TLS для нового адреса проверяется честно), но увести запрос
// можно на любой домен, где у уводящего есть валидный сертификат, — а запрос
// уносит подпись устройства и тело.
//
// 🔴 Тест поднимает НАСТОЯЩИЙ сервер и смотрит, постучались ли в цель
// редиректа. Проверять поле `followRedirects` на объекте запроса значило бы
// проверять собственную реализацию, а не поведение.
//
// `HttpOverrides.runZoned` здесь обязателен: `TestWidgetsFlutterBinding`
// подменяет `HttpClient` заглушкой, которая отвечает 400 на всё, — чтобы тесты
// не ходили в сеть. Без снятия заглушки этот тест зеленел бы на любом коде,
// включая сломанный: 400 — это не 200, значит «за редиректом не пошли».

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 клиент НЕ идёт за редиректом', () async {
    await withRealHttp(() async {
      await _redirectIsNotFollowed();
    });
  });

  test('обычный ответ проходит как прежде', () async {
    // Обратная защёлка: запрет редиректов не имеет права мешать нормальной
    // работе. Без неё «защита» могла бы просто ломать все запросы.
    await withRealHttp(() async {
      await _plainResponseStillWorks();
    });
  });
}

/// Снимает сетевую заглушку тестового окружения на время [body].
///
/// 🔴 Именно СНИМАЕТ, а не подменяет своей фабрикой. Фабрика, вызывающая
/// `HttpClient()`, уходит в бесконечную рекурсию: конструктор снова спрашивает
/// `HttpOverrides.current`, а там всё ещё она сама. Проверено — Stack Overflow.
/// Пустой наследник отдаёт настоящий клиент реализацией из базового класса —
/// она конструирует его напрямую, минуя поиск переопределений.
Future<void> withRealHttp(Future<void> Function() body) =>
    HttpOverrides.runWithHttpOverrides<Future<void>>(body, _RealHttp());

/// Поведение по умолчанию: `HttpOverrides.createHttpClient` базового класса
/// возвращает штатный `HttpClient` без обращения к зоне.
class _RealHttp extends HttpOverrides {}

Future<void> _redirectIsNotFollowed() async {
  var targetHits = 0;
  final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaitedServe(target, (req) {
    targetHits++;
    req.response.statusCode = 200;
    req.response.write('секрет уехал не туда');
  });

  final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaitedServe(source, (req) {
    req.response.statusCode = 302;
    req.response.headers.set(
      'location',
      'http://127.0.0.1:${target.port}/moved',
    );
  });

  final client = createResilientHttpClient();
  try {
    final resp = await client.get(
      Uri.parse('http://127.0.0.1:${source.port}/start'),
    );
    expect(
      resp.statusCode,
      302,
      reason: 'редирект обязан вернуться вызывающему, а не быть пройденным',
    );
    expect(
      targetHits,
      0,
      reason: 'запрос ушёл на чужой хост — ровно то, что SEC-13 запрещает',
    );
  } finally {
    client.close();
    await source.close(force: true);
    await target.close(force: true);
  }
}

Future<void> _plainResponseStillWorks() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaitedServe(server, (req) {
    req.response.statusCode = 200;
    req.response.write('ok');
  });

  final client = createResilientHttpClient();
  try {
    final resp = await client.get(
      Uri.parse('http://127.0.0.1:${server.port}/plain'),
    );
    expect(resp.statusCode, 200);
    expect(resp.body, 'ok');
  } finally {
    client.close();
    await server.close(force: true);
  }
}

void unawaitedServe(HttpServer server, void Function(HttpRequest) handle) {
  server.listen((req) async {
    handle(req);
    await req.response.close();
  });
}
