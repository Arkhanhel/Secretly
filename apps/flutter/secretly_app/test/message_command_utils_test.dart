// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart';

void main() {
  test('delete-for-all command roundtrips payload ids', () {
    final command = buildDeleteForAllCommand(['payload-1', 'payload-2']);

    expect(isDeleteForAllCommandText(command), isTrue);
    expect(parseDeleteForAllCommand(command), ['payload-1', 'payload-2']);
  });

  test(
    'hidden control detection keeps delete command visible to parser only',
    () {
      expect(isHiddenMessageControlText('__secretly_custom__:noop'), isTrue);
      expect(
        isHiddenMessageControlText(buildDeleteForAllCommand(['payload-1'])),
        isFalse,
      );
    },
  );

  test(
    'edit message command roundtrips text and mentions as hidden control',
    () {
      final command = buildEditMessageCommand(
        convoId: 'peer-1',
        payloadEventId: 'payload-1',
        text: 'edited text',
        editedAtMs: 42,
        mentions: const [
          {'type': 'profile', 'start': 0, 'end': 5, 'profile_id': 'peer-2'},
        ],
      );

      final parsed = parseEditMessageCommand(command);

      expect(isEditMessageCommandText(command), isTrue);
      expect(isHiddenMessageControlText(command), isTrue);
      expect(parsed?.convoId, 'peer-1');
      expect(parsed?.payloadEventId, 'payload-1');
      expect(parsed?.text, 'edited text');
      expect(parsed?.editedAtMs, 42);
      expect(parsed?.mentions.single['profile_id'], 'peer-2');
    },
  );

  // ---------------------------------------------------------------------------
  // Self-mirror command roundtrips — TZ §21.1
  //
  // These tests verify only encode/decode symmetry of the new control envelopes
  // used to fan out a sender's own messages to their other devices. Wiring into
  // app_controller (mirror call sites + receive-side decoder branches) is a
  // separate commit and is not tested here — that's done end-to-end with
  // app-state fixtures elsewhere.
  // ---------------------------------------------------------------------------

  test('self-mirror attachment roundtrips required fields', () {
    final command = buildSelfMirrorAttachmentCommand(
      convoId: 'peer-1',
      msgEventId: 'event-7',
      blobId: 'blob-xyz',
      fileKeyB64: 'ZmlsZS1rZXk=',
      sizeBytes: 12345,
      createdAtMs: 1700000000000,
    );

    final parsed = parseSelfMirrorAttachmentCommand(command);

    expect(isSelfMirrorAttachmentCommandText(command), isTrue);
    expect(isHiddenMessageControlText(command), isTrue);
    expect(parsed?.convoId, 'peer-1');
    expect(parsed?.msgEventId, 'event-7');
    expect(parsed?.blobId, 'blob-xyz');
    expect(parsed?.fileKeyB64, 'ZmlsZS1rZXk=');
    expect(parsed?.sizeBytes, 12345);
    expect(parsed?.createdAtMs, 1700000000000);
    expect(parsed?.mime, isNull);
    expect(parsed?.blobAccessTokenB64, isNull);
    expect(parsed?.replyToPayloadEventId, isNull);
    expect(parsed?.mediaGroupId, isNull);
  });

  test('self-mirror attachment roundtrips optional fields', () {
    final command = buildSelfMirrorAttachmentCommand(
      convoId: 'peer-1',
      msgEventId: 'event-7',
      blobId: 'blob-xyz',
      fileKeyB64: 'k',
      sizeBytes: 1024,
      createdAtMs: 1700000001000,
      blobAccessTokenB64: 'tok',
      mime: 'image/jpeg',
      replyToPayloadEventId: 'event-4',
      mediaGroupId: 'group-1',
    );

    final parsed = parseSelfMirrorAttachmentCommand(command);

    expect(parsed?.mime, 'image/jpeg');
    expect(parsed?.blobAccessTokenB64, 'tok');
    expect(parsed?.replyToPayloadEventId, 'event-4');
    expect(parsed?.mediaGroupId, 'group-1');
  });

  test('self-mirror attachment rejects malformed payload', () {
    expect(parseSelfMirrorAttachmentCommand('hello'), isNull);
    expect(
      parseSelfMirrorAttachmentCommand(kSelfMirrorAttachmentCommandPrefix),
      isNull,
    );
    expect(
      parseSelfMirrorAttachmentCommand(
        '${kSelfMirrorAttachmentCommandPrefix}not-base64!!!',
      ),
      isNull,
    );
    // Missing required fields → null.
    final badCommand = buildSelfMirrorAttachmentCommand(
      convoId: '',
      msgEventId: 'e',
      blobId: 'b',
      fileKeyB64: 'k',
      sizeBytes: 1,
      createdAtMs: 1,
    );
    expect(parseSelfMirrorAttachmentCommand(badCommand), isNull);
  });

  test('self-mirror sticker roundtrips fields', () {
    final command = buildSelfMirrorStickerCommand(
      convoId: 'peer-1',
      msgEventId: 'event-10',
      packId: 'pack-a',
      packVersion: 3,
      stickerId: 'sticker-77',
      createdAtMs: 1700000005000,
      emojiHint: '👋',
      label: 'wave',
      animated: true,
      format: 'webp',
      replyToPayloadEventId: 'event-5',
    );

    final parsed = parseSelfMirrorStickerCommand(command);

    expect(isSelfMirrorStickerCommandText(command), isTrue);
    expect(isHiddenMessageControlText(command), isTrue);
    expect(parsed?.convoId, 'peer-1');
    expect(parsed?.msgEventId, 'event-10');
    expect(parsed?.packId, 'pack-a');
    expect(parsed?.packVersion, 3);
    expect(parsed?.stickerId, 'sticker-77');
    expect(parsed?.createdAtMs, 1700000005000);
    expect(parsed?.emojiHint, '👋');
    expect(parsed?.label, 'wave');
    expect(parsed?.animated, isTrue);
    expect(parsed?.format, 'webp');
    expect(parsed?.replyToPayloadEventId, 'event-5');
  });

  test('self-mirror sticker defaults when optional fields omitted', () {
    final command = buildSelfMirrorStickerCommand(
      convoId: 'peer-1',
      msgEventId: 'event-10',
      packId: 'pack-a',
      packVersion: 1,
      stickerId: 'sticker-1',
      createdAtMs: 1,
    );

    final parsed = parseSelfMirrorStickerCommand(command);

    expect(parsed?.emojiHint, '');
    expect(parsed?.label, '');
    expect(parsed?.animated, isFalse);
    expect(parsed?.format, 'png');
    expect(parsed?.replyToPayloadEventId, isNull);
  });

  test('self-mirror reaction roundtrips fields', () {
    final command = buildSelfMirrorReactionCommand(
      convoId: 'peer-1',
      targetPayloadEventId: 'event-42',
      emoji: '🔥',
      removed: false,
      createdAtMs: 1700000010000,
      actorProfileId: 'me',
      actorName: 'Yurii',
      actorAvatarPath: '/path/to/avatar.png',
    );

    final parsed = parseSelfMirrorReactionCommand(command);

    expect(isSelfMirrorReactionCommandText(command), isTrue);
    expect(isHiddenMessageControlText(command), isTrue);
    expect(parsed?.convoId, 'peer-1');
    expect(parsed?.targetPayloadEventId, 'event-42');
    expect(parsed?.emoji, '🔥');
    expect(parsed?.removed, isFalse);
    expect(parsed?.createdAtMs, 1700000010000);
    expect(parsed?.actorProfileId, 'me');
    expect(parsed?.actorName, 'Yurii');
    expect(parsed?.actorAvatarPath, '/path/to/avatar.png');
  });

  test('self-mirror reaction roundtrips removal flag', () {
    final command = buildSelfMirrorReactionCommand(
      convoId: 'peer-1',
      targetPayloadEventId: 'event-42',
      emoji: '🔥',
      removed: true,
      createdAtMs: 1,
    );

    final parsed = parseSelfMirrorReactionCommand(command);

    expect(parsed?.removed, isTrue);
    expect(parsed?.actorProfileId, isNull);
  });

  test('self-mirror reaction rejects empty emoji', () {
    final bad = buildSelfMirrorReactionCommand(
      convoId: 'peer-1',
      targetPayloadEventId: 'event-42',
      emoji: '',
      removed: false,
      createdAtMs: 1,
    );

    expect(parseSelfMirrorReactionCommand(bad), isNull);
  });

  test(
    'self-mirror prefixes do not collide with delete-for-all or edit prefixes',
    () {
      // Delete-for-all and edit prefixes are the only special-cased ones in
      // isHiddenMessageControlText. Make sure the new prefixes are classified
      // as hidden but are NOT misidentified as delete or edit commands.
      final attCommand = buildSelfMirrorAttachmentCommand(
        convoId: 'p',
        msgEventId: 'e',
        blobId: 'b',
        fileKeyB64: 'k',
        sizeBytes: 1,
        createdAtMs: 1,
      );
      expect(isDeleteForAllCommandText(attCommand), isFalse);
      expect(isEditMessageCommandText(attCommand), isFalse);
      expect(parseEditMessageCommand(attCommand), isNull);
    },
  );

  group('self-mirror read watermark', () {
    test('roundtrips the conversation and the watermark', () {
      final command = buildSelfMirrorReadCommand(
        convoId: 'peer-1',
        readUpToMs: 1700000000000,
        appliedAtMs: 1700000000123,
      );

      expect(isSelfMirrorReadCommandText(command), isTrue);
      final parsed = parseSelfMirrorReadCommand(command);
      expect(parsed, isNotNull);
      expect(parsed!.convoId, 'peer-1');
      expect(parsed.readUpToMs, 1700000000000);
      expect(parsed.appliedAtMs, 1700000000123);
    });

    test('is hidden control, so builds that predate it skip it', () {
      // The compatibility promise of the whole `__secretly_self_mirror_*`
      // family: an older client must drop this silently, never render it as a
      // message. Mobile ships before desktop can rely on it, so this matters.
      final command = buildSelfMirrorReadCommand(
        convoId: 'peer-1',
        readUpToMs: 1,
        appliedAtMs: 1,
      );
      expect(isHiddenMessageControlText(command), isTrue);
    });

    test('is not confused with the receipt mirror', () {
      // The two carry opposite directions — "peer read mine" vs "I read
      // theirs" — and applying one as the other would corrupt the ticks.
      final read = buildSelfMirrorReadCommand(
        convoId: 'peer-1',
        readUpToMs: 5,
        appliedAtMs: 5,
      );
      final receipt = buildSelfMirrorReceiptCommand(
        refPayloadEventIds: const ['payload-1'],
        status: 'read',
        appliedAtMs: 5,
      );

      expect(parseSelfMirrorReceiptCommand(read), isNull);
      expect(parseSelfMirrorReadCommand(receipt), isNull);
      expect(isSelfMirrorReadCommandText(receipt), isFalse);
      expect(isSelfMirrorReceiptCommandText(read), isFalse);
    });

    test('a watermark of zero is rejected, not silently applied as a no-op', () {
      final command = buildSelfMirrorReadCommand(
        convoId: 'peer-1',
        readUpToMs: 0,
        appliedAtMs: 1,
      );
      expect(parseSelfMirrorReadCommand(command), isNull);
    });

    test('garbage and foreign prefixes parse to null', () {
      expect(parseSelfMirrorReadCommand('hello'), isNull);
      expect(parseSelfMirrorReadCommand('__secretly_self_mirror_read_v1__:'), isNull);
      expect(
        parseSelfMirrorReadCommand('__secretly_self_mirror_read_v1__:!!!'),
        isNull,
      );
    });
  });

  group('self-mirror conversation state', () {
    test('carries only the fields that were actually changed', () {
      // The patch property is the whole point: a mirror that shipped the full
      // state would overwrite flags the sending screen never touched.
      final command = buildSelfMirrorConvoStateCommand(
        convoId: 'peer-1',
        appliedAtMs: 10,
        muted: true,
      );
      final parsed = parseSelfMirrorConvoStateCommand(command);

      expect(parsed, isNotNull);
      expect(parsed!.convoId, 'peer-1');
      expect(parsed.muted, isTrue);
      expect(parsed.pinned, isNull);
      expect(parsed.archived, isNull);
      expect(parsed.personal, isNull);
      expect(parsed.autoDeleteSet, isFalse);
    });

    test('roundtrips every field at once', () {
      final command = buildSelfMirrorConvoStateCommand(
        convoId: 'group:room-1',
        appliedAtMs: 11,
        muted: false,
        pinned: true,
        archived: false,
        personal: true,
        autoDeleteSet: true,
        autoDeleteSeconds: 86400,
      );
      final parsed = parseSelfMirrorConvoStateCommand(command)!;

      expect(parsed.muted, isFalse);
      expect(parsed.pinned, isTrue);
      expect(parsed.archived, isFalse);
      expect(parsed.personal, isTrue);
      expect(parsed.autoDeleteSet, isTrue);
      expect(parsed.autoDeleteSeconds, 86400);
    });

    test('separates "timer turned off" from "timer not in this change"', () {
      // Both look like a null timer; conflating them would silently clear a
      // disappearing-message setting the user still wants.
      final off = parseSelfMirrorConvoStateCommand(
        buildSelfMirrorConvoStateCommand(
          convoId: 'peer-1',
          appliedAtMs: 12,
          autoDeleteSet: true,
          autoDeleteSeconds: null,
        ),
      )!;
      expect(off.autoDeleteSet, isTrue);
      expect(off.autoDeleteSeconds, isNull);

      final untouched = parseSelfMirrorConvoStateCommand(
        buildSelfMirrorConvoStateCommand(
          convoId: 'peer-1',
          appliedAtMs: 12,
          pinned: true,
        ),
      )!;
      expect(untouched.autoDeleteSet, isFalse);
      expect(untouched.autoDeleteSeconds, isNull);
    });

    test('an empty patch is rejected rather than applied as a no-op', () {
      final command = buildSelfMirrorConvoStateCommand(
        convoId: 'peer-1',
        appliedAtMs: 13,
      );
      expect(parseSelfMirrorConvoStateCommand(command), isNull);
    });

    test('is hidden control and does not collide with the other mirrors', () {
      final command = buildSelfMirrorConvoStateCommand(
        convoId: 'peer-1',
        appliedAtMs: 14,
        archived: true,
      );
      expect(isHiddenMessageControlText(command), isTrue);
      expect(isSelfMirrorConvoStateCommandText(command), isTrue);
      expect(parseSelfMirrorReadCommand(command), isNull);
      expect(parseSelfMirrorReceiptCommand(command), isNull);

      final read = buildSelfMirrorReadCommand(
        convoId: 'peer-1',
        readUpToMs: 5,
        appliedAtMs: 5,
      );
      expect(parseSelfMirrorConvoStateCommand(read), isNull);
    });
  });

  group('self-mirror chat folder', () {
    test('carries the whole folder, membership included', () {
      // A folder IS its membership: "chat X joined folder F" means nothing to
      // a device that never heard of F, so the mirror is not a delta.
      final command = buildSelfMirrorFolderCommand(
        folderId: 'folder-1',
        appliedAtMs: 20,
        name: 'Работа',
        emoji: '💼',
        position: 2,
        convoIds: const ['peer-1', 'group:room-1'],
      );
      final parsed = parseSelfMirrorFolderCommand(command)!;

      expect(parsed.folderId, 'folder-1');
      expect(parsed.deleted, isFalse);
      expect(parsed.name, 'Работа');
      expect(parsed.emoji, '💼');
      expect(parsed.position, 2);
      expect(parsed.convoIds, ['peer-1', 'group:room-1']);
    });

    test('deletion carries no body', () {
      final command = buildSelfMirrorFolderCommand(
        folderId: 'folder-1',
        appliedAtMs: 21,
        deleted: true,
      );
      final parsed = parseSelfMirrorFolderCommand(command)!;

      expect(parsed.deleted, isTrue);
      expect(parsed.name, isEmpty);
      expect(parsed.convoIds, isEmpty);
    });

    test('an empty folder membership is legal, an empty name is not', () {
      // A folder with nothing in it is a real state the user can create; a
      // folder with no name would render as a blank tab nobody can identify.
      final empty = parseSelfMirrorFolderCommand(
        buildSelfMirrorFolderCommand(
          folderId: 'folder-1',
          appliedAtMs: 22,
          name: 'Пусто',
          convoIds: const [],
        ),
      );
      expect(empty, isNotNull);
      expect(empty!.convoIds, isEmpty);

      final nameless = parseSelfMirrorFolderCommand(
        buildSelfMirrorFolderCommand(
          folderId: 'folder-1',
          appliedAtMs: 22,
          name: '   ',
          convoIds: const ['peer-1'],
        ),
      );
      expect(nameless, isNull);
    });

    test('is hidden control and distinct from the other mirrors', () {
      final folder = buildSelfMirrorFolderCommand(
        folderId: 'folder-1',
        appliedAtMs: 23,
        name: 'Работа',
      );
      expect(isHiddenMessageControlText(folder), isTrue);
      expect(isSelfMirrorFolderCommandText(folder), isTrue);
      expect(parseSelfMirrorConvoStateCommand(folder), isNull);
      expect(parseSelfMirrorReadCommand(folder), isNull);

      final convo = buildSelfMirrorConvoStateCommand(
        convoId: 'peer-1',
        appliedAtMs: 23,
        muted: true,
      );
      expect(parseSelfMirrorFolderCommand(convo), isNull);
    });
  });
}
