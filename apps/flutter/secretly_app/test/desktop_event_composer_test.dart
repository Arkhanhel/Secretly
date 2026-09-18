// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// СОЗДАНИЕ СОБЫТИЯ С КОМПЬЮТЕРА.
//
// 🔴 Событие можно было только получить с телефона: в меню вложений пункта не
// было вовсе.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/event_composer_dialog.dart';

DesktopEventDraft _draft({
  String title = 'Встреча',
  int startMs = 1789700000000,
}) => DesktopEventDraft(
  title: title,
  startMs: startMs,
  description: '',
  location: '',
);

void main() {
  group('заготовка события', () {
    test('название и дата — годится', () {
      expect(_draft().isValid, isTrue);
    });

    test('🔴 без названия — нет', () {
      expect(_draft(title: '   ').isValid, isFalse);
    });

    test('🔴 без даты — нет', () {
      expect(_draft(startMs: 0).isValid, isFalse);
    });
  });

  group('проводка (по исходникам)', () {
    String read(String path) => File(path).readAsStringSync();

    test('🔴 пункт «Событие» в меню вложений подключён', () {
      final panel = read('lib/ui/desktop/chat/chat_thread_panel.dart');
      expect(panel.contains('onEvent: widget.onComposeEvent'), isTrue);
      expect(
        panel.contains('eventLabel: AppLocalizations.of(context)?'),
        isTrue,
        reason: 'подпись пункта — из языковых файлов, а не зашита в код',
      );
    });

    test('🔴 событие отправляется только в комнату', () {
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      expect(section.contains('showDesktopEventComposer('), isTrue);
      expect(section.contains('sendGroupEvent('), isTrue);
      expect(
        section.contains("onComposeEvent: _convoId.startsWith('group:')"),
        isTrue,
      );
    });

    test('подписи окна есть во всех восьми языках', () {
      for (final code in const [
        'ru', 'en', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de',
      ]) {
        final arb = read('lib/l10n/app_$code.arb');
        for (final key in const [
          'desktopEventNewTitle',
          'desktopEventTitleHint',
          'desktopEventDescriptionHint',
          'desktopEventLocationHint',
          'desktopEventPickWhen',
          'desktopEventNeedTitleAndDate',
        ]) {
          expect(arb.contains('"$key"'), isTrue, reason: '$code: $key');
        }
      }
    });
  });
}
