// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/secure_secrets.dart';

/// REGRESSION (2026-07-20): a tester opened the app to an empty account — no
/// chats, no messages, no contacts — while the real 12.5 MB encrypted database
/// was still sitting on the device.
///
/// The cause was a classification bug, not a crypto bug. iOS answers a keychain
/// read on a locked device (or before the first unlock — e.g. a push-woken
/// launch) with "no such item" rather than an error. The app read that as "the
/// key is gone forever", quarantined the live database and issued a fresh
/// passphrase, which permanently stranded the old data.
///
/// The invariant these tests pin: **a database on disk proves a key existed, so
/// an empty read is TRANSIENT and must never authorise a re-key.**
const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> stored;
  late List<String> methodCalls;

  /// Installs a keychain stub. [readReturns] overrides what `read` answers so a
  /// test can simulate the locked-device "present but invisible" case.
  void installKeychain({
    Object? Function(String key)? readReturns,
    Object Function()? throwOnRead,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
          methodCalls.add(call.method);
          final arguments = Map<Object?, Object?>.from(
            call.arguments as Map<Object?, Object?>? ?? const {},
          );
          final key = arguments['key'] as String?;
          switch (call.method) {
            case 'read':
              if (throwOnRead != null) throw throwOnRead();
              if (key == null) return null;
              return readReturns != null ? readReturns(key) : stored[key];
            case 'write':
              if (key != null) {
                stored[key] = (arguments['value'] as String?) ?? '';
              }
              return null;
            case 'delete':
              if (key != null) stored.remove(key);
              return null;
            default:
              return null;
          }
        });
  }

  setUp(() {
    stored = <String, String>{};
    methodCalls = <String>[];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  test(
    'locked device (read answers empty) is TRANSIENT — never re-keys',
    () async {
      // The key is really there; the locked keychain just will not show it.
      stored['secretly/db_passphrase_v1'] = 'the-real-passphrase';
      installKeychain(readReturns: (_) => null);

      await expectLater(
        SecureSecrets.create().requireExistingDbPassphrase(),
        // NOT DbPassphraseLost: that verdict is what authorises quarantine and
        // a fresh passphrase, i.e. the data loss.
        throwsA(isA<DbPassphraseUnavailable>()),
      );

      // The decisive assertion: nothing was overwritten or removed, so the real
      // passphrase still opens the real database on the next (unlocked) launch.
      expect(methodCalls, isNot(contains('write')));
      expect(methodCalls, isNot(contains('delete')));
      expect(stored['secretly/db_passphrase_v1'], 'the-real-passphrase');
    },
  );

  test('a readable passphrase is returned untouched', () async {
    stored['secretly/db_passphrase_v1'] = 'the-real-passphrase';
    installKeychain();

    expect(
      await SecureSecrets.create().requireExistingDbPassphrase(),
      'the-real-passphrase',
    );
    expect(methodCalls, isNot(contains('write')));
    expect(methodCalls, isNot(contains('delete')));
  });

  test('a failing keychain read is transient too, and retried', () async {
    installKeychain(
      throwOnRead: () => PlatformException(code: 'Unexpected security error'),
    );

    await expectLater(
      SecureSecrets.create().requireExistingDbPassphrase(),
      throwsA(isA<DbPassphraseUnavailable>()),
    );
    // Retried rather than giving up on the first failure.
    expect(methodCalls.where((m) => m == 'read').length, greaterThan(1));
    expect(methodCalls, isNot(contains('write')));
    expect(methodCalls, isNot(contains('delete')));
  });

  test(
    'genuine keystore invalidation is the ONLY permanent verdict',
    () async {
      // Android reports an invalidated wrapping key like this; the blob really
      // is unrecoverable, so starting over is correct here.
      installKeychain(
        throwOnRead: () => PlatformException(
          code: 'Unexpected security error',
          message: 'javax.crypto.AEADBadTagException',
        ),
      );

      await expectLater(
        SecureSecrets.create().requireExistingDbPassphrase(),
        throwsA(isA<DbPassphraseLost>()),
      );
    },
  );

  test('a fresh install still mints a passphrase', () async {
    installKeychain(); // empty store, nothing on disk yet
    final pass = await SecureSecrets.create().getOrCreateDbPassphrase();

    expect(pass, isNotEmpty);
    expect(stored['secretly/db_passphrase_v1'], pass);
  });
}
