// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Шифрование группового созвона в окне ПК (ТЗ E2EE созвонов, §8.2).
///
/// Пока у устройства нет раскатки шифрования, окно созвона не меняется:
/// окон перед входом нет, плашки нет, в шапке прежняя честная подсказка
/// «шифруется при передаче». Замок и «Сквозное шифрование» — только в
/// зашифрованном созвоне.
library;

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../rooms/call_e2ee/room_call_e2ee_status.dart';
import '../design/tokens.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_switch.dart';

/// Окно у создателя (§8.3). Закрыть окно — не начинать.
Future<({bool encrypted, bool notify})?> showDesktopRoomCallCreatorChoice(
  BuildContext context,
  String names,
) {
  final l10n = AppLocalizations.of(context)!;
  final nav = Navigator.of(context, rootNavigator: true);
  var notify = true;
  return DesktopDialog.show<({bool encrypted, bool notify})>(
    context,
    title: l10n.roomCallStartChoiceTitle,
    size: DDialogSize.small,
    body: StatefulBuilder(
      builder: (ctx, setState) {
        final c = DColors.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.roomCallStartChoiceBody(names),
              style: DType.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DSpace.m),
            Row(
              children: [
                DesktopSwitch(
                  value: notify,
                  semanticsLabel: l10n.roomCallStartChoiceNotify,
                  onChanged: (v) => setState(() => notify = v),
                ),
                const SizedBox(width: DSpace.s),
                Expanded(
                  child: Text(
                    l10n.roomCallStartChoiceNotify,
                    style: DType.body.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
    primary: DDialogAction(
      label: l10n.roomCallStartEncrypted,
      onPressed: () => nav.maybePop((encrypted: true, notify: notify)),
    ),
    secondary: DDialogAction(
      label: l10n.roomCallStartOpen,
      onPressed: () => nav.maybePop((encrypted: false, notify: false)),
    ),
  );
}

/// Окно перед входом в открытый созвон, пока идёт раскатка шифрования.
Future<bool> showDesktopRoomCallOpenJoin(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final nav = Navigator.of(context, rootNavigator: true);
  final ok = await DesktopDialog.show<bool>(
    context,
    title: l10n.roomCallJoinOpenTitle,
    size: DDialogSize.small,
    body: Builder(
      builder: (ctx) => Text(
        l10n.roomCallJoinOpenBody,
        style: DType.body.copyWith(color: DColors.of(ctx).textSecondary),
      ),
    ),
    primary: DDialogAction(
      label: l10n.roomCallJoinOpenAction,
      onPressed: () => nav.maybePop(true),
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      onPressed: () => nav.maybePop(false),
    ),
  );
  return ok == true;
}

/// Подсказка у чипа в шапке окна созвона.
String desktopRoomCallSecurityHint(
  RoomCallE2eeStatus? status,
  AppLocalizations l10n,
) {
  if (status == null) return l10n.desktopRoomCallTransportEncrypted;
  return switch (status.own) {
    RoomCallE2eeOwnState.encrypting => l10n.roomCallE2eeOnHint,
    RoomCallE2eeOwnState.connecting => l10n.roomCallE2eeConnecting,
    RoomCallE2eeOwnState.failed =>
      status.errorCode == 'platform_unsupported'
          ? l10n.roomCallE2eeUnsupported
          : l10n.roomCallE2eeFailed,
  };
}

/// Плашка шифрования под шапкой окна созвона.
class DesktopRoomCallE2eeStrip extends StatelessWidget {
  const DesktopRoomCallE2eeStrip({
    super.key,
    required this.status,
    required this.showOpenWarning,
  });

  final RoomCallE2eeStatus? status;
  final bool showOpenWarning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final s = status;
    final IconData icon;
    final String text;
    final Color tint;
    if (s == null) {
      if (!showOpenWarning) return const SizedBox.shrink();
      icon = FluentIcons.lock_open_16_filled;
      text = l10n.roomCallOpenBanner;
      tint = c.danger;
    } else {
      switch (s.own) {
        case RoomCallE2eeOwnState.encrypting:
          if (s.unknownParticipants == 0) {
            // Всё хорошо — места не занимаем: замок уже в шапке.
            return const SizedBox.shrink();
          }
          icon = FluentIcons.shield_error_16_filled;
          text = l10n.roomCallE2eeUnknownParticipants(s.unknownParticipants);
          tint = c.warning;
        case RoomCallE2eeOwnState.connecting:
          icon = FluentIcons.clock_lock_16_filled;
          text = l10n.roomCallE2eeConnecting;
          tint = c.textSecondary;
        case RoomCallE2eeOwnState.failed:
          icon = FluentIcons.shield_error_16_filled;
          text = s.errorCode == 'platform_unsupported'
              ? l10n.roomCallE2eeUnsupported
              : l10n.roomCallE2eeFailed;
          tint = c.danger;
      }
    }
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.fromLTRB(DSpace.m, 0, DSpace.m, DSpace.s),
          padding: const EdgeInsets.symmetric(
            horizontal: DSpace.m,
            vertical: DSpace.s,
          ),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DRadii.sm),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: DSpace.s),
              Expanded(
                child: Text(
                  text,
                  style: DType.label.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
