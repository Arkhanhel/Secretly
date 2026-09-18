// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_screen_l10n.dart';

/// 🔴 «был(а) 01.01 03:00» в шапке чата (полевой отчёт 03.08.2026).
///
/// Шапка передавала в форматтер ЖЁСТКИЙ НОЛЬ как заглушку, пока не подтянется
/// настоящее присутствие, а форматтер честно превращал его в дату:
/// `DateTime.fromMillisecondsSinceEpoch(0)` = 01.01.1970 00:00 UTC, то есть
/// 01.01 03:00 по Москве.
///
/// Сервер тут ни при чём — тот же экран показал бы 1970 год и с мгновенным
/// ответом. Это наш класс дефекта: ОТСУТСТВУЮЩЕЕ значение выдавалось за
/// настоящее.
void main() {
  /// Прогоняет форматтер в дереве с нужным языком.
  Future<String> render(
    WidgetTester tester, {
    required int? timestampMs,
    required DateTime now,
    Locale locale = const Locale('ru'),
  }) async {
    late String out;
    // Голый Localizations, без MaterialApp: форматтеру нужен ТОЛЬКО язык
    // (`Localizations.localeOf`), а материальные переводы русского в тестовой
    // сборке нет — и тащить их сюда значило бы проверять не то.
    await tester.pumpWidget(
      Localizations(
        locale: locale,
        delegates: const <LocalizationsDelegate<Object>>[
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              out = chatLastSeenText(
                context,
                timestampMs: timestampMs,
                now: now,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return out;
  }

  final now = DateTime(2026, 8, 3, 10, 9);

  /// 🔴 Собственно дефект: ноль обязан читаться как «неизвестно», а не как
  /// дата из 1970-го.
  testWidgets('🔴 ноль — это «неизвестно», а не 1970 год', (tester) async {
    final text = await render(tester, timestampMs: 0, now: now);
    expect(text, 'был(а) недавно');
    expect(text.contains('01.01'), isFalse,
        reason: 'ровно та строка, что видел пользователь');
    expect(text.contains('1970'), isFalse);
  });

  /// null — то же самое: шапка теперь передаёт именно его.
  testWidgets('🔴 null — тоже «неизвестно»', (tester) async {
    expect(await render(tester, timestampMs: null, now: now),
        'был(а) недавно');
  });

  /// 🔴 И НЕ «не в сети»: человек мог написать секунду назад, объявлять его
  /// офлайн в этот момент — врать так же, как врал 1970 год, только незаметнее.
  testWidgets('🔴 неизвестное время не выдаётся за «не в сети»',
      (tester) async {
    final ru = await render(tester, timestampMs: null, now: now);
    expect(ru.contains('не в сети'), isFalse);
    final en = await render(
      tester,
      timestampMs: null,
      now: now,
      locale: const Locale('en'),
    );
    expect(en, 'last seen recently');
    expect(en.toLowerCase().contains('offline'), isFalse);
  });

  /// Отрицательное значение — та же поломанная запись, что и ноль.
  testWidgets('отрицательное время тоже «неизвестно»', (tester) async {
    expect(await render(tester, timestampMs: -1, now: now), 'был(а) недавно');
  });

  /// Время из будущего — часы разошлись; это не повод показывать завтрашнюю
  /// дату.
  testWidgets('время из будущего читается как «недавно»', (tester) async {
    final future = now.add(const Duration(hours: 3)).millisecondsSinceEpoch;
    expect(await render(tester, timestampMs: future, now: now),
        'был(а) недавно');
  });

  /// А НАСТОЯЩЕЕ время обязано остаться настоящим — правка не должна была
  /// превратить форматтер в вечное «недавно».
  testWidgets('сегодняшнее время показывается часами', (tester) async {
    final ms = DateTime(2026, 8, 3, 9, 5).millisecondsSinceEpoch;
    expect(await render(tester, timestampMs: ms, now: now), 'был(а) в 09:05');
  });

  testWidgets('давнее время показывается датой', (tester) async {
    final ms = DateTime(2026, 7, 28, 21, 40).millisecondsSinceEpoch;
    expect(
      await render(tester, timestampMs: ms, now: now),
      'был(а) 28.07 21:40',
    );
  });
}
