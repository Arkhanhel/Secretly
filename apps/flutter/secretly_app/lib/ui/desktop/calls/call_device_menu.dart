// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// МЕНЮ УСТРОЙСТВ В ЗВОНКЕ — ОДНО НА ЗВОНОК 1:1 И ГРУППОВОЙ.
///
/// 🔴 ЗАЧЕМ (28.09.2026). Стрелка у кнопки «Микрофон» открывала список
/// устройств ВЫВОДА: выбрать сам микрофон в звонке было нельзя, а «Как в
/// системе» не было вовсе. Теперь, как у Telegram и Discord, два раздела:
/// «Микрофон» и «Динамики и наушники», в каждом первым — «Как в системе».
///
/// Выбор в звонке сразу становится настройкой: человек меняет устройство
/// потому, что звук идёт не туда, и ждёт того же в следующем звонке.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../calls/call_audio_route.dart';
import '../../../l10n/app_localizations.dart';
import '../primitives/context_menu.dart';
import '../services/desktop_call_devices.dart';
import '../services/desktop_ui_prefs.dart';
import 'call_controls.dart';

/// Пункты меню. Чистая функция — её проверяют тесты.
List<List<CtxMenuItem>> buildCallDeviceMenuSections({
  required AppLocalizations l10n,
  required List<DesktopDevice> microphones,
  required String selectedMicrophoneId,
  required CallAudioRouteState outputs,
  required void Function(String micId) onPickMicrophone,
  required void Function(String routeId) onPickOutput,
}) {
  final systemDefault = l10n.desktopDevicesSystemDefault;
  return <List<CtxMenuItem>>[
    [
      CtxMenuItem(label: l10n.desktopDevicesMicrophone, enabled: false),
      CtxMenuItem(
        label: systemDefault,
        icon: selectedMicrophoneId.isEmpty
            ? FluentIcons.checkmark_24_regular
            : FluentIcons.mic_24_regular,
        onTap: () => onPickMicrophone(''),
      ),
      for (final mic in microphones)
        CtxMenuItem(
          label: mic.label,
          icon: mic.deviceId == selectedMicrophoneId
              ? FluentIcons.checkmark_24_regular
              : FluentIcons.mic_24_regular,
          onTap: () => onPickMicrophone(mic.deviceId),
        ),
    ],
    if (outputs.availableRoutes.isNotEmpty)
      [
        CtxMenuItem(label: l10n.desktopDevicesSpeakers, enabled: false),
        for (final route in outputs.availableRoutes)
          CtxMenuItem(
            label: route.deviceId == kSystemDefaultAudioRouteId
                ? systemDefault
                : route.label,
            icon: route.deviceId == outputs.selectedRouteId
                ? FluentIcons.checkmark_24_regular
                : callAudioRouteIcon(route.kind),
            onTap: () => onPickOutput(route.deviceId),
          ),
      ],
  ];
}

/// Открыть меню устройств над кнопкой [anchor].
///
/// [applyOutput] — как переключить вывод в ЭТОМ звонке; [applyMicrophone] —
/// как переключить микрофон (у звонка 1:1 и группового разные движки).
Future<void> showCallDeviceMenu(
  BuildContext anchor, {
  required CallAudioRouteState outputs,
  required Future<void> Function(String routeId) applyOutput,
  required Future<void> Function() applyMicrophone,
}) async {
  final l10n = AppLocalizations.of(anchor)!;
  final microphones = await desktopDeviceList(
    DesktopDeviceKind.microphone,
    unnamed: l10n.desktopDevicesMicrophone,
  );
  if (!anchor.mounted) return;
  final sections = buildCallDeviceMenuSections(
    l10n: l10n,
    microphones: microphones,
    selectedMicrophoneId: DesktopUiPrefs.preferredMicId.value,
    outputs: outputs,
    onPickMicrophone: (id) => unawaited(() async {
      await DesktopUiPrefs.setPreferredMic(id);
      await applyMicrophone();
    }()),
    onPickOutput: (routeId) => unawaited(() async {
      await DesktopUiPrefs.setPreferredSpeaker(
        routeId == kSystemDefaultAudioRouteId ? '' : routeId,
      );
      await applyOutput(routeId);
    }()),
  );
  final rows = sections.fold<int>(0, (n, s) => n + s.length);
  await ContextMenu.show(
    anchor,
    globalPosition: callMenuAnchorAbove(anchor, rows),
    width: 280,
    sections: sections,
  );
}
