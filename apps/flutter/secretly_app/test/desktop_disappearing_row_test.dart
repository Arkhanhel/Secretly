// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · «Исчезающие сообщения» — настройка, а не факт.
//
// ЧТО БЫЛО. Строка называлась «Автоудаление» и была устроена как строка
// ФАКТОВ: сверху значение («Выкл.»), снизу подпись. Но это не факт о
// собеседнике — это то, что человек ВКЛЮЧАЕТ, и в такой строке сверху должно
// стоять НАЗВАНИЕ, а снизу состояние.
//
// Функцию при этом не урезали: макет знает только вкл/выкл, а у нас есть срок.
// Переключатель отвечает за вкл/выкл, нажатие на строку открывает выбор срока.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final view = File(
    'lib/ui/desktop/chat/details/contact_details_view.dart',
  ).readAsStringSync();
  final section = File(
    'lib/ui/desktop/chat/details/details_info_section.dart',
  ).readAsStringSync();

  test('· строка стала настройкой: название сверху, состояние снизу', () {
    expect(view.contains('label: l10n.desktopContactDisappearing,'), isTrue);
    expect(view.contains('subtitle: _autoDeleteLabel(),'), isTrue);
    // Строкой фактов она больше не строится.
    expect(view.contains("label: 'Автоудаление',\n                value:"), isFalse);
  });

  test('🔴 срок никуда не делся — функцию не урезали', () {
    // Макет знает только вкл/выкл; у нас есть «1 час», «7 дней», «30 дней».
    expect(view.contains('onTap: _pickAutoDelete,'), isTrue);
    expect(view.contains('on ? _pickAutoDelete() : _setAutoDelete(null)'), isTrue);
  });

  test('выключение — сразу, включение — спрашивает срок', () {
    // Иначе «включить» означало бы выбрать срок за человека.
    // Якорь — сама строка панели, а не одноимённый пункт меню выше по файлу.
    final i = view.indexOf('DetailsToggleRow(\n                icon: FluentIcons.timer_24_regular');
    expect(i, greaterThan(0));
    final body = view.substring(i, (i + 520).clamp(0, view.length));
    expect(body.contains('_setAutoDelete(null)'), isTrue);
    expect(body.contains('_pickAutoDelete()'), isTrue);
  });

  test('одно название на оба входа', () {
    // В меню чата настройка называлась «Автоудаление», в панели — иначе. Два
    // имени у одной настройки человек читает как две разные.
    expect(view.contains("label: 'Автоудаление',"), isFalse);
    expect(view.contains('return l10n.desktopContactOff;'), isTrue);
  });

  test('нажатие на строку-переключатель — добавочная возможность', () {
    // У обычных переключателей его нет: там нажимать нечего, кроме самого
    // переключателя, и подсветка строки обещала бы несуществующее действие.
    expect(section.contains('final VoidCallback? onTap;'), isTrue);
    expect(section.contains('if (onTap == null) return row;'), isTrue);
  });
}
