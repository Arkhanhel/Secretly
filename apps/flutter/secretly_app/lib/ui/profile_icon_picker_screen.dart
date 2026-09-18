// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../app/app_controller.dart';
import '../app/profile_icon_gradients.dart';
import '../billing/show_paywall.dart';
import '../cosmetics/cosmetics_catalog_service.dart';
import '../entitlements/cosmetic_catalog.dart';
import 'app_asset_paths.dart';
import 'avatar_catalog.dart';
import 'icons/app_icons.dart';
import 'paywall_screen.dart';
import 'profile_icon_asset_catalog.dart';
import 'wave1_l10n.dart';
import 'widgets/frosted_header_island.dart';

/// Prefix marking a server-hosted cosmetic icon selection (vs a bundled asset
/// path). The suffix is the catalog item id.
const String kServerIconRefPrefix = 'server:';

/// Top-level sections of the picker grid: the existing icon catalog (local +
/// server-hosted) vs the bundled DiceBear avatars.
enum _PickerCategory { icons, avatars }

class ProfileIconSelection {
  const ProfileIconSelection({
    required this.assetPath,
    required this.gradientIndex,
    required this.gradientStartArgb,
    required this.gradientEndArgb,
    required this.iconScale,
    this.iconBytes,
  });

  /// Bundled asset path, or a `server:<id>` token for server-hosted icons.
  final String assetPath;
  final int gradientIndex;
  final int gradientStartArgb;
  final int gradientEndArgb;
  final double iconScale;

  /// Full-resolution icon bytes — non-null only for server-hosted icons (already
  /// downloaded + integrity-checked). Callers composite from these instead of
  /// loading a bundled asset.
  final Uint8List? iconBytes;

  bool get isServerIcon => iconBytes != null;
}

class ProfileIconPickerScreen extends StatefulWidget {
  const ProfileIconPickerScreen({
    super.key,
    required this.controller,
    this.initialAssetPath,
    this.initialGradientIndex = 0,
    this.onApplySelection,
    this.title = 'Выбрать иконку',
    this.applyButtonLabel = 'Установить',
    this.gatePremium = true,
  });

  final AppController controller;
  final String? initialAssetPath;
  final int initialGradientIndex;
  final Future<void> Function(ProfileIconSelection selection)? onApplySelection;
  final String title;
  final String applyButtonLabel;

  /// When false, every icon is free (no premium lock / paywall). Used for the
  /// contact-icon picker — a purely local label cosmetic that stays free even
  /// for premium icons. Own-profile and room icons keep the gate (`true`).
  final bool gatePremium;

  @override
  State<ProfileIconPickerScreen> createState() =>
      _ProfileIconPickerScreenState();
}

class _ProfileIconPickerScreenState extends State<ProfileIconPickerScreen> {
  static const _assetsPrefix = '${AppAssetPaths.pngIconsDir}/';

  List<ProfileIconGradientPair> get _gradients => kProfileIconPrimaryGradients;
  List<ProfileIconGradientPair> get _lightGradients =>
      kProfileIconSecondaryGradients;
  List<ProfileIconGradientPair> get _allGradients => kProfileIconAllGradients;

