// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../models/e2e_payload_v1.dart';
import '../ui/app_asset_paths.dart';

/// [webp] is an ANIMATED WebP (full-alpha, multi-frame) — Premium "live"
/// stickers. Flutter's Image widget plays it inline natively (no video_player /
/// per-sticker controller), so it works in dense grids and chat bubbles exactly
/// like a [png]. Encoded on-device via ffmpeg from procedural motion-effect
/// frames; falls back to [png] if the encode is unavailable.
enum SecretlyStickerFormat { png, lottie, webp }

enum SecretlyStickerAssetSource { bundledAsset, file, missing }

enum SecretlyStickerPackOrigin { bundled, remote }

extension SecretlyStickerFormatWire on SecretlyStickerFormat {
  String get wireValue {
    switch (this) {
      case SecretlyStickerFormat.png:
        return 'png';
      case SecretlyStickerFormat.lottie:
        return 'lottie';
      case SecretlyStickerFormat.webp:
        return 'webp';
    }
  }

  /// True for multi-frame ("live") formats that animate when rendered.
  bool get isAnimatedFormat =>
      this == SecretlyStickerFormat.lottie ||
      this == SecretlyStickerFormat.webp;

  static SecretlyStickerFormat fromWire(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'lottie':
        return SecretlyStickerFormat.lottie;
      case 'webp':
        return SecretlyStickerFormat.webp;
      case 'png':
      default:
        return SecretlyStickerFormat.png;
    }
  }
}

class SecretlyStickerDescriptor {
  const SecretlyStickerDescriptor({
    required this.packId,
    required this.packVersion,
    required this.stickerId,
    required this.assetPath,
    required this.format,
    required this.animated,
    required this.emojiHint,
    required this.label,
    required this.keywords,
    this.assetSource = SecretlyStickerAssetSource.bundledAsset,
    this.blobId,
    this.fileKeyB64,
    this.blobAccessTokenB64,
    this.sizeBytes,
    this.width,
    this.height,
  });

  final String packId;
  final int packVersion;
  final String stickerId;
  final String assetPath;
  final SecretlyStickerFormat format;
  final bool animated;
  final String emojiHint;
  final String label;
  final List<String> keywords;
  final SecretlyStickerAssetSource assetSource;

  /// E2EE blob handle for a USER-CREATED sticker's pixels (XChaCha20, like an
  /// attachment). Carried so the send path can emit a self-contained sticker the
  /// recipient downloads + decrypts. All null for catalog/bundled stickers.
  final String? blobId;
  final String? fileKeyB64;
  final String? blobAccessTokenB64;
  final int? sizeBytes;
  final int? width;
  final int? height;

  /// True when this descriptor carries its own pixels via [blobId] (a
  /// user-created sticker) rather than a shared catalog reference.
  bool get hasInlineBlob => (blobId ?? '').isNotEmpty;

  String get lookupKey => '$packId@$packVersion::$stickerId';

  bool get isRenderable =>
      assetSource != SecretlyStickerAssetSource.missing && assetPath.isNotEmpty;

  factory SecretlyStickerDescriptor.localFile({
    required String packId,
    required int packVersion,
    required String stickerId,
    required String localFilePath,
    required SecretlyStickerFormat format,
    required bool animated,
    required String emojiHint,
    required String label,
    required List<String> keywords,
    // When this local-file descriptor also stands for a user sticker that must
    // be shipped E2E, the caller supplies the uploaded blob handle so the send
    // path can embed it in the StickerEventV1.
    String? blobId,
    String? fileKeyB64,
    String? blobAccessTokenB64,
    int? sizeBytes,
    int? width,
    int? height,
  }) {
    return SecretlyStickerDescriptor(
      packId: packId,
      packVersion: packVersion,
      stickerId: stickerId,
      assetPath: localFilePath,
      format: format,
      animated: animated,
      emojiHint: emojiHint,
      label: label,
      keywords: keywords,
      assetSource: SecretlyStickerAssetSource.file,
      blobId: blobId,
      fileKeyB64: fileKeyB64,
      blobAccessTokenB64: blobAccessTokenB64,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
    );
  }

  factory SecretlyStickerDescriptor.placeholder({
    required String packId,
    required int packVersion,
    required String stickerId,
    String emojiHint = '',
    String label = '',
    List<String> keywords = const <String>[],
    SecretlyStickerFormat format = SecretlyStickerFormat.png,
    bool animated = false,
  }) {
    return SecretlyStickerDescriptor(
      packId: packId,
      packVersion: packVersion,
      stickerId: stickerId,
      assetPath: '',
      format: format,
      animated: animated,
      emojiHint: emojiHint,
      label: label,
      keywords: keywords,
      assetSource: SecretlyStickerAssetSource.missing,
    );
  }
}

class SecretlyStickerPack {
  const SecretlyStickerPack({
    required this.id,
    required this.version,
    required this.title,
    required this.iconStickerId,
    required this.stickers,
    this.description = '',
    this.tags = const <String>[],
    this.installed = true,
    this.origin = SecretlyStickerPackOrigin.bundled,
    this.featuredRank,
    this.iconEmojiHint = '',
  });

  final String id;
  final int version;
  final String title;
  final String iconStickerId;
  final List<SecretlyStickerDescriptor> stickers;
  final String description;
  final List<String> tags;
  final bool installed;
  final SecretlyStickerPackOrigin origin;
  final int? featuredRank;
  final String iconEmojiHint;

  bool get isRemoteAvailableOnly =>
      origin == SecretlyStickerPackOrigin.remote && !installed;

  bool get isBundledLegacyIconPack =>
      origin == SecretlyStickerPackOrigin.bundled &&
      stickers.isNotEmpty &&
      stickers.every((sticker) {
        return sticker.assetSource == SecretlyStickerAssetSource.bundledAsset &&
            sticker.format == SecretlyStickerFormat.png &&
            sticker.assetPath.startsWith('${AppAssetPaths.pngIconsDir}/');
      });

