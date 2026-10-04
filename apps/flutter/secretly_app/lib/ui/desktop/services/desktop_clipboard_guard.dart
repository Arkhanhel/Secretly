// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../diagnostics/diag_log.dart';

/// Секрет в буфере обмена — не дольше, чем он нужен (01.10.2026).
///
/// 🔴 ЗАЧЕМ. Экран набора восстановления компьютер берёт у телефона целиком
/// (`RecoveryKitScreen`), а там кнопка «Копировать» кладёт набор в буфер — и
/// он лежал там до следующего копирования: час, неделю, до перезагрузки. Набор
/// восстановления вместе с паролем возвращает аккаунт целиком, а буфер
/// читает любая программа и любой менеджер истории буфера. Телефонный экран
/// выпущен и заморожен, поэтому сторожит компьютер снаружи: пока окно
/// открыто, он замечает, что набор скопирован; через [ttl] после копирования и
/// при закрытии окна стирает буфер — ТОЛЬКО если там всё ещё наш текст.
/// Скопированное человеком после этого не трогается.
///
/// 🔴 КАК ЗАМЕЧАЕТСЯ, НЕ ЧИТАЯ ЧУЖОГО. macOS с 15.4 спрашивает разрешение,
/// когда программа сама читает буфер, записанный ДРУГОЙ программой. Поэтому
/// основной путь — счётчик изменений буфера (`NSPasteboard.changeCount`,
/// `GetClipboardSequenceNumber`): он ничего не раскрывает и ни о чём не
/// спрашивает. Содержимое читается один раз — когда счётчик сдвинулся при
/// открытом окне набора, то есть почти наверняка после нашего же
/// копирования, — а «всё ещё наш текст» проверяется тем же счётчиком, без
/// чтения. Без нативного счётчика (Linux, проверки) — сравнение текста.
class DesktopClipboardGuard {
  DesktopClipboardGuard({
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting Future<String?> Function()? readText,
    @visibleForTesting Future<void> Function()? clear,
    @visibleForTesting Duration? pollEvery,
    @visibleForTesting Duration? ttl,
  }) : _channel = channel ?? const MethodChannel('secretly/clipboard_guard'),
       _readTextOverride = readText,
       _clearOverride = clear,
       pollEvery = pollEvery ?? const Duration(milliseconds: 500),
       ttl = ttl ?? const Duration(seconds: 60);

  static final DesktopClipboardGuard instance = DesktopClipboardGuard();

  final MethodChannel _channel;
  final Future<String?> Function()? _readTextOverride;
  final Future<void> Function()? _clearOverride;

  /// Как часто смотреть на буфер, пока окно открыто.
  final Duration pollEvery;

  /// Сколько наш текст может пролежать в буфере после копирования.
  final Duration ttl;

  Future<int?> _changeCount() async {
    try {
      final v = await _channel.invokeMethod<int>('changeCount');
      return v;
    } catch (_) {
      // Нет нативной стороны (Linux, проверки) — сравниваем текст.
      return null;
    }
  }

  Future<String?> _readText() async {
    final override = _readTextOverride;
    if (override != null) return override();
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clear() async {
    final override = _clearOverride;
    if (override != null) return override();
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (_) {
      // Не вышло — нечем помочь; следующее копирование всё равно заменит.
    }
  }

  /// Сторожить буфер, пока открыто окно, показывающее [secret]: [open]
  /// завершается, когда окно закрыли. Возвращается после закрытия и уборки.
  Future<void> guard(String secret, Future<Object?> open) async {
    if (secret.isEmpty) {
      await open;
      return;
    }
    var baseline = await _changeCount();
    int? oursAt; // счётчик, при котором в буфере НАШ текст
    var oursByText = false; // то же без счётчика — замечено чтением
    Timer? expiry;
    Future<void>? inflight;

    Future<bool> stillOurs() async {
      final at = oursAt;
      if (at != null) return await _changeCount() == at;
      if (oursByText) return await _readText() == secret;
      return false;
    }

    Future<void> wipe(String why) async {
      expiry?.cancel();
      expiry = null;
      if (await stillOurs()) {
        await _clear();
        DiagLog.event('clipboard', 'secret_cleared', {'why': why});
      }
      oursAt = null;
      oursByText = false;
      // Наша же очистка сдвинула счётчик — это не новое копирование.
      baseline = await _changeCount();
    }

    void arm() {
      expiry?.cancel();
      expiry = Timer(ttl, () => unawaited(wipe('ttl')));
    }

    Future<void> look() async {
      final count = await _changeCount();
      if (count != null) {
        if (count == baseline) return;
        baseline = count;
        if (await _readText() == secret) {
          oursAt = count;
          arm();
        } else {
          // Человек скопировал другое — наше уже не в буфере.
          oursAt = null;
          expiry?.cancel();
        }
        return;
      }
      final ours = await _readText() == secret;
      if (ours && !oursByText) arm();
      if (!ours) expiry?.cancel();
      oursByText = ours;
    }

    // Один взгляд за раз: медленный канал не должен наслаивать проверки.
    Future<void> check() =>
        inflight ??= look().whenComplete(() => inflight = null);

    final ticker = Timer.periodic(pollEvery, (_) => unawaited(check()));
    try {
      await open;
    } finally {
      ticker.cancel();
      // Скопировали в последний миг — заметить, и сразу убрать.
      await inflight;
      await check();
      await wipe('closed');
    }
  }
}
