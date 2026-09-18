// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// The rule that decides WHICH id `markChatRead` is given.
//
// It used to live inside the mobile chat screen, marked `@visibleForTesting`,
// so the desktop could not reach it. The desktop therefore used the peer
// profile id — which is null for a room — and bailed, so opening a room on the
// desktop never marked it read and its unread badge never cleared. The chat
// list's "mark read" menu then told the user to open the room instead, advice
// that did not work either.
//
// One home, one rule, both interfaces.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/chat_read_target.dart';

void main() {
  test('a room is addressed by its group convo id', () {
    // The peer id is null for a room — that is exactly the case the desktop
    // used to drop on the floor.
    expect(
      resolveChatMarkReadPeerProfileId(
        convoId: 'group:room-1',
        peerProfileIdForSend: null,
      ),
      'group:room-1',
    );
  });

  test('the group convo id wins even when a peer id is also present', () {
    expect(
      resolveChatMarkReadPeerProfileId(
        convoId: 'group:room-1',
        peerProfileIdForSend: 'peer-1',
      ),
      'group:room-1',
    );
  });

  test('a 1:1 chat is addressed by the peer profile id', () {
    expect(
      resolveChatMarkReadPeerProfileId(
        convoId: 'peer-1',
        peerProfileIdForSend: 'peer-1',
      ),
      'peer-1',
    );
  });

  test('a 1:1 chat with no peer resolves to nothing to mark', () {
    expect(
      resolveChatMarkReadPeerProfileId(
        convoId: 'peer-1',
        peerProfileIdForSend: null,
      ),
      isNull,
    );
    expect(
      resolveChatMarkReadPeerProfileId(
        convoId: 'peer-1',
        peerProfileIdForSend: '   ',
      ),
      isNull,
    );
  });

  test('surrounding whitespace never changes the answer', () {
    expect(
      resolveChatMarkReadPeerProfileId(
        convoId: '  group:room-1  ',
        peerProfileIdForSend: null,
      ),
      'group:room-1',
    );
    expect(
      resolveChatMarkReadPeerProfileId(
        convoId: 'peer-1',
        peerProfileIdForSend: '  peer-1  ',
      ),
      'peer-1',
    );
  });
}
