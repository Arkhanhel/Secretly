// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ВРЕМЕННЫЕ ОТКРЫТИЯ БАЗЫ — СО СВОИМ СОЕДИНЕНИЕМ (06.10.2026).
//
// На Android общее соединение sqflite (`singleInstance`) одно на все движки
// Flutter процесса. Фоновая выборка пушей открывала базу и в конце закрывала
// её — вместе с соединением основного приложения: на Xiaomi при запуске
// сыпались `database_closed` из созвона комнаты и отправки, пока сторож не
// переоткрывал базу. Кто открывает базу ненадолго и закрывает, обязан взять
// своё соединение.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppDb.open передаёт выбор соединения в sqflite на всех площадках', () {
    final src = File('lib/storage/app_db.dart').readAsStringSync();
    final at = src.indexOf('static Future<AppDb> open({');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 9000);
    expect(body.contains('bool shared = true'), isTrue);
    // Телефон (SQLCipher) и компьютер (FFI).
    expect(
      RegExp(r'singleInstance: shared').allMatches(body).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('🔴 открыл-сделал-закрыл — только со своим соединением', () {
    for (final entry in const <String, String>{
      'lib/push/background_inbox_fetcher.dart':
          'AppDb.open(passphrase: dbPass, shared: false)',
      'lib/push/background_worker.dart':
          'AppDb.open(passphrase: dbPass, shared: false)',
    }.entries) {
      final src = File(entry.key).readAsStringSync();
      expect(src.contains(entry.value), isTrue, reason: entry.key);
      expect(
        src.contains('AppDb.open(passphrase: dbPass);'),
        isFalse,
        reason: '${entry.key}: общее соединение закрылось бы у приложения',
      );
    }
    final ctrl = File('lib/app/app_controller.dart').readAsStringSync();
    expect(
      ctrl.contains('final importDb = await AppDb.open(passphrase: dbPass, '
          'shared: false);'),
      isTrue,
    );
    final remember = ctrl.indexOf('Future<void> _rememberRestoredOwnDeviceIdsInDb(');
    expect(remember, greaterThan(0));
    expect(
      ctrl.substring(remember, remember + 1200).contains('shared: false'),
      isTrue,
    );
  });
}
