// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// СОЗДАНИЕ ОПРОСА С КОМПЬЮТЕРА.
//
// 🔴 Пункт «Опрос» в меню вложений был заготовлен, но никуда не вёл: опрос
// можно было только получить с телефона.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/poll_composer_dialog.dart';

DesktopPollDraft _draft({
  String question = 'Когда встречаемся?',
  List<String> options = const ['В пятницу', 'В субботу'],
}) => DesktopPollDraft(
  question: question,
  options: options,
  multiple: false,
  anonymous: false,
);

void main() {
  group('заготовка опроса', () {
    test('полный опрос годится', () {
      expect(_draft().isValid, isTrue);
    });

    test('🔴 без вопроса — не опрос', () {
      expect(_draft(question: '   ').isValid, isFalse);
    });

    test('🔴 одного варианта мало', () {
      expect(_draft(options: const ['Только этот', '  ']).isValid, isFalse);
    });

    test('пустые строки вариантов отбрасываются', () {
      final draft = _draft(
        options: const ['  В пятницу ', '', 'В субботу', '   '],
      );
      expect(draft.cleanOptions, ['В пятницу', 'В субботу']);
      expect(draft.isValid, isTrue);
    });

    test('границы числа вариантов заданы', () {
      expect(kDesktopPollMinOptions, 2);
      expect(kDesktopPollMaxOptions, greaterThanOrEqualTo(4));
    });
  });

  group('проводка (по исходникам)', () {
    String read(String path) => File(path).readAsStringSync();

    test('🔴 пункт «Опрос» в меню вложений подключён', () {
      final panel = read('lib/ui/desktop/chat/chat_thread_panel.dart');
      expect(panel.contains('onPoll: widget.onComposePoll'), isTrue);
    });

    test('🔴 опрос отправляется только в комнату', () {
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      expect(section.contains('showDesktopPollComposer('), isTrue);
      expect(section.contains('sendGroupPoll('), isTrue);
      expect(
        section.contains("onComposePoll: _convoId.startsWith('group:')"),
        isTrue,
        reason: 'в личной переписке опрос отправить нельзя',
      );
    });

    test('подписи окна есть во всех восьми языках', () {
      for (final code in const [
        'ru', 'en', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de',
      ]) {
        final arb = read('lib/l10n/app_$code.arb');
        for (final key in const [
          'desktopPollNewTitle',
          'desktopPollQuestionHint',
          'desktopPollOptionHint',
          'desktopPollAddOption',
          'desktopPollCreateAction',
          'desktopPollNeedTwo',
          'desktopPollMultipleLabel',
          'desktopPollAnonymousLabel',
        ]) {
          expect(arb.contains('"$key"'), isTrue, reason: '$code: $key');
        }
      }
    });
  });
}
