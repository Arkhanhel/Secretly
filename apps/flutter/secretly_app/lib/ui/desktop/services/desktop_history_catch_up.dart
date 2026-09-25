// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../diagnostics/diag_log.dart';
import '../../../sync/peer_history_service.dart';

/// 🔴 Догон истории на ПК после отключения (25.09.2026).
///
/// Жалоба владельца: ПК не видел половины того, что он писал с телефона и что
/// ему писали, пока компьютер был выключен, а прочитанное на телефоне висело
/// непрочитанным. Журнал реле показал причину: копии для своих устройств жили
/// на сервере час, и за ночь истекли все 23 копии его ответов. Срок копий
/// исправлен отдельно (реле и `sendControlMessage`), но ПК, выключенный
/// дольше этого срока, или телефон, который копию так и не послал, оставляют
/// дыру. Её закрывает история с телефона.
///
/// Прежде история запрашивалась один раз при запуске и только если прошлая
/// была больше суток назад — «последние 250 событий». Здесь:
///
///  * ПК помнит, когда он последний раз был на связи с реле;
///  * при запуске и при восстановлении связи после паузы больше
///    [gapWorthCatchingUp] он просит у телефона всё, что новее этого момента
///    (с запасом [floorMargin]), листая до конца (`PeerHistoryService.catchUp`);
///  * телефон отвечает, только пока он на экране. Не ответил — окно остаётся
///    ждать, и запрос повторяется, как только от телефона придёт что угодно
///    (значит, он сейчас открыт), и изредка по таймеру.
///
/// Только ПК: телефон этот класс не запускает.
class DesktopHistoryCatchUp {
  DesktopHistoryCatchUp._();

  static const String _kOnlineAtKey = 'desktop_relay_online_at_ms_v1';
  static const String _kPendingSinceKey = 'desktop_history_pending_since_ms_v1';

  /// Пауза связи, после которой имеет смысл догонять.
  static const Duration gapWorthCatchingUp = Duration(minutes: 10);

  /// Запас назад от последней связи: часы устройств расходятся, а сообщение,
  /// написанное перед самым отключением, могло не успеть прийти.
  static const Duration floorMargin = Duration(minutes: 30);

  /// Первый запуск этой сборки: когда ПК был на связи, ещё неизвестно.
  static const Duration firstRunLookback = Duration(days: 3);

  /// Дальше недели не заглядываем: столько живут вложения на сервере, и это
  /// предел работы для телефона.
  static const Duration maxLookback = Duration(days: 7);

  /// Повтор по признаку жизни телефона — не чаще.
  static const Duration minRetryGap = Duration(minutes: 2);

  /// Повтор по таймеру, пока окно не закрыто, — и не больше [maxTimerRetries]
  /// раз подряд: дальше ждём признака жизни телефона.
  static const Duration timerRetryEvery = Duration(minutes: 15);
  static const int maxTimerRetries = 16;

  static bool Function()? _relayOnline;
  static Future<PeerHistoryCatchUpOutcome> Function(int sinceMs)? _runCatchUp;
  static SharedPreferences? _prefsForTest;
  static StreamSubscription<bool>? _connSub;
  static StreamSubscription<String>? _activitySub;
  static Timer? _heartbeat;
  static Timer? _retryTimer;
  static int _timerRetries = 0;
  static int _lastAttemptAtMs = 0;
  static bool _attemptInFlight = false;

  static Future<SharedPreferences> _prefs() async =>
      _prefsForTest ?? await SharedPreferences.getInstance();

