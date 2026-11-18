// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// iPhone с крупным текстом (17.11.2026). Многие включают в настройках iPhone
// «Размер текста» побольше, а приложение его слушается (нигде не зажат). На
// самом маленьком iPhone (SE, 375×667) с текстом ×1,35 и ×2 и с открытой
// клавиатурой ни один экран приветствия, окно подтверждения, капсула
// уведомления и строка со смахиванием не должны вылезать за край.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/l10n/app_localizations_ru.dart';
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/apple_style.dart';
import 'package:secretly_app/ui/onboarding_flow.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake extends AppController {
  String nickname = '';
  String? pw;

  @override
  String get myNickname => nickname;
  @override
  Future<void> setMyNickname(String v) async => nickname = v;
  @override
  bool get hasServerProfile => true;
  @override
  String get profileId => 'ABCD-EFGH-JKLM-NPQR';
  @override
  bool get safeBackupAutoEnabled => false;
  @override
  bool get safeBackupAutoServerEnabled => true;
  @override
  int get safeBackupAutoIntervalMin => 24 * 60;
  @override
  Future<void> setSafeBackupAutoEnabled(bool value) async {}
  @override
  Future<void> setSafeBackupAutoServerEnabled(bool value) async {}
  @override
  Future<void> setSafeBackupAutoIntervalMinutes(int minutes) async {}
  @override
  Future<void> setSafeBackupAutoPassword(String password) async =>
      pw = password;
  @override
  Future<bool> hasSafeBackupAutoPassword() async => pw != null;
}

final _ru = AppLocalizationsRu();

Widget _host(Widget child, double scale, {Brightness b = Brightness.light}) {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    theme: ThemeData(brightness: b, platform: TargetPlatform.iOS),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
      child: AppleToastMessenger(
        key: messengerKey,
        child: Stack(children: [child!, const AppleToastHost()]),
      ),
    ),
    home: child,
  );
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _tap(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).last);
  await t.pumpAndSettle(const Duration(milliseconds: 100));
  await t.tap(find.text(text).last, warnIfMissed: false);
  await _settle(t);
}

void _noOverflow(WidgetTester t, String where) {
  final e = t.takeException();
  expect(e, isNull, reason: '$where: $e');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    appleToastCurrent.value = null;
  });

  void iphoneSE(WidgetTester t, {double keyboard = 0}) {
    t.view.physicalSize = const Size(375, 667);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 20);
    t.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(t.view.reset);
  }

  for (final scale in [1.35, 2.0]) {
    testWidgets('приветствие целиком, текст ×$scale', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      iphoneSE(t);
      final c = _Fake();
      await t.pumpWidget(
        _host(OnboardingFlow(controller: c, onComplete: () {}), scale),
      );
      await _settle(t);
      _noOverflow(t, 'приветствие');
      // Название не ломается на «Secretl» и «y».
      final title = t.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Secretly'),
          matching: find.byType(RichText),
        ),
      );
      expect(title.didExceedMaxLines, isFalse);
      // Одна строка: высота меньше полутора строк крупного шрифта.
      expect(
        t.getSize(find.text('Secretly')).height,
        lessThan(46 * scale * 1.5),
        reason: 'одной строкой',
      );

      await _tap(t, _ru.welcomeCreateAccount);
      _noOverflow(t, 'имя');
      // Клавиатура открыта: поле и «Продолжить» должны оставаться доступны.
      t.view.viewInsets = const FakeViewPadding(bottom: 291);
      await t.enterText(find.byType(TextField), 'Александра');
      await _settle(t);
      _noOverflow(t, 'имя с клавиатурой');
      await t.ensureVisible(find.text(_ru.continueAction));
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      expect(
        t.getRect(find.text(_ru.continueAction)).bottom,
        lessThanOrEqualTo(667 - 291 + 1),
        reason: '«Продолжить» не под клавиатурой',
      );
      t.view.viewInsets = FakeViewPadding.zero;
      await _tap(t, _ru.continueAction);
      for (var i = 0; i < 24; i++) {
        await t.pump(const Duration(milliseconds: 250));
      }
      _noOverflow(t, 'ключи');
      await _settle(t);

      expect(find.text(_ru.welcomeBackupTitle), findsOneWidget);
      _noOverflow(t, 'копия');
      await t.enterText(find.byType(TextField).first, 'Secret!pass');
      await _settle(t);
      // Второе поле появляется после первого.
      await t.enterText(find.byType(TextField).at(1), 'Secret!pass');
      await _settle(t);
      _noOverflow(t, 'копия с паролем');
      await _tap(t, _ru.welcomeBackupLater);
      _noOverflow(t, 'уведомления');
      expect(find.text(_ru.welcomeNotifyTitle), findsOneWidget);
      await _tap(t, _ru.welcomeNotifyNotNow);
      _noOverflow(t, 'готово');
      expect(find.text(_ru.welcomeOpenApp), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('восстановление, текст ×$scale', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      iphoneSE(t);
      await t.pumpWidget(
        _host(OnboardingFlow(controller: _Fake(), onComplete: () {}), scale),
      );
      await _settle(t);
      await _tap(t, _ru.welcomeHaveAccount);
      _noOverflow(t, 'выбор восстановления');
      await _tap(t, _ru.welcomeRestoreCloudTitle);
      _noOverflow(t, 'облако');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('окно, капсула и смахивание, текст ×$scale', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      iphoneSE(t);
      late BuildContext ctx;
      await t.pumpWidget(
        _host(
          Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return ListView(
                  children: [
                    AppleSwipeActions(
                      leading: [
                        AppleSwipeAction(
                          label: _ru.pin,
                          icon: Icons.push_pin,
                          color: Colors.orange,
                          onPressed: () {},
                        ),
                      ],
                      trailing: [
                        AppleSwipeAction(
                          label: _ru.chatSwipeUnmute,
                          icon: Icons.notifications,
                          color: Colors.indigo,
                          onPressed: () {},
                        ),
                        AppleSwipeAction(
                          label: _ru.delete,
                          icon: Icons.delete,
                          color: Colors.red,
                          onPressed: () {},
                        ),
                      ],
                      child: const ListTile(
                        title: Text('Александра Константинопольская'),
                        subtitle: Text('Последнее сообщение очень длинное'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          scale,
        ),
      );
      await t.drag(find.byType(ListTile), const Offset(-260, 0));
      await t.pumpAndSettle();
      _noOverflow(t, 'смахивание');

      ScaffoldMessenger.of(ctx).showSnackBar(
        SecretlySnackBar(
          content: Text(_ru.attachmentActionGeneric),
          action: SnackBarAction(label: _ru.uploadRetry, onPressed: () {}),
        ),
      );
      await t.pump();
      await t.pumpAndSettle();
      _noOverflow(t, 'капсула');

      unawaitedDialog(ctx);
      await t.pumpAndSettle();
      _noOverflow(t, 'окно');
      expect(find.text(_ru.blockUserConfirmTitle), findsOneWidget);
      await t.tap(find.text(_ru.cancel));
      await t.pumpAndSettle(const Duration(seconds: 3));
      debugDefaultTargetPlatformOverride = null;
    });
  }
}

void unawaitedDialog(BuildContext context) {
  showDialog<bool>(
    context: context,
    builder: (context) => SecretlyAlertDialog(
      title: Text(_ru.blockUserConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ABCD-EFGH-JKLM-NPQR'),
          CheckboxListTile(
            value: true,
            onChanged: (_) {},
            title: Text(_ru.alsoDeleteChat),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_ru.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(_ru.block),
        ),
      ],
    ),
  );
}
