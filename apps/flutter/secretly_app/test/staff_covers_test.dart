// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Закрытые обложки команды и новогодняя серия (макет «Staff Covers»,
// 23.11.2026).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/elite_badges.dart';
import 'package:secretly_app/entitlements/cosmetic_catalog.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _staff = [
  'pattern_champagne',
  'pattern_gems',
  'pattern_perfume',
  'pattern_macarons',
  'pattern_watches',
  'pattern_movement',
  'pattern_armillary',
  'pattern_cards',
  'pattern_gifts',
];

const _newYear = [
  'pattern_ornaments',
  'pattern_snowflakes',
  'pattern_snowman',
  'pattern_tangerines',
  'pattern_gingerbread',
  'pattern_sparkler',
  'pattern_bells',
  'pattern_cocoa',
  'pattern_tree',
  'pattern_snowglobe',
];

final _serverId = RegExp(r'^[a-z0-9_]{1,32}$');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EliteBadges.instance.resetForTest();
  });

  test('🔴 обложек команды нет в каталоге и в поиске по id', () {
    expect(kStaffProfileCovers.map((c) => c.id).toList(), _staff);
    expect(kStaffCoverIds, _staff.toSet());
    final all = kAllProfileCovers.map((c) => c.id).toSet();
    for (final id in _staff) {
      expect(all, isNot(contains(id)), reason: id);
      expect(coverById(id), isNull, reason: id);
      expect(staffCoverById(id), isNotNull, reason: id);
      expect(isCosmeticFree(CosmeticKind.profileCover, id), isFalse);
      // Сервер принимает id только такого вида.
      expect(_serverId.hasMatch(id), isTrue, reason: id);
    }
    // Новогодние в поиске по id обложек команды не находятся.
    for (final id in _newYear) {
      expect(staffCoverById(id), isNull, reason: id);
    }
  });

  test('новогодние — платные и первые среди платных, по порядку макета', () {
    final first = kFreeProfileCoverCount;
    final ids = kAllProfileCovers.map((c) => c.id).toList();
    expect(ids.sublist(first, first + _newYear.length), _newYear);
    for (final id in _newYear) {
      expect(isCosmeticFree(CosmeticKind.profileCover, id), isFalse, reason: id);
      expect(_serverId.hasMatch(id), isTrue, reason: id);
      final c = coverById(id)!;
      expect(c.nameRu.trim(), isNotEmpty);
      expect(c.nameEn.trim(), isNotEmpty);
    }
  });

  testWidgets('у всех 20 есть имя на восьми языках', (t) async {
    for (final c in [...kStaffProfileCovers, ...kNewYearProfileCovers]) {
      for (final loc in const [
        Locale('ru'),
        Locale('en'),
        Locale('uk'),
        Locale('es'),
        Locale('pt'),
        Locale('pt', 'BR'),
        Locale('fr'),
        Locale('de'),
      ]) {
        late String name;
        await t.pumpWidget(
          Localizations(
            locale: loc,
            delegates: const [
              DefaultWidgetsLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
            ],
            child: Builder(
              builder: (ctx) {
                name = c.nameLocalized(ctx);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(name.trim(), isNotEmpty, reason: '${c.id} $loc');
        // Украинское имя — своё (не английская заглушка): значит, строка
        // перевода для обложки есть.
        if (loc.languageCode == 'uk') {
          expect(name, isNot(c.nameEn), reason: '${c.id} uk');
        }
      }
    }
  });

  test('🔴 без владельца профиля (комнаты, превью) — пусто', () {
    for (final id in _staff) {
      expect(coverWidgetFor(id), isNull, reason: id);
      expect(coverBackWidgetFor(id), isNull, reason: id);
      expect(coverWidgetFor(id, ownerProfileId: '  '), isNull, reason: id);
    }
  });

  testWidgets('🔴 видна только в профиле со знаком команды', (t) async {
    final w = coverWidgetFor(_staff.first, ownerProfileId: 'pid_team');
    expect(w, isA<TeamCoverGate>());
    await t.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 390, height: 460, child: w),
      ),
    );
    await t.pump();
    // Знака нет — ничего.
    expect(find.byType(SizedBox), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(TeamCoverGate),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    // Знак пришёл с сервера — обложка появилась сама.
    EliteBadges.instance.record('pid_team', 'h2', present: true);
    await t.pump();
    expect(
      find.descendant(
        of: find.byType(TeamCoverGate),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    // Знак сняли — пропала.
    EliteBadges.instance.record('pid_team', null, present: true);
    await t.pump();
    expect(
      find.descendant(
        of: find.byType(TeamCoverGate),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    await t.pumpWidget(const SizedBox());
  });

  test('знак команды = знак, выданный оператором', () {
    expect(EliteBadges.instance.isTeam('x'), isFalse);
    EliteBadges.instance.record('x', 'h2', present: true);
    expect(EliteBadges.instance.isTeam('x'), isTrue);
    expect(EliteBadges.instance.isTeam(null), isFalse);
    expect(EliteBadges.instance.isTeam(''), isFalse);
  });
}
