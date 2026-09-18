// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

enum CallFailureCode {
  serviceUnavailable,
  alreadyInProgress,
  iceConfigUnavailable,
  permissionDenied,
  invalidRemoteOffer,
  invalidRemoteAnswer,
  localOfferUnavailable,
  signalingConflict,
  connectionInterrupted,
  generic,
}

CallFailureCode? parseCallFailureCode(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  for (final value in CallFailureCode.values) {
    if (value.name == text) {
      return value;
    }
  }
  return null;
}

class CallFailure implements Exception {
  CallFailure(
    this.code, {
    this.cause,
    String? message,
  }) : message = message ?? _defaultCallFailureMessage(code);

  final CallFailureCode code;
  final Object? cause;
  final String message;

  @override
  String toString() => message;
}

CallFailure describeCallFailure(
  Object error, {
  CallFailureCode fallbackCode = CallFailureCode.generic,
  String? fallbackMessage,
}) {
  if (error is CallFailure) {
    return error;
  }
  final code = classifyCallFailure(error, fallbackCode: fallbackCode);
  return CallFailure(code, cause: error, message: fallbackMessage);
}

CallFailureCode classifyCallFailure(
  Object error, {
  CallFailureCode fallbackCode = CallFailureCode.generic,
}) {
  if (error is CallFailure) {
    return error.code;
  }
  if (error is TimeoutException ||
      error is SocketException ||
      error is HandshakeException ||
      error is HttpException) {
    return CallFailureCode.connectionInterrupted;
  }

  final message = error.toString().toLowerCase();
  if (message.contains('call service unavailable')) {
    return CallFailureCode.serviceUnavailable;
  }
  if (message.contains('already in a call')) {
    return CallFailureCode.alreadyInProgress;
  }
  if (message.contains('call ice config is empty') ||
      message.contains(
        'relay_only policy active but no usable turn servers are available',
      )) {
    return CallFailureCode.iceConfigUnavailable;
  }
  if (_looksLikePermissionDenied(message)) {
    return CallFailureCode.permissionDenied;
  }
  if (message.contains('incoming answer sdp is invalid')) {
    return CallFailureCode.invalidRemoteAnswer;
  }
  if (message.contains('incoming sdp is invalid')) {
    return CallFailureCode.invalidRemoteOffer;
  }
  if (message.contains('local offer generation returned empty sdp')) {
    return CallFailureCode.localOfferUnavailable;
  }
  if (message.contains('replacement offer while a local offer is still pending') ||
      message.contains('cannot create local offer in signalingstate=') ||
      message.contains('have-local-offer')) {
    return CallFailureCode.signalingConflict;
  }
  if (_looksLikeConnectionInterrupted(message)) {
    return CallFailureCode.connectionInterrupted;
  }
  return fallbackCode;
}

bool _looksLikePermissionDenied(String message) {
  return message.contains('notallowederror') ||
      message.contains('permission denied') ||
      message.contains('permission blocked') ||
      message.contains('microphone permission') ||
      message.contains('camera permission') ||
      (message.contains('permission') &&
          (message.contains('denied') || message.contains('blocked')));
}

bool _looksLikeConnectionInterrupted(String message) {
  return message.contains('remote video recovery exhausted') ||
      message.contains('rtptransceiver has been disposed') ||
      message.contains('rtcrtpsender has been disposed') ||
      message.contains('rtpsender has been disposed') ||
      message.contains('rtcpeerconnection is closed') ||
      message.contains('connection closed') ||
      message.contains('connection lost') ||
      (message.contains('transport') &&
          (message.contains('failed') || message.contains('disconnected'))) ||
      message.contains('timeoutexception') ||
      message.contains('timed out');
}

String _defaultCallFailureMessage(CallFailureCode code) {
  switch (code) {
    case CallFailureCode.serviceUnavailable:
      return 'Call service is unavailable right now.';
    case CallFailureCode.alreadyInProgress:
      return 'Another call is already in progress.';
    case CallFailureCode.iceConfigUnavailable:
      return 'Secure call setup is unavailable right now. Try again in a moment.';
    case CallFailureCode.permissionDenied:
      return 'Microphone or camera access is blocked. Allow permissions and try again.';
    case CallFailureCode.invalidRemoteOffer:
    case CallFailureCode.invalidRemoteAnswer:
    case CallFailureCode.localOfferUnavailable:
    case CallFailureCode.signalingConflict:
      return 'Could not establish the secure call. Try again.';
    case CallFailureCode.connectionInterrupted:
      return 'Call connection was interrupted. Try again.';
    case CallFailureCode.generic:
      return 'Could not start the call. Try again.';
  }
}