  SecretlyStickerDescriptor get iconSticker {
    final explicit = stickers
        .where((sticker) => sticker.stickerId == iconStickerId)
        .firstOrNull;
    if (explicit != null) return explicit;
    final firstSticker = stickers.firstOrNull;
    if (firstSticker != null) return firstSticker;
    return SecretlyStickerDescriptor.placeholder(
      packId: id,
      packVersion: version,
      stickerId: iconStickerId,
      emojiHint: iconEmojiHint,
      label: title,
    );
  }
}

class SecretlyStickerPackCategory {
  const SecretlyStickerPackCategory({
    required this.id,
    required this.tag,
    required this.label,
    required this.emojiHint,
    required this.order,
  });

  final String id;
  final String tag;
  final String label;
  final String emojiHint;
  final int order;
}

abstract final class SecretlyStickerCatalog {
  static const int bundledPackVersion = 1;
  static const String recentPackId = '__recent__';
  static const String categoryTagPrefix = 'category:';
  static const List<SecretlyStickerPackCategory> pickerCategories =
      // Category chips removed — they were never wired to real packs.
      <SecretlyStickerPackCategory>[];

  static final List<SecretlyStickerPack> bundledPacks = <SecretlyStickerPack>[
    SecretlyStickerPack(
      id: 'cookie_pack',
      version: bundledPackVersion,
      title: 'Cookie',
      iconStickerId: 'cookie_hearts',
      stickers: const <SecretlyStickerDescriptor>[
        SecretlyStickerDescriptor(
          packId: 'cookie_pack',
          packVersion: bundledPackVersion,
          stickerId: 'cookie_hearts',
          assetPath: AppAssetPaths.reactionCookieHearts,
          format: SecretlyStickerFormat.lottie,
          animated: true,
          emojiHint: '🥰',
          label: 'Hearts',
          keywords: <String>['love', 'hearts', 'cookie', 'мило', 'любовь'],
        ),
        SecretlyStickerDescriptor(
          packId: 'cookie_pack',
          packVersion: bundledPackVersion,
          stickerId: 'cookie_eyes',
          assetPath: AppAssetPaths.reactionCookieEyes,
          format: SecretlyStickerFormat.lottie,
          animated: true,
          emojiHint: '😁',
          label: 'Eyes',
          keywords: <String>['wow', 'eyes', 'cookie', 'вау', 'восторг'],
        ),
        SecretlyStickerDescriptor(
          packId: 'cookie_pack',
          packVersion: bundledPackVersion,
          stickerId: 'cookie_scared',
          assetPath: AppAssetPaths.reactionCookieScared,
          format: SecretlyStickerFormat.lottie,
          animated: true,
          emojiHint: '😱',
          label: 'Scared',
          keywords: <String>['panic', 'shock', 'cookie', 'шок', 'паника'],
        ),
        SecretlyStickerDescriptor(
          packId: 'cookie_pack',
          packVersion: bundledPackVersion,
          stickerId: 'cookie_angry',
          assetPath: AppAssetPaths.reactionCookieAngry,
          format: SecretlyStickerFormat.lottie,
          animated: true,
          emojiHint: '😡',
          label: 'Angry',
          keywords: <String>['angry', 'mad', 'cookie', 'злой', 'ярость'],
        ),
        SecretlyStickerDescriptor(
          packId: 'cookie_pack',
          packVersion: bundledPackVersion,
          stickerId: 'cookie_devil',
          assetPath: AppAssetPaths.reactionCookieDevil,
          format: SecretlyStickerFormat.lottie,
          animated: true,
          emojiHint: '🔥',
          label: 'Devil',
          keywords: <String>['fire', 'devil', 'cookie', 'огонь', 'дьявол'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'hearts_pack',
      version: bundledPackVersion,
      title: 'Love',
      iconStickerId: 'heart_primary',
      stickers: const <SecretlyStickerDescriptor>[
        SecretlyStickerDescriptor(
          packId: 'hearts_pack',
          packVersion: bundledPackVersion,
          stickerId: 'heart_primary',
          assetPath: '${AppAssetPaths.pngIconsDir}/037-heart.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '❤️',
          label: 'Heart',
          keywords: <String>['heart', 'love', 'сердце', 'любовь'],
        ),
        SecretlyStickerDescriptor(
          packId: 'hearts_pack',
          packVersion: bundledPackVersion,
          stickerId: 'heart_soft',
          assetPath: '${AppAssetPaths.pngIconsDir}/041-heart-1.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '💖',
          label: 'Soft Heart',
          keywords: <String>['heart', 'cute', 'мило', 'сердце'],
        ),
        SecretlyStickerDescriptor(
          packId: 'hearts_pack',
          packVersion: bundledPackVersion,
          stickerId: 'heart_bright',
          assetPath: '${AppAssetPaths.pngIconsDir}/043-heart-2.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '💘',
          label: 'Bright Heart',
          keywords: <String>['heart', 'spark', 'искры', 'сердце'],
        ),
        SecretlyStickerDescriptor(
          packId: 'hearts_pack',
          packVersion: bundledPackVersion,
          stickerId: 'heart_ribbon',
          assetPath: '${AppAssetPaths.pngIconsDir}/060-heart.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '💝',
          label: 'Gift Heart',
          keywords: <String>['gift', 'heart', 'подарок', 'любовь'],
        ),
        SecretlyStickerDescriptor(
          packId: 'hearts_pack',
          packVersion: bundledPackVersion,
          stickerId: 'heart_duo',
          assetPath: '${AppAssetPaths.pngIconsDir}/100-heart-1.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '💕',
          label: 'Duo Heart',
          keywords: <String>['duo', 'heart', 'двойное сердце'],
        ),
        SecretlyStickerDescriptor(
          packId: 'hearts_pack',
          packVersion: bundledPackVersion,
          stickerId: 'heart_flare',
          assetPath: '${AppAssetPaths.pngIconsDir}/105-heart-2.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '💓',
          label: 'Heart Flare',
          keywords: <String>['heart', 'flare', 'сияние', 'сердце'],
        ),
        SecretlyStickerDescriptor(
          packId: 'hearts_pack',
          packVersion: bundledPackVersion,
          stickerId: 'heart_locked',
          assetPath: '${AppAssetPaths.pngIconsDir}/150-heart-3.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '💞',
          label: 'Locked Heart',
          keywords: <String>['heart', 'locked', 'сердце', 'навсегда'],
        ),
        SecretlyStickerDescriptor(
          packId: 'hearts_pack',
          packVersion: bundledPackVersion,
          stickerId: 'heart_secret',
          assetPath: '${AppAssetPaths.pngIconsDir}/152-heart-4.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '💗',
          label: 'Secret Heart',
          keywords: <String>['secret', 'heart', 'сердце', 'секрет'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'party_pack',
      version: bundledPackVersion,
      title: 'Party',
      iconStickerId: 'party_confetti',
      stickers: const <SecretlyStickerDescriptor>[
        SecretlyStickerDescriptor(
          packId: 'party_pack',
          packVersion: bundledPackVersion,
          stickerId: 'party_confetti',
          assetPath: '${AppAssetPaths.pngIconsDir}/035-confetti.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '🎉',
          label: 'Confetti',
          keywords: <String>['party', 'confetti', 'вечеринка', 'ура'],
        ),
        SecretlyStickerDescriptor(
          packId: 'party_pack',
          packVersion: bundledPackVersion,
          stickerId: 'party_balloons',
          assetPath: '${AppAssetPaths.pngIconsDir}/033-balloons.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '🎈',
          label: 'Balloons',
          keywords: <String>['party', 'balloons', 'шары', 'праздник'],
        ),
        SecretlyStickerDescriptor(
          packId: 'party_pack',
          packVersion: bundledPackVersion,
          stickerId: 'party_firework',
          assetPath: '${AppAssetPaths.pngIconsDir}/064-firework.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '✨',
          label: 'Firework',
          keywords: <String>['firework', 'party', 'салют', 'искры'],
        ),
        SecretlyStickerDescriptor(
          packId: 'party_pack',
          packVersion: bundledPackVersion,
          stickerId: 'party_discoball',
          assetPath: '${AppAssetPaths.pngIconsDir}/084-disco-ball.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '🪩',
          label: 'Disco',
          keywords: <String>['disco', 'party', 'танцы', 'дискотека'],
        ),
        SecretlyStickerDescriptor(
          packId: 'party_pack',
          packVersion: bundledPackVersion,
          stickerId: 'party_star',
          assetPath: '${AppAssetPaths.pngIconsDir}/103-star.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '⭐',
          label: 'Star',
          keywords: <String>['star', 'party', 'звезда', 'сияние'],
        ),
        SecretlyStickerDescriptor(
          packId: 'party_pack',
          packVersion: bundledPackVersion,
          stickerId: 'party_confetti_bright',
          assetPath: '${AppAssetPaths.pngIconsDir}/108-confetti.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '🥳',
          label: 'Bright Confetti',
          keywords: <String>['confetti', 'party', 'ярко', 'ура'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'space_pack',
      version: bundledPackVersion,
      title: 'Space',
      iconStickerId: 'space_astronaut',
      stickers: const <SecretlyStickerDescriptor>[
        SecretlyStickerDescriptor(
          packId: 'space_pack',
          packVersion: bundledPackVersion,
          stickerId: 'space_astronaut',
          assetPath: '${AppAssetPaths.pngIconsDir}/111-astronaut.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '🚀',
          label: 'Astronaut',
          keywords: <String>['space', 'astronaut', 'космос', 'астронавт'],
        ),
        SecretlyStickerDescriptor(
          packId: 'space_pack',
          packVersion: bundledPackVersion,
          stickerId: 'space_blackhole',
          assetPath: '${AppAssetPaths.pngIconsDir}/110-black-hole.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '🌀',
          label: 'Black Hole',
          keywords: <String>['space', 'black hole', 'космос', 'черная дыра'],
        ),
        SecretlyStickerDescriptor(
          packId: 'space_pack',
          packVersion: bundledPackVersion,
          stickerId: 'space_meteorite',
          assetPath: '${AppAssetPaths.pngIconsDir}/112-meteorite.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '☄️',
          label: 'Meteorite',
          keywords: <String>['space', 'meteor', 'космос', 'метеор'],
        ),
        SecretlyStickerDescriptor(
          packId: 'space_pack',
          packVersion: bundledPackVersion,
          stickerId: 'space_earth',
          assetPath: '${AppAssetPaths.pngIconsDir}/113-earth-2.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '🌍',
          label: 'Earth',
          keywords: <String>['space', 'earth', 'земля', 'космос'],
        ),
        SecretlyStickerDescriptor(
          packId: 'space_pack',
          packVersion: bundledPackVersion,
          stickerId: 'space_planet',
          assetPath: '${AppAssetPaths.pngIconsDir}/114-planet.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '🪐',
          label: 'Planet',
          keywords: <String>['space', 'planet', 'планета', 'космос'],
        ),
        SecretlyStickerDescriptor(
          packId: 'space_pack',
          packVersion: bundledPackVersion,
          stickerId: 'space_sun',
          assetPath: '${AppAssetPaths.pngIconsDir}/146-sun.png',
          format: SecretlyStickerFormat.png,
          animated: false,
          emojiHint: '☀️',
          label: 'Sun',
          keywords: <String>['space', 'sun', 'солнце', 'космос'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'wins_pack',
      version: bundledPackVersion,
      title: 'Wins',
      iconStickerId: 'wins_trophy',
      stickers: <SecretlyStickerDescriptor>[
        _pngSticker(
          packId: 'wins_pack',
          stickerId: 'wins_trophy',
          fileName: '007-trophy.png',
          emojiHint: '🏆',
          label: 'Trophy',
          keywords: const <String>[
            'win',
            'champion',
            'victory',
            'победа',
            'кубок',
          ],
        ),
        _pngSticker(
          packId: 'wins_pack',
          stickerId: 'wins_ribbon',
          fileName: '028-1st-place-ribbon.png',
          emojiHint: '🥇',
          label: 'Ribbon',
          keywords: const <String>[
            'first place',
            'winner',
            'лента',
            'первое место',
          ],
        ),
        _pngSticker(
          packId: 'wins_pack',
          stickerId: 'wins_medal',
          fileName: '091-medal.png',
          emojiHint: '🏅',
          label: 'Medal',
          keywords: const <String>['medal', 'award', 'награда', 'медаль'],
        ),
        _pngSticker(
          packId: 'wins_pack',
          stickerId: 'wins_cup_one',
          fileName: '092-trophy-1.png',
          emojiHint: '🏆',
          label: 'Cup One',
          keywords: const <String>['cup', 'trophy', 'кубок'],
        ),
        _pngSticker(
          packId: 'wins_pack',
          stickerId: 'wins_cup_two',
          fileName: '093-trophy-2.png',
          emojiHint: '🏆',
          label: 'Cup Two',
          keywords: const <String>['cup', 'trophy', 'кубок'],
        ),
        _pngSticker(
          packId: 'wins_pack',
          stickerId: 'wins_gold_medal',
          fileName: '167-gold-medal.png',
          emojiHint: '🥇',
          label: 'Gold Medal',
          keywords: const <String>['gold', 'medal', 'золото', 'медаль'],
        ),
        _pngSticker(
          packId: 'wins_pack',
          stickerId: 'wins_champion_cup',
          fileName: '168-trophy-3.png',
          emojiHint: '🏆',
          label: 'Champion Cup',
          keywords: const <String>['champion', 'cup', 'чемпион'],
        ),
        _pngSticker(
          packId: 'wins_pack',
          stickerId: 'wins_grand_trophy',
          fileName: '169-trophy-4.png',
          emojiHint: '🏆',
          label: 'Grand Trophy',
          keywords: const <String>['grand', 'trophy', 'трофей'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'mood_pack',
      version: bundledPackVersion,
      title: 'Mood',
      iconStickerId: 'mood_smile',
      stickers: <SecretlyStickerDescriptor>[
        _pngSticker(
          packId: 'mood_pack',
          stickerId: 'mood_smile',
          fileName: '137-smile.png',
          emojiHint: '😊',
          label: 'Smile',
          keywords: const <String>['smile', 'happy', 'улыбка', 'радость'],
        ),
        _pngSticker(
          packId: 'mood_pack',
          stickerId: 'mood_passion',
          fileName: '155-passion.png',
          emojiHint: '😍',
          label: 'Passion',
          keywords: const <String>['passion', 'love', 'страсть', 'влюблен'],
        ),
        _pngSticker(
          packId: 'mood_pack',
          stickerId: 'mood_couple',
          fileName: '061-couple.png',
          emojiHint: '🫶',
          label: 'Couple',
          keywords: const <String>['couple', 'together', 'пара', 'вместе'],
        ),
        _pngSticker(
          packId: 'mood_pack',
          stickerId: 'mood_peace',
          fileName: '107-peace.png',
          emojiHint: '✌️',
          label: 'Peace',
          keywords: const <String>['peace', 'calm', 'мир', 'спокойно'],
        ),
        _pngSticker(
          packId: 'mood_pack',
          stickerId: 'mood_devil',
          fileName: '154-devil.png',
          emojiHint: '😈',
          label: 'Devil',
          keywords: const <String>['devil', 'spicy', 'дьявол', 'хитро'],
        ),
        _pngSticker(
          packId: 'mood_pack',
          stickerId: 'mood_parade',
          fileName: '059-parade.png',
          emojiHint: '🎊',
          label: 'Parade',
          keywords: const <String>['parade', 'party', 'парад', 'праздник'],
        ),
        _pngSticker(
          packId: 'mood_pack',
          stickerId: 'mood_love',
          fileName: '058-love.png',
          emojiHint: '💞',
          label: 'Love',
          keywords: const <String>['love', 'heart', 'любовь', 'сердце'],
        ),
        _pngSticker(
          packId: 'mood_pack',
          stickerId: 'mood_lily',
          fileName: '030-lilly.png',
          emojiHint: '🌸',
          label: 'Lily',
          keywords: const <String>['flower', 'lily', 'лилия', 'нежность'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'speed_pack',
      version: bundledPackVersion,
      title: 'Speed',
      iconStickerId: 'speed_rocket',
      stickers: <SecretlyStickerDescriptor>[
        _pngSticker(
          packId: 'speed_pack',
          stickerId: 'speed_rocket',
          fileName: '008-rocket.png',
          emojiHint: '🚀',
          label: 'Rocket',
          keywords: const <String>['rocket', 'fast', 'ракета', 'быстро'],
        ),
        _pngSticker(
          packId: 'speed_pack',
          stickerId: 'speed_launch',
          fileName: '009-rocket-launch.png',
          emojiHint: '🚀',
          label: 'Launch',
          keywords: const <String>['launch', 'go', 'старт', 'взлет'],
        ),
        _pngSticker(
          packId: 'speed_pack',
          stickerId: 'speed_turbo',
          fileName: '025-turbo.png',
          emojiHint: '⚡',
          label: 'Turbo',
          keywords: const <String>['turbo', 'boost', 'турбо', 'ускорение'],
        ),
        _pngSticker(
          packId: 'speed_pack',
          stickerId: 'speed_racing',
          fileName: '032-racing.png',
          emojiHint: '🏎️',
          label: 'Racing',
          keywords: const <String>['racing', 'speed', 'гонки', 'скорость'],
        ),
        _pngSticker(
          packId: 'speed_pack',
          stickerId: 'speed_shift',
          fileName: '031-gear-shift.png',
          emojiHint: '🏁',
          label: 'Shift',
          keywords: const <String>['gear', 'shift', 'передача', 'гонка'],
        ),
        _pngSticker(
          packId: 'speed_pack',
          stickerId: 'speed_tire',
          fileName: '024-tire.png',
          emojiHint: '🛞',
          label: 'Tire',
          keywords: const <String>['tire', 'wheel', 'шина', 'колесо'],
        ),
        _pngSticker(
          packId: 'speed_pack',
          stickerId: 'speed_ecocar',
          fileName: '174-eco-car.png',
          emojiHint: '🚗',
          label: 'Eco Car',
          keywords: const <String>['car', 'eco', 'машина', 'авто'],
        ),
        _pngSticker(
          packId: 'speed_pack',
          stickerId: 'speed_battery',
          fileName: '160-car-battery.png',
          emojiHint: '🔋',
          label: 'Battery',
          keywords: const <String>['battery', 'power', 'батарея', 'энергия'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'nature_pack',
      version: bundledPackVersion,
      title: 'Nature',
      iconStickerId: 'nature_tree',
      stickers: <SecretlyStickerDescriptor>[
        _pngSticker(
          packId: 'nature_pack',
          stickerId: 'nature_tree',
          fileName: '119-tree.png',
          emojiHint: '🌳',
          label: 'Tree',
          keywords: const <String>['tree', 'nature', 'дерево', 'природа'],
        ),
        _pngSticker(
          packId: 'nature_pack',
          stickerId: 'nature_forest',
          fileName: '086-trees.png',
          emojiHint: '🌲',
          label: 'Forest',
          keywords: const <String>['forest', 'woods', 'лес', 'деревья'],
        ),
        _pngSticker(
          packId: 'nature_pack',
          stickerId: 'nature_earth',
          fileName: '055-earth.png',
          emojiHint: '🌍',
          label: 'Earth',
          keywords: const <String>['earth', 'world', 'земля', 'мир'],
        ),
        _pngSticker(
          packId: 'nature_pack',
          stickerId: 'nature_sun',
          fileName: '146-sun.png',
          emojiHint: '☀️',
          label: 'Sun',
          keywords: const <String>['sun', 'warm', 'солнце', 'тепло'],
        ),
        _pngSticker(
          packId: 'nature_pack',
          stickerId: 'nature_flower',
          fileName: '156-flower.png',
          emojiHint: '🌼',
          label: 'Flower',
          keywords: const <String>['flower', 'bloom', 'цветок', 'весна'],
        ),
        _pngSticker(
          packId: 'nature_pack',
          stickerId: 'nature_tulip',
          fileName: '118-tulip.png',
          emojiHint: '🌷',
          label: 'Tulip',
          keywords: const <String>['tulip', 'flower', 'тюльпан', 'цветок'],
        ),
        _pngSticker(
          packId: 'nature_pack',
          stickerId: 'nature_cherry',
          fileName: '120-cherry.png',
          emojiHint: '🍒',
          label: 'Cherry',
          keywords: const <String>['cherry', 'fruit', 'вишня', 'ягода'],
        ),
        _pngSticker(
          packId: 'nature_pack',
          stickerId: 'nature_umbrella',
          fileName: '056-umbrella.png',
          emojiHint: '☔',
          label: 'Umbrella',
          keywords: const <String>['umbrella', 'rain', 'зонт', 'дождь'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'secret_pack',
      version: bundledPackVersion,
      title: 'Secret',
      iconStickerId: 'secret_fingerprint',
      stickers: <SecretlyStickerDescriptor>[
        _pngSticker(
          packId: 'secret_pack',
          stickerId: 'secret_fingerprint',
          fileName: '127-fingerprint.png',
          emojiHint: '🫆',
          label: 'Fingerprint',
          keywords: const <String>[
            'fingerprint',
            'identity',
            'отпечаток',
            'личность',
          ],
        ),
        _pngSticker(
          packId: 'secret_pack',
          stickerId: 'secret_locked',
          fileName: '151-locked.png',
          emojiHint: '🔒',
          label: 'Locked',
          keywords: const <String>['lock', 'closed', 'замок', 'закрыто'],
        ),
        _pngSticker(
          packId: 'secret_pack',
          stickerId: 'secret_key',
          fileName: '153-key.png',
          emojiHint: '🔑',
          label: 'Key',
          keywords: const <String>['key', 'access', 'ключ', 'доступ'],
        ),
        _pngSticker(
          packId: 'secret_pack',
          stickerId: 'secret_password',
          fileName: '136-password.png',
          emojiHint: '🔐',
          label: 'Password',
          keywords: const <String>['password', 'secret', 'пароль', 'секрет'],
        ),
        _pngSticker(
          packId: 'secret_pack',
          stickerId: 'secret_shield',
          fileName: '135-cyber-security.png',
          emojiHint: '🛡️',
          label: 'Shield',
          keywords: const <String>['shield', 'security', 'щит', 'защита'],
        ),
        _pngSticker(
          packId: 'secret_pack',
          stickerId: 'secret_hidden',
          fileName: '128-hidden.png',
          emojiHint: '🕵️',
          label: 'Hidden',
          keywords: const <String>['hidden', 'spy', 'скрыто', 'шпион'],
        ),
        _pngSticker(
          packId: 'secret_pack',
          stickerId: 'secret_cctv',
          fileName: '170-cctv-1.png',
          emojiHint: '📹',
          label: 'CCTV',
          keywords: const <String>['camera', 'cctv', 'камера', 'наблюдение'],
        ),
        _pngSticker(
          packId: 'secret_pack',
          stickerId: 'secret_spyware',
          fileName: '194-spyware.png',
          emojiHint: '🕶️',
          label: 'Spyware',
          keywords: const <String>['spyware', 'spy', 'шпион', 'слежка'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'travel_pack',
      version: bundledPackVersion,
      title: 'Travel',
      iconStickerId: 'travel_plane',
      stickers: <SecretlyStickerDescriptor>[
        _pngSticker(
          packId: 'travel_pack',
          stickerId: 'travel_plane',
          fileName: '172-airplane.png',
          emojiHint: '✈️',
          label: 'Airplane',
          keywords: const <String>['plane', 'travel', 'самолет', 'путешествие'],
        ),
        _pngSticker(
          packId: 'travel_pack',
          stickerId: 'travel_maps',
          fileName: '074-maps.png',
          emojiHint: '🗺️',
          label: 'Maps',
          keywords: const <String>['maps', 'route', 'карта', 'маршрут'],
        ),
        _pngSticker(
          packId: 'travel_pack',
          stickerId: 'travel_transport',
          fileName: '069-transport.png',
          emojiHint: '🚕',
          label: 'Transport',
          keywords: const <String>['transport', 'ride', 'транспорт', 'поездка'],
        ),
        _pngSticker(
          packId: 'travel_pack',
          stickerId: 'travel_van',
          fileName: '082-surf-van.png',
          emojiHint: '🚐',
          label: 'Surf Van',
          keywords: const <String>['van', 'trip', 'фургон', 'дорога'],
        ),
        _pngSticker(
          packId: 'travel_pack',
          stickerId: 'travel_home',
          fileName: '125-house.png',
          emojiHint: '🏡',
          label: 'Home',
          keywords: const <String>['home', 'house', 'дом', 'уют'],
        ),
        _pngSticker(
          packId: 'travel_pack',
          stickerId: 'travel_location',
          fileName: '142-location.png',
          emojiHint: '📍',
          label: 'Location',
          keywords: const <String>['location', 'pin', 'гео', 'локация'],
        ),
        _pngSticker(
          packId: 'travel_pack',
          stickerId: 'travel_smarthouse',
          fileName: '175-smart-house.png',
          emojiHint: '🏠',
          label: 'Smart House',
          keywords: const <String>['house', 'smart', 'дом', 'умный дом'],
        ),
        _pngSticker(
          packId: 'travel_pack',
          stickerId: 'travel_tracker',
          fileName: '126-gps-tracker.png',
          emojiHint: '📡',
          label: 'Tracker',
          keywords: const <String>['gps', 'tracker', 'трекер', 'координаты'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'art_pack',
      version: bundledPackVersion,
      title: 'Art',
      iconStickerId: 'art_brush',
      stickers: <SecretlyStickerDescriptor>[
        _pngSticker(
          packId: 'art_pack',
          stickerId: 'art_brush',
          fileName: '177-brush.png',
          emojiHint: '🖌️',
          label: 'Brush',
          keywords: const <String>['brush', 'paint', 'кисть', 'рисование'],
        ),
        _pngSticker(
          packId: 'art_pack',
          stickerId: 'art_creative',
          fileName: '116-creative.png',
          emojiHint: '🎨',
          label: 'Creative',
          keywords: const <String>['creative', 'art', 'креатив', 'арт'],
        ),
        _pngSticker(
          packId: 'art_pack',
          stickerId: 'art_day',
          fileName: '117-world-art-day.png',
          emojiHint: '🖼️',
          label: 'Art Day',
          keywords: const <String>[
            'art day',
            'picture',
            'искусство',
            'картина',
          ],
        ),
        _pngSticker(
          packId: 'art_pack',
          stickerId: 'art_idea',
          fileName: '157-light-bulb-1.png',
          emojiHint: '💡',
          label: 'Idea',
          keywords: const <String>['idea', 'thought', 'идея', 'мысль'],
        ),
        _pngSticker(
          packId: 'art_pack',
          stickerId: 'art_bright_idea',
          fileName: '158-light-bulb-2.png',
          emojiHint: '✨',
          label: 'Bright Idea',
          keywords: const <String>['idea', 'bright', 'озарение', 'вдохновение'],
        ),
        _pngSticker(
          packId: 'art_pack',
          stickerId: 'art_shape',
          fileName: '178-shape.png',
          emojiHint: '◼️',
          label: 'Shape',
          keywords: const <String>['shape', 'abstract', 'форма', 'абстракция'],
        ),
        _pngSticker(
          packId: 'art_pack',
          stickerId: 'art_mosaic',
          fileName: '179-shape-1.png',
          emojiHint: '🔷',
          label: 'Mosaic',
          keywords: const <String>['mosaic', 'shape', 'мозаика', 'узор'],
        ),
        _pngSticker(
          packId: 'art_pack',
          stickerId: 'art_pattern',
          fileName: '180-shape-2.png',
          emojiHint: '🔶',
          label: 'Pattern',
          keywords: const <String>['pattern', 'shape', 'паттерн', 'узор'],
        ),
      ],
    ),
    SecretlyStickerPack(
      id: 'magic_pack',
      version: bundledPackVersion,
      title: 'Magic',
      iconStickerId: 'magic_ball',
      stickers: <SecretlyStickerDescriptor>[
        _pngSticker(
          packId: 'magic_pack',
          stickerId: 'magic_ball',
          fileName: '183-crystal-ball.png',
          emojiHint: '🔮',
          label: 'Crystal Ball',
          keywords: const <String>['magic', 'crystal ball', 'магия', 'шар'],
        ),
        _pngSticker(
          packId: 'magic_pack',
          stickerId: 'magic_book',
          fileName: '145-spell-book.png',
          emojiHint: '📕',
          label: 'Spell Book',
          keywords: const <String>['spell', 'book', 'заклинание', 'книга'],
        ),
        _pngSticker(
          packId: 'magic_pack',
          stickerId: 'magic_shaman',
          fileName: '046-shaman.png',
          emojiHint: '🪄',
          label: 'Shaman',
          keywords: const <String>['shaman', 'ritual', 'шаман', 'ритуал'],
        ),
        _pngSticker(
          packId: 'magic_pack',
          stickerId: 'magic_viking',
          fileName: '047-viking.png',
          emojiHint: '⚔️',
          label: 'Viking',
          keywords: const <String>['viking', 'warrior', 'викинг', 'воин'],
        ),
        _pngSticker(
          packId: 'magic_pack',
          stickerId: 'magic_fire',
          fileName: '184-fire.png',
          emojiHint: '🔥',
          label: 'Fire',
          keywords: const <String>['fire', 'flame', 'огонь', 'пламя'],
        ),
        _pngSticker(
          packId: 'magic_pack',
          stickerId: 'magic_mars',
          fileName: '185-mars.png',
          emojiHint: '🔴',
          label: 'Mars',
          keywords: const <String>['mars', 'planet', 'марс', 'космос'],
        ),
        _pngSticker(
          packId: 'magic_pack',
          stickerId: 'magic_sagittarius',
          fileName: '186-sagittarius.png',
          emojiHint: '♐',
          label: 'Sagittarius',
          keywords: const <String>[
            'sagittarius',
            'zodiac',
            'стрелец',
            'зодиак',
          ],
        ),
        _pngSticker(
          packId: 'magic_pack',
          stickerId: 'magic_hexagram',
          fileName: '148-hexagram.png',
          emojiHint: '✨',
          label: 'Hexagram',
          keywords: const <String>[
            'hexagram',
            'symbol',
            'гексаграмма',
            'символ',
          ],
        ),
      ],
    ),
  ];

  // The picker now offers NO bundled packs — only the user's own «Мои стикеры»
  // packs (+ recents). bundledPacks stays defined below purely for back-compat
  // resolution of already-sent bundled stickers via the lookup maps.
  static const List<SecretlyStickerPack> bundledPickerPacks =
      <SecretlyStickerPack>[];

  static List<SecretlyStickerPack> _remotePacks = const <SecretlyStickerPack>[];
  static List<SecretlyStickerPack> _lookupPacks =
      List<SecretlyStickerPack>.unmodifiable(bundledPacks);
  static List<SecretlyStickerPack> _installedPacks =
      List<SecretlyStickerPack>.unmodifiable(bundledPickerPacks);
  static List<SecretlyStickerPack> _pickerPacks =
      List<SecretlyStickerPack>.unmodifiable(bundledPickerPacks);
  static Map<String, SecretlyStickerPack> _packsByLookupKey =
      <String, SecretlyStickerPack>{
        for (final pack in bundledPacks)
          _packLookupKey(pack.id, pack.version): pack,
      };
  static Map<String, SecretlyStickerDescriptor> _stickersByLookupKey =
      <String, SecretlyStickerDescriptor>{
        for (final pack in bundledPacks)
          for (final sticker in pack.stickers) sticker.lookupKey: sticker,
      };
  static List<SecretlyStickerDescriptor> _searchableStickers =
      List<SecretlyStickerDescriptor>.unmodifiable(<SecretlyStickerDescriptor>[
        for (final pack in bundledPickerPacks)
          for (final sticker in pack.stickers)
            if (sticker.isRenderable) sticker,
      ]);

  static String get defaultPickerPackId =>
      bundledPickerPacks.firstOrNull?.id ?? recentPackId;

  static List<SecretlyStickerPack> get pickerPacks => _pickerPacks;

  static List<SecretlyStickerPack> get installedPacks => _installedPacks;

  static List<SecretlyStickerDescriptor> get allStickers => _searchableStickers;

  static List<SecretlyStickerPackCategory> categoriesForPacks(
    Iterable<SecretlyStickerPack> packs,
  ) {
    final tags = <String>{
      for (final pack in packs)
        ...pack.tags.where((tag) => tag.startsWith(categoryTagPrefix)),
    };
    final orderByTag = <String, int>{
      for (final category in pickerCategories) category.tag: category.order,
    };
    final categories = pickerCategories
        .where((category) => tags.contains(category.tag))
        .toList(growable: false);
    categories.sort(
      (a, b) => (orderByTag[a.tag] ?? 1 << 20).compareTo(
        orderByTag[b.tag] ?? 1 << 20,
      ),
    );
    return categories;
  }

  static List<SecretlyStickerPack> filterPacksByCategory(
    Iterable<SecretlyStickerPack> packs,
    String? categoryTag,
  ) {
    final normalizedCategory = _normalizeCategoryTag(categoryTag);
    if (normalizedCategory == null) {
      return packs.toList(growable: false);
    }
    return packs
        .where((pack) => packMatchesCategory(pack, normalizedCategory))
        .toList(growable: false);
  }

  static List<SecretlyStickerDescriptor> filterStickersByCategory(
    Iterable<SecretlyStickerDescriptor> stickers,
    String? categoryTag,
  ) {
    final normalizedCategory = _normalizeCategoryTag(categoryTag);
    if (normalizedCategory == null) {
      return stickers.toList(growable: false);
    }
    return stickers
        .where((sticker) => stickerMatchesCategory(sticker, normalizedCategory))
        .toList(growable: false);
  }

  static bool packMatchesCategory(
    SecretlyStickerPack pack,
    String? categoryTag,
  ) {
    final normalizedCategory = _normalizeCategoryTag(categoryTag);
    if (normalizedCategory == null) return true;
    return pack.tags.contains(normalizedCategory);
  }

  static bool stickerMatchesCategory(
    SecretlyStickerDescriptor sticker,
    String? categoryTag,
  ) {
    final normalizedCategory = _normalizeCategoryTag(categoryTag);
    if (normalizedCategory == null) return true;
    final pack =
        _packsByLookupKey[_packLookupKey(sticker.packId, sticker.packVersion)];
    return pack?.tags.contains(normalizedCategory) == true;
  }

  static void applyRemoteCatalog(Iterable<SecretlyStickerPack> remotePacks) {
    _remotePacks = remotePacks.toList(growable: false);
    _rebuildRuntimeIndexes();
  }

  static void clearRemoteCatalog() {
    _remotePacks = const <SecretlyStickerPack>[];
    _rebuildRuntimeIndexes();
  }

  static SecretlyStickerPack? pickerPackById(String packId) {
    final normalized = packId.trim();
    if (normalized.isEmpty) return null;
    return _pickerPacks.where((pack) => pack.id == normalized).firstOrNull;
  }

  static SecretlyStickerDescriptor? findSticker({
    required String packId,
    required int packVersion,
    required String stickerId,
  }) {
    final direct = _stickersByLookupKey['$packId@$packVersion::$stickerId'];
    if (direct != null) return direct;
    return _lookupPacks.expand((pack) => pack.stickers).where((sticker) {
      return sticker.packId == packId && sticker.stickerId == stickerId;
    }).firstOrNull;
  }

  static SecretlyStickerDescriptor resolveEvent(StickerEventV1 event) {
    return findSticker(
          packId: event.packId,
          packVersion: event.packVersion,
          stickerId: event.stickerId,
        ) ??
        SecretlyStickerDescriptor.placeholder(
          packId: event.packId,
          packVersion: event.packVersion,
          stickerId: event.stickerId,
          emojiHint: event.emojiHint,
          label: event.label,
          keywords: const <String>[],
          format: SecretlyStickerFormatWire.fromWire(event.format),
          animated: event.animated,
        );
  }

  static List<SecretlyStickerDescriptor> search(
    String query, {
    String? categoryTag,
  }) {
    final categoryScoped = filterStickersByCategory(allStickers, categoryTag);
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return categoryScoped;
    return categoryScoped
        .where((sticker) {
          if (sticker.emojiHint.contains(normalized)) return true;
          if (sticker.label.toLowerCase().contains(normalized)) return true;
          return sticker.keywords.any(
            (keyword) => keyword.toLowerCase().contains(normalized),
          );
        })
        .toList(growable: false);
  }

  static String previewLabel({
    required bool isRu,
    String? emojiHint,
    String? label,
    String? baseLabel,
  }) {
    final normalizedBase = (baseLabel ?? '').trim();
    var base = normalizedBase;
    if (base.isEmpty) {
      if (isRu) {
        base = 'Стикер';
      } else {
        base = 'Sticker';
      }
    }
    final normalizedEmoji = (emojiHint ?? '').trim();
    if (normalizedEmoji.isNotEmpty) {
      return '$base $normalizedEmoji';
    }
    final normalizedLabel = (label ?? '').trim();
    if (normalizedLabel.isNotEmpty) {
      return '$base · $normalizedLabel';
    }
    return base;
  }

  static void _rebuildRuntimeIndexes() {
    final remoteOrdered = _remotePacks.toList(growable: false)
      ..sort((a, b) {
        final featuredA = a.featuredRank ?? 1 << 20;
        final featuredB = b.featuredRank ?? 1 << 20;
        final featuredCompare = featuredA.compareTo(featuredB);
        if (featuredCompare != 0) return featuredCompare;
        final installCompare = b.installed == a.installed
            ? 0
            : (a.installed ? -1 : 1);
        if (installCompare != 0) return installCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    final visibleBundled = bundledPickerPacks; // empty — clean slate
    // The picker shows ONLY the user's own packs (packId `user:…`). Server
    // catalog packs are kept in _lookupPacks (so historical sends still resolve)
    // but are NOT offered in the picker. Bundled cookie pack is gone too.
    final userPacks = remoteOrdered
        .where((pack) => pack.id.startsWith('user:'))
        .toList(growable: false);
    _lookupPacks = List<SecretlyStickerPack>.unmodifiable(
      _dedupePacks(<SecretlyStickerPack>[...bundledPacks, ...remoteOrdered]),
    );
    _installedPacks = List<SecretlyStickerPack>.unmodifiable(
      _dedupePacks(<SecretlyStickerPack>[...visibleBundled, ...userPacks]),
    );
    _pickerPacks = List<SecretlyStickerPack>.unmodifiable(
      _dedupePacks(<SecretlyStickerPack>[...visibleBundled, ...userPacks]),
    );
    _packsByLookupKey = <String, SecretlyStickerPack>{
      for (final pack in _lookupPacks)
        _packLookupKey(pack.id, pack.version): pack,
    };
    _stickersByLookupKey = <String, SecretlyStickerDescriptor>{
      for (final pack in _lookupPacks)
        for (final sticker in pack.stickers) sticker.lookupKey: sticker,
    };
    _searchableStickers = List<SecretlyStickerDescriptor>.unmodifiable(
      <SecretlyStickerDescriptor>[
        for (final pack in _installedPacks)
          for (final sticker in pack.stickers)
            if (sticker.isRenderable) sticker,
      ],
    );
  }

  static List<SecretlyStickerPack> _dedupePacks(
    Iterable<SecretlyStickerPack> source,
  ) {
    final seen = <String>{};
    final out = <SecretlyStickerPack>[];
    for (final pack in source) {
      final key = '${pack.id}@${pack.version}';
      if (!seen.add(key)) continue;
      out.add(pack);
    }
    return out;
  }

  static String _packLookupKey(String packId, int packVersion) {
    return '$packId@$packVersion';
  }

  static String? _normalizeCategoryTag(String? categoryTag) {
    final normalized = categoryTag?.trim() ?? '';
    if (normalized.isEmpty) return null;
    return normalized;
  }
}

SecretlyStickerDescriptor _pngSticker({
  required String packId,
  required String stickerId,
  required String fileName,
  required String emojiHint,
  required String label,
  required List<String> keywords,
}) {
  return SecretlyStickerDescriptor(
    packId: packId,
    packVersion: SecretlyStickerCatalog.bundledPackVersion,
    stickerId: stickerId,
    assetPath: '${AppAssetPaths.pngIconsDir}/$fileName',
    format: SecretlyStickerFormat.png,
    animated: false,
    emojiHint: emojiHint,
    label: label,
    keywords: keywords,
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