  /// Запускается один раз после подъёма контроллера (вместо прежнего
  /// `PeerHistoryService.maybeSyncOnBoot`). Повторный вызов перезапускает.
  ///
  /// Контроллер сюда не передаётся целиком — только то, что нужно: состояние
  /// связи с реле и знак жизни своего устройства.
  static Future<void> start({
    required Stream<bool> relayConnectionChanges,
    required Stream<String> ownDeviceActivity,
    required bool Function() relayOnline,
    Future<PeerHistoryCatchUpOutcome> Function(int sinceMs)? runCatchUp,
    SharedPreferences? prefsForTest,
    DateTime? now,
  }) async {
    stop();
    _relayOnline = relayOnline;
    _runCatchUp =
        runCatchUp ??
        (sinceMs) => PeerHistoryService.instance.catchUp(sinceMs: sinceMs);
    _prefsForTest = prefsForTest;
    try {
      final prefs = await _prefs();
      final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final floor = catchUpFloorMs(
        lastOnlineMs: prefs.getInt(_kOnlineAtKey) ?? 0,
        pendingSinceMs: prefs.getInt(_kPendingSinceKey) ?? 0,
        nowMs: nowMs,
      );
      if (floor != null) {
        await prefs.setInt(_kPendingSinceKey, floor);
      }
    } catch (_) {
      // Без настроек догонять не с чего — ПК работает и без истории.
    }
    _connSub = relayConnectionChanges.listen(_onRelayConnection);
    _activitySub = ownDeviceActivity.listen((_) {
      unawaited(_attempt(reason: 'own_device_active'));
    });
    _heartbeat = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_isOnline()) unawaited(_markOnline());
    });
    if (relayOnline()) {
      await _markOnline();
    }
    unawaited(_attempt(reason: 'boot'));
  }

  static void stop() {
    _connSub?.cancel();
    _connSub = null;
    _activitySub?.cancel();
    _activitySub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _timerRetries = 0;
    _relayOnline = null;
    _runCatchUp = null;
  }

  static bool _isOnline() {
    try {
      return _relayOnline?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// С какого момента догонять, или null — догонять нечего.
  ///
  /// Правило отделено от хранилища и часов, чтобы его можно было проверить.
  @visibleForTesting
  static int? catchUpFloorMs({
    required int lastOnlineMs,
    required int pendingSinceMs,
    required int nowMs,
  }) {
    int? floor;
    if (lastOnlineMs <= 0) {
      floor = nowMs - firstRunLookback.inMilliseconds;
    } else if (nowMs - lastOnlineMs >= gapWorthCatchingUp.inMilliseconds) {
      floor = lastOnlineMs - floorMargin.inMilliseconds;
    }
    if (pendingSinceMs > 0) {
      floor = floor == null ? pendingSinceMs : math.min(floor, pendingSinceMs);
    }
    if (floor == null) return null;
    return math.max(floor, nowMs - maxLookback.inMilliseconds);
  }

  static Future<void> _onRelayConnection(bool connected) async {
    try {
      final prefs = await _prefs();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (connected) {
        // Новая связь — новая попытка: таймерные повторы считаются заново.
        _timerRetries = 0;
        final floor = catchUpFloorMs(
          lastOnlineMs: prefs.getInt(_kOnlineAtKey) ?? 0,
          pendingSinceMs: prefs.getInt(_kPendingSinceKey) ?? 0,
          nowMs: nowMs,
        );
        if (floor != null) {
          await prefs.setInt(_kPendingSinceKey, floor);
        }
        await prefs.setInt(_kOnlineAtKey, nowMs);
        unawaited(_attempt(reason: 'reconnect'));
      } else {
        // Связь только что была — запомним этот миг, а не прошлый такт.
        await prefs.setInt(_kOnlineAtKey, nowMs);
      }
    } catch (_) {
      // Учёт — лучшее из возможного; догон подхватит следующая связь.
    }
  }

  static Future<void> _markOnline() async {
    try {
      final prefs = await _prefs();
      await prefs.setInt(_kOnlineAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<void> _attempt({required String reason}) async {
    final runCatchUp = _runCatchUp;
    if (runCatchUp == null || _attemptInFlight) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (reason != 'boot' &&
        reason != 'reconnect' &&
        nowMs - _lastAttemptAtMs < minRetryGap.inMilliseconds) {
      return;
    }
    final SharedPreferences prefs;
    try {
      prefs = await _prefs();
    } catch (_) {
      return;
    }
    final sinceMs = prefs.getInt(_kPendingSinceKey) ?? 0;
    if (sinceMs <= 0) return;
    if (!_isOnline()) return; // спросим, когда будет связь

    _attemptInFlight = true;
    _lastAttemptAtMs = nowMs;
    PeerHistoryCatchUpOutcome outcome = PeerHistoryCatchUpOutcome.unavailable;
    try {
      outcome = await runCatchUp(sinceMs);
    } catch (_) {
      outcome = PeerHistoryCatchUpOutcome.noResponse;
    } finally {
      _attemptInFlight = false;
    }
    DiagLog.event('peer_history', 'catch_up', {
      'reason': reason,
      'outcome': outcome.name,
      'since_age_min': (nowMs - sinceMs) ~/ 60000,
    });

    if (outcome == PeerHistoryCatchUpOutcome.completed) {
      // Окно могло сдвинуться, пока шёл догон (новая пауза связи): снимаем
      // только то, что догнали.
      final current = prefs.getInt(_kPendingSinceKey) ?? 0;
      if (current == sinceMs) {
        await prefs.remove(_kPendingSinceKey);
      }
      _retryTimer?.cancel();
      _retryTimer = null;
      _timerRetries = 0;
      return;
    }
    _scheduleTimerRetry();
  }

  static void _scheduleTimerRetry() {
    if (_retryTimer != null || _timerRetries >= maxTimerRetries) return;
    _retryTimer = Timer(timerRetryEvery, () {
      _retryTimer = null;
      _timerRetries += 1;
      unawaited(_attempt(reason: 'timer'));
    });
  }

  /// Снять паузу между повторами — чтобы проверка не ждала две минуты.
  @visibleForTesting
  static void debugForgetLastAttempt() => _lastAttemptAtMs = 0;

  @visibleForTesting
  static void resetForTest() {
    stop();
    _lastAttemptAtMs = 0;
    _attemptInFlight = false;
    _prefsForTest = null;
  }
}
