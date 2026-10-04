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
///   • falls back to the standard asset for anything unknown,
///   • кладёт узор (картинки набора и живые обои) по ВЫСОТЕ панели,
///     колонками от центра, как Telegram Desktop, — на широком окне дудлы
///     добавляются, а не растут (О1, `desktop_wallpaper_tiling.dart`); фото и
///     серверные обои остаются «по покрытию».
///
/// This keeps the picker (`settings_workspace.dart`) wired to the shared
/// preset ids while letting the chat panel paint a desktop-appropriate
/// background without dragging in the mobile theme extension.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../services/desktop_file_probe.dart';

// chat_wallpapers re-exports the animated renderer, so one import covers the
// id resolution, the anim mode enum and TelegramWallpaper itself.
import '../../chat_wallpapers.dart';
import '../design/colors.dart';
import 'desktop_wallpaper_tiling.dart';

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
  // Плитка выбора: живые обои — неподвижным кадром, картинки — мелким
  // декодом (28.09.2026, сетка обоев ПК).
  bool preview = false,
}) {
  final normalized = normalizeChatWallpaperId(wallpaperId);
  // server:<id> — платные обои с сервера: скачивание, кэш и заглушка на время
  // загрузки — в общем коде, у ПК своего пути для них не было (28.09.2026).
  if (decodeServerChatWallpaperId(normalized) != null) {
    return buildChatWallpaperBackground(context, normalized, preview: preview);
  }

  // anim:<style> — the shared animated renderer, shader pulse and all.
  //
  // Used directly rather than through `buildChatWallpaperBackground`, which
  // reads ChatVisualsThemeExtension and Theme.colorScheme — neither of which
  // the desktop pipeline publishes. TelegramWallpaper itself needs only a
  // style and a mask, so it drops in unchanged: same 5 styles, same animation
  // modes, same geodesic light wave, no new wire or asset of our own.
  //
  // 🔴 О1 (30.09.2026): узор и поле волны — по высоте панели, колонками от
  // центра (`desktop_wallpaper_tiling.dart`), а не «по покрытию»: на широком
  // окне дудлы больше не растут. Телефон раскладку не передаёт и рисует как
  // раньше.
  final animStyle = decodeAnimatedChatWallpaperStyle(normalized);
  if (animStyle != null) {
    return TelegramWallpaper(
      key: animKey,
      style: animStyle,
      mode: preview ? ChatWallpaperAnimMode.off : animMode,
      conduct: preview ? false : conduct,
      patternLayout: const DesktopTiledPatternLayout(),
    );
  }

  // asset:* id — узор по высоте панели, колонками от центра (О1).
  final assetPath = decodeAssetChatWallpaperId(normalized);
  if (assetPath != null) {
    // 🔴 Пара под тему, как на телефоне: тёмная картинка в светлой теме
    // меняется на свою светлую пару и наоборот (28.09.2026).
    return _assetWallpaper(
      context,
      themedChatWallpaperAssetPath(assetPath, darkMode: palette.isDark),
      preview: preview,
    );
  }

  // file:* id — paint the local file full-bleed if it still exists. Фото —
  // не узор: его колонками не разложишь, остаётся «по покрытию» (О1).
  final filePath = decodeFileChatWallpaperId(normalized);
  // Без обращения к диску на каждую перерисовку ленты — [DesktopFileProbe].
  if (filePath != null && DesktopFileProbe.exists(filePath)) {
    // D-3: same decode cap as the bundled assets. A user-chosen wallpaper can
    // easily be a full-resolution camera photo, which is worse than anything
    // we ship.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.bg,
        image: DecorationImage(
          image: ResizeImage.resizeIfNeeded(
            chatWallpaperDecodeWidth(context, preview: preview),
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
      // 🔴 «Классика» — градиент по цветам темы, как у телефона
      // (`themedLightSolidChatWallpaperColors`). Раньше `default` на ПК
      // рисовал картинку «Ночной синий», и одно имя значило разное на двух
      // устройствах. Тем, у кого на ПК был выбран `default`, при запуске один
      // раз ставится именно картинка — их фон не меняется
      // (`migrateDesktopDefaultWallpaper`).
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themedLightSolidChatWallpaperColors(context),
          ),
        ),
      );
    default:
      return _assetWallpaper(
        context,
        palette.isDark
            ? kDarkThemeStandardChatWallpaperAssetPath
            : kLightThemeStandardChatWallpaperAssetPath,
        preview: preview,
      );
  }
}

/// Идентификатор, которым ПК подменяет свой прежний `default` (картинка
/// «Ночной синий»), чтобы у нынешних пользователей фон не поменялся.
String desktopLegacyDefaultWallpaperId() =>
    encodeAssetChatWallpaperId(kDarkThemeStandardChatWallpaperAssetPath);

/// Paints a bundled wallpaper asset.
///
/// 🔴 О1 (30.09.2026): не «по покрытию», а по высоте панели, колонками от
/// центра — все картинки набора это узор дудлов поверх градиента, и на широком
/// окне «покрытие» раздувало дудлы вдвое-вчетверо. Центральная колонка — сама
/// картинка целиком, как задумана; боковые — её повтор, если края картинки
/// совпадают по цвету, иначе отражение (замеры — в шапке
/// `desktop_wallpaper_tiling.dart`).
///
/// D-3 сохранён в новом виде: картинка 1440×2560 (~14,75 МБ) декодируется не
/// больше, чем бывает нужно, но теперь по ВЫСОТЕ и один раз на плотность
/// пикселей — ширина окна на ключ кэша не влияет, и растягивание окна больше
/// не декодирует её заново на каждом шаге.
Widget _assetWallpaper(
  BuildContext context,
  String assetPath, {
  bool preview = false,
}) {
  return DesktopTiledWallpaperImage(
    image: AssetImage(assetPath),
    tileMode: desktopWallpaperTileModeFor(assetPath),
    preview: preview,
  );
}
