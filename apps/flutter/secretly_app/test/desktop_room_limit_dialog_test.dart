// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПРЕДЕЛ КОМНАТ — ОКНОМ ПК, А НЕ ТЕЛЕФОННОЙ ВИТРИНОЙ (30.09.2026).
//
// Экраны создания комнаты и входа по приглашению на ПК — телефонные. Упёршись
// в предел бесплатного тарифа, они открывали внутри окна ПК телефонную
// страницу покупки. Теперь ПК проверяет предел заранее — тем же правилом, что
// и телефон, — и объясняет его своим окном.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_models.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_room_limit_dialog.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

const _free = EntitlementState(
  monetizationEnabled: true,
  tier: EntitlementTier.free,
  source: 'test',
  features: EntitlementFeatures.none,
  limits: EntitlementLimits.free,
);

const _premium = EntitlementState(
  monetizationEnabled: true,
  tier: EntitlementTier.premium,
  source: 'test',
  features: EntitlementFeatures.all,
  limits: EntitlementLimits.premium,
);

Future<BuildContext> _pump(WidgetTester t) async {
  late BuildContext ctx;
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );
  return ctx;
}

String _read(String path) => File(path).readAsStringSync();

void main() {
  testWidgets('создание: сколько можно и где взять больше', (t) async {
    final ctx = await _pump(t);
    showDesktopRoomLimitDialog(ctx, state: _free, joining: false);
    await t.pumpAndSettle();
    expect(find.text('Достигнут предел комнат'), findsOneWidget);
    expect(find.text('Можно создать не больше 5 комнат.'), findsOneWidget);
    expect(find.textContaining('В Premium этот предел выше'), findsOneWidget);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Достигнут предел комнат'), findsNothing);
  });

  testWidgets('вступление: предел и что делать', (t) async {
    final ctx = await _pump(t);
    showDesktopRoomLimitDialog(ctx, state: _free, joining: true);
    await t.pumpAndSettle();
    expect(
      find.textContaining('Можно состоять не больше чем в 20 комнатах.'),
      findsOneWidget,
    );
  });

  testWidgets('у кого Premium уже есть — Premium не предлагаем', (t) async {
    final ctx = await _pump(t);
    showDesktopRoomLimitDialog(ctx, state: _premium, joining: false);
    await t.pumpAndSettle();
    expect(find.text('Можно создать не больше 100 комнат.'), findsOneWidget);
    expect(find.textContaining('Premium'), findsNothing);
  });

  test('русские числа склоняются правильно', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(ru.desktopRoomLimitCreate(1), 'Можно создать не больше 1 комнаты.');
    expect(ru.desktopRoomLimitCreate(3), 'Можно создать не больше 3 комнат.');
    expect(
      ru.desktopRoomLimitCreate(21),
      'Можно создать не больше 21 комнаты.',
    );
    expect(
      ru.desktopRoomLimitJoin(21),
      startsWith('Можно состоять не больше чем в 21 комнате.'),
    );
  });

  group('🔴 проверка идёт ДО телефонного экрана (по исходникам)', () {
    void guard(String file, String method, String check) {
      final src = _read(file);
      final at = src.indexOf(method);
      expect(at, greaterThan(0), reason: '$file: $method');
      final body = src.substring(at, at + 1400);
      final checkAt = body.indexOf(check);
      final screenAt = body.indexOf('showDesktopScreenWindow');
      expect(checkAt, greaterThan(0), reason: '$method: нет $check');
      expect(checkAt < screenAt, isTrue, reason: method);
    }

    test('создание комнаты', () {
      guard(
        'lib/ui/desktop/app/desktop_chats_section.dart',
        'Future<void> _startNewRoom()',
        'desktopMayCreateRoom(',
      );
    });

    test('вступление из меню и из переписки', () {
      guard(
        'lib/ui/desktop/app/desktop_chats_section.dart',
        'Future<void> openRoomInvite(',
        'desktopMayJoinRoom(',
      );
    });

    test('вступление по ссылке от системы', () {
      guard(
        'lib/ui/desktop/app/desktop_production_app.dart',
        'Future<void> _openRoomInviteFromLink(',
        'desktopMayJoinRoom(',
      );
    });

    test('правило — телефонное, а не своё', () {
      final src = _read('lib/ui/desktop/app/desktop_room_limit_dialog.dart');
      expect(src.contains('controller.canCreateGroupNow()'), isTrue);
      expect(src.contains('controller.canJoinGroupNow()'), isTrue);
      expect(src.contains('preview.isAlreadyMember'), isTrue);
    });
  });
}
