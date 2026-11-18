// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Вход на компьютере: три дороги, и ни одна не создаёт личность заранее.
//
// 🔴 ЗАЧЕМ ЭТО ВООБЩЕ ПОЯВИЛОСЬ. Компьютерная версия делалась вторым экраном к
// ПЛАТНОМУ телефонному приложению: раз человек купил телефонную версию, телефон
// у него есть по условию, и единственный вход — привязка по QR. Приложение
// стало бесплатным с подписками, условие отпало, и к нам приходят люди без
// телефонной версии вовсе.
//
// 🔴 ГЛАВНОЕ, ЧТО ЗДЕСЬ СТЕРЕЖЁТСЯ. Привязка по QR заводит серверный профиль
// уже на показе кода. Если бы экран выбора оставил это как есть, каждый запуск
// плодил бы брошенный профиль на сервере ключей — ещё до того, как человек
// что-нибудь выбрал.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/onboarding/desktop_auth_gate.dart';
import 'package:secretly_app/ui/welcome/welcome_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DesktopAppViewModel vm;

  setUp(() {
    vm = DesktopAppViewModel(controller: AppController());
  });
  tearDown(() => vm.dispose());

  Widget host(Widget child) => MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(body: child),
        ),
      );

  final ru = lookupAppLocalizations(const Locale('ru'));

  /// С 17.11.2026 вход начинается с приветствия («Начать»), выбор — следом.
  Future<void> openChoice(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(host(DesktopAuthGate(vm: vm)));
    await t.pumpAndSettle();
    expect(find.text('Secretly'), findsOneWidget);
    await t.tap(find.text(ru.welcomeStart));
    await t.pumpAndSettle();
  }

  testWidgets('🔴 предлагается ТРИ дороги, телефон первым', (t) async {
    await openChoice(t);

    expect(find.text(ru.desktopAuthPhoneTitle), findsOneWidget);
    expect(find.text(ru.welcomeDesktopNewAccount), findsOneWidget);
    expect(find.text(ru.desktopAuthRestoreTitle), findsOneWidget);

    // Порядок — не алфавитный: у большинства Secretly уже на телефоне, и это
    // самый быстрый и самый безопасный путь (аккаунт остаётся в двух местах).
    // По макету 17.11.2026 телефон — главная кнопка сверху, под ней «или» и
    // две равные: новый аккаунт слева, восстановление справа.
    final phone = t.getTopLeft(find.text(ru.desktopAuthPhoneTitle));
    final create = t.getTopLeft(find.text(ru.welcomeDesktopNewAccount));
    final restore = t.getTopLeft(find.text(ru.desktopAuthRestoreTitle));
    expect(phone.dy < create.dy, isTrue);
    expect(phone.dy < restore.dy, isTrue);
    expect(create.dx < restore.dx, isTrue);
  });

  testWidgets('🔴 про подписку сказано СРАЗУ, а не после создания', (t) async {
    await openChoice(t);

    // Покупки живут в магазинах. Аккаунт, заведённый здесь, остаётся на
    // бесплатном уровне, пока к нему не присоединится телефон. Молчание об
    // этом читается как обман. Решение владельца 17.11.2026: пояснение — в
    // значке «?» прямо на кнопке «Новый аккаунт», до создания.
    final hint = find.byTooltip(ru.desktopAuthCreateBody);
    expect(hint, findsOneWidget);
    expect(ru.desktopAuthCreateBody.toLowerCase().contains('телефон'), isTrue);
    final button = find.ancestor(
      of: find.text(ru.welcomeDesktopNewAccount),
      matching: find.byType(WelcomeSecondaryButton),
    );
    expect(
      find.descendant(of: button, matching: hint),
      findsOneWidget,
      reason: '«?» стоит на самой кнопке «Новый аккаунт»',
    );
    // У двух других дорог пояснения тоже есть.
    expect(find.byTooltip(ru.desktopAuthPhoneBody), findsOneWidget);
    expect(find.byTooltip(ru.desktopAuthRestoreBody), findsOneWidget);

    // Нажатие на «?» показывает пояснение, а не открывает создание.
    await t.tap(hint);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(ru.desktopAuthCreateBody), findsOneWidget);
    expect(find.text(ru.desktopAuthNameTitle), findsNothing);
    await t.pumpAndSettle(const Duration(seconds: 10));
  });

  testWidgets('«Создать» ведёт к имени, а не сразу к созданию', (t) async {
    await openChoice(t);
    await t.tap(find.text(ru.welcomeDesktopNewAccount));
    await t.pumpAndSettle();

    expect(find.text(ru.desktopAuthNameTitle), findsOneWidget);
    // Назад — есть: человек вправе передумать до того, как что-то создано.
    expect(find.byTooltip(ru.desktopAuthBack), findsOneWidget);
    await t.tap(find.byTooltip(ru.desktopAuthBack));
    await t.pumpAndSettle();
    expect(find.text(ru.welcomeDesktopChooseTitle), findsOneWidget);
  });

  testWidgets('«Восстановить» предлагает набор ПЕРВЫМ', (t) async {
    await openChoice(t);
    await t.tap(find.text(ru.desktopAuthRestoreTitle).first);
    await t.pumpAndSettle();

    // Копия на сервере требует Secretly ID, а его не помнит наизусть никто.
    // В наборе восстановления он уже записан.
    final kitY = t.getTopLeft(find.text(ru.desktopAuthKitOptionTitle)).dy;
    final srvY = t.getTopLeft(find.text(ru.desktopAuthServerOptionTitle)).dy;
    expect(kitY < srvY, isTrue);
  });

  test('🔴 ни одна кнопка выбора не создаёт личность', () {
    // Привязка заводит серверный профиль уже на показе QR. Экран выбора не
    // имеет права делать этого до выбора — иначе каждый запуск оставляет
    // брошенный профиль на сервере ключей.
    // Комментарии отбрасываем: в этом файле об опасности НАПИСАНО, и искать
    // имя по всему тексту значило бы ловить собственное объяснение.
    final gate = File('lib/ui/desktop/onboarding/desktop_auth_gate.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    for (final api in const [
      'createDesktopLinkRequest',
      'createNewServerProfileForCurrentDevice',
      'restoreFrom',
    ]) {
      expect(gate.contains(api), isFalse, reason: 'экран выбора зовёт $api');
    }
  });

  test('🔴 у шага «сохраните набор» НЕТ «пропустить»', () {
    // Решение владельца 23.09.2026. У Secretly нет ни почты, ни телефона:
    // аккаунт, заведённый здесь и нигде больше, умирает вместе с диском — и
    // вернуть его не может никто, включая нас.
    final code = File(
      'lib/ui/desktop/onboarding/desktop_recovery_kit_gate.dart',
    ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');
    for (final word in const ['skip', 'Пропустить', 'later', 'Позже']) {
      expect(code.contains(word), isFalse, reason: 'найдено «$word»');
    }
    // И уйти с шага нельзя: `onBack` ему не передаётся.
    expect(code.contains('onBack:'), isFalse);
  });

  test('🔴 признак «ключа ещё нет» ставит ТОЛЬКО создание', () {
    String read(String p) => File(p).readAsStringSync();
    final create = read('lib/ui/desktop/onboarding/desktop_create_account_flow.dart');
    final restore = read('lib/ui/desktop/onboarding/desktop_restore_flow.dart');
    final pairing = read('lib/ui/desktop/onboarding/desktop_onboarding_screen.dart');
    expect(create.contains('markKitPending'), isTrue);
    // При привязке и восстановлении ключ либо уже есть, либо аккаунт живёт
    // ещё где-то — требовать набор там значило бы задерживать без причины.
    expect(restore.contains('markKitPending'), isFalse);
    expect(pairing.contains('markKitPending'), isFalse);
  });
}
