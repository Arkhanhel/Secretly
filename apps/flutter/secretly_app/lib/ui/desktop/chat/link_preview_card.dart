// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../links/link_preview_draft.dart';
import '../../../models/link_preview_v1.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_tooltip.dart';

/// Карточка ссылки в пузыре — тем же видом, что на телефоне
/// (`_LinkPreviewCard` в `chat_screen.dart`): полоска, сайт, заголовок,
/// описание и картинка 16:9.
///
/// 🔴 КАРТИНКА УЖЕ В СООБЩЕНИИ. Её приготовил отправитель, и за ней никто не
/// ходит в сеть: иначе собеседник, прислав ссылку на свой сервер, узнал бы
/// адрес этого компьютера.
class DesktopLinkPreviewCard extends StatelessWidget {
  const DesktopLinkPreviewCard({
    super.key,
    required this.preview,
    required this.isSelf,
    this.onOpen,
  });

  final LinkPreviewV1 preview;
  final bool isSelf;

  /// Открыть ссылку. По умолчанию — в браузере.
  final ValueChanged<Uri>? onOpen;

  /// Шире карточка не нужна: заголовок в две строки и картинка читаются и
  /// так, а на широком окне пузырь растянулся бы на пол-экрана.
  static const double maxWidth = 420;

  static Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Браузер не открылся — ссылка остаётся в тексте, её можно скопировать.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    // Числа и цвета — телефонные: на своём залитом пузыре всё белое, на
    // чужом полоска и сайт служебным синим ленты (им же набраны ссылки).
    final accent = isSelf ? Colors.white : c.deliveryIndicator;
    final fg = isSelf ? Colors.white : c.textPrimary;
    final panel = isSelf
        ? Colors.white.withValues(alpha: 0.13)
        : c.textPrimary.withValues(alpha: 0.06);
    final title = (preview.title ?? '').trim();
    final description = (preview.description ?? '').trim();
    final thumb = preview.thumbnail;
    final hasImage = thumb != null && thumb.isNotEmpty;
    final uri = Uri.tryParse(preview.url);

    final card = Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accent.withValues(alpha: 0.92)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.siteName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.caption.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DType.bodyStrong.copyWith(
                          color: fg,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: hasImage ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: DType.caption.copyWith(
                          color: fg.withValues(alpha: 0.82),
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (hasImage) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.memory(
                            thumb,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.medium,
                            // Битая картинка — карточка без неё, а не
                            // пустой серый прямоугольник.
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (uri == null) return card;
    // Куда ведёт карточка, видно ДО нажатия: заголовок пишет сайт, а адрес —
    // это то, что откроется.
    return DesktopTooltip(
      message: preview.url,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final open = onOpen;
            if (open != null) {
              open(uri);
            } else {
              unawaited(_launch(uri));
            }
          },
          child: card,
        ),
      ),
    );
  }
}

/// Карточка своего прежнего сообщения, в котором её нет, — загружается здесь
/// же (см. [LinkPreviewMemoryCache]). Пока грузится или не вышло — [builder]
/// получает `null`, и пузырь выглядит как обычный текст.
class DesktopOwnLinkPreview extends StatefulWidget {
  const DesktopOwnLinkPreview({
    super.key,
    required this.target,
    required this.builder,
    this.cache,
  });

  final Uri target;
  final Widget Function(BuildContext context, LinkPreviewV1? preview) builder;

  /// Для тестов; в приложении — общий [LinkPreviewMemoryCache.instance].
  final LinkPreviewMemoryCache? cache;

  @override
  State<DesktopOwnLinkPreview> createState() => _DesktopOwnLinkPreviewState();
}

class _DesktopOwnLinkPreviewState extends State<DesktopOwnLinkPreview> {
  LinkPreviewV1? _preview;
  int _request = 0;

  LinkPreviewMemoryCache get _cache =>
      widget.cache ?? LinkPreviewMemoryCache.instance;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(DesktopOwnLinkPreview old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) _resolve();
  }

  void _resolve() {
    final request = ++_request;
    // Уже загруженное — в том же кадре, что и пузырь, без «прыжка».
    _preview = _cache.peek(widget.target);
    if (_preview != null) return;
    unawaited(
      _cache.get(widget.target).then((value) {
        if (!mounted || request != _request || value == null) return;
        setState(() => _preview = value);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _preview);
}

/// Карточка над полем ввода: что уйдёт вместе с сообщением. Крестик убирает
/// её из этого сообщения.
class DesktopLinkPreviewDraftBar extends StatelessWidget {
  const DesktopLinkPreviewDraftBar({
    super.key,
    required this.draft,
    required this.frameColor,
    required this.frameWidth,
  });

  final OutgoingLinkPreviewDraft draft;
  final Color frameColor;
  final double frameWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final preview = draft.preview;
        final loading = draft.loading;
        if (preview == null && !loading) return const SizedBox.shrink();
        final c = DColors.of(context);
        final thumb = preview?.thumbnail;
        final title = (preview?.title ?? '').trim();
        final subtitle = preview == null
            ? (draft.target?.host ?? '')
            : (title.isNotEmpty
                  ? title
                  : (preview.description ?? preview.siteName));
        return Container(
          // Та же геометрия, что у карточки ответа: верх со скруглением, без
          // нижней черты — её роль играет рамка поля.
          padding: const EdgeInsets.fromLTRB(9, 7, 10, 7),
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            border: Border(
              top: BorderSide(color: frameColor, width: frameWidth),
              left: BorderSide(color: frameColor, width: frameWidth),
              right: BorderSide(color: frameColor, width: frameWidth),
            ),
          ),
          child: Row(
            children: [
              Icon(
                FluentIcons.link_24_regular,
                size: 17,
                color: c.deliveryIndicator,
              ),
              const SizedBox(width: 9),
              Container(
                width: 2,
                height: 26,
                decoration: BoxDecoration(
                  color: c.deliveryIndicator,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      preview?.siteName ?? l10n.desktopLinkPreviewLoading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.caption.copyWith(
                        fontSize: 11.5,
                        color: c.deliveryIndicator,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.caption.copyWith(
                        fontSize: 11.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (thumb != null && thumb.isNotEmpty) ...[
                const SizedBox(width: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    thumb,
                    width: 44,
                    height: 32,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ] else if (loading) ...[
                const SizedBox(width: 9),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: c.textSecondary,
                  ),
                ),
              ],
              const SizedBox(width: 9),
              DesktopIconButton(
                icon: FluentIcons.dismiss_24_regular,
                tooltip: l10n.desktopLinkPreviewOff,
                size: 26,
                iconSize: 16,
                radius: DRadii.r8,
                onPressed: draft.dismiss,
              ),
            ],
          ),
        );
      },
    );
  }
}
