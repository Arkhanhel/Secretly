// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/safe_backup_upload_gate.dart';

void main() {
  test('🔴 смена пароля: автокопия и перезаливка — одна загрузка', () async {
    var clock = 1000;
    final gate = SafeBackupUploadGate(nowMs: () => clock);
    var uploads = 0;
    final firstMayFinish = Completer<void>();

    // Перезаливка с экрана: момент — до сохранения пароля.
    const passwordSetAt = 1000;
    clock = 1001;
    final screen = gate.run<bool>(
      password: 'новый-пароль-1',
      skipIfStartedSinceMs: passwordSetAt,
      upload: () async {
        uploads++;
        await firstMayFinish.future;
        return true;
      },
      accepted: (ok) => ok,
    );
    // Автокопия, запущенная сохранением пароля, приходит, пока первая идёт.
    final auto = gate.run<bool>(
      password: 'новый-пароль-1',
      skipIfStartedSinceMs: 1000,
      upload: () async {
        uploads++;
        return true;
      },
      accepted: (ok) => ok,
    );
    await Future<void>.delayed(Duration.zero);
    expect(uploads, 1, reason: 'вторая ждёт первую, а не идёт параллельно');
    firstMayFinish.complete();
    expect(await screen, isTrue);
    expect(await auto, isNull, reason: 'свежая копия с тем же паролем уже есть');
    expect(uploads, 1);
  });

  test('другой пароль или более ранняя загрузка — не повод пропускать',
      () async {
    var clock = 100;
    final gate = SafeBackupUploadGate(nowMs: () => clock);
    var uploads = 0;
    Future<bool?> go(String pw, int? since) => gate.run<bool>(
          password: pw,
          skipIfStartedSinceMs: since,
          upload: () async {
            uploads++;
            return true;
          },
          accepted: (ok) => ok,
        );

    // Старая автокопия старым паролем началась ДО смены пароля.
    await go('старый-пароль', null);
    clock = 200;
    expect(await go('новый-пароль', 150), isTrue);
    expect(uploads, 2, reason: 'архив зашифрован другим паролем');

    // Загрузка тем же паролем, но начатая раньше нужного момента.
    clock = 300;
    expect(await go('новый-пароль', 250), isTrue);
    expect(uploads, 3);

    // Без отметки (кнопка «создать копию») — всегда загружает.
    expect(await go('новый-пароль', null), isTrue);
    expect(uploads, 4);
  });

  test('неудачная загрузка не считается свежей и не держит очередь', () async {
    final gate = SafeBackupUploadGate(nowMs: () => 10);
    var uploads = 0;

    await expectLater(
      gate.run<bool>(
        password: 'p',
        upload: () async {
          uploads++;
          throw StateError('сеть');
        },
        accepted: (ok) => ok,
      ),
      throwsStateError,
    );
    expect(
      await gate.run<bool>(
        password: 'p',
        skipIfStartedSinceMs: 0,
        upload: () async {
          uploads++;
          return false;
        },
        accepted: (ok) => ok,
      ),
      isFalse,
    );
    expect(
      await gate.run<bool>(
        password: 'p',
        skipIfStartedSinceMs: 0,
        upload: () async {
          uploads++;
          return true;
        },
        accepted: (ok) => ok,
      ),
      isTrue,
    );
    expect(uploads, 3);
  });
}
