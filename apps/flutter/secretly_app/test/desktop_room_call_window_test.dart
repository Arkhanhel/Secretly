// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Окно комнатного созвона показывает ТО, ЧТО ИДЁТ, а не то, что мы просили.
//
// 🔴 Дефект, ради которого написана проверка, я увидел живьём в первый же
// запуск: голосовой созвон, камера не включалась ни разу — а строка участника
// писала «камера включена», и кнопка камеры горела зелёным.
//
// Причина: снимок созвона с релея несёт ФЛАГ НАМЕРЕНИЯ (`videoEnabled`), то
// есть то, что мы когда-то отправили, а не то, что сейчас передаётся. Для
// показа правильный источник — медиаслой: он знает, есть ли дорожка.
//
// Ошибка незаметная и живучая: флаг и дорожка совпадают в большинстве случаев,
// и расходятся именно тогда, когда человеку важнее всего понять, включена ли у
// него камера. Поэтому правило закреплено текстом — поведение здесь живёт в
// виджете, которому нужны живой менеджер созвона и сессия LiveKit.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/ui/desktop/calls/room_call_window.dart',
  ).readAsStringSync();

  /// Тело метода по его ОБЪЯВЛЕНИЮ.
  ///
  /// 🔴 Якорь включает открывающую скобку объявления целиком: имя метода
  /// встречается ещё и в вызовах, и поиск по голому имени уже дважды находил
  /// вызов вместо объявления — проверка при этом падала не на том, что
  /// проверяет.
  String bodyOf(String declaration) {
    final start = source.indexOf(declaration);
    expect(
      start,
      greaterThan(0),
      reason: 'объявление «$declaration» изменилось — перепиши проверку',
    );
    // Ищем закрывающую скобку МЕТОДА — она стоит на своей строке. Просто
    // «\n  }» совпадало с «\n  }) {» многострочной сигнатуры, и тело
    // обрезалось сразу после объявления.
    final end = source.indexOf('\n  }\n', start);
    return source.substring(start, end > 0 ? end : source.length);
  }

  test('🔴 «камера включена» считается по ДОРОЖКЕ, а не по флагу', () {
    final body = bodyOf('bool _videoLive(CachedRoomCallParticipant');

    expect(
      body.contains('hasParticipantCameraView'),
      isTrue,
      reason: 'без обращения к медиаслою строка снова начнёт врать о камере',
    );
    expect(
      body.contains('publishVideo'),
      isTrue,
      reason: 'намерение участника тоже учитывается — но вместе с дорожкой',
    );
  });

  test('🔴 показ экрана — так же', () {
    final body = bodyOf('bool _shareLive(CachedRoomCallParticipant');
    expect(body.contains('hasParticipantScreenShareView'), isTrue);
  });

  test('🔴 кнопки камеры и экрана берут живое состояние', () {
    final body = bodyOf('Widget _controls(DColorSet');
    expect(
      body.contains('_videoLive(self)'),
      isTrue,
      reason: 'кнопка отвечает на «включена ли у меня камера СЕЙЧАС»',
    );
    expect(body.contains('_shareLive(self)'), isTrue);
  });

  group('движок остаётся общим с телефоном', () {
    test('🔴 порядок вызовов при входе повторяет мобильный', () {
      // joinRelayRoomCall → ensureJoined(forceRefresh: true). Без второго шага
      // медиасессия не пересобирается, и человек входит в созвон без звука.
      final body = bodyOf('Future<void> _startOrJoin({');
      final join = body.indexOf('joinRelayRoomCall');
      final ensure = body.indexOf('ensureJoined');
      expect(join, greaterThan(0));
      expect(
        ensure,
        greaterThan(join),
        reason: 'ensureJoined идёт ПОСЛЕ входа',
      );
      expect(body.contains('forceRefresh: true'), isTrue);
    });

    test('🔴 порядок вызовов при выходе повторяет мобильный', () {
      // leaveRelayRoomCall → clearIfMatches. Без второго шага менеджер
      // продолжает считать созвон живым и держит медиасессию.
      final body = bodyOf('Future<void> _leave() {');
      final leave = body.indexOf('leaveRelayRoomCall');
      final clear = body.indexOf('clearIfMatches');
      expect(leave, greaterThan(0));
      expect(clear, greaterThan(leave));
    });

    test('🔴 окно НЕ заводит своего жизненного цикла созвона', () {
      // Вход, выход и медиасессия — общий с телефоном код. Своя реализация
      // разошлась бы с ним на первой же правке, причём в самом дорогом месте.
      expect(
        source.contains('joinRelayRoomCallMedia'),
        isFalse,
        reason: 'медиасессию поднимает менеджер, а не окно',
      );
      expect(
        source.contains('RoomCallMediaControllerFactory'),
        isFalse,
        reason: 'свой медиаконтроллер окну заводить нельзя',
      );
    });
  });
}
