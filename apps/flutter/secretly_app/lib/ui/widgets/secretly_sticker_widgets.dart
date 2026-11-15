// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import '../scroll_feel.dart';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:lottie/lottie.dart';

import '../../app/app_controller.dart';
import '../../stickers/sticker_catalog.dart';
import '../../stickers/sticker_share_mode.dart';
import '../icons/app_icons.dart';
import '../l10n.dart';
import 'broken_media_box.dart';
import 'sticker_pack_access_picker.dart';


class SecretlyStickerAssetView extends StatelessWidget {
  const SecretlyStickerAssetView({
    super.key,
    required this.sticker,
    required this.size,
    this.fit = BoxFit.contain,
  });

  final SecretlyStickerDescriptor sticker;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dimension = size.clamp(24.0, 280.0);
    final child = switch (sticker.assetSource) {
      SecretlyStickerAssetSource.bundledAsset => switch (sticker.format) {
        SecretlyStickerFormat.lottie => Lottie.asset(
          sticker.assetPath,
          width: dimension,
          height: dimension,
          fit: fit,
          repeat: true,
        ),
        // png AND animated webp both render via Image — Flutter's codec plays
        // animated WebP inline with no controller (ideal for grids + bubbles).
        SecretlyStickerFormat.png || SecretlyStickerFormat.webp => Image.asset(
          sticker.assetPath,
          width: dimension,
          height: dimension,
          fit: fit,
          filterQuality: FilterQuality.high,
        ),
      },
      SecretlyStickerAssetSource.file => _fileStickerChild(
        sticker: sticker,
        dimension: dimension,
      ),
      SecretlyStickerAssetSource.missing => _MissingStickerAsset(
        sticker: sticker,
        size: dimension,
      ),
    };
    return SizedBox(
      width: dimension,
      height: dimension,
      child: RepaintBoundary(child: child),
    );
  }

  Widget _fileStickerChild({
    required SecretlyStickerDescriptor sticker,
    required double dimension,
  }) {
    final file = File(sticker.assetPath);
    if (!file.existsSync()) {
      return _MissingStickerAsset(sticker: sticker, size: dimension);
    }
    return switch (sticker.format) {
      SecretlyStickerFormat.lottie => Lottie.file(
        file,
        width: dimension,
        height: dimension,
        fit: fit,
        repeat: true,
      ),
      // Animated WebP plays inline through Image.file (no video_player).
      SecretlyStickerFormat.png || SecretlyStickerFormat.webp => Image.file(
        file,
        width: dimension,
        height: dimension,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 18),
      ),
    };
  }
}

class _MissingStickerAsset extends StatelessWidget {
  const _MissingStickerAsset({required this.sticker, required this.size});

  final SecretlyStickerDescriptor sticker;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emoji = sticker.emojiHint.trim();
    final fontSize = size < 40 ? size * 0.48 : size * 0.42;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.38)),
      ),
      child: Center(
        child: emoji.isNotEmpty
            ? Text(emoji, style: TextStyle(fontSize: fontSize))
            : Icon(
                Icons.sticky_note_2_rounded,
                size: size * 0.44,
                color: cs.onSurfaceVariant,
              ),
      ),
    );
  }
}

class SecretlyStickerPickerTab extends StatefulWidget {
  const SecretlyStickerPickerTab({
    super.key,
    required this.controller,
    required this.recentStickers,
    required this.onStickerSelected,
    this.onCreateSticker,
    this.onAddStickerToPack,
    this.bottomInset = 0,
  });

  final AppController controller;
  final List<SecretlyStickerDescriptor> recentStickers;
  final ValueChanged<SecretlyStickerDescriptor> onStickerSelected;

  /// Tapped the "Создать стикер" affordance — opens the photo→sticker flow.
  /// Null hides the entry (e.g. where sticker creation isn't available).
  final VoidCallback? onCreateSticker;

  /// «+» в окне своего набора — новый стикер сразу в этот набор (15.11.2026).
  /// Null прячет клетку «+».
  final ValueChanged<String>? onAddStickerToPack;
  final double bottomInset;

  @override
  State<SecretlyStickerPickerTab> createState() =>
      _SecretlyStickerPickerTabState();
}

class _SecretlyStickerPickerTabState extends State<SecretlyStickerPickerTab> {
  late String _selectedPackId;
  String? _selectedCategoryTag;
  List<SecretlyStickerPack> _packs = const <SecretlyStickerPack>[];
  bool _loadingPacks = true;
  String _query = '';

