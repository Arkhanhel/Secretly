// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «Без звука…» со сроком — как у телефона и Telegram Desktop.
///
/// 🔴 30.09.2026, ТЗ «ПК как Telegram» §2. На ПК звук чата был только
/// «вкл/выкл»: заглушить шумную комнату на вечер значило потом не забыть
/// включить её обратно. Телефон давно умеет «на 1 час / 8 часов / навсегда /
/// только упоминания» (`setChatMute`); здесь — те же сроки плюс «2 дня»
/// Telegram. Сами вызовы контроллера — у разделов: этот файл только
/// рисует меню.
library;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

import '../../../l10n/app_localizations.dart';
import '../primitives/context_menu.dart';

enum DesktopMuteChoice { hour, eightHours, twoDays, forever, mentionsOnly }

/// Срок «без звука» в мс эпохи для `setChatMute`: `-1` — навсегда.
int desktopMuteUntilMs(DesktopMuteChoice choice, {required int nowMs}) =>
    switch (choice) {
      DesktopMuteChoice.hour => nowMs + const Duration(hours: 1).inMilliseconds,
      DesktopMuteChoice.eightHours =>
        nowMs + const Duration(hours: 8).inMilliseconds,
      DesktopMuteChoice.twoDays =>
        nowMs + const Duration(days: 2).inMilliseconds,
      DesktopMuteChoice.forever || DesktopMuteChoice.mentionsOnly => -1,
    };

/// Пункт меню: «Без звука…» с подменю сроков — или «Включить звук», если
/// чат уже заглушён.
CtxMenuItem desktopMuteMenuItem({
  required AppLocalizations l10n,
  required bool muted,
  required bool isRoom,
  required void Function(DesktopMuteChoice choice) onMute,
  required VoidCallback onUnmute,
}) {
  if (muted) {
    return CtxMenuItem(
      label: l10n.desktopChatsSoundOn,
      icon: FluentIcons.alert_24_regular,
      onTap: onUnmute,
    );
  }
  return CtxMenuItem(
    label: l10n.desktopMuteMenu,
    icon: FluentIcons.alert_off_24_regular,
    submenu: [
      CtxMenuItem(
        label: l10n.desktopMuteFor1h,
        icon: FluentIcons.clock_24_regular,
        onTap: () => onMute(DesktopMuteChoice.hour),
      ),
      CtxMenuItem(
        label: l10n.desktopMuteFor8h,
        icon: FluentIcons.clock_24_regular,
        onTap: () => onMute(DesktopMuteChoice.eightHours),
      ),
      CtxMenuItem(
        label: l10n.desktopMuteFor2d,
        icon: FluentIcons.calendar_24_regular,
        onTap: () => onMute(DesktopMuteChoice.twoDays),
      ),
      CtxMenuItem(
        label: l10n.desktopMuteForever,
        icon: FluentIcons.alert_off_24_regular,
        onTap: () => onMute(DesktopMuteChoice.forever),
      ),
      // Только в комнатах: в личной переписке упоминать некого, кроме тебя.
      if (isRoom)
        CtxMenuItem(
          label: l10n.desktopMuteMentionsOnly,
          icon: FluentIcons.mention_24_regular,
          onTap: () => onMute(DesktopMuteChoice.mentionsOnly),
        ),
    ],
  );
}
