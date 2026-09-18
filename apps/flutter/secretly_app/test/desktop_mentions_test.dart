// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ДЕСКТОП УМЕЛ ПОКАЗЫВАТЬ УПОМИНАНИЯ, НО НЕ УМЕЛ ИХ СТАВИТЬ.
//
// Пузырь подсвечивает обращение, строка списка ставит сиренево-розовый
// счётчик, уведомление приходит — всё это работало на ВХОД. А на выход
// `sendGroupMessage` вызывался без `mentions`: набранное на компьютере
// «@Игорь, посмотри» уходило обычным текстом. У получателя — ни подсветки, ни
// значка, ни уведомления; человек, которого позвали с компьютера, об этом не
// узнавал.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_mentions.dart';

({String profileId, String displayName, String? avatarPath, String? role}) m(
  String id,
  String name, {
  String? role,
}) => (profileId: id, displayName: name, avatarPath: null, role: role);

void main() {
  group('ярлык', () {
    test('пробелы становятся подчёркиванием, знаки уходят', () {
      expect(desktopMentionHandle('Игорь Петров'), 'Игорь_Петров');
      expect(desktopMentionHandle('  Anna (QA)  '), 'Anna_QA');
      expect(desktopMentionHandle('@yurii'), 'yurii');
      expect(desktopMentionHandle('...'), '');
    });

    // 🔴 КОПИЯ ПРАВИЛА ТЕЛЕФОНА НЕ ДОЛЖНА РАЗОЙТИСЬ С ОРИГИНАЛОМ.
    //
    // `_sanitizeMentionHandle` в `chat_screen.dart` приватный, и вызвать его
    // отсюда нельзя. Но можно сверить сами выражения: разойдутся — тест
    // покажет, какое именно.
    test('🔴 те же выражения, что у телефона', () {
      final mobile = File('lib/ui/chat_screen.dart').readAsStringSync();
      final desktop = File(
        'lib/ui/desktop/chat/desktop_mentions.dart',
      ).readAsStringSync();
      const rules = <String>[
        r"replaceAll(RegExp(r'\s+'), '_')",
        r"replaceAll(RegExp(r'[@.,!?;:()\[\]{}<>/]+'), '')",
        r"replaceAll(RegExp(r'_+'), '_')",
        r"replaceAll(RegExp(r'^_+|_+$'), '')",
      ];
      for (final rule in rules) {
        expect(mobile.contains(rule), isTrue, reason: 'у телефона нет: $rule');
        expect(desktop.contains(rule), isTrue, reason: 'у десктопа нет: $rule');
      }
    });
  });

  group('кого можно позвать', () {
    test('«все» впереди, себя в списке нет', () {
      final t = desktopMentionTargets(
        members: [m('me', 'Я'), m('p1', 'Игорь')],
        selfProfileId: 'me',
      );
      expect(t.first.token, '@all');
      expect(t.any((x) => x.profileId == 'me'), isFalse);
      expect(t.any((x) => x.profileId == 'p1'), isTrue);
    });

    test('🔴 два одинаковых имени разводятся суффиксом', () {
      // Иначе один ярлык на двоих, и разметка встала бы не на того.
      final t = desktopMentionTargets(
        members: [m('p1', 'Игорь'), m('p2', 'Игорь')],
        selfProfileId: 'me',
      );
      final tokens = t.where((x) => !x.isBroadcast).map((x) => x.token).toList();
      expect(tokens, ['@Игорь', '@Игорь_2']);
    });

    test('без имени ярлык берётся от идентификатора', () {
      final t = desktopMentionTargets(
        members: [m('6R2K', '')],
        selfProfileId: 'me',
      );
      expect(t.last.token, '@6R2K');
    });

    test('«админы» — только там, где они есть', () {
      final without = desktopMentionTargets(members: [], selfProfileId: 'me');
      expect(without.any((x) => x.token == '@admins'), isFalse);
      final with_ = desktopMentionTargets(
        members: [],
        selfProfileId: 'me',
        withAdmins: true,
      );
      expect(with_.any((x) => x.token == '@admins'), isTrue);
    });
  });

  group('что набирают сейчас', () {
    test('видит «собачку» под курсором', () {
      final d = desktopMentionDraft(text: 'привет @иг', caret: 10);
      expect(d, isNotNull);
      expect(d!.query, 'иг');
      expect(d.start, 7);
      expect(d.end, 10);
    });

    test('пустое «@» — тоже начало упоминания', () {
      final d = desktopMentionDraft(text: '@', caret: 1);
      expect(d, isNotNull);
      expect(d!.query, '');
    });

    test('🔴 адрес почты списка не открывает', () {
      // Перед «собачкой» буква — значит это не обращение, а адрес.
      expect(
        desktopMentionDraft(text: 'mail@example', caret: 12),
        isNull,
      );
    });

    test('пробел обрывает: «@» из прошлого слова уже не считается', () {
      expect(desktopMentionDraft(text: '@игорь привет', caret: 13), isNull);
    });

    test('обычный текст — ничего', () {
      expect(desktopMentionDraft(text: 'привет', caret: 6), isNull);
    });
  });

  group('отбор по набранному', () {
    final targets = desktopMentionTargets(
      members: [m('p1', 'Игорь'), m('p2', 'Сергей Игоревич'), m('p3', 'Анна')],
      selfProfileId: 'me',
    );

    test('сперва те, у кого совпало НАЧАЛО', () {
      final got = desktopMentionMatches(targets: targets, query: 'иг');
      expect(got.first.title, 'Игорь');
      expect(got.any((x) => x.title == 'Сергей Игоревич'), isTrue);
    });

    test('пустой запрос — все по порядку', () {
      final got = desktopMentionMatches(targets: targets, query: '');
      expect(got.first.token, '@all');
    });
  });

  group('разметка на отправку', () {
    final targets = desktopMentionTargets(
      members: [m('p1', 'Игорь')],
      selfProfileId: 'me',
    );

    test('🔴 упоминание превращается в разметку протокола', () {
      final got = desktopResolveMentions(
        text: '@Игорь, посмотри',
        targets: targets,
      );
      expect(got.length, 1);
      expect(got.first.isProfile, isTrue);
      expect(got.first.profileId, 'p1');
      expect(got.first.start, 0);
      expect(got.first.end, 6);
    });

    test('«всех» — разметкой allType, без профиля', () {
      final got = desktopResolveMentions(text: 'ребята @all', targets: targets);
      expect(got.length, 1);
      expect(got.first.isAll, isTrue);
      expect(got.first.profileId, isNull);
    });

    test('чужого имени в списке нет — разметки нет', () {
      final got = desktopResolveMentions(text: '@Петя привет', targets: targets);
      expect(got, isEmpty);
    });

    test('без «собачки» не считаем вовсе', () {
      expect(desktopResolveMentions(text: 'Игорь', targets: targets), isEmpty);
      expect(
        desktopResolveMentions(text: '@Игорь', targets: const []),
        isEmpty,
      );
    });

    test('смещения совпадают с общим разбором телефона', () {
      // Разбор один и тот же (`resolveChatMessageMentions`), значит и
      // смещения по определению те же. Проверяем на тексте с эмодзи, где
      // «символы» и кодовые единицы расходятся.
      const text = '👋 @Игорь';
      final got = desktopResolveMentions(text: text, targets: targets);
      expect(got.length, 1);
      expect(text.substring(got.first.start, got.first.end), '@Игорь');
    });
  });

  test('🔴 отправка комнаты действительно несёт разметку', () {
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    expect(section.contains('mentions: '), isTrue);
    expect(section.contains('desktopResolveMentions('), isTrue);
  });

  test('🔴 правка сообщения тоже несёт разметку', () {
    // Вызов правки уходил без `mentions:`, и упоминания стирались — здесь и
    // на телефоне, куда правка зеркалится.
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    final at = section.indexOf('editTextMessage(');
    expect(at, greaterThan(0), reason: 'вызов правки не найден');
    final call = section.substring(at, section.indexOf(');', at));
    expect(
      call.contains('desktopResolveMentions('),
      isTrue,
      reason: 'правка отправляет пустой список упоминаний',
    );
  });
}
