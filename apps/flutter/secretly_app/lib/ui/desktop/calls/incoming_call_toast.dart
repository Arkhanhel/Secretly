// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';

/// Incoming call notification — top-right toast, NOT a full-screen modal.
/// Matches desktop conventions (FaceTime / Telegram desktop).
class IncomingCallToast extends StatelessWidget {
  const IncomingCallToast({
    super.key,
    required this.callerName,
    this.avatarName,
    this.callerSeed,
    this.callerImage,
    this.subtitle = 'Входящий звонок',
    this.video = false,
    required this.onAccept,
    required this.onDecline,
    this.onReplyWithText,
  });

  final String callerName;

  /// Имя для букв на заглушке, если оно отличается от заголовка: у
  /// неизвестного звонящего заголовок «Входящий звонок», а буквы — «?».
  final String? avatarName;

  /// Ключ цвета заглушки — профиль звонящего, как в списке чатов.
  final String? callerSeed;

  final ImageProvider? callerImage;
  final String subtitle;
  final bool video;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// · ОТВЕТИТЬ ТЕКСТОМ (макет). `null` — кнопки нет.
  ///
  /// 🔴 ЭТО НЕ ТРЕТИЙ СПОСОБ ОТКЛОНИТЬ. Между «взять трубку» и «сбросить» есть
  /// третий настоящий ответ — «сейчас не могу, напишу»: на совещании, в
  /// наушниках с музыкой, рядом со спящим ребёнком. Без него человек либо
  /// берёт трубку молча, либо сбрасывает, и звонивший не знает, что случилось.
  ///
  /// Кнопка сбрасывает звонок ТЕМ ЖЕ путём, что «Отклонить», и открывает
  /// переписку с этим человеком: дальше он пишет сам, приложение за него
  /// ничего не отправляет.
  final VoidCallback? onReplyWithText;

  /// Shows the toast as an overlay. Returns a [VoidCallback] to dismiss.
  static VoidCallback show(
    BuildContext context, {
    required String callerName,
    String? avatarName,
    String? callerSeed,
    ImageProvider? callerImage,
    String subtitle = 'Входящий звонок',
    bool video = false,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
    VoidCallback? onReplyWithText,
  }) {
    final entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned(
            top: 56,
            right: DSpace.l,
            child: _AnimatedEnter(
              child: IncomingCallToast(
                callerName: callerName,
                avatarName: avatarName,
                callerSeed: callerSeed,
                callerImage: callerImage,
                subtitle: subtitle,
                video: video,
                onAccept: onAccept,
                onDecline: onDecline,
                onReplyWithText: onReplyWithText,
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    return entry.remove;
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(DSpace.m),
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(DRadii.lg),
          border: Border.all(color: c.borderSubtle),
          boxShadow: DShadows.floating,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(
                  name: avatarName ?? callerName,
                  seed: callerSeed,
                  image: callerImage,
                  size: 48,
                ),
                const SizedBox(width: DSpace.m),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        callerName,
                        style: DType.bodyStrong.copyWith(color: c.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            video ? FluentIcons.video_24_regular : FluentIcons.call_24_regular,
                            size: 14,
                            color: c.accentPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            subtitle,
                            style: DType.label.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DSpace.m),
            // 🔴 ВЕС КНОПОК БЫЛ ПЕРЕПУТАН.
            //
            // «Отклонить» и «Ответить» стояли двумя одинаковыми половинами,
            // обе залиты сплошным цветом. Всплывашка приходит внезапно и
            // ловит палец на полпути — и половина площади под необратимым
            // «отклонить» это приглашение промахнуться. Сбросить звонок легко,
            // а вернуть его нельзя: перезванивать будет уже человек.
            //
            // В макете отклонение — узкая кнопка сбоку на приглушённой
            // красной плёнке, а «Ответить» занимает всё остальное сплошным
            // зелёным. Цвета не поменялись, поменялись площадь и вес.
            Row(
              children: [
                _ToastAction(
                  icon: FluentIcons.call_end_24_filled,
                  bg: c.danger.withValues(alpha: 0.16),
                  fg: c.danger,
                  width: 46,
                  tooltip: 'Отклонить',
                  onTap: onDecline,
                ),
                if (onReplyWithText != null) ...[
                  const SizedBox(width: DSpace.s),
                  Expanded(
                    child: _ToastAction(
                      icon: FluentIcons.chat_24_filled,
                      label: 'Текстом',
                      // Приглушённая, а не сплошная: это не главное действие
                      // всплывашки, а третий честный ответ рядом с ним.
                      bg: Colors.white.withValues(alpha: 0.06),
                      fg: c.textSecondary,
                      onTap: onReplyWithText!,
                    ),
                  ),
                ],
                const SizedBox(width: DSpace.s),
                Expanded(
                  child: _ToastAction(
                    icon: FluentIcons.call_24_filled,
                    label: video ? 'Ответить с видео' : 'Ответить',
                    bg: c.voice,
                    fg: Colors.white,
                    onTap: onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToastAction extends StatelessWidget {
  const _ToastAction({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.label,
    this.width,
    this.tooltip,
  });
  final IconData icon;

  /// `null` — кнопка без подписи, одним значком. Тогда обязателен [tooltip]:
  /// значок без слова должен уметь назвать себя хотя бы по наведению.
  final String? label;
  final Color bg;
  final Color fg;
  final double? width;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final btn = HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) {
        final fill = bg.withValues(
          alpha: (bg.a * (pressed ? 0.85 : (hovered ? 0.92 : 1.0)))
              .clamp(0.0, 1.0),
        );
        return AnimatedContainer(
          duration: DMotion.fast,
          width: width,
          padding: EdgeInsets.symmetric(
            vertical: 10,
            horizontal: label == null ? 0 : DSpace.s,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(DRadii.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 18),
              if (label != null) ...[
                const SizedBox(width: DSpace.s),
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
    final t = tooltip;
    return t == null ? btn : DesktopTooltip(message: t, child: btn);
  }
}

class _AnimatedEnter extends StatefulWidget {
  const _AnimatedEnter({required this.child});
  final Widget child;
  @override
  State<_AnimatedEnter> createState() => _AnimatedEnterState();
}

class _AnimatedEnterState extends State<_AnimatedEnter> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: DMotion.medium)..forward();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _ctrl, curve: DMotion.easeOutCubic);
    final slide = Tween(begin: const Offset(0.15, -0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: DMotion.easeOutBack));
    return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: widget.child));
  }
}
