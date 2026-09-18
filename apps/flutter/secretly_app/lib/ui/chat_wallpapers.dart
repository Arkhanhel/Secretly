// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../cosmetics/cosmetics_catalog_service.dart';
import 'theme_presets.dart';
import 'wave1_l10n.dart';
import 'widgets/telegram_wallpaper.dart';
import 'widgets/wallpaper_blur.dart';

export 'widgets/telegram_wallpaper.dart'
    show
        ChatWallpaperAnimMode,
        parseChatWallpaperAnimMode,
        WallpaperStyle,
        WallpaperStyles,
        TelegramWallpaper,
        TelegramWallpaperState;
export 'widgets/wallpaper_blur.dart'
    show WallpaperBlurController, WallpaperBlurConfig, kWallpaperBlurConfig;

const String kGlobalChatWallpaperSelectionId = 'global';
const String kAssetChatWallpaperPrefix = 'asset:';
const String kFileChatWallpaperPrefix = 'file:';
// Server-hosted premium wallpaper: `server:<catalog-item-id>`.
const String kServerChatWallpaperPrefix = 'server:';
// Animated premium wallpaper (Telegram-style), rendered locally from a bundled
// pattern mask + 4-colour gradient: `anim:<style-key>`. Premium-gated.
const String kAnimatedChatWallpaperPrefix = 'anim:';
const String kBundledChatWallpaperAssetRoot = 'assets/Background/';
const String kLightThemeChatWallpaperAssetRoot =
    '${kBundledChatWallpaperAssetRoot}improved_light/';
const String kLightThemeStandardChatWallpaperAssetPath =
    '${kLightThemeChatWallpaperAssetRoot}wallpaper_light_mint.jpg';
const String kDarkThemeStandardChatWallpaperAssetPath =
    '${kBundledChatWallpaperAssetRoot}wallpaper_dark_navy.jpg';
const Color kLightSolidChatWallpaperColor = Color(0xFFF6F8FC);
const Color kDarkSolidChatWallpaperColor = Color(0xFF11161E);

const List<String> kBuiltInChatWallpaperIds = <String>['default', 'midnight'];

/// Featured bundled wallpapers shown FIRST in the picker, before the other
/// standard ones (the supplied dark doodle set). `wallpaper_dark_navy.jpg` is
/// also the dark-theme default ([kDarkThemeStandardChatWallpaperAssetPath]).
const List<String> kFeaturedChatWallpaperBasenames = <String>[
  // Dark theme set (navy is the dark default). Shown only in dark theme.
  'wallpaper_dark_navy.jpg',
  'wallpaper_dark_graphite.jpg',
  'wallpaper_dark_teal.jpg',
  'wallpaper_dark_plum.jpg',
  'wallpaper_dark_wine.jpg',
  // Light theme set (mint is the light default). Shown only in light theme.
  'wallpaper_light_mint.jpg',
  'wallpaper_light_lavender.jpg',
  'wallpaper_light_sunset.jpg',
  'wallpaper_light_peach.jpg',
  'wallpaper_light_sky.jpg',
];

const Map<String, String> kLegacyBuiltInChatWallpaperIdAliases = {
  'mist': 'default',
  'aurora': 'default',
  'sunset': 'default',
};

String normalizeChatWallpaperId(String id) {
  final normalized = id.trim();
  if (normalized.isEmpty) return 'default';
  return kLegacyBuiltInChatWallpaperIdAliases[normalized] ?? normalized;
}

class ChatWallpaperOption {
  const ChatWallpaperOption({
    required this.id,
    required this.title,
    this.colors,
    this.assetPath,
    this.filePath,
  });

  final String id;
  final String title;
  final List<Color>? colors;
  final String? assetPath;
  final String? filePath;

  ImageProvider<Object>? get imageProvider {
    final resolvedAssetPath = assetPath?.trim();
    if (resolvedAssetPath != null && resolvedAssetPath.isNotEmpty) {
      return AssetImage(resolvedAssetPath);
    }
    final resolvedFilePath = filePath?.trim();
    if (resolvedFilePath != null &&
        resolvedFilePath.isNotEmpty &&
        File(resolvedFilePath).existsSync()) {
      return FileImage(File(resolvedFilePath));
    }
    return null;
  }
}

bool isAssetChatWallpaperId(String id) =>
    id.startsWith(kAssetChatWallpaperPrefix);
bool isFileChatWallpaperId(String id) =>
    id.startsWith(kFileChatWallpaperPrefix);
bool isServerChatWallpaperId(String id) =>
    id.startsWith(kServerChatWallpaperPrefix);

