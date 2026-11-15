// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

import 'dart:async';
import 'dart:convert';

import 'auth_signer.dart';

/// Очередь загрузок резервной копии на сервер (14.11.2026).
///
/// Сохранение пароля автокопии само запускает автокопию, а экран тут же
/// перезаливает копию новым паролем. Без очереди два одинаковых архива уходили
/// одновременно, а на сервере оставался тот, что дошёл последним.
///
/// Загрузки идут строго по одной. Загрузка с `skipIfStartedSinceMs` не
/// выполняется, если после этого момента уже НАЧАЛАСЬ и прошла загрузка с тем
/// же паролем: её архив не старше нужного. Время берётся по началу загрузки,
/// не по концу: архив собирается в начале. Пароль хранится только как
/// отпечаток и только в памяти.
class SafeBackupUploadGate {
  SafeBackupUploadGate({int Function()? nowMs})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int Function() _nowMs;
  Future<void>? _tail;
  ({int startedAtMs, String pwDigest})? _last;

  /// Выполняет [upload] после всех начатых раньше. [upload] возвращает `true`,
  /// когда копия принята сервером — только такая загрузка запоминается.
  ///
  /// Возвращает `null`, если загрузка пропущена как повтор свежей.
  Future<T?> run<T>({
    required String password,
    int? skipIfStartedSinceMs,
    required Future<T> Function() upload,
    required bool Function(T result) accepted,
  }) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    if (previous != null) await previous;
    try {
      final digest = await _digest(password);
      final last = _last;
      if (skipIfStartedSinceMs != null &&
          last != null &&
          last.startedAtMs >= skipIfStartedSinceMs &&
          last.pwDigest == digest) {
        return null;
      }
      final startedAtMs = _nowMs();
      final result = await upload();
      if (accepted(result)) {
        _last = (startedAtMs: startedAtMs, pwDigest: digest);
      }
      return result;
    } finally {
      done.complete();
      if (identical(_tail, done.future)) _tail = null;
    }
  }

  static Future<String> _digest(String password) => AuthSigner.sha256B64(
        utf8.encode('secretly-backup-upload-dedupe|$password'),
      );
}
