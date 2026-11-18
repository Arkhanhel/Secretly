// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Новый стиль первого запуска и окна «Новый вход» (макет «Secretly Kit»,
// 17.11.2026). Проверяем не пиксели, а то, что за ними: шаги идут в том же
// порядке, сохраняется то же самое, кнопки гаснут там, где шаг не заполнен,
// а у читалки экрана есть заголовки и подписи.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/l10n/app_localizations_ru.dart';
import 'package:secretly_app/ui/devices_auth_screen.dart';
import 'package:secretly_app/ui/onboarding_flow.dart';
import 'package:secretly_app/ui/welcome/particle_logo_background.dart';
import 'package:secretly_app/ui/welcome/welcome_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOnboardingController extends AppController {
  String nickname = '';
  bool serverProfile = true;
  bool autoEnabled = false;
  bool autoServer = true;
  int interval = 24 * 60;
  String? savedPassword;
  final List<String> calls = [];

  @override
  String get myNickname => nickname;

  @override
  Future<void> setMyNickname(String v) async {
    calls.add('nick:$v');
    nickname = v;
  }

  @override
  bool get hasServerProfile => serverProfile;

  @override
  String get profileId => serverProfile ? 'ABCD-EFGH-JKLM-NPQR' : 'unknown';

  @override
  bool get safeBackupAutoEnabled => autoEnabled;

  @override
  bool get safeBackupAutoServerEnabled => autoServer;

  @override
  int get safeBackupAutoIntervalMin => interval;

  @override
  Future<void> setSafeBackupAutoEnabled(bool value) async {
    calls.add('enabled:$value');
    autoEnabled = value;
  }

  @override
  Future<void> setSafeBackupAutoServerEnabled(bool value) async {
    calls.add('server:$value');
    autoServer = value;
  }

  @override
  Future<void> setSafeBackupAutoIntervalMinutes(int minutes) async {
    calls.add('interval:$minutes');
    interval = minutes;
  }

  @override
  Future<void> setSafeBackupAutoPassword(String password) async {
    calls.add('password');
    savedPassword = password;
  }

  @override
  Future<bool> hasSafeBackupAutoPassword() async => savedPassword != null;
}

final _ru = AppLocalizationsRu();

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.dark,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    theme: ThemeData(brightness: brightness, platform: platform),
    // Фон из частиц тикает без конца — в тестах он стоит на одном кадре,
    // как у человека с выключенными анимациями.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: child,
  );
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).last);
  await t.tap(find.text(text).last);
  await _settle(t);
}