  // 🔴 ЛЕНТА РАЗДЕЛОВ (15.11.2026, образец владельца). С 02.07 панель листала
  // наборы страницами; владелец показал образец: одна лента — «Недавние» с
  // клеткой «Создать» первой, затем разделы наборов с заголовками. Значок в
  // верхней полосе прокручивает к разделу, прокрутка подсвечивает значок.
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};
  bool _scrollingToSection = false;

  GlobalKey _sectionKey(String id) =>
      _sectionKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'stickers:$id'));

  String get _fallbackPackId => SecretlyStickerCatalog.defaultPickerPackId;

  List<SecretlyStickerPackCategory> get _availableCategories =>
      SecretlyStickerCatalog.categoriesForPacks(_packs);

  List<SecretlyStickerPack> get _visiblePacks =>
      SecretlyStickerCatalog.filterPacksByCategory(
        _packs,
        _selectedCategoryTag,
      );

  List<SecretlyStickerDescriptor> get _visibleRecentStickers =>
      SecretlyStickerCatalog.filterStickersByCategory(
        widget.recentStickers,
        _selectedCategoryTag,
      );

  SecretlyStickerPack? get _selectedPack =>
      _visiblePacks.where((item) => item.id == _selectedPackId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _selectedPackId = widget.recentStickers.isNotEmpty
        ? SecretlyStickerCatalog.recentPackId
        : _fallbackPackId;
    _scroll.addListener(_syncSelectedSectionWithScroll);
    _loadPacks();
  }

  @override
  void didUpdateWidget(covariant SecretlyStickerPickerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _normalizePickerSelection();
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncSelectedSectionWithScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Порядок разделов — как в верхней полосе: «Недавние» (если есть что
  /// показать или куда нажать «Создать»), затем наборы.
  List<String> _sectionIds(List<SecretlyStickerPack> packs) => [
    if (_visibleRecentStickers.isNotEmpty || widget.onCreateSticker != null)
      SecretlyStickerCatalog.recentPackId,
    for (final pack in packs) pack.id,
  ];

  /// Прокрутить ленту к разделу и подсветить его значок.
  void _goToSection(String sectionId, List<SecretlyStickerPack> packs) {
    setState(() => _selectedPackId = sectionId);
    final ctx = _sectionKeys[sectionId]?.currentContext;
    if (ctx == null) return;
    _scrollingToSection = true;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    ).whenComplete(() => _scrollingToSection = false);
  }

  /// Подсветка значка по прокрутке: последний раздел, чей заголовок уже
  /// поднялся до верха ленты.
  void _syncSelectedSectionWithScroll() {
    if (_scrollingToSection || !mounted) return;
    final viewport = _scroll.position.context.storageContext.findRenderObject();
    if (viewport is! RenderBox) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    String? current;
    for (final entry in _sectionKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy - top;
      if (y <= 12) {
        if (current == null) {
          current = entry.key;
        } else {
          final prevBox = _sectionKeys[current]!.currentContext!
              .findRenderObject()! as RenderBox;
          if (prevBox.localToGlobal(Offset.zero).dy - top < y) {
            current = entry.key;
          }
        }
      }
    }
    current ??= _sectionKeys.keys.firstOrNull;
    if (current != null && current != _selectedPackId) {
      setState(() => _selectedPackId = current!);
    }
  }

  Future<void> _loadPacks({
    bool refresh = true,
    bool rethrowError = false,
  }) async {
    setState(() => _loadingPacks = true);
    try {
      final packs = await widget.controller.loadStickerPickerPacks(
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _packs = packs;
        _normalizePickerSelection();
        _loadingPacks = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingPacks = false);
      if (rethrowError) rethrow;
    }
  }

  void _normalizePickerSelection() {
    final visibleCategoryTags = _availableCategories
        .map((category) => category.tag)
        .toSet();
    if (_selectedCategoryTag != null &&
        !visibleCategoryTags.contains(_selectedCategoryTag)) {
      _selectedCategoryTag = null;
    }

    final visiblePacks = _visiblePacks;
    final visibleRecentStickers = _visibleRecentStickers;
    if (_selectedPackId == SecretlyStickerCatalog.recentPackId) {
      if (_selectedCategoryTag == null ||
          visibleRecentStickers.isNotEmpty ||
          visiblePacks.isEmpty) {
        return;
      }
      _selectedPackId = visiblePacks.first.id;
      return;
    }
    if (visiblePacks.any((pack) => pack.id == _selectedPackId)) {
      return;
    }
    if (visibleRecentStickers.isNotEmpty) {
      _selectedPackId = SecretlyStickerCatalog.recentPackId;
      return;
    }
    _selectedPackId = visiblePacks.firstOrNull?.id ?? _fallbackPackId;
  }

  void _showPackActionSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SecretlySnackBar(content: Text(message)));
  }

  void _showPackActionError({required Object error, required bool installing}) {
    _showPackActionSnack(
      installing
          ? context.l10n.stickerPackInstallFailed('$error')
          : context.l10n.stickerPackRemoveFailed('$error'),
    );
  }

  // Minimal, thin search — no filled background, tight vertical rhythm.
  InputDecoration _searchDecoration(ColorScheme cs, String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        fontSize: 14.5,
      ),
      prefixIcon: Icon(
        Icons.search_rounded,
        size: 17,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      isDense: true,
      isCollapsed: true,
      contentPadding: const EdgeInsets.only(top: 4, bottom: 4),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
    );
  }

  Future<void> _confirmUninstall(SecretlyStickerPack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            dialogContext.l10n.stickerPackRemoveTitle,
          ),
          content: Text(
            dialogContext.l10n.stickerPackRemoveBody(pack.title),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.l10n.stickerPackRemoveAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await widget.controller.uninstallStickerPack(
        packId: pack.id,
        packVersion: pack.version,
      );
      if (!mounted) return;
      await _loadPacks(refresh: false, rethrowError: true);
      if (!mounted) return;
      setState(() {
        if (_selectedPackId == pack.id) {
          _selectedPackId = _packs.firstOrNull?.id ?? _fallbackPackId;
        }
        _normalizePickerSelection();
      });
      _showPackActionSnack(
        context.l10n.stickerPackRemovedSnack(pack.title),
      );
    } catch (error) {
      if (!mounted) return;
      _showPackActionError(error: error, installing: false);
    }
  }

  List<SecretlyStickerDescriptor> _visibleStickers() {
    if (_query.isNotEmpty) {
      return SecretlyStickerCatalog.search(
        _query,
        categoryTag: _selectedCategoryTag,
      );
    }
    if (_selectedPackId == SecretlyStickerCatalog.recentPackId) {
      return _visibleRecentStickers;
    }
    return SecretlyStickerCatalog.filterStickersByCategory(
      _selectedPack?.stickers ?? const <SecretlyStickerDescriptor>[],
      _selectedCategoryTag,
    );
  }

  /// Долгое нажатие: стикер крупно и меню (15.11.2026, образец владельца):
  /// отправить; в избранное или убрать; у своего набора — обложка и удаление.
  Future<void> _showStickerPreview(
    SecretlyStickerDescriptor sticker, {
    SecretlyStickerPack? pack,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final myPid = widget.controller.profileId;
    final favoritesId = 'user:$myPid:favorites';
    final isFavorite = widget.controller.isStickerFavorite(sticker.stickerId);
    final ownPack = pack != null &&
        pack.id.startsWith('user:$myPid:') &&
        pack.id != favoritesId;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        Widget item(String id, IconData icon, String label,
            {bool danger = false}) {
          final color = danger ? Colors.red : cs.onSurface;
          return InkWell(
            key: ValueKey('stickers:preview:$id'),
            onTap: () => Navigator.of(dialogContext).pop(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 16, color: color),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sticker.emojiHint.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    sticker.emojiHint.trim(),
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              SecretlyStickerAssetView(sticker: sticker, size: 220),
              const SizedBox(height: 18),
              Material(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    item('send', Icons.send_rounded,
                        dialogContext.l10n.stickerSend),
                    if (isFavorite)
                      item('unfavorite', Icons.star_rounded,
                          dialogContext.l10n.stickerRemoveFromFavorites)
                    else
                      item('favorite', Icons.star_outline_rounded,
                          dialogContext.l10n.stickerMakeFavorite),
                    if (ownPack) ...[
                      item('cover', Icons.image_outlined,
                          dialogContext.l10n.stickerMakeCover),
                      item('delete', Icons.delete_outline_rounded,
                          dialogContext.l10n.stickerDeleteAction,
                          danger: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      switch (action) {
        case 'send':
          widget.onStickerSelected(sticker);
        case 'favorite':
          await widget.controller.addStickerToFavorites(
            sticker,
            favoritesTitle: l10n.stickerFavoritesPackTitle,
          );
          messenger.showSnackBar(
            SecretlySnackBar(content: Text(l10n.stickerAddedToFavorites)),
          );
        case 'unfavorite':
          await widget.controller.removeStickerFromFavorites(sticker.stickerId);
          messenger.showSnackBar(
            SecretlySnackBar(content: Text(l10n.stickerRemovedFromFavorites)),
          );
        case 'cover':
          await widget.controller.setUserStickerPackCover(
            packId: pack!.id,
            stickerId: sticker.stickerId,
          );
          messenger.showSnackBar(
            SecretlySnackBar(content: Text(l10n.stickerPackCoverUpdated)),
          );
        case 'delete':
          final ok = await _confirmStickerDelete(
            context,
            packTitle: pack!.title,
            isLast: pack.stickers.length <= 1,
          );
          if (!ok) return;
          await widget.controller.deleteUserStickerFromPack(
            packId: pack.id,
            stickerId: sticker.stickerId,
          );
      }
    } catch (e) {
      messenger.showSnackBar(
        SecretlySnackBar(content: Text(l10n.stickerSaveFailed('$e'))),
      );
    }
    if (!mounted || action == 'send') return;
    await _loadPacks(refresh: false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Sections = packs that actually have stickers (a remote pack not yet
    // installed has nothing to show until the tap-sticker install flow runs).
    final packs = _visiblePacks
        .where((p) => p.stickers.isNotEmpty)
        .toList(growable: false);
    return Stack(
      children: [
        Column(
          children: [
            // Search FIRST, at the very top — minimal, no frosted island.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
              child: TextField(
                autofocus: false,
                decoration: _searchDecoration(cs, context.l10n.searchStickers),
                onChanged: (value) {
                  setState(() => _query = value.trim().toLowerCase());
                },
              ),
            ),
            // Compact pack-icon strip directly under the search.
            if (packs.isNotEmpty) _buildPackStrip(cs, packs),
            const SizedBox(height: 4),
            Expanded(child: _buildPickerBody(cs, packs)),
          ],
        ),
      ],
    );
  }

  /// «Создать» — первая клетка раздела «Недавние» (15.11.2026, образец
  /// владельца): клетка размером со стикер, «+» и подпись под ним. Раньше —
  /// плитка, прибитая к левому нижнему углу панели.
  Widget _buildCreateStickerTile(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey('stickers:create'),
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onCreateSticker,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 26,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.stickerCreate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (Old full-width "Create a sticker from a photo" card removed — replaced by
  // the compact sticker-sized _buildCreateStickerTile pinned bottom-left.)

  /// Top icon strip — one icon per section (recents + each pack). Tapping an
  /// icon animates the PageView below to that section's page. The ONE accent
  /// signal is a small dot under the active icon; everything else stays
  /// neutral so the strip reads as content, not a row of coloured buttons.
  Widget _buildPackStrip(ColorScheme cs, List<SecretlyStickerPack> packs) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
        scrollDirection: Axis.horizontal,
        physics: secretlyListPhysics(),
        itemCount: packs.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final isRecent = index == 0;
          final packId = isRecent
              ? SecretlyStickerCatalog.recentPackId
              : packs[index - 1].id;
          final selected = packId == _selectedPackId && _query.isEmpty;
          final pack = isRecent ? null : packs[index - 1];
          final packBusy = pack == null
              ? false
              : widget.controller.isStickerPackBusy(
                  packId: pack.id,
                  packVersion: pack.version,
                );
          return Tooltip(
            message: isRecent ? context.l10n.stickersRecent : pack!.title,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() => _query = '');
                _goToSection(packId, packs);
              },
              onLongPress:
                  pack != null &&
                      pack.origin == SecretlyStickerPackOrigin.remote &&
                      pack.installed
                  ? () => _confirmUninstall(pack)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(
                          alpha: selected ? 0.09 : 0.0,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: isRecent
                            ? Icon(
                                AppIcons.schedule,
                                size: 20,
                                color: cs.onSurface.withValues(
                                  alpha: selected ? 0.9 : 0.6,
                                ),
                              )
                            : Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Opacity(
                                    opacity: selected ? 1.0 : 0.72,
                                    child: SecretlyStickerAssetView(
                                      sticker: pack!.iconSticker,
                                      size: 34,
                                    ),
                                  ),
                                  if (pack.isRemoteAvailableOnly)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: cs.surface,
                                            width: 2,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: packBusy
                                              ? SizedBox(
                                                  width: 10,
                                                  height: 10,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 1.4,
                                                        color: cs.onPrimary,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.download_rounded,
                                                  size: 11,
                                                  color: cs.onPrimary,
                                                ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: selected ? 14 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(ColorScheme cs, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  /// A flat grid while searching; otherwise one full PAGE per section
  /// (recents + each pack) — swiping or tapping a top-bar icon moves between
  /// pages, so browsing one pack never shows a neighbour pack's stickers.
  Widget _buildPickerBody(ColorScheme cs, List<SecretlyStickerPack> packs) {
    if (_loadingPacks && _packs.isEmpty) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.1, color: cs.primary),
        ),
      );
    }
    if (_query.isNotEmpty) {
      final results = _visibleStickers();
      if (results.isEmpty) return _emptyState(cs, context.l10n.noStickersFound);
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(12, 2, 12, 14 + widget.bottomInset),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 78,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1,
        ),
        itemCount: results.length,
        itemBuilder: (context, i) => _stickerTile(cs, results[i]),
      );
    }
    final recents = _visibleRecentStickers;
    final canCreate = widget.onCreateSticker != null;
    if (recents.isEmpty && packs.isEmpty && !canCreate) {
      return _emptyState(cs, context.l10n.noRecentStickers);
    }
    final myPid = widget.controller.profileId;
    // Ключи — только у разделов, которые сейчас на экране.
    final ids = _sectionIds(packs).toSet();
    _sectionKeys.removeWhere((id, _) => !ids.contains(id));
    return CustomScrollView(
      controller: _scroll,
      physics: secretlyListPhysics(),
      slivers: [
        if (ids.contains(SecretlyStickerCatalog.recentPackId)) ...[
          _sectionHeader(
            cs,
            id: SecretlyStickerCatalog.recentPackId,
            title: context.l10n.stickersRecent,
          ),
          _sectionGrid(
            cs,
            leading: canCreate ? _buildCreateStickerTile(cs) : null,
            stickers: recents,
          ),
        ],
        for (final pack in packs) ...[
          _sectionHeader(
            cs,
            id: pack.id,
            title: pack.title,
            onSettings: pack.id.startsWith('user:$myPid:')
                ? () => _editUserPack(pack)
                : null,
            onMore: pack.id.startsWith('user:$myPid:')
                ? null
                : () => _showForeignPackActions(pack),
          ),
          _sectionGrid(cs, stickers: pack.stickers, pack: pack),
        ],
        SliverToBoxAdapter(child: SizedBox(height: 14 + widget.bottomInset)),
      ],
    );
  }

  /// Заголовок раздела: название и, рядом с ним, маленькая ⚙ у своего набора
  /// (образец владельца) или ⋯ у чужого.
  Widget _sectionHeader(
    ColorScheme cs, {
    required String id,
    required String title,
    VoidCallback? onSettings,
    VoidCallback? onMore,
  }) {
    final muted = cs.onSurface.withValues(alpha: 0.55);
    Widget smallButton(IconData icon, String tooltip, VoidCallback onTap,
        String keyName) {
      return Tooltip(
        message: tooltip,
        child: InkResponse(
          key: ValueKey('stickers:$keyName:$id'),
          onTap: onTap,
          radius: 18,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 17, color: muted),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        key: _sectionKey(id),
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 4),
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            if (onSettings != null)
              smallButton(Icons.settings_outlined,
                  context.l10n.stickerPackSettings, onSettings, 'settings'),
            if (onMore != null)
              smallButton(Icons.more_horiz_rounded, context.l10n.stickerMore,
                  onMore, 'more'),
          ],
        ),
      ),
    );
  }

  /// Сетка раздела — пять стикеров в ряд, как на образце.
  Widget _sectionGrid(
    ColorScheme cs, {
    required List<SecretlyStickerDescriptor> stickers,
    Widget? leading,
    SecretlyStickerPack? pack,
  }) {
    final offset = leading == null ? 0 : 1;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i < offset) return leading!;
            return _stickerTile(cs, stickers[i - offset], pack: pack);
          },
          childCount: stickers.length + offset,
        ),
      ),
    );
  }

  Widget _stickerTile(
    ColorScheme cs,
    SecretlyStickerDescriptor sticker, {
    SecretlyStickerPack? pack,
  }) {
    return _StickerTile(
      sticker: sticker,
      onTap: () => widget.onStickerSelected(sticker),
      onLongPress: () => _showStickerPreview(sticker, pack: pack),
    );
  }

  /// ⚙ у своего набора — окно набора целиком: добавить, удалить, обложка,
  /// доступ, удалить набор (15.11.2026, образец владельца).
  Future<void> _editUserPack(SecretlyStickerPack pack) async {
    final addTo = widget.onAddStickerToPack;
    String? addRequested;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _StickerPackEditSheet(
        controller: widget.controller,
        packId: pack.id,
        title: pack.title,
        onAddSticker: addTo == null ? null : () => addRequested = pack.id,
      ),
    );
    if (!mounted) return;
    await _loadPacks(refresh: false);
    final target = addRequested;
    if (target != null) addTo?.call(target);
  }

  /// ⋯ у чужого набора — убрать его из своей панели. У автора и у других он
  /// остаётся.
  Future<void> _showForeignPackActions(SecretlyStickerPack pack) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              key: const ValueKey('stickers:remove-foreign'),
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: Text(sheetCtx.l10n.stickerPackRemoveFromMine),
              onTap: () => Navigator.of(sheetCtx).pop(true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (remove != true || !mounted) return;
    final confirmed = await _confirmDestructive(
      context,
      title: context.l10n.stickerPackRemoveFromMine,
      body: context.l10n.stickerPackRemoveFromMineBody(pack.title),
      action: context.l10n.stickerPackRemoveAction,
    );
    if (!confirmed || !mounted) return;
    await widget.controller.deleteUserStickerPack(pack.id);
    if (!mounted) return;
    await _loadPacks(refresh: false);
  }
}

