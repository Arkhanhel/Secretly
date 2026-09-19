// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../design/tokens.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';
import '../services/desktop_notification_service.dart';

/// «Не беспокоить» в шапке окна.
///
/// 🔴 Настройка существовала и была спрятана.
///
/// `DesktopNotificationService.doNotDisturb` работал давно, но добраться до
/// него можно было только через раздел настроек — то есть выключить
/// уведомления на время созвона или разговора стоило четырёх нажатий и ухода
/// из чата. Это ровно тот случай, когда настройку включают и выключают по
/// несколько раз в день, и её место — на виду.
///
/// Кнопка не добавляет возможностей; она перестаёт их прятать.
class DesktopDndButton extends StatefulWidget {
  const DesktopDndButton({super.key});

  @override
  State<DesktopDndButton> createState() => _DesktopDndButtonState();
}

class _DesktopDndButtonState extends State<DesktopDndButton> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final svc = DesktopNotificationService.instance;
    // Службы может не быть вовсе (не десктопная система, ещё грузимся). Тогда
    // кнопки нет: серая кнопка, которая ничего не делает, хуже её отсутствия.
    if (svc == null) return const SizedBox.shrink();

    final off = svc.doNotDisturb;
    return DesktopTooltip(
      message: off ? l10n.desktopNotifOff : l10n.desktopNotifDnd,
      child: HoverListener(
        onTap: () async {
          await svc.setDoNotDisturb(!off);
          if (mounted) setState(() {});
        },
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.fast,
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed
                ? c.pressed
                : (hovered ? c.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            off
                ? FluentIcons.alert_off_24_regular
                : FluentIcons.alert_24_regular,
            size: 19,
            // Выключенные уведомления — состояние, о котором надо помнить:
            // человек перестаёт получать сообщения и должен видеть причину.
            color: off ? c.warning : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
