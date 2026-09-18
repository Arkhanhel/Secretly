// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// 🔴 П-5 (Э-0 of docs/TZ_DELIVERY_SIGNAL_MODEL_2026-08-01.md): the convergence
/// backstop must only re-key and re-send toward devices the peer STILL HAS.
///
/// Measured on production 2026-08-01: 298 copies piled into the mailbox of a
/// device the relay had already marked superseded, and fresh copies were still
/// being added three days after that eviction. The backstop targeted whatever
/// sat in the local device cache — which IS pruned, but only on a roster
/// refresh that this 30-second sweep never triggered.
void main() {
  group('convergence targets only live devices', () {
    test('🔴 a device missing from the live roster is NOT targeted', () {
      expect(
        AppController.convergenceShouldTargetDevice(
          deviceId: 'evicted-device',
          liveDeviceIds: {'live-device'},
        ),
        isFalse,
        reason: 'this is the 298-copies-into-a-dead-mailbox case',
      );
    });

    test('a device present in the live roster is targeted', () {
      expect(
        AppController.convergenceShouldTargetDevice(
          deviceId: 'live-device',
          liveDeviceIds: {'live-device', 'other'},
        ),
        isTrue,
      );
    });

    /// 🔴 THE FAILURE DIRECTION, and it is the opposite of the resend budget's.
    ///
    /// An unresolvable roster (offline, rate-limited, keys server down) means we
    /// do not KNOW — and not knowing is not evidence that the peer is gone.
    /// Treating it as "nobody is live" would silently withhold the heal that
    /// fixes a one-way break, turning a transient lookup failure into a
    /// permanent broken conversation. The Э-0 lifetime cap is what bounds the
    /// cost of being wrong in this direction; there is no such backstop for
    /// being wrong in the other.
    test('🔴 an UNRESOLVED roster must keep healing, not go silent', () {
      expect(
        AppController.convergenceShouldTargetDevice(
          deviceId: 'some-device',
          liveDeviceIds: null,
        ),
        isTrue,
        reason: 'failing to look up a roster is not proof a peer is gone',
      );
    });

    test('an empty device id is never a target', () {
      expect(
        AppController.convergenceShouldTargetDevice(
          deviceId: '   ',
          liveDeviceIds: null,
        ),
        isFalse,
      );
    });

    test('device ids are compared trimmed', () {
      expect(
        AppController.convergenceShouldTargetDevice(
          deviceId: '  live-device  ',
          liveDeviceIds: {'live-device'},
        ),
        isTrue,
      );
    });
  });
}
