// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations_de.dart';
import 'package:secretly_app/l10n/app_localizations_en.dart';
import 'package:secretly_app/l10n/app_localizations_es.dart';
import 'package:secretly_app/l10n/app_localizations_fr.dart';
import 'package:secretly_app/l10n/app_localizations_pt.dart';
import 'package:secretly_app/l10n/app_localizations_ru.dart';
import 'package:secretly_app/l10n/app_localizations_uk.dart';

// SEC-06 (25.08.2026, исправлено 26.08).
//
// Настройка обещала буквально: «писать только тем, чьи ключи вы сверили лично»,
// без оговорок. На деле привратник `_sendGateBlockingDevices` вызывается только
// на путях личной переписки — в группах его нет вовсе.
//
// Поведение групп решено НЕ менять: блокировать сообщение всей группе из-за
// одного непроверенного участника — фактический запрет писать. Значит правдой
// должен стать текст.
//
// 🔴 Расхождение обещания и поведения — это находка аудита сама по себе, даже
// когда поведение разумно. Человек, включивший режим ради группы, получает не
// то, что прочитал. Тест держит оговорку на месте во ВСЕХ языках: перевести
// строку заново и потерять её — ровно тот способ, каким такие правки пропадают.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Слово «группы» в каждом языке. Проверяется корень, а не фраза целиком:
  // формулировку менять можно, умалчивать про группы — нельзя.
  const marker = <String, String>{
    'ru': 'групп',
    'uk': 'груп',
    'en': 'group',
    'de': 'Gruppen',
    'es': 'grupos',
    'fr': 'groupes',
    'pt': 'grupos',
    'pt_BR': 'grupos',
  };

  final shipped = <String, String>{
    'ru': AppLocalizationsRu().blockUnverifiedSubtitle,
    'uk': AppLocalizationsUk().blockUnverifiedSubtitle,
    'en': AppLocalizationsEn().blockUnverifiedSubtitle,
    'de': AppLocalizationsDe().blockUnverifiedSubtitle,
    'es': AppLocalizationsEs().blockUnverifiedSubtitle,
    'fr': AppLocalizationsFr().blockUnverifiedSubtitle,
    'pt': AppLocalizationsPt().blockUnverifiedSubtitle,
    'pt_BR': AppLocalizationsPtBr().blockUnverifiedSubtitle,
  };

  test('🔴 обещание строгого режима нигде не умалчивает про группы', () {
    for (final entry in shipped.entries) {
      expect(
        entry.value,
        contains(marker[entry.key]),
        reason:
            'язык ${entry.key}: настройка обещает больше, чем делает — '
            'привратник в группах не работает, и текст обязан это сказать',
      );
    }
  });

  test('🔴 переводы и поставляемый текст не разошлись', () {
    // Строка живёт в двух местах: `.arb` — источник перевода, `.dart` —
    // то, что реально видит человек. Расхождение означает, что перевод
    // поправили, а до приложения оно не доехало.
    for (final entry in shipped.entries) {
      final arb =
          jsonDecode(
                File('lib/l10n/app_${entry.key}.arb').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        arb['blockUnverifiedSubtitle'],
        entry.value,
        reason: 'язык ${entry.key}: .arb и сгенерированный .dart разошлись',
      );
    }
  });
}