String encodeServerChatWallpaperId(String itemId) =>
    '$kServerChatWallpaperPrefix$itemId';

String? decodeServerChatWallpaperId(String id) {
  if (!isServerChatWallpaperId(id)) return null;
  final itemId = id.substring(kServerChatWallpaperPrefix.length).trim();
  return itemId.isEmpty ? null : itemId;
}

bool isAnimatedChatWallpaperId(String id) =>
    id.startsWith(kAnimatedChatWallpaperPrefix);

String encodeAnimatedChatWallpaperId(String styleKey) =>
    '$kAnimatedChatWallpaperPrefix$styleKey';

/// Resolves an `anim:<key>` id to its [WallpaperStyle], or null if not an
/// animated id or the key is unknown.
WallpaperStyle? decodeAnimatedChatWallpaperStyle(String id) {
  if (!isAnimatedChatWallpaperId(id)) return null;
  final key = id.substring(kAnimatedChatWallpaperPrefix.length).trim();
  if (key.isEmpty) return null;
  return WallpaperStyles.byKey(key);
}

String encodeAssetChatWallpaperId(String assetPath) =>
    '$kAssetChatWallpaperPrefix$assetPath';
String encodeFileChatWallpaperId(String filePath) =>
    '$kFileChatWallpaperPrefix$filePath';

String? decodeAssetChatWallpaperId(String id) {
  if (!isAssetChatWallpaperId(id)) return null;
  final path = id.substring(kAssetChatWallpaperPrefix.length).trim();
  if (path.isEmpty || !path.startsWith(kBundledChatWallpaperAssetRoot)) {
    return null;
  }
  return path;
}

