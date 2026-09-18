// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'package:secretly_app/stickers/sticker_catalog.dart';

const int _unicodeFeaturedRankBase = 100;

const List<_UnicodeVendorSpec> _unicodeVendorSpecs = <_UnicodeVendorSpec>[
  _UnicodeVendorSpec(
    id: 'twemoji',
    title: 'Twemoji',
    assetDirSegments: <String>['twemoji', 'assets', '72x72'],
    layout: _UnicodeVendorLayout.dashedHex,
  ),
  _UnicodeVendorSpec(
    id: 'openmoji',
    title: 'OpenMoji',
    assetDirSegments: <String>['openmoji', 'color', '72x72'],
    layout: _UnicodeVendorLayout.dashedHex,
  ),
  _UnicodeVendorSpec(
    id: 'noto',
    title: 'Noto',
    assetDirSegments: <String>['noto-emoji', 'png', '72'],
    layout: _UnicodeVendorLayout.notoEmoji,
  ),
];

const List<_UnicodeCategorySpec> _unicodeCategorySpecs = <_UnicodeCategorySpec>[
  _UnicodeCategorySpec(
    id: 'faces_emotion',
    title: 'Faces',
    description: 'stickers for faces, moods, and hearts',
    emojiHint: '😀',
    primaryIconHexcodes: <String>['1F600', '1F60D'],
    groups: <String>{'smileys-emotion'},
  ),
  _UnicodeCategorySpec(
    id: 'hands_body',
    title: 'Hands',
    description: 'hand signs and body details',
    emojiHint: '👍',
    primaryIconHexcodes: <String>['1F44D', '270C-FE0F'],
    groups: <String>{'people-body'},
    subgroups: <String>{
      'hand-fingers-open',
      'hands',
      'hand-fingers-partial',
      'hand-single-finger',
      'hand-fingers-closed',
      'hand-prop',
      'body-parts',
    },
  ),
  _UnicodeCategorySpec(
    id: 'people_gestures',
    title: 'People',
    description: 'people, gestures, and resting poses',
    emojiHint: '🙋',
    primaryIconHexcodes: <String>['1F64B', '1F9CD'],
    groups: <String>{'people-body'},
    subgroups: <String>{'person', 'person-gesture', 'person-resting'},
  ),
  _UnicodeCategorySpec(
    id: 'people_roles_fantasy',
    title: 'Roles',
    description: 'jobs, fantasy characters, and symbolic people',
    emojiHint: '🧙',
    primaryIconHexcodes: <String>['1F9D9', '1F469-200D-1F4BB'],
    groups: <String>{'people-body'},
    subgroups: <String>{'person-role', 'person-fantasy', 'person-symbol'},
  ),
  _UnicodeCategorySpec(
    id: 'family_relationships',
    title: 'Family',
    description: 'families and relationship combinations',
    emojiHint: '👨‍👩‍👧',
    primaryIconHexcodes: <String>['1F46A', '1F469-200D-1F467'],
    groups: <String>{'people-body'},
    subgroups: <String>{'family'},
  ),
  _UnicodeCategorySpec(
    id: 'people_activity',
    title: 'Activity',
    description: 'walking, dancing, and everyday movement',
    emojiHint: '🏃',
    primaryIconHexcodes: <String>['1F3C3', '1F57A'],
    groups: <String>{'people-body'},
    subgroups: <String>{'person-activity'},
  ),
  _UnicodeCategorySpec(
    id: 'people_sport',
    title: 'Sport',
    description: 'sports and competitive action',
    emojiHint: '⛹️',
    primaryIconHexcodes: <String>['26F9-FE0F', '1F93E'],
    groups: <String>{'people-body'},
    subgroups: <String>{'person-sport'},
  ),
  _UnicodeCategorySpec(
    id: 'animals_nature',
    title: 'Animals',
    description: 'animals, plants, weather, and landscapes',
    emojiHint: '🐻',
    primaryIconHexcodes: <String>['1F43B', '1F98A'],
    groups: <String>{'animals-nature'},
  ),
  _UnicodeCategorySpec(
    id: 'food_drink',
    title: 'Food',
    description: 'food, drinks, and kitchen moments',
    emojiHint: '🍔',
    primaryIconHexcodes: <String>['1F354', '1F355'],
    groups: <String>{'food-drink'},
  ),
  _UnicodeCategorySpec(
    id: 'travel_places',
    title: 'Travel',
    description: 'transport, landmarks, and places',
    emojiHint: '✈️',
    primaryIconHexcodes: <String>['2708-FE0F', '1F5FA-FE0F'],
    groups: <String>{'travel-places'},
  ),
  _UnicodeCategorySpec(
    id: 'activities',
    title: 'Fun',
    description: 'games, celebration, and entertainment',
    emojiHint: '🎯',
    primaryIconHexcodes: <String>['1F3AF', '1F389'],
    groups: <String>{'activities'},
  ),
  _UnicodeCategorySpec(
    id: 'objects',
    title: 'Objects',
    description: 'tools, tech, money, and daily objects',
    emojiHint: '💡',
    primaryIconHexcodes: <String>['1F4A1', '1F4F1'],
    groups: <String>{'objects'},
  ),
  _UnicodeCategorySpec(
    id: 'symbols',
    title: 'Symbols',
    description: 'signs, arrows, and symbolic marks',
    emojiHint: '♻️',
    primaryIconHexcodes: <String>['267B', '2764-FE0F'],
    groups: <String>{'symbols'},
  ),
  _UnicodeCategorySpec(
    id: 'flags',
    title: 'Flags',
    description: 'country, region, and signal flags',
    emojiHint: '🏳️',
    primaryIconHexcodes: <String>['1F3F3-FE0F', '1F1FA-1F1F8'],
    groups: <String>{'flags'},
  ),
  _UnicodeCategorySpec(
    id: 'extras_unicode',
    title: 'Unicode+',
    description: 'extended unicode extras outside the main groups',
    emojiHint: '🔣',
    primaryIconHexcodes: <String>['1F524', '1F523'],
    groups: <String>{'extras-unicode'},
  ),
  _UnicodeCategorySpec(
    id: 'extras_openmoji',
    title: 'OpenMoji+',
    description: 'OpenMoji-specific extras and private-use artwork',
    emojiHint: '🧪',
    primaryIconHexcodes: <String>['E000', 'E001'],
    groups: <String>{'extras-openmoji'},
    allowedVendors: <String>{'openmoji'},
  ),
];

