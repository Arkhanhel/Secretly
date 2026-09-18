// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Подстановка участников по «@» в поле ввода.
//
// 🔴 БЕЗ НЕЁ НУЖНЫЙ ЯРЛЫК НЕ НАБРАТЬ. Он собирается из имени по правилам
// (пробелы в подчёркивания, знаки прочь), и угадать «@Игорь_Петров» по виду
// «Игорь Петров» человек не обязан. А не угадав — отправит обычный текст, и
// позванный об этом не узнает.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/composer.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_mentions.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

final _targets = desktopMentionTargets(
  members: [
    (profileId: 'p1', displayName: 'Игорь Петров', avatarPath: null, role: null),
    (profileId: 'p2', displayName: 'Анна', avatarPath: null, role: 'Владелец'),
  ],
  selfProfileId: 'me',
);

Widget host(TextEditingController ctl, {List<DesktopMentionTarget>? targets}) =>
    MaterialApp(
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 300),
            child: SizedBox(
              width: 700,
              child: Composer(
                controller: ctl,
                onSend: (_) {},
                autofocus: true,
                mentionTargets: targets ?? _targets,
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('🔴 «@» открывает список, ярлык виден заранее', (t) async {
    final ctl = TextEditingController();
    await t.pumpWidget(host(ctl));
    await t.pump();

    ctl.value = const TextEditingValue(
      text: '@',
      selection: TextSelection.collapsed(offset: 1),
    );
    await t.pumpAndSettle();

    expect(find.text('Все участники'), findsOneWidget);
    expect(find.text('Игорь Петров'), findsOneWidget);
    // Ярлык показан ДО нажатия: имя и ярлык совпадают не всегда.
    expect(find.text('@Игорь_Петров'), findsOneWidget);
  });

  testWidgets('набранное сужает список', (t) async {
    final ctl = TextEditingController();
    await t.pumpWidget(host(ctl));
    ctl.value = const TextEditingValue(
      text: '@анн',
      selection: TextSelection.collapsed(offset: 4),
    );
    await t.pumpAndSettle();
    expect(find.text('Анна'), findsOneWidget);
    expect(find.text('Игорь Петров'), findsNothing);
  });

  testWidgets('🔴 выбор подставляет ярлык И пробел после него', (t) async {
    // Без пробела следующее слово прилипнет к имени, и разбор на отправке
    // упоминания уже не увидит — у него граница обязана быть разделителем.
    final ctl = TextEditingController();
    await t.pumpWidget(host(ctl));
    ctl.value = const TextEditingValue(
      text: 'привет @иг',
      selection: TextSelection.collapsed(offset: 10),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('Игорь Петров'));
    await t.pumpAndSettle();

    expect(ctl.text, 'привет @Игорь_Петров ');
    expect(ctl.selection.baseOffset, ctl.text.length);
    // И список закрылся.
    expect(find.text('Игорь Петров'), findsNothing);
  });

  testWidgets('подставленное действительно становится разметкой', (t) async {
    final ctl = TextEditingController();
    await t.pumpWidget(host(ctl));
    ctl.value = const TextEditingValue(
      text: '@иг',
      selection: TextSelection.collapsed(offset: 3),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Игорь Петров'));
    await t.pumpAndSettle();

    final mentions = desktopResolveMentions(
      text: ctl.text.trim(),
      targets: _targets,
    );
    expect(mentions.length, 1);
    expect(mentions.first.profileId, 'p1');
  });

  testWidgets('в личной переписке списка нет вовсе', (t) async {
    final ctl = TextEditingController();
    await t.pumpWidget(host(ctl, targets: const <DesktopMentionTarget>[]));
    ctl.value = const TextEditingValue(
      text: '@',
      selection: TextSelection.collapsed(offset: 1),
    );
    await t.pumpAndSettle();
    expect(find.text('Все участники'), findsNothing);
  });

  testWidgets('адрес почты списка не открывает', (t) async {
    final ctl = TextEditingController();
    await t.pumpWidget(host(ctl));
    ctl.value = const TextEditingValue(
      text: 'mail@ex',
      selection: TextSelection.collapsed(offset: 7),
    );
    await t.pumpAndSettle();
    expect(find.text('Все участники'), findsNothing);
  });

  group('клавиши', () {
    final src = File(
      'lib/ui/desktop/chat/composer.dart',
    ).readAsStringSync();

    test('🔴 список забирает клавиши ПЕРВЫМ, пока открыт', () {
      // Иначе Enter отправлял бы сообщение с недонабранным «@иг» вместо
      // подстановки, а стрелки уводили бы курсор мимо списка.
      final guard = src.indexOf(
        'if (_mentionDraft != null && _mentionMatches.isNotEmpty)',
      );
      final enter = src.indexOf('final isEnter =');
      expect(guard, greaterThan(0));
      expect(guard, lessThan(enter));
    });

    test('стрелки, Enter, Tab и Escape', () {
      expect(src.contains('LogicalKeyboardKey.arrowDown'), isTrue);
      expect(src.contains('LogicalKeyboardKey.arrowUp'), isTrue);
      expect(src.contains('LogicalKeyboardKey.tab'), isTrue);
      expect(src.contains('_mentionDismissed = true;'), isTrue);
    });

    test('закрытый Escape'"'"'ом список не всплывает сам', () {
      // Иначе Escape не закрывал бы ничего: следующий же символ открыл бы
      // список заново.
      expect(src.contains('if (_mentionDismissed) return;'), isTrue);
      // И сбрасывается, когда «@» кончилось.
      expect(src.contains('_mentionDismissed = false;'), isTrue);
    });
  });
}
