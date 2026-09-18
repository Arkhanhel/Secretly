// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 «Кому что видно» едет между устройствами одного человека.
//
// ЧТО БЫЛО. Рамка, обложка, эмодзи-статус, ник и описание принимались с
// сервера молча, а карта видимости — нет. Два устройства одного человека
// обещали собеседникам РАЗНОЕ, и какое из двух обещаний выполнится, зависело
// от того, с какого устройства последним ушла публикация.
//
// Решение владельца 15.09.2026: принимать молча, как украшения. Эта карта —
// настройка ЧЕЛОВЕКА, а не аппарата: «последний вход виден контактам» человек
// решает про себя, а не про телефон отдельно от компьютера.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/app/app_controller.dart').readAsStringSync();
  final i = src.indexOf('Future<void> _adoptMyPublishedProfileMeta() async {');
  final body = src.substring(i, src.indexOf('\n  }\n', i));

  test('🔴 карта видимости принимается вместе с остальным', () {
    expect(body.contains("_trimmedMetaString(row, 'privacy_audience_json')"), isTrue);
    expect(body.contains('_privacyAudience = next;'), isTrue);
    expect(body.contains('_prefsPrivacyAudienceMapKey'), isTrue);
  });

  test('🔴 пустой ответ карту НЕ трогает', () {
    // Иначе первый же ответ без поля сбросил бы выбор на заводской — то есть
    // молча РАСШИРИЛ бы круг тех, кто видит последний вход.
    expect(
      body.contains('if (publishedPrivacy != null && publishedPrivacy.isNotEmpty)'),
      isTrue,
    );
  });

  test('приняв чужой выбор, аппарат перестаёт бояться его затереть', () {
    // Публикация с «невыбиравшего» устройства нарочно повторяет то, что уже
    // опубликовано (`_privacyAudienceChosenHere`). Приняв карту, устройство
    // публикует ровно её — флаг обязан подняться вместе с принятием.
    expect(body.contains('_privacyAudienceChosenHere = true;'), isTrue);
  });

  test('своя правка в пути — чужое значение ждёт', () {
    // Иначе собственный только что сделанный выбор был бы перебит ещё не
    // дошедшим до сервера прежним. Проверка стоит В НАЧАЛЕ метода, до чтения
    // опубликованной строки.
    final head = src.substring(i, i + 400);
    expect(
      head.contains('if (_myProfileMetaPublishRequested || _myProfileMetaPublishInFlight) return;'),
      isTrue,
    );
  });

  test('сравнение карт идёт по известным ключам, а не по length', () {
    // Ответ сервера может нести лишние ключи будущих версий; сравнивать надо
    // то, чем мы пользуемся, иначе карта «менялась» бы на каждом тике.
    expect(src.contains('static bool _privacyAudienceMapsEqual('), isTrue);
    expect(src.contains('for (final key in _privacyAudienceKeys) {\n      if (a[key] != b[key]) return false;'), isTrue);
  });
}