/// Вопрос перед удалением (15.11.2026): ни стикер, ни набор не исчезают без
/// подтверждения.
Future<bool> _confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.cancel),
        ),
        TextButton(
          key: const ValueKey('stickers:confirm'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Удалить стикер из своего набора — с вопросом; последний уносит набор,
/// и вопрос об этом говорит прямо.
Future<bool> _confirmStickerDelete(
  BuildContext context, {
  required String packTitle,
  required bool isLast,
}) =>
    _confirmDestructive(
      context,
      title: isLast
          ? context.l10n.stickerDeleteLastTitle
          : context.l10n.stickerDeleteTitle,
      body: isLast
          ? context.l10n.stickerDeleteLastBody(packTitle)
          : context.l10n.stickerDeleteBody(packTitle),
      action: context.l10n.stickerDeleteAction,
    );

/// A single grid tile with a soft press-down scale for tactile feedback —
/// no colour change, just a subtle physical response (iOS-style), matching
/// the picker's overall "content, not buttons" restraint.
class _StickerTile extends StatefulWidget {
  const _StickerTile({
    required this.sticker,
    required this.onTap,
    required this.onLongPress,
  });

  final SecretlyStickerDescriptor sticker;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_StickerTile> createState() => _StickerTileState();
}

class _StickerTileState extends State<_StickerTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SecretlyStickerAssetView(sticker: widget.sticker, size: 64),
        ),
      ),
    );
  }
}

