// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Карточка участника комнаты: по участнику наконец можно щёлкнуть.
//
// 🔴 ЧТО БЫЛО. В строке участника был ТОЛЬКО правый щелчок с меню управления.
// Левым не открывалось ничего, и курсор над строкой был принудительно обычной
// стрелкой — список честно сообщал, что нажимать тут не на что. Узнать, кто
// этот человек, и написать ему из комнаты было нечем: приходилось искать его
// имя в общем списке чатов, а если переписки ещё нет — там его и не было.
//
// 🔴 ЧЕГО В КАРТОЧКЕ НЕТ, ХОТЯ В МАКЕТЕ ЕСТЬ. «@handle» (такого поля нет ни в
// одной модели профиля), галочка проверки (у участника комнаты этого признака
// нет, а галочка означала бы «я сверил ключи»), чипы украшений (состав комнаты
// их не знает) и кнопки звонка (позвонить можно только в переписке, которой с
// этим человеком может ещё не быть — кнопка привела бы туда же, куда
// «Написать»).

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/details/member_profile_card.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget host(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('показывает имя, идентификатор и роль', (t) async {
    await t.pumpWidget(
      host(
        MemberProfileCard(
          name: 'Nathan Ford',
          profileId: '6R2K-5KJI-VT2M',
          avatarPath: null,
          isOnline: true,
          roleLabel: 'Админ',
          onWrite: () {},
          onCopyId: () {},
        ),
      ),
    );
    expect(find.text('Nathan Ford'), findsOneWidget);
    expect(find.text('6R2K-5KJI-VT2M · АДМИН'), findsOneWidget);
    expect(find.text('в сети'), findsOneWidget);
  });

  testWidgets('без роли строка — один идентификатор', (t) async {
    await t.pumpWidget(
      host(
        MemberProfileCard(
          name: 'Tara Quinn',
          profileId: 'ABCD-EFGH',
          avatarPath: null,
          isOnline: false,
          onWrite: () {},
          onCopyId: () {},
        ),
      ),
    );
    expect(find.text('ABCD-EFGH'), findsOneWidget);
    expect(find.text('не в сети'), findsOneWidget);
  });

  testWidgets('🔴 состояние членства не замалчивается', (t) async {
    await t.pumpWidget(
      host(
        MemberProfileCard(
          name: 'Grace Sloan',
          profileId: 'ZZ-11',
          avatarPath: null,
          isOnline: false,
          statusNote: 'Ждёт одобрения',
          onWrite: () {},
          onCopyId: () {},
        ),
      ),
    );
    // Карточка предлагает написать человеку — молчать о том, что он ещё не в
    // комнате, нельзя.
    expect(find.text('Ждёт одобрения'), findsOneWidget);
  });

  testWidgets('«Написать» и «Скопировать ID» срабатывают', (t) async {
    var wrote = 0;
    var copied = 0;
    await t.pumpWidget(
      host(
        MemberProfileCard(
          name: 'Max Palmer',
          profileId: 'QQ-22',
          avatarPath: null,
          isOnline: true,
          onWrite: () => wrote++,
          onCopyId: () => copied++,
        ),
      ),
    );
    await t.tap(find.text('Написать'));
    await t.pump();
    expect(wrote, 1);
    await t.tap(find.byTooltip('Скопировать ID'));
    await t.pump();
    expect(copied, 1);
  });

  test('пустое имя не оставляет карточку безымянной', () async {
    // Подстановка идентификатора вместо пустого имени — то же правило, что в
    // строке списка участников.
    final src = File(
      'lib/ui/desktop/chat/details/member_profile_card.dart',
    ).readAsStringSync();
    expect(src.contains('name.trim().isEmpty ? profileId : name.trim()'), isTrue);
  });

  test('🔴 придуманных признаков в карточке нет', () {
    final src = File(
      'lib/ui/desktop/chat/details/member_profile_card.dart',
    ).readAsStringSync();
    // Галочка проверки означала бы «я сверил ключи» — такого признака у
    // участника комнаты нет.
    expect(src.contains('DesktopVerifiedBadge'), isFalse);
    // Кнопок звонка нет: позвонить можно только в переписке, которой может
    // ещё не существовать.
    expect(src.contains('FluentIcons.call_24'), isFalse);
    expect(src.contains('FluentIcons.video_24'), isFalse);
  });

  test('строка открывает карточку левым щелчком', () {
    final view = File(
      'lib/ui/desktop/chat/details/room_details_view.dart',
    ).readAsStringSync();
    expect(view.contains('onTap: () => onOpen(context, member)'), isTrue);
    expect(
      view.contains('cursor: SystemMouseCursors.basic'),
      isFalse,
      reason: 'курсор больше не сообщает «нажимать не на что»',
    );
    expect(view.contains('DesktopPopover.showFrom<void>'), isTrue);
  });
}
