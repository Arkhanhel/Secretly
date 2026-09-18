// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПАРОЛЬ ПОСЛЕ ДОЛГОГО ОТСУТСТВИЯ СВЯЗИ.
//
// 🔴 Отключить потерянный компьютер можно, только пока он выходит на связь:
// команда приходит с сервера. Унесённый без сети её не получит никогда, и
// переписка остаётся открытой. Срок же наступает сам — по нему и запираем.
//
// Решение владельца (17.09.2026): именно пароль, а не стирание — данные целы.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/app/desktop_offline_lock.dart';

const _day = 24 * 60 * 60 * 1000;

void main() {
  const now = 1700000000000;

  bool lock({
    int lastContactAtMs = now - 20 * _day,
    int days = DesktopOfflineLock.defaultDays,
    bool lockEnabled = true,
  }) => DesktopOfflineLock.shouldLock(
    lastContactAtMs: lastContactAtMs,
    nowMs: now,
    days: days,
    lockEnabled: lockEnabled,
  );

  group('когда запирать', () {
    test('🔴 давно нет связи — пароль', () {
      expect(lock(), isTrue);
    });

    test('связь была недавно — не трогаем', () {
      expect(lock(lastContactAtMs: now - 3 * _day), isFalse);
    });

    test('ровно на сроке — запираем', () {
      expect(lock(lastContactAtMs: now - 14 * _day), isTrue);
    });

    test('🔴 пароль входа не задан — запирать нечем', () {
      expect(lock(lockEnabled: false), isFalse);
    });

    test('выбрано «Никогда» — не запираем', () {
      expect(lock(days: 0), isFalse);
    });

    test('🔴 связи не было ни разу — не пугаем на ровном месте', () {
      // Первый запуск с этой правкой: отметки ещё нет.
      expect(lock(lastContactAtMs: 0), isFalse);
    });

    test('часы уехали назад — не запираем', () {
      expect(lock(lastContactAtMs: now + 5 * _day), isFalse);
    });
  });

  group('срок из настроек', () {
    test('по умолчанию две недели', () {
      expect(DesktopOfflineLock.normalizeDays(null), 14);
    });

    test('свои значения сохраняются', () {
      for (final d in const [0, 7, 14, 30]) {
        expect(DesktopOfflineLock.normalizeDays(d), d);
      }
    });

    test('🔴 чужое число не ослабляет защиту молча', () {
      expect(DesktopOfflineLock.normalizeDays(999), 14);
      expect(DesktopOfflineLock.normalizeDays(-5), 0);
    });
  });

  group('проводка (по исходникам)', () {
    String read(String path) => File(path).readAsStringSync();

    test('🔴 окно проверяет срок при запуске и запирает', () {
      final shell = read('lib/ui/desktop/app/desktop_production_app.dart');
      expect(shell.contains('DesktopOfflineLock.shouldLock('), isTrue);
      expect(shell.contains('lockNow(SecurityLockScope.app)'), isTrue);
    });

    test('🔴 удачная связь с сервером отмечается', () {
      final ctrl = read('lib/app/app_controller.dart');
      expect(ctrl.contains('prefsLastServerContactAtMsKey'), isTrue);
      final at = ctrl.indexOf('void _onRelayAcceptedOwnDevice()');
      expect(at, greaterThan(0));
      expect(
        ctrl.substring(at, at + 400).contains('_noteServerContact()'),
        isTrue,
        reason: 'без отметки срок никогда не начнёт идти',
      );
    });

    test('настройка есть во всех восьми языках', () {
      for (final code in const [
        'ru', 'en', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de',
      ]) {
        final arb = read('lib/l10n/app_$code.arb');
        for (final key in const [
          'desktopOfflineLockTitle',
          'desktopOfflineLockDescription',
          'desktopOfflineLockNever',
          'desktopOfflineLockDays7',
          'desktopOfflineLockDays14',
          'desktopOfflineLockDays30',
        ]) {
          expect(arb.contains('"$key"'), isTrue, reason: '$code: $key');
        }
      }
    });
  });
}