/// Edit sheet for a user pack: grid of its stickers, each with a delete badge.
class _StickerPackEditSheet extends StatefulWidget {
  const _StickerPackEditSheet({
    required this.controller,
    required this.packId,
    required this.title,
    this.onAddSticker,
  });

  final AppController controller;
  final String packId;
  final String title;

  /// «+» — закрыть окно и открыть создание стикера в этот набор.
  final VoidCallback? onAddSticker;

  @override
  State<_StickerPackEditSheet> createState() => _StickerPackEditSheetState();
}

/// Окно своего набора по ⚙ (15.11.2026, образец владельца): название и ⋮,
/// сетка по пять с «⋯» у каждого стикера, клетка «+», кнопка «Готово».
class _StickerPackEditSheetState extends State<_StickerPackEditSheet> {
  List<SecretlyStickerDescriptor> _stickers =
      const <SecretlyStickerDescriptor>[];
  StickerShareMode _mode = StickerShareMode.fallback;

  /// Режим можно менять только у СВОЕГО набора и только в доле флага.
  /// Чужой установленный набор тоже начинается с `user:`, но его режим решает
  /// автор.
  bool get _canChangeAccess =>
      widget.controller.stickerPackAccessUiEnabled &&
      widget.packId.startsWith('user:${widget.controller.profileId}');

