// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/security/qr_payload.dart';

void main() {
  test('QrPayload parses newline key=value format', () {
    final p = QrPayload.tryParse(
      'secretly_id=ABC-123\n'
      'device_id=dev1\n'
      'identity_key_pub_b64=IKB64\n'
      'nickname=Alice',
    );
    expect(p.secretlyId, 'ABC-123');
    expect(p.deviceId, 'dev1');
    expect(p.identityKeyPubB64, 'IKB64');
    expect(p.nickname, 'Alice');
  });

  test('QrPayload parses ampersand format + aliases', () {
    final p = QrPayload.tryParse('profile_id=PID&deviceid=DID&ik_b64=IK&name=Bob');
    expect(p.secretlyId, 'PID');
    expect(p.deviceId, 'DID');
    expect(p.identityKeyPubB64, 'IK');
    expect(p.nickname, 'Bob');
  });
}
