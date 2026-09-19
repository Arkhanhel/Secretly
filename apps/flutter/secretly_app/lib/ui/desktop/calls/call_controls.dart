// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../design/tokens.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';

/// Bottom control dock for a call. Floating pill — works on top of any
/// background (avatar/video).
class CallControls extends StatelessWidget {
  const CallControls({
    super.key,
    required this.micOn,
    required this.camOn,
    required this.sharingScreen,
    required this.handRaised,
    this.compact = false,
    this.onToggleMic,
    this.onToggleCam,
    this.onToggleScreenShare,
    this.onToggleHand,
    this.onOpenChat,
    this.onOpenParticipants,
    this.onMore,
    required this.onEnd,
  });

  final bool micOn;
  final bool camOn;
  final bool sharingScreen;
  final bool handRaised;
  final bool compact;
  final VoidCallback? onToggleMic;
  final VoidCallback? onToggleCam;
  final VoidCallback? onToggleScreenShare;
  final VoidCallback? onToggleHand;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenParticipants;
  final VoidCallback? onMore;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final pad = compact ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                       : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    final gap = compact ? 4.0 : 6.0;
    final size = compact ? 36.0 : 44.0;

    Widget btn({
      required IconData on,
      required IconData off,
      required bool isOn,
      required String tooltipOn,
      required String tooltipOff,
      VoidCallback? onTap,
      bool dangerWhenOff = false,
    }) {
      return _CallControlButton(
        icon: isOn ? on : off,
        tooltip: isOn ? tooltipOn : tooltipOff,
        size: size,
        active: !isOn && dangerWhenOff,
        onTap: onTap,
      );
    }

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: c.elevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DRadii.pill),
        border: Border.all(color: c.borderSubtle),
        boxShadow: DShadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(
            on: FluentIcons.mic_24_filled,
            off: FluentIcons.mic_off_24_filled,
            isOn: micOn,
            tooltipOn: l10n.desktopCallCtlMicOff,
            tooltipOff: l10n.desktopCallCtlMicOn,
            onTap: onToggleMic,
            dangerWhenOff: true,
          ),
          SizedBox(width: gap),
          btn(
            on: FluentIcons.video_24_filled,
            off: FluentIcons.video_off_24_filled,
            isOn: camOn,
            tooltipOn: l10n.desktopCallCtlCamOff,
            tooltipOff: l10n.desktopCallCtlCamOn,
            onTap: onToggleCam,
            dangerWhenOff: true,
          ),
          SizedBox(width: gap),
          _CallControlButton(
            icon: sharingScreen
                ? FluentIcons.share_screen_stop_24_filled
                : FluentIcons.share_screen_start_24_filled,
            tooltip: sharingScreen ? l10n.desktopCallCtlShareStop : l10n.desktopCallCtlShare,
            size: size,
            highlighted: sharingScreen,
            onTap: onToggleScreenShare,
          ),
          SizedBox(width: gap),
          _CallControlButton(
            icon: handRaised
                ? FluentIcons.hand_right_24_filled
                : FluentIcons.hand_right_24_regular,
            tooltip: handRaised ? l10n.desktopCallCtlHandDown : l10n.desktopCallCtlHandUp,
            size: size,
            highlighted: handRaised,
            onTap: onToggleHand,
          ),
          if (!compact) ...[
            SizedBox(width: gap),
            _CallControlButton(
              icon: FluentIcons.chat_24_regular,
              tooltip: l10n.contactDetailsChat,
              size: size,
              onTap: onOpenChat,
            ),
            SizedBox(width: gap),
            _CallControlButton(
              icon: FluentIcons.people_24_regular,
              tooltip: l10n.desktopRoomTabMembers,
              size: size,
              onTap: onOpenParticipants,
            ),
            SizedBox(width: gap),
            _CallControlButton(
              icon: FluentIcons.more_horizontal_24_regular,
              tooltip: l10n.desktopThreadMore,
              size: size,
              onTap: onMore,
            ),
          ],
          SizedBox(width: gap + 4),
          _EndCallButton(size: size, onTap: onEnd),
        ],
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    this.active = false,
    this.highlighted = false,
    this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final double size;
  final bool active;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final disabled = onTap == null;
    return DesktopTooltip(
      message: tooltip,
      child: HoverListener(
        onTap: onTap,
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        builder: (ctx, hovered, pressed) {
          Color bg;
          Color fg;
          if (active) {
            bg = c.danger.withValues(alpha: pressed ? 0.95 : hovered ? 0.85 : 0.75);
            fg = Colors.white;
          } else if (highlighted) {
            bg = c.accentPrimary.withValues(alpha: pressed ? 0.95 : hovered ? 0.85 : 0.75);
            fg = Colors.white;
          } else {
            bg = hovered ? c.hover : Colors.transparent;
            if (pressed) bg = c.pressed;
            fg = c.textPrimary;
          }
          return AnimatedContainer(
            duration: DMotion.fast,
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: AnimatedScale(
              duration: DMotion.fast,
              scale: pressed ? 0.92 : 1.0,
              child: Icon(icon, size: size * 0.46, color: fg),
            ),
          );
        },
      ),
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.size, required this.onTap});
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return DesktopTooltip(
      message: l10n.desktopCallCtlHangUp,
      child: HoverListener(
        onTap: onTap,
        builder: (ctx, hovered, pressed) {
          return AnimatedContainer(
            duration: DMotion.fast,
            width: size * 1.6,
            height: size,
            decoration: BoxDecoration(
              color: pressed
                  ? c.danger.withValues(alpha: 0.85)
                  : (hovered ? c.danger.withValues(alpha: 0.95) : c.danger),
              borderRadius: BorderRadius.circular(DRadii.pill),
              boxShadow: [
                BoxShadow(
                  color: c.danger.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(FluentIcons.call_end_24_filled, color: Colors.white, size: 22),
            ),
          );
        },
      ),
    );
  }
}
