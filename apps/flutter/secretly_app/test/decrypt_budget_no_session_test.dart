// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// How long an unopenable wire keeps retrying before we park it and ask the
/// sender to re-handshake.
///
/// 🔴 FIELD (2026-08-01): "a notification arrived but the chat is empty" — and
/// the message showed up TEN MINUTES later. Ten minutes was not a hang: it is
/// the wall-clock decrypt budget. The wire could not be opened, and the client
/// patiently retried for the full budget before parking it and triggering the
/// heal that actually fixes things.
///
/// The patience is correct while a session EXISTS — a heal is a round trip, and
/// tearing sessions down on the first miss is exactly what produced the reset
/// storms of И-4. It is wrong when there is NO session: nothing on this device
/// can ever open that ciphertext until the peer sends a fresh handshake, so
/// every extra second is a person staring at a notification for a message that
/// is not there.
void main() {
  group('the budget splits by whether a session exists at all', () {
    test('no session heals within a minute, not ten', () {
      expect(
        AppController.deliveredDecryptNoSessionFailingForMsForTest,
        lessThanOrEqualTo(60 * 1000),
        reason: 'this is the delay the person actually feels',
      );
    });

    test('a live session keeps the patient budget', () {
      // Shortening this one would re-open И-4: a transient miss (out of order,
      // a DB lock, too many skipped) would tear down a healthy session, both
      // peers would do it to each other, and they would diverge.
      expect(
        AppController.deliveredDecryptMaxFailingForMsForTest,
        greaterThanOrEqualTo(5 * 60 * 1000),
      );
    });

    test('the short budget really is shorter — an order of magnitude', () {
      final short = AppController.deliveredDecryptNoSessionFailingForMsForTest;
      final long = AppController.deliveredDecryptMaxFailingForMsForTest;
      expect(short, lessThan(long));
      expect(
        long / short,
        greaterThanOrEqualTo(5),
        reason: 'if the two converge the split stops being worth its risk',
      );
    });

    test('neither budget is zero — parking instantly is its own bug', () {
      // A zero budget would park on the very first miss, which is a session
      // reset on any transient hiccup: the exact churn И-4 removed.
      expect(
        AppController.deliveredDecryptNoSessionFailingForMsForTest,
        greaterThan(0),
      );
      expect(
        AppController.deliveredDecryptMaxFailingForMsForTest,
        greaterThan(0),
      );
    });
  });
}
