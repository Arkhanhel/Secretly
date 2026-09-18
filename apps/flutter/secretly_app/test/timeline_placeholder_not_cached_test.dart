// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';

/// F-CONTENTKEY-4 — a failed decrypt must never be remembered as a result.
///
/// The timeline caches each resolved row under a key built from the event id
/// and a tail slice of its ciphertext. Neither changes when the crypto provider
/// finally becomes available, and eviction only happens when the event leaves
/// the live set — so a placeholder written into that cache stays for the whole
/// screen session.
///
/// That is what turned a one-second hiccup into "my messages turned into '…'":
/// the amplifier, not the cause (the cause was the content key being re-minted,
/// F-CONTENTKEY-1). The rule pinned here is simply: cache successes, retry
/// failures.
void main() {
  /// The predicate the timeline uses, mirrored exactly
  /// (`chat_screen.dart:_isUnresolvedPlaceholderText`). Kept as a local copy
  /// because the widget's State is private; the assertions below are about the
  /// RULE, and this states it in one place.
  bool isUnresolved(E2eEventV1? payload, String text) =>
      payload == null && text.trim() == '…';

  group('what counts as an unresolved row', () {
    test('no payload and the ellipsis placeholder is unresolved', () {
      expect(isUnresolved(null, '…'), isTrue);
      // Padding must not hide it — the timeline trims before comparing.
      expect(isUnresolved(null, ' … '), isTrue);
    });

    test('a real message that merely LOOKS like the placeholder is resolved',
        () {
      // Somebody genuinely sending "…" must still be cached and shown. The
      // payload is what distinguishes a message from a failure.
      final payload = MsgEventV1(eventId: 'e1', text: '…');
      expect(isUnresolved(payload, '…'), isFalse);
    });

    test('an empty or ordinary text with no payload is NOT the placeholder',
        () {
      // Only the exact placeholder is treated as a failure, so unrelated empty
      // rows keep their existing caching behaviour.
      expect(isUnresolved(null, ''), isFalse);
      expect(isUnresolved(null, 'hello'), isFalse);
    });
  });

  group('the caching rule', () {
    // A minimal stand-in for the cache the timeline keeps, so the rule can be
    // exercised end to end: write only when the row resolved.
    final cache = <String, String>{};
    void resolveInto(String id, E2eEventV1? payload, String text) {
      if (!isUnresolved(payload, text)) cache[id] = text;
    }

    setUp(cache.clear);

    test('REGRESSION: a placeholder is not remembered, so the next rebuild '
        'retries and shows the real text', () {
      // First pass: crypto is not ready.
      resolveInto('evt-1', null, '…');
      expect(cache.containsKey('evt-1'), isFalse);

      // Second pass, moments later: the key is readable and the row resolves.
      resolveInto('evt-1', MsgEventV1(eventId: 'evt-1', text: 'привет'), 'привет');
      expect(cache['evt-1'], 'привет');
    });

    test('a resolved row IS remembered — the cache still does its job', () {
      // The fix must not turn the cache off: re-decrypting every row on every
      // rebuild is what the cache exists to prevent.
      resolveInto('evt-2', MsgEventV1(eventId: 'evt-2', text: 'hi'), 'hi');
      expect(cache['evt-2'], 'hi');
    });

    test('a failure never overwrites a good cached value', () {
      resolveInto('evt-3', MsgEventV1(eventId: 'evt-3', text: 'hi'), 'hi');
      // A later pass fails transiently. The already-good text must survive.
      resolveInto('evt-3', null, '…');
      expect(cache['evt-3'], 'hi');
    });
  });
}