String? decodeFileChatWallpaperId(String id) {
  if (!isFileChatWallpaperId(id)) return null;
  final path = id.substring(kFileChatWallpaperPrefix.length).trim();
  if (path.isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return file.path;
}

bool isLightThemeChatWallpaperAssetPath(String assetPath) {
  return assetPath.trim().startsWith(kLightThemeChatWallpaperAssetRoot);
}

bool isDarkThemeChatWallpaperAssetPath(String assetPath) {
  final path = assetPath.trim();
  return path.startsWith(kBundledChatWallpaperAssetRoot) &&
      !path.startsWith(kLightThemeChatWallpaperAssetRoot);
}

String themedChatWallpaperAssetPath(
  String assetPath, {
  required bool darkMode,
}) {
  final path = assetPath.trim();
  final fileName = _bundledChatWallpaperFileName(path);
  if (path.isEmpty || fileName.isEmpty) return path;
  // The featured set is dark-only (no improved_light/ counterpart) — never swap
  // those or we'd point at a missing asset. Everything else is a light/dark
  // pair (secureN.jpg, chat_default.jpg, …) and swaps per theme as before.
  if (kFeaturedChatWallpaperBasenames.contains(fileName)) return path;

  if (darkMode) {
    return isLightThemeChatWallpaperAssetPath(path)
        ? '$kBundledChatWallpaperAssetRoot$fileName'
        : path;
  }

  return isDarkThemeChatWallpaperAssetPath(path)
      ? '$kLightThemeChatWallpaperAssetRoot$fileName'
      : path;
}

String _bundledChatWallpaperFileName(String assetPath) {
  final extension = p.extension(assetPath).toLowerCase();
  if (extension == '.png') {
    final baseName = p.basenameWithoutExtension(assetPath).trim();
    return baseName.isEmpty ? '' : '$baseName.jpg';
  }
  return p.basename(assetPath).trim();
}

bool isValidChatWallpaperId(String id) {
  final normalized = normalizeChatWallpaperId(id);
  if (normalized == kGlobalChatWallpaperSelectionId) return true;
  if (kBuiltInChatWallpaperIds.contains(normalized)) return true;
  return decodeAssetChatWallpaperId(normalized) != null ||
      decodeFileChatWallpaperId(normalized) != null ||
      decodeServerChatWallpaperId(normalized) != null ||
      decodeAnimatedChatWallpaperStyle(normalized) != null;
}

String resolveEffectiveChatWallpaperId({
  required String selectionId,
  required String defaultId,
}) {
  final normalizedSelectionId = normalizeChatWallpaperId(selectionId);
  final normalizedDefaultId = normalizeChatWallpaperId(defaultId);
  if (normalizedSelectionId == kGlobalChatWallpaperSelectionId) {
    return isValidChatWallpaperId(normalizedDefaultId) &&
            normalizedDefaultId != kGlobalChatWallpaperSelectionId
        ? normalizedDefaultId
        : 'default';
  }
  return isValidChatWallpaperId(normalizedSelectionId)
      ? normalizedSelectionId
      : 'default';
}

String themeStandardChatWallpaperId({required bool darkMode}) {
  return encodeAssetChatWallpaperId(
    darkMode
        ? kDarkThemeStandardChatWallpaperAssetPath
        : kLightThemeStandardChatWallpaperAssetPath,
  );
}

Color _mixColor(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

List<Color> themedLightSolidChatWallpaperColors(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return <Color>[
    _mixColor(cs.surface, cs.primaryContainer, 0.26),
    _mixColor(cs.surfaceContainerHighest, cs.secondaryContainer, 0.20),
  ];
}

List<Color> themedDarkSolidChatWallpaperColors(BuildContext context) {
  // The "midnight" wallpaper is the per-theme deep solid background:
  // pure black for Flutter Dash and Graphite, near-black with a faint hue
  // of the active theme for the rest. The deep color is published via
  // ChatVisualsThemeExtension so we keep a single source of truth (set in
  // main.dart from the resolved AppThemePreset).
  final visuals = Theme.of(context).extension<ChatVisualsThemeExtension>();
  if (visuals != null) {
    final deep = visuals.chatWallpaperDeepColor;
    return <Color>[deep, deep];
  }
  // Fallback (tests / contexts without the extension installed): keep the
  // legacy ColorScheme-derived gradient so existing behaviour is preserved.
  final cs = Theme.of(context).colorScheme;
  return <Color>[
    _mixColor(cs.surface, cs.primary, 0.18),
    _mixColor(cs.surfaceContainerHighest, cs.tertiary, 0.12),
  ];
}

Future<List<String>> loadBundledChatWallpaperAssets() async {
  List<String> keys = const <String>[];

  bool isWallpaperAsset(String k) {
    if (!k.startsWith(kBundledChatWallpaperAssetRoot)) return false;
    final lower = k.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    keys = manifest
        .listAssets()
        .where(isWallpaperAsset)
        .toList(growable: false);
  } catch (_) {
    try {
      final json = await rootBundle.loadString('AssetManifest.json');
      final map = (jsonDecode(json) as Map<String, dynamic>);
      keys = map.keys.where(isWallpaperAsset).toList(growable: false);
    } catch (e) {
      if (!kReleaseMode) {
        debugPrint('Wallpaper manifest load failed: $e');
      }
      return const <String>[];
    }
  }

  final out = keys.toList(growable: false)..sort();
  return out;
}

String _assetTitleFromPath(String assetPath) {
  final base = p.basenameWithoutExtension(assetPath);
  final pretty = base
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (pretty.isEmpty) return 'Wallpaper';
  return pretty;
}

String _fileTitleFromPath(String filePath) {
  final base = p.basenameWithoutExtension(filePath);
  final pretty = base
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (pretty.isEmpty) return 'Wallpaper';
  return pretty;
}

List<ChatWallpaperOption> buildChatWallpaperOptions(
  BuildContext context, {
  required List<String> assetPaths,
  List<String> filePaths = const <String>[],
  List<({String id, String title})> serverWallpapers =
      const <({String id, String title})>[],
  required bool includeGlobalOption,
}) {
  final cs = Theme.of(context).colorScheme;

  final options = <ChatWallpaperOption>[];
  final darkMode = Theme.of(context).brightness == Brightness.dark;

  if (includeGlobalOption) {
    options.add(
      ChatWallpaperOption(
        id: kGlobalChatWallpaperSelectionId,
        title: wave1Text(
          context,
          ru: 'Как в настройках',
          en: 'Use default',
          uk: 'Як у налаштуваннях',
          es: 'Usar predeterminado',
          pt: 'Usar predefinicao',
          ptBr: 'Usar padrao',
          fr: 'Utiliser par defaut',
          de: 'Standard verwenden',
        ),
        colors: [cs.surfaceContainerHighest, cs.surfaceContainerLow],
      ),
    );
  }

  options.addAll([
    ChatWallpaperOption(
      id: 'default',
      title: wave1Text(context, ru: 'Классика', en: 'Classic'),
      colors: themedLightSolidChatWallpaperColors(context),
    ),
    ChatWallpaperOption(
      id: 'midnight',
      title: wave1Text(context, ru: 'Ночной', en: 'Midnight'),
      colors: themedDarkSolidChatWallpaperColors(context),
    ),
  ]);

  // Animated premium wallpapers (Telegram-style, rendered locally via
  // TelegramWallpaper). Shown for everyone; premium-gated by the caller
  // (cosmetic_catalog treats `anim:` ids as premium → lock badge + paywall).
  for (final style in WallpaperStyles.all) {
    options.add(
      ChatWallpaperOption(
        id: encodeAnimatedChatWallpaperId(style.key),
        title: style.name,
      ),
    );
  }

  // Featured wallpapers (the supplied dark doodle set) come first, before the
  // other standard bundled wallpapers; the rest keep their incoming order.
  bool isFeatured(String path) =>
      kFeaturedChatWallpaperBasenames.any((b) => path.endsWith('/$b'));
  final orderedAssetPaths = <String>[
    for (final basename in kFeaturedChatWallpaperBasenames)
      ...assetPaths.where((path) => path.endsWith('/$basename')),
    ...assetPaths.where((path) => !isFeatured(path)),
  ];

  for (final assetPath in orderedAssetPaths) {
    final normalizedAssetPath = assetPath.trim();
    if (normalizedAssetPath.isEmpty) continue;
    final showForTheme = darkMode
        ? isDarkThemeChatWallpaperAssetPath(normalizedAssetPath)
        : isLightThemeChatWallpaperAssetPath(normalizedAssetPath);
    if (!showForTheme) continue;
    options.add(
      ChatWallpaperOption(
        id: encodeAssetChatWallpaperId(normalizedAssetPath),
        title: _assetTitleFromPath(normalizedAssetPath),
        assetPath: normalizedAssetPath,
      ),
    );
  }

  for (final filePath in filePaths) {
    final normalizedFilePath = filePath.trim();
    if (normalizedFilePath.isEmpty || !File(normalizedFilePath).existsSync()) {
      continue;
    }
    options.add(
      ChatWallpaperOption(
        id: encodeFileChatWallpaperId(normalizedFilePath),
        title: _fileTitleFromPath(normalizedFilePath),
        filePath: normalizedFilePath,
      ),
    );
  }

  // Server-hosted premium wallpapers (previewed + rendered via
  // buildChatWallpaperBackground → _ServerChatWallpaperBackground).
  for (final entry in serverWallpapers) {
    final itemId = entry.id.trim();
    if (itemId.isEmpty) continue;
    final title = entry.title.trim();
    options.add(
      ChatWallpaperOption(
        id: encodeServerChatWallpaperId(itemId),
        title: title.isEmpty ? 'Premium' : title,
      ),
    );
  }

  return options;
}

String chatWallpaperDisplayTitle(
  BuildContext context,
  String id, {
  required List<String> assetPaths,
  List<String> filePaths = const <String>[],
  required bool includeGlobalOption,
}) {
  final normalizedId = normalizeChatWallpaperId(id);
  final options = buildChatWallpaperOptions(
    context,
    assetPaths: assetPaths,
    filePaths: filePaths,
    includeGlobalOption: includeGlobalOption,
  );
  for (final o in options) {
    if (o.id == normalizedId) return o.title;
  }
  final assetPath = decodeAssetChatWallpaperId(normalizedId);
  if (assetPath != null) return _assetTitleFromPath(assetPath);
  final filePath = decodeFileChatWallpaperId(normalizedId);
  if (filePath != null) return _fileTitleFromPath(filePath);
  return wave1Text(context, ru: 'Классика', en: 'Classic');
}


/// Widest a wallpaper is ever DRAWN, in physical pixels — the only number that
/// should drive how big it is decoded.
///
/// 🔴 MEMORY (2026-08-01, field): wallpapers were handed to `AssetImage` and
/// `FileImage` raw, so a 1440x2560 asset was decoded at full size — 14.1 MB of
/// RAM — whether it filled the screen or sat in a 120 dp picker tile. The
/// bundle carries 18 of them; the picker alone could ask for 254 MB against a
/// 128 MB image cache, which does not just waste memory, it THRASHES: the cache
/// evicts and re-decodes in a loop, and every decode is tens of milliseconds on
/// the very thread that has 8.3 ms to draw a frame at 120 Hz. That is the
/// "scrolling is not smooth" report, and the 1.25 GB process seen in the log.
///
/// Decoding to the size actually painted is the standard remedy: identical
/// pixels on screen, a fraction of the memory. Preview tiles shrink ~29x.
int chatWallpaperDecodeWidth(BuildContext context, {required bool preview}) {
  final view = MediaQuery.maybeOf(context);
  final dpr = (view?.devicePixelRatio ?? 1.0).clamp(1.0, 4.0);
  if (preview) {
    // A picker tile is a thumbnail. 320 physical px covers the largest tile on
    // the widest phone with room to spare, and is ~0.4 MB instead of 14 MB.
    return 320;
  }
  final logicalWidth = view?.size.width ?? 420.0;
  // Full-bleed: the screen width is all that can ever be shown. `BoxFit.cover`
  // may crop horizontally, never stretch beyond it.
  return (logicalWidth * dpr).round().clamp(360, 2160);
}

/// [provider], decoded no wider than [maxWidth].
///
/// `allowUpscaling: false` so a small custom wallpaper is never blown up — it
/// would cost memory AND look worse.
ImageProvider<Object> sizedChatWallpaper(
  ImageProvider<Object> provider,
  int maxWidth,
) => ResizeImage(provider, width: maxWidth, allowUpscaling: false);

Widget buildChatWallpaperBackground(
  BuildContext context,
  String wallpaperId, {
  bool preview = false,
  ChatWallpaperAnimMode animMode = ChatWallpaperAnimMode.onEnter,
  bool conduct = false,
  GlobalKey<TelegramWallpaperState>? animKey,
  WallpaperBlurController? blurController,
}) {
  final normalizedWallpaperId = normalizeChatWallpaperId(wallpaperId);
  final rawAssetPath = decodeAssetChatWallpaperId(normalizedWallpaperId);
  if (rawAssetPath != null) {
    final assetPath = themedChatWallpaperAssetPath(
      rawAssetPath,
      darkMode: Theme.of(context).brightness == Brightness.dark,
    );
    final decodeWidth = chatWallpaperDecodeWidth(context, preview: preview);
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: sizedChatWallpaper(AssetImage(assetPath), decodeWidth),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
  final filePath = decodeFileChatWallpaperId(normalizedWallpaperId);
  if (filePath != null) {
    final decodeWidth = chatWallpaperDecodeWidth(context, preview: preview);
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: sizedChatWallpaper(FileImage(File(filePath)), decodeWidth),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  final serverItemId = decodeServerChatWallpaperId(normalizedWallpaperId);
  if (serverItemId != null) {
    // Server-hosted wallpaper: downloaded + cached asynchronously, so render via
    // a stateful widget that shows a gradient until the file is on disk.
    return _ServerChatWallpaperBackground(
      itemId: serverItemId,
      preview: preview,
    );
  }

  final animStyle = decodeAnimatedChatWallpaperStyle(normalizedWallpaperId);
  if (animStyle != null) {
    // Grid previews render a single static frame (no looping animations in the
    // picker); the live chat drives the motion via [animMode] + [animKey].
    return TelegramWallpaper(
      key: animKey,
      style: animStyle,
      mode: preview ? ChatWallpaperAnimMode.off : animMode,
      // Плитки выбора обоев НИКОГДА не проводят сообщения: их на экране
      // десяток, и каждая тянула бы поле, шейдер и свой контроллер.
      conduct: preview ? false : conduct,
      blurController: blurController,
    );
  }

  switch (normalizedWallpaperId) {
    case 'midnight':
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themedDarkSolidChatWallpaperColors(context),
          ),
        ),
      );
    default:
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themedLightSolidChatWallpaperColors(context),
          ),
        ),
      );
  }
}

