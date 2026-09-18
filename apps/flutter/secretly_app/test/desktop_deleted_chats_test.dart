// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Tombstones for chats deleted on this desktop.
//
// Deleting a chat is local, and the boot-time history sync deliberately
// re-materialises conversation rows ("we materialize the conversation row …
// so subsequent `db.insertEvent` calls don't leave the chat list empty").
// Both behaviours are correct on their own and wrong together: the chat comes
// back carrying the messages the user removed.
//
// What is pinned here is the line between "resurrected by a re-import" and
// "genuinely alive again", because getting that line wrong in the other
// direction — hiding a chat someone just wrote in — is the worse failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_deleted_chats.dart';

void main() {
  setUp(DesktopDeletedChats.resetForTest);
  tearDown(DesktopDeletedChats.resetForTest);

  test('a chat with no tombstone is never suppressed', () {
    expect(
      DesktopDeletedChats.isSuppressed(convoId: 'peer-1', lastEventAtMs: 100),
      isFalse,
    );
  });

  test('re-imported history older than the deletion stays hidden', () async {
    await DesktopDeletedChats.remember('peer-1', atMs: 1000);

    // The sync brings back messages that existed BEFORE the deletion.
    expect(
      DesktopDeletedChats.isSuppressed(convoId: 'peer-1', lastEventAtMs: 999),
      isTrue,
    );
    expect(
      DesktopDeletedChats.isSuppressed(convoId: 'peer-1', lastEventAtMs: 1000),
      isTrue,
      reason: 'an event at the very moment of deletion is not new activity',
    );
  });

  test('a message newer than the deletion brings the chat back', () async {
    await DesktopDeletedChats.remember('peer-1', atMs: 1000);

    expect(
      DesktopDeletedChats.isSuppressed(convoId: 'peer-1', lastEventAtMs: 1001),
      isFalse,
      reason: 'someone wrote again — hiding that would be the worse bug',
    );
  });

  test('the tombstone is dropped once the chat is alive again', () async {
    await DesktopDeletedChats.remember('peer-1', atMs: 1000);
    expect(DesktopDeletedChats.count, 1);

    // New activity clears it...
    DesktopDeletedChats.isSuppressed(convoId: 'peer-1', lastEventAtMs: 2000);
    await Future<void>.delayed(Duration.zero);
    expect(DesktopDeletedChats.count, 0);

    // ...and it cannot hide the chat again on a later, unrelated re-import.
    expect(
      DesktopDeletedChats.isSuppressed(convoId: 'peer-1', lastEventAtMs: 500),
      isFalse,
    );
  });

  test('tombstones are per conversation', () async {
    await DesktopDeletedChats.remember('peer-1', atMs: 1000);

    expect(
      DesktopDeletedChats.isSuppressed(convoId: 'peer-2', lastEventAtMs: 10),
      isFalse,
    );
  });

  test('an empty conversation id is not recorded', () async {
    await DesktopDeletedChats.remember('   ');
    expect(DesktopDeletedChats.count, 0);
  });
}
