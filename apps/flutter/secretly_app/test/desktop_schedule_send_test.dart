// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 «ОТПРАВИТЬ ПОЗЖЕ» В ОКНЕ НЕ БЫЛО ВОВСЕ.
//
// Указание владельца 16.09.2026: «доделай перевод сообщений и отложенную
// отправку на ПК».
//
// На телефоне она есть давно и держится на ОБЩЕМ коде: `sendMessage` и
// `sendGroupMessage` принимают `scheduledAtMs`, кладут местную заготовку и
// отпускают её в срок сами — переживая перезапуск приложения. То есть в окне
// недоставало ровно выбора времени и одного параметра в вызове; ничего в
// отправке переписывать не пришлось.
//
// 🔴 ПРОШЕДШЕЕ ВРЕМЯ НЕ ПРИНИМАЕТСЯ. Для контроллера «отправить в прошлое»
// означает «немедленно»: человек нажал «позже», а сообщение ушло сразу. Такое
// молчаливое несоответствие обещанию хуже отказа.

import 'package:flutter/widgets.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/schedule_send_dialog.dart';

final _ru = lookupAppLocalizations(const Locale('ru'));

void main() {
  final panel = File(
    'lib/ui/desktop/chat/chat_thread_panel.dart',
  ).readAsStringSync();
  final composer = File(
    'lib/ui/desktop/chat/composer.dart',
  ).readAsStringSync();
  final section = File(
    'lib/ui/desktop/app/desktop_chats_section.dart',
  ).readAsStringSync();

  group('🔴 готовые варианты времени', () {
    test('днём предлагают и вечер сегодня, и утро завтра', () {
      final presets = scheduleSendPresets(DateTime(2026, 9, 16, 11, 20), _ru);
      expect(presets.map((p) => p.label), contains('Сегодня в 19:00'));
      expect(presets.map((p) => p.label), contains('Завтра в 9:00'));
    });

    test('🔴 вечером «сегодня в 19:00» ПРОПАДАЕТ — это уже прошлое', () {
      final presets = scheduleSendPresets(DateTime(2026, 9, 16, 21, 40), _ru);
      expect(presets.map((p) => p.label), isNot(contains('Сегодня в 19:00')));
      expect(presets.map((p) => p.label), contains('Завтра в 9:00'));
    });

    test('🔴 ни один вариант не смотрит в прошлое', () {
      for (final hour in <int>[0, 6, 12, 18, 23]) {
        final now = DateTime(2026, 9, 16, hour, 30);
        for (final preset in scheduleSendPresets(now, _ru)) {
          expect(
            preset.at.isAfter(now),
            isTrue,
            reason: '«${preset.label}» в $hour:30 указывает назад',
          );
        }
      }
    });

    test('через неделю — это ровно через семь дней, а не «в следующий вторник»',
        () {
      final now = DateTime(2026, 9, 16, 11, 20);
      final week = scheduleSendPresets(now, _ru)
          .firstWhere((p) => p.label == 'Через неделю');
      expect(week.at.difference(now).inDays, 7);
    });
  });

  group('подпись момента', () {
    final now = DateTime(2026, 9, 16, 11, 20);

    test('сегодня', () {
      expect(
        formatScheduleMoment(DateTime(2026, 9, 16, 19), _ru, now: now),
        'сегодня в 19:00',
      );
    });

    test('завтра', () {
      expect(
        formatScheduleMoment(DateTime(2026, 9, 17, 9, 5), _ru, now: now),
        'завтра в 09:05',
      );
    });

    test('дальше — числом', () {
      expect(
        formatScheduleMoment(DateTime(2026, 9, 23, 11, 20), _ru, now: now),
        '23.09 в 11:20',
      );
    });
  });

  group('🔴 проводка до контроллера', () {
    test('время едет в посылке отправки', () {
      expect(panel.contains('final int? scheduledAtMs;'), isTrue);
      expect(panel.contains('scheduledAtMs: scheduledAtMs,'), isTrue);
    });

    test('и доходит до ОБОИХ вызовов — личного чата и комнаты', () {
      final i = section.indexOf('Future<void> _send(DesktopComposerSubmission');
      expect(i, greaterThan(0));
      final body = section.substring(i, i + 3400);
      expect(
        RegExp(r'scheduledAtMs: submission\.scheduledAtMs')
            .allMatches(body)
            .length,
        2,
        reason: 'в комнату отложить было бы нельзя',
      );
    });

    test('🔴 правку отложить нельзя — у неё нет «потом»', () {
      final i = panel.indexOf('Future<bool> _submitLater(');
      expect(i, greaterThan(0));
      final body = panel.substring(i, i + 1200);
      expect(body.contains('_ctx!.isEdit'), isTrue);
      expect(body.contains('desktopThreadNoScheduleEdit'), isTrue);
    });
  });

  group('кнопка', () {
    test('🔴 «позже» — правой кнопкой по отправке, и об этом написано', () {
      expect(composer.contains('onSecondaryTapDown:'), isTrue);
      expect(composer.contains('l10n.desktopComposerSendHint'), isTrue);
      expect(
        File('lib/l10n/app_ru.arb')
            .readAsStringSync()
            .contains('Правая кнопка — отправить позже'),
        isTrue,
        reason: 'иначе возможность остаётся тайным знанием',
      );
    });

    test('🔴 передумал — набранное осталось на месте', () {
      final i = composer.indexOf('Future<void> _trySendLater()');
      expect(i, greaterThan(0));
      final body = composer.substring(i, i + 500);
      // Чистим поле только после подтверждённой постановки в очередь.
      expect(body.indexOf('if (!mounted || !sent) return;'),
          lessThan(body.indexOf('widget.controller.clear();')));
    });

    test('нет обработчика — нет и правой кнопки', () {
      expect(composer.contains('onScheduleTap: widget.onScheduleSend == null'),
          isTrue);
    });
  });

  test('🔴 у запланированного пузыря пишется ДЕНЬ, а не только часы', () {
    // У такой заготовки `created_at_ms` — момент БУДУЩЕЙ отправки, и подвал
    // показывал бы «09:00» ровно так же, как у отправленного в девять утра.
    // Для сообщения, которое уйдёт завтра, это неправда.
    expect(
      section.contains('event.localState == MessageLocalState.scheduled'),
      isTrue,
    );
    final i = section.indexOf('final time = event.localState ==');
    expect(i, greaterThan(0));
    expect(
      section.substring(i, i + 300).contains('formatScheduleMoment('),
      isTrue,
      reason: 'подпись та же, что в выборе времени — иначе они разойдутся',
    );
  });

  test('🔴 запланированное сообщение видно в ленте отдельным значком', () {
    final bubble = File(
      'lib/ui/desktop/chat/message_bubble.dart',
    ).readAsStringSync();
    expect(bubble.contains('case DeliveryStatus.scheduled:'), isTrue);
    expect(bubble.contains('calendar_clock_24_regular'), isTrue);
    // И состояние из базы действительно в него превращается.
    expect(section.contains('case MessageLocalState.scheduled:'), isTrue);
    expect(section.contains('return DeliveryStatus.scheduled;'), isTrue);
  });
}
