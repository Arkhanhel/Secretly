// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import '../scroll_feel.dart';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:lottie/lottie.dart';

import '../../app/app_controller.dart';
import '../../stickers/sticker_catalog.dart';
import '../icons/app_icons.dart';
import '../l10n.dart';
import '../wave1_l10n.dart';
import 'broken_media_box.dart';

String _stickerText(
  BuildContext context, {
  required String ru,
  required String en,
  String? uk,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  return wave1Text(
    context,
    ru: ru,
    en: en,
    uk: uk,
    es: es,
    pt: pt,
    ptBr: ptBr,
    fr: fr,
    de: de,
  );
}

String _stickerPreviewLabel(
  BuildContext context, {
  String? emojiHint,
  String? label,
}) {
  final base = _stickerText(context, ru: 'Стикер', en: 'Sticker');
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
    this.bottomInset = 0,
  });

  final AppController controller;
  final List<SecretlyStickerDescriptor> recentStickers;
  final ValueChanged<SecretlyStickerDescriptor> onStickerSelected;

  /// Tapped the "Создать стикер" affordance — opens the photo→sticker flow.
  /// Null hides the entry (e.g. where sticker creation isn't available).
  final VoidCallback? onCreateSticker;
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

  // Paged layout (2026-07-02 redesign): one full page per section (recents +
  // each pack), matching Telegram/iMessage — the top icon bar SWITCHES the
  // visible page (smooth animated transition) instead of scrolling one long
  // combined grid to an anchor, so browsing one pack never shows a neighbour
  // pack's stickers above/below it. [_selectedPackId] doubles as the
  // highlighted top icon AND the active page.
  final PageController _pageController = PageController();
  bool _pageControllerJumping = false;

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
    _loadPacks();
  }

  @override
  void didUpdateWidget(covariant SecretlyStickerPickerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _normalizePickerSelection();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Ordered section ids matching the icon strip AND the PageView: recents
  /// first (only when it has stickers), then one id per pack.
  List<String> _sectionIds(List<SecretlyStickerPack> packs) => [
    if (_visibleRecentStickers.isNotEmpty) SecretlyStickerCatalog.recentPackId,
    for (final pack in packs) pack.id,
  ];

  /// Animate the PageView to [sectionId]'s page and highlight its top-bar
  /// icon. [sectionId] is a packId or the recents id.
  void _goToSection(String sectionId, List<SecretlyStickerPack> packs) {
    final ids = _sectionIds(packs);
    final index = ids.indexOf(sectionId);
    setState(() => _selectedPackId = sectionId);
    if (index < 0 || !_pageController.hasClients) return;
    _pageControllerJumping = true;
    _pageController
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _pageControllerJumping = false);
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
          ? _stickerText(
              context,
              ru: 'Не удалось установить стикерпак: $error',
              en: 'Failed to install sticker pack: $error',
              uk: 'Не вдалося встановити стікерпак: $error',
              es: 'No se pudo instalar el paquete de stickers: $error',
              pt: 'Nao foi possivel instalar o pacote de stickers: $error',
              fr: 'Impossible d installer le pack de stickers : $error',
              de: 'Stickerpaket konnte nicht installiert werden: $error',
            )
          : _stickerText(
              context,
              ru: 'Не удалось удалить стикерпак: $error',
              en: 'Failed to remove sticker pack: $error',
              uk: 'Не вдалося видалити стікерпак: $error',
              es: 'No se pudo eliminar el paquete de stickers: $error',
              pt: 'Nao foi possivel remover o pacote de stickers: $error',
              fr: 'Impossible de supprimer le pack de stickers : $error',
              de: 'Stickerpaket konnte nicht entfernt werden: $error',
            ),
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
            _stickerText(
              dialogContext,
              ru: 'Удалить стикерпак?',
              en: 'Remove sticker pack?',
              uk: 'Видалити стікерпак?',
              es: 'Eliminar paquete de stickers?',
              pt: 'Remover pacote de stickers?',
              fr: 'Supprimer le pack de stickers ?',
              de: 'Stickerpaket entfernen?',
            ),
          ),
          content: Text(
            _stickerText(
              dialogContext,
              ru: 'Пак "${pack.title}" останется в каталоге, но локальные файлы будут удалены.',
              en: 'Pack "${pack.title}" will stay in the catalog, but its local files will be removed.',
              uk: 'Пак "${pack.title}" залишиться в каталозі, але локальні файли буде видалено.',
              es: 'El paquete "${pack.title}" seguira en el catalogo, pero se eliminaran sus archivos locales.',
              pt: 'O pacote "${pack.title}" fica no catalogo, mas os ficheiros locais serao removidos.',
              ptBr:
                  'O pacote "${pack.title}" ficara no catalogo, mas os arquivos locais serao removidos.',
              fr: 'Le pack "${pack.title}" restera dans le catalogue, mais ses fichiers locaux seront supprimes.',
              de: 'Das Paket "${pack.title}" bleibt im Katalog, aber lokale Dateien werden entfernt.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                _stickerText(dialogContext, ru: 'Отмена', en: 'Cancel'),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                _stickerText(dialogContext, ru: 'Удалить', en: 'Remove'),
              ),
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
        _stickerText(
          context,
          ru: 'Стикерпак "${pack.title}" удалён с устройства.',
          en: 'Removed "${pack.title}" from this device.',
          uk: 'Стікерпак "${pack.title}" видалено з пристрою.',
          es: '"${pack.title}" eliminado de este dispositivo.',
          pt: '"${pack.title}" removido deste dispositivo.',
          fr: '"${pack.title}" supprime de cet appareil.',
          de: '"${pack.title}" von diesem Gerat entfernt.',
        ),
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

  Future<void> _showStickerPreview(SecretlyStickerDescriptor sticker) async {
    final cs = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 36,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SecretlyStickerAssetView(sticker: sticker, size: 220),
                  const SizedBox(height: 10),
                  Text(
                    _stickerPreviewLabel(
                      context,
                      emojiHint: sticker.emojiHint,
                      label: sticker.label,
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
        // Create-sticker affordance: a sticker-sized tile pinned bottom-left,
        // sitting in the empty gap beside the centered tab strip.
        if (widget.onCreateSticker != null)
          Positioned(
            left: 12,
            bottom: (widget.bottomInset - 60).clamp(8.0, 320.0),
            child: _buildCreateStickerTile(cs),
          ),
      ],
    );
  }

  /// Sticker-sized "create" tile (bottom-left). Neutral glassy square with a
  /// camera-plus glyph — reads as a sticker cell, not a CTA button.
  Widget _buildCreateStickerTile(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onCreateSticker,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
          ),
          child: Icon(
            Icons.add_a_photo_rounded,
            size: 24,
            color: cs.onSurface.withValues(alpha: 0.7),
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
    if (recents.isEmpty && packs.isEmpty) {
      return _emptyState(cs, context.l10n.noRecentStickers);
    }
    final myPid = widget.controller.profileId;
    final sectionIds = _sectionIds(packs);
    return PageView.builder(
      controller: _pageController,
      itemCount: sectionIds.length,
      onPageChanged: (index) {
        if (_pageControllerJumping) return;
        final id = sectionIds[index];
        if (id != _selectedPackId) setState(() => _selectedPackId = id);
      },
      itemBuilder: (context, index) {
        final id = sectionIds[index];
        if (id == SecretlyStickerCatalog.recentPackId) {
          return _buildSectionPage(
            cs,
            title: context.l10n.stickersRecent,
            stickers: recents,
          );
        }
        final pack = packs.firstWhere((p) => p.id == id);
        return _buildSectionPage(
          cs,
          title: pack.title,
          stickers: pack.stickers,
          onEdit: pack.id.startsWith('user:$myPid')
              ? () => _editUserPack(pack)
              : null,
        );
      },
    );
  }

  Widget _buildSectionPage(
    ColorScheme cs, {
    required String title,
    required List<SecretlyStickerDescriptor> stickers,
    VoidCallback? onEdit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (onEdit != null)
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      _stickerText(context, ru: 'изменить', en: 'edit'),
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 14 + widget.bottomInset),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 78,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: stickers.length,
            itemBuilder: (context, i) => _stickerTile(cs, stickers[i]),
          ),
        ),
      ],
    );
  }

  Widget _stickerTile(ColorScheme cs, SecretlyStickerDescriptor sticker) {
    return _StickerTile(
      sticker: sticker,
      onTap: () => widget.onStickerSelected(sticker),
      onLongPress: () => _showStickerPreview(sticker),
    );
  }

  /// «Изменить» for one of the user's OWN packs — delete stickers from it.
  Future<void> _editUserPack(SecretlyStickerPack pack) async {
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
      ),
    );
    if (!mounted) return;
    await _loadPacks(refresh: true);
  }
}

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
  });

  final AppController controller;
  final String packId;
  final String title;

  @override
  State<_StickerPackEditSheet> createState() => _StickerPackEditSheetState();
}

class _StickerPackEditSheetState extends State<_StickerPackEditSheet> {
  List<SecretlyStickerDescriptor> _stickers =
      const <SecretlyStickerDescriptor>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final pack = SecretlyStickerCatalog.pickerPackById(widget.packId);
    setState(
      () => _stickers = pack?.stickers ?? const <SecretlyStickerDescriptor>[],
    );
  }

  Future<void> _delete(SecretlyStickerDescriptor sticker) async {
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
      SecretlySnackBar(content: const Text('Обложка набора обновлена')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_stickerText(context, ru: 'Готово', en: 'Done')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: secretlyListPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 88,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _stickers.length,
                itemBuilder: (context, i) {
                  final s = _stickers[i];
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          // Long-press a sticker → make it the pack cover/icon.
                          onLongPress: () => _setCover(s),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: SecretlyStickerAssetView(
                                sticker: s,
                                size: 60,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _delete(s),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 1.5),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: cs.onError,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
