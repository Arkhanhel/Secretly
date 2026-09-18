// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// The local symmetric fallback must not decide the fate of a peer's wire
/// (2026-07-31, field: 317 discards on one device within minutes).
///
/// Inbound decrypt tries three decryptors in turn. The last is the local
/// symmetric fallback, which exists for legacy/self-encrypted wires and can
/// NEVER open a peer's ratchet wire — for peer traffic it always fails with
/// `rust open failed`. That error used to overwrite the ratchet's verdict and
/// be the one thrown, and because it is classified PERMANENT the message was
/// ACKed to the relay and destroyed — even when the ratchet's own reason was
/// transient and would have healed on the next session re-establish.
void main() {
  group('the fallback error is permanent — which is why it must not win', () {
    test('`rust open failed` is classified PERMANENT', () {
      // This is what made masking fatal rather than merely confusing.
      expect(
        DeliveredDecryptAckPolicy.isGenuineMacFailure(
          StateError('rust open failed: -1'),
        ),
        isTrue,
      );
    });
  });

  group('the ratchet verdicts that MUST survive the fallback', () {
    // Each of these heals by itself once the session re-establishes, so the
    // wire has to be parked and retried — never acknowledged away.
    const transient = <String>[
      'session not found',
      'no v1.3 session',
      'message key not found',
      'missing recv chain key',
      'missing remote dh pub',
      'too many skipped messages',
    ];

    for (final reason in transient) {
      test('"$reason" is TRANSIENT, so the wire is kept', () {
        final e = StateError(reason);
        expect(
          DeliveredDecryptAckPolicy.isTransientDecryptError(e),
          isTrue,
          reason: '$reason heals on its own and must not be acked away',
        );
        expect(
          DeliveredDecryptAckPolicy.isGenuineMacFailure(e),
          isFalse,
          reason: 'a transient flavour must never read as permanent',
        );
      });
    }

    test(
      'REGRESSION: a transient ratchet reason and the fallback error classify '
      'OPPOSITELY — masking one with the other loses the message',
      () {
        final real = StateError('session not found');
        final fallback = StateError('rust open failed: -1');

        // Keep the ratchet's verdict → parked, retried, recovered.
        expect(DeliveredDecryptAckPolicy.isGenuineMacFailure(real), isFalse);
        // Let the fallback win → acked, discarded, gone for good.
        expect(DeliveredDecryptAckPolicy.isGenuineMacFailure(fallback), isTrue);
      },
    );
  });

  group('genuinely unopenable wires stay permanent', () {
    // The fix must not turn real corruption into an endless replay.
    const permanent = <String>[
      'SecretBoxAuthenticationError',
      'invalid mac',
      'aeadbadtag',
      'ciphertext too short',
      'invalid wire format',
    ];

    for (final reason in permanent) {
      test('"$reason" is still PERMANENT', () {
        expect(
          DeliveredDecryptAckPolicy.isGenuineMacFailure(StateError(reason)),
          isTrue,
        );
      });
    }
  });
}
