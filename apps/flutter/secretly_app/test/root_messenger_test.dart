// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Сообщение обязано пережить экран, с которого пришло.
//
// НАЙДЕНО НА ЖИВОМ ТЕЛЕФОНЕ 15.09.2026. Экран «Восстановить аккаунт» сообщал
// об ошибке через `ScaffoldMessenger.of(context)` и падал с
// `No ScaffoldMessenger widget found`:
//
//   #3 _RestoreAccountPageState._snack        (onboarding_flow.dart:1965)
//   #4 _RestoreAccountPageState._restoreFromServer (onboarding_flow.dart:2153)
//
// Причина не в отсутствии `ScaffoldMessenger` — он есть у `MaterialApp`
// всегда. Причина в том, что запрос резервной копии с сервера ДОЛЬШЕ, чем
// живёт страница: к моменту ответа её элемент уже снят с дерева, а у снятого
// элемента поиск наследуемых виджетов не находит ничего и `of` бросает.
//
// Итог был худшим из возможных: человек, у которого не восстановился аккаунт,
// не получал НИКАКОГО объяснения — вместо надписи приложение роняло
// неперехваченное исключение. Экран восстановления — ровно то место, где
// молчать нельзя.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/root_messenger.dart';

void main() {
  testWidgets('🔴 сообщение показывается ПОСЛЕ того, как страница закрылась', (
    t,
  ) async {
    // Повторяем форму отказа: со страницы начинают долгую работу, страницу
    // закрывают, работа возвращается с ошибкой.
    late BuildContext pageContext;
    await t.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: Builder(
          builder: (home) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(home).push(
                MaterialPageRoute<void>(
                  builder: (ctx) {
                    pageContext = ctx;
                    return const Scaffold(body: Text('страница'));
                  },
                ),
              ),
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();
    expect(find.text('страница'), findsOneWidget);

    // Страницы больше нет.
    Navigator.of(pageContext).pop();
    await t.pumpAndSettle();
    expect(find.text('страница'), findsNothing);

    // Ответ пришёл с ошибкой — и человек её ВИДИТ.
    showRootSnackBar(
      const SnackBar(content: Text('Восстановить не удалось')),
      context: null,
    );
    await t.pump();
    expect(find.text('Восстановить не удалось'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('🔴 без единого ScaffoldMessenger не падает, а молчит', (
    t,
  ) async {
    // Путь заведён ради того, чтобы НЕ падать: если показать сообщение негде,
    // это не повод ронять приложение поверх уже случившейся беды.
    await t.pumpWidget(const SizedBox());
    showRootSnackBar(const SnackBar(content: Text('нечего показывать')));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('· при живом экране сообщение показывается как прежде', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const Scaffold(body: Text('экран')),
      ),
    );
    showRootSnackBar(const SnackBar(content: Text('готово')));
    await t.pump();
    expect(find.text('готово'), findsOneWidget);
  });

  group('места, где отказ случился', () {
    final onboarding = File(
      'lib/ui/onboarding_flow.dart',
    ).readAsStringSync();

    test('🔴 бросающего `ScaffoldMessenger.of` в потоке входа не осталось', () {
      // Комментарии выбрасываем: в них это имя упомянуто как раз затем, чтобы
      // объяснить, почему его больше нет в коде.
      final code = onboarding
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//') &&
              !l.trimLeft().startsWith('///'))
          .join('\n');
      expect(code.contains('ScaffoldMessenger.of('), isFalse);
      // `maybeOf` остаётся — он и не падает.
      expect(code.contains('ScaffoldMessenger.maybeOf('), isTrue);
    });

    test('корневой ключ подключён к MaterialApp', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(
        main.contains('scaffoldMessengerKey: rootScaffoldMessengerKey'),
        isTrue,
      );
    });

    test('🔴 проверки `mounted` в `_snack` больше нет — она всё отменяла', () {
      final i = onboarding.indexOf('void _snack(String msg) {');
      expect(i, greaterThan(0));
      final body = onboarding.substring(i, i + 200);
      expect(body.contains('if (!mounted) return;'), isFalse);
      expect(body.contains('showRootSnackBar('), isTrue);
    });

    test('🔴 строка об ошибке копии берётся ДО ожидания', () {
      // `context.l10n` — тот же поиск по дереву: на снятом элементе он упал бы
      // первым, до самого сообщения.
      final i = onboarding.indexOf('Future<void> _onFinish() async {');
      final body = onboarding.substring(i, i + 700);
      expect(
        body.indexOf('final failedMessage = context.l10n') <
            body.indexOf('await widget.controller'),
        isTrue,
      );
    });

    test('закрытие экрана после успеха не выдаётся за неудачу', () {
      expect(onboarding.contains('Navigator.maybeOf(context)?.pop()'), isTrue);
    });
  });
}
