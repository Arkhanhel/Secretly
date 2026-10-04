// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaDeviceInfo;

import '../../../calls/call_audio_route.dart';
import '../../../calls/call_manager.dart';
import '../../../rooms/room_call_manager.dart';
import '../calls/room_call_media_guard.dart';
import '../design/tokens.dart';
import '../primitives/hover_listener.dart';
import '../services/desktop_audio_output.dart';
import '../services/desktop_call_activity.dart';
import '../services/desktop_call_devices.dart';
import '../services/desktop_camera_preview.dart';
import '../services/desktop_device_watch.dart';
import '../services/desktop_mic_check.dart';
import '../services/desktop_ui_prefs.dart';
import 'media_check_rows.dart';
import 'settings_style.dart';
import 'workspace_layout.dart';

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
///
/// ◆ ПРОВЕРКИ (30.09.2026, ТЗ §1.4). Выбрать устройство мало — нужно
/// убедиться, что выбрано то: уровень микрофона и «записать — проиграть»
/// (см. `media_check_rows.dart`). Порядок карточек — как у Telegram и в ТЗ:
/// динамики, микрофон, камера.
class MediaDevicesPane extends StatefulWidget {
  const MediaDevicesPane({
    super.key,
    required this.body,
    this.enumerate,
    this.checks,
  });

  /// Обёртка раздела настроек: карточки и отступы приходят снаружи, чтобы
  /// этот виджет не знал о раскладке окна настроек.
  final Widget Function(List<Widget> children) body;

  /// Откуда брать список устройств; по умолчанию — у системы. Подменяют
  /// тесты.
  final Future<List<MediaDeviceInfo>> Function()? enumerate;

  /// Проверки звука; `null` — настоящие для своей системы.
  final MediaCheckServices? checks;

  @override
  State<MediaDevicesPane> createState() => _MediaDevicesPaneState();
}

class _MediaDevicesPaneState extends State<MediaDevicesPane> {
  List<DesktopDevice> _cameras = const <DesktopDevice>[];
  List<DesktopDevice> _mics = const <DesktopDevice>[];
  List<DesktopDevice> _speakers = const <DesktopDevice>[];
  bool _loading = true;

  bool _started = false;

  /// 🔴 СПИСОК ОБНОВЛЯЕТСЯ САМ (30.09.2026, ТЗ §1.4). Раньше он читался один
  /// раз при открытии раздела: воткнул гарнитуру — её нет, пока не уйдёшь из
  /// раздела и не вернёшься, и человек решал, что гарнитура не определилась.
  /// Почему опрос, а не событие системы, — см. [DesktopDeviceWatcher].
  late final DesktopDeviceWatcher _watcher = DesktopDeviceWatcher(
    onChanged: _reload,
    enumerate: widget.enumerate,
  );

  /// Раздел на экране: окно не спрятано в трей и не свёрнуто. Спрятанному
  /// разделу незачем спрашивать систему об устройствах — и незачем держать
  /// открытым микрофон.
  bool _visible = false;

  late final MediaCheckServices _checks =
      widget.checks ?? MediaCheckServices.system();

  /// Идёт ли звонок. Свой наблюдатель — только если его не подставили.
  DesktopCallActivity? _ownActivity;
  late final ValueListenable<bool> _callActive =
      _checks.callActive ?? (_ownActivity = DesktopCallActivity());

  /// Проигрыватель проверок — один на раздел: сигнал динамиков и запись
  /// микрофона звучат по очереди, а не друг поверх друга.
  DesktopAudioOutput? _output;
  DesktopMicCheck? _mic;
  DesktopSpeakerCheck? _speaker;

  /// Превью камеры — только по кнопке (см. `desktop_camera_preview.dart`).
  DesktopCameraPreviewController? _preview;

