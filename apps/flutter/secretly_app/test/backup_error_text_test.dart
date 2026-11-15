// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 14.11.2026: ошибки копии — одной понятной строкой, без трассы Java.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations_ru.dart';
import 'package:secretly_app/ui/backup_error_text.dart';

void main() {
  final l10n = AppLocalizationsRu();

  test('named unreadable slot', () {
    final t = backupErrorText(
      l10n,
      StateError('secure_storage_unreadable:device_keys'),
    );
    expect(t, contains('«device_keys»'));
    expect(t, contains('Переписка на телефоне цела'));
  });

  test('raw Android AEADBadTagException becomes the same sentence', () {
    final e = PlatformException(
      code: 'Exception encountered',
      message: 'read',
      details: 'javax.crypto.AEADBadTagException: error:1e000065:Cipher '
          'functions:OPENSSL_internal:BAD_DECRYPT\n at java.lang.reflect...',
    );
    final t = backupErrorText(l10n, e);
    expect(t, isNot(contains('java')));
    expect(t, contains('защищённого хранилища'));
  });

  test('unknown error: first line, bounded', () {
    final t = backupErrorText(l10n, StateError('x' * 500 + '\nstack'));
    expect(t.length, lessThanOrEqualTo(161));
    expect(t, isNot(contains('stack')));
  });
}
