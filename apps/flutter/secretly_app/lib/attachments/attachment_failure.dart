// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

enum AttachmentFailureCode {
  fileMissing,
  tooLarge,
  uploadCanceled,
  uploadTimedOut,
  finalizeTimedOut,
  transportBlocked,
  serviceUnavailable,
  localUnavailable,
  transportUnavailable,
  contactSyncPending,
  contactBlocked,
  recipientProfileNotFound,
  recipientNoDevices,
  contactUnverified,
  noDeliverableTargetDevices,
  generic,
}

class AttachmentFailure implements Exception {
  AttachmentFailure(
    this.code, {
    this.cause,
    this.bytes,
    String? message,
  }) : message = message ?? _defaultAttachmentFailureMessage(code, bytes: bytes);

  final AttachmentFailureCode code;
  final Object? cause;
  final int? bytes;
  final String message;

  @override
  String toString() => message;
}

AttachmentFailure describeAttachmentFailure(
  Object error, {
  AttachmentFailureCode fallbackCode = AttachmentFailureCode.generic,
  String? fallbackMessage,
}) {
  if (error is AttachmentFailure) {
    return error;
  }
  final code = classifyAttachmentFailure(error, fallbackCode: fallbackCode);
  return AttachmentFailure(
    code,
    cause: error,
    bytes: parseAttachmentFailureBytes(error),
    message: fallbackMessage,
  );
}

AttachmentFailureCode classifyAttachmentFailure(
  Object error, {
  AttachmentFailureCode fallbackCode = AttachmentFailureCode.generic,
}) {
  if (error is AttachmentFailure) {
    return error.code;
  }
  if (error is TimeoutException) {
    return AttachmentFailureCode.uploadTimedOut;
  }
  if (error is SocketException ||
      error is HandshakeException ||
      error is HttpException) {
    return AttachmentFailureCode.serviceUnavailable;
  }

  final message = error.toString().toLowerCase();
  if (message.contains('attach_file_missing')) {
    return AttachmentFailureCode.fileMissing;
  }
  if (message.contains('attach_too_large:')) {
    return AttachmentFailureCode.tooLarge;
  }
  if (message.contains('attach_upload_cancelled')) {
    return AttachmentFailureCode.uploadCanceled;
  }
  if (message.contains('attach_upload_timeout') ||
      message.contains('attach_file_read_timeout')) {
    return AttachmentFailureCode.uploadTimedOut;
  }
  if (message.contains('attach_finalize_timeout') ||
      message.contains('attach_keys_list_timeout')) {
    return AttachmentFailureCode.finalizeTimedOut;
  }
  if (message.contains('transport blocked') ||
      message.contains('different server') ||
      message.contains('server binding mismatch')) {
    return AttachmentFailureCode.transportBlocked;
  }
  if (message.contains('attachment send unavailable: local crypto/db not ready') ||
      message.contains('group attachment send unavailable: local crypto/db not ready')) {
    return AttachmentFailureCode.localUnavailable;
  }
  if (message.contains('attachment send unavailable: transport is not ready')) {
    return AttachmentFailureCode.transportUnavailable;
  }
  if (message.contains('waiting for contact identity sync')) {
    return AttachmentFailureCode.contactSyncPending;
  }
  if (message.contains('contact is blocked')) {
    return AttachmentFailureCode.contactBlocked;
  }
  if (message.contains('recipient profile not found on server')) {
    return AttachmentFailureCode.recipientProfileNotFound;
  }
  if (message.contains('recipient has no registered devices yet')) {
    return AttachmentFailureCode.recipientNoDevices;
  }
  if (message.contains('contact is unverified')) {
    return AttachmentFailureCode.contactUnverified;
  }
  if (message.contains('no deliverable target devices')) {
    return AttachmentFailureCode.noDeliverableTargetDevices;
  }
  if (_looksLikeServiceUnavailable(message)) {
    return AttachmentFailureCode.serviceUnavailable;
  }
  return fallbackCode;
}

int? parseAttachmentFailureBytes(Object error) {
  if (error is AttachmentFailure) {
    return error.bytes;
  }
  final raw = error.toString();
  final marker = 'ATTACH_TOO_LARGE:';
  final idx = raw.indexOf(marker);
  if (idx < 0) return null;
  final tail = raw.substring(idx + marker.length).replaceAll(')', '').trim();
  return int.tryParse(tail);
}

bool _looksLikeServiceUnavailable(String message) {
  return message.contains('blob upload failed') ||
      message.contains('failed host lookup') ||
      message.contains('socketexception') ||
      message.contains('timeoutexception') ||
      message.contains('timed out') ||
      message.contains('connection refused') ||
      message.contains('network is unreachable') ||
      message.contains('connection reset by peer') ||
      message.contains('server is unavailable right now');
}

String _defaultAttachmentFailureMessage(
  AttachmentFailureCode code, {
  int? bytes,
}) {
  switch (code) {
    case AttachmentFailureCode.fileMissing:
      return 'File is not available anymore.';
    case AttachmentFailureCode.tooLarge:
      return bytes == null ? 'Attachment is too large.' : 'Attachment is too large ($bytes bytes).';
    case AttachmentFailureCode.uploadCanceled:
      return 'Upload canceled.';
    case AttachmentFailureCode.uploadTimedOut:
      return 'Upload timed out.';
    case AttachmentFailureCode.finalizeTimedOut:
      return 'Upload finished, but send confirmation timed out.';
    case AttachmentFailureCode.transportBlocked:
      return 'This action is unavailable because the app is bound to a different server.';
    case AttachmentFailureCode.serviceUnavailable:
      return 'Attachment transfer is unavailable right now.';
    case AttachmentFailureCode.localUnavailable:
      return 'Attachment sending is not ready on this device.';
    case AttachmentFailureCode.transportUnavailable:
      return 'Attachment transport is not ready.';
    case AttachmentFailureCode.contactSyncPending:
      return 'Waiting for contact identity sync.';
    case AttachmentFailureCode.contactBlocked:
      return 'Contact is blocked.';
    case AttachmentFailureCode.recipientProfileNotFound:
      return 'Recipient profile was not found on this server.';
    case AttachmentFailureCode.recipientNoDevices:
      return 'Recipient has no registered devices yet.';
    case AttachmentFailureCode.contactUnverified:
      return 'Contact is not verified.';
    case AttachmentFailureCode.noDeliverableTargetDevices:
      return 'Could not deliver the attachment to any recipient device.';
    case AttachmentFailureCode.generic:
      return 'Could not send attachment. Try again.';
  }
}