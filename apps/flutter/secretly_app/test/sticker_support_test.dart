// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/stickers/sticker_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sticker support', () {
    test('StickerEventV1 round-trips through E2ePayloadV1', () {
      final payload = E2ePayloadV1(
        senderDeviceId: 'device-1',
        createdAtMs: 123456,
        events: [
          StickerEventV1(
            eventId: 'sticker-event-1',
            packId: 'hearts_pack',
            packVersion: 2,
            stickerId: 'heart_burst',
            emojiHint: '💖',
            label: 'Heart Burst',
            animated: true,
            format: 'lottie',
            replyToEventId: 'reply-1',
          ),
        ],
      );

      final decoded = E2ePayloadV1.decode(payload.encode());
      expect(decoded.senderDeviceId, 'device-1');
      expect(decoded.createdAtMs, 123456);
      expect(decoded.events, hasLength(1));

      final sticker = decoded.events.single;
      expect(sticker, isA<StickerEventV1>());
      final typed = sticker as StickerEventV1;
      expect(typed.eventId, 'sticker-event-1');
      expect(typed.packId, 'hearts_pack');
      expect(typed.packVersion, 2);
      expect(typed.stickerId, 'heart_burst');
      expect(typed.emojiHint, '💖');
      expect(typed.label, 'Heart Burst');
      expect(typed.animated, isTrue);
      expect(typed.format, 'lottie');
      expect(typed.replyToEventId, 'reply-1');
      // Catalog stickers carry no inline blob.
      expect(typed.hasInlineBlob, isFalse);
      expect(typed.blobId, isNull);
    });

    test('user-created StickerEventV1 round-trips its E2EE blob handle', () {
      // A user-made cutout ships its pixels as an XChaCha20 blob (like an
      // attachment) instead of a catalog reference. The blob handle must survive
      // encode→decode so the recipient can download + decrypt the sticker.
      final payload = E2ePayloadV1(
        senderDeviceId: 'device-9',
        createdAtMs: 987654,
        events: [
          StickerEventV1(
            eventId: 'user-sticker-1',
            packId: 'user:BBMU-GEJ4-QH37-U-RBM7JHQ',
            packVersion: 1,
            stickerId: 'abc123sha',
            emojiHint: '🔥',
            format: 'png',
            blobId: 'blob-xyz',
            fileKeyB64: 'ZmlsZS1rZXk=',
            blobAccessTokenB64: 'dG9rZW4=',
            sizeBytes: 81234,
            width: 512,
            height: 420,
          ),
        ],
      );

      final decoded = E2ePayloadV1.decode(payload.encode());
      final typed = decoded.events.single as StickerEventV1;
      expect(typed.hasInlineBlob, isTrue);
      expect(typed.packId, 'user:BBMU-GEJ4-QH37-U-RBM7JHQ');
      expect(typed.stickerId, 'abc123sha');
      expect(typed.format, 'png');
      expect(typed.blobId, 'blob-xyz');
      expect(typed.fileKeyB64, 'ZmlsZS1rZXk=');
      expect(typed.blobAccessTokenB64, 'dG9rZW4=');
      expect(typed.sizeBytes, 81234);
      expect(typed.width, 512);
      expect(typed.height, 420);
      // Catalog/blob stickers carry no inline pixels.
      expect(typed.inlinePngB64, isNull);
      expect(typed.hasInlinePng, isFalse);
    });

    test('StickerEventV1 round-trips INLINE pixels (WS fallback)', () {
      // When the blob upload is blocked, a small sticker ships its pixels INLINE
      // in the encrypted event over the WS. The base64 must survive encode→decode
      // (and be backward-compatible: old clients drop the unknown key).
      final inline = base64Encode(<int>[137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
      final payload = E2ePayloadV1(
        senderDeviceId: 'device-9',
        createdAtMs: 987654,
        events: [
          StickerEventV1(
            eventId: 'inline-sticker-1',
            packId: 'user:BBMU-GEJ4-QH37-U-RBM7JHQ',
            packVersion: 1,
            stickerId: 'inlsha',
            format: 'png',
            inlinePngB64: inline,
            width: 192,
            height: 192,
          ),
        ],
      );

      final typed =
          E2ePayloadV1.decode(payload.encode()).events.single as StickerEventV1;
      expect(typed.hasInlinePng, isTrue);
      expect(typed.inlinePngB64, inline);
      expect(typed.hasInlineBlob, isFalse);
      expect(typed.blobId, isNull);
    });

    test('recent stickers keep the newest 20 unique entries', () async {
      final db = await AppDb.openForTesting();
      try {
        for (var i = 0; i < 20; i++) {
          await db.recentStickerTouch(
            profileId: 'self-profile',
            packId: 'pack-main',
            packVersion: 1,
            stickerId: 'sticker-$i',
            lastUsedAtMs: 1000 + i,
          );
        }

        await db.recentStickerTouch(
          profileId: 'self-profile',
          packId: 'pack-main',
          packVersion: 1,
          stickerId: 'sticker-0',
          lastUsedAtMs: 5000,
        );

        await db.recentStickerTouch(
          profileId: 'self-profile',
          packId: 'pack-main',
          packVersion: 1,
          stickerId: 'sticker-20',
          lastUsedAtMs: 6000,
        );

        await db.recentStickerTouch(
          profileId: 'self-profile',
          packId: 'pack-main',
          packVersion: 1,
          stickerId: 'sticker-21',
          lastUsedAtMs: 7000,
        );

        final rows = await db.listRecentStickers(profileId: 'self-profile');
        expect(rows, hasLength(20));
        expect(rows.first['sticker_id'], 'sticker-21');

        final stickerIds = rows
            .map((row) => row['sticker_id'] as String?)
            .whereType<String>()
            .toList(growable: false);
        final stickerZeroRow = rows.firstWhere(
          (row) => row['sticker_id'] == 'sticker-0',
        );
        expect(stickerZeroRow['use_count'], 2);
        expect(stickerIds, isNot(contains('sticker-1')));
        expect(stickerIds, isNot(contains('sticker-2')));
        expect(stickerIds, contains('sticker-21'));
      } finally {
        await db.close();
      }
    });

    test('incoming sticker payload is stored as sticker event', () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();
      try {
        await db.contactUpsert(profileId: 'peer-1', displayName: 'Peer 1');

        final payload = E2ePayloadV1(
          senderDeviceId: 'peer-device-1',
          createdAtMs: 7777,
          events: [
            StickerEventV1(
              eventId: 'payload-sticker-1',
              packId: 'party_pack',
              packVersion: 1,
              stickerId: 'spark',
              emojiHint: '✨',
              label: 'Spark',
              animated: false,
              format: 'png',
            ),
          ],
        );

        final handled = await controller
            .handleDecryptedInboundPayloadForTesting(
              db: db,
              msgId: 'transport-sticker-1',
              ciphertextB64: 'AA==',
              plainBytes: Uint8List.fromList(payload.encode()),
              payload: payload,
              senderDeviceId: 'peer-device-1',
              senderProfileId: 'peer-1',
              nowMs: 9000,
            );

        expect(handled, isTrue);

        final rows = await db.listEventsChronological('peer-1', limit: 10);
        expect(rows, hasLength(1));
        expect(rows.single['type'], 'sticker');
        expect(rows.single['payload_event_id'], 'payload-sticker-1');
        expect((rows.single['created_at_ms'] as num?)?.toInt(), 7777);
      } finally {
        await db.close();
      }
    });

    test('sticker asset integrity rejects size mismatch', () {
      expect(
        () => AppController.verifyStickerAssetIntegrityForTesting(
          stickerId: 'studio_palette',
          expectedSha256B64: '',
          expectedSizeBytes: 5,
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        ),
        throwsStateError,
      );
    });

    test('sticker asset integrity accepts exact size and checksum', () {
      final bytes = Uint8List.fromList(<int>[9, 8, 7, 6]);
      final expectedHash = base64Encode(crypto.sha256.convert(bytes).bytes);

      expect(
        () => AppController.verifyStickerAssetIntegrityForTesting(
          stickerId: 'studio_palette',
          expectedSha256B64: expectedHash,
          expectedSizeBytes: bytes.length,
          bytes: bytes,
        ),
        returnsNormally,
      );
    });

    test(
      'all bundled packs are hidden from the picker but stay resolvable',
      () {
        SecretlyStickerCatalog.clearRemoteCatalog();
        try {
          // Clean slate: NO bundled packs in the picker anymore (cookie included).
          expect(
            SecretlyStickerCatalog.pickerPacks.any(
              (pack) => pack.id == 'cookie_pack',
            ),
            isFalse,
          );
          expect(
            SecretlyStickerCatalog.pickerPacks.any(
              (pack) => pack.id == 'hearts_pack',
            ),
            isFalse,
          );

          final searchResults = SecretlyStickerCatalog.search('heart');
          expect(
            searchResults.any((item) => item.packId == 'hearts_pack'),
            isFalse,
          );

          final resolved = SecretlyStickerCatalog.resolveEvent(
            StickerEventV1(
              eventId: 'legacy-heart-1',
              packId: 'hearts_pack',
              packVersion: 1,
              stickerId: 'heart_primary',
              emojiHint: '❤️',
              label: 'Heart',
              animated: false,
              format: 'png',
            ),
          );

          expect(resolved.packId, 'hearts_pack');
          expect(resolved.stickerId, 'heart_primary');
          expect(resolved.assetSource, SecretlyStickerAssetSource.bundledAsset);
        } finally {
          SecretlyStickerCatalog.clearRemoteCatalog();
        }
      },
    );

    test(
      'remote sticker registry resolves placeholders but is hidden from the picker/search',
      () {
        SecretlyStickerCatalog.clearRemoteCatalog();
        try {
          SecretlyStickerCatalog.applyRemoteCatalog(<SecretlyStickerPack>[
            SecretlyStickerPack(
              id: 'winter_pack',
              version: 1,
              title: 'Winter',
              description: 'Remote winter pack',
              iconStickerId: 'winter_santa',
              iconEmojiHint: '🎅',
              installed: false,
              origin: SecretlyStickerPackOrigin.remote,
              stickers: <SecretlyStickerDescriptor>[
                SecretlyStickerDescriptor.placeholder(
                  packId: 'winter_pack',
                  packVersion: 1,
                  stickerId: 'winter_santa',
                  emojiHint: '🎅',
                  label: 'Santa',
                  keywords: <String>['winter', 'holiday'],
                ),
              ],
            ),
            SecretlyStickerPack(
              id: 'studio_pack',
              version: 1,
              title: 'Studio',
              description: 'Installed remote studio pack',
              iconStickerId: 'studio_palette',
              iconEmojiHint: '🎨',
              installed: true,
              origin: SecretlyStickerPackOrigin.remote,
              stickers: <SecretlyStickerDescriptor>[
                SecretlyStickerDescriptor.localFile(
                  packId: 'studio_pack',
                  packVersion: 1,
                  stickerId: 'studio_palette',
                  localFilePath: '/tmp/studio_palette.png',
                  format: SecretlyStickerFormat.png,
                  animated: false,
                  emojiHint: '🎨',
                  label: 'Palette',
                  keywords: <String>['palette', 'design'],
                ),
              ],
            ),
          ]);

          final remoteResolved = SecretlyStickerCatalog.resolveEvent(
            StickerEventV1(
              eventId: 'remote-1',
              packId: 'winter_pack',
              packVersion: 1,
              stickerId: 'winter_santa',
              emojiHint: '🎅',
              label: 'Santa',
              animated: false,
              format: 'png',
            ),
          );

          expect(
            remoteResolved.assetSource,
            SecretlyStickerAssetSource.missing,
          );
          expect(remoteResolved.label, 'Santa');

          // Remote packs (installed or not) are no longer searchable — the
          // picker is user-packs-only now.
          final searchResults = SecretlyStickerCatalog.search('palette');
          expect(
            searchResults.any((item) => item.packId == 'studio_pack'),
            isFalse,
          );
          expect(
            searchResults.any((item) => item.packId == 'winter_pack'),
            isFalse,
          );
          expect(
            SecretlyStickerCatalog.pickerPacks.any(
              (pack) => pack.id == 'studio_pack',
            ),
            isFalse,
          );
        } finally {
          SecretlyStickerCatalog.clearRemoteCatalog();
        }
      },
    );

    test('category chips and remote packs are fully removed from the picker', () {
      SecretlyStickerCatalog.clearRemoteCatalog();
      try {
        SecretlyStickerCatalog.applyRemoteCatalog(<SecretlyStickerPack>[
          SecretlyStickerPack(
            id: 'twemoji_faces',
            version: 1,
            title: 'Twemoji Faces',
            description: 'Remote face pack',
            iconStickerId: 'grin',
            iconEmojiHint: '😀',
            installed: true,
            origin: SecretlyStickerPackOrigin.remote,
            tags: const <String>[
              'remote',
              'unicode',
              'vendor:twemoji',
              'category:faces_emotion',
            ],
            stickers: <SecretlyStickerDescriptor>[
              SecretlyStickerDescriptor.localFile(
                packId: 'twemoji_faces',
                packVersion: 1,
                stickerId: 'grin',
                localFilePath: '/tmp/twemoji_grin.png',
                format: SecretlyStickerFormat.png,
                animated: false,
                emojiHint: '😀',
                label: 'Grinning Face',
                keywords: <String>['grin', 'face', 'smile'],
              ),
            ],
          ),
          SecretlyStickerPack(
            id: 'noto_objects',
            version: 1,
            title: 'Noto Objects',
            description: 'Remote object pack',
            iconStickerId: 'lamp',
            iconEmojiHint: '💡',
            installed: true,
            origin: SecretlyStickerPackOrigin.remote,
            tags: const <String>[
              'remote',
              'unicode',
              'vendor:noto',
              'category:objects',
            ],
            stickers: <SecretlyStickerDescriptor>[
              SecretlyStickerDescriptor.localFile(
                packId: 'noto_objects',
                packVersion: 1,
                stickerId: 'lamp',
                localFilePath: '/tmp/noto_lamp.png',
                format: SecretlyStickerFormat.png,
                animated: false,
                emojiHint: '💡',
                label: 'Lamp',
                keywords: <String>['lamp', 'light'],
              ),
            ],
          ),
        ]);

        // Category chips were removed from the picker (they were never wired to
        // real bundled packs); categoriesForPacks now resolves to nothing even
        // when packs carry category tags.
        final categories = SecretlyStickerCatalog.categoriesForPacks(
          SecretlyStickerCatalog.pickerPacks,
        );
        expect(categories, isEmpty);

        // Remote packs are no longer offered in the picker, so neither category
        // filtering nor picker search surface them anymore.
        final facePacks = SecretlyStickerCatalog.filterPacksByCategory(
          SecretlyStickerCatalog.pickerPacks,
          'category:faces_emotion',
        );
        expect(facePacks, isEmpty);

        final faceSearch = SecretlyStickerCatalog.search(
          'grin',
          categoryTag: 'category:faces_emotion',
        );
        expect(faceSearch, isEmpty);

        final objectSearch = SecretlyStickerCatalog.search(
          'lamp',
          categoryTag: 'category:faces_emotion',
        );
        expect(objectSearch, isEmpty);
      } finally {
        SecretlyStickerCatalog.clearRemoteCatalog();
      }
    });

    test('user packs are offered in the picker; server packs are not', () {
      SecretlyStickerCatalog.clearRemoteCatalog();
      try {
        SecretlyStickerCatalog.applyRemoteCatalog(<SecretlyStickerPack>[
          SecretlyStickerPack(
            id: 'user:PID7:default',
            version: 1,
            title: 'Мои стикеры',
            description: '',
            iconStickerId: 'mine1',
            iconEmojiHint: '',
            installed: false,
            origin: SecretlyStickerPackOrigin.remote,
            stickers: <SecretlyStickerDescriptor>[
              SecretlyStickerDescriptor.localFile(
                packId: 'user:PID7:default',
                packVersion: 1,
                stickerId: 'mine1',
                localFilePath: '/tmp/mine1.png',
                format: SecretlyStickerFormat.png,
                animated: false,
                emojiHint: '',
                label: '',
                keywords: const <String>[],
              ),
            ],
          ),
          SecretlyStickerPack(
            id: 'server_pack',
            version: 1,
            title: 'Server',
            description: '',
            iconStickerId: 'srv1',
            iconEmojiHint: '',
            installed: true,
            origin: SecretlyStickerPackOrigin.remote,
            stickers: <SecretlyStickerDescriptor>[
              SecretlyStickerDescriptor.localFile(
                packId: 'server_pack',
                packVersion: 1,
                stickerId: 'srv1',
                localFilePath: '/tmp/srv1.png',
                format: SecretlyStickerFormat.png,
                animated: false,
                emojiHint: '',
                label: '',
                keywords: const <String>[],
              ),
            ],
          ),
        ]);
        final ids = SecretlyStickerCatalog.pickerPacks
            .map((pack) => pack.id)
            .toList();
        expect(ids, contains('user:PID7:default'));
        expect(ids, isNot(contains('server_pack')));
      } finally {
        SecretlyStickerCatalog.clearRemoteCatalog();
      }
    });

    test('sticker catalog db deletes stale pack rows and stickers', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.upsertStickerPackSummary(
          packId: 'legacy_pack',
          packVersion: 1,
          title: 'Legacy',
          description: 'Old remote pack',
          iconStickerId: 'legacy_sticker',
          iconEmojiHint: '🧩',
          featuredRank: 10,
          tags: const <String>['remote'],
          stickerCount: 1,
          updatedAtMs: 1000,
        );
        await db.replaceStickerPackStickers(
          packId: 'legacy_pack',
          packVersion: 1,
          stickers: const <StickerPackStickerRecord>[
            (
              packId: 'legacy_pack',
              packVersion: 1,
              stickerId: 'legacy_sticker',
              fileName: 'legacy.png',
              localPath: '',
              format: 'png',
              animated: false,
              emojiHint: '🧩',
              label: 'Legacy',
              keywords: <String>['legacy'],
              sha256B64: 'hash-legacy',
              sizeBytes: 64,
              downloadedAtMs: null,
              lastAccessedAtMs: null,
            ),
          ],
        );

        await db.deleteStickerCatalogPack(
          packId: 'legacy_pack',
          packVersion: 1,
        );

        final packRows = await db.listStickerCatalogPacks();
        final stickerRows = await db.listStickerCatalogStickers(
          packId: 'legacy_pack',
          packVersion: 1,
        );

        expect(packRows.any((pack) => pack.packId == 'legacy_pack'), isFalse);
        expect(stickerRows, isEmpty);
      } finally {
        await db.close();
      }
    });

    test(
      'sticker catalog db preserves installed asset paths across manifest refresh',
      () async {
        final db = await AppDb.openForTesting();
        try {
          await db.upsertStickerPackSummary(
            packId: 'studio_pack',
            packVersion: 1,
            title: 'Studio',
            description: 'Design pack',
            iconStickerId: 'studio_palette',
            iconEmojiHint: '🎨',
            featuredRank: 120,
            tags: const <String>['design', 'remote'],
            stickerCount: 1,
            updatedAtMs: 1000,
          );
          await db.replaceStickerPackStickers(
            packId: 'studio_pack',
            packVersion: 1,
            stickers: const <StickerPackStickerRecord>[
              (
                packId: 'studio_pack',
                packVersion: 1,
                stickerId: 'studio_palette',
                fileName: 'studio_palette.png',
                localPath: '',
                format: 'png',
                animated: false,
                emojiHint: '🎨',
                label: 'Palette',
                keywords: <String>['palette', 'design'],
                sha256B64: 'hash-1',
                sizeBytes: 128,
                downloadedAtMs: null,
                lastAccessedAtMs: null,
              ),
            ],
          );
          await db.updateStickerLocalAsset(
            packId: 'studio_pack',
            packVersion: 1,
            stickerId: 'studio_palette',
            localPath: '/tmp/studio_palette.png',
            downloadedAtMs: 2000,
            lastAccessedAtMs: 3000,
          );
          await db.setStickerPackInstalled(
            packId: 'studio_pack',
            packVersion: 1,
            installed: true,
            installedAtMs: 2000,
          );

          await db.replaceStickerPackStickers(
            packId: 'studio_pack',
            packVersion: 1,
            stickers: const <StickerPackStickerRecord>[
              (
                packId: 'studio_pack',
                packVersion: 1,
                stickerId: 'studio_palette',
                fileName: 'studio_palette.png',
                localPath: '',
                format: 'png',
                animated: false,
                emojiHint: '🎨',
                label: 'Palette V2',
                keywords: <String>['palette', 'creative'],
                sha256B64: 'hash-2',
                sizeBytes: 256,
                downloadedAtMs: null,
                lastAccessedAtMs: null,
              ),
            ],
          );

          final packs = await db.listStickerCatalogPacks();
          final stickers = await db.listStickerCatalogStickers(
            packId: 'studio_pack',
            packVersion: 1,
          );

          expect(packs.single.installed, isTrue);
          expect(packs.single.installedAtMs, 2000);
          expect(stickers.single.localPath, '/tmp/studio_palette.png');
          expect(stickers.single.downloadedAtMs, 2000);
          expect(stickers.single.label, 'Palette V2');
          expect(stickers.single.sha256B64, 'hash-2');
        } finally {
          await db.close();
        }
      },
    );
  });
}