  @override
  void initState() {
    super.initState();
    if (_checks.soundChecks) {
      final output = _output = _checks.audioOutput();
      _mic = DesktopMicCheck(capture: _checks.micCapture(), output: output);
      _speaker = DesktopSpeakerCheck(output: output);
    }
    if (_checks.cameraCheck) {
      _preview = DesktopCameraPreviewController(engine: _checks.cameraEngine());
    }
    _callActive.addListener(_onCallActivity);
    DesktopUiPrefs.preferredMicId.addListener(_onPrefs);
    DesktopUiPrefs.preferredSpeakerId.addListener(_onPrefs);
    DesktopUiPrefs.preferredCameraId.addListener(_onPrefs);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      visible ? _watcher.start() : _watcher.stop();
      _syncMic();
    }
    // Имена безымянных устройств — из переводов, а их можно читать только
    // после initState.
    if (_started) return;
    _started = true;
    unawaited(_load(AppLocalizations.of(context)!));
  }

  void _reload() {
    if (!mounted) return;
    unawaited(_load(AppLocalizations.of(context)!));
  }

  void _onCallActivity() {
    if (!mounted) return;
    setState(() {});
    _syncMic();
  }

  /// Устройство выбрали в другом месте — в меню идущего звонка.
  void _onPrefs() {
    if (!mounted) return;
    setState(() {});
    _syncMic();
  }

  @override
  void dispose() {
    _watcher.dispose();
    _callActive.removeListener(_onCallActivity);
    DesktopUiPrefs.preferredMicId.removeListener(_onPrefs);
    DesktopUiPrefs.preferredSpeakerId.removeListener(_onPrefs);
    DesktopUiPrefs.preferredCameraId.removeListener(_onPrefs);
    _ownActivity?.dispose();
    // Микрофон и проигрыватель отпускаются ВМЕСТЕ с разделом: ушёл из
    // настроек — ничего не слушает и не звучит.
    _mic?.dispose();
    _speaker?.dispose();
    _preview?.dispose();
    unawaited(_output?.dispose());
    super.dispose();
  }

  /// 🔴 СПРАШИВАЕМ СИСТЕМУ НАПРЯМУЮ, А НЕ ЧЕРЕЗ ДВИЖОК СОЗВОНА.
  ///
  /// Первая редакция брала список у `DefaultRoomCallMediaController()` — и
  /// панель честно показывала «Камер не найдено»: вне звонка у фасада нет
  /// делегата, и любой его метод отвечает «не знаю». Список устройств даёт
  /// система, сессия для этого не нужна.
  Future<void> _load(AppLocalizations l10n) async {
    final cams = await desktopDeviceList(
      DesktopDeviceKind.camera,
      unnamed: l10n.desktopDevicesCamera,
      enumerate: widget.enumerate,
    );
    final mics = await desktopDeviceList(
      DesktopDeviceKind.microphone,
      unnamed: l10n.desktopDevicesMicrophone,
      enumerate: widget.enumerate,
    );
    final speakers = await desktopDeviceList(
      DesktopDeviceKind.speakers,
      unnamed: l10n.desktopDevicesSpeakers,
      enumerate: widget.enumerate,
    );
    if (!mounted) return;
    setState(() {
      _cameras = cams;
      _mics = mics;
      _speakers = speakers;
      _loading = false;
    });
    _syncMic(devicesChanged: true);
  }

  /// Выбранное устройство, если оно подключено; иначе '' — «как в системе»:
  /// ровно так поступит и звонок.
  static String _effective(List<DesktopDevice> devices, String selectedId) =>
      devices.any((d) => d.deviceId == selectedId) ? selectedId : '';

  static String _labelOf(List<DesktopDevice> devices, String id) {
    for (final d in devices) {
      if (d.deviceId == id) return d.label;
    }
    return '';
  }

  /// Какой микрофон слушает индикатор.
  String? _meterMicId;

  /// Индикатор микрофона — только пока раздел на экране и нет звонка, и
  /// всегда тот микрофон, что пойдёт в звонок.
  void _syncMic({bool devicesChanged = false}) {
    final wanted = _visible && !_callActive.value;
    // Сигнал динамиков тоже смолкает: звонок начался — не звучим человеку в
    // ухо; окно спрятали — не звучим из ниоткуда.
    if (!wanted) _speaker?.stop();
    _syncCamera(wanted);
    final mic = _mic;
    if (mic == null || _loading) return;
    if (!wanted) {
      _meterMicId = null;
      // 🔴 Всегда, а не «если включён» (30.09.2026): включение могло ещё
      // ждать ответа системы — статус при этом «выключен», и окно, спрятанное
      // в первую секунду раздела, оставляло микрофон открытым. `stop`
      // отменяет и такое включение, а выключенному ничего не делает.
      unawaited(mic.stop());
      return;
    }
    final id = _effective(_mics, DesktopUiPrefs.preferredMicId.value);
    final retry = devicesChanged && mic.status == MicCheckStatus.failed;
    if (_meterMicId == id && mic.status != MicCheckStatus.off && !retry) {
      return;
    }
    _meterMicId = id;
    unawaited(mic.start(micId: id, micLabel: _labelOf(_mics, id)));
  }

  /// Превью гаснет, когда раздел уходит с экрана или начинается звонок (на
  /// Windows камеру держит кто-то один), и идёт за выбором камеры.
  void _syncCamera(bool wanted) {
    final preview = _preview;
    if (preview == null || !preview.active) return;
    if (!wanted) {
      unawaited(preview.hide());
      return;
    }
    if (_loading) return;
    unawaited(
      preview.follow(
        _effective(_cameras, DesktopUiPrefs.preferredCameraId.value),
      ),
    );
  }

  Future<void> _pickCamera(String id) async {
    await DesktopUiPrefs.setPreferredCamera(id);
    // Идёт звонок — применяем сразу, а не «со следующего раза»: человек
    // меняет камеру ИМЕННО потому, что видит не то.
    //
    // 🔴 «Как в системе» ТОЖЕ применяется (30.09.2026). Раньше пустой выбор
    // до созвона не доходил вовсе, и камера оставалась прежней — пункт
    // ничего не менял. Теперь это конкретная камера: та, что движок
    // открывает сам, когда выбора нет (см. `resolveDesktopCamera`).
    //
    // 🔴 Но ВЫКЛЮЧЕННУЮ камеру выбор не включает (30.09.2026): переключение
    // устройства у приглушённой дорожки заново открывало камеру. Сторож
    // запоминает выбор до включения камеры.
    final media = RoomCallManager.instance?.mediaController;
    if (media != null) {
      final target = await desktopCameraTarget(enumerate: widget.enumerate);
      if (target != null) {
        await DesktopRoomCallMediaGuard.chooseCamera(media, target);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickMic(String id) async {
    await DesktopUiPrefs.setPreferredMic(id);
    // Идёт звонок — переключаем сразу. «Как в системе» тоже применяется:
    // модуль звука помнит прошлый выбор, и без этого остался бы на нём.
    final target = await desktopMicrophoneTarget();
    if (target != null) {
      await RoomCallManager.instance?.mediaController?.selectAudioInput(target);
      if (CallManager.instance?.state.value.isActive ?? false) {
        await prepareDesktopMicrophone();
      }
    }
    if (mounted) setState(() {});
  }

  /// 🔴 ДИНАМИКИ ТЕПЕРЬ ВЫБИРАЮТСЯ И ЗДЕСЬ (28.09.2026). Раньше вывод звука
  /// звонок угадывал сам по слову в названии устройства и на русской Windows
  /// уводил звук в первое по алфавиту — например, в монитор. Теперь по
  /// умолчанию «Как в системе», а выбор отсюда и из меню звонка — одна и та
  /// же настройка.
  Future<void> _pickSpeaker(String id) async {
    await DesktopUiPrefs.setPreferredSpeaker(id);
    final route = id.isEmpty ? kSystemDefaultAudioRouteId : id;
    if (CallManager.instance?.state.value.isActive ?? false) {
      await CallManager.instance?.selectAudioRoute(route);
    }
    await RoomCallManager.instance?.selectAudioRoute(route);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = SettingsScope.paletteOf(context);
    if (_loading) {
      return widget.body([
        Padding(
          padding: const EdgeInsets.all(DSpace.l),
          child: Text(
            l10n.desktopDevicesSearching,
            style: DType.body.copyWith(color: p.faint),
          ),
        ),
      ]);
    }
    final busy = _callActive.value;
    final speakerId = _effective(
      _speakers,
      DesktopUiPrefs.preferredSpeakerId.value,
    );
    final mic = _mic;
    final speaker = _speaker;
    final speakerLabel = _labelOf(_speakers, speakerId);
    return widget.body([
      WorkspaceCard(
        title: l10n.desktopDevicesSpeakers,
        child: Column(
          children: [
            ..._DeviceCard(
              devices: _speakers,
              selectedId: DesktopUiPrefs.preferredSpeakerId.value,
              onPick: (id) => unawaited(_pickSpeaker(id)),
              emptyLabel: l10n.desktopDevicesNoSpeakers,
            ).rows(context),
            if (speaker != null)
              speakerCheckRow(
                check: speaker,
                mic: mic,
                busy: busy,
                outputId: speakerId,
                outputLabel: speakerLabel,
              ),
          ],
        ),
      ),
      WorkspaceCard(
        title: l10n.desktopDevicesMicrophone,
        child: Column(
          children: [
            ..._DeviceCard(
              devices: _mics,
              selectedId: DesktopUiPrefs.preferredMicId.value,
              onPick: (id) => unawaited(_pickMic(id)),
              emptyLabel: l10n.desktopDevicesNoMics,
            ).rows(context),
            if (mic != null)
              ...micCheckRows(
                check: mic,
                speaker: speaker,
                busy: busy,
                outputId: speakerId,
                outputLabel: speakerLabel,
              ),
          ],
        ),
      ),
      WorkspaceCard(
        title: l10n.desktopDevicesCamera,
        child: Column(
          children: [
            ..._DeviceCard(
              devices: _cameras,
              selectedId: DesktopUiPrefs.preferredCameraId.value,
              onPick: (id) => unawaited(_pickCamera(id)),
              emptyLabel: l10n.desktopDevicesNoCameras,
            ).rows(context),
            ...cameraCheckRows(
              // Камер не нашлось — показывать нечего: кнопка «Показать»,
              // которая всегда отвечает «не удалось», хуже её отсутствия.
              preview: _cameras.isEmpty ? null : _preview,
              busy: busy,
              cameraId: _effective(
                _cameras,
                DesktopUiPrefs.preferredCameraId.value,
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// Список устройств одной карточки: «Как в системе» и то, что нашла система.
class _DeviceCard {
  const _DeviceCard({
    required this.devices,
    required this.selectedId,
    required this.onPick,
    required this.emptyLabel,
  });

  final List<DesktopDevice> devices;
  final String selectedId;
  final ValueChanged<String> onPick;
  final String emptyLabel;

  /// Строки — отдельными детьми карточки, чтобы между ними легли черты.
  List<Widget> rows(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (devices.isEmpty) {
      return <Widget>[_EmptyDevices(label: emptyLabel)];
    }
    // Выбранное устройство отключено — звонок идёт через системное, и
    // отмечено должно быть оно, а не пустота: иначе в списке не выбрано
    // ничего, и непонятно, что будет в звонке.
    final effective =
        devices.any((d) => d.deviceId == selectedId) ? selectedId : '';
    // «Как в системе» — первым: это умолчание, и оно должно быть достижимо
    // одним движением после любого выбора.
    final rows = <Widget>[
      _DeviceRow(
        label: l10n.desktopDevicesSystemDefault,
        selected: effective.isEmpty,
        onTap: () => onPick(''),
      ),
      for (final d in devices)
        _DeviceRow(
          label: d.label,
          selected: d.deviceId == effective,
          onTap: () => onPick(d.deviceId),
        ),
    ];
    return rows;
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: DType.family,
          fontSize: 13,
          height: 1.4,
          color: p.faint,
        ),
      ),
    );
  }
}

/// Строка выбора устройства: кружок-отметка и имя. Вся строка нажимается.
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
    final p = SettingsScope.paletteOf(context);
    final accent = DColors.of(context).accentPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: HoverListener(
        onTap: onTap,
        cursor: SystemMouseCursors.click,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          color: hovered ? p.hover : Colors.transparent,
          child: Row(
            children: [
              Icon(
                selected
                    ? FluentIcons.checkmark_circle_24_filled
                    : FluentIcons.circle_24_regular,
                size: 18,
                color: selected ? accent : p.faint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DType.family,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? p.head : p.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
