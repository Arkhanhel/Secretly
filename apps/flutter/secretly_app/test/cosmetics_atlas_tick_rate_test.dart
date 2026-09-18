// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Атлас украшений не должен будить кадр на каждом вsync.
//
// 🔴 Почему это сторожится. `Ticker` заказывает кадр шестьдесят раз в секунду.
// Текстуры украшений обновляются тридцать — половина тиков не делала ничего и
// всё равно стоила полного прохода кадра. Пока на экране есть хоть одно
// украшение, приложение не простаивает никогда.
//
// Замер 12.09.2026 (отладочная сборка, macOS, один процесс):
//
//     без чата                            1,9 %
//     чат с анимированным украшением      43,7 %  → 35,5 % после изоляции слоя
//     чат без украшений                    5,9 %
//
// Таймер кадров не заказывает: кадр появляется сам, когда обновлённая текстура
// приходит слушателям. Поведением это не проверить — виджет-тест сам решает,
// сколько кадров прогнать, и на лишние не жалуется. Поэтому текстом.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'lib/ui/premium/cosmetics_catalog.dart',
  ).readAsStringSync();

  /// Тело `_FrameAtlas` — остальной файл полон законных тикеров у виджетов,
  /// и проверять надо именно атлас.
  String atlasBody() {
    final start = src.indexOf('class _FrameAtlas {');
    expect(start, greaterThan(0), reason: 'класс переименован — проверку надо '
        'переписать под новое имя, а не удалять');
    final end = src.indexOf('\nclass ', start + 10);
    return src.substring(start, end == -1 ? src.length : end);
  }

  test('🔴 атлас крутится таймером, а не тикером кадров', () {
    final body = atlasBody()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    expect(
      body.contains('Ticker('),
      isFalse,
      reason: 'вернулся тикер — значит кадр снова заказывается на каждом вsync, '
          'и половина кадров опять не делает ничего',
    );
    expect(
      body.contains('Timer.periodic('),
      isTrue,
      reason: 'без таймера украшения просто перестанут двигаться',
    );
  });

  test('период — тридцать кадров в секунду', () {
    expect(
      src.contains('Duration(milliseconds: 33)'),
      isTrue,
      reason: 'тридцать кадров — то, на что текстуры и были рассчитаны',
    );
  });

  test('🔴 нижний порог НЕ подобрался к периоду', () {
    // Если порог станет близок к периоду, дрожание таймера начнёт съедать
    // каждый второй тик, и частота втихую упадёт вдвое — а выглядеть это будет
    // как «украшения стали дёрганые», без единой ошибки в журнале.
    final m = RegExp(r'_kMinTickGapSec\s*=\s*([0-9.]+)').firstMatch(src);
    expect(m, isNotNull, reason: 'порог пропал — двойное обновление в одну '
        'миллисекунду снова возможно');
    final gapSec = double.parse(m!.group(1)!);
    expect(gapSec, lessThan(0.033 * 0.8),
        reason: 'порог $gapSec с слишком близок к периоду 0.033 с');
  });

  test('таймер останавливается, когда украшений на экране не осталось', () {
    final body = atlasBody();
    expect(body.contains('_timer?.cancel()'), isTrue,
        reason: 'иначе он будет тикать всю жизнь приложения');
    expect(body.contains('if (_entries.isEmpty)'), isTrue,
        reason: 'остановка обязана быть привязана к пустому экрану');
  });

  test('🔴 в фоне таймер замолкает — тикер делал это сам', () {
    // `Ticker` живёт кадрами: приложение ушло в фон, движок перестал их
    // выдавать — тикер замолк бесплатно. Таймер так не умеет и будил бы
    // событийный цикл тридцать раз в секунду на телефоне в кармане. Платили бы
    // это ТЫСЯЧИ людей на мобильной версии, где батарея дороже всего.
    final body = atlasBody();

    expect(body.contains('_appResumed'), isTrue,
        reason: 'атлас снова не знает про фон — таймер будет тикать в кармане');
    expect(body.contains('_onAppLifecycle'), isTrue);
    expect(
      RegExp(r'if \(resumed\)').hasMatch(body) ||
          body.contains('AppLifecycleState.resumed'),
      isTrue,
      reason: 'возврат из фона обязан заводить таймер обратно, иначе украшения '
          'замрут навсегда после первого сворачивания',
    );
  });

  test('наблюдатель снимается при сбросе, а не копится', () {
    expect(
      atlasBody().contains('removeObserver'),
      isTrue,
      reason: 'иначе между тестами и перезапусками профиля наблюдатели копятся',
    );
  });
}
