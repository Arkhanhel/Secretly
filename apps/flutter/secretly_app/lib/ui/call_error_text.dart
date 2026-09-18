// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../app/contact_action_failure.dart';
import '../calls/call_failure.dart';
import '../l10n/app_localizations.dart';
import 'contact_action_error_text.dart';

String callErrorText(AppLocalizations l10n, Object error) {
  if (error is ContactActionFailure) {
    return contactActionErrorText(l10n, error);
  }

  final failure = describeCallFailure(error);
  switch (failure.code) {
    case CallFailureCode.serviceUnavailable:
      return l10n.callServiceUnavailable;
    case CallFailureCode.alreadyInProgress:
      return l10n.callAlreadyInProgress;
    case CallFailureCode.iceConfigUnavailable:
      return l10n.callIceUnavailable;
    case CallFailureCode.permissionDenied:
      return l10n.callPermissionDenied;
    case CallFailureCode.invalidRemoteOffer:
    case CallFailureCode.invalidRemoteAnswer:
    case CallFailureCode.localOfferUnavailable:
    case CallFailureCode.signalingConflict:
      return l10n.callNegotiationFailed;
    case CallFailureCode.connectionInterrupted:
      return l10n.callConnectionInterrupted;
    case CallFailureCode.generic:
      return l10n.callActionGeneric;
  }
}