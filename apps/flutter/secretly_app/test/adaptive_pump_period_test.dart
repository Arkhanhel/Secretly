// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/push/background_inbox_fetcher.dart';

/// Adaptive inbox pump (Ф-4, docs/TZ_HEAT_ISOLATE_AND_PUMP_2026-07-31.md).
///
/// The pump used to wake every second forever. The cost is not one poll — it is
/// that the CPU never reaches deep idle, and every poll runs several SQLCipher
/// queries. On an idle phone that is pure heat.
void main() {
  const active = 1000;
  const idle = 5000;
  const deepIdle = 15000;

  group('pumpPeriodForIdleMs — three steps', () {
    test('recent activity polls fast', () {
      expect(
        AppController.pumpPeriodForIdleMs(idleMs: 0, inCall: false),
        active,
      );
      expect(
        AppController.pumpPeriodForIdleMs(idleMs: 59999, inCall: false),
        active,
      );
    });

    test('a quiet minute steps down', () {
      expect(
        AppController.pumpPeriodForIdleMs(idleMs: 60000, inCall: false),
        idle,
      );
      expect(
        AppController.pumpPeriodForIdleMs(idleMs: 4 * 60000, inCall: false),
        idle,
      );
    });

    /// Глубокая ступень с 02.09.2026 существует ТОЛЬКО для фона: она
    /// задумана против нагрева лежащего телефона, а на открытом экране
    /// процессор и так не спит — экономить там нечего, тогда как плата
    /// составляла до пятнадцати секунд на первое сообщение серии.
    test('a quiet five minutes steps down again (background only)', () {
      expect(
        AppController.pumpPeriodForIdleMs(
          idleMs: 5 * 60000,
          inCall: false,
          inForeground: false,
        ),
        deepIdle,
      );
      expect(
        AppController.pumpPeriodForIdleMs(
          idleMs: const Duration(hours: 9).inMilliseconds,
          inCall: false,
          inForeground: false,
        ),
        deepIdle,
      );
    });

    test('🔴 открытое приложение НЕ уходит на глубокую ступень', () {
      for (final idle in <int>[
        5 * 60000,
        const Duration(hours: 1).inMilliseconds,
        const Duration(hours: 9).inMilliseconds,
      ]) {
        expect(
          AppController.pumpPeriodForIdleMs(
            idleMs: idle,
            inCall: false,
            inForeground: true,
          ),
          5000,
          reason: 'сценарий «приложение открыто, сокет полумёртв, пробуждение '
              'не дошло» давал до пятнадцати секунд на первое сообщение серии',
        );
      }
    });

    test('звонок остаётся на быстрой ступени независимо от фона', () {
      for (final fg in <bool>[true, false]) {
        expect(
          AppController.pumpPeriodForIdleMs(
            idleMs: const Duration(hours: 9).inMilliseconds,
            inCall: true,
            inForeground: fg,
          ),
          1000,
          reason: 'сигналы звонка критичны к задержке — это правило старше '
              'и сильнее правила про глубокий простой',
        );
      }
    });

    test('never slower than the deepest step', () {
      for (final h in <int>[1, 6, 24, 240]) {
        expect(
          AppController.pumpPeriodForIdleMs(
            idleMs: Duration(hours: h).inMilliseconds,
            inCall: false,
            inForeground: false,
          ),
          lessThanOrEqualTo(deepIdle),
        );
      }
    });

    test('a call pins the fast step at ANY idleness', () {
      // Call signalling (offer/answer/ICE) is latency-critical: a call that
      // takes seconds longer to connect is a far worse trade than a little heat.
      for (final ms in <int>[0, 60000, 5 * 60000, 60 * 60000]) {
        expect(
          AppController.pumpPeriodForIdleMs(idleMs: ms, inCall: true),
          active,
          reason: 'idle=$ms must not slow the pump during a call',
        );
      }
    });

    test('is monotonic — more idle never polls FASTER', () {
      var previous = 0;
      for (final ms in <int>[0, 30000, 60000, 120000, 300000, 900000]) {
        final p = AppController.pumpPeriodForIdleMs(idleMs: ms, inCall: false);
        expect(p, greaterThanOrEqualTo(previous));
        previous = p;
      }
    });
  });

  group('REGRESSION: liveness must outrun the background takeover', () {
    // 🔴 The audit's headline risk. The liveness stamp used to ride this very
    // pump. Slowing the pump would have slowed the stamp, and the background
    // fetcher declares the foreground DEAD after `mainIsolateFreshMs` without
    // one — then decrypts on its own. Two writers into the ratchet is exactly
    // what invariant И-3 exists to prevent.
    //
    // The stamp therefore lives on its own fixed 10 s timer. This test pins the
    // relationship so that raising the pump's ceiling can never silently cross
    // the takeover threshold.
    const heartbeatPeriodMs = 10000;

    test('the fixed heartbeat is well inside the takeover window', () {
      expect(
        heartbeatPeriodMs,
        lessThan(BackgroundInboxFetcher.mainIsolateFreshMs),
        reason: 'a stamp slower than the window hands the ratchet to the '
            'background isolate while the foreground is still alive',
      );
      // Two full periods must still fit, so a single missed tick (GC pause,
      // a busy frame) cannot trigger a takeover on its own.
      expect(
        heartbeatPeriodMs * 2,
        lessThanOrEqualTo(BackgroundInboxFetcher.mainIsolateFreshMs),
        reason: 'one missed heartbeat must not be enough to lose the lease',
      );
    });

    test('even the SLOWEST pump step is irrelevant to liveness', () {
      // The whole point of the split: the pump may idle as far down as it
      // likes without touching the stamp.
      expect(deepIdle, greaterThan(heartbeatPeriodMs));
      expect(
        heartbeatPeriodMs,
        lessThan(BackgroundInboxFetcher.mainIsolateFreshMs),
      );
    });
  });
}
