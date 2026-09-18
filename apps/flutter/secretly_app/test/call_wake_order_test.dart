// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПОРЯДОК ЗАПУСКА НА ПУТИ ЗВОНКА.
//
// Экран входящего звонка строится из самого пуша: подсказка лежит в
// SharedPreferences, и `_seedIncomingFromHint` разворачивает её в состояние без
// единого сетевого вызова. Всё, что стоит ПЕРЕД этим разворотом, человек ждёт,
// глядя на пустую главную страницу.
//
// Замер поля 22.08.2026: пуш ушёл в 15:47:54, устройство впервые обратилось к
// реле в 15:48:27 — тридцать три секунды, потому что перед показом экрана
// стояли Firebase, выборка ящика и общая синхронизация.
//
// Тест сторожит ПОРЯДОК в исходнике, а не поведение: перестановка этих строк
// беззвучна — она ничего не ломает и не падает, просто снова отодвигает экран
// за сеть. Такое ловится только чтением порядка.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Позиция первого вхождения [needle] в [haystack] или -1.
int _at(String haystack, String needle) => haystack.indexOf(needle);

void main() {
  final source = File('lib/main.dart').readAsStringSync();

  test('холодный старт: экран звонка поднимается до сети и до Firebase', () {
    final start = source.indexOf('Future<void> _initPushRuntime');
    expect(start, greaterThan(0), reason: 'функция запуска пушей не найдена');
    final end = source.indexOf('Future<void> _restart()', start);
    final body = source.substring(start, end > 0 ? end : source.length);

    final hint = _at(body, 'processStartupCallHint');
    final firebase = _at(body, 'PushWakeService.initialize()');
    final pump = _at(body, 'pumpInboxForCallWake');
    final sync = _at(body, 'triggerPushWakeSync');

    expect(hint, greaterThan(0), reason: 'подсказка звонка здесь не разбирается');
    expect(hint, lessThan(firebase),
        reason: 'экран звонка ждёт инициализации Firebase — она ему не нужна');
    expect(hint, lessThan(pump),
        reason: 'экран звонка ждёт выборки ящика; предложение соединения нужно '
            'для СОЕДИНЕНИЯ, а не для показа — качать надо после');
    expect(hint, lessThan(sync),
        reason: 'экран звонка ждёт общей синхронизации пробуждения');
  });

  test('холодный старт: выборка ящика не задерживает показ', () {
    final start = source.indexOf('Future<void> _initPushRuntime');
    final end = source.indexOf('Future<void> _restart()', start);
    final body = source.substring(start, end > 0 ? end : source.length);
    final line = body
        .split('\n')
        .firstWhere((l) => l.contains('pumpInboxForCallWake'), orElse: () => '');
    expect(line.contains('unawaited('), isTrue,
        reason: 'выборка ящика снова ожидается на пути звонка: $line');
  });

  test('возобновление из фона: тот же порядок', () {
    // Второй путь — пробуждение уже запущенного приложения. Он повторял ту же
    // ошибку: сначала сеть, потом показ.
    final marker = 'final callHint = wakeHint.oneToOneCallHint;';
    final start = source.indexOf(marker);
    expect(start, greaterThan(0), reason: 'путь возобновления не найден');
    final body = source.substring(start, start + 1600);

    final hint = _at(body, 'processStartupCallHint');
    final pump = _at(body, 'pumpInboxForCallWake');
    expect(hint, greaterThan(0));
    expect(pump, greaterThan(0));
    expect(hint, lessThan(pump),
        reason: 'на возобновлении экран звонка снова ждёт выборки ящика');
  });

  test('выборка ящика для звонка ограничена по времени', () {
    final controller =
        File('lib/app/app_controller.dart').readAsStringSync();
    final start = controller.indexOf('Future<void> pumpInboxForCallWake');
    expect(start, greaterThan(0));
    final body = controller.substring(start, start + 1400);
    expect(body.contains('.timeout('), isTrue,
        reason: 'без предела выборка держится столько же, сколько HTTP-клиент — '
            'на мёртвой сети это десятки секунд');
  });
}
