// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
class QrPayload {
  const QrPayload({
    required this.secretlyId,
    required this.deviceId,
    required this.identityKeyPubB64,
    required this.nickname,
    required this.keysBaseUrl,
  });

  final String? secretlyId;
  final String? deviceId;
  final String? identityKeyPubB64;
  final String? nickname;
  final String? keysBaseUrl;

  static QrPayload tryParse(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const QrPayload(secretlyId: null, deviceId: null, identityKeyPubB64: null, nickname: null, keysBaseUrl: null);
    }

    // Accept either newline-separated key=value or &-separated.
    final parts = s.split(RegExp(r'[\n&]+'));
    final map = <String, String>{};
    for (final p in parts) {
      final idx = p.indexOf('=');
      if (idx <= 0) continue;
      final k = p.substring(0, idx).trim().toLowerCase();
      final v = p.substring(idx + 1).trim();
      if (k.isEmpty || v.isEmpty) continue;
      map[k] = v;
    }

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    return QrPayload(
      secretlyId: pick(['secretly_id', 'secretlyid', 'profile_id', 'profileid']),
      deviceId: pick(['device_id', 'deviceid']),
      identityKeyPubB64: pick(['identity_key_pub_b64', 'identitykeypubb64', 'ik_b64']),
      nickname: pick(['nickname', 'name', 'display_name', 'displayname']),
      keysBaseUrl: pick(['keys_base_url', 'keysbaseurl', 'server', 'srv']),
    );
  }
}