  Future<void> _setMode(StickerShareMode mode) async {
    if (mode == _mode) return;
    final previous = _mode;
    setState(() => _mode = mode);
    final ok = await widget.controller.setUserStickerPackShareMode(
      packId: widget.packId,
      mode: mode,
    );
    if (!ok && mounted) setState(() => _mode = previous);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final pack = SecretlyStickerCatalog.pickerPackById(widget.packId);
    setState(() {
      _stickers = pack?.stickers ?? const <SecretlyStickerDescriptor>[];
      _mode = pack?.shareMode ?? StickerShareMode.fallback;
    });
  }

  Future<void> _delete(SecretlyStickerDescriptor sticker) async {
    // 🔴 15.11.2026: раньше «×» удалял сразу — без вопроса и без отмены, а
    // последний стикер уносил весь набор. Владелец потерял набор с iPhone.
    final ok = await _confirmStickerDelete(
      context,
      packTitle: widget.title,
      isLast: _stickers.length <= 1,
    );
    if (!ok || !mounted) return;
    try {
      await widget.controller.deleteUserStickerFromPack(
        packId: widget.packId,
        stickerId: sticker.stickerId,
      );
    } catch (_) {}
    if (!mounted) return;
    _reload();
    if (_stickers.isEmpty && mounted) Navigator.of(context).pop();
  }

