// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';

// Паритет настроек компьютера с телефоном (17.09.2026, реестр отставания):
//   • a4e3cf2e — «Скрывать мой адрес в звонках» (SEC-10③);
//   • a00ae2a7 — подсказка пересохранить копию без опоры токена (SEC-01).
// Подписи — через общие переводы: храповик захардкоженных строк не растёт.

const _locales = ['ru', 'en', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de'];

void main() {
  final src = File(
    'lib/ui/desktop/workspace/settings_workspace.dart',
  ).readAsStringSync();

  test('🔴 переключатель адреса в звонках привязан к общей настройке', () {
    expect(src.contains('AppLocalizations.of(context)!.callsHideAddressTitle'), isTrue);
    expect(src.contains('value: ctrl.hideAddressInCalls,'), isTrue);
    expect(
      src.contains('onChanged: (v) => unawaited(ctrl.setHideAddressInCalls(v)),'),
      isTrue,
    );
  });

  test('🔴 подсказка SEC-01 показывается по тому же признаку, что на телефоне', () {
    expect(
      src.contains('widget.controller?.serverBackupNeedsAccessUpgrade ?? false'),
      isTrue,
    );
    expect(src.contains('.backupAccessUpgradeTitle'), isTrue);
    expect(src.contains('.backupAccessUpgradeAction'), isTrue);
  });

  test('новые подписи есть во всех языках и не пустые', () {
    for (final loc in _locales) {
      final arb = jsonDecode(
        File('lib/l10n/app_$loc.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in ['callsHideAddressTitle', 'callsHideAddressSubtitle']) {
        expect((arb[key] as String?)?.trim(), isNotEmpty, reason: '$loc/$key');
      }
    }
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(ru.callsHideAddressTitle, 'Скрывать мой адрес в звонках');
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.callsHideAddressTitle, 'Hide my address in calls');
  });
}
