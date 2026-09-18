// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

/// Who a room notification names as the author.
///
/// The room banner used to resolve its title and avatar from "the latest unread
/// message in this room" instead of from the message being announced. With two
/// members writing at once that names the WRONG person on a message — not a
/// cosmetic defect in a messenger, and invisible in testing because it only
/// shows up under overlap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const room = 'group:team';
  const me = 'my-dev';

  late AppDb db;

  setUp(() async {
    db = await AppDb.openForTesting();
    // The room already holds an unread message from Bob — the stale answer the
    // old code would have given for every notification in this room.
    await db.deviceProfileUpsert(
      deviceId: 'bob-dev',
      profileId: 'bob-pid',
    );
    await db.deviceProfileUpsert(
      deviceId: 'alice-dev',
      profileId: 'alice-pid',
    );
    await db.insertEvent(
      eventId: 'bob-1',
      convoId: room,
      type: 'msg',
      senderDeviceId: 'bob-dev',
      ciphertextB64: 'x',
      createdAtMs: 1000,
      localState: 'received',
      payloadEventId: 'p-bob-1',
    );
  });

  tearDown(() async => db.close());

  Future<String?> resolve({String? profileId, String? deviceId}) =>
      AppController.resolveRoomSenderProfileId(
        db: db,
        selfDeviceId: me,
        convoId: room,
        ownDeviceIds: const [me],
        senderProfileId: profileId,
        senderDeviceId: deviceId,
      );

  test('the author carried by the envelope wins over the latest unread', () async {
    // Alice's message is the one being announced; Bob merely wrote last.
    expect(await resolve(profileId: 'alice-pid'), 'alice-pid');
  });

  test('the author is resolved from their device when no profile id came '
      'along', () async {
    expect(await resolve(deviceId: 'alice-dev'), 'alice-pid');
  });

  test('the latest unread is used only when the author is unknown', () async {
    // Older envelopes carry neither, and a name is better than none.
    expect(await resolve(), 'bob-pid');
  });

  test('an unresolvable device falls back rather than naming nobody', () async {
    // A device we have never seen (peer reinstalled) must not blank the banner.
    expect(await resolve(deviceId: 'ghost-dev'), 'bob-pid');
  });

  test('blank inputs are treated as absent, not as an author', () async {
    expect(await resolve(profileId: '   ', deviceId: '  '), 'bob-pid');
  });

  test('no author and nothing unread yields null, not a wrong name', () async {
    final empty = await AppDb.openForTesting(path: 'file:empty?mode=memory');
    expect(
      await AppController.resolveRoomSenderProfileId(
        db: empty,
        selfDeviceId: me,
        convoId: 'group:silent',
        ownDeviceIds: const [me],
      ),
      isNull,
    );
    await empty.close();
  });
}
