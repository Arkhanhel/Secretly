// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../app/app_controller.dart' show AppController;
import '../../../stickers/sticker_catalog.dart' show SecretlyStickerDescriptor;
import '../../widgets/secretly_sticker_widgets.dart'
    show SecretlyStickerPickerTab;
import '../design/tokens.dart';
import '../primitives/desktop_popover.dart';
import '../primitives/desktop_text_field.dart';
import '../primitives/hover_listener.dart';
import 'emoji_grid.dart';
import 'gif_picker_tab.dart';

/// Emoji + stickers popover. Tabs along the top, sticky search, last-used row.
class EmojiPopover {
  EmojiPopover._();

  static Future<String?> show(
    BuildContext context, {
    required GlobalKey anchorKey,
    PopoverSide side = PopoverSide.above,
    AppController? stickerController,
    ValueChanged<SecretlyStickerDescriptor>? onStickerSelected,
    ValueChanged<String>? onGifFilePicked,
    bool emojiOnly = false,
  }) {
    return DesktopPopover.show<String>(
      context,
      anchorKey: anchorKey,
      side: side,
      width: 360,
      maxHeight: 440,
      child: _EmojiPanel(
        stickerController: stickerController,
        onStickerSelected: onStickerSelected,
        onGifFilePicked: onGifFilePicked,
        emojiOnly: emojiOnly,
      ),
    );
  }
}

enum _Tab { emoji, stickers, gifs }

class _EmojiPanel extends StatefulWidget {
  const _EmojiPanel({
    this.stickerController,
    this.onStickerSelected,
    this.onGifFilePicked,
    this.emojiOnly = false,
  });
  /// Только эмодзи, без вкладок: в подписи к снимку стикер и гифку не
  /// вставишь, а пустые вкладки-заглушки только путают.
  final bool emojiOnly;
  final AppController? stickerController;
  final ValueChanged<SecretlyStickerDescriptor>? onStickerSelected;

  /// Путь к скачанной гифке. Отправляет её хозяин окна — тем же путём, что и
  /// перетащенный файл.
  final ValueChanged<String>? onGifFilePicked;
  @override
  State<_EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<_EmojiPanel> {
  _Tab _tab = _Tab.emoji;
  final _query = TextEditingController();
  String _q = '';
  List<SecretlyStickerDescriptor> _recentStickers = const [];

  @override
  void initState() {
    super.initState();
    final ctl = widget.stickerController;
    if (ctl != null) {
      ctl.loadRecentStickers().then((r) {
        if (mounted) setState(() => _recentStickers = r);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.emojiOnly) ...[
            _tabsRow(c),
            Container(height: 1, color: c.borderSubtle),
          ],
          // The real sticker picker tab carries its own search/sections, so the
          // shared search box is hidden there to avoid a dead duplicate.
          if (!(_tab == _Tab.stickers && widget.stickerController != null))
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(DSpace.s, DSpace.s, DSpace.s, 4),
              child: DesktopTextField(
                controller: _query,
                hintText: _tab == _Tab.emoji
                    ? l10n.desktopEmojiSearchHint
                    : (_tab == _Tab.stickers
                        ? l10n.desktopStickersSearchHint
                        : l10n.desktopGifSearchHint),
                prefixIcon: FluentIcons.search_24_regular,
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          Flexible(child: _body(c)),
        ],
      ),
    );
  }

  Widget _tabsRow(DColorSet c) {
    final l10n = AppLocalizations.of(context)!;
    Widget tab(_Tab t, IconData ic, String label) {
      final active = _tab == t;
      return Expanded(
        child: HoverListener(
          onTap: () => setState(() => _tab = t),
          builder: (ctx, hovered, pressed) => Container(
            height: 40,
            decoration: BoxDecoration(
              color: active ? c.selected : (hovered ? c.hover : Colors.transparent),
              border: Border(
                bottom: BorderSide(
                  color: active ? c.accentPrimary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ic, size: 16, color: active ? c.accentPrimary : c.textSecondary),
                const SizedBox(width: 6),
                Text(label,
                    style: DType.caption.copyWith(
                      color: active ? c.accentPrimary : c.textSecondary,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [
      tab(_Tab.emoji, FluentIcons.emoji_24_regular, l10n.desktopEmojiTabEmoji),
      tab(_Tab.stickers, FluentIcons.sticker_24_regular,
          l10n.desktopEmojiTabStickers),
      tab(_Tab.gifs, FluentIcons.gif_24_regular, 'GIF'),
    ]);
  }

  Widget _body(DColorSet c) {
    final l10n = AppLocalizations.of(context)!;
    switch (_tab) {
      case _Tab.emoji:
        return _emojiBody(c);
      case _Tab.stickers:
        final ctl = widget.stickerController;
        if (ctl == null) {
          return _stubBody(
              c, FluentIcons.sticker_24_regular, l10n.desktopStickerPacksSoon);
        }
        return SecretlyStickerPickerTab(
          controller: ctl,
          recentStickers: _recentStickers,
          onStickerSelected: (s) {
            widget.onStickerSelected?.call(s);
            Navigator.of(context).pop();
          },
        );
      case _Tab.gifs:
        final ctl = widget.stickerController;
        // Контроллер тот же самый: он нужен ради недавних гифок, они лежат в
        // зашифрованной базе профиля. Без него вкладка была бы наполовину
        // живой, и честнее сказать об этом прямо.
        if (ctl == null || widget.onGifFilePicked == null) {
          return _stubBody(
            c,
            FluentIcons.gif_24_regular,
            l10n.desktopGifUnavailable,
          );
        }
        return DesktopGifPickerTab(
          loadRecents: ctl.loadRecentGifs,
          rememberPicked: ctl.rememberPickedGif,
          query: _q,
          onPicked: (path) {
            widget.onGifFilePicked!(path);
            Navigator.of(context).maybePop();
          },
        );
    }
  }

  /// 🔴 ПОДБОРЩИК БЕРЁТ ОБЩИЙ КАТАЛОГ, А НЕ СВОЙ СПИСОЧЕК ИЗ ТРИДЦАТИ СЕМИ.
  ///
  /// НАЙДЕНО 16.09.2026 ПО УКАЗАНИЮ ВЛАДЕЛЬЦА «сделай чтобы все эмодзи, гифки
  /// и т д работали правильно в пк версии — в мобильной всё идеально».
  /// Здесь лежал `_kEmojiBundle` — тридцать семь символов, вбитых руками.
  ///
  /// С 29.09.2026 сама сетка живёт в [DesktopEmojiGrid]: её же берёт выбор
  /// эмодзи-статуса, и у обоих — ленивая раскладка, полоса категорий,
  /// «Недавние» и подписи на языке окна.
  Widget _emojiBody(DColorSet c) {
    return DesktopEmojiGrid(
      query: _q,
      recentsKey: kDesktopEmojiRecentsKey,
      onPicked: (e) => Navigator.of(context).maybePop(e),
    );
  }

  Widget _stubBody(DColorSet c, IconData ic, String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DSpace.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 48, color: c.textDisabled),
            const SizedBox(height: DSpace.s),
            Text(label, style: DType.caption.copyWith(color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}
