// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · Полоса тем начинается сразу чипом «Общий».
//
// ЧТО БЫЛО. Слева стояла подпись «ТЕМЫ» 9.5px/800. В макете её нет, и она
// не нужна: чипы с «#» и есть темы, а слово перед ними отнимало ширину у
// самих тем в полосе, которая и так узкая.
//
// 🔴 ФИЛЬТР «ТОЛЬКО МОИ ТЕМЫ» (макет, правый край) НЕ СДЕЛАН НАМЕРЕННО.
// Ответить на «мои» честно нечем: отдельного признака «я писал в этой теме»
// протокол не хранит, а посчитать его можно только по ЗАГРУЖЕННОЙ ленте — она
// подгружается страницами. Фильтр СПРЯТАЛ БЫ тему, в которой человек писал
// раньше, чем дотянулась подгрузка, и тот прочитал бы это как «я туда не
// писал». Пустое место врёт меньше, чем спрятанная ветка.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart' show RoomTopicRef;
import 'package:secretly_app/ui/desktop/chat/room_topics_strip.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

void main() {
  testWidgets('· подписи «ТЕМЫ» в полосе нет', (t) async {
    await t.pumpWidget(
      MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: SizedBox(
              width: 700,
              child: RoomTopicsStrip(
                topics: [
                  RoomTopicRef(id: 't1', title: 'Релиз', createdAtMs: 1),
                ],
                selectedTopicId: null,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('ТЕМЫ'), findsNothing);
    // А сами темы на месте: полоса начинается «Основой».
    //
    // ◆ «Основа», а не «Общий» (указание владельца 15.09.2026): «Общий»
    // звучит как «остальное, что никуда не подошло», на деле это главный
    // поток комнаты, от которого ветки и отходят.
    expect(find.text('Основа'), findsOneWidget);
    expect(find.text('Релиз'), findsOneWidget);
  });

  test('🔴 фильтра «только мои» нет, и причина записана', () {
    final src = File(
      'lib/ui/desktop/chat/room_topics_strip.dart',
    ).readAsStringSync();
    final code = src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code.contains('Только мои'), isFalse);
    // Причина живёт рядом с местом, где фильтр был бы, — иначе через месяц
    // его добавят, не зная, почему его не было.
    expect(src.contains('ФИЛЬТРА «ТОЛЬКО МОИ ТЕМЫ»'), isTrue);
  });
}
