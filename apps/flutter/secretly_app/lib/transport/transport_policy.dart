// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
class TransportPolicyResult {
  const TransportPolicyResult({required this.allowed, this.warning});

  final bool allowed;
  final String? warning;
}

class TransportPolicy {
  const TransportPolicy._();

  static TransportPolicyResult evaluate({
    required Uri keysBaseUrl,
    required Uri relayHttpBaseUrl,
    required Uri relayWsUrl,
    required bool isReleaseMode,
    required bool allowInsecureTransport,
  }) {
    final problems = <String>[];

    void check({required String label, required Uri uri, required Set<String> allowedSchemes, required Set<String> secureSchemes}) {
      if (!uri.hasScheme) {
        problems.add('$label URL missing scheme: $uri');
        return;
      }
      if (!allowedSchemes.contains(uri.scheme)) {
        problems.add('$label URL has unsupported scheme "${uri.scheme}": $uri');
        return;
      }

      final isSecure = secureSchemes.contains(uri.scheme);
      if (isSecure) return;

      // Insecure: allow in non-release builds, or when explicitly enabled.
      if (!isReleaseMode || allowInsecureTransport) return;

      // In release builds, allow loopback-only cleartext for adb reverse / local dev.
      if (_isLoopbackHost(uri.host)) return;

      problems.add('$label URL is insecure in release build: $uri');
    }

    check(
      label: 'Keys',
      uri: keysBaseUrl,
      allowedSchemes: const {'http', 'https'},
      secureSchemes: const {'https'},
    );

    check(
      label: 'Relay HTTP',
      uri: relayHttpBaseUrl,
      allowedSchemes: const {'http', 'https'},
      secureSchemes: const {'https'},
    );

    check(
      label: 'Relay WS',
      uri: relayWsUrl,
      allowedSchemes: const {'ws', 'wss'},
      secureSchemes: const {'wss'},
    );

    if (problems.isEmpty) return const TransportPolicyResult(allowed: true);

    final hint = isReleaseMode
        ? 'Use HTTPS/WSS, or (dev-only) pass --dart-define=SECRETLY_ALLOW_INSECURE_TRANSPORT=true.'
        : 'Update URLs to HTTPS/WSS for production hardening.';

    return TransportPolicyResult(
      allowed: false,
      warning: 'Transport policy blocked network startup. ${problems.join(' | ')}. $hint',
    );
  }

  static bool _isLoopbackHost(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) return false;
    if (h == 'localhost' || h == '::1') return true;
    // 127.0.0.0/8
    if (h.startsWith('127.')) return true;
    return false;
  }
}