Future<void> main(List<String> args) async {
  final command = args.isEmpty ? 'build-default' : args.first.trim();
  final options = _parseOptions(args.skip(1));
  final appRoot = Directory.current.path;
  final outputPath = options['output']?.trim().isNotEmpty == true
      ? options['output']!.trim()
      : p.normalize(
          p.join(
            appRoot,
            '..',
            '..',
            '..',
            'server',
            'relay',
            'sticker_catalog',
          ),
        );
  final outputDir = Directory(outputPath);

  final packs = switch (command) {
    'seed-bundled' => _bundledSourcePacks(),
    'build-unicode' => await _buildUnicodeVendorPacks(
      appRoot,
      vendorRootPath: options['vendor-root'],
    ),
    'import-pack' => <_SourcePack>[
      await _loadSourcePack(
        options['input'],
        appRoot: appRoot,
        featuredRankOverride: _tryParseInt(options['featured-rank']),
      ),
    ],
    'build-default' => <_SourcePack>[
      ..._bundledSourcePacks(),
      ...await _buildUnicodeVendorPacks(
        appRoot,
        vendorRootPath: options['vendor-root'],
      ),
      ...await _loadDefaultSourcePacks(appRoot),
    ],
    _ => throw ArgumentError(
      'Unknown command "$command". Supported commands: build-default, build-unicode, seed-bundled, import-pack.',
    ),
  };

  await _writeCatalog(outputDir: outputDir, packs: packs);
  stdout.writeln(
    'Sticker catalog written to ${outputDir.path} (${packs.length} packs).',
  );
}

