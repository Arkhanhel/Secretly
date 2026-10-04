// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «МЕЛОДИЯ ЗВОНКА» В НАСТРОЙКАХ ЗВОНКОВ ПК: громкость, «Послушать» и выбор
/// мелодии (ТЗ «ПК как Telegram», §1.4, блок «Входящие»).
///
/// ВЫБОР МЕЛОДИИ (01.10.2026, владелец: «человек должен выбирать звуки и
/// слышать их»). Мелодия по умолчанию (`Bubble.mp3`) и звуки из
/// `sounds/call/` — см. [DesktopSounds.callIds]. «Beacon» и «Chime» телефона
/// в список не вошли: это та же мелодия по умолчанию на ±3–4 % скорости,
/// выбор, который ничего не меняет. Выбор пишется в телефонный ключ мелодии,
/// звонок берёт файл через точку ПК (`DesktopCallDeviceHooks.ringtoneAsset`);
/// телефон её не заполняет и звучит как раньше.
///
/// Громкость — своя у ПК (`DesktopCallPrefs.ringtoneVolume`) и доходит до
/// звонка через точку ПК в общем коде (`desktopRingtoneVolumeScale`): на
/// телефоне множитель всегда 1.
///
/// «Послушать» — общий проигрыватель всех списков звуков
/// ([DesktopSoundPreview]): новая мелодия гасит прежний звук, где бы тот ни
/// играл.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../entitlements/entitlement_models.dart' show EntitlementState;
import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../services/desktop_call_activity.dart';
import '../services/desktop_call_prefs.dart';
import '../services/desktop_sounds.dart';
import 'media_check_rows.dart';
import 'settings_kit.dart';
import 'settings_style.dart';
import 'sound_picker.dart';
import 'workspace_layout.dart';

/// Карточка «Мелодия звонка».
class DesktopRingtoneCard extends StatefulWidget {
  const DesktopRingtoneCard({super.key, this.entitlement, this.callActive});

  /// Подписка сейчас; `null` — не известна, и тогда можно всё.
  final EntitlementState? Function()? entitlement;

  /// Идёт ли звонок; `null` — следить за настоящими.
  final ValueListenable<bool>? callActive;

  @override
  State<DesktopRingtoneCard> createState() => _DesktopRingtoneCardState();
}

class _DesktopRingtoneCardState extends State<DesktopRingtoneCard> {
  final DesktopSoundPreview _preview = DesktopSoundPreview.instance;
  DesktopCallActivity? _ownActivity;
  late final ValueListenable<bool> _callActive =
      widget.callActive ?? (_ownActivity = DesktopCallActivity());

  @override
  void initState() {
    super.initState();
    _callActive.addListener(_onCallActivity);
    _preview.playing.addListener(_onPreview);
    DesktopCallPrefs.ringtoneVolume.addListener(_onVolume);
  }

  void _onCallActivity() {
    // Звонок начался — «Послушать» смолкает: мелодия поверх разговора — это
    // шум у собеседника в ухе.
    if (_callActive.value) unawaited(_preview.stop());
    if (mounted) setState(() {});
  }

  void _onPreview() {
    if (mounted) setState(() {});
  }

  void _onVolume() {
    // Громкость меняется и во время «Послушать» — слышно сразу.
    unawaited(_preview.setCallVolume(DesktopCallPrefs.ringtoneVolume.value));
    if (mounted) setState(() {});
  }

  /// «Послушать» у громкости — ВЫБРАННАЯ мелодия, с той громкостью, с какой
  /// она зазвонит.
  Future<void> _listen() async {
    if (_callActive.value) return;
    var id = DesktopSounds.defaultCallId;
    try {
      final prefs = await SharedPreferences.getInstance();
      id = DesktopSounds.readId(prefs, DesktopSoundKind.call);
    } catch (_) {}
    if (!mounted || _callActive.value) return;
    await _preview.play(DesktopSoundKind.call, id);
  }

  @override
  void dispose() {
    _callActive.removeListener(_onCallActivity);
    _preview.playing.removeListener(_onPreview);
    DesktopCallPrefs.ringtoneVolume.removeListener(_onVolume);
    _ownActivity?.dispose();
    if (_preview.isPlayingKind(DesktopSoundKind.call)) {
      unawaited(_preview.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = SettingsScope.paletteOf(context);
    final volume = DesktopCallPrefs.ringtoneVolume.value;
    final busy = _callActive.value;
    final playing = _preview.isPlayingKind(DesktopSoundKind.call);
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(volume);
    final slider = Row(
      children: [
        Expanded(
          child: SettingsSlider(
            value: volume,
            min: 0,
            max: 1,
            divisions: DesktopCallPrefs.ringtoneVolumeSteps,
            semanticLabel: l10n.desktopRingtoneVolume,
            semanticValue: percent,
            onChanged: (v) => unawaited(DesktopCallPrefs.setRingtoneVolume(v)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            percent,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: DType.family,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: p.text,
            ),
          ),
        ),
      ],
    );
    final note = busy
        ? l10n.desktopMediaBusyInCall
        : (volume <= 0
              ? l10n.desktopRingtoneSilent
              : l10n.desktopRingtoneVolumeHint);
    return WorkspaceCard(
      title: l10n.desktopRingtoneTitle,
      // В столбце: у строки свои поля, и карточка не должна добавлять вторые.
      child: Column(
        children: [
          SettingsCheckRow(
            label: l10n.desktopRingtoneVolume,
            palette: p,
            lines: [slider, SettingsCheckNote(note)],
            trailing: SettingsSoftButton(
              label: playing
                  ? l10n.desktopMediaCheckStop
                  : l10n.desktopRingtoneListen,
              icon: playing
                  ? FluentIcons.stop_24_regular
                  : FluentIcons.music_note_2_24_regular,
              // Без звука слушать нечего; во время звонка — не время.
              onTap: playing
                  ? () => unawaited(_preview.stop())
                  : (busy || volume <= 0 ? null : () => unawaited(_listen())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DesktopSoundList(
              kind: DesktopSoundKind.call,
              entitlement: widget.entitlement,
              callActive: _callActive,
              previewEnabled: volume > 0,
            ),
          ),
        ],
      ),
    );
  }
}
