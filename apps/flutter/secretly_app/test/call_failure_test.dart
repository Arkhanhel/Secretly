// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/contact_action_failure.dart';
import 'package:secretly_app/calls/call_failure.dart';
import 'package:secretly_app/l10n/app_localizations_en.dart';
import 'package:secretly_app/ui/call_error_text.dart';

void main() {
  test('describeCallFailure classifies call setup errors', () {
    expect(
      describeCallFailure(
        StateError('call ICE config is empty; relay STUN/TURN is not configured'),
      ).code,
      CallFailureCode.iceConfigUnavailable,
    );
    expect(
      describeCallFailure(
        StateError('Incoming ANSWER SDP is invalid (missing v= line)'),
      ).code,
      CallFailureCode.invalidRemoteAnswer,
    );
    expect(
      describeCallFailure(
        StateError('Cannot create local offer in signalingState=have-local-offer'),
      ).code,
      CallFailureCode.signalingConflict,
    );
    expect(
      describeCallFailure(TimeoutException('call timeout')).code,
      CallFailureCode.connectionInterrupted,
    );
  });

  test('describeCallFailure classifies permission-denied errors', () {
    expect(
      describeCallFailure(StateError('NotAllowedError: Permission denied')).code,
      CallFailureCode.permissionDenied,
    );
  });

  test('callErrorText localizes typed call failures', () {
    final l10n = AppLocalizationsEn();

    expect(
      callErrorText(l10n, CallFailure(CallFailureCode.permissionDenied)),
      'Microphone or camera access is blocked. Allow permissions and try again.',
    );
    expect(
      callErrorText(l10n, CallFailure(CallFailureCode.iceConfigUnavailable)),
      'Secure call setup is unavailable right now. Try again in a moment.',
    );
    expect(
      callErrorText(l10n, CallFailure(CallFailureCode.connectionInterrupted)),
      'Call connection was interrupted. Try again.',
    );
  });

  test('callErrorText preserves contact-action invite failures', () {
    final l10n = AppLocalizationsEn();

    expect(
      callErrorText(
        l10n,
        ContactActionFailure(ContactActionFailureCode.callsDisabledForContact),
      ),
      l10n.contactActionCallsDisabledForContact,
    );
  });
}