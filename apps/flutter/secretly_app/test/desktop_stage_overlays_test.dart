// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Служебные наложения над демонстрацией: взято одно из двух, и это решение.
//
// ◆ В МАКЕТЕ над чужим экраном два чипа: слева-снизу «В отдельное окно», и
// справа-снизу качество дорожки «1080p · 30 fps».
//
// 1. ВТОРОГО НАТИВНОГО ОКНА В ПРОЕКТЕ НЕТ (`desktop_multi_window` не
//    подключён) — обещать его нельзя. Вместо него чип разворачивает сцену во
//    весь экран тем же путём, что кнопка в шапке окна созвона, и подписан
//    своими словами: «Во весь экран» / «Свернуть».
//
// 2. ЧИП КАЧЕСТВА НЕ РИСУЕТСЯ ВОВСЕ: показателей дорожки движок наружу не
//    отдаёт (в `RoomCallMediaController` нет ни одного метода статистики).
//    Выдуманное число хуже отсутствующего — по нему судят, стоит ли просить
//    показывающего сменить окно.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'lib/ui/desktop/calls/room_call_window.dart',
  ).readAsStringSync();

  /// Тот же файл без строк-комментариев: решение «чего мы НЕ рисуем» записано
  /// прямо над кодом, и искать отсутствие подписи надо в самом коде, иначе
  /// объяснение засчитывается за нарушение.
  final code = src
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('◆ чип разворота есть и подписан честно', () {
    expect(
      src.contains('expanded ? l10n.callMinimize : l10n.desktopCallFullScreenShort'),
      isTrue,
    );
    // Макетной подписи нет: второго окна мы не открываем.
    expect(code.contains('В отдельное окно'), isFalse);
  });

  test('🔴 чип ведёт ТЕМ ЖЕ путём, что кнопка в шапке', () {
    // Два разных пути к полноэкранному режиму разъехались бы с состоянием, и
    // чип показывал бы «Свернуть» у развёрнутой сцены и наоборот.
    expect(src.contains('onExpand: pick.screenShare && !found.isSelf'), isTrue);
    expect(src.contains('? _toggleFullScreen'), isTrue);
    expect(src.contains('expanded: _fullScreen,'), isTrue);
  });

  test('чип появляется только над ЧУЖОЙ демонстрацией', () {
    // Над лицом собеседника это была бы вторая кнопка того же действия в
    // сорока точках от кнопки в шапке; свой показ увеличивать незачем — он и
    // так на своём мониторе.
    expect(src.contains('pick.screenShare && !found.isSelf'), isTrue);
    expect(src.contains('VoidCallback? onExpand;'), isTrue);
  });

  // 🔴 ЧИП КАЧЕСТВА ПОЯВИЛСЯ 15.09.2026 — вместе с показателями дорожки.
  //
  // Раньше его не рисовали, потому что чисел неоткуда было взять, а выдуманное
  // число хуже отсутствующего: по нему судят, стоит ли просить показывающего
  // сменить окно. Теперь движок отдаёт их по принимаемой дорожке, и числа
  // настоящие.
  test('🔴 чип качества берёт ИЗМЕРЕННОЕ, а не выдуманное', () {
    expect(src.contains('RoomCallVideoStats? stats;'), isTrue);
    // Меряем только у ЧУЖОГО показа: своя дорожка исходящая, и «сколько
    // дошло» к ней неприменимо.
    expect(
      src.contains('stats: pick.screenShare && !found.isSelf ? _stageStats : null'),
      isTrue,
    );
    // Движок может отдать высоту без частоты — тогда в чипе одна половина, а
    // не выдуманная вторая.
    expect(src.contains('if (h != null && h > 0) parts.add('), isTrue);
    expect(src.contains('if (fps != null && fps > 0) parts.add('), isTrue);
    // И чипа нет вовсе, когда мерить нечем.
    expect(src.contains('if (stats != null)'), isTrue);
  });
}
