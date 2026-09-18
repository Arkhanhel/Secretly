// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Which id `AppController.markChatRead` should be given for a conversation.
///
/// A room is addressed by its `group:` convo id; a 1:1 chat by the peer's
/// profile id. `markChatRead` branches on the `group:` prefix and sends room
/// read-receipts, so the only thing that differs between the two kinds is the
/// addressing — and getting it wrong is silent: the call simply marks nothing.
///
/// It lives here, and not in a screen, because BOTH interfaces need exactly
/// the same rule. It used to live inside the mobile `chat_screen.dart` marked
/// `@visibleForTesting`, so the desktop could not reach it without importing
/// the whole mobile chat screen — and it did not: the desktop bailed for rooms
/// instead, which is why a room's unread badge never cleared there.
String? resolveChatMarkReadPeerProfileId({
  required String convoId,
  required String? peerProfileIdForSend,
}) {
  final trimmedConvoId = convoId.trim();
  if (trimmedConvoId.startsWith('group:')) {
    return trimmedConvoId;
  }
  final peer = peerProfileIdForSend?.trim();
  if (peer == null || peer.isEmpty) return null;
  return peer;
}
