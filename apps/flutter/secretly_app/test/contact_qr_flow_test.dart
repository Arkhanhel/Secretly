// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/contact_qr_flow.dart';

void main() {
  group('qrMatchesKeysServer', () {
    test('accepts empty values and rejects hostless mismatches', () {
      final appKeysBaseUrl = Uri.parse('https://keys.example.com');

      expect(qrMatchesKeysServer('', appKeysBaseUrl), isTrue);
      expect(qrMatchesKeysServer('not a valid uri', appKeysBaseUrl), isFalse);
    });

    test('matches only the same scheme host and effective port', () {
      final appKeysBaseUrl = Uri.parse('https://keys.example.com');

      expect(
        qrMatchesKeysServer('https://keys.example.com', appKeysBaseUrl),
        isTrue,
      );
      expect(
        qrMatchesKeysServer('https://keys.example.com:443', appKeysBaseUrl),
        isTrue,
      );
      expect(
        qrMatchesKeysServer('http://keys.example.com', appKeysBaseUrl),
        isFalse,
      );
      expect(
        qrMatchesKeysServer('https://keys.example.com:444', appKeysBaseUrl),
        isFalse,
      );
      expect(
        qrMatchesKeysServer('https://other.example.com', appKeysBaseUrl),
        isFalse,
      );
    });
  });
}