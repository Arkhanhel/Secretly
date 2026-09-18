// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Bundled DiceBear avatar catalog (free, CC0 / free-commercial — see
/// `assets/avatars/dicebear/LICENSE.txt`).
///
/// These are plain bundled PNGs, so a selection flows through the existing
/// asset-path avatar pipeline (`AppController.setMyAvatarFromIconAsset` →
/// `buildAvatarBytesFromIconAsset` → baked `my_avatar_*.png`). No new storage
/// representation is needed: the chosen path is stored in
/// `profile_icon_asset_path` (round-trips through backup/restore since the asset
/// always ships with the app) and every avatar render site shows the baked
/// composite, exactly like the existing local icon catalog.
library;

/// Directory the 60 bundled avatars live in (declared in `pubspec.yaml`).
const String kAvatarAssetDir = 'assets/avatars/dicebear';

/// DiceBear styles bundled, in display order. Each ships 10 variants (`_01`..
/// `_10`), giving 60 avatars total.
const List<String> kAvatarStyles = <String>[
  'lorelei',
  'notionists',
  'open-peeps',
  'pixel-art',
  'bottts',
  'avataaars',
];

/// All 60 bundled avatar asset paths, e.g.
/// `assets/avatars/dicebear/lorelei_01.png`. Generated from
/// [kAvatarStyles] × `01..10` so it always matches the bundled files.
final List<String> kAvatarAssetPaths = List<String>.unmodifiable(<String>[
  for (final style in kAvatarStyles)
    for (var n = 1; n <= 10; n++)
      '$kAvatarAssetDir/${style}_${n.toString().padLeft(2, '0')}.png',
]);

/// Basenames (no directory, with extension) of avatars that play a subtle idle
/// animation in the picker grid + preview. Spans every style so the effect is
/// visible whichever section the user scrolls to. Purely cosmetic — never gated.
const Set<String> kAnimatedAvatarBasenames = <String>{
  'lorelei_03.png',
  'notionists_05.png',
  'open-peeps_02.png',
  'pixel-art_07.png',
  'bottts_01.png',
  'bottts_09.png',
  'avataaars_04.png',
  'avataaars_10.png',
};

/// True when [assetPath] is one of the bundled avatars flagged for the idle
/// animation. Matches on basename so it works for both full asset paths and the
/// stored `profile_icon_asset_path` value.
bool avatarPathIsAnimated(String assetPath) {
  final slash = assetPath.lastIndexOf('/');
  final base = slash >= 0 ? assetPath.substring(slash + 1) : assetPath;
  return kAnimatedAvatarBasenames.contains(base);
}
