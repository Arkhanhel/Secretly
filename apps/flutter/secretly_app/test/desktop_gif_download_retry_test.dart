// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/ui/desktop/chat/gif_picker_tab.dart';

// 🔴 ГИФКА НА КОМПЬЮТЕРЕ ГИБЛА ОТ СЕКУНДНОГО ПРОВАЛА МАРШРУТА (17.09.2026).
//
// Одна попытка, и при полной сетке — ни слова о неудаче. Как на телефоне
// (`a4004ccd`): три попытки для сетевых сбоев и 5xx, 404 — сразу.

const _url = 'https://media3.giphy.com/media/x/giphy.gif';

void main() {
  Future<http.Response> download(
    Future<http.Response> Function(http.Request) handler,
  ) {
    return http.runWithClient(
      () => downloadGifWithRetry(
        _url,
        isAlive: () => true,
        backoff: const <Duration>[Duration.zero, Duration.zero],
      ),
      () => MockClient(handler),
    );
  }

  test('🔴 пропавший маршрут переживается повтором', () async {
    var calls = 0;
    final resp = await download((_) async {
      calls++;
      if (calls < 3) {
        throw const SocketException('No route to host (OS Error, errno = 113)');
      }
      return http.Response.bytes(<int>[1, 2, 3], 200);
    });
    expect(resp.statusCode, 200);
    expect(calls, 3);
  });

  test('5xx повторяется, 404 — нет', () async {
    var calls = 0;
    final ok = await download((_) async {
      calls++;
      return calls == 1 ? http.Response('', 503) : http.Response('gif', 200);
    });
    expect(ok.statusCode, 200);
    expect(calls, 2);

    calls = 0;
    await expectLater(
      download((_) async {
        calls++;
        return http.Response('', 404);
      }),
      throwsA(isA<HttpException>()),
    );
    expect(calls, 1, reason: 'гифки больше нет — повтор не поможет');
  });

  test('три неудачи подряд — последняя ошибка наружу', () async {
    var calls = 0;
    await expectLater(
      download((_) async {
        calls++;
        throw http.ClientException('connection reset');
      }),
      throwsA(isA<http.ClientException>()),
    );
    expect(calls, 3);
  });

  test('экран закрыли — повторы прекращаются', () async {
    var calls = 0;
    await expectLater(
      http.runWithClient(
        () => downloadGifWithRetry(
          _url,
          isAlive: () => false,
          backoff: const <Duration>[Duration.zero, Duration.zero],
        ),
        () => MockClient((_) async {
          calls++;
          throw const SocketException('offline');
        }),
      ),
      throwsA(isA<SocketException>()),
    );
    expect(calls, 1);
  });

  test('сетевой класс ошибок', () {
    expect(gifDownloadIsWorthRetrying(const SocketException('x')), isTrue);
    expect(gifDownloadIsWorthRetrying(http.ClientException('x')), isTrue);
    expect(gifDownloadIsWorthRetrying(const HttpException('HTTP 404')), isFalse);
    expect(gifDownloadIsWorthRetrying(StateError('x')), isFalse);
  });

  test('неудача выбора видна и при полной сетке', () {
    final src = File(
      'lib/ui/desktop/chat/gif_picker_tab.dart',
    ).readAsStringSync();
    expect(src.contains('if (_pickFailed) _pickFailureBanner(c),'), isTrue);
    expect(src.contains('attachmentActionGeneric'), isTrue);
  });
}
