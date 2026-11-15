// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// К4 (14.11.2026): причина отказа в выдаче копии — словами, а не «копии нет».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/backup_refusal_text.dart';

void main() {
  Future<String> render(
    WidgetTester tester,
    ({String? reason, int? retryAtMs}) refusal,
    Locale locale,
  ) async {
    late String out;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            out = serverBackupRefusalText(
              context,
              AppLocalizations.of(context)!,
              refusal,
              fallback: 'FALLBACK',
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return out;
  }

  testWidgets('wrong password, locked with time, unknown reason', (t) async {
    const ru = Locale('ru');
    expect(
      await render(t, (reason: 'wrong_password', retryAtMs: null), ru),
      contains('Пароль не подходит или'),
    );
    final at = DateTime.now().add(const Duration(minutes: 30));
    final locked = await render(
      t,
      (reason: 'locked', retryAtMs: at.millisecondsSinceEpoch),
      ru,
    );
    expect(locked, contains('Слишком много'));
    expect(locked, contains(at.minute.toString().padLeft(2, '0')));
    expect(await render(t, (reason: null, retryAtMs: null), ru), 'FALLBACK');
    expect(await render(t, (reason: 'new_thing', retryAtMs: null), ru), 'FALLBACK');
  });

  testWidgets('every locale has its own text', (t) async {
    final en = await render(t, (reason: 'wrong_password', retryAtMs: null), const Locale('en'));
    for (final l in AppLocalizations.supportedLocales) {
      if (l.languageCode == 'en') continue;
      final s = await render(t, (reason: 'wrong_password', retryAtMs: null), l);
      expect(s, isNot(en), reason: l.toString());
    }
  });
}
