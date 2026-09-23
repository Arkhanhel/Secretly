// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Требования к паролю набора восстановления — на языке ОКНА.
//
// 🔴 ЧТО ЭТО ЗА ДЕФЕКТ (найден 23.09.2026). `BackupPasswordPolicy` знает два
// языка и выбирает их логическим `isRu`, а окно настроек передавало `true`
// ВСЕГДА. Немец, испанец и бразилец читали требования к паролю по-русски —
// причём ровно в тот момент, когда пароль не приняли и человек и так озадачен.
//
// Общий файл политики не трогаем: он делит код с выпущенной мобильной
// версией. Перевод живёт в окне и берётся из тех же переводов, что и всё
// остальное.

import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/security/backup_password_policy.dart';
import 'package:secretly_app/ui/desktop/app/recovery_kit_export.dart';

const _locales = ['ru', 'en', 'uk', 'de', 'es', 'fr', 'pt', 'pt_BR'];

AppLocalizations _l(String tag) {
  final parts = tag.split('_');
  return lookupAppLocalizations(
    parts.length == 1 ? Locale(parts[0]) : Locale(parts[0], parts[1]),
  );
}

/// Кириллица в строке — признак русского текста там, где его быть не должно.
bool _hasCyrillic(String s) => RegExp(r'[Ѐ-ӿ]').hasMatch(s);

void main() {
  test('🔴 требования к паролю переведены на все восемь языков', () {
    final seen = <String>{};
    for (final tag in _locales) {
      final text = desktopPasswordRequirements(_l(tag));
      expect(text.trim(), isNotEmpty, reason: tag);
      if (tag != 'ru' && tag != 'uk') {
        expect(_hasCyrillic(text), isFalse,
            reason: '$tag: требования показаны кириллицей — это и был дефект');
      }
      seen.add(text);
    }
    // pt и pt_BR у этой строки совпадают намеренно, остальные различаются.
    expect(seen.length, greaterThanOrEqualTo(_locales.length - 1));
  });

  test('🔴 каждая причина отказа переведена, и ни одна не пустая', () {
    for (final tag in _locales) {
      final l10n = _l(tag);
      for (final p in BackupPasswordProblem.values) {
        final text = desktopPasswordProblems(
          l10n,
          BackupPasswordValidation(<BackupPasswordProblem>[p]),
        );
        expect(text.trim(), isNotEmpty, reason: '$tag/$p');
        if (tag != 'ru' && tag != 'uk') {
          expect(_hasCyrillic(text), isFalse, reason: '$tag/$p');
        }
      }
    }
  });

  test('длины подставляются числом, а не остаются заготовкой', () {
    final text = desktopPasswordProblems(
      _l('en'),
      BackupPasswordValidation(
        <BackupPasswordProblem>[BackupPasswordProblem.tooShort],
      ),
    );
    expect(text.contains('${BackupPasswordPolicy.minLength}'), isTrue);
    expect(text.contains('{count}'), isFalse);
  });

  test('🔴 окно больше не передаёт «isRu» жёстко', () {
    // Сторож против возврата: `isRu: true` в десктопном коде означает, что
    // перевод снова выбирается не по языку окна.
    for (final f in const [
      'lib/ui/desktop/workspace/settings_workspace.dart',
      'lib/ui/desktop/app/recovery_kit_export.dart',
    ]) {
      final code = File(f)
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('isRu: true'), isFalse, reason: f);
    }
  });

  test('🔴 путь «сделать набор» ОДИН на настройки и на создание аккаунта', () {
    // Это тот самый ключ, которым человек однажды будет возвращать себе
    // аккаунт: две копии разошлись бы текстами и проверками.
    final settings = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();
    expect(settings.contains('runRecoveryKitExport('), isTrue);
    expect(settings.contains('createRecoveryKitPayload('), isFalse,
        reason: 'настройки обязаны звать общий путь, а не делать ключ сами');
  });
}
