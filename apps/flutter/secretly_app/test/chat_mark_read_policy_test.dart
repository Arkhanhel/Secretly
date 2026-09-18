// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_screen.dart';

void main() {
  test('auto mark read is disabled while app is backgrounded', () {
    expect(
      shouldAutoMarkChatRead(
        appInForeground: false,
        isChatVisible: true,
        isNearLatestMessages: true,
        isRequestConvo: false,
        peerProfileId: 'peer-1',
      ),
      isFalse,
    );
  });

  test('auto mark read is disabled when user is away from latest messages', () {
    expect(
      shouldAutoMarkChatRead(
        appInForeground: true,
        isChatVisible: true,
        isNearLatestMessages: false,
        isRequestConvo: false,
        peerProfileId: 'peer-1',
      ),
      isFalse,
    );
  });

  // TZ read-receipt scope (2026-07-18): a still-mounted chat that is NOT the
  // visible route (covered by a pushed screen / mid-transition / off-stage)
  // must NOT leak a read receipt — "read even on the main page".
  test('auto mark read is disabled when the chat route is not visible', () {
    expect(
      shouldAutoMarkChatRead(
        appInForeground: true,
        isChatVisible: false,
        isNearLatestMessages: true,
        isRequestConvo: false,
        peerProfileId: 'peer-1',
      ),
      isFalse,
    );
  });

  test('auto mark read is disabled for request conversations', () {
    expect(
      shouldAutoMarkChatRead(
        appInForeground: true,
        isChatVisible: true,
        isNearLatestMessages: true,
        isRequestConvo: true,
        peerProfileId: 'peer-1',
      ),
      isFalse,
    );
  });

  test(
    'auto mark read stays enabled only for a foreground, VISIBLE chat near latest',
    () {
      expect(
        shouldAutoMarkChatRead(
          appInForeground: true,
          isChatVisible: true,
          isNearLatestMessages: true,
          isRequestConvo: false,
          peerProfileId: 'peer-1',
        ),
        isTrue,
      );
    },
  );
}