  // Icon catalog (local bundled icons + appended server-hosted tokens).
  List<String> _allAssets = <String>[];
  // Bundled DiceBear avatar paths — a separate, always-free category.
  final List<String> _avatarAssets = List<String>.from(kAvatarAssetPaths);
  // Currently visible (post-search) tiles for the active category.
  List<String> _filteredAssets = <String>[];
  _PickerCategory _category = _PickerCategory.icons;
  // The first kFreeProfileIconCount catalog icons are free; the rest are
  // premium (locked behind the cosmetic gate). Path-based so it survives search
  // filtering. `_cosmeticUnlocked` is re-read after the paywall returns.
  Set<String> _freeAssetSet = <String>{};
  bool _cosmeticUnlocked = false;
  String? _selectedAsset;
  int _selectedGradientIndex = 0;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  double _iconScale = 1.0;
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  // Server-hosted premium icons, keyed by their `server:<id>` token.
  final Map<String, RemoteCosmeticItem> _serverById =
      <String, RemoteCosmeticItem>{};

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.initialAssetPath;
    _selectedGradientIndex = widget.initialGradientIndex.clamp(
      0,
      _allGradients.length - 1,
    );
    // Open straight to the avatars tab when re-editing a bundled-avatar pick.
    if (_isAvatarToken(widget.initialAssetPath)) {
      _category = _PickerCategory.avatars;
    }
    _searchController.addListener(_applySearch);
    _initializeAssets();
    _loadServerIcons();
  }

  bool _isServerToken(String token) => token.startsWith(kServerIconRefPrefix);

  /// True for a bundled DiceBear avatar path (lives under [kAvatarAssetDir]).
  bool _isAvatarToken(String? token) =>
      token != null && token.startsWith('$kAvatarAssetDir/');

  /// Best-effort: append server-hosted premium icons to the grid. No-op (and no
  /// error surfaced) when the catalog is empty / unreachable.
  Future<void> _loadServerIcons() async {
    try {
      final service = CosmeticsCatalogService.instance
        ..configure(widget.controller.relayHttpBaseUrl);
      final items = await service.icons();
      if (!mounted || items.isEmpty) return;
      final tokens = <String>[];
      for (final item in items) {
        final token = '$kServerIconRefPrefix${item.id}';
        _serverById[token] = item;
        tokens.add(token);
      }
      _allAssets = <String>[..._allAssets, ...tokens];
      _applySearch(); // re-filters over the expanded set + rebuilds
    } catch (_) {
      // best-effort — leave the bundled grid as-is
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeAssets() {
    final keys = profileIconAssetCatalog
        .where(
          (k) =>
              k.startsWith(_assetsPrefix) && k.toLowerCase().endsWith('.png'),
        )
        .toList(growable: false);
    _allAssets = keys;
    _freeAssetSet = profileIconAssetCatalog.take(kFreeProfileIconCount).toSet();
    // Re-read through the gate (kFreeProfileIconCount is the first premium index,
    // so this is true iff the cosmetic gate is unlocked / fails open).
    _cosmeticUnlocked = isProfileIconAllowed(
      widget.controller.entitlementStateNow,
      kFreeProfileIconCount,
    );
    _loadError = keys.isEmpty ? 'Иконки PNG не найдены в ассетах' : null;
    if ((_selectedAsset == null || _selectedAsset!.isEmpty) &&
        keys.isNotEmpty) {
      _selectedAsset = keys.first;
    }
    // Seed the visible list from the active category (avatars when re-editing a
    // bundled-avatar pick, icons otherwise).
    _filteredAssets = _activeSource;
    _loading = false;
  }

  Widget _profileIconAssetImage(
    String assetPath, {
    BoxFit fit = BoxFit.contain,
    double? width,
    double? height,
    double fallbackSize = 24,
  }) {
    return Image.asset(
      assetPath,
      fit: fit,
      width: width,
      height: height,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Icon(
        AppIcons.emoji,
        size: fallbackSize,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Full (pre-search) tile list for the active category.
  List<String> get _activeSource =>
      _category == _PickerCategory.avatars ? _avatarAssets : _allAssets;

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    final source = _activeSource;
    if (q.isEmpty) {
      setState(() => _filteredAssets = source);
      return;
    }
    setState(() {
      _filteredAssets = source
          .where((a) {
            if (_isServerToken(a)) {
              final title = _serverById[a]?.title.toLowerCase() ?? '';
              return title.contains(q) || a.toLowerCase().contains(q);
            }
            return a.toLowerCase().contains(q);
          })
          .toList(growable: false);
    });
  }

  void _selectCategory(_PickerCategory next) {
    if (_category == next) return;
    _category = next;
    // Re-filter the new category's source against the current query (setState).
    _applySearch();
  }

  bool _isAllowed(String asset) =>
      !widget.gatePremium ||
      _isAvatarToken(asset) ||
      _cosmeticUnlocked ||
      _freeAssetSet.contains(asset);

  Future<void> _onIconTap(String asset) async {
    if (_isAllowed(asset)) {
      setState(() => _selectedAsset = asset);
      return;
    }
    // Premium icon while locked → open the paywall (cosmetic trigger). If the
    // user unlocks, select it immediately; otherwise leave the selection as-is.
    await showPaywall(context, PaywallTrigger.cosmetic);
    if (!mounted) return;
    final unlocked = isProfileIconAllowed(
      widget.controller.entitlementStateNow,
      kFreeProfileIconCount,
    );
    setState(() {
      _cosmeticUnlocked = unlocked;
      if (unlocked) _selectedAsset = asset;
    });
  }

  Future<void> _applySelection() async {
    final asset = _selectedAsset;
    if (asset == null || asset.isEmpty || _saving) return;
    // Defensive: never apply a premium icon while locked (the grid gates taps,
    // but the initial selection could be a premium icon).
    if (!_isAllowed(asset)) {
      await showPaywall(context, PaywallTrigger.cosmetic);
      if (!mounted) return;
      final unlocked = isProfileIconAllowed(
        widget.controller.entitlementStateNow,
        kFreeProfileIconCount,
      );
      setState(() => _cosmeticUnlocked = unlocked);
      if (!unlocked) return;
    }
    final gradient = _allGradients[_selectedGradientIndex];

    setState(() => _saving = true);
    try {
      // Server-hosted icons: download + integrity-check the full asset, then
      // carry its bytes through the selection (no bundled asset path exists).
      Uint8List? iconBytes;
      if (_isServerToken(asset)) {
        final item = _serverById[asset];
        if (item == null) {
          throw StateError('Иконка недоступна');
        }
        final file = await CosmeticsCatalogService.instance.fullFile(item);
        if (file == null) {
          throw StateError('Не удалось загрузить иконку');
        }
        iconBytes = await file.readAsBytes();
      }
      final selection = ProfileIconSelection(
        assetPath: asset,
        gradientIndex: _selectedGradientIndex,
        gradientStartArgb: gradient.startArgb,
        gradientEndArgb: gradient.endArgb,
        iconScale: _iconScale,
        iconBytes: iconBytes,
      );
      if (widget.onApplySelection != null) {
        await widget.onApplySelection!(selection);
      } else if (iconBytes != null) {
        await widget.controller.setMyAvatarFromIconBytes(
          iconBytes: iconBytes,
          iconRefId: selection.assetPath,
          gradientIndex: selection.gradientIndex,
          gradientStartArgb: selection.gradientStartArgb,
          gradientEndArgb: selection.gradientEndArgb,
          iconScale: selection.iconScale,
        );
      } else {
        await widget.controller.setMyAvatarFromIconAsset(
          assetPath: selection.assetPath,
          gradientIndex: selection.gradientIndex,
          gradientStartArgb: selection.gradientStartArgb,
          gradientEndArgb: selection.gradientEndArgb,
          iconScale: selection.iconScale,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            wave1Text(
              context,
              ru: 'Ошибка: $e',
              en: 'Error: $e',
              uk: 'Помилка: $e',
              es: 'Error: $e',
              pt: 'Erro: $e',
              ptBr: 'Erro: $e',
              fr: 'Erreur : $e',
              de: 'Fehler: $e',
            ),
          ),
        ),
      );
      setState(() => _saving = false);
    }
  }

  String _fileName(String assetPath) {
    final slash = assetPath.lastIndexOf('/');
    return slash >= 0 ? assetPath.substring(slash + 1) : assetPath;
  }

  String _displayName(String token) {
    if (_isServerToken(token)) {
      final t = _serverById[token]?.title ?? '';
      return t.isNotEmpty ? t : token.substring(kServerIconRefPrefix.length);
    }
    return _fileName(token);
  }

  /// Image for a grid tile / preview: bundled `Image.asset`, or a cached server
  /// thumbnail (or full, for the preview) via [_ServerIconImage]. Bundled
  /// avatars flagged in [kAnimatedAvatarBasenames] get a subtle idle animation.
  Widget _iconImageFor(
    String token, {
    double fallbackSize = 24,
    bool full = false,
  }) {
    if (_isAvatarToken(token)) {
      final image = _profileIconAssetImage(token, fallbackSize: fallbackSize);
      return avatarPathIsAnimated(token) ? _IdleAvatar(child: image) : image;
    }
    if (_isServerToken(token)) {
      final item = _serverById[token];
      if (item == null) {
        return Icon(
          AppIcons.emoji,
          size: fallbackSize,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      }
      return _ServerIconImage(
        item: item,
        useFull: full,
        fallbackSize: fallbackSize,
      );
    }
    return _profileIconAssetImage(token, fallbackSize: fallbackSize);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gradient = _allGradients[_selectedGradientIndex];
    final previewGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(gradient.startArgb), Color(gradient.endArgb)],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 58, 16, 14),
                    child: Column(
                      children: [
                        // Preview avatar + vertical icon-size slider to its right.
                        SizedBox(
                          height: 138,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: previewGradient,
                                ),
                                child: _selectedAsset == null
                                    ? const Icon(
                                        Icons.emoji_emotions_outlined,
                                        size: 52,
                                        color: Colors.white,
                                      )
                                    : ClipOval(
                                        child: Center(
                                          child: SizedBox(
                                            width: 120 * _iconScale,
                                            height: 120 * _iconScale,
                                            child: _iconImageFor(
                                              _selectedAsset!,
                                              fallbackSize: 52,
                                              full: true,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 18),
                              FrostedHeaderIsland(
                                radius: 22,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 10,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.text_fields,
                                      size: 16,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    SizedBox(
                                      height: 116,
                                      child: RotatedBox(
                                        quarterTurns: 3,
                                        child: SizedBox(
                                          width: 116,
                                          child: Slider(
                                            value: _iconScale,
                                            min: 0.35,
                                            max: 1.25,
                                            divisions: 18,
                                            label:
                                                '${(_iconScale * 100).round()}%',
                                            onChanged: (v) =>
                                                setState(() => _iconScale = v),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Background gradient palette (glass island).
                        FrostedHeaderIsland(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(_gradients.length, (
                                  index,
                                ) {
                                  final g = _gradients[index];
                                  final selected =
                                      index == _selectedGradientIndex;
                                  return GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedGradientIndex = index,
                                    ),
                                    child: _GradientDot(
                                      gradient: g,
                                      selected: selected,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  _lightGradients.length,
                                  (index) {
                                    final g = _lightGradients[index];
                                    final globalIndex =
                                        _gradients.length + index;
                                    final selected =
                                        globalIndex == _selectedGradientIndex;
                                    return GestureDetector(
                                      onTap: () => setState(
                                        () => _selectedGradientIndex =
                                            globalIndex,
                                      ),
                                      child: _GradientDot(
                                        gradient: g,
                                        selected: selected,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_searchOpen) ...[
                          const SizedBox(height: 12),
                          _GlassSearchField(
                            controller: _searchController,
                            onClose: () => setState(() {
                              _searchOpen = false;
                              _searchController.clear();
                            }),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Category switcher: existing icons vs bundled avatars.
                        _CategorySwitcher(
                          category: _category,
                          iconsLabel: wave1Text(
                            context,
                            ru: 'Иконки',
                            en: 'Icons',
                            uk: 'Іконки',
                            es: 'Iconos',
                            pt: 'Icones',
                            ptBr: 'Icones',
                            fr: 'Icones',
                            de: 'Symbole',
                          ),
                          avatarsLabel: wave1Text(
                            context,
                            ru: 'Аватары',
                            en: 'Avatars',
                            uk: 'Аватари',
                            es: 'Avatares',
                            pt: 'Avatares',
                            ptBr: 'Avatares',
                            fr: 'Avatars',
                            de: 'Avatare',
                          ),
                          onSelect: _selectCategory,
                        ),
                        const SizedBox(height: 12),
                        // Icon / avatar grid (glass island).
                        Expanded(
                          child: FrostedHeaderIsland(
                            radius: 20,
                            padding: const EdgeInsets.all(10),
                            child: _filteredAssets.isEmpty
                                ? Center(
                                    child: Text(
                                      _category == _PickerCategory.avatars
                                          ? wave1Text(
                                              context,
                                              ru: 'Аватары не найдены',
                                              en: 'No avatars found',
                                              uk: 'Аватари не знайдено',
                                              es: 'No se encontraron avatares',
                                              pt: 'Nenhum avatar encontrado',
                                              ptBr: 'Nenhum avatar encontrado',
                                              fr: 'Aucun avatar trouve',
                                              de: 'Keine Avatare gefunden',
                                            )
                                          : (_loadError ?? 'Иконки не найдены'),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  )
                                : GridView.builder(
                                    itemCount: _filteredAssets.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 6,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                        ),
                                    itemBuilder: (context, index) {
                                      final asset = _filteredAssets[index];
                                      final selected = asset == _selectedAsset;
                                      final locked = !_isAllowed(asset);
                                      return Tooltip(
                                        message: _displayName(asset),
                                        child: GestureDetector(
                                          onTap: () => _onIconTap(asset),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              color: selected
                                                  ? cs.primary.withValues(
                                                      alpha: 0.20,
                                                    )
                                                  : Colors.white.withValues(
                                                      alpha: 0.04,
                                                    ),
                                              border: Border.all(
                                                color: selected
                                                    ? cs.primary
                                                    : Colors.white.withValues(
                                                        alpha: 0.10,
                                                      ),
                                                width: selected ? 2 : 1,
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(7),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Opacity(
                                                  opacity: locked ? 0.45 : 1.0,
                                                  child: _iconImageFor(asset),
                                                ),
                                                if (locked)
                                                  const Align(
                                                    alignment:
                                                        Alignment.bottomRight,
                                                    child: _PremiumLockBadge(),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _applySelection,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _saving
                                  ? const CircularProgressIndicator()
                                  : Text(widget.applyButtonLabel),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Floating glass islands: back (left) + search toggle (right).
                  Positioned(
                    top: 4,
                    left: 12,
                    child: _GlassIconIsland(
                      icon: Icons.arrow_back_ios_new,
                      tooltip: 'Назад',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 12,
                    child: _GlassIconIsland(
                      icon: _searchOpen ? Icons.close : Icons.search,
                      tooltip: 'Поиск',
                      onTap: () => setState(() {
                        _searchOpen = !_searchOpen;
                        if (!_searchOpen) _searchController.clear();
                      }),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Neutral frosted-glass round icon button for the floating back / search
/// controls (replaces the old top app bar) — liquid-glass, no solid colour.
class _GlassIconIsland extends StatelessWidget {
  const _GlassIconIsland({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget island = FrostedHeaderIsland(
      radius: 22,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: cs.onSurface),
        ),
      ),
    );
    if (tooltip != null) {
      island = Tooltip(message: tooltip!, child: island);
    }
    return island;
  }
}

/// Frosted-glass inline search field, shown when the search island is toggled.
class _GlassSearchField extends StatelessWidget {
  const _GlassSearchField({required this.controller, required this.onClose});

  final TextEditingController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FrostedHeaderIsland(
      radius: 16,
      padding: const EdgeInsets.only(left: 14, right: 4),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Поиск',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _GradientDot extends StatelessWidget {
  const _GradientDot({required this.gradient, required this.selected});

  final ProfileIconGradientPair gradient;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: selected ? 32 : 28,
      height: selected ? 32 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(gradient.startArgb), Color(gradient.endArgb)],
        ),
        border: selected
            ? Border.all(color: cs.onSurface, width: 2)
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
    );
  }
}

/// Renders a server-hosted cosmetic icon from its on-disk cache (downloading +
/// integrity-checking on first use). Spinner while loading, fallback glyph on
/// failure.
class _ServerIconImage extends StatefulWidget {
  const _ServerIconImage({
    required this.item,
    this.useFull = false,
    this.fallbackSize = 24,
  });

  final RemoteCosmeticItem item;
  final bool useFull;
  final double fallbackSize;

  @override
  State<_ServerIconImage> createState() => _ServerIconImageState();
}

class _ServerIconImageState extends State<_ServerIconImage> {
  // Cache the resolve future per State so the 750-tile GridView's constant
  // rebuilds (scroll recycle, search/selection setState, paywall return) don't
  // restart a fresh download future every frame and flicker the icon back to the
  // emoji fallback. Only re-resolve when the tile is recycled to a new item.
  late Future<File?> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(_ServerIconImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.useFull != widget.useFull) {
      _future = _resolve();
    }
  }

  Future<File?> _resolve() async {
    final service = CosmeticsCatalogService.instance;
    Future<File?> fetch() => widget.useFull
        ? service.fullFile(widget.item)
        : service.thumbFile(widget.item);
    var file = await fetch();
    // One bounded retry: under the first-load burst a transient download/decode
    // failure would otherwise pin this tile to the emoji fallback forever.
    if (file == null && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      file = await fetch();
    }
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final fallbackSize = widget.fallbackSize;
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => Icon(
              AppIcons.emoji,
              size: fallbackSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: fallbackSize * 0.7,
              height: fallbackSize * 0.7,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Icon(
          AppIcons.emoji,
          size: fallbackSize,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      },
    );
  }
}

/// Small gold "premium" lock chip overlaid on locked icon tiles. Gold is used
/// only as a tiny accent (per the app's premium design taste).
class _PremiumLockBadge extends StatelessWidget {
  const _PremiumLockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6D365), Color(0xFFD4A11E)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(Icons.lock, size: 10, color: Colors.white),
    );
  }
}

/// Two-segment glass switcher choosing between the icon catalog and the bundled
/// avatars. Matches the frosted-island styling used across this screen.
class _CategorySwitcher extends StatelessWidget {
  const _CategorySwitcher({
    required this.category,
    required this.iconsLabel,
    required this.avatarsLabel,
    required this.onSelect,
  });

  final _PickerCategory category;
  final String iconsLabel;
  final String avatarsLabel;
  final ValueChanged<_PickerCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return FrostedHeaderIsland(
      radius: 16,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _CategorySegment(
              label: iconsLabel,
              icon: Icons.grid_view_rounded,
              selected: category == _PickerCategory.icons,
              onTap: () => onSelect(_PickerCategory.icons),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _CategorySegment(
              label: avatarsLabel,
              icon: Icons.face_retouching_natural,
              selected: category == _PickerCategory.avatars,
              onTap: () => onSelect(_PickerCategory.avatars),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySegment extends StatelessWidget {
  const _CategorySegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? cs.primary.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected ? cs.primary : Colors.white.withValues(alpha: 0.10),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a static avatar image in a subtle, looping idle animation — a gentle
/// scale breathing (1.0 ↔ 1.05). Premium and unobtrusive; no new assets.
class _IdleAvatar extends StatefulWidget {
  const _IdleAvatar({required this.child});

  final Widget child;

  @override
  State<_IdleAvatar> createState() => _IdleAvatarState();
}

class _IdleAvatarState extends State<_IdleAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