  Future<void> _deletePack() async {
    final ok = await _confirmDestructive(
      context,
      title: context.l10n.stickerPackDeleteWholeTitle,
      body: context.l10n.stickerPackDeleteWholeBody(widget.title),
      action: context.l10n.stickerDeleteAction,
    );
    if (!ok || !mounted) return;
    await widget.controller.deleteUserStickerPack(widget.packId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _setCover(SecretlyStickerDescriptor sticker) async {
    try {
      await widget.controller.setUserStickerPackCover(
        packId: widget.packId,
        stickerId: sticker.stickerId,
      );
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(content: Text(context.l10n.stickerPackCoverUpdated)),
    );
  }

  Future<void> _stickerMenu(
    SecretlyStickerDescriptor sticker,
    BuildContext anchor,
  ) async {
    final box = anchor.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        topLeft & box.size,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'cover',
          child: Text(context.l10n.stickerMakeCover),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            context.l10n.stickerDeleteAction,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
    if (!mounted) return;
    if (choice == 'cover') await _setCover(sticker);
    if (choice == 'delete') await _delete(sticker);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final add = widget.onAddSticker;
    final count = _stickers.length + (add == null ? 0 : 1);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  key: const ValueKey('stickers:pack-menu'),
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) {
                    if (v == 'delete-pack') unawaited(_deletePack());
                  },
                  itemBuilder: (menuCtx) => [
                    PopupMenuItem<String>(
                      value: 'delete-pack',
                      child: Text(
                        menuCtx.l10n.stickerPackDeleteWhole,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_canChangeAccess) ...[
              StickerPackAccessPicker(
                value: _mode,
                onChanged: (m) => unawaited(_setMode(m)),
                showExistingNote: true,
                foreground: cs.onSurface,
              ),
              const SizedBox(height: 12),
            ],
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: secretlyListPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: count,
                itemBuilder: (context, i) {
                  if (i == _stickers.length) {
                    return Tooltip(
                      message: context.l10n.stickerAddSticker,
                      child: Center(
                        child: Material(
                          color: cs.surfaceContainerHighest,
                          shape: const CircleBorder(),
                          child: InkWell(
                            key: const ValueKey('stickers:pack-add'),
                            customBorder: const CircleBorder(),
                            onTap: () {
                              Navigator.of(context).pop();
                              add?.call();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Icon(
                                Icons.add_rounded,
                                size: 28,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  final s = _stickers[i];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: SecretlyStickerAssetView(sticker: s, size: 60),
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Builder(
                          builder: (anchor) => Tooltip(
                            message: context.l10n.stickerMore,
                            child: InkResponse(
                              key: ValueKey('stickers:sticker-more:${s.stickerId}'),
                              radius: 16,
                              onTap: () => unawaited(_stickerMenu(s, anchor)),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest
                                      .withValues(alpha: 0.92),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 16,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('stickers:pack-done'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  context.l10n.stickerEditorDone,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
