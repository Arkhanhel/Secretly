// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Открытие переписки «извне» обязано переключить РАЗДЕЛ.
//
// 🔴 Дефект, который этот тест сторожит, был невидим по коду и молчалив в
// работе.
//
// `_openConvoByIdFromDeepLink` выбирал переписку в нужном складе и делал
// `setState(() => _section = ...)`. Но `_section` у корня — ЗЕРКАЛО: его пишет
// сама оболочка в `contentBuilder`, а `initialSection` она читает один раз при
// создании. То есть запись была мёртвой, раздел не менялся, и человек не видел
// НИЧЕГО.
//
// Путь не редкий: по нему открываются нажатие на уведомление, ссылка
// `secretly://room/...`, ссылка на профиль, кнопка «Написать сообщение» в
// контактах и плитка комнаты на рейке. Если открываемая переписка была не в
// текущем разделе, все они молчали.
//
// Проверка текстовая, потому что поведение живёт в корне приложения — виджете,
// который тянет за собой контроллер, базу и сеть. Сторожить здесь надо не
// раскладку, а ОДИН вызов, без которого весь путь бесполезен.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/ui/desktop/app/desktop_production_app.dart',
  ).readAsStringSync();

  /// Тело метода от его объявления до следующего объявления верхнего уровня.
  ///
  /// Ищем ОБЪЯВЛЕНИЕ, а не первое упоминание имени.
  ///
  /// Привязка к полной сигнатуре уже сломала проверку, когда метод начал
  /// возвращать `bool`. Привязка к голому имени сломала её второй раз: имя
  /// встречается и в вызове из соседнего метода, и поиск находил вызов.
  ///
  /// Тип параметра есть только у объявления — им и цепляемся.
  String bodyOf(String name) {
    final start = source.indexOf('$name(String');
    expect(
      start,
      greaterThan(0),
      reason:
          'метод «$name» переименован — проверку надо переписать под новое '
          'имя, а не удалять',
    );
    final end = source.indexOf('\n  Future<', start + name.length);
    return source.substring(start, end > 0 ? end : source.length);
  }

  test('🔴 открытие по ссылке переключает раздел через оболочку', () {
    final body = bodyOf('_openConvoByIdFromDeepLink');

    expect(
      body.contains('_shellSelectSection'),
      isTrue,
      reason:
          'без вызова оболочки раздел не меняется: `_section` у корня это '
          'зеркало, которое оболочка перезапишет на следующей же сборке',
    );
  });

  test('переписка при этом ещё и выбирается в нужном складе', () {
    // Одного переключения раздела мало: без выбора человек увидит пустой
    // раздел вместо той переписки, ради которой пришёл.
    final body = bodyOf('_openConvoByIdFromDeepLink');

    expect(body.contains('_roomsSelection.select'), isTrue);
    expect(body.contains('_chatsSelection.select'), isTrue);
  });

  test('🔴 корень НЕ пытается переключить раздел присваиванием в одиночку', () {
    // Ровно та мёртвая запись, с которой всё началось. Она допустима только
    // РЯДОМ с вызовом оболочки — как обновление зеркала, а не как способ
    // переключить раздел.
    final body = bodyOf('_openConvoByIdFromDeepLink');
    final assigns = body.contains('_section =');

    expect(
      !assigns || body.contains('_shellSelectSection'),
      isTrue,
      reason: 'присваивание `_section` без вызова оболочки не делает ничего',
    );
  });
}
