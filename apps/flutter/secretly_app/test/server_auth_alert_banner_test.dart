// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/transport/response_signature.dart';
import 'package:secretly_app/ui/server_auth_alert_banner.dart';

// Б3 Э2 (25.10.2026): баннер «ответ сервера не прошёл проверку».

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Column(children: [child])),
    );

void main() {
  setUp(() => ServerAuthEnforcement.resetForTesting());
  tearDown(() => ServerAuthEnforcement.resetForTesting());

  testWidgets('без отказа баннера нет — так у всех при доле 0', (tester) async {
    await tester.pumpWidget(_app(const ServerAuthAlertBanner()));
    expect(find.byType(Material), findsOneWidget, reason: 'только Scaffold');
    expect(find.text('Server response failed verification'), findsNothing);
  });

  testWidgets('отказ показывает баннер, «Понятно» прячет его', (tester) async {
    await tester.pumpWidget(_app(const ServerAuthAlertBanner()));
    ServerAuthEnforcement.lastRejection.value =
        const ServerUnauthenticatedException(
      route: 'keys.bundle',
      outcome: ResponseAuthOutcome.bad,
    );
    await tester.pump();
    expect(find.text('Server response failed verification'), findsOneWidget);
    expect(find.textContaining('existing chats stay protected'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(find.text('Server response failed verification'), findsNothing);
    expect(ServerAuthEnforcement.lastRejection.value, isNull);
  });

  testWidgets('переведён на все языки приложения', (tester) async {
    ServerAuthEnforcement.lastRejection.value =
        const ServerUnauthenticatedException(
      route: 'device.lookup',
      outcome: ResponseAuthOutcome.missing,
    );
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
          _app(const ServerAuthAlertBanner(compact: true), locale: locale));
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(find.text(l10n.serverAuthAlertTitle), findsOneWidget,
          reason: locale.toString());
      if (locale.languageCode != 'en') {
        expect(l10n.serverAuthAlertTitle,
            isNot('Server response failed verification'),
            reason: '$locale не должен падать на английский');
      }
    }
  });
}
