// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../rooms/room_call_manager.dart';
import '../../../rooms/room_call_media_controller.dart';
import '../design/tokens.dart';
import '../services/desktop_ui_prefs.dart';

/// «Звук и видео»: какая камера и какой микрофон пойдут в звонок.
///
/// ◆ РАЗДЕЛА НЕ БЫЛО, И ПРИЧИНА БЫЛА ВЕРНОЙ: до 15.09.2026 движок не умел
/// перечислять устройства, и пункт получился бы мёртвой панелью. Теперь умеет —
/// `videoInputs()` / `audioInputs()`, — и раздел собирается из настоящего
/// списка системы.
///
/// 🔴 ПЕРЕЧИСЛЕНИЕ РАБОТАЕТ И БЕЗ ЗВОНКА: список даёт система, а не сессия.
/// Поэтому выбрать камеру можно заранее, а не только когда уже звонишь, —
/// ровно тогда, когда человек этим и занимается.
///
/// Что сохраняется — ИДЕНТИФИКАТОР устройства, а не имя: имена меняются при
/// переподключении, а пропавшее устройство должно откатиться к системному, а
/// не увести звонок в тишину.
class MediaDevicesPane extends StatefulWidget {
  const MediaDevicesPane({super.key, required this.body});

  /// Обёртка раздела настроек: карточки и отступы приходят снаружи, чтобы
  /// этот виджет не знал о раскладке окна настроек.
  final Widget Function(List<Widget> children) body;

  @override
  State<MediaDevicesPane> createState() => _MediaDevicesPaneState();
}

class _MediaDevicesPaneState extends State<MediaDevicesPane> {
  List<RoomCallVideoDevice> _cameras = const <RoomCallVideoDevice>[];
  List<RoomCallVideoDevice> _mics = const <RoomCallVideoDevice>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// 🔴 СПРАШИВАЕМ СИСТЕМУ НАПРЯМУЮ, А НЕ ЧЕРЕЗ ДВИЖОК СОЗВОНА.
  ///
  /// Первая редакция брала список у `DefaultRoomCallMediaController()` — и
  /// панель честно показывала «Камер не найдено»: вне звонка у фасада нет
  /// делегата, и любой его метод отвечает «не знаю». Список устройств даёт
  /// система, сессия для этого не нужна.
  Future<void> _load() async {
    final cams = await roomCallSystemDevices(video: true);
    final mics = await roomCallSystemDevices(video: false);
    if (!mounted) return;
    setState(() {
      _cameras = cams;
      _mics = mics;
      _loading = false;
    });
  }

  Future<void> _pickCamera(String id) async {
    await DesktopUiPrefs.setPreferredCamera(id);
    // Идёт звонок — применяем сразу, а не «со следующего раза»: человек
    // меняет камеру ИМЕННО потому, что видит не то.
    if (id.isNotEmpty) {
      await RoomCallManager.instance?.mediaController?.selectVideoInput(id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickMic(String id) async {
    await DesktopUiPrefs.setPreferredMic(id);
    if (id.isNotEmpty) {
      await RoomCallManager.instance?.mediaController?.selectAudioInput(id);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    if (_loading) {
      return widget.body([
        Padding(
          padding: const EdgeInsets.all(DSpace.l),
          child: Text(
            l10n.desktopDevicesSearching,
            style: DType.body.copyWith(color: c.textSecondary),
          ),
        ),
      ]);
    }
    return widget.body([
      _DeviceCard(
        title: l10n.callControlCamera,
        icon: FluentIcons.video_24_regular,
        devices: _cameras,
        selectedId: DesktopUiPrefs.preferredCameraId.value,
        onPick: (id) => unawaited(_pickCamera(id)),
        emptyLabel: l10n.desktopDevicesNoCameras,
      ),
      _DeviceCard(
        title: l10n.callControlMute,
        icon: FluentIcons.mic_24_regular,
        devices: _mics,
        selectedId: DesktopUiPrefs.preferredMicId.value,
        onPick: (id) => unawaited(_pickMic(id)),
        emptyLabel: l10n.desktopDevicesNoMics,
      ),
      // 🔴 ВЫВОД ЗВУКА ЗДЕСЬ НЕ ВЫБИРАЕТСЯ, И ЭТО НЕ ЗАБЫВЧИВОСТЬ.
      //
      // Им распоряжается `CallAudioRouteController` во время созвона: он
      // переключается сам, когда втыкают наушники, и помнит выбор на время
      // разговора. Второй хозяин у той же настройки означал бы, что она
      // меняется в двух местах и разъезжается.
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, DSpace.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              FluentIcons.speaker_2_24_regular,
              size: 16,
              color: c.textTertiary,
            ),
            const SizedBox(width: DSpace.s),
            Expanded(
              child: Text(
                l10n.desktopDevicesOutputHint,
                style: DType.caption.copyWith(
                  color: c.textTertiary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.title,
    required this.icon,
    required this.devices,
    required this.selectedId,
    required this.onPick,
    required this.emptyLabel,
  });

  final String title;
  final IconData icon;
  final List<RoomCallVideoDevice> devices;
  final String selectedId;
  final ValueChanged<String> onPick;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    if (devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: DSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: DSpace.s),
              child: Text(
                title.toUpperCase(),
                style: DType.meta.copyWith(color: c.textTertiary),
              ),
            ),
            Text(
              emptyLabel,
              style: DType.caption.copyWith(color: c.textSecondary, height: 1.45),
            ),
          ],
        ),
      );
    }
    // «Как в системе» — первым: это умолчание, и оно должно быть достижимо
    // одним движением после любого выбора.
    final rows = <Widget>[
      _DeviceRow(
        label: l10n.desktopDevicesSystemDefault,
        selected: selectedId.isEmpty,
        onTap: () => onPick(''),
      ),
      for (final d in devices)
        _DeviceRow(
          label: d.label,
          selected: d.deviceId == selectedId,
          onTap: () => onPick(d.deviceId),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: DSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: DSpace.s),
            child: Row(
              children: [
                Icon(icon, size: 15, color: c.textTertiary),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: DType.meta.copyWith(color: c.textTertiary),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(DRadii.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.elevated,
                border: Border.all(color: c.borderSubtle),
                borderRadius: BorderRadius.circular(DRadii.md),
              ),
              child: Column(children: rows),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.m,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? FluentIcons.checkmark_circle_24_filled
                  : FluentIcons.circle_24_regular,
              size: 17,
              color: selected ? c.accentPrimary : c.textTertiary,
            ),
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.body.copyWith(
                  color: selected ? c.textPrimary : c.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
