// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/secure_secrets.dart';

/// F-CONTENTKEY-1/2 — the local content key must never be silently replaced.
///
/// That key encrypts every local display copy: sent messages, the self-mirror,
/// cached received plaintext. Minting a new one makes all of them permanently
/// unreadable and they render as '…'. `getOrCreateCryptoKey` used to DELETE the
/// stored key whenever a read threw anything `_isRecoverableSecureStorageError`
/// matched — a predicate that includes `usernotauthenticated` and a bare
/// `keystore`, i.e. exactly the conditions that mean "try again in a moment" —
/// and then minted a replacement.
///
/// This is the 2026-07-19 database-passphrase loss repeated on another key, so
/// the tests below pin the same invariant the DB passphrase got:
///
///   *A stored ciphertext proves a key existed. "I cannot read the key right
///   now" must NEVER become "make a new key."*
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  /// The one key the app stores content under.
  const cryptoKeyName = 'secretly/crypto_key_v1_b64';

  late Map<String, String> store;
  late List<String> deleted;
  late List<String> written;
  late Object? readThrows;
  late int readCalls;

  void installFakeKeychain() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final key = args['key'] as String? ?? '';
      switch (call.method) {
        case 'read':
          readCalls++;
          if (readThrows != null) throw readThrows!;
          return store[key];
        case 'write':
          written.add(key);
          store[key] = args['value'] as String? ?? '';
          return null;
        case 'delete':
          deleted.add(key);
          store.remove(key);
          return null;
        case 'containsKey':
          return store.containsKey(key);
        default:
          return null;
      }
    });
  }

  setUp(() {
    store = <String, String>{};
    deleted = <String>[];
    written = <String>[];
    readThrows = null;
    readCalls = 0;
    installFakeKeychain();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// A stored key, as an install with real history would have.
  void seedExistingKey() {
    store[cryptoKeyName] = base64Encode(List<int>.filled(32, 7));
  }

  /// The transient conditions. Each one used to trigger a delete + re-mint.
  final transientErrors = <String, PlatformException>{
    'locked device': PlatformException(code: 'UserNotAuthenticated'),
    'warming keystore': PlatformException(
      code: 'Exception',
      message: 'Keystore operation failed',
    ),
    'decrypt hiccup': PlatformException(
      code: 'Exception',
      message: 'Failed to decrypt value',
    ),
  };

  group('a transient read failure NEVER destroys the key', () {
    for (final entry in transientErrors.entries) {
      test('${entry.key}: requireExistingCryptoKey throws, key survives', () async {
        seedExistingKey();
        readThrows = entry.value;

        await expectLater(
          SecureSecrets.create().requireExistingCryptoKey(),
          throwsA(isA<ContentKeyUnavailable>()),
        );

        expect(deleted, isEmpty, reason: 'a transient error must not delete');
        expect(written, isEmpty, reason: 'a transient error must not re-mint');
        expect(store.containsKey(cryptoKeyName), isTrue);
      });

      test('${entry.key}: get-or-create refuses too when there is content',
          () async {
        seedExistingKey();
        readThrows = entry.value;

        // allowMint:false is the default, and is what every caller now passes
        // unless it has PROVEN there is nothing to lose.
        await expectLater(
          SecureSecrets.create().getOrCreateCryptoKey(),
          throwsA(isA<ContentKeyUnavailable>()),
        );

        expect(deleted, isEmpty);
        expect(written, isEmpty);
      });
    }

    test('it RETRIES rather than giving up on the first hiccup', () async {
      seedExistingKey();
      readThrows = transientErrors['locked device'];

      await expectLater(
        SecureSecrets.create().requireExistingCryptoKey(),
        throwsA(isA<ContentKeyUnavailable>()),
      );

      expect(
        readCalls,
        greaterThan(1),
        reason: 'a single glitchy read must not be the final answer',
      );
    });
  });

  group('a null read is NOT proof of absence', () {
    test('REGRESSION: an empty keychain never mints while content may exist',
        () async {
      // On iOS a locked device reports a perfectly good item as MISSING rather
      // than raising. This is the subtler half of the bug: no exception at all,
      // just a silent fall-through into minting.
      await expectLater(
        SecureSecrets.create().requireExistingCryptoKey(),
        throwsA(isA<ContentKeyUnavailable>()),
      );
      expect(written, isEmpty, reason: 'a null read must not mint');
      expect(deleted, isEmpty);
    });
  });

  group('minting is still possible where there is nothing to lose', () {
    test('a fresh install mints exactly once and then reuses', () async {
      final first =
          await SecureSecrets.create().getOrCreateCryptoKey(allowMint: true);
      expect(first, hasLength(32));
      expect(written, hasLength(1));

      final second =
          await SecureSecrets.create().getOrCreateCryptoKey(allowMint: true);
      expect(second, equals(first), reason: 'the second call must not re-mint');
      expect(written, hasLength(1));
    });

    test('an existing key is returned untouched even when minting is allowed',
        () async {
      seedExistingKey();
      final key =
          await SecureSecrets.create().getOrCreateCryptoKey(allowMint: true);
      expect(key, equals(base64Decode(store[cryptoKeyName]!)));
      expect(deleted, isEmpty);
      expect(written, isEmpty);
    });
  });

  group('the background isolate is read-only (F-CONTENTKEY-2)', () {
    test('reads an existing key', () async {
      seedExistingKey();
      final key = await SecureSecrets.create().readCryptoKeyIfExists();
      expect(key, isNotNull);
      expect(key, hasLength(32));
    });

    test('returns null instead of minting when there is none', () async {
      final key = await SecureSecrets.create().readCryptoKeyIfExists();
      expect(key, isNull);
      expect(written, isEmpty, reason: 'a push-woken pass must never mint');
      expect(deleted, isEmpty);
    });

    test('returns null instead of deleting when the read throws', () async {
      seedExistingKey();
      readThrows = transientErrors['locked device'];

      final key = await SecureSecrets.create().readCryptoKeyIfExists();
      expect(key, isNull);
      expect(deleted, isEmpty, reason: 'a background pass must never delete');
      expect(written, isEmpty);
      expect(store.containsKey(cryptoKeyName), isTrue);
    });
  });

  group('the permanent/transient split matches the DB passphrase one', () {
    test('permanent invalidations are exactly the unrecoverable ones', () {
      for (final raw in <String>[
        'BadPaddingException',
        'AEADBadTagException',
        'Failed to unwrap key',
        'InvalidKeyException',
      ]) {
        expect(
          SecureSecrets.isPermanentKeystoreInvalidation(
            PlatformException(code: 'Exception', message: raw),
          ),
          isTrue,
          reason: '$raw is genuinely unrecoverable',
        );
      }
    });

    test('REGRESSION: transient conditions are NOT permanent', () {
      // The old `_isRecoverableSecureStorageError` lumped these in with the
      // list above and then deleted on all of them. That single confusion is
      // the whole bug.
      for (final e in transientErrors.values) {
        expect(
          SecureSecrets.isPermanentKeystoreInvalidation(e),
          isFalse,
          reason: '${e.code}/${e.message} means "retry", not "start over"',
        );
      }
    });
  });
}
