// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Контакт на компьютере: завести и переименовать.
//
// 🔴 ДО 21.09.2026 НИ ТОГО, НИ ДРУГОГО НА КОМПЬЮТЕРЕ НЕ БЫЛО. Раздел «Контакты»
// умел искать среди уже известных, показать карточку и написать — и всё.
// Человек за компьютером не мог завести новое знакомство, не взяв телефон.
//
// Главная проверяемая мысль здесь одна: Secretly-ID ходит по свету в ТРЁХ
// видах — сам по себе, ссылкой-приглашением и содержимым QR-кода, — а человек
// вставляет то, что ему прислали, и различать их не обязан. Поле, принимающее
// только первый вид, отвечало бы «такого ID нет» на совершенно правильную
// ссылку.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/app/desktop_contacts_section.dart';

void main() {
  group('что вставили — то и разобрали', () {
    test('сам ID остаётся собой', () {
      expect(resolveDesktopContactInput('ABCD1234'), 'ABCD1234');
      expect(resolveDesktopContactInput('  ABCD1234  '), 'ABCD1234');
    });

    test('пусто — это НЕ контакт', () {
      expect(resolveDesktopContactInput(''), isNull);
      expect(resolveDesktopContactInput('   \n  '), isNull);
    });

    test('🔴 ссылка-приглашение во всех её видах', () {
      const id = 'ABCD1234';
      for (final link in <String>[
        'secretly://profile/$id',
        'https://links.secretlyapp.com/profile/$id',
        'https://secretlyapp.com/p/$id',
        'https://www.secretlyapp.com/user/$id',
        'https://links.secretlyapp.com/install?profile=$id',
      ]) {
        expect(resolveDesktopContactInput(link), id, reason: link);
      }
    });

    test('🔴 содержимое QR — и через перевод строки, и через «&»', () {
      expect(
        resolveDesktopContactInput('secretly_id=ABCD1234\nnickname=Аня'),
        'ABCD1234',
      );
      expect(
        resolveDesktopContactInput('secretly_id=ABCD1234&nickname=Аня'),
        'ABCD1234',
      );
    });

    test('🔴 ссылка разбирается РАНЬШЕ QR', () {
      // `?profile=…` разобрал бы и разборщик QR — но неверно: он взял бы
      // ключ `profile` из строки запроса как попало. Порядок здесь и есть
      // правило, поэтому он проверяется отдельно.
      expect(
        resolveDesktopContactInput(
          'https://links.secretlyapp.com/profile/REAL?nickname=Аня',
        ),
        'REAL',
      );
    });

    test('чужая ссылка уходит на сервер как есть, а не молча превращается в ID',
        () {
      // Решение, а не недосмотр: локальная проверка «похоже на ID» врала бы
      // в обе стороны. Сервер ключей отвечает на это «такого ID нет» —
      // тем же текстом, что и на телефоне.
      expect(
        resolveDesktopContactInput('https://example.com/profile/ABCD1234'),
        'https://example.com/profile/ABCD1234',
      );
    });
  });

  group('имя из приглашения', () {
    test('ник из QR подставляется', () {
      expect(
        resolveDesktopContactName('secretly_id=ABCD1234&nickname=Аня'),
        'Аня',
      );
    });

    test('имя из строки запроса ссылки подставляется', () {
      expect(
        resolveDesktopContactName(
          'https://links.secretlyapp.com/profile/ABCD?name=Аня',
        ),
        'Аня',
      );
    });

    test('у голого ID имени нет — и выдумывать его нечем', () {
      expect(resolveDesktopContactName('ABCD1234'), isNull);
      expect(resolveDesktopContactName(''), isNull);
    });
  });

  group('проводка раздела', () {
    // Виджет-тест здесь не поставить: разделу нужен живой `AppController`
    // (база, сервер ключей). Поэтому проводка проверяется по исходнику —
    // тем же приёмом, что и паритет настроек с телефоном.
    final src = File(
      'lib/ui/desktop/app/desktop_contacts_section.dart',
    ).readAsStringSync();

    test('🔴 добавление зовёт общий addContact, а не своё сохранение', () {
      expect(src.contains('widget.controller.addContact('), isTrue);
      expect(src.contains('displayNameIsCustom: name.isNotEmpty'), isTrue);
    });

    test('🔴 переименование зовёт общий renameContact', () {
      final shared = File(
        'lib/ui/desktop/app/contact_rename.dart',
      ).readAsStringSync();
      expect(shared.contains('vm.controller.renameContact('), isTrue);
      // Пустое поле СНИМАЕТ своё имя, а не сохраняет пустую строку.
      expect(
        shared.contains('displayName: name.isEmpty ? null : name'),
        isTrue,
      );
    });

    test('ошибки объясняются теми же словами, что на телефоне', () {
      final shared = File(
        'lib/ui/desktop/app/contact_rename.dart',
      ).readAsStringSync();
      expect(src.contains('contactActionErrorText(l10n, e)'), isTrue);
      expect(shared.contains('contactActionErrorText(l10n, e)'), isTrue);
    });

    test('🔴 переименование — ОДНО окно на оба места', () {
      // Раздел «Контакты» и карточка человека в переписке зовут один и тот же
      // `showRenameContactDialog`. Две копии одного действия расходятся не
      // сразу и не целиком: сперва в одной появится подсказка, потом в другой
      // — другое сообщение об ошибке. Так в этом окне уже было с выходом из
      // аккаунта.
      final details = File(
        'lib/ui/desktop/chat/details/contact_details_view.dart',
      ).readAsStringSync();
      expect(src.contains('showRenameContactDialog('), isTrue,
          reason: 'раздел «Контакты»');
      expect(details.contains('showRenameContactDialog('), isTrue,
          reason: 'карточка человека в переписке');
      // И ни одного своего `renameContact` мимо общего окна.
      expect(src.contains('.renameContact('), isFalse);
      expect(details.contains('.renameContact('), isFalse);
    });

    test('🔴 «Добавить» есть и у пустого списка, и рядом с поиском', () {
      expect('addContact'.allMatches(src).length, greaterThanOrEqualTo(2));
      expect(src.contains('onAdd: _query.isEmpty'), isTrue,
          reason: 'по неудачному поиску предлагать «добавить» нельзя — '
              'человек искал среди своих, а не заводил нового');
    });
  });
}
