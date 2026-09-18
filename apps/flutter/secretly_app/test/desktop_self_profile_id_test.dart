// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ◆ Под именем — идентификатор, а рядом «Редактировать».
//
// Своё присутствие и так очевидно: человек сидит перед этим окном. А свой
// Secretly ID — единственное, чем он делится, чтобы с ним связались, и искать
// его в «Информации» ниже приходилось каждый раз.
//
// Правка при этом шла нажатием по строкам «Имя» и «О себе», и узнать об этом
// было нельзя: строки выглядели фактами, а не полями.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/details/details_headline.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget host(Widget child) => MaterialApp(
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 330, child: child)),
  ),
);

void main() {
  testWidgets('◆ идентификатор виден под именем', (t) async {
    await t.pumpWidget(
      host(
        const DetailsHeadline(
          name: 'Yurii',
          idLine: '6R2K-5KJI-VT2M',
          avatar: SizedBox(width: 88, height: 88),
        ),
      ),
    );
    expect(find.text('6R2K-5KJI-VT2M'), findsOneWidget);
  });

  testWidgets('🔴 чужому профилю строка не передаётся', (t) async {
    // Там под именем полезнее присутствие.
    await t.pumpWidget(
      host(
        const DetailsHeadline(
          name: 'Игорь',
          presence: 'в сети',
          avatar: SizedBox(width: 88, height: 88),
        ),
      ),
    );
    expect(find.text('в сети'), findsOneWidget);
    final contact = File(
      'lib/ui/desktop/chat/details/contact_details_view.dart',
    ).readAsStringSync();
    final room = File(
      'lib/ui/desktop/chat/details/room_details_view.dart',
    ).readAsStringSync();
    expect(contact.contains('idLine:'), isFalse);
    expect(room.contains('idLine:'), isFalse);
  });

  testWidgets('кнопка справа рисуется, когда её передали', (t) async {
    await t.pumpWidget(
      host(
        const DetailsHeadline(
          name: 'Yurii',
          trailing: Text('Редактировать'),
          avatar: SizedBox(width: 88, height: 88),
        ),
      ),
    );
    expect(find.text('Редактировать'), findsOneWidget);
  });

  test('🔴 идентификатор не показан ДВАЖДЫ на одном экране', () {
    // Он переехал под имя; в шапке панели повтор читался бы как две разные
    // строки.
    final view = File(
      'lib/ui/desktop/chat/details/self_profile_view.dart',
    ).readAsStringSync();
    expect(view.contains('idLine: _c.profileId'), isTrue);
    expect(view.contains('subtitle: id,'), isFalse);
  });

  test('«Редактировать» открывает тот же путь, что строка «Имя»', () {
    // Два разных способа править одно и то же разъехались бы: у одного
    // ограничение длины, у другого нет.
    final view = File(
      'lib/ui/desktop/chat/details/self_profile_view.dart',
    ).readAsStringSync();
    final i = view.indexOf("label: 'Редактировать'");
    final body = view.substring(i, (i + 500).clamp(0, view.length));
    expect(body.contains('_editLine('), isTrue);
    expect(body.contains('save: (v) => _c.setMyNickname(v)'), isTrue);
  });

  test('идентификатор набран моноширинным', () {
    // Это не слово, а КОД: его переписывают на слух или сверяют знак за знаком.
    final headline = File(
      'lib/ui/desktop/chat/details/details_headline.dart',
    ).readAsStringSync();
    final i = headline.indexOf("idLine!.trim()");
    final body = headline.substring(i, (i + 260).clamp(0, headline.length));
    expect(body.contains('DType.mono'), isTrue);
  });
}
