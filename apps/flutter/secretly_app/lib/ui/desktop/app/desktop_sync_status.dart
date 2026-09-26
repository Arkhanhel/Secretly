// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Desktop-only relay connection / backfill status holder.
//
// PR4 (2026-05-19, SPRINT2_AUDIT §16): mobile is always foreground so it
// doesn't need a visible "connecting / syncing" affordance — when the
// phone is unlocked, the relay is healthy. Desktop is different: the app
// is closed and reopened many times a day, the OS suspends the WS during
// sleep, and `flutter run` cold-boots can take 1–3 seconds to reach the
// first WS `Welcome` frame. Without UI feedback the user assumes "broken".
//
// This file does NOT touch [AppController] internals — it observes the
// already-exposed [AppController.relayConnectionChanges] stream and
// exposes a `ValueListenable<DesktopSyncStatus>` for the banner widget.
//
// State machine:
//
//   ┌─────────────┐  WS connects                   ┌─────────────┐
//   │  connecting │ ──────────────────────────▶    │   syncing   │
//   └─────────────┘                                └──────┬──────┘
//          ▲                                              │
//          │ WS drops                                     │ kSyncSettleDelay
//          │                                              ▼
//   ┌─────────────┐                                ┌─────────────┐
//   │ reconnecting│ ◀─────  WS drops  ─────────    │    online   │
//   └─────────────┘                                └─────────────┘
//
// `connecting` is the cold-boot state. After the first WS `connected=true`
// we move through a brief `syncing` window (covers the time it takes the
// HTTP /v1/pending + WS `Welcome → FetchPending` paths to drain a 7-day
// mailbox) before settling on `online`. If the connection later drops we
// switch to `reconnecting` — but never back to `connecting`, because by
// then the user knows the app works.
//
// Mobile is unaffected: this file is only constructed from desktop
// widgets, and the underlying [AppController] streams are read-only.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/app_controller.dart';
import '../shell/sidebar.dart' show ConnectionStatus;

/// Coarse relay/backfill phase shown in the desktop UI.
enum DesktopSyncPhase {
  /// Cold-boot — relay client not yet reported a connection.
  connecting,

  /// Connected; HTTP /v1/pending + WS FetchPending are still draining
  /// the per-device mailbox. We sit in this state for
  /// [DesktopSyncStatusController.kSyncSettleDelay] after the first
  /// `connected=true` event so the user sees a non-blank acknowledgement
  /// of "we're catching you up".
  syncing,

  /// Steady state.
  online,

  /// We were online and the WS dropped. Reconnect path is debounced via
  /// `_scheduleRelayReconnectKick` in [AppController].
  reconnecting,

  /// Связи нет дольше [DesktopSyncStatusController.kOfflineAfter]. Отдельно от
  /// [reconnecting]: «Переподключение…» через минуту молчания — это уже не
  /// сообщение о состоянии, а заставка. Красная точка честнее.
  offline,
}

/// Immutable snapshot. Compared by value in the controller's `notifyListeners`
/// gate so dependent widgets only rebuild on actual phase transitions.
@immutable
class DesktopSyncStatus {
  const DesktopSyncStatus({
    required this.phase,
    required this.changedAtMs,
  });

  final DesktopSyncPhase phase;

  /// Epoch ms at which we last entered [phase]. Used by the banner to
  /// fade in/out animations and to suppress flicker on reconnect storms.
  final int changedAtMs;

  static const DesktopSyncStatus initial = DesktopSyncStatus(
    phase: DesktopSyncPhase.connecting,
    changedAtMs: 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DesktopSyncStatus &&
          other.phase == phase &&
          other.changedAtMs == changedAtMs);

  @override
  int get hashCode => Object.hash(phase, changedAtMs);

  @override
  String toString() =>
      'DesktopSyncStatus(phase: $phase, changedAtMs: $changedAtMs)';
}

