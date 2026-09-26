// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/security/auth_signer.dart';
import 'package:secretly_app/transport/keys_client.dart';

/// П-5 (ТЗ мультиустройства, 25.09.2026), ПК-часть: отвязанный компьютер
/// узнаёт правду и не обходит отвязку новым номером.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 подписываемая строка самопроверки совпадает с Rust побайтово', () {
    // Та же строка закреплена в Rust: device_self_status_message_is_byte_stable.
    expect(
      utf8.decode(
        AuthSigner.keysDeviceSelfStatusMessage(
          deviceId: 'dev-1',
          tsMs: 42,
          nonceB64: 'bm9uY2U=',
        ),
      ),
      'SECRETLY-KEYS-DEVICE-SELF-STATUS-V1\n'
      'device_id=dev-1\n'
      'ts_ms=42\n'
      'nonce_b64=bm9uY2U=\n',
    );
  });

  test('самопроверка: подписанный GET и разбор ответа', () async {
    late http.Request seen;
    final client = KeysClient(
      baseUrl: Uri.parse('https://keys.example'),
      httpClient: MockClient((req) async {
        seen = req;
        return http.Response(
          jsonEncode({
            'status': 'unlinked',
            'reason': 'inactive',
            'unlinked_at_ms': 1790000000000,
            'now_ms': 1790000001000,
          }),
          200,
        );
      }),
    );
    final s = await client.deviceSelfStatus(
      deviceId: 'dev-1',
      tsMs: 42,
      nonceB64: 'n',
      signatureB64: 'sig',
    );
    expect(seen.method, 'GET');
    expect(seen.url.path, '/v1/device/self_status');
    expect(seen.headers['x-secretly-device-id'], 'dev-1');
    expect(seen.headers['x-secretly-signature-b64'], 'sig');
    expect(s.isUnlinked, isTrue);
    expect(s.reason, 'inactive');
    expect(s.unlinkedAtMs, 1790000000000);
  });

  test('🔴 device_unlinked не ведёт ни к ротации номера, ни к повтору', () {
    // Ротация = новый номер без одобрения телефона = обход отвязки.
    const f = KeysPolicyFailure(
      code: KeysPolicyFailureCode.deviceUnlinked,
      message: 'unlinked',
    );
    expect(f.isRecoverableByDeviceRotation, isFalse);
    expect(f.isTransientRetryable, isFalse);
    final src = File('lib/transport/keys_client.dart').readAsStringSync();
    expect(
      src.contains("case 'device_unlinked':\n      return KeysPolicyFailureCode.deviceUnlinked;"),
      isTrue,
    );
  });

  group('текст для отвязанного компьютера', () {
    test('дата и причина с сервера', () {
      final at = DateTime(2026, 9, 25, 12).millisecondsSinceEpoch;
      final text = AppController.desktopUnlinkedMessage(
        KeysDeviceSelfStatus(
          status: 'unlinked',
          reason: 'inactive',
          unlinkedAtMs: at,
          nowMs: at,
        ),
      );
      expect(text, contains('2026-09-25'));
      expect(text, contains('offline for too long'));
      expect(text, contains('replaced with a copy from the phone'));
      expect(text, isNot(contains('revoked')), reason: 'ложное «отозван»');
    });

    test('без ответа сервера — общий текст без догадок', () {
      final text = AppController.desktopUnlinkedMessage(null);
      expect(text, contains('unlinked'));
      expect(text, isNot(contains('offline for too long')));
      expect(
        AppController.desktopUnlinkedMessage(
          const KeysDeviceSelfStatus(status: 'hidden', nowMs: 1),
        ),
        text,
      );
    });
  });

  group('порядок в исходнике', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();

    test('оба пути регистрации понимают отвязку раньше общего отказа', () {
      final branch = RegExp(
        r'registrationPolicyFailure\.code ==\s*KeysPolicyFailureCode\.deviceUnlinked\)',
      );
      expect(branch.allMatches(src).length, 2);
    });

    test('пульс — только ПК, и гасится при закрытии и в режиме «удалён»', () {
      final start = src.indexOf('void _startDesktopKeysPulse(');
      final body = src.substring(start, start + 400);
      expect(body.contains('if (!_isDesktopOrWebPlatform) return;'), isTrue);
      expect(
        RegExp(r'_desktopKeysPulseTimer\?\.cancel\(\);').allMatches(src).length,
        greaterThanOrEqualTo(4),
      );
    });
  });
}
