// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/legal/third_party_licenses.dart';

// О-6 (26.08.2026). И SIL Open Font License, и Apache 2.0 требуют, чтобы текст
// лицензии сопровождал распространение. Шрифты уезжают внутри бинарника —
// значит и лицензия обязана уехать туда же, а не остаться в репозитории.
//
// Flutter собирает экран лицензий только по пакетам из `pub`; шрифты, положенные
// ассетами, он не видит. Заявляются они руками, а рука забывает — поэтому здесь
// сторож, а не доверие.

Set<String> _normalized(Iterable<String> names) =>
    names.map((n) => n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')).toSet();

/// Семейства шрифтов, объявленные в `pubspec.yaml`.
Set<String> _familiesFromPubspec() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final families = <String>{};
  for (final line in lines) {
    final m = RegExp(r'^\s*-\s*family:\s*(\S+)\s*$').firstMatch(line);
    if (m != null) families.add(m.group(1)!);
  }
  return families;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 каждый шрифт из pubspec заявлен в лицензиях', () async {
    // Настоящая защита не в том, что лицензии есть сегодня, а в том, что
    // завтрашний шрифт нельзя будет добавить молча: тест покраснеет на
    // семействе, которого нет в списке.
    final declared = _familiesFromPubspec();
    expect(declared, isNotEmpty, reason: 'разбор pubspec сломался');

    LicenseRegistry.reset();
    registerThirdPartyLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final registered = _normalized(entries.expand((e) => e.packages));

    final missing = declared.where(
      (f) => !_normalized(<String>[f]).every(registered.contains),
    );
    expect(
      missing,
      isEmpty,
      reason:
          'у этих семейств нет лицензии в lib/legal/third_party_licenses.dart '
          'и в assets/fonts/LICENSES.md: $missing',
    );
  });

  test('🔴 компьютер тоже заявляет лицензии — ровно один раз', () {
    // Экран лицензий компьютера (настройки) молчал о шрифтах: вызов был только
    // в телефонном main (17.09.2026). Повторный вызов задвоит записи.
    for (final path in ['lib/main.dart', 'lib/main_desktop.dart']) {
      final src = File(path).readAsStringSync();
      expect(
        RegExp(r'^\s*registerThirdPartyLicenses\(\);', multiLine: true)
            .allMatches(src)
            .length,
        1,
        reason: path,
      );
    }
  });

  test('🔴 тексты лицензий дословные, а не ссылки', () async {
    // Ссылка на лицензию лицензией не является: обе требуют приложить ТЕКСТ.
    // Проверяются места, которые нельзя воспроизвести по памяти, — заголовок с
    // датой редакции и завершающий раздел.
    LicenseRegistry.reset();
    registerThirdPartyLicenses();
    final entries = await LicenseRegistry.licenses.toList();

    final ofl = entries.firstWhere((e) => e.packages.contains('Inter'));
    final oflText = ofl.paragraphs.map((p) => p.text).join('\n');
    expect(oflText, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(oflText, contains('26 February 2007'));
    expect(oflText, contains('OTHER DEALINGS IN THE FONT SOFTWARE'));

    final apache = entries.firstWhere((e) => e.packages.contains('Roboto'));
    final apacheText = apache.paragraphs.map((p) => p.text).join('\n');
    expect(apacheText, contains('Apache License'));
    expect(apacheText, contains('Version 2.0, January 2004'));
    expect(apacheText, contains('APPENDIX: How to apply the Apache License'));
  });

  test('🔴 тексты лицензий лежат и файлами рядом со шрифтами', () {
    // Экран в приложении закрывает требование для пользователя, файлы — для
    // того, кто получает исходный код. Оба пути нужны: публичный репозиторий
    // везёт сами `.ttf`.
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    expect(File('assets/fonts/LICENSE-APACHE-2.0.txt').existsSync(), isTrue);
    expect(File('assets/fonts/LICENSES.md').existsSync(), isTrue);
  });
}
