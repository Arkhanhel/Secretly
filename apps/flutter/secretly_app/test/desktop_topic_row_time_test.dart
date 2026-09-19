// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// У темы справа стоит время последнего сообщения.
//
// ◆ ЧТО БЫЛО. Правая половина строки темы пустовала ВСЕГДА: счётчик
// непрочитанного по темам честно не считается (нет отдельного курсора
// прочтения на ветку — см. `_topicUnreadCounts`), а больше туда ничего не
// ставилось. Отличить живую тему от заброшенной было нечем: список выглядел
// одинаково и через минуту, и через месяц.
//
// 🔴 ГРАНИЦА ЧЕСТНОСТИ. Время считается по ЗАГРУЖЕННОЙ ленте, а не по всей
// истории: отдельного «когда в теме писали в последний раз» протокол не
// передаёт. У темы, чьи сообщения остались за краем подгруженного, времени
// НЕТ вовсе — пустое место ничего не обещает, а неверная дата обещает и врёт.
//
// Признака «в теме идёт голос» из макета здесь нет намеренно: голос по темам
// протокол не различает, рисовать его было бы не по чему.

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/widgets.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_time_label.dart';
import 'package:secretly_app/ui/desktop/chat/details/desktop_selection_store.dart';

final _ru = lookupAppLocalizations(const Locale('ru'));

void main() {
  // Сокращения дней недели даёт `intl`. В приложении их готовит
  // `GlobalMaterialLocalizations`, которого в чистом тесте нет, —
  // поэтому здесь то же самое делается руками.
  setUpAll(() => initializeDateFormatting('ru'));

  group('подпись времени', () {
    final now = DateTime(2026, 9, 15, 18, 30);
    int ms(DateTime d) => d.millisecondsSinceEpoch;

    test('сегодня — часы и минуты', () {
      expect(desktopTimeLabel(ms(DateTime(2026, 9, 15, 14, 19)), _ru, now: now), '14:19');
      expect(desktopTimeLabel(ms(DateTime(2026, 9, 15, 9, 5)), _ru, now: now), '09:05');
    });

    test('вчера — словом', () {
      expect(desktopTimeLabel(ms(DateTime(2026, 9, 14, 23, 59)), _ru, now: now), 'вчера');
    });

    test('на этой неделе — день недели', () {
      // 11.09.2026 — пятница.
      expect(desktopTimeLabel(ms(DateTime(2026, 9, 11, 12, 0)), _ru, now: now), 'пт');
    });

    test('дальше недели — число и месяц', () {
      expect(desktopTimeLabel(ms(DateTime(2026, 6, 30, 12, 0)), _ru, now: now), '30.06');
    });

    test('нуля и отрицательного времени не бывает — подпись пуста', () {
      expect(desktopTimeLabel(0, _ru, now: now), '');
      expect(desktopTimeLabel(-1, _ru, now: now), '');
    });

    test('подпись одна на весь десктоп', () {
      // Список чатов считал время своей копией той же лестницы условий. Две
      // копии разошлись бы на первой правке, а человек читает их рядом.
      final section = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(section.contains('desktopTimeLabel(ms, l10n)'), isTrue);
      expect(
        section.contains("const wd = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс']"),
        isFalse,
        reason: 'второй копии лестницы условий быть не должно',
      );
    });
  });

  group('склад выбора', () {
    test('время едет вместе с темами', () {
      final store = DesktopChatSelectionStore();
      var notified = 0;
      store.addListener(() => notified++);

      store.publishTopics(
        topics: const [],
        currentTopicId: null,
        unread: const <String, int>{},
        lastActivityMs: const {'': 1757000000000},
      );
      expect(store.topicLastActivityMs[''], 1757000000000);
      expect(notified, 1);
    });

    test('🔴 изменилось ТОЛЬКО время — склад всё равно оповещает', () {
      // Иначе новое сообщение в теме не двигало бы подпись: состав тем при
      // этом не меняется, и публикация молча уходила бы в отказ.
      final store = DesktopChatSelectionStore();
      store.publishTopics(
        topics: const [],
        currentTopicId: null,
        unread: const <String, int>{},
        lastActivityMs: const {'': 1},
      );
      var notified = 0;
      store.addListener(() => notified++);
      store.publishTopics(
        topics: const [],
        currentTopicId: null,
        unread: const <String, int>{},
        lastActivityMs: const {'': 2},
      );
      expect(notified, 1);
      expect(store.topicLastActivityMs[''], 2);
    });

    test('ничего не изменилось — молчит', () {
      final store = DesktopChatSelectionStore();
      store.publishTopics(
        topics: const [],
        currentTopicId: null,
        unread: const <String, int>{},
        lastActivityMs: const {'': 7},
      );
      var notified = 0;
      store.addListener(() => notified++);
      store.publishTopics(
        topics: const [],
        currentTopicId: null,
        unread: const <String, int>{},
        lastActivityMs: const {'': 7},
      );
      expect(notified, 0);
    });

    test('чат закрыли — время забыто вместе с темами', () {
      // `clear()` руками не дёрнуть без выбранной переписки (он выходит
      // сразу, если выбора и так нет), поэтому проверяем сам сброс: иначе
      // время прошлой комнаты всплыло бы у следующей.
      final src = File(
        'lib/ui/desktop/chat/details/desktop_selection_store.dart',
      ).readAsStringSync();
      final i = src.indexOf('void clear() {');
      expect(i, greaterThan(0));
      expect(
        src
            .substring(i, src.indexOf('notifyListeners();', i))
            .contains('_topicLastActivityMs = const <String, int>{};'),
        isTrue,
      );
    });
  });

  group('правила строки темы', () {
    final src = File(
      'lib/ui/desktop/chat/details/room_details_view.dart',
    ).readAsStringSync();

    test('счётчик важнее времени и занимает то же место', () {
      expect(src.contains('if (unread == 0 && time.isNotEmpty)'), isTrue);
    });

    test('не знаем времени — справа пусто, а не «давно»', () {
      expect(src.contains('final int? lastActivityMs;'), isTrue);
      expect(src.contains('desktopTimeLabel(lastActivityMs ?? 0, l10n)'), isTrue);
    });

    test('признака голоса нет: протокол его не различает', () {
      expect(src.contains('voiceActive'), isFalse);
      expect(src.contains('graphic_eq'), isFalse);
    });
  });

  test('время считается по загруженной ленте и по максимуму', () {
    final src = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    final i = src.indexOf('Map<String, int> _topicLastActivityMs()');
    expect(i, greaterThan(0));
    final body = src.substring(i, i + 420);
    expect(body.contains('for (final m in _messages)'), isTrue);
    expect(body.contains('if (prev == null || ms > prev) out[key] = ms;'), isTrue);
    // Ленту читаем только когда темы вообще видны.
    expect(body.contains('if (!_topicsVisible) return const <String, int>{};'), isTrue);
  });
}
