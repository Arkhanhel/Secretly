// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ТОКЕН ДОСТУПА К АРХИВУ (SEC-01, этап Э-1).
//
// До этого этапа архив на сервере отдавался любому, кто знал `profile_id`, и
// защищал его только пароль — то есть подбор шёл ОФЛАЙН, на железе атакующего,
// без единого ограничения. Токен переносит подбор на сервер.
//
// Главное свойство, которое здесь сторожится: токен уходит НА СЕРВЕР, поэтому
// он не имеет права давать доступ к содержимому. Если вывод токена и вывод
// ключа архива сойдутся, сервер сможет читать переписку — то есть сквозное
// шифрование перестанет существовать, а внешне всё будет работать.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/safe_backup.dart';

void main() {
  const password = 'Correct-Horse-1!';

  test('токен доступа НЕ совпадает с ключом содержимого', () async {
    final access = await BackupAccessV1.mint(password: password);
    final salt = base64Decode(access.saltB64);

    // Ключ содержимого выводится из того же пароля и той же соли, но по другой
    // ветви. Совпадение означало бы, что предъявленный серверу токен открывает
    // и сам архив.
    final contentKey = await SafeBackupV1.deriveAccessBase(
      password: password,
      salt: salt,
    );

    expect(
      base64Encode(contentKey),
      isNot(equals(access.tokenB64)),
      reason: 'токен доступа равен ключевому материалу содержимого — '
          'сервер, получив токен, сможет расшифровать архив',
    );
  });

  test('проверочное значение не позволяет восстановить токен', () async {
    final access = await BackupAccessV1.mint(password: password);
    expect(
      access.verifierB64,
      isNot(equals(access.tokenB64)),
      reason: 'сервер хранит сам токен — кража базы отдаёт доступ к архивам',
    );
  });

  test('соль каждый раз новая', () async {
    final a = await BackupAccessV1.mint(password: password);
    final b = await BackupAccessV1.mint(password: password);
    expect(
      a.saltB64,
      isNot(equals(b.saltB64)),
      reason: 'постоянная соль делает проверочные значения сравнимыми между '
          'профилями: одинаковый пароль стал бы виден по базе',
    );
    expect(a.tokenB64, isNot(equals(b.tokenB64)));
  });

  test('тот же пароль и та же соль дают тот же токен', () async {
    // Иначе восстановление невозможно: на новом устройстве токен выводится
    // заново из введённого пароля и соли, полученной от сервера.
    final minted = await BackupAccessV1.mint(password: password);
    final again = await BackupAccessV1.fromSalt(
      password: password,
      saltB64: minted.saltB64,
    );
    expect(again.tokenB64, equals(minted.tokenB64));
    expect(again.verifierB64, equals(minted.verifierB64));
  });

  test('другой пароль даёт другой токен', () async {
    final minted = await BackupAccessV1.mint(password: password);
    final wrong = await BackupAccessV1.fromSalt(
      password: 'Wrong-Horse-2!',
      saltB64: minted.saltB64,
    );
    expect(
      wrong.tokenB64,
      isNot(equals(minted.tokenB64)),
      reason: 'токен не зависит от пароля — проверка доступа бессмысленна',
    );
  });

  test('опора уходит вместе с архивом, а не отдельно', () {
    // 🔴 Смена пароля НЕ перезаливает архив. Если проверочное значение
    // обновить отдельно, владелец пройдёт проверку новым паролем и получит
    // содержимое, зашифрованное старым, — отказ случится ПОСЛЕ успешной
    // проверки и будет выглядеть как порча архива.
    final source = File(
      'lib/app/app_controller.dart',
    ).readAsStringSync();
    final helper = source.indexOf('_signBackupSetWithAccess');
    expect(helper, greaterThan(0), reason: 'общий помощник подписи исчез');

    // Путей сохранения архива два; подпись с опорой обязана считаться в одном
    // месте, иначе один путь снова окажется без опоры.
    final uses = RegExp('_signBackupSetWithAccess').allMatches(source).length;
    expect(
      uses,
      greaterThanOrEqualTo(3),
      reason: 'помощник объявлен, но используется не во всех путях сохранения',
    );
  });
}
