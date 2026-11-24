// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 22.11.2026: пружина iPhone на главной (верх под пальцем — «Личные»,
// остальное пружинит) и окно знака команды Secretly.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/scroll_feel.dart';
import 'package:secretly_app/ui/widgets/elite_badge_mark.dart';
import 'package:secretly_app/ui/widgets/verified_badges.dart';

ScrollMetrics _m(double pixels) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: 1000,
  pixels: pixels,
  viewportDimension: 800,
  axisDirection: AxisDirection.down,
  devicePixelRatio: 3,
);

void main() {
  group('пружина главной', () {
    test('палец тянет у верха — край прижат (overscroll уходит «Личным»)', () {
      final p = TopPullBounceScrollPhysics(topPullDragActive: () => true);
      expect(p.applyBoundaryConditions(_m(0), -12), -12);
      expect(p.applyBoundaryConditions(_m(5), -7), -7);
    });

    test('бросок к верху и низ списка — пружина (без прижатия)', () {
      final p = TopPullBounceScrollPhysics(topPullDragActive: () => false);
      expect(p.applyBoundaryConditions(_m(0), -12), 0);
      final drag = TopPullBounceScrollPhysics(topPullDragActive: () => true);
      // Внизу пружинит и под пальцем.
      expect(drag.applyBoundaryConditions(_m(1000), 1012), 0);
    });

    test('applyTo сохраняет признак пальца', () {
      final p = TopPullBounceScrollPhysics(topPullDragActive: () => true)
          .applyTo(const AlwaysScrollableScrollPhysics());
      expect(p, isA<TopPullBounceScrollPhysics>());
      expect(p.applyBoundaryConditions(_m(0), -3), -3);
    });
  });

  group('знак команды', () {
    test('роли по id, с дефисами и без', () {
      expect(secretlyTeamRoleOf('Z75L-TCBZ-437I-U-DXT6XPY'), SecretlyTeamRole.founder);
      expect(secretlyTeamRoleOf('od3swhk6chbmufh54hxa'), SecretlyTeamRole.founder);
      expect(secretlyTeamRoleOf('UT5Z-UIO2-TG6H-Y-Y7UG3DA'), SecretlyTeamRole.tester);
      expect(secretlyTeamRoleOf('TMZH-BYEI-GROG-6-ZNHLJIQ'), SecretlyTeamRole.tester);
      expect(secretlyTeamRoleOf('AAAA-BBBB-CCCC-D-EEEEEEE'), isNull);
      expect(secretlyTeamRoleOf(null), isNull);
    });

    testWidgets('окно: команда, текст и статус', (t) async {
      final style = verifiedBadgeStyleFromSlug('h2') ??
          VerifiedBadgeStyle.values.first;
      await t.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showSecretlyTeamBadgeSheet(
                  context,
                  role: SecretlyTeamRole.tester,
                  style: style,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 30));
      }
      expect(find.text('Команда Secretly'), findsOneWidget);
      expect(find.textContaining('состав разработчиков'), findsOneWidget);
      expect(find.text('Тестировщик'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  });
}
