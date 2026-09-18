// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'crypto_provider.dart';
import 'dart_crypto_provider.dart';
import 'rust_crypto_provider.dart';
import '../security/secure_secrets.dart';

class CryptoFactory {
  /// Builds the local content-encryption provider.
  ///
  /// [allowMint] must be true ONLY when the caller has established that this
  /// install has no encrypted content to lose. It defaults to false so that a
  /// new call site fails safe: the worst case of refusing is "crypto not ready,
  /// retry", while the worst case of minting is the user's local history
  /// becoming permanently unreadable (F-CONTENTKEY, 2026-07-31).
  ///
  /// Throws [ContentKeyUnavailable] when the key exists but cannot be read yet
  /// (locked device, warming keystore). Callers must treat that as a transient
  /// "not ready" — never as "there is no key".
  static Future<CryptoProvider> create({bool allowMint = false}) async {
    // v0.5: key material stored in OS keystore.
    // TODO: replace with per-session keys + ratchet state machine.
    final secrets = SecureSecrets.create();
    final key = await secrets.getOrCreateCryptoKey(allowMint: allowMint);
    return fromKey(key);
  }

  /// Builds a provider around a key the caller already read.
  ///
  /// Exists so that read-only paths (the background decrypt pass) can obtain a
  /// provider WITHOUT going anywhere near the get-or-create logic.
  static CryptoProvider fromKey(Uint8List key) {
    if (Platform.isAndroid || Platform.isWindows) {
      final rust = RustCryptoProvider.tryCreate(key);
      if (rust != null) return rust;
    }

    return DartCryptoProvider(key);
  }
}
