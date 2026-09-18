// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Settings → Power must not be English-only in six of the eight locales.
///
/// REGRESSION CLASS (see also `l10n_parity_test.dart`, 2026-07-20): settings
/// screens carry their text through `settingsScreenLabel(context, ru:, en:)`,
/// which returns Russian or English directly and looks EVERY other language up
/// in `_settingsTranslations` **keyed by the exact English string**. Miss the
/// key and the helper silently returns English. Nothing throws, nothing warns —
/// a German speaker simply reads English and nobody finds out.
///
/// The lookup being an exact string match is what makes this worth a test
/// rather than a review: the source writes these strings as ADJACENT LITERALS
/// that Dart joins at compile time, so a stray space or a reflowed line changes
/// the runtime key while the code still looks correct.
void main() {
  final ui = Directory('lib/ui');

  String read(String name) {
    final f = File('${ui.path}/$name');
    expect(f.existsSync(), isTrue, reason: 'missing ${f.path}');
    return f.readAsStringSync();
  }

  // A Dart string literal, either quote style. Built from two raw strings
  // because a raw string cannot END with the quote that delimits it.
  const dq = r'"((?:[^"\\]|\\.)*)"';
  const sq = r"'((?:[^'\\]|\\.)*)'";
  final literal = '$dq|$sq';

  /// Joins Dart adjacent string literals — `'a ' 'b'` — into `a b`, matching
  /// exactly what the compiler produces and therefore what the map is keyed by.
  String joinLiterals(String raw) {
    final buf = StringBuffer();
    for (final m in RegExp(literal).allMatches(raw)) {
      buf.write((m.group(1) ?? m.group(2) ?? '').replaceAll(r'\"', '"'));
    }
    return buf.toString();
  }

  /// Every English string the Power screen and its menu entry hand to the
  /// ru/en helper.
  List<String> powerScreenEnglish() {
    final src = read('settings_screen.dart');
    final start = src.indexOf('/// Power / heat settings.');
    expect(start, isNot(-1), reason: 'the Power screen moved or was renamed');
    final end = src.indexOf('class _StorageSettingsScreen', start);
    expect(end, isNot(-1));

    // The screen body, plus the menu tile that opens it (which lives earlier in
    // the file and carries the section title and subtitle).
    final menuStart = src.indexOf('icon: Icons.bolt_rounded');
    expect(menuStart, isNot(-1), reason: 'the Power menu tile moved');
    final regions = <String>[
      src.substring(menuStart, src.indexOf('onTap:', menuStart)),
      src.substring(start, end),
    ];

    final out = <String>[];
    final re = RegExp('en:\\s*((?:(?:$literal)\\s*)+)');
    for (final region in regions) {
      for (final m in re.allMatches(region)) {
        final value = joinLiterals(m.group(1)!).trim();
        if (value.isNotEmpty) out.add(value);
      }
    }
    return out;
  }

  /// The keys present in one locale's map inside `settings_screen_l10n.dart`.
  Set<String> keysForLocale(String locale) {
    final src = read('settings_screen_l10n.dart');
    final start = src.indexOf('  _SettingsLocale.$locale: {');
    expect(start, isNot(-1), reason: 'no map for locale $locale');
    // The map ends at the next locale entry, or at the closing brace.
    final next = RegExp(r'\n  _SettingsLocale\.\w+: \{').firstMatch(
      src.substring(start + 10),
    );
    final end = next == null ? src.length : start + 10 + next.start;
    final body = src.substring(start, end);

    final keys = <String>{};
    final re = RegExp('^\\s*($literal):', multiLine: true);
    for (final m in re.allMatches(body)) {
      keys.add(joinLiterals(m.group(0)!.trim()));
    }
    return keys;
  }

  test('🔴 the screen ROUTES through the shared lookup, not a local shortcut',
      () {
    // The gap that made the previous version of this file useless. It proved
    // the dictionary CONTAINED every string, and the screen went on showing
    // English anyway — because it carried a private helper:
    //
    //     return Localizations.localeOf(context).languageCode == 'ru' ? ru : en;
    //
    // Perfect translations plus a helper that never reads them is still an
    // English screen. Coverage means nothing without the wiring, so assert the
    // wiring first.
    final src = read('settings_screen.dart');
    final start = src.indexOf('/// Power / heat settings.');
    final end = src.indexOf('class _StorageSettingsScreen', start);
    final body = src.substring(start, end);

    // Comments quote the old code deliberately; strip them before judging.
    final code = body
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      code.contains('Localizations.localeOf'),
      isFalse,
      reason: 'the Power screen decides the language by itself again — every '
          'locale except ru will silently read English',
    );
    expect(
      code.contains('_settingsLabel(context'),
      isTrue,
      reason: 'the screen must resolve text through the shared helper, which '
          'is what consults _settingsTranslations',
    );
  });

  test('the extractor actually found the screen (guards a silent no-op)', () {
    final english = powerScreenEnglish();
    // If a refactor renames the screen this test could quietly assert nothing.
    expect(english.length, greaterThanOrEqualTo(8),
        reason: 'found only ${english.length} strings — the extractor is '
            'probably looking at the wrong region');
    expect(english, contains('Power'));
    expect(english, contains('Glass bubbles'));
  });

  // ru and en are returned directly by the helper and need no map entry.
  for (final locale in const ['uk', 'es', 'pt', 'fr', 'de']) {
    test('locale $locale translates every Power string', () {
      final keys = keysForLocale(locale);
      final missing =
          powerScreenEnglish().where((s) => !keys.contains(s)).toList();
      expect(
        missing,
        isEmpty,
        reason: 'these fall back to English for $locale speakers:\n'
            '${missing.map((s) => '  • $s').join('\n')}',
      );
    });
  }

  test('pt-BR inherits pt rather than falling back to English', () {
    // `settingsScreenLabel` resolves ptBR through the pt map (see
    // `_translatedStatic`), so Brazilian users are covered by the same entries
    // — this pins that relationship instead of leaving it to be rediscovered.
    final pt = keysForLocale('pt');
    for (final s in powerScreenEnglish()) {
      expect(pt.contains(s), isTrue, reason: 'pt-BR would show English: $s');
    }
  });
}
