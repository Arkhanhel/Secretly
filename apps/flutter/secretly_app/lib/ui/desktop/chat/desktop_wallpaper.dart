// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Desktop-side chat wallpaper renderer.
///
/// The shared [buildChatWallpaperBackground] in `lib/ui/chat_wallpapers.dart`
/// is mobile-flavoured: it reads `ChatVisualsThemeExtension` and
/// `Theme.of(context).colorScheme`, neither of which the desktop pipeline
/// publishes. We use a thin wrapper that:
///
///   • resolves `asset:` / `file:` ids the same way the shared helper does,
///   • for `default` uses the dark-mode standard asset shipped with the app,
///   • for `midnight` falls back to the deep solid color baked into the
///     desktop palette (`bg`),
///   • falls back to the standard asset for anything unknown.
///
/// This keeps the picker (`settings_workspace.dart`) wired to the shared
/// preset ids while letting the chat panel paint a desktop-appropriate
/// background without dragging in the mobile theme extension.
library;

import 'dart:io';

import 'package:flutter/material.dart';

// chat_wallpapers re-exports the animated renderer, so one import covers the
// id resolution, the anim mode enum and TelegramWallpaper itself.
import '../../chat_wallpapers.dart';
import '../design/colors.dart';

/// Builds a widget that paints the chat-thread wallpaper for [wallpaperId].
///
/// [palette] is the active desktop palette; used to derive a solid fallback
/// color for the `midnight` choice and for any unknown id.
///
/// [animKey] is forwarded to the animated renderer so the host can trigger the
/// «проводит сообщение» pulse; null for the static paths, which have none.
/// [animMode] and [conduct] come from the shared controller preferences, so
/// the choice a user made on their phone applies here too.
Widget buildDesktopChatWallpaper(
  BuildContext context, {
  required String wallpaperId,
  required DColorSet palette,
  GlobalKey<TelegramWallpaperState>? animKey,
  ChatWallpaperAnimMode animMode = ChatWallpaperAnimMode.onEnter,
  bool conduct = false,
}) {
  final normalized = normalizeChatWallpaperId(wallpaperId);

  // anim:<style> — the shared animated renderer, shader pulse and all.
  //
  // Used directly rather than through `buildChatWallpaperBackground`, which
  // reads ChatVisualsThemeExtension and Theme.colorScheme — neither of which
  // the desktop pipeline publishes. TelegramWallpaper itself needs only a
  // style and a mask, so it drops in unchanged: same 5 styles, same animation
  // modes, same geodesic light wave, no new wire or asset of our own.
  final animStyle = decodeAnimatedChatWallpaperStyle(normalized);
  if (animStyle != null) {
    return TelegramWallpaper(
      key: animKey,
      style: animStyle,
      mode: animMode,
      conduct: conduct,
    );
  }

  // asset:* id — paint the asset full-bleed.
  final assetPath = decodeAssetChatWallpaperId(normalized);
  if (assetPath != null) {
    return _assetWallpaper(context, assetPath);
  }

  // file:* id — paint the local file full-bleed if it still exists.
  final filePath = decodeFileChatWallpaperId(normalized);
  if (filePath != null && File(filePath).existsSync()) {
    // D-3: same decode cap as the bundled assets. A user-chosen wallpaper can
    // easily be a full-resolution camera photo, which is worse than anything
    // we ship.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.bg,
        image: DecorationImage(
          image: ResizeImage.resizeIfNeeded(
            chatWallpaperDecodeWidth(context, preview: false),
            null,
            FileImage(File(filePath)),
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  switch (normalized) {
    case 'midnight':
      // Solid deep background — no image.
      return ColoredBox(color: palette.bg);
    case 'default':
    default:
      return _assetWallpaper(context, kDarkThemeStandardChatWallpaperAssetPath);
  }
}

/// Paints a full-bleed wallpaper asset.
///
/// D-3: decoded at the window's own width rather than the source's. The
/// wallpaper assets are 1440×2560 — ~14.75 MB decoded — and `BoxFit.cover` can
/// only ever crop, never show more than the window is wide, so the extra
/// pixels are pure cache pressure held for the lifetime of the open chat.
/// [chatWallpaperDecodeWidth] is the same helper the mobile chat uses.
Widget _assetWallpaper(BuildContext context, String assetPath) {
  return DecoratedBox(
    decoration: BoxDecoration(
      image: DecorationImage(
        image: ResizeImage.resizeIfNeeded(
          chatWallpaperDecodeWidth(context, preview: false),
          null,
          AssetImage(assetPath),
        ),
        fit: BoxFit.cover,
      ),
    ),
  );
}
