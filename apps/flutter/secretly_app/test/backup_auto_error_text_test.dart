// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 14.11.2026: экран копий телефона переводит причины сбоя автокопии.
// Контроллер пишет их по-английски — строки на экране обязаны совпадать.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone backup screen knows the exact controller error strings', () {
    final controller = File('lib/app/app_controller.dart').readAsStringSync();
    final screen = File('lib/ui/safe_backup_screen.dart').readAsStringSync();
    for (final raw in const [
      'Auto-backup password is not set',
      'Auto-backup password does not meet the current policy',
    ]) {
      expect(controller.contains("'$raw'"), isTrue, reason: raw);
      expect(screen.contains("'$raw'"), isTrue, reason: raw);
    }
    expect(screen.contains('backupAutoErrorNoPassword'), isTrue);
    expect(screen.contains('_editAutoPassword(context)'), isTrue);
  });
}
