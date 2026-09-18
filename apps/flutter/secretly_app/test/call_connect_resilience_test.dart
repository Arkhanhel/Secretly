// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ЗВОНОК НЕ ДОЛЖЕН УМИРАТЬ ОТ ОДНОГО ОТКАЗА СЕТИ.
//
// Поле 24.08.2026, звонок с iPhone на Android: трубку взяли, экран разговора
// открылся — а звонящий продолжал слушать гудки до самого таймаута. Причина
// сшивается из трёх звеньев, и каждое звено сторожит свой тест ниже.
//
// ① Принявшая сторона пошла за бандлом собеседника, чтобы зашифровать ОТВЕТ, и
//    получила `429 rate_limited`: бакет сервера ключей считается ПО IP, и два
//    устройства за одним Wi-Fi делят его с фоновой перепрёркой бандлов.
// ② Запрос бандла делал РОВНО ОДНУ попытку, хотя бакет восстанавливается два
//    запроса в секунду — повтор через полсекунды прошёл бы.
// ③ Страховка повторов `need_offer` включалась ТОЛЬКО при успешной отправке,
//    то есть ровно тогда, когда она не нужна. Первый же отказ оставлял звонок
//    без единого повтора.
//
// Тесты читают ИСХОДНИК: все три поломки беззвучны — ничего не падает и не
// печатает ошибку, звонок просто не соединяется. Такое ловится только чтением
// структуры, а не прогоном.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final callManager = File('lib/calls/call_manager.dart').readAsStringSync();
  final controller = File('lib/app/app_controller.dart').readAsStringSync();

  /// Тело функции [name] от её начала до начала следующей функции.
  String bodyOf(String source, String name) {
    final start = source.indexOf(name);
    expect(start, greaterThan(0), reason: 'не найдено в исходнике: $name');
    final end = source.indexOf('\n  Future<', start + name.length);
    final end2 = source.indexOf('\n  void ', start + name.length);
    final stop = <int>[
      end,
      end2,
      source.length,
    ].where((v) => v > 0).reduce((a, b) => a < b ? a : b);
    return source.substring(start, stop);
  }

  test('③ повторы need_offer запускаются И ПРИ ПРОВАЛЕ отправки', () {
    final body = bodyOf(callManager, 'Future<void> _requestOfferRecovery(');

    expect(
      body.contains('_startNeedOfferRetries'),
      isTrue,
      reason: 'запрос переигровки оффера остался вообще без повторов',
    );

    // Ключевая проверка: запуск повторов стоит в finally, а не внутри try.
    // Если вернуть его в try — первый же отказ снова убьёт звонок молча.
    final finallyAt = body.indexOf('} finally {');
    final retriesAt = body.indexOf('_startNeedOfferRetries');
    expect(
      finallyAt,
      greaterThan(0),
      reason: 'у отправки need_offer нет finally — страховка снова зависит '
          'от успеха отправки',
    );
    expect(
      retriesAt,
      greaterThan(finallyAt),
      reason: 'повторы need_offer запускаются внутри try: при отказе '
          '(например 429 от сервера ключей) звонок останется без повторов, '
          'а звонящий — с гудками в пустоту',
    );
  });

  test('② запрос бандла повторяется при отказе по лимиту', () {
    final body = bodyOf(controller, 'Future<List<Map<String, Object?>>> _fetchBundleAuthed(');

    expect(
      body.contains('rate_limited'),
      isTrue,
      reason: 'запрос бандла не отличает отказ по лимиту от прочих ошибок',
    );
    expect(
      body.contains('rateLimitRetryDelaysMs'),
      isTrue,
      reason: 'у запроса бандла снова одна попытка: 429 в момент звонка '
          'оставит ответ незашифрованным',
    );

    // Паузы должны быть короткими — звонок ждать не может.
    final delays = RegExp(r'rateLimitRetryDelaysMs = <int>\[([^\]]+)\]')
        .firstMatch(body)
        ?.group(1);
    expect(delays, isNotNull, reason: 'не найден список пауз между повторами');
    final values = delays!
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .where((v) => v > 0)
        .toList();
    expect(values.length, greaterThanOrEqualTo(2),
        reason: 'одного повтора мало: бакет делят два устройства');
    expect(values.reduce((a, b) => a + b), lessThanOrEqualTo(5000),
        reason: 'повторы тянутся дольше пяти секунд — звонок столько не ждёт');
  });

  test('① фоновая перепроверка бандлов уступает звонку', () {
    final body = bodyOf(controller, 'Future<void> _bundleRevalidationWatchdogTick(');

    expect(
      body.contains('callPriorityActive'),
      isTrue,
      reason: 'перепроверка бандлов снова ходит за ключами во время звонка и '
          'вычерпывает общий по IP бакет',
    );

    // Уступка обязана стоять ДО отметки тика: иначе тик засчитается
    // выполненным и настоящая перепроверка отложится ещё на минуту.
    final yieldAt = body.indexOf('callPriorityActive');
    final markAt = body.indexOf('_bundleRevalidationLastTickAtMs = now');
    expect(markAt, greaterThan(0), reason: 'не найдена отметка тика');
    expect(
      yieldAt,
      lessThan(markAt),
      reason: 'уступка звонку стоит после отметки тика — перепроверка будет '
          'пропущена не только на время звонка',
    );
  });

  test('окно приоритета звонка открывается на всех шагах звонка', () {
    for (final entry in <String, String>{
      'Future<void> startCall(': 'исходящий звонок',
      'Future<void> acceptIncoming(': 'принятие входящего',
      'void _enqueueSignal(': 'входящий сигнал звонка',
      'Future<void> processStartupCallHint(': 'холодный старт из пуша',
    }.entries) {
      final body = bodyOf(callManager, entry.key);
      expect(
        body.contains('markCallPriorityWindow'),
        isTrue,
        reason: '${entry.value}: окно приоритета не открывается, значит '
            'фоновая работа продолжит отбирать бакет у звонка',
      );
    }
  });

  test('отказ сети не выдаётся за отсутствие устройств у собеседника', () {
    expect(
      controller.contains('transientSkips'),
      isTrue,
      reason: 'временный отказ снова превращается в «no deliverable target '
          'devices» — сообщение о ПОСТОЯННОЙ причине на месте временной',
    );
  });
}
