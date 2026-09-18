// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 СЛОМАННЫЙ ВИДЖЕТ НЕ ЗАЛИВАЕТ ОКНО КРАСНЫМ — И НЕ УХОДИТ МОЛЧА.
//
// ЖАЛОБА ВЛАДЕЛЬЦА 16.09.2026: «при появлении менюшки над пузырём моргает
// экран красным цветом».
//
// Красное полотно во весь экран — это `ErrorWidget` Flutter: он подменяет
// собой поддерево, которое не смогло собраться. Вспышка потому и вспышка, что
// следующий кадр рисует уже исправное поддерево. Для того, кто переписывается,
// это выглядит как сбой всего окна, хотя не собралась одна кнопка; и, что
// хуже, о ПРИЧИНЕ он не узнаёт ничего — вспышку не прочитать.
//
// 🔴 ОКНО ВЛАДЕЛЬЦА — ОТЛАДОЧНАЯ СБОРКА. `tools/desktop_build_macos.sh` собирает
// `--debug`, а в отладке `ErrorWidget` красный по умолчанию. Поэтому и глушим
// по умолчанию, а не «только в релизе»: иначе правка не касалась бы ровно того
// случая, из-за которого написана.
//
// Причина при этом уходит в журнал, а красное полотно возвращается флагом
// среды — тем же способом, что и стеки заказа кадров рядом.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/main_desktop.dart').readAsStringSync();

  test('🔴 причина уходит в журнал с именем виджета', () {
    expect(src.contains("DiagLog.event('ui', 'widget_error'"), isTrue);
    // Имя библиотеки и место — без них запись говорит «что-то упало».
    expect(src.contains("'lib': details.library"), isTrue);
    expect(src.contains("'ctx': details.context?.toDescription()"), isTrue);
  });

  test('🔴 прежний обработчик НЕ теряется', () {
    // Иначе правка глушила бы и вывод самого Flutter — единственное место,
    // где виден стек.
    final i = src.indexOf('void _installDesktopErrorGuard()');
    expect(i, greaterThan(0));
    final body = src.substring(i, i + 1200);
    expect(body.contains('final inner = FlutterError.onError;'), isTrue);
    expect(body.contains('inner?.call(details);'), isTrue);
  });

  test('🔴 красное полотно глушится ПО УМОЛЧАНИЮ, а не только в релизе', () {
    final i = src.indexOf('void _installDesktopErrorGuard()');
    final body = src.substring(i, i + 1400);
    expect(body.contains('ErrorWidget.builder = '), isTrue);
    expect(
      body.contains("Platform.environment['SECRETLY_SHOW_WIDGET_ERRORS'] == '1'"),
      isTrue,
      reason: 'вернуть красное полотно должно быть можно одной переменной',
    );
    expect(
      body.contains('isDebug'),
      isFalse,
      reason: 'окно владельца и есть отладочная сборка',
    );
  });

  test('ловушка ставится ДО запуска окна', () {
    final guard = src.indexOf('_installDesktopErrorGuard();');
    final run = src.indexOf('runApp(const DesktopProductionApp());');
    expect(guard, greaterThan(0));
    expect(run, greaterThan(guard));
  });
}
