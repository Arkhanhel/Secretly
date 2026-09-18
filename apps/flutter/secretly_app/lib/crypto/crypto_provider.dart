// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
abstract class CryptoProvider {
  Future<List<int>> encrypt(List<int> plaintext);
  Future<List<int>> decrypt(List<int> ciphertext);
}
