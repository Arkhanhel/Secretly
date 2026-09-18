// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

/// И-1 field fix (2026-07-21): a rotated peer arrives as a NEW device_id, not
/// as an identity change under the old id — the 2026-07-21 restore test showed
/// the "safety number changed" notice never fired for it. The upsert now
/// reports BOTH signals so the caller can raise the notice for "known contact
/// grew a device we have never seen" while first discovery stays silent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('upsert distinguishes first-insert, re-upsert and identity rotation',
      () async {
    final db = await AppDb.openForTesting();

    // First ever device row for the contact — an insert, not a rotation.
    final first = await db.contactDeviceUpsert(
      profileId: 'peer-1',
      deviceId: 'dev-a',
      identityKeyPubB64: 'ik-1',
      signedPrekeyPubB64: 'spk-1',
      signedPrekeySigB64: 'sig-1',
    );
    expect(first.insertedNewDevice, isTrue);
    expect(first.identityRotated, isFalse);

    // Same row again, unchanged — neither signal.
    final again = await db.contactDeviceUpsert(
      profileId: 'peer-1',
      deviceId: 'dev-a',
      identityKeyPubB64: 'ik-1',
      signedPrekeyPubB64: 'spk-1',
      signedPrekeySigB64: 'sig-1',
    );
    expect(again.insertedNewDevice, isFalse);
    expect(again.identityRotated, isFalse);

    // И-1 rotation as the peer sees it: a NEW device id appears.
    final rotatedInStyleOfI1 = await db.contactDeviceUpsert(
      profileId: 'peer-1',
      deviceId: 'dev-b',
      identityKeyPubB64: 'ik-2',
      signedPrekeyPubB64: 'spk-2',
      signedPrekeySigB64: 'sig-2',
    );
    expect(rotatedInStyleOfI1.insertedNewDevice, isTrue);
    expect(rotatedInStyleOfI1.identityRotated, isFalse);

    // Classic same-id identity change still reports the rotation signal.
    final classic = await db.contactDeviceUpsert(
      profileId: 'peer-1',
      deviceId: 'dev-a',
      identityKeyPubB64: 'ik-CHANGED',
      signedPrekeyPubB64: 'spk-1',
      signedPrekeySigB64: 'sig-1',
      allowIdentityRotation: true,
    );
    expect(classic.identityRotated, isTrue);
    expect(classic.insertedNewDevice, isFalse);

    await db.close();
  });
}