/// Owns the phase transitions. Construct once from
/// [DesktopProductionApp] (or whatever desktop shell wraps the
/// controller), call [dispose] on shutdown.
class DesktopSyncStatusController extends ChangeNotifier
    implements ValueListenable<DesktopSyncStatus> {
  DesktopSyncStatusController({required AppController controller})
      : this.fromRelay(
          changes: controller.relayConnectionChanges,
          online: controller.relayOnline,
        );

  /// Только то, что классу нужно на самом деле: состояние связи сейчас и поток
  /// его изменений. Отдельный вход существует ради проверок — собрать целый
  /// [AppController] ради двух значений тест не может, а выдержки времени
  /// здесь такие, что проверять их надо обязательно.
  DesktopSyncStatusController.fromRelay({
    required Stream<bool> changes,
    required bool online,
  }) {
    // Seed from whatever the relay reports right now. The stream
    // listener fires for future changes; this primes the initial state
    // so a connection that came up before we subscribed surfaces as
    // `syncing → online` rather than stuck in `connecting`.
    _value = online
        ? DesktopSyncStatus(
            phase: DesktopSyncPhase.syncing,
            changedAtMs: DateTime.now().millisecondsSinceEpoch,
          )
        : DesktopSyncStatus.initial;
    _everConnected = online;
    _scheduleSettleIfNeeded();
    _sub = changes.listen(_onRelayConnChanged);
  }

  /// How long the banner sits in [DesktopSyncPhase.syncing] before
  /// fading to `online`. Picked to roughly cover the worst-case 7-day
  /// mailbox drain on a slow connection — the `_pumpTimer` runs every
  /// 1 s and `pumpInbox` pages 500 entries per HTTP round-trip, so
  /// 3 s is enough headroom for a typical 1–2 page backlog while still
  /// feeling snappy on a cold boot with no missed events.
  static const Duration kSyncSettleDelay = Duration(seconds: 3);

  StreamSubscription<bool>? _sub;
  Timer? _settleTimer;
  Timer? _dropTimer;
  Timer? _offlineTimer;
  DesktopSyncStatus _value = DesktopSyncStatus.initial;
  bool _everConnected = false;

  @override
  DesktopSyncStatus get value => _value;

  /// Manually push the banner back into the "syncing" state — called by
  /// the boot-time eager force-pump kicker in `main_desktop.dart` so the
  /// banner reflects the very-first cold-boot backfill cycle even if the
  /// WS happened to connect before this controller was constructed.
  void markSyncing() {
    _set(DesktopSyncPhase.syncing);
    _scheduleSettleIfNeeded();
  }

  /// 🔴 СКОЛЬКО ЖДАТЬ, ПРЕЖДЕ ЧЕМ СКАЗАТЬ О ПОТЕРЕ СВЯЗИ (26.09.2026, владелец:
  /// «если закрыть приложение и открыть заново, то внизу „соединение“ мигает
  /// вместе с „подключением“»).
  ///
  /// Связь рвётся и восстанавливается чаще, чем об этом стоит рассказывать:
  /// [RelayClient.connect] сам начинает с `disconnect()`, поэтому каждый
  /// повторный заход — это пара «оборвалось / подключилось» за доли секунды.
  /// Замер 14.08.2026 насчитал 33 таких переключения за сеанс. Подпись,
  /// меняющаяся 33 раза, не сообщает ничего — она просто мигает, и мигает
  /// сильнее всего на запуске, когда подключений подряд несколько.
  ///
  /// Поэтому обрыв показывается не сразу: если за это время связь вернулась,
  /// человек не узнает о ней вовсе — и правильно, ему нечего было делать с
  /// этим знанием. Полторы секунды — дольше любого повторного захода и короче
  /// того, что человек считает «задумалось».
  static const Duration kDropGrace = Duration(milliseconds: 1500);

  /// Через сколько молчания «Переподключение…» сменяется на «Нет соединения».
  static const Duration kOfflineAfter = Duration(seconds: 25);

  void _onRelayConnChanged(bool connected) {
    if (connected) {
      _cancelDropTimers();
      _everConnected = true;
      _set(DesktopSyncPhase.syncing);
      _scheduleSettleIfNeeded();
      return;
    }
    // Холодный запуск: мы и так показываем «Подключение…», ждать нечего.
    if (!_everConnected) {
      _cancelSettle();
      _set(DesktopSyncPhase.connecting);
      return;
    }
    // Уже сообщили об обрыве — второй раз не пересчитываем: иначе череда
    // неудачных попыток каждый раз отодвигала бы «Нет соединения».
    if (_value.phase == DesktopSyncPhase.reconnecting ||
        _value.phase == DesktopSyncPhase.offline ||
        _dropTimer != null) {
      return;
    }
    _cancelSettle();
    _dropTimer = Timer(kDropGrace, () {
      _dropTimer = null;
      _set(DesktopSyncPhase.reconnecting);
      _offlineTimer = Timer(kOfflineAfter, () {
        _offlineTimer = null;
        _set(DesktopSyncPhase.offline);
      });
    });
  }

  void _cancelDropTimers() {
    _dropTimer?.cancel();
    _dropTimer = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
  }

  void _set(DesktopSyncPhase next) {
    if (_value.phase == next) return;
    _value = DesktopSyncStatus(
      phase: next,
      changedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  void _scheduleSettleIfNeeded() {
    if (_value.phase != DesktopSyncPhase.syncing) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(kSyncSettleDelay, () {
      _settleTimer = null;
      if (_value.phase == DesktopSyncPhase.syncing) {
        _set(DesktopSyncPhase.online);
      }
    });
  }

  void _cancelSettle() {
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  /// Состояние связи для точки на портрете в рейке. Оба указателя внизу окна
  /// берут его отсюда: пока их считали порознь, они успевали спорить друг с
  /// другом — один говорил «Подключение…», другой уже «Подключено».
  ConnectionStatus get connection => switch (_value.phase) {
        DesktopSyncPhase.syncing || DesktopSyncPhase.online =>
          ConnectionStatus.connected,
        DesktopSyncPhase.connecting || DesktopSyncPhase.reconnecting =>
          ConnectionStatus.connecting,
        DesktopSyncPhase.offline => ConnectionStatus.offline,
      };

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _cancelSettle();
    _cancelDropTimers();
    super.dispose();
  }
}
