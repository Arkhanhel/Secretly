// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';

// SLOW-DRAIN REGRESSION R9 (2026-07-16, delivery-wake audit): the X3DH bundle
// fetch is a NETWORK call. It used to run INSIDE the per-peer serialization
// lock (initiator-create path of `encryptToPeer`), so while a first-send /
// post-reset handshake waited on a flaky network, every INBOUND decrypt from
// that same peer queued behind it, tripped the inbox drain's apply timeout and
// burned its retry budget — field case: app open, a 63-envelope backlog
// trickled for ~48 minutes. `encryptToPeer` must PREFETCH the bundle before
// taking the lock, leaving the lock free for inbound decrypts while the
// network round trip is in flight.

const String peerDev = 'PEER-device';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('X3DH bundle fetch runs OUTSIDE the per-peer lock', () async {
    final db = await AppDb.openForTesting();
    try {
      final fetchStarted = Completer<void>();
      final releaseFetch = Completer<void>();
      final mgr = RatchetSessionManagerV3(
        db: db,
        deviceKeys: DeviceKeys.create(),
        keysClient: KeysClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
        fetchBundleAuthed: (String profileId) async {
          if (!fetchStarted.isCompleted) fetchStarted.complete();
          await releaseFetch.future;
          // The fetch outcome is irrelevant to what this test asserts (the
          // LOCK must be free while the fetch is in flight); failing here just
          // ends the encrypt attempt the same way a dead network would.
          throw StateError('no bundle');
        },
      );

      // No session row for peerDev → encryptToPeer must (pre)fetch the bundle.
      final encryptOutcome = mgr
          .encryptToPeer(
            selfDeviceId: 'SELF-device',
            peerProfileId: 'PEER-profile',
            peerDeviceId: peerDev,
            plaintext: Uint8List.fromList([1, 2, 3]),
          )
          .then<Object?>((v) => v, onError: (Object e) => e);
      await fetchStarted.future;

      // While the (gated) bundle fetch is in flight, the per-peer lock for
      // peerDev must be FREE: a locked op (stand-in for an inbound decrypt)
      // completes without waiting for the fetch. Pre-fix this timed out —
      // the lock was held for the whole fetch.
      final probed = await mgr
          .debugWithPeerLockForTest(peerDev, () async => 'lock-free')
          .timeout(const Duration(seconds: 2));
      expect(probed, 'lock-free');

      releaseFetch.complete();
      expect(await encryptOutcome, isA<StateError>());
    } finally {
      await db.close();
    }
  });
}
