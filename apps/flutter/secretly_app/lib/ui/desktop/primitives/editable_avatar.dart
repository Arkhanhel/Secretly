// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import 'avatar.dart';
import 'context_menu.dart';
import 'desktop_tooltip.dart';
import 'hover_listener.dart';

/// Портрет, который можно сменить, — как в Telegram Desktop (29.09.2026).
///
/// 🔴 Жалоба владельца: «нет кнопки изменить / удалить фото профиля группы и
/// своего профиля». У своего профиля щелчок по портрету открывал только
/// просмотр, «Убрать фото» пряталось внизу и было лишь для фото, выбранного
/// на этом ПК. У группы смена фото жила только в окне «Изменить группу».
///
/// Теперь как в Telegram: наведение затемняет портрет и показывает камеру с
/// подписью, щелчок открывает меню «Выбрать фото… / Открыть / Удалить фото».
/// Маленькая камера в углу остаётся: без мыши наведения нет.
class DesktopEditableAvatar extends StatefulWidget {
  const DesktopEditableAvatar({
    super.key,
    required this.avatar,
    required this.size,
    this.shape = AvatarShape.round,
    this.framed = false,
    required this.onChoose,
    this.onOpen,
    this.onRemove,
    this.removeUnavailableHint,
    this.cornerRing,
  });

  /// Сам портрет ([Avatar]) — с рамкой, если она есть.
  final Widget avatar;
  final double size;
  final AvatarShape shape;

  /// У портрета рамка: затемнение ложится на лицо внутри кольца.
  final bool framed;

  /// «Выбрать фото…».
  final VoidCallback onChoose;

  /// «Открыть» — если фото есть.
  final VoidCallback? onOpen;

  /// «Удалить фото»; `null` — пункта нет (или он неактивен, см. ниже).
  final VoidCallback? onRemove;

  /// Фото есть, но удалить его здесь нельзя (пришло с телефона): пункт
  /// показывается неактивным с этой подписью вместо действия.
  final String? removeUnavailableHint;

  /// Цвет выреза вокруг угловой камеры — цвет панели под портретом.
  final Color? cornerRing;

  @override
  State<DesktopEditableAvatar> createState() => _DesktopEditableAvatarState();
}

class _DesktopEditableAvatarState extends State<DesktopEditableAvatar> {
  bool _hovered = false;

  Future<void> _menu(BuildContext context, Offset at) {
    final l10n = AppLocalizations.of(context)!;
    return ContextMenu.show(
      context,
      globalPosition: at,
      width: 240,
      sections: <List<CtxMenuItem>>[
        <CtxMenuItem>[
          CtxMenuItem(
            label: l10n.desktopRoomEditPhotoChoose,
            icon: FluentIcons.camera_24_regular,
            onTap: widget.onChoose,
          ),
          if (widget.onOpen != null)
            CtxMenuItem(
              label: l10n.desktopAvatarOpen,
              icon: FluentIcons.eye_24_regular,
              onTap: widget.onOpen,
            ),
        ],
        if (widget.onRemove != null)
          <CtxMenuItem>[
            CtxMenuItem(
              label: l10n.desktopRoomEditPhotoRemove,
              icon: FluentIcons.delete_24_regular,
              isDanger: true,
              onTap: widget.onRemove,
            ),
          ]
        else if (widget.removeUnavailableHint != null)
          <CtxMenuItem>[
            CtxMenuItem(
              label: widget.removeUnavailableHint!,
              icon: FluentIcons.delete_24_regular,
              enabled: false,
            ),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final size = widget.size;
    final inset = size * Avatar.portraitInset(shape: widget.shape, framed: widget.framed);
    final face = size - inset * 2;
    final BorderRadius radius = widget.shape == AvatarShape.round
        ? BorderRadius.circular(face / 2)
        : BorderRadius.circular(Avatar.roomRadius(face));
    return Semantics(
      container: true,
      button: true,
      label: l10n.desktopProfileChangePhoto,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _menu(context, d.globalPosition),
                onSecondaryTapUp: (d) => _menu(context, d.globalPosition),
                child: Stack(
                  children: [
                    Positioned.fill(child: ExcludeSemantics(child: widget.avatar)),
                    Positioned(
                      left: inset,
                      top: inset,
                      width: face,
                      height: face,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _hovered ? 1 : 0,
                          duration: DMotion.fast,
                          child: ClipRRect(
                            borderRadius: radius,
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    FluentIcons.camera_24_regular,
                                    size: face >= 72 ? 26 : 18,
                                    color: Colors.white,
                                  ),
                                  if (face >= 72) ...[
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Text(
                                        l10n.desktopProfileChangePhoto,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        style: DType.tiny.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
            // Угловая камера — вход без наведения (клавиатура, сенсор).
            Positioned(
              right: -2,
              bottom: -2,
              child: DesktopTooltip(
                message: l10n.desktopProfileChangePhoto,
                child: HoverListener(
                  cursor: SystemMouseCursors.click,
                  onTap: widget.onChoose,
                  builder: (ctx, hovered, pressed) => AnimatedContainer(
                    duration: DMotion.fast,
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hovered || pressed ? c.accentPrimary : c.elevated,
                      shape: BoxShape.circle,
                      // Вырез цветом панели: без него кружок слипается с
                      // краем портрета.
                      border: Border.all(color: widget.cornerRing ?? c.chatList, width: 3),
                    ),
                    child: Icon(
                      FluentIcons.camera_24_filled,
                      size: 13,
                      color: hovered || pressed ? Colors.white : c.textSecondary,
                    ),
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
