// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

/// Server-signed configuration for the in-app Support channel (TZ
/// docs/TZ_SUPPORT_TICKETS_2026-07-24.md), carried in the additive `support`
/// block of `/v1/config`.
///
/// **Failure direction is OFF — like [IdentityFlags], not [ReliabilityFlags].**
/// Support is a NEW feature that needs a real X25519 public key to encrypt
/// tickets to; an unreachable server, an old server without the block, a
/// stripped field, or a forged response all leave [supportEnabled] false and
/// [supportPubB64] empty, so the app hides the new Support page and falls back
/// to the existing e-mail path. Nothing unauthenticated may enable it or inject
/// a support key.
@immutable
class SupportConfig {
  const SupportConfig({
    this.supportEnabled = false,
    this.supportPubB64 = '',
  });

  /// The dormant state: used whenever the server said nothing we could verify.
  static const SupportConfig defaults = SupportConfig();

  /// Whether the in-app Support ticket flow is active.
  final bool supportEnabled;

  /// Base64 of the SUPPORT X25519 public key (32 bytes) that tickets are sealed
  /// to; its private key lives only in the admin console. Empty ⇒ nothing to
  /// encrypt to ⇒ the Support page stays off.
  final String supportPubB64;

  /// True only when the feature is on AND we actually have a key to seal to.
  bool get isUsable => supportEnabled && supportPubB64.isNotEmpty;

  /// Reads the config out of a `/v1/config` response. [verified] must be the
  /// result of `verifySupportSignature`; when false this returns [defaults].
  static SupportConfig fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['support'];
    if (payload is! Map) return defaults;
    return SupportConfig(
      supportEnabled: payload['support_enabled'] == true,
      supportPubB64: (payload['support_pub_b64'] as String?)?.trim() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportConfig &&
          other.supportEnabled == supportEnabled &&
          other.supportPubB64 == supportPubB64;

  @override
  int get hashCode => Object.hash(supportEnabled, supportPubB64);

  @override
  String toString() =>
      'SupportConfig(enabled: $supportEnabled, hasKey: ${supportPubB64.isNotEmpty})';
}
