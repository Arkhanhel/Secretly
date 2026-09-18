// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// REGRESSION (2026-07-20): the redesigned backup screen shipped its strings
/// through a ru/en-only helper, so speakers of the other six supported locales
/// would have seen English. The gap was invisible — nothing failed, the text
/// just silently fell back.
///
/// This pins the contract instead: every locale carries exactly the same keys
/// as the English template, and none of them is left empty.
void main() {
  final arbDir = Directory('lib/l10n');

  Map<String, dynamic> loadArb(String locale) {
    final file = File('${arbDir.path}/app_$locale.arb');
    expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Translatable keys only — `@`-prefixed entries are metadata and live in
  /// the template alone.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  late Set<String> templateKeys;

  setUpAll(() {
    templateKeys = messageKeys(loadArb('en'));
  });

  test('the template itself is non-empty', () {
    expect(templateKeys, isNotEmpty);
  });

  for (final locale in const ['de', 'es', 'fr', 'pt', 'pt_BR', 'ru', 'uk']) {
    group('locale $locale', () {
      test('carries every key the English template has', () {
        final keys = messageKeys(loadArb(locale));
        expect(
          templateKeys.difference(keys),
          isEmpty,
          reason: 'app_$locale.arb is missing keys present in app_en.arb',
        );
        expect(
          keys.difference(templateKeys),
          isEmpty,
          reason: 'app_$locale.arb has keys that app_en.arb does not',
        );
      });

      test('has no empty translations', () {
        final arb = loadArb(locale);
        final blank = <String>[
          for (final key in messageKeys(arb))
            if ((arb[key] as String?)?.trim().isEmpty ?? true) key,
        ];
        expect(blank, isEmpty, reason: 'blank strings in app_$locale.arb');
      });
    });
  }
}
