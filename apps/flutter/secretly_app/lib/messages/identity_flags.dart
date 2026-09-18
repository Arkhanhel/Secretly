// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

/// Server-signed switch for И-1 rotation-on-state-loss
/// (TZ_I1_IDENTITY_2026-07-21 §Д-5), carried in the additive `identity` block
/// of `/v1/config`.
///
/// **Failure direction is OFF — deliberately the opposite of
/// [ReliabilityFlags].** The reliability switches guard machinery that already
/// shipped, so an unauthenticated absence must leave it running. Rotation on
/// state loss is NEW behaviour with real consequences (peers see a new device,
/// the safety number changes), so it activates only after this client has seen
/// a VERIFIED block that says so. An unreachable server, an old server without
/// the block, a stripped field or a forged response all leave rotation dormant
/// and the client behaves exactly like the previous build.
///
/// The last verified value is cached in prefs by the controller, because the
/// decision point (AppController.init opening the database) runs long before
/// the first /v1/config fetch of the launch.
@immutable
class IdentityFlags {
  const IdentityFlags({this.rotationOnStateLossEnabled = false});

  /// The dormant state: used whenever the server said nothing we could verify.
  static const IdentityFlags defaults = IdentityFlags();

  /// Gates rotating device_id (fresh identity + republish) when a launch
  /// detects the session store was lost while device_id survived.
  final bool rotationOnStateLossEnabled;

  /// Reads the flags out of a `/v1/config` response.
  ///
  /// [verified] must be the result of `verifyIdentitySignature` — when it is
  /// false this returns [defaults] and rotation stays dormant.
  static IdentityFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['identity'];
    if (payload is! Map) return defaults;
    return IdentityFlags(
      rotationOnStateLossEnabled:
          payload['rotation_on_state_loss_enabled'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentityFlags &&
          other.rotationOnStateLossEnabled == rotationOnStateLossEnabled;

  @override
  int get hashCode => rotationOnStateLossEnabled.hashCode;

  @override
  String toString() => 'IdentityFlags(rotation: $rotationOnStateLossEnabled)';
}
