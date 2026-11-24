// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 Проверка локализации перед 1.9 (24.11.2026): экраны, которые передают в
// wave1Text только русский и английский, берут остальные языки из словаря
// по английскому тексту. 31 строка (звонок, контакты, обрезка видео, живые
// обои, пробный Premium) там отсутствовала — украинец, испанец, португалец,
// француз и немец видели английский. Этот тест ловит новые такие строки.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/wave1_l10n.dart';

const _lit = r"'((?:[^'\\]|\\.)*)'";

String _unescape(String s) =>
    s.replaceAll(r"\'", "'").replaceAll(r'\n', '\n').replaceAll(r'\\', r'\');

void main() {
  test('каждая строка wave1Text без своих переводов есть в словаре', () {
    final missing = <String>[];
    final direct = RegExp(
      r'wave1Text(?:ForLocale)?\([^()]*?\bru:\s*' + _lit + r',\s*en:\s*' + _lit + r'\s*,?\s*\)',
    );
    final helperDecl = RegExp(r'(\w+)\(String ru, String en\)\s*(?:=>|\{)');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      final pairs = <(String, String)>[];
      for (final m in direct.allMatches(src)) {
        pairs.add((m.group(1)!, m.group(2)!));
      }
      for (final h in helperDecl.allMatches(src)) {
        final call = RegExp(
          r'\b' + h.group(1)! + r'\(\s*' + _lit + r'\s*,\s*' + _lit + r'\s*\)',
        );
        for (final m in call.allMatches(src)) {
          pairs.add((m.group(1)!, m.group(2)!));
        }
      }
      for (final (ru, en) in pairs) {
        final e = _unescape(en);
        // Украинский всегда отличается от английского (кириллица), поэтому
        // совпадение = перевода нет и подставился английский.
        final uk = wave1TextForLocale('uk', ru: _unescape(ru), en: e);
        if (uk == e && RegExp('[A-Za-z]{2}').hasMatch(e)) {
          missing.add('${f.path}: $e');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('новые переводы: все шесть языков, не английский', () {
    for (final en in [
      'Weak connection', 'Global search', 'Set wallpaper',
      'Files up to 1 GB', 'Processing video…', 'QR code copied',
    ]) {
      for (final l in ['uk', 'es', 'pt', 'pt_BR', 'fr', 'de']) {
        expect(wave1TextForLocale(l, ru: 'ru', en: en), isNot(en),
            reason: '$l $en');
      }
    }
  });
}