Future<List<_SourcePack>> _buildUnicodeVendorPacks(
  String appRoot, {
  String? vendorRootPath,
}) async {
  final vendorRoot = _resolveVendorRoot(appRoot, vendorRootPath);
  final metadataFile = File(
    p.join(vendorRoot, 'openmoji', 'data', 'openmoji.json'),
  );
  if (!await metadataFile.exists()) {
    throw ArgumentError(
      'Unicode sticker metadata not found: ${metadataFile.path}. Provide --vendor-root <dir> with openmoji, twemoji, and noto-emoji sources.',
    );
  }

  final metadata = await _loadUnicodeMetadata(metadataFile);
  final vendors = <_IndexedUnicodeVendorAssets>[
    for (final spec in _unicodeVendorSpecs)
      await _loadUnicodeVendorAssets(spec, vendorRoot),
  ];

  final packs = <_SourcePack>[];
  var featuredRank = _unicodeFeaturedRankBase;
  for (final category in _unicodeCategorySpecs) {
    final categoryEntries = metadata
        .where((entry) => category.matches(entry))
        .toList(growable: false);
    if (categoryEntries.isEmpty) continue;
    for (final vendor in vendors) {
      if (!category.supportsVendor(vendor.spec.id)) continue;
      final pack = _buildUnicodeVendorPack(
        vendor: vendor,
        category: category,
        entries: categoryEntries,
        featuredRank: featuredRank,
      );
      if (pack == null) continue;
      packs.add(pack);
      featuredRank += 1;
    }
  }
  return packs;
}

String _resolveVendorRoot(String appRoot, String? overridePath) {
  final trimmedOverride = (overridePath ?? '').trim();
  if (trimmedOverride.isNotEmpty) {
    return p.normalize(
      p.isAbsolute(trimmedOverride)
          ? trimmedOverride
          : p.join(appRoot, trimmedOverride),
    );
  }
  return p.normalize(
    p.join(appRoot, '..', '..', '..', 'artifacts', 'vendor_inspect'),
  );
}

Future<List<_UnicodeStickerMeta>> _loadUnicodeMetadata(
  File metadataFile,
) async {
  final decoded = jsonDecode(await metadataFile.readAsString());
  if (decoded is! List) {
    throw ArgumentError(
      'OpenMoji metadata must be a JSON array: ${metadataFile.path}',
    );
  }

  final metadata = <_UnicodeStickerMeta>[];
  for (final item in decoded.whereType<Map>()) {
    final map = Map<String, dynamic>.from(item);
    final group = (map['group'] as String? ?? '').trim();
    final subgroup = (map['subgroups'] as String? ?? '').trim();
    final hexcode = (map['hexcode'] as String? ?? '').trim();
    if (group.isEmpty || subgroup.isEmpty || hexcode.isEmpty) continue;
    metadata.add(
      _UnicodeStickerMeta(
        emoji: (map['emoji'] as String? ?? '').trim(),
        hexcode: hexcode,
        group: group,
        subgroup: subgroup,
        annotation: (map['annotation'] as String? ?? '').trim(),
        tags: _parseMetadataTags(map['tags']),
        order: int.tryParse(map['order']?.toString() ?? '') ?? (1 << 20),
      ),
    );
  }
  metadata.sort((a, b) => a.order.compareTo(b.order));
  return metadata;
}

