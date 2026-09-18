// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// В пузыре сообщения не должно быть вечных анимаций.
//
// 🔴 Почему это сторожится по исходнику. Зацикленная анимация заказывает кадр
// каждый вsync. Одна такая фишка в одном пузыре держит ВЕСЬ экран в
// непрерывной перерисовке, пока чат открыт, — приложение не простаивает
// никогда. Снаружи это выглядит не как ошибка, а как «просто греется».
//
// Мобильная версия уже платила этим: «NOT repeat() (31.07.2026, нагрев iOS) —
// контроллер, который повторяется вечно, заказывает кадр каждый вsync» и
// «каждая реакция проигрывается ровно один раз, и только пока видна».
// Десктоп повторил ошибку: фишки реакций крутились в цикле в каждом пузыре.
//
// Тест текстовый, потому что поймать это поведением нельзя: виджет-тест
// прогоняет кадры сам и на бесконечность не жалуется.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final bubble = File(
    'lib/ui/desktop/chat/message_bubble.dart',
  ).readAsStringSync();

  test('🔴 в пузыре нет зацикленных анимаций', () {
    final code = bubble
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      code.contains('NotoLottieMode.looping'),
      isFalse,
      reason: 'вечный цикл кадров вернулся: пока чат открыт, приложение не '
          'простаивает никогда. В пузыре допустим только `once` — ключ виджета '
          'включает playToken, поэтому новая реакция перезапустит показ сама',
    );
  });

  test('🔴 бесконечный показ крутится, ТОЛЬКО пока эмодзи видно', () {
    // 16.09.2026 эмодзи внутри текста сообщения стали оживать — как на
    // телефоне. Цикл в ленте допустим ровно при одном условии: он обязан
    // останавливаться, когда сообщение уехало за край. Иначе сотня смайликов
    // в невидимых сообщениях держит окно в вечной перерисовке — ровно та беда,
    // ради которой написан этот файл.
    final player = File(
      'lib/ui/desktop/chat/noto_emoji_lottie.dart',
    ).readAsStringSync();
    expect(player.contains('VisibilityDetector('), isTrue);
    expect(player.contains('onVisibilityChanged: _onVisibilityChanged'), isTrue);
    expect(player.contains('ctrl.stop();'), isTrue);
    // Своим контроллером, а не `repeat: true`: чужой внутренний остановить
    // нечем.
    expect(
      player.contains('repeat: true,'),
      isFalse,
      reason: 'внутренний цикл Lottie не остановить по видимости',
    );
  });

  test('фишка реакции всё-таки оживает — режим `once` на месте', () {
    expect(
      bubble.contains('NotoLottieMode.once'),
      isTrue,
      reason: 'если убрать и это, анимация исчезнет совсем — а нужна ровно '
          'одна прокрутка на появление',
    );
  });

  test('перезапуск показа завязан на playToken, а не на время', () {
    // Ключ включает токен: пришёл ещё один человек — виджет пересоздан, и
    // `once` проигрывается заново. Без этого `once` означал бы «один раз за
    // всю жизнь чата».
    expect(
      bubble.contains(r"ValueKey('${m.id}|${r.emoji}|$token')"),
      isTrue,
      reason: 'без токена в ключе новая реакция не оживит фишку',
    );
  });
}
