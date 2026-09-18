// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

/// Rooms in the read-receipt reconcile backstop (2026-07-30).
///
/// The backstop re-emits read state for messages already read, so a receipt
/// lost to an undecryptable wire is not lost forever. Rooms were excluded
/// because a room has one conversation and many authors, and the 1:1 query
/// takes the peer from the conversation id. The author now comes from the row.
///
/// This matters more than it used to: the room convergence backstop treats "no
/// receipt from this member" as evidence to re-key them, so a single dead
/// receipt with no safety net becomes repeated session resets against a member
/// whose only fault was one lost wire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const me = 'my-dev';
  late AppDb db;

  Future<void> put({
    required String id,
    required String convo,
    required String sender,
    required String? payloadId,
    int? readAtMs,
    String type = 'msg',
  }) => db.insertEvent(
    eventId: id,
    convoId: convo,
    type: type,
    senderDeviceId: sender,
    ciphertextB64: 'x',
    createdAtMs: 1000,
    localState: 'received',
    payloadEventId: payloadId,
    readAtMs: readAtMs,
  );

  setUp(() async => db = await AppDb.openForTesting());
  tearDown(() async => db.close());

  test('returns read room messages together with who wrote them', () async {
    await put(
      id: 'e1',
      convo: 'group:team',
      sender: 'alice-dev',
      payloadId: 'p1',
      readAtMs: 5000,
    );
    await put(
      id: 'e2',
      convo: 'group:team',
      sender: 'bob-dev',
      payloadId: 'p2',
      readAtMs: 5000,
    );

    final out = await db.roomReadReceiptReconcileTargets(
      selfDeviceId: me,
      readAfterMs: 1,
    );

    // The author has to travel with the row — the room id cannot supply it.
    expect(
      out.map((r) => '${r.senderDeviceId}/${r.payloadEventId}').toSet(),
      {'alice-dev/p1', 'bob-dev/p2'},
    );
    expect(out.every((r) => r.roomId == 'group:team'), isTrue);
  });

  test('never re-acknowledges my own message to myself', () async {
    await put(
      id: 'mine',
      convo: 'group:team',
      sender: me,
      payloadId: 'p-mine',
      readAtMs: 5000,
    );
    // A sibling device of mine is my message too, arriving via self-mirror.
    await put(
      id: 'sibling',
      convo: 'group:team',
      sender: 'my-other-dev',
      payloadId: 'p-sib',
      readAtMs: 5000,
    );

    final out = await db.roomReadReceiptReconcileTargets(
      selfDeviceId: me,
      readAfterMs: 1,
      excludedSenderDeviceIds: const ['my-other-dev'],
    );
    expect(out, isEmpty);
  });

  test('only what was actually read, and only rooms', () async {
    // Unread: the author is owed nothing yet.
    await put(
      id: 'unread',
      convo: 'group:team',
      sender: 'alice-dev',
      payloadId: 'p-unread',
    );
    // Read long ago: outside the window the caller passes.
    await put(
      id: 'stale',
      convo: 'group:team',
      sender: 'alice-dev',
      payloadId: 'p-stale',
      readAtMs: 100,
    );
    // A 1:1 chat belongs to the other loop; handling it twice would send the
    // same receipt from both.
    await put(
      id: 'direct',
      convo: 'alice-pid',
      sender: 'alice-dev',
      payloadId: 'p-direct',
      readAtMs: 5000,
    );
    // A system frame is not a user message.
    await put(
      id: 'sys',
      convo: 'group:team',
      sender: 'alice-dev',
      payloadId: 'p-sys',
      readAtMs: 5000,
      type: 'sys',
    );
    // No payload id: a receipt referring to nothing cannot be matched.
    await put(
      id: 'nopayload',
      convo: 'group:team',
      sender: 'alice-dev',
      payloadId: null,
      readAtMs: 5000,
    );

    final out = await db.roomReadReceiptReconcileTargets(
      selfDeviceId: me,
      readAfterMs: 1000,
    );
    expect(out, isEmpty);
  });
}
