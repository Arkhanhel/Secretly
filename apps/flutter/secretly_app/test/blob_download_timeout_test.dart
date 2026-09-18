// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/blob_client.dart';

/// СКАЧИВАНИЕ БЕЗ ПРЕДЕЛА ОЖИДАНИЯ (найдено 02.09.2026, аудит передачи файлов).
///
/// У скачивания блоба не было таймаута вовсе. Зависшая TCP-сессия держала
/// вызывающего в состоянии «загружается» бесконечно: предзагрузка вложений с
/// её четырьмя попытками при таком зависании не доходила даже до второй, а
/// кольцо загрузки не двигалось и не гасло.
///
/// Лечение НЕ общим пределом на скачивание: сервер не поддерживает докачку с
/// середины, поэтому обрыв на девяноста процентах означает качать всё заново —
/// общий предел рубил бы честные большие файлы на медленной связи. Сторож
/// считает паузу МЕЖДУ кусками: пока данные идут, хоть по чуть-чуть,
/// скачивание живо.
///
/// 🔴 ВРЕМЯ ВИРТУАЛЬНОЕ (04.09.2026). Первая редакция ждала по-настоящему —
/// `Future.delayed` на сотни миллисекунд. Под нагрузкой (например, когда рядом
/// идёт сборка) такие тесты плывут и падают на ровном месте: один такой провал
/// уже случился и заставил перепроверять исправный код. Здесь время двигает
/// `fakeAsync`, поэтому прогон одинаков и на свободной машине, и на занятой.
void main() {
  const stall = Duration(milliseconds: 120);

  Stream<List<int>> guarded(Stream<List<int>> source) => source.timeout(
        stall,
        onTimeout: (sink) =>
            sink.addError(TimeoutException('blob download stalled', stall)),
      );

  group('сторож тишины при скачивании', () {
    test('🔴 молчащий поток обрывается, а не висит вечно', () {
      fakeAsync((async) {
        final controller = StreamController<List<int>>();
        Object? caught;
        guarded(controller.stream)
            .listen((_) {}, onError: (Object e) => caught = e);

        async.elapse(const Duration(milliseconds: 119));
        expect(caught, isNull, reason: 'предел ещё не вышел');

        async.elapse(const Duration(milliseconds: 2));
        expect(
          caught,
          isA<TimeoutException>(),
          reason: 'зависшая сессия обязана оборваться, иначе вызывающий '
              'остаётся в состоянии «загружается» навсегда',
        );
        controller.close();
        async.flushMicrotasks();
      });
    });

    test('🔴 медленный, но живой поток НЕ обрывается', () {
      fakeAsync((async) {
        final controller = StreamController<List<int>>();
        Object? caught;
        var received = 0;
        guarded(controller.stream)
            .listen((_) => received++, onError: (Object e) => caught = e);

        // Кусок реже, чем половина предела, но чаще самого предела: связь
        // медленная, однако живая. Общий таймаут такой файл бы убил.
        for (var i = 0; i < 6; i++) {
          async.elapse(const Duration(milliseconds: 70));
          controller.add(<int>[1, 2, 3]);
          async.flushMicrotasks();
        }

        expect(received, 6);
        expect(
          caught,
          isNull,
          reason: 'пока данные идут, скачивание живо — медленная загрузка '
              'не повод её рвать',
        );
        controller.close();
        async.flushMicrotasks();
      });
    });

    test('пауза отсчитывается заново от каждого куска', () {
      fakeAsync((async) {
        final controller = StreamController<List<int>>();
        Object? caught;
        guarded(controller.stream)
            .listen((_) {}, onError: (Object e) => caught = e);

        async.elapse(const Duration(milliseconds: 90));
        controller.add(<int>[1]); // сбрасывает отсчёт
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 90));
        expect(
          caught,
          isNull,
          reason: 'суммарно 180 мс при пределе 120 мс, но каждая пауза короче',
        );

        async.elapse(const Duration(milliseconds: 120));
        expect(caught, isA<TimeoutException>());
        controller.close();
        async.flushMicrotasks();
      });
    });
  });

  group('боевые величины', () {
    test('предел ожидания заголовков разумен', () {
      expect(
        BlobClient.downloadHeadersTimeout.inSeconds,
        inInclusiveRange(15, 60),
        reason: 'меньше — рвём медленный ответ сервера, больше — снова '
            'приближаемся к «висит вечно»',
      );
    });

    test('🔴 сторож тишины НЕ является общим пределом скачивания', () {
      // Ключевое свойство правки. Если эту величину когда-нибудь начнут
      // трактовать как «сколько всего качать», большие вложения на медленной
      // связи снова начнут срываться — теперь уже на скачивании, ровно как
      // раньше срывались на отправке.
      expect(
        BlobClient.downloadStallTimeout.inSeconds,
        lessThan(BlobClient.uploadTimeoutFor(200 * 1024 * 1024).inSeconds),
        reason: 'сторож тишины заведомо короче времени, нужного большому '
            'файлу целиком — значит он и не может быть общим пределом',
      );
      expect(BlobClient.downloadStallTimeout.inSeconds, greaterThanOrEqualTo(30));
    });
  });
}
