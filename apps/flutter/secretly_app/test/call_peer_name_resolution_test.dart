// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Имя и фото собеседника на экране звонка.
//
// Жалоба 22.08.2026: «очень часто не показывает фото профиля, и иногда имя».
// На экране разговора вместо имени стоял сырой profile_id
// («3XBC-F5DJ-FA4C-Q-AYZNW5Q»), а в кружке — «?».
//
// Причина была в асимметрии: фото звонок брал через `cachedProfileAvatarPath`
// (контакт ИЛИ метаданные профиля), а имя — перебором СОХРАНЁННЫХ контактов.
// Звонок от того, кого нет в контактах, оставался без имени, хотя никнейм
// лежал в метаданных рядом с фотографией, которую тот же экран показывал.
//
// Тест сторожит исходник: обе стороны обязаны ходить одним путём, и ни одна
// ветка входящего звонка не имеет права подставлять profile_id вместо имени.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manager = File('lib/calls/call_manager.dart').readAsStringSync();

  test('имя берётся тем же путём, что и фото', () {
    expect(manager.contains('cachedProfileDisplayName'), isTrue,
        reason: 'имя снова резолвится в обход метаданных профиля');
    expect(manager.contains('cachedProfileAvatarPath'), isTrue);
  });

  test('profile_id не подставляется вместо имени', () {
    // Ветки входящего звонка: приглашение и предложение-до-приглашения.
    expect(manager.contains('String peerName = sig.fromProfileId;'), isFalse,
        reason: 'ветка приглашения снова показывает идентификатор как имя');
    expect(
        manager.contains(
            "String peerName = fromProfileId.isEmpty ? 'Unknown' : fromProfileId;"),
        isFalse,
        reason: 'ветка предложения снова показывает идентификатор как имя');
  });

  test('экраны звонка не показывают пустую подпись', () {
    for (final path in const [
      'lib/ui/active_call_screen.dart',
      'lib/ui/incoming_call_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source.contains('state.peerName.trim().isNotEmpty'), isTrue,
          reason: '$path: пустое имя снова рисуется пустой строкой');
    }
  });
}
