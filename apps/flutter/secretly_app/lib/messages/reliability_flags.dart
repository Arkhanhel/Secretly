// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

/// Server-controlled kill-switches for the self-healing delivery machinery
/// (TZ_RELIABLE_DELIVERY_E2E_RECEIPTS §12), carried in the signed `reliability`
/// block of `/v1/config`.
///
/// Why this exists: the client-side switches (`_nackReceiptsEnabled`,
/// `_senderConvergenceBackstopEnabled`) are compile-time defaults, so stopping
/// a misbehaving heuristic used to mean shipping a build and waiting on an App
/// Store review. We have already had one live incident of that shape (the
/// 2026-07-18 rekey/resend storm), so the lever needs to be reachable in
/// minutes.
///
/// **Failure direction is ON.** Both flags default to true and are only ever
/// turned off by a block whose Ed25519 signature verified. An unreachable
/// server, a stripped field, a forged response or an old server that does not
/// send the block at all all leave the machinery running. This is deliberately
/// the opposite of billing (which fails OPEN): this machinery is the safety net
/// against silent message loss, and nothing unauthenticated may disable it.
@immutable
class ReliabilityFlags {
  const ReliabilityFlags({
    this.nackReceiptsEnabled = true,
    this.convergenceResendEnabled = true,
  });

  /// The safe state: every net engaged. Used whenever the server said nothing
  /// we could authenticate.
  static const ReliabilityFlags defaults = ReliabilityFlags();

  /// Gates emitting and consuming `nack_undecryptable` receipts (Epic A).
  final bool nackReceiptsEnabled;

  /// Gates the sender-convergence resend backstop (heuristic re-key + resend
  /// when relay-ACKed messages never earn an end-to-end `delivered`).
  final bool convergenceResendEnabled;

  /// Reads the flags out of a `/v1/config` response.
  ///
  /// [verified] must be the result of `verifyReliabilitySignature` — when it is
  /// false (no key baked in, missing/garbage signature, forged block) this
  /// returns [defaults] and the caller keeps healing.
  static ReliabilityFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['reliability'];
    if (payload is! Map) return defaults;
    return ReliabilityFlags(
      nackReceiptsEnabled: payload['nack_receipts_enabled'] == true,
      convergenceResendEnabled: payload['convergence_resend_enabled'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReliabilityFlags &&
          other.nackReceiptsEnabled == nackReceiptsEnabled &&
          other.convergenceResendEnabled == convergenceResendEnabled;

  @override
  int get hashCode => Object.hash(nackReceiptsEnabled, convergenceResendEnabled);

  @override
  String toString() =>
      'ReliabilityFlags(nack: $nackReceiptsEnabled, '
      'convergenceResend: $convergenceResendEnabled)';
}
