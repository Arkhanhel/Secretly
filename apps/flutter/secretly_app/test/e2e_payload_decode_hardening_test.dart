// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';

List<int> _encode(Map<String, Object?> map) => utf8.encode(jsonEncode(map));

void main() {
  group('E2ePayloadV1.decode hardening (defensive peer-input parsing)', () {
    test('valid payload decodes normally', () {
      final bytes = _encode({
        'v': 1,
        'sender_device_id': 'dev:abc',
        'created_at_ms': 123,
        'events': [
          {'type': 'msg', 'event_id': 'e1', 'text': 'hi'},
        ],
      });
      final payload = E2ePayloadV1.decode(bytes);
      expect(payload.senderDeviceId, 'dev:abc');
      expect(payload.createdAtMs, 123);
      expect(payload.events, hasLength(1));
      expect(payload.events.single, isA<MsgEventV1>());
    });

    test('a single malformed event is skipped, the rest are kept', () {
      final bytes = _encode({
        'v': 1,
        'sender_device_id': 'dev:abc',
        'created_at_ms': 1,
        'events': [
          {'type': 'msg', 'event_id': 'e1', 'text': 'good'},
          // Missing required event_id/text → must NOT drop the whole payload.
          {'type': 'msg'},
          {'type': 'msg', 'event_id': 'e2', 'text': 'also good'},
        ],
      });
      final payload = E2ePayloadV1.decode(bytes);
      expect(payload.events, hasLength(2));
      expect(
        payload.events.whereType<MsgEventV1>().map((e) => e.eventId),
        containsAll(<String>['e1', 'e2']),
      );
    });

    test('non-map / null event entries are ignored', () {
      final bytes = _encode({
        'v': 1,
        'sender_device_id': 'dev:abc',
        'created_at_ms': 1,
        'events': [
          null,
          'garbage',
          42,
          {'type': 'msg', 'event_id': 'e1', 'text': 'hi'},
        ],
      });
      final payload = E2ePayloadV1.decode(bytes);
      expect(payload.events, hasLength(1));
    });

    test('missing sender/created/events fields do not throw', () {
      final bytes = _encode({'v': 1});
      final payload = E2ePayloadV1.decode(bytes);
      expect(payload.senderDeviceId, '');
      expect(payload.createdAtMs, 0);
      expect(payload.events, isEmpty);
    });

    test('wrong-typed created_at_ms falls back instead of throwing', () {
      final bytes = _encode({
        'v': 1,
        'sender_device_id': 'dev:abc',
        'created_at_ms': 'not-a-number',
        'events': [
          {'type': 'msg', 'event_id': 'e1', 'text': 'hi'},
        ],
      });
      final payload = E2ePayloadV1.decode(bytes);
      expect(payload.createdAtMs, 0);
      expect(payload.events, hasLength(1));
    });

    test('genuine non-JSON garbage still throws (so the session-reset path '
        'still fires for a truly bad ciphertext)', () {
      expect(
        () => E2ePayloadV1.decode(utf8.encode('not json at all')),
        throwsA(anything),
      );
    });

    test('unsupported version still throws', () {
      final bytes = _encode({'v': 999, 'events': const []});
      expect(() => E2ePayloadV1.decode(bytes), throwsA(isA<StateError>()));
    });
  });
}
