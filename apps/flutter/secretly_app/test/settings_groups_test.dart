// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Переделка настроек (11.2026): заголовки групп, пояснения и страница
// «Как это работает» в разделе «Сеть».
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/network_settings_screen.dart';
import 'package:secretly_app/ui/settings_group.dart';

Widget _host(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

void main() {
  testWidgets('group header is upper-case and marked as a header', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const Locale('ru'),
        const Scaffold(
          body: Column(
            children: [
              SettingsGroupHeader('Профиль'),
              SettingsGroupCaption('Пояснение'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('ПРОФИЛЬ'), findsOneWidget);
    expect(find.text('Пояснение'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('ПРОФИЛЬ')),
      matchesSemantics(label: 'ПРОФИЛЬ', isHeader: true),
    );
    handle.dispose();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('how-it-works page shows six steps ($locale)', (tester) async {
      await tester.pumpWidget(_host(locale, const NetworkHowItWorksScreen()));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(NetworkHowItWorksScreen)),
      )!;
      expect(find.text(l10n.netHowItWorksTitle), findsOneWidget);
      final titles = [
        l10n.netHowStep1Title,
        l10n.netHowStep2Title,
        l10n.netHowStep3Title,
        l10n.netHowStep4Title,
        l10n.netHowStep5Title,
        l10n.netHowStep6Title,
      ];
      for (final t in titles) {
        await tester.scrollUntilVisible(find.text(t), 200);
        expect(find.text(t), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('no group label falls back to English outside en', () {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final l = lookupAppLocalizations(locale);
      final en = lookupAppLocalizations(const Locale('en'));
      // «Secretly ID» одинаков во всех языках — его не сравниваем.
      final pairs = <String, String>{
        l.settingsGroupProfile: en.settingsGroupProfile,
        l.settingsCaptionLeave: en.settingsCaptionLeave,
        l.settingsCaptionBlocked: en.settingsCaptionBlocked,
        l.settingsCaptionOffline: en.settingsCaptionOffline,
        l.netHowStep4Body: en.netHowStep4Body,
      };
      pairs.forEach((value, english) {
        expect(value, isNot(english), reason: '$locale: $value');
      });
    }
  });

  testWidgets('«?» opens the explanation sheet and «Got it» closes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Locale('ru'),
        const Scaffold(
          body: SettingsGroupHeader(
            'Восстановление',
            help: SettingsHelp(
              title: 'Восстановление',
              text: 'Пояснение к группе',
              tip: 'Короткий совет',
            ),
          ),
        ),
      ),
    );
    expect(find.text('ВОССТАНОВЛЕНИЕ'), findsOneWidget);
    expect(find.text('Пояснение к группе'), findsNothing);
    await tester.tap(find.text('?'));
    await tester.pumpAndSettle();
    expect(find.text('Пояснение к группе'), findsOneWidget);
    expect(find.textContaining('Короткий совет'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Пояснение к группе'), findsNothing);
  });

  testWidgets('steps and status cards render their text', (tester) async {
    await tester.pumpWidget(
      _host(
        const Locale('en'),
        const Scaffold(
          body: Column(
            children: [
              SettingsStatusCard(title: 'Direct', subtitle: 'Path'),
              SettingsStepsCard(steps: [('One', 'a'), ('Two', 'b')]),
            ],
          ),
        ),
      ),
    );
    for (final t in ['Direct', 'Path', '1', '2', 'One', 'Two', 'a', 'b']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  test('offline step 3 names the real section and button in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      expect(l.offlineStep3Body, contains(l.settingsGroupOffline));
      expect(l.offlineStep3Body, contains(l.netSettingsOpenMessageFileTitle));
      // Подсказка «не удалось прочитать файл» ведёт в новый раздел.
      expect(l.netSettingsImportCouldNotRead, contains(l.settingsGroupOffline));
    }
  });

  test('new hub and intro texts are translated outside en', () {
    final en = lookupAppLocalizations(const Locale('en'));
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final l = lookupAppLocalizations(locale);
      final pairs = <String, String>{
        l.settingsHubAccountGroup: en.settingsHubAccountGroup,
        l.settingsHubOfflineSub: en.settingsHubOfflineSub,
        l.settingsIntroNetwork: en.settingsIntroNetwork,
        l.settingsIntroOffline: en.settingsIntroOffline,
        l.offlineStep2Body: en.offlineStep2Body,
        l.settingsHelpGotIt: en.settingsHelpGotIt,
      };
      pairs.forEach((value, english) {
        expect(value, isNot(english), reason: '$locale: $value');
      });
    }
  });
}