/// Background for a server-hosted wallpaper: resolves the catalog item, downloads
/// + caches the full image, and renders it. Shows a neutral themed gradient
/// while the download is in flight or if it fails — best-effort, never throws
/// into the UI.
class _ServerChatWallpaperBackground extends StatefulWidget {
  const _ServerChatWallpaperBackground({
    required this.itemId,
    this.preview = false,
  });

  final String itemId;

  /// When true, render the small low-quality thumbnail (~a few KB) for grid
  /// previews instead of downloading the full-resolution image. The full image
  /// is fetched only when the wallpaper is actually applied (preview == false).
  final bool preview;

  @override
  State<_ServerChatWallpaperBackground> createState() =>
      _ServerChatWallpaperBackgroundState();
}

class _ServerChatWallpaperBackgroundState
    extends State<_ServerChatWallpaperBackground> {
  late Future<File?> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(_ServerChatWallpaperBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId ||
        oldWidget.preview != widget.preview) {
      _future = _resolve();
    }
  }

  Future<File?> _resolve() async {
    final service = CosmeticsCatalogService.instance;
    final item = await service.itemById(widget.itemId);
    if (item == null) return null;
    // Grid previews use the tiny thumb variant (~3 KB) so opening the picker
    // doesn't download dozens of full-resolution wallpapers at once; the full
    // image is fetched only when the wallpaper is applied.
    return widget.preview ? service.thumbFile(item) : service.fullFile(item);
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
            ),
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: darkMode
                  ? themedDarkSolidChatWallpaperColors(context)
                  : themedLightSolidChatWallpaperColors(context),
            ),
          ),
        );
      },
    );
  }
}
