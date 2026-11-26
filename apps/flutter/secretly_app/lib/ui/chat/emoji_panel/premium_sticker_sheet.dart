// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Премиум-наборы в панели (24.11.2026): значки у лупы и окно набора.
///
/// - [PremiumStickerPins] — значки наборов (первый стикер + золотая
///   звёздочка), закреплены в верхней строке слева от лупы и не уезжают с
///   прокруткой рейки. С Premium касание ведёт к разделу набора, без
///   Premium — открывает окно набора.
/// - [showPremiumStickerPackSheet] — окно снизу: живые стикеры набора и
///   кнопка «Открыть с Premium» (страница покупки). С Premium кнопки нет,
///   касание стикера отправляет его.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../stickers/premium_sticker_packs.dart';
import '../../../stickers/sticker_catalog.dart';
import '../../widgets/secretly_sticker_widgets.dart';
import 'emoji_panel_stickers.dart';
import 'emoji_panel_style.dart';
import 'emoji_panel_widgets.dart';

/// Фирменный цвет премиум-наборов из макета.
const Color kPremiumStickerViolet = Color(0xFF7B5CFA);
const Color kPremiumStickerStar = Color(0xFFFFD23F);

/// Название встроенного набора дизайнера на языке интерфейса.
String premiumPackTitle(AppLocalizations l10n, SecretlyStickerPack pack) =>
    switch (pack.id) {
      kPremiumSafePackId => l10n.stickerPremiumPackSafe,
      kPremiumPixelPackId => l10n.stickerPremiumPackPixel,
      kKidsStickerPackId => l10n.stickerPackKids,
      _ => pack.title,
    };

/// Маленькая звёздочка премиум-набора (в углу значка).
class PremiumStickerStar extends StatelessWidget {
  const PremiumStickerStar({super.key, this.size = 13});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: kPremiumStickerViolet,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.star_rounded,
        size: size * .78,
        color: kPremiumStickerStar,
      ),
    );
  }
}

/// Значки премиум-наборов слева от лупы.
class PremiumStickerPins extends StatelessWidget {
  const PremiumStickerPins({
    super.key,
    required this.model,
    required this.style,
  });

  final StickerTabModel model;
  final EmojiPanelStyle style;

  static const double itemWidth = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final packs = model.premium;
        if (packs.isEmpty) return const SizedBox.shrink();
        final secs = model.buildSections(l10n);
        return ValueListenableBuilder<int>(
          valueListenable: model.active,
          builder: (context, active, _) {
            final activeId = model.query.isEmpty &&
                    active >= 0 &&
                    active < secs.length
                ? secs[active].id
                : null;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in packs)
                  _PremiumPin(
                    key: ValueKey('emoji-panel:premium-pin:${p.id}'),
                    pack: p,
                    style: style,
                    active: model.premiumUnlocked && activeId == p.id,
                    label: premiumPackTitle(l10n, p),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (model.premiumUnlocked) {
                        model.jumpToPack(l10n, p.id);
                      } else {
                        showPremiumStickerPackSheet(
                          context,
                          pack: p,
                          unlocked: false,
                          onOpenPremium: () =>
                              unawaited(model.openPremium(context)),
                        );
                      }
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PremiumPin extends StatelessWidget {
  const _PremiumPin({
    super.key,
    required this.pack,
    required this.style,
    required this.active,
    required this.label,
    required this.onTap,
  });

  final SecretlyStickerPack pack;
  final EmojiPanelStyle style;
  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: '$label · Premium',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PanelPress(
          child: SizedBox(
            width: PremiumStickerPins.itemWidth,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? style.railInd : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Значок — первый стикер набора, без анимации (как у
                    // остальных значков рейки).
                    PanelStickerThumb(sticker: pack.iconSticker, size: 28),
                    const Positioned(
                      right: -4,
                      top: -4,
                      child: PremiumStickerStar(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Окно премиум-набора. Без Premium — кнопка покупки; с Premium — касание
/// стикера отправляет его ([onSend]).
Future<void> showPremiumStickerPackSheet(
  BuildContext context, {
  required SecretlyStickerPack pack,
  required bool unlocked,
  required VoidCallback onOpenPremium,
  void Function(SecretlyStickerDescriptor sticker)? onSend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => PremiumStickerPackSheet(
      pack: pack,
      unlocked: unlocked,
      onOpenPremium: () {
        Navigator.of(sheetContext).pop();
        onOpenPremium();
      },
      onSend: onSend == null
          ? null
          : (s) {
              Navigator.of(sheetContext).pop();
              onSend(s);
            },
    ),
  );
}

class PremiumStickerPackSheet extends StatelessWidget {
  const PremiumStickerPackSheet({
    super.key,
    required this.pack,
    required this.unlocked,
    required this.onOpenPremium,
    this.onSend,
  });

  final SecretlyStickerPack pack;
  final bool unlocked;
  final VoidCallback onOpenPremium;
  final void Function(SecretlyStickerDescriptor sticker)? onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF171324) : Colors.white;
    final text = dark ? Colors.white : const Color(0xFF14111C);
    final sub = dark ? const Color(0xFF9A92B3) : const Color(0xFF5F5878);
    final media = MediaQuery.of(context);
    final maxH = media.size.height * .78;
    return Container(
      key: ValueKey('premium-sticker-sheet:${pack.id}'),
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + media.padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: sub.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Text(
                  premiumPackTitle(l10n, pack),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const _PremiumTag(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.stickerPremiumSubtitle,
            style: TextStyle(color: sub, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: pack.stickers.length,
              itemBuilder: (context, i) {
                final st = pack.stickers[i];
                return GestureDetector(
                  key: ValueKey('premium-sticker-sheet:cell:${st.stickerId}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (unlocked && onSend != null) {
                      onSend!(st);
                    } else if (!unlocked) {
                      HapticFeedback.lightImpact();
                    }
                  },
                  child: LayoutBuilder(
                    builder: (context, c) => Center(
                      child: SecretlyStickerAssetView(
                        sticker: st,
                        size: c.maxWidth,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!unlocked) ...[
            const SizedBox(height: 14),
            _UnlockButton(
              label: l10n.stickerPremiumUnlock,
              onTap: onOpenPremium,
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumTag extends StatelessWidget {
  const _PremiumTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
      decoration: BoxDecoration(
        color: kPremiumStickerViolet,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 15, color: kPremiumStickerStar),
          SizedBox(width: 4),
          Text(
            'Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockButton extends StatelessWidget {
  const _UnlockButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const ValueKey('premium-sticker-sheet:unlock'),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF8E72FF), kPremiumStickerViolet],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: kPremiumStickerViolet.withValues(alpha: .35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 20,
                color: kPremiumStickerStar,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
