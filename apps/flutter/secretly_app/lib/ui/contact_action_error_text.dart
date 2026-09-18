// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../app/contact_action_failure.dart';
import '../l10n/app_localizations.dart';

String contactActionErrorText(
  AppLocalizations l10n,
  Object error, {
  ContactActionFailureCode fallbackCode = ContactActionFailureCode.generic,
}) {
  final failure = describeContactActionFailure(
    error,
    fallbackCode: fallbackCode,
  );
  if (failure.hasCustomMessage) {
    return failure.message;
  }
  switch (failure.code) {
    case ContactActionFailureCode.profileNotFound:
      return l10n.contactActionProfileNotFound;
    case ContactActionFailureCode.recipientNoDevices:
      return failure.message;
    case ContactActionFailureCode.transportBlocked:
      return l10n.contactActionTransportBlocked;
    case ContactActionFailureCode.serviceUnavailable:
      return l10n.contactActionServiceUnavailable;
    case ContactActionFailureCode.callsDisabledGlobally:
      return l10n.contactActionCallsDisabled;
    case ContactActionFailureCode.callsDisabledForContact:
      return l10n.contactActionCallsDisabledForContact;
    case ContactActionFailureCode.generic:
      return l10n.contactActionGeneric;
  }
}

String contactLookupErrorText(AppLocalizations l10n, Object error) {
  final failure = describeContactActionFailure(error);
  if (failure.hasCustomMessage) {
    return failure.message;
  }
  if (failure.code == ContactActionFailureCode.generic) {
    return l10n.contactLookupUnavailable;
  }
  return contactActionErrorText(l10n, failure);
}
