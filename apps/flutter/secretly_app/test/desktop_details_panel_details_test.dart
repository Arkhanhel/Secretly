// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Правая панель подробностей: свой тон, своя ширина и видимая подсказка
// «это можно скопировать».

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:secretly_app/ui/desktop/chat/details/details_info_section.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 330, child: child)),
  ),
);

void main() {
  // · КОПИРОВАНИЕ РАБОТАЛО ПО НАЖАТИЮ НА ВСЮ СТРОКУ — и узнать об этом было
  // нельзя ниоткуда: ни курсор, ни вид не отличали «Secretly ID», который
  // копируется, от «Участников», которые просто число.
  testWidgets('· строку с копированием видно по значку', (t) async {
    await t.pumpWidget(
      host(
        const DetailsInfoRow(
          icon: FluentIcons.person_24_regular,
          label: 'Secretly ID',
          value: '6R2K-9QZP',
          copyValue: '6R2K-9QZP',
        ),
      ),
    );
    expect(find.byIcon(FluentIcons.copy_24_regular), findsOneWidget);
  });

  testWidgets('· у строки без копирования значка нет', (t) async {
    await t.pumpWidget(
      host(
        const DetailsInfoRow(
          icon: FluentIcons.people_24_regular,
          label: 'Участники',
          value: '12 участников',
        ),
      ),
    );
    expect(find.byIcon(FluentIcons.copy_24_regular), findsNothing);
  });

  testWidgets('свой значок справа важнее автоматического', (t) async {
    await t.pumpWidget(
      host(
        const DetailsInfoRow(
          icon: FluentIcons.link_24_regular,
          label: 'Ссылка',
          value: 'links.secretlyapp.com/…',
          copyValue: 'https://links.secretlyapp.com/x',
          trailing: Icon(FluentIcons.open_24_regular, size: 16),
        ),
      ),
    );
    expect(find.byIcon(FluentIcons.copy_24_regular), findsNothing);
    expect(find.byIcon(FluentIcons.open_24_regular), findsOneWidget);
  });

  test('🔴 значок считается в ОДНОМ месте, а не в трёх вызовах', () {
    // Иначе подсказка разъедется: в одном месте её поставят, в другом забудут.
    final section = File(
      'lib/ui/desktop/chat/details/details_info_section.dart',
    ).readAsStringSync();
    expect(section.contains("] else if ((copyValue ?? '').isNotEmpty)"), isTrue);
    // И ведущий значок строки «ID комнаты» больше не повторяет значок справа.
    final room = File(
      'lib/ui/desktop/chat/details/room_details_view.dart',
    ).readAsStringSync();
    final i = room.indexOf('label: l10n.desktopRoomId');
    expect(room.substring(i - 300, i).contains('copy_24_regular'), isFalse);
  });

  test('· панель шириной 330 и своего тона', () {
    final shell = File(
      'lib/ui/desktop/shell/desktop_shell.dart',
    ).readAsStringSync();
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    final panel = File(
      'lib/ui/desktop/shell/details_panel.dart',
    ).readAsStringSync();
    expect(shell.contains('this.detailsWidth = 330,'), isTrue);
    expect(app.contains('detailsWidth: 330,'), isTrue);
    // Свой тон, а не тон списка чатов: окно устроено как три полосы, и когда
    // крайние две одного тона, переписка между ними читается ямой.
    expect(panel.contains('color: c.detailsPanel'), isTrue);
    expect(panel.contains('color: c.chatList'), isFalse);
  });
}
