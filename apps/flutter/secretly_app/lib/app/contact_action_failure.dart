// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

enum ContactActionFailureCode {
  profileNotFound,
  recipientNoDevices,
  transportBlocked,
  serviceUnavailable,
  callsDisabledGlobally,
  callsDisabledForContact,
  generic,
}

class ContactActionFailure implements Exception {
  ContactActionFailure(this.code, {this.cause, String? message})
    : message = message ?? _defaultContactActionFailureMessage(code),
      hasCustomMessage = message != null;

  final ContactActionFailureCode code;
  final Object? cause;
  final String message;
  final bool hasCustomMessage;

  @override
  String toString() => message;
}

ContactActionFailure describeContactActionFailure(
  Object error, {
  ContactActionFailureCode fallbackCode = ContactActionFailureCode.generic,
  String? fallbackMessage,
}) {
  if (error is ContactActionFailure) {
    return error;
  }
  final rawMessage = error.toString();
  if (_looksLikePeerIdentityKeyChanged(rawMessage.toLowerCase())) {
    return ContactActionFailure(
      ContactActionFailureCode.generic,
      cause: error,
      message:
          'This contact\'s safety key changed. Verify the new device before continuing.',
    );
  }
  final code = classifyContactActionFailure(error, fallbackCode: fallbackCode);
  return ContactActionFailure(code, cause: error, message: fallbackMessage);
}

ContactActionFailureCode classifyContactActionFailure(
  Object error, {
  ContactActionFailureCode fallbackCode = ContactActionFailureCode.generic,
}) {
  if (error is ContactActionFailure) {
    return error.code;
  }
  if (error is TimeoutException ||
      error is SocketException ||
      error is HandshakeException ||
      error is HttpException) {
    return ContactActionFailureCode.serviceUnavailable;
  }

  final message = error.toString().toLowerCase();
  if (message.contains('no such secretly id') ||
      message.contains('profile not found')) {
    return ContactActionFailureCode.profileNotFound;
  }
  if (message.contains('calltargetunavailable') ||
      message.contains('no target devices') ||
      message.contains('no reachable devices')) {
    return ContactActionFailureCode.recipientNoDevices;
  }
  if (message.contains('transport blocked') ||
      message.contains('different server') ||
      message.contains('server binding mismatch')) {
    return ContactActionFailureCode.transportBlocked;
  }
  if (message.contains('calls are disabled in privacy settings')) {
    return ContactActionFailureCode.callsDisabledGlobally;
  }
  if (message.contains('calls are disabled for this contact')) {
    return ContactActionFailureCode.callsDisabledForContact;
  }
  if (_looksLikeServiceUnavailable(message)) {
    return ContactActionFailureCode.serviceUnavailable;
  }
  return fallbackCode;
}

bool _looksLikeServiceUnavailable(String message) {
  return message.contains('failed host lookup') ||
      message.contains('socketexception') ||
      message.contains('timeoutexception') ||
      message.contains('timed out') ||
      message.contains('connection refused') ||
      message.contains('network is unreachable') ||
      message.contains('connection reset by peer') ||
      message.contains('profileexists failed') ||
      message.contains('searchprofiles failed') ||
      RegExp(r'listdevices failed:\s*5\d\d\b').hasMatch(message) ||
      message.contains('fetchbundle failed') ||
      message.contains('relay blocks set failed') ||
      message.contains('relay blocks list failed');
}

bool _looksLikePeerIdentityKeyChanged(String message) {
  return message.contains('peer identity key changed');
}

String _defaultContactActionFailureMessage(ContactActionFailureCode code) {
  switch (code) {
    case ContactActionFailureCode.profileNotFound:
      return 'Secretly ID was not found on this server.';
    case ContactActionFailureCode.recipientNoDevices:
      return 'Recipient has no reachable devices. Ask the contact to open Secretly and try again.';
    case ContactActionFailureCode.transportBlocked:
      return 'This action is unavailable because the app is bound to a different server.';
    case ContactActionFailureCode.serviceUnavailable:
      return 'Server is unavailable right now. Try again in a moment.';
    case ContactActionFailureCode.callsDisabledGlobally:
      return 'Calls are disabled in Privacy settings.';
    case ContactActionFailureCode.callsDisabledForContact:
      return 'Calls are disabled for this contact.';
    case ContactActionFailureCode.generic:
      return 'Could not complete the action. Try again.';
  }
}
