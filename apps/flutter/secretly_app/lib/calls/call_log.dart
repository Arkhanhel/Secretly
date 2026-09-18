// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('secretly/log');
const bool _enableCallLogsInRelease = bool.fromEnvironment(
  'SECRETLY_ENABLE_CALL_LOGS_IN_RELEASE',
  defaultValue: false,
);
const bool _redactCallLogsInRelease = bool.fromEnvironment(
  'SECRETLY_REDACT_CALL_LOGS_IN_RELEASE',
  defaultValue: true,
);
const String _releaseOperationalPrefix = '[OP] ';

final RegExp _sensitiveKv = RegExp(
  r'\b(sdp|candidate|nonce|signature|[A-Za-z_]*(?:id|Id|ID))=([^\s,;]+)',
  caseSensitive: false,
);

/// Logging utility that writes to Android's logcat via native MethodChannel.
/// Works in release builds.
///
/// Release-mode policy (see docs/MESSAGE_DELIVERY_AUDIT_2026-05-28.md §10.4 O1):
///
///   * **Operational events** prefixed with `[OP] ` (emitted by `callOpLog`
///     and `DiagLog.event`) ALWAYS flow through in release. They are
///     emitted with mandatory redaction unless an explicit unredacted
///     diagnostic build was requested via `SECRETLY_REDACT_CALL_LOGS_IN_RELEASE=false`
///     AND the broader `SECRETLY_ENABLE_CALL_LOGS_IN_RELEASE=true` opt-in.
///     This gives us production observability without leaking PII.
///
///   * **Free-text logs** (no `[OP]` prefix) remain gated behind the
///     dev-only `--dart-define SECRETLY_ENABLE_CALL_LOGS_IN_RELEASE=true`
///     opt-in, because they can carry developer context (file paths,
///     raw error strings, etc.) unsafe for production logging.
void callLog(String tag, String message) {
  final isOperational = message.startsWith(_releaseOperationalPrefix);

  // [A] Release-mode gate. Non-operational free-text logs still require
  //     the explicit dev-only opt-in. Operational events bypass.
  if (kReleaseMode && !isOperational && !_enableCallLogsInRelease) {
    return;
  }

  var safeMessage = message;
  if (kReleaseMode) {
    // For operational events we force redaction whenever either the
    // global redact flag is on OR we are running without the broader
    // dev-only opt-in. That ensures production builds (`flag=off`,
    // `redact=on`) emit only sanitized operational telemetry, while
    // explicit diagnostic builds (`flag=on`, `redact=off`) preserve the
    // legacy unredacted-debug behavior they enabled on purpose.
    final shouldRedact = isOperational
        ? (_redactCallLogsInRelease || !_enableCallLogsInRelease)
        : _redactCallLogsInRelease;
    if (shouldRedact) {
      if (!isOperational) {
        // Free-text in redacted-release mode: drop. We cannot safely
        // emit unstructured developer messages in production.
        return;
      }
      // Strip the `[OP] ` prefix, apply PII regex, normalize whitespace,
      // truncate to a single readable line.
      safeMessage = safeMessage.substring(_releaseOperationalPrefix.length);
      safeMessage = safeMessage.replaceAllMapped(
        _sensitiveKv,
        (m) => '${m.group(1)}=<redacted>',
      );
      safeMessage = safeMessage.replaceAll('\n', ' ').replaceAll('\r', ' ');
      if (safeMessage.length > 240) {
        safeMessage = '${safeMessage.substring(0, 240)}…';
      }
    }
  }

  if (!kReleaseMode) {
    debugPrint('[$tag] $safeMessage');
  }

  // Fire-and-forget — don't await so we never block call logic.
  _channel
      .invokeMethod('log', {'tag': tag, 'msg': safeMessage})
      .catchError((Object _) {
        // 🔴 ФОНОВЫЙ ИЗОЛЯТ БЫЛ НЕВИДИМ ЦЕЛИКОМ (10.08.2026).
        //
        // Канал `secretly/log` зарегистрирован только на ПЕРЕДНЕМ движке — его
        // ставит MainActivity. В фоновом изоляте обработчика нет, вызов падает,
        // а прежний `.catchError((_) {})` глотал это молча. То есть весь путь
        // фонового приёма — скачивание, расшифровка, решение об уведомлении —
        // не писал НИ ОДНОЙ строки даже в сборке с включённой диагностикой.
        //
        // Нашлось при разборе жалобы «уведомления приходят повторно»: в записи
        // логов было видно приход пуша и полная тишина после него, хотя
        // уведомление на экране появлялось.
        //
        // 🔴 ИМЕННО `print`, А НЕ `developer.log` (11.08.2026, моя ошибка).
        //
        // Первая редакция этого запасного пути звала `developer.log`. В релизной
        // сборке он уходит в отладочный канал движка и в logcat НЕ ПОПАДАЕТ —
        // то есть фоновый изолят остался таким же невидимым, каким был. Это
        // выяснилось на проде: реле показывало, что телефон исправно забирает
        // ящик по HTTP, а в logcat от Dart по-прежнему не было ни строки.
        //
        // `print` в релизе идёт в logcat тегом `flutter` и обработчика на
        // стороне платформы не требует, поэтому работает в любом изоляте.
        print('[$tag] $safeMessage');
      });
}

String? _normalizeOperationalValue(Object? value) {
  if (value == null) return null;
  if (value is Enum) return value.name;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return text.replaceAll(RegExp(r'\s+'), '_');
}

void callOpLog(
  String tag,
  String event, {
  Map<String, Object?> fields = const <String, Object?>{},
}) {
  final buffer = StringBuffer('[OP] event=${event.trim()}');
  for (final entry in fields.entries) {
    final key = entry.key.trim();
    if (key.isEmpty) continue;
    final value = _normalizeOperationalValue(entry.value);
    if (value == null) continue;
    buffer.write(' $key=$value');
  }
  callLog(tag, buffer.toString());
}
