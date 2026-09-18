// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// AUD-2026-04-25 Sprint A regression tests.
//
// Covers the deterministic, side-effect-free portion of the QR pairing /
// first-message recovery path that was hardened in Sprints A–C:
//
//   1. QR pairing introduction control message round-trip (D1):
//      - canonical encode/parse;
//      - tolerates missing display name and missing token;
//      - URI-decodes safely without throwing on garbled input;
//      - `isQrPairingIntroductionCommandText` does not match other
//        `__secretly_*` control messages (e.g. delete-for-all).
//
//   2. Per-`msg_id` relay send-error classification (D4):
//      - permanent codes never get a retry (`permanent: true`);
//      - transient codes are retryable (`permanent: false`);
//      - unknown codes degrade gracefully into a transient
//        `relay_unavailable` reason;
//      - `blocked` maps to the `recipient_blocked` reason already used
//        elsewhere in the UI.
//
//   3. `CallTargetUnavailableException` (Sprint E C2) is classified by
//      `describeContactActionFailure` into `recipientNoDevices` with the
//      expected user-facing message.
//
// These tests exercise the public API surface only; they do not depend on
// SQLite, WebSockets or platform plugins, so they run in a few hundred ms
// inside the standard `flutter test` harness.

import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/app/app_controller.dart'
    show CallTargetUnavailableException;
import 'package:secretly_app/app/contact_action_failure.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';

void main() {
  group('QR pairing introduction command (Sprint A D1)', () {
    test('round-trips a typical scanner display name and token', () {
      final command = buildQrPairingIntroductionCommand(
        scannerDisplayName: 'Alice (iPhone)',
        qrTokenB64: 'AQID/+8=',
      );

      expect(isQrPairingIntroductionCommandText(command), isTrue);
      expect(isHiddenMessageControlText(command), isTrue);

      final parsed = parseQrPairingIntroductionCommand(command);
      expect(parsed, isNotNull);
      expect(parsed!.scannerDisplayName, 'Alice (iPhone)');
      expect(parsed.qrTokenB64, 'AQID/+8=');
    });

    test('tolerates missing display name and missing token', () {
      final none = buildQrPairingIntroductionCommand();
      final parsedNone = parseQrPairingIntroductionCommand(none);
      expect(parsedNone, isNotNull);
      expect(parsedNone!.scannerDisplayName, isNull);
      expect(parsedNone.qrTokenB64, isNull);

      final nameOnly = buildQrPairingIntroductionCommand(
        scannerDisplayName: 'Bob',
      );
      final parsedNameOnly = parseQrPairingIntroductionCommand(nameOnly);
      expect(parsedNameOnly, isNotNull);
      expect(parsedNameOnly!.scannerDisplayName, 'Bob');
      expect(parsedNameOnly.qrTokenB64, isNull);

      final tokenOnly = buildQrPairingIntroductionCommand(qrTokenB64: 'token');
      final parsedTokenOnly = parseQrPairingIntroductionCommand(tokenOnly);
      expect(parsedTokenOnly, isNotNull);
      expect(parsedTokenOnly!.scannerDisplayName, isNull);
      expect(parsedTokenOnly.qrTokenB64, 'token');
    });

    test('does not match unrelated hidden control messages', () {
      final deleteCmd = buildDeleteForAllCommand(['x', 'y']);
      expect(isQrPairingIntroductionCommandText(deleteCmd), isFalse);
      expect(parseQrPairingIntroductionCommand(deleteCmd), isNull);
    });

    test('returns null for plain text and tolerates garbled body', () {
      expect(parseQrPairingIntroductionCommand('hi'), isNull);

      // Garbled URI-encoded body: parser must not throw and must produce
      // null fields rather than half-populated nonsense.
      final garbled = '__secretly_qr_pair__:%E0%A4|%E0%A4';
      final parsed = parseQrPairingIntroductionCommand(garbled);
      expect(parsed, isNotNull);
      expect(parsed!.scannerDisplayName, isNull);
      expect(parsed.qrTokenB64, isNull);
    });
  });

  group('Relay per-msg_id send-error classification (Sprint A D4)', () {
    test('permanent codes are not retryable', () {
      for (final code in const <String>[
        'bad_request',
        'bad_ciphertext',
        'auth_failed',
        'blocked',
        'unknown_recipient',
      ]) {
        final outcome = MessageFailureReason.classifyRelaySendError(code);
        expect(
          outcome.permanent,
          isTrue,
          reason: 'code=$code must be permanent',
        );
      }
    });

    test('transient codes are retryable', () {
      for (final code in const <String>['over_capacity', 'store_error']) {
        final outcome = MessageFailureReason.classifyRelaySendError(code);
        expect(
          outcome.permanent,
          isFalse,
          reason: 'code=$code must be transient/retryable',
        );
      }
    });

    test('blocked maps to the shared recipient_blocked reason', () {
      final outcome = MessageFailureReason.classifyRelaySendError('blocked');
      expect(outcome.reason, MessageFailureReason.recipientBlocked);
      expect(outcome.permanent, isTrue);
    });

    test('unknown codes degrade into transient relay_unavailable', () {
      final outcome = MessageFailureReason.classifyRelaySendError(
        'something_brand_new',
      );
      expect(outcome.reason, MessageFailureReason.relayUnavailable);
      expect(outcome.permanent, isFalse);
    });
  });

  group('CallTargetUnavailableException mapping (Sprint E C2)', () {
    test('describeContactActionFailure produces recipientNoDevices', () {
      final failure = describeContactActionFailure(
        const CallTargetUnavailableException(
          peerProfileId: 'peer-123',
          action: 'invite',
        ),
      );

      expect(failure.code, ContactActionFailureCode.recipientNoDevices);
      expect(failure.message, contains('Recipient has no reachable devices'));
    });

    test('classifyContactActionFailure honors the substring fallback', () {
      // Even if some upstream wraps the exception in a String message, the
      // classifier should still recognise the marker phrase.
      final code = classifyContactActionFailure(
        Exception('CallTargetUnavailable(action=offer, peer=p)'),
      );
      expect(code, ContactActionFailureCode.recipientNoDevices);
    });
  });
}