/// Кнопка нового стиля с этой подписью нажимаема?
bool _enabled(WidgetTester t, String label) {
  final button = t.widget<WelcomePrimaryButton>(
    find.widgetWithText(WelcomePrimaryButton, label).last,
  );
  return button.onPressed != null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('создание аккаунта: все шаги по порядку, сохраняется то же', (
    t,
  ) async {
    phone(t);
    final c = _FakeOnboardingController();
    var completed = false;
    await t.pumpWidget(
      _host(OnboardingFlow(controller: c, onComplete: () => completed = true)),
    );
    await _settle(t);

    // Приветствие.
    expect(find.text('Secretly'), findsOneWidget);
    expect(find.text(_ru.welcomeTagline), findsOneWidget);
    expect(find.text(_ru.welcomeHaveAccount), findsOneWidget);
    await _tapText(t, _ru.welcomeCreateAccount);

    // Имя.
    expect(find.text(_ru.welcomeNameTitle), findsOneWidget);
    expect(find.byTooltip(_ru.onboardingBackTooltip), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Алекс');
    await t.pump();
    expect(find.text('А'), findsOneWidget, reason: 'буква в круге');
    await t.tap(find.text(_ru.continueAction));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(c.calls, contains('nick:Алекс'));

    // Ключи: три фразы и «готово», потом сам переходит дальше.
    expect(find.text(_ru.welcomeKeysStepIdentity), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    expect(find.text(_ru.welcomeKeysReady), findsOneWidget);
    expect(find.text('ABCD-EFGH-JKLM-NPQR'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await _settle(t);

    // Резервная копия: кнопка гаснет, пока пароль не по правилам.
    expect(find.text(_ru.welcomeBackupTitle), findsOneWidget);
    expect(_enabled(t, _ru.welcomeBackupEnable), isFalse);
    await t.enterText(find.byType(TextField).first, 'secret');
    await t.pump();
    expect(_enabled(t, _ru.welcomeBackupEnable), isFalse);
    await t.enterText(find.byType(TextField).first, 'Secret!pass');
    await _settle(t);
    expect(find.text(_ru.welcomePasswordStrong), findsOneWidget);
    await t.enterText(find.byType(TextField).at(1), 'Secret!pas');
    await t.pump();
    expect(_enabled(t, _ru.welcomeBackupEnable), isFalse);
    await t.enterText(find.byType(TextField).at(1), 'Secret!pass');
    await t.pump();
    expect(_enabled(t, _ru.welcomeBackupEnable), isTrue);

    // «На устройстве» — копия не на сервере, как прежний выбор «Локально».
    await _tapText(t, _ru.welcomeBackupOnDevice);
    expect(find.text(_ru.welcomeBackupBodyDevice), findsOneWidget);
    await _tapText(t, _ru.welcomeBackupEnable);
    expect(c.calls, containsAllInOrder(['enabled:true', 'server:false']));
    expect(c.savedPassword, 'Secret!pass');
    expect(find.text(_ru.welcomeBackupOnTitle), findsOneWidget);
    expect(
      find.text(_ru.welcomeBackupOnBody(_ru.onboardingIntervalEveryDay)),
      findsOneWidget,
    );
    await _tapText(t, _ru.continueAction);

    // Уведомления (Android) — «Не сейчас» разрешения не спрашивает.
    expect(find.text(_ru.welcomeNotifyTitle), findsOneWidget);
    await _tapText(t, _ru.welcomeNotifyNotNow);

    // Готово.
    expect(find.text(_ru.welcomeDoneTitle('Алекс')), findsOneWidget);
    expect(find.text('ABCD-EFGH-JKLM-NPQR'), findsOneWidget);
    await _tapText(t, _ru.welcomeOpenApp);
    expect(completed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isNotEmpty, reason: 'вход отмечен пройденным');
  });

  testWidgets('«Настроить позже» не включает копию и не спрашивает пароль', (
    t,
  ) async {
    phone(t);
    final c = _FakeOnboardingController()..nickname = 'Ия';
    await t.pumpWidget(_host(OnboardingFlow(controller: c, onComplete: () {})));
    await _settle(t);
    await _tapText(t, _ru.welcomeCreateAccount);
    await _tapText(t, _ru.continueAction);
    await t.pump(const Duration(seconds: 6));
    await _settle(t);
    await _tapText(t, _ru.welcomeBackupLater);
    expect(c.calls.where((x) => x.startsWith('enabled:true')), isEmpty);
    expect(c.savedPassword, isNull);
    expect(find.text(_ru.welcomeNotifyTitle), findsOneWidget);
  });

  testWidgets('без профиля копия откладывается, но вход не держит', (t) async {
    phone(t);
    final c = _FakeOnboardingController()..serverProfile = false;
    await t.pumpWidget(_host(OnboardingFlow(controller: c, onComplete: () {})));
    await _settle(t);
    await _tapText(t, _ru.welcomeCreateAccount);
    await _tapText(t, _ru.continueAction);
    // Ждёт профиль не дольше десяти секунд.
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    await _settle(t);
    expect(find.text(_ru.welcomeBackupTitle), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Secret!pass');
    await _settle(t);
    await t.enterText(find.byType(TextField).at(1), 'Secret!pass');
    await t.pump();
    await _tapText(t, _ru.welcomeBackupEnable);
    expect(c.calls, contains('enabled:false'));
    expect(c.savedPassword, isNull);
    expect(find.text(_ru.welcomeNotifyTitle), findsOneWidget);
  });

  testWidgets('назад с шага «Имя» и системной кнопкой', (t) async {
    phone(t);
    final c = _FakeOnboardingController();
    await t.pumpWidget(_host(OnboardingFlow(controller: c, onComplete: () {})));
    await _settle(t);
    await _tapText(t, _ru.welcomeCreateAccount);
    expect(find.text(_ru.welcomeNameTitle), findsOneWidget);
    await t.tap(find.byTooltip(_ru.onboardingBackTooltip));
    await _settle(t);
    expect(find.text(_ru.welcomeCreateAccount), findsOneWidget);
    await _tapText(t, _ru.welcomeCreateAccount);
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await _settle(t);
    expect(find.text(_ru.welcomeCreateAccount), findsOneWidget);
  });

  testWidgets('восстановление: облако и файл, кнопка ждёт заполнения', (
    t,
  ) async {
    phone(t);
    final c = _FakeOnboardingController();
    await t.pumpWidget(_host(OnboardingFlow(controller: c, onComplete: () {})));
    await _settle(t);
    await _tapText(t, _ru.welcomeHaveAccount);
    expect(find.text(_ru.welcomeRestoreTitle), findsOneWidget);
    expect(find.text(_ru.welcomeRestoreCloudTitle), findsOneWidget);
    expect(find.text(_ru.welcomeRestoreFileTitle), findsOneWidget);
    // Под восстановлением шаги входа не рисуются — только общий фон.
    expect(find.text(_ru.welcomeCreateAccount), findsNothing);
    expect(find.byType(ParticleLogoBackground), findsOneWidget);

    await _tapText(t, _ru.welcomeRestoreCloudTitle);
    expect(find.text(_ru.welcomeRestoreCloudFormBody), findsOneWidget);
    expect(_enabled(t, _ru.restore), isFalse);
    await t.enterText(find.byType(TextField).first, 'ABCD-EFGH');
    await t.pump();
    expect(_enabled(t, _ru.restore), isFalse);
    await t.enterText(find.byType(TextField).at(1), 'pw');
    await t.pump();
    expect(_enabled(t, _ru.restore), isTrue);

    await t.tap(find.byTooltip(_ru.onboardingBackTooltip));
    await _settle(t);
    await _tapText(t, _ru.welcomeRestoreFileTitle);
    expect(find.text(_ru.welcomeRestoreFilePick), findsOneWidget);
    expect(_enabled(t, _ru.restore), isFalse);

    await t.tap(find.byTooltip(_ru.onboardingBackTooltip));
    await _settle(t);
    await t.tap(find.byTooltip(_ru.onboardingBackTooltip));
    await _settle(t);
    expect(find.text(_ru.welcomeCreateAccount), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('рисуется без ошибок: ${brightness.name}, ${platform.name}', (
        t,
      ) async {
        phone(t);
        final c = _FakeOnboardingController();
        await t.pumpWidget(
          _host(
            OnboardingFlow(controller: c, onComplete: () {}),
            brightness: brightness,
            platform: platform,
          ),
        );
        await _settle(t);
        await _tapText(t, _ru.welcomeCreateAccount);
        await _tapText(t, _ru.continueAction);
        await t.pump(const Duration(seconds: 6));
        await _settle(t);
        expect(find.text(_ru.welcomeBackupTitle), findsOneWidget);
        expect(t.takeException(), isNull);
        final s = WelcomeStyle.resolve(
          brightness: brightness,
          platform: platform,
        );
        expect(s.dark, brightness == Brightness.dark);
        expect(s.material, platform == TargetPlatform.android);
      });
    }
  }

  testWidgets('читалка: заголовки шагов и подписи кнопок', (t) async {
    phone(t);
    final handle = t.ensureSemantics();
    final c = _FakeOnboardingController();
    await t.pumpWidget(_host(OnboardingFlow(controller: c, onComplete: () {})));
    await _settle(t);
    expect(
      t.getSemantics(find.text('Secretly')),
      matchesSemantics(label: 'Secretly', isHeader: true),
    );
    expect(
      find.bySemanticsLabel(_ru.welcomeCreateAccount),
      findsOneWidget,
    );
    final node = t.getSemantics(
      find.bySemanticsLabel(_ru.welcomeCreateAccount),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await _tapText(t, _ru.welcomeCreateAccount);
    expect(
      t.getSemantics(find.text(_ru.welcomeNameTitle)),
      matchesSemantics(label: _ru.welcomeNameTitle, isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('окно «Новый вход»: разрешить, отклонить, закрыть', (t) async {
    phone(t);
    NewLoginDecision? result;
    var closed = false;
    Future<void> open() async {
      await t.tap(find.text('open'));
      await _settle(t);
    }

    await t.pumpWidget(
      _host(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                closed = false;
                result = await showNewLoginSheet(
                  context,
                  deviceLabel: 'MacBook · Secretly Desktop',
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
        platform: TargetPlatform.iOS,
      ),
    );

    await open();
    expect(find.text(_ru.welcomeNewLoginTitle), findsOneWidget);
    expect(find.text('MacBook · Secretly Desktop'), findsOneWidget);
    expect(find.text(_ru.devicesSyncChats), findsOneWidget);
    // Медиа выключены по умолчанию, как и было.
    await _tapText(t, _ru.welcomeNewLoginApprove);
    expect(closed, isTrue);
    expect(result!.isApproved, isTrue);
    expect(result!.syncChats, isTrue);
    expect(result!.syncSettings, isTrue);
    expect(result!.syncMedia, isFalse);

    await open();
    // Нечего переносить — разрешать нельзя.
    await t.tap(find.text(_ru.devicesSyncChats));
    await _settle(t);
    await t.tap(find.text(_ru.devicesSyncSettings));
    await _settle(t);
    expect(_enabled(t, _ru.welcomeNewLoginApprove), isFalse);
    await _tapText(t, _ru.welcomeNewLoginDecline);
    expect(result!.isApproved, isFalse);

    await open();
    await t.tapAt(const Offset(195, 30));
    await _settle(t);
    expect(closed, isTrue);
    expect(result, isNull, reason: 'закрыть = ничего не делать');
  });

  testWidgets('окно «Новый вход» без имени устройства', (t) async {
    phone(t);
    await t.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showNewLoginSheet(context, deviceLabel: '  '),
            child: const Text('open'),
          ),
        ),
        brightness: Brightness.light,
      ),
    );
    await t.tap(find.text('open'));
    await _settle(t);
    expect(find.text(_ru.welcomeNewLoginUnknownDevice), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('точки знака на месте и в ожидаемом формате', () {
    final bytes = File(kWelcomeLogoFieldAsset).readAsBytesSync();
    expect(bytes.length % 6, 0);
    final v = Int16List.sublistView(bytes);
    expect(v.length ~/ 3, greaterThanOrEqualTo(2600));
    for (var i = 0; i < v.length; i += 3) {
      expect(v[i].abs(), lessThan(20000));
      expect(v[i + 1].abs(), lessThan(20000));
      expect(v[i + 2], greaterThanOrEqualTo(0));
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/welcome/'));
  });

  test('🔴 новые подписи есть во всех восьми языках', () {
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    final keys = RegExp(r'"(welcome[A-Za-z]+)":')
        .allMatches(en)
        .map((m) => m.group(1)!)
        .toSet();
    expect(keys.length, greaterThan(60));
    for (final loc in ['ru', 'uk', 'de', 'es', 'fr', 'pt', 'pt_BR']) {
      final arb = File('lib/l10n/app_$loc.arb').readAsStringSync();
      for (final k in keys) {
        expect(arb.contains('"$k":'), isTrue, reason: '$loc: $k');
      }
    }
  });

  test('в новых экранах нет строк мимо перевода', () {
    for (final path in [
      'lib/ui/welcome/welcome_style.dart',
      'lib/ui/welcome/welcome_hero.dart',
      'lib/ui/welcome/particle_logo_background.dart',
      'lib/ui/desktop/onboarding/desktop_auth_gate.dart',
      'lib/ui/desktop/onboarding/desktop_auth_scaffold.dart',
      'lib/ui/desktop/onboarding/desktop_create_account_flow.dart',
      'lib/ui/desktop/onboarding/desktop_recovery_kit_gate.dart',
      'lib/ui/desktop/onboarding/desktop_restore_flow.dart',
    ]) {
      final code = File(path)
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        // Знак «?» и название «Secretly» не переводятся.
        RegExp(r"Text\(\s*'(?!\?'|Secretly')").hasMatch(code),
        isFalse,
        reason: '$path: подпись строкой в коде',
      );
    }
  });
}