List<String> _parseMetadataTags(Object? raw) {
  if (raw is List) {
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const <String>[];
    return trimmed
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

Future<_IndexedUnicodeVendorAssets> _loadUnicodeVendorAssets(
  _UnicodeVendorSpec spec,
  String vendorRoot,
) async {
  final assetDir = Directory(
    p.joinAll(<String>[vendorRoot, ...spec.assetDirSegments]),
  );
  if (!await assetDir.exists()) {
    throw ArgumentError(
      'Unicode sticker asset directory not found: ${assetDir.path}',
    );
  }

  final assetsByLookupKey = <String, String>{};
  await for (final entity in assetDir.list(followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.toLowerCase().endsWith('.png')) continue;
    final rawSequence = spec.rawSequenceForFile(entity.path);
    if (rawSequence == null || rawSequence.isEmpty) continue;
    for (final key in _lookupAliasesForSequence(
      rawSequence,
      separator: spec.sequenceSeparator,
    )) {
      assetsByLookupKey.putIfAbsent(key, () => entity.path);
    }
  }

  if (assetsByLookupKey.isEmpty) {
    throw ArgumentError(
      'No PNG unicode assets were indexed for ${spec.title} in ${assetDir.path}',
    );
  }

  return _IndexedUnicodeVendorAssets(
    spec: spec,
    assetsByLookupKey: assetsByLookupKey,
  );
}

_SourcePack? _buildUnicodeVendorPack({
  required _IndexedUnicodeVendorAssets vendor,
  required _UnicodeCategorySpec category,
  required List<_UnicodeStickerMeta> entries,
  required int featuredRank,
}) {
  final stickers = <_SourceSticker>[];
  for (final entry in entries) {
    final assetPath = vendor.resolveAsset(entry.hexcode);
    if (assetPath == null) continue;
    stickers.add(
      _SourceSticker(
        stickerId: _unicodeStickerId(entry.hexcode),
        sourcePath: assetPath,
        format: 'png',
        animated: false,
        emojiHint: entry.emoji,
        label: _unicodeStickerLabel(entry),
        keywords: _unicodeStickerKeywords(entry),
      ),
    );
  }
  if (stickers.isEmpty) return null;

  final iconSticker = _pickUnicodeIconSticker(stickers, category);
  return _SourcePack(
    packId: '${vendor.spec.id}_${category.id}',
    packVersion: 1,
    title: '${vendor.spec.title} ${category.title}',
    description: '${vendor.spec.title} ${category.description}.',
    iconStickerId: iconSticker.stickerId,
    iconEmojiHint: category.emojiHint,
    featuredRank: featuredRank,
    tags: <String>[
      'remote',
      'unicode',
      'vendor:${vendor.spec.id}',
      category.categoryTag,
      if (category.id.startsWith('extras_')) 'extras',
    ],
    stickers: stickers,
  );
}

_SourceSticker _pickUnicodeIconSticker(
  List<_SourceSticker> stickers,
  _UnicodeCategorySpec category,
) {
  final stickersById = <String, _SourceSticker>{
    for (final sticker in stickers) sticker.stickerId: sticker,
  };
  for (final hexcode in category.primaryIconHexcodes) {
    final sticker = stickersById[_unicodeStickerId(hexcode)];
    if (sticker != null) return sticker;
  }
  return stickers.first;
}

String _unicodeStickerId(String hexcode) {
  final normalized = _normalizeHexSequence(hexcode, separator: '-');
  return 'u_${normalized.toLowerCase().replaceAll('-', '_')}';
}

String _unicodeStickerLabel(_UnicodeStickerMeta entry) {
  final annotation = entry.annotation.trim();
  if (annotation.isNotEmpty) return annotation;
  if (entry.emoji.isNotEmpty) return entry.emoji;
  return entry.hexcode;
}

List<String> _unicodeStickerKeywords(_UnicodeStickerMeta entry) {
  final keywords = <String>{
    entry.annotation.trim(),
    entry.group.replaceAll('-', ' '),
    entry.subgroup.replaceAll('-', ' '),
    ...entry.tags,
    ..._splitKeywordTokens(entry.annotation),
    ..._splitKeywordTokens(entry.group),
    ..._splitKeywordTokens(entry.subgroup),
  };
  keywords.removeWhere((value) => value.trim().isEmpty);
  return keywords.toList(growable: false);
}

Iterable<String> _splitKeywordTokens(String raw) sync* {
  for (final token in raw.split(RegExp(r'[\s_\-]+'))) {
    final normalized = token.trim();
    if (normalized.isEmpty) continue;
    yield normalized;
  }
}

Iterable<String> _lookupAliasesForSequence(
  String rawSequence, {
  required String separator,
}) sync* {
  final normalized = _normalizeHexSequence(rawSequence, separator: separator);
  if (normalized.isEmpty) return;
  final seen = <String>{};
  if (seen.add(normalized)) {
    yield normalized;
  }
  final withoutVs16 = normalized
      .split('-')
      .where((part) => part != 'FE0F')
      .join('-');
  if (withoutVs16.isNotEmpty && seen.add(withoutVs16)) {
    yield withoutVs16;
  }
}

String _normalizeHexSequence(String raw, {required String separator}) {
  final parts = raw
      .split(separator)
      .map(_normalizeHexCodepoint)
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  return parts.join('-');
}

String _normalizeHexCodepoint(String raw) {
  final trimmed = raw.trim().toUpperCase();
  if (trimmed.isEmpty) return '';
  final withoutPrefix = trimmed.startsWith('U+')
      ? trimmed.substring(2)
      : trimmed;
  final withoutLeadingZeros = withoutPrefix.replaceFirst(
    RegExp(r'^0+(?=[0-9A-F])'),
    '',
  );
  return withoutLeadingZeros.isEmpty ? '0' : withoutLeadingZeros;
}

Map<String, String> _parseOptions(Iterable<String> args) {
  final out = <String, String>{};
  final list = args.toList(growable: false);
  for (var i = 0; i < list.length; i++) {
    final raw = list[i].trim();
    if (!raw.startsWith('--')) continue;
    final eqIndex = raw.indexOf('=');
    if (eqIndex > 2) {
      out[raw.substring(2, eqIndex)] = raw.substring(eqIndex + 1).trim();
      continue;
    }
    final key = raw.substring(2);
    if (i + 1 < list.length && !list[i + 1].trim().startsWith('--')) {
      out[key] = list[i + 1].trim();
      i += 1;
    } else {
      out[key] = 'true';
    }
  }
  return out;
}

int? _tryParseInt(String? raw) {
  if (raw == null) return null;
  return int.tryParse(raw.trim());
}

List<_SourcePack> _bundledSourcePacks() {
  final out = <_SourcePack>[];
  for (
    var index = 0;
    index < SecretlyStickerCatalog.bundledPickerPacks.length;
    index++
  ) {
    final pack = SecretlyStickerCatalog.bundledPickerPacks[index];
    final iconSticker = pack.iconSticker;
    out.add(
      _SourcePack(
        packId: pack.id,
        packVersion: pack.version,
        title: pack.title,
        description: '',
        iconStickerId: pack.iconStickerId,
        iconEmojiHint: iconSticker.emojiHint,
        featuredRank: index,
        tags: const <String>['bundled', 'featured'],
        stickers: pack.stickers
            .map(
              (sticker) => _SourceSticker(
                stickerId: sticker.stickerId,
                sourcePath: sticker.assetPath,
                format: sticker.format.wireValue,
                animated: sticker.animated,
                emojiHint: sticker.emojiHint,
                label: sticker.label,
                keywords: sticker.keywords,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
  return out;
}

Future<List<_SourcePack>> _loadDefaultSourcePacks(String appRoot) async {
  final dir = Directory(p.join(appRoot, 'tools', 'sticker_catalog_sources'));
  if (!await dir.exists()) return const <_SourcePack>[];
  final legacyIconsDir = p.normalize(
    p.join(appRoot, 'assets', 'app_ui', 'icons', 'png'),
  );
  final out = <_SourcePack>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.toLowerCase().endsWith('.json')) continue;
    out.add(await _loadSourcePack(entity.path, appRoot: appRoot));
  }
  out.sort((a, b) {
    final rankA = a.featuredRank ?? 1 << 20;
    final rankB = b.featuredRank ?? 1 << 20;
    final cmp = rankA.compareTo(rankB);
    if (cmp != 0) return cmp;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return out
      .where((pack) => !_isLegacyIconSourcePack(pack, legacyIconsDir))
      .toList(growable: false);
}

bool _isLegacyIconSourcePack(_SourcePack pack, String legacyIconsDir) {
  if (pack.stickers.isEmpty) return false;
  return pack.stickers.every((sticker) {
    final normalizedPath = p.normalize(sticker.sourcePath);
    return sticker.format.toLowerCase() == 'png' &&
        p.isWithin(legacyIconsDir, normalizedPath);
  });
}

Future<_SourcePack> _loadSourcePack(
  String? inputPath, {
  required String appRoot,
  int? featuredRankOverride,
}) async {
  final trimmedInput = (inputPath ?? '').trim();
  if (trimmedInput.isEmpty) {
    throw ArgumentError('Missing --input <source-pack.json>');
  }
  final sourceFile = File(
    p.isAbsolute(trimmedInput) ? trimmedInput : p.join(appRoot, trimmedInput),
  );
  if (!await sourceFile.exists()) {
    throw ArgumentError('Source pack file not found: ${sourceFile.path}');
  }
  final raw = await sourceFile.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw ArgumentError(
      'Source pack JSON must be an object: ${sourceFile.path}',
    );
  }
  final stickersJson = decoded['stickers'];
  if (stickersJson is! List) {
    throw ArgumentError(
      'Source pack must contain a stickers array: ${sourceFile.path}',
    );
  }
  final sourceDir = sourceFile.parent.path;
  final stickers = <_SourceSticker>[];
  for (final item in stickersJson.whereType<Map>()) {
    final map = Map<String, dynamic>.from(item);
    final rawSourcePath = (map['source_path'] as String? ?? '').trim();
    final resolvedSource = _resolveSourcePath(
      rawSourcePath,
      appRoot: appRoot,
      sourceDir: sourceDir,
    );
    stickers.add(
      _SourceSticker(
        stickerId: (map['sticker_id'] as String? ?? '').trim(),
        sourcePath: resolvedSource,
        format: (map['format'] as String? ?? 'png').trim(),
        animated: map['animated'] == true,
        emojiHint: (map['emoji_hint'] as String? ?? '').trim(),
        label: (map['label'] as String? ?? '').trim(),
        keywords:
            (map['keywords'] as List?)
                ?.map((value) => (value as String? ?? '').trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false) ??
            const <String>[],
      ),
    );
  }
  final pack = _SourcePack(
    packId: (decoded['pack_id'] as String? ?? '').trim(),
    packVersion: _tryParseInt(decoded['pack_version']?.toString()) ?? 1,
    title: (decoded['title'] as String? ?? '').trim(),
    description: (decoded['description'] as String? ?? '').trim(),
    iconStickerId: (decoded['icon_sticker_id'] as String? ?? '').trim(),
    iconEmojiHint: (decoded['icon_emoji_hint'] as String? ?? '').trim(),
    featuredRank:
        featuredRankOverride ??
        _tryParseInt(decoded['featured_rank']?.toString()),
    tags:
        (decoded['tags'] as List?)
            ?.map((value) => (value as String? ?? '').trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[],
    stickers: stickers,
  );
  pack.validate();
  return pack;
}

String _resolveSourcePath(
  String raw, {
  required String appRoot,
  required String sourceDir,
}) {
  if (raw.isEmpty) {
    throw ArgumentError('Sticker source_path must not be empty');
  }
  final absolute = File(raw);
  if (absolute.isAbsolute && absolute.existsSync()) {
    return absolute.path;
  }
  final fromSourceDir = File(p.normalize(p.join(sourceDir, raw)));
  if (fromSourceDir.existsSync()) {
    return fromSourceDir.path;
  }
  final fromAppRoot = File(p.normalize(p.join(appRoot, raw)));
  if (fromAppRoot.existsSync()) {
    return fromAppRoot.path;
  }
  throw ArgumentError('Sticker source asset not found: $raw');
}

Future<void> _writeCatalog({
  required Directory outputDir,
  required List<_SourcePack> packs,
}) async {
  if (await outputDir.exists()) {
    await outputDir.delete(recursive: true);
  }
  await outputDir.create(recursive: true);
  final generatedAtMs = DateTime.now().millisecondsSinceEpoch;
  final catalogPacks = <Map<String, Object?>>[];
  for (final pack in packs) {
    pack.validate();
    final stickerDir = Directory(
      p.join(
        outputDir.path,
        'packs',
        pack.packId,
        '${pack.packVersion}',
        'stickers',
      ),
    );
    await stickerDir.create(recursive: true);
    final stickerDocs = <Map<String, Object?>>[];
    for (final sticker in pack.stickers) {
      sticker.validate();
      final sourceFile = File(sticker.sourcePath);
      if (!await sourceFile.exists()) {
        throw FileSystemException('Sticker source not found', sourceFile.path);
      }
      final ext = p.extension(sourceFile.path).toLowerCase();
      final fileName = '${sticker.stickerId}${ext.isEmpty ? '.png' : ext}';
      final targetFile = File(p.join(stickerDir.path, fileName));
      await targetFile.parent.create(recursive: true);
      await sourceFile.copy(targetFile.path);
      final bytes = await targetFile.readAsBytes();
      stickerDocs.add(<String, Object?>{
        'sticker_id': sticker.stickerId,
        'file_name': fileName,
        'format': sticker.format,
        'animated': sticker.animated,
        'emoji_hint': sticker.emojiHint,
        'label': sticker.label,
        'keywords': sticker.keywords,
        'sha256_b64': base64Encode(crypto.sha256.convert(bytes).bytes),
        'size_bytes': bytes.length,
      });
    }
    catalogPacks.add(<String, Object?>{
      'pack_id': pack.packId,
      'pack_version': pack.packVersion,
      'title': pack.title,
      'description': pack.description,
      'icon_sticker_id': pack.iconStickerId,
      'icon_emoji_hint': pack.iconEmojiHint,
      'featured_rank': pack.featuredRank,
      'tags': pack.tags,
      'stickers': stickerDocs,
    });
  }
  final catalogJson = const JsonEncoder.withIndent('  ').convert(
    <String, Object?>{
      'schema_version': 1,
      'generated_at_ms': generatedAtMs,
      'packs': catalogPacks,
    },
  );
  await File(
    p.join(outputDir.path, 'catalog.json'),
  ).writeAsString('$catalogJson\n');
}

class _SourcePack {
  const _SourcePack({
    required this.packId,
    required this.packVersion,
    required this.title,
    required this.description,
    required this.iconStickerId,
    required this.iconEmojiHint,
    required this.featuredRank,
    required this.tags,
    required this.stickers,
  });

  final String packId;
  final int packVersion;
  final String title;
  final String description;
  final String iconStickerId;
  final String iconEmojiHint;
  final int? featuredRank;
  final List<String> tags;
  final List<_SourceSticker> stickers;

  void validate() {
    if (packId.isEmpty ||
        packVersion <= 0 ||
        title.isEmpty ||
        iconStickerId.isEmpty) {
      throw ArgumentError('Invalid pack definition: $packId@$packVersion');
    }
    if (stickers.isEmpty) {
      throw ArgumentError(
        'Sticker pack must contain at least one sticker: $packId',
      );
    }
  }
}

class _SourceSticker {
  const _SourceSticker({
    required this.stickerId,
    required this.sourcePath,
    required this.format,
    required this.animated,
    required this.emojiHint,
    required this.label,
    required this.keywords,
  });

  final String stickerId;
  final String sourcePath;
  final String format;
  final bool animated;
  final String emojiHint;
  final String label;
  final List<String> keywords;

  void validate() {
    if (stickerId.isEmpty || sourcePath.isEmpty || format.isEmpty) {
      throw ArgumentError('Invalid sticker definition: $stickerId');
    }
  }
}

enum _UnicodeVendorLayout { dashedHex, notoEmoji }

class _UnicodeVendorSpec {
  const _UnicodeVendorSpec({
    required this.id,
    required this.title,
    required this.assetDirSegments,
    required this.layout,
  });

  final String id;
  final String title;
  final List<String> assetDirSegments;
  final _UnicodeVendorLayout layout;

  String get sequenceSeparator {
    switch (layout) {
      case _UnicodeVendorLayout.dashedHex:
        return '-';
      case _UnicodeVendorLayout.notoEmoji:
        return '_';
    }
  }

  String? rawSequenceForFile(String filePath) {
    final baseName = p.basenameWithoutExtension(filePath);
    switch (layout) {
      case _UnicodeVendorLayout.dashedHex:
        return baseName;
      case _UnicodeVendorLayout.notoEmoji:
        if (!baseName.startsWith('emoji_u')) return null;
        return baseName.substring('emoji_u'.length);
    }
  }
}

class _IndexedUnicodeVendorAssets {
  const _IndexedUnicodeVendorAssets({
    required this.spec,
    required this.assetsByLookupKey,
  });

  final _UnicodeVendorSpec spec;
  final Map<String, String> assetsByLookupKey;

  String? resolveAsset(String hexcode) {
    for (final key in _lookupAliasesForSequence(hexcode, separator: '-')) {
      final asset = assetsByLookupKey[key];
      if (asset != null) return asset;
    }
    return null;
  }
}

class _UnicodeCategorySpec {
  const _UnicodeCategorySpec({
    required this.id,
    required this.title,
    required this.description,
    required this.emojiHint,
    required this.primaryIconHexcodes,
    this.groups = const <String>{},
    this.subgroups = const <String>{},
    this.allowedVendors = const <String>{},
  });

  final String id;
  final String title;
  final String description;
  final String emojiHint;
  final List<String> primaryIconHexcodes;
  final Set<String> groups;
  final Set<String> subgroups;
  final Set<String> allowedVendors;

  String get categoryTag => '${SecretlyStickerCatalog.categoryTagPrefix}$id';

  bool supportsVendor(String vendorId) {
    return allowedVendors.isEmpty || allowedVendors.contains(vendorId);
  }

  bool matches(_UnicodeStickerMeta entry) {
    if (groups.isNotEmpty && !groups.contains(entry.group)) {
      return false;
    }
    if (subgroups.isNotEmpty && !subgroups.contains(entry.subgroup)) {
      return false;
    }
    return true;
  }
}

class _UnicodeStickerMeta {
  const _UnicodeStickerMeta({
    required this.emoji,
    required this.hexcode,
    required this.group,
    required this.subgroup,
    required this.annotation,
    required this.tags,
    required this.order,
  });

  final String emoji;
  final String hexcode;
  final String group;
  final String subgroup;
  final String annotation;
  final List<String> tags;
  final int order;
}
