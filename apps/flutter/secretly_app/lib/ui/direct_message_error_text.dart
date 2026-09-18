// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../app/contact_action_failure.dart';
import '../l10n/app_localizations.dart';
import 'contact_action_error_text.dart';

String directMessageErrorText(AppLocalizations l10n, Object error) {
  final failure = describeContactActionFailure(error);
  if (failure.hasCustomMessage) {
    return failure.message;
  }
  if (error is ContactActionFailure ||
      failure.code != ContactActionFailureCode.generic) {
    return contactActionErrorText(l10n, failure);
  }
  return l10n.sendFailed(error.toString());
}
