// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../attachments/attachment_failure.dart';
import '../l10n/app_localizations.dart';
import 'room_policy_error_text.dart';

String attachmentErrorText(AppLocalizations l10n, Object error) {
  final roomPolicyText = tryRoomPolicyErrorText(l10n, error);
  if (roomPolicyText != null) {
    return roomPolicyText;
  }

  final failure = describeAttachmentFailure(error);
  switch (failure.code) {
    case AttachmentFailureCode.fileMissing:
      return l10n.attachmentFileMissing;
    case AttachmentFailureCode.tooLarge:
      final bytes = failure.bytes ?? parseAttachmentFailureBytes(error);
      final mb = bytes == null ? 0 : (bytes / (1024 * 1024)).round();
      return l10n.attachmentTooLarge(mb);
    case AttachmentFailureCode.uploadCanceled:
      return l10n.uploadCanceled;
    case AttachmentFailureCode.uploadTimedOut:
      return l10n.uploadTimedOut;
    case AttachmentFailureCode.finalizeTimedOut:
      return l10n.attachmentFinalizeTimeout;
    case AttachmentFailureCode.transportBlocked:
      return l10n.contactActionTransportBlocked;
    case AttachmentFailureCode.serviceUnavailable:
      return l10n.attachmentTransferUnavailable;
    case AttachmentFailureCode.localUnavailable:
    case AttachmentFailureCode.transportUnavailable:
      return l10n.attachmentSendUnavailable;
    case AttachmentFailureCode.contactSyncPending:
      return l10n.attachmentContactSyncPending;
    case AttachmentFailureCode.contactBlocked:
      return l10n.attachmentContactBlocked;
    case AttachmentFailureCode.recipientProfileNotFound:
      return l10n.attachmentRecipientNotFound;
    case AttachmentFailureCode.recipientNoDevices:
      return l10n.attachmentRecipientNoDevices;
    case AttachmentFailureCode.contactUnverified:
      return l10n.contactNotVerified;
    case AttachmentFailureCode.noDeliverableTargetDevices:
      return l10n.attachmentNoDeliverableDevices;
    case AttachmentFailureCode.generic:
      return l10n.attachmentActionGeneric;
  }
}