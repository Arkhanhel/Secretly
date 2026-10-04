// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_log.dart';

// PR-H+2 (2026-05-20): direct AVAudioSession channel to engage the iOS
// loudspeaker. flutter_webrtc's `Helper.setSpeakerphoneOn` goes through
// `RTCAudioSession.overrideOutputAudioPort`, which is silently reverted
// by RTCAudioSession's preferred-config re-apply (useManualAudio=NO)
// and by CallKit's `provider:didActivate:` callback. The native handler
// at `secretly/call_ui#setSpeakerEnabled` sets the category WITH
// `.defaultToSpeaker` directly, which survives both reverts.
const MethodChannel _iosCallAudioChannel = MethodChannel('secretly/call_ui');

Future<bool> _iosSetSpeakerEnabled(bool enabled) async {
  try {
    final result = await _iosCallAudioChannel.invokeMethod<bool>(
      'setSpeakerEnabled',
      {'enabled': enabled},
    );
    return result == true;
  } on PlatformException catch (e) {
    callLog(
      'CallAudio',
      'iOS native setSpeakerEnabled($enabled) failed: ${e.message}',
    );
    return false;
  } on MissingPluginException {
    // Older builds without the native handler — caller will fall back.
    return false;
  }
}

enum CallAudioRouteKind {
  bluetooth,
  wiredHeadset,
  earpiece,
  speaker,
  unknown,
}

@immutable
class CallAudioRouteOption {
  const CallAudioRouteOption({
    required this.deviceId,
    required this.label,
    required this.kind,
  });

  final String deviceId;
  final String label;
  final CallAudioRouteKind kind;

  bool get isExternalAccessory =>
      kind == CallAudioRouteKind.bluetooth ||
      kind == CallAudioRouteKind.wiredHeadset;

  bool get isSpeaker => kind == CallAudioRouteKind.speaker;
}

@immutable
class CallAudioRouteState {
  const CallAudioRouteState({
    required this.availableRoutes,
    required this.selectedRouteId,
    required this.selectedRouteKind,
    required this.preferSpeakerByDefault,
    required this.userSelectionActive,
  });

  const CallAudioRouteState.idle({this.preferSpeakerByDefault = false})
    : availableRoutes = const <CallAudioRouteOption>[],
      selectedRouteId = '',
      selectedRouteKind = CallAudioRouteKind.unknown,
      userSelectionActive = false;

  final List<CallAudioRouteOption> availableRoutes;
  final String selectedRouteId;
  final CallAudioRouteKind selectedRouteKind;
  final bool preferSpeakerByDefault;
  final bool userSelectionActive;

  bool get isSpeakerSelected => selectedRouteKind == CallAudioRouteKind.speaker;

  bool get hasExternalAccessory =>
      availableRoutes.any((route) => route.isExternalAccessory);

  bool get hasMultipleChoices =>
      availableRoutes.length > 2 ||
      (hasExternalAccessory && availableRoutes.length > 1);

  CallAudioRouteOption? get selectedRoute =>
      audioRouteById(availableRoutes, selectedRouteId);

  CallAudioRouteOption? get speakerRoute =>
      _firstRouteOfKind(availableRoutes, CallAudioRouteKind.speaker);

  CallAudioRouteOption? get preferredPrivateRoute {
    final external = preferredExternalRoute;
    if (external != null) {
      return external;
    }
    final earpiece =
        _firstRouteOfKind(availableRoutes, CallAudioRouteKind.earpiece);
    if (earpiece != null) {
      return earpiece;
    }
    for (final route in availableRoutes) {
      if (!route.isSpeaker) {
        return route;
      }
    }
    return null;
  }

  CallAudioRouteOption? get preferredExternalRoute {
    final bluetooth =
        _firstRouteOfKind(availableRoutes, CallAudioRouteKind.bluetooth);
    if (bluetooth != null) {
      return bluetooth;
    }
    return _firstRouteOfKind(
      availableRoutes,
      CallAudioRouteKind.wiredHeadset,
    );
  }

  CallAudioRouteState copyWith({
    List<CallAudioRouteOption>? availableRoutes,
    String? selectedRouteId,
    CallAudioRouteKind? selectedRouteKind,
    bool? preferSpeakerByDefault,
    bool? userSelectionActive,
  }) {
    return CallAudioRouteState(
      availableRoutes: availableRoutes ?? this.availableRoutes,
      selectedRouteId: selectedRouteId ?? this.selectedRouteId,
      selectedRouteKind: selectedRouteKind ?? this.selectedRouteKind,
      preferSpeakerByDefault:
          preferSpeakerByDefault ?? this.preferSpeakerByDefault,
      userSelectionActive: userSelectionActive ?? this.userSelectionActive,
    );
  }
}

CallAudioRouteOption? audioRouteById(
  List<CallAudioRouteOption> availableRoutes,
  String routeId,
) {
  final normalizedRouteId = routeId.trim();
  if (normalizedRouteId.isEmpty) {
    return null;
  }
  for (final route in availableRoutes) {
    if (route.deviceId == normalizedRouteId) {
      return route;
    }
  }
  return null;
}

CallAudioRouteKind classifyCallAudioRouteKind(MediaDeviceInfo device) {
  final normalizedDeviceId = device.deviceId.trim().toLowerCase();
  final normalizedGroupId = (device.groupId ?? '').trim().toLowerCase();
  final normalizedLabel = device.label.trim().toLowerCase();

  if (normalizedDeviceId == 'bluetooth' ||
      normalizedGroupId == 'bluetooth' ||
      normalizedLabel.contains('bluetooth')) {
    return CallAudioRouteKind.bluetooth;
  }
  if (normalizedDeviceId == 'wired-headset' ||
      normalizedGroupId == 'wired-headset' ||
      normalizedLabel.contains('wired')) {
    return CallAudioRouteKind.wiredHeadset;
  }
  if (normalizedDeviceId == 'speaker' ||
      normalizedGroupId == 'speaker' ||
      normalizedLabel.contains('speaker')) {
    return CallAudioRouteKind.speaker;
  }
  if (normalizedDeviceId == 'earpiece' ||
      normalizedGroupId == 'earpiece' ||
      normalizedLabel.contains('earpiece')) {
    return CallAudioRouteKind.earpiece;
  }
  return CallAudioRouteKind.unknown;
}

List<CallAudioRouteOption> normalizeCallAudioRouteOptions(
  Iterable<MediaDeviceInfo> devices,
) {
  final routesById = <String, CallAudioRouteOption>{};
  for (final device in devices) {
    final routeId = device.deviceId.trim();
    if (routeId.isEmpty) {
      continue;
    }
    routesById[routeId] = CallAudioRouteOption(
      deviceId: routeId,
      label: device.label.trim(),
      kind: classifyCallAudioRouteKind(device),
    );
  }
  final routes = routesById.values.toList(growable: false);
  routes.sort((left, right) {
    final kindCompare =
        _audioRouteSortOrder(left.kind).compareTo(_audioRouteSortOrder(right.kind));
    if (kindCompare != 0) {
      return kindCompare;
    }
    return left.label.compareTo(right.label);
  });
  return routes;
}

/// 2026-07-08: iOS `Helper.audiooutputs` enumerates ONLY the loudspeaker (plus
/// BT/wired when attached) — the built-in RECEIVER (ушной динамик) is never
/// reported. `resolvePreferredCallAudioRouteId` then found no earpiece for an
/// AUDIO call and fell through to the speaker, so iOS voice calls started on
/// loudspeaker by default. Every iPhone has a receiver, so synthesize the
/// earpiece option when the platform is iOS and enumeration omitted it; the
/// apply path routes it через overrideOutputAudioPort(.none) (native
/// setSpeakerEnabled(false)), which is exactly the receiver.
const String kIosSyntheticEarpieceRouteId = 'ios-builtin-earpiece';

List<CallAudioRouteOption> ensureIosEarpieceRoute(
  List<CallAudioRouteOption> routes,
) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return routes;
  final hasEarpiece = routes.any(
    (route) => route.kind == CallAudioRouteKind.earpiece,
  );
  if (hasEarpiece) return routes;
  return <CallAudioRouteOption>[
    ...routes,
    const CallAudioRouteOption(
      deviceId: kIosSyntheticEarpieceRouteId,
      label: 'iPhone',
      kind: CallAudioRouteKind.earpiece,
    ),
  ];
}

String resolvePreferredCallAudioRouteId({
  required List<CallAudioRouteOption> availableRoutes,
  required bool preferSpeakerByDefault,
}) {
  if (availableRoutes.isEmpty) {
    return '';
  }
  final bluetooth =
      _firstRouteOfKind(availableRoutes, CallAudioRouteKind.bluetooth);
  if (bluetooth != null) {
    return bluetooth.deviceId;
  }
  final wired =
      _firstRouteOfKind(availableRoutes, CallAudioRouteKind.wiredHeadset);
  if (wired != null) {
    return wired.deviceId;
  }
  if (preferSpeakerByDefault) {
    final speaker =
        _firstRouteOfKind(availableRoutes, CallAudioRouteKind.speaker);
    if (speaker != null) {
      return speaker.deviceId;
    }
  }
  final earpiece =
      _firstRouteOfKind(availableRoutes, CallAudioRouteKind.earpiece);
  if (earpiece != null) {
    return earpiece.deviceId;
  }
  final speaker = _firstRouteOfKind(availableRoutes, CallAudioRouteKind.speaker);
  if (speaker != null) {
    return speaker.deviceId;
  }
  return availableRoutes.first.deviceId;
}

bool shouldAutoPromoteExternalAudioRoute({
  required List<CallAudioRouteOption> availableRoutes,
  required String currentRouteId,
  bool userSelectionActive = false,
}) {
  final external = availableRoutes.any((route) => route.isExternalAccessory);
  if (!external) {
    return false;
  }
  final currentRoute = audioRouteById(availableRoutes, currentRouteId);
  // If the user just explicitly chose this route, never override it — even
  // if a wired headset / bluetooth accessory is connected. Otherwise tapping
  // "Speaker" while headphones are plugged in does nothing because the
  // accessory immediately re-promotes itself.
  if (userSelectionActive && currentRoute != null) {
    return false;
  }
  return currentRoute == null || !currentRoute.isExternalAccessory;
}

// ─────────────────────────────────────────────────────────────────────────
// 🔴 ПК: «КАК В СИСТЕМЕ» ВМЕСТО УГАДЫВАНИЯ ПО НАЗВАНИЮ (28.09.2026).
//
// Владелец: «во время звонка он выбирает не стандартные динамики, а какие-то
// первые по списку, и пока не переключишь — не слышишь человека».
//
// Правило телефона — тип устройства по английскому слову в названии
// («speaker», «bluetooth»…) и порядок BT → проводные → динамики — на
// компьютере не работает. Названия приходят от Windows на языке системы:
// «Динамики (Realtek)» не содержит «speaker», все устройства получали тип
// «неизвестно», и выбиралось ПЕРВОЕ ПО АЛФАВИТУ — латинское имя монитора или
// цифрового выхода. Звук уходил в тишину. На macOS «MacBook Pro Speakers»
// перебивали AirPods, в названии которых нет «bluetooth».
//
// Теперь на ПК ничего не угадываем. По умолчанию звук идёт туда, куда
// настроена система, и следует за ней (воткнули наушники — звонок перешёл в
// них). Другое устройство — только если человек выбрал его сам: в звонке или
// в настройках. Телефонов это не касается: там прежнее правило.
// ─────────────────────────────────────────────────────────────────────────

/// Пункт «Как в системе» в списке устройств вывода ПК.
const String kSystemDefaultAudioRouteId = 'system-default';

/// Пункт, которым модуль звука сам обозначает устройство системы по
/// умолчанию.
///
/// На macOS модуль WebRTC ставит первым пунктом «default (Имя устройства)»:
/// выбрать его и значит «как в системе» — модуль сам следует за системой.
/// `default` — так же называют его другие сборки модуля.
bool isSystemDefaultAudioDevice({
  required String deviceId,
  required String label,
}) {
  final id = deviceId.trim().toLowerCase();
  final name = label.trim().toLowerCase();
  return id == 'default' ||
      name.startsWith('default (') ||
      name.startsWith('default - ');
}

/// Что умеет компьютер и чего нет в общем коде: выбор человека из настроек и
/// «какое устройство система считает основным». Ставится приложением ПК при
/// запуске; на телефоне `null`.
class DesktopCallDeviceHooks {
  const DesktopCallDeviceHooks({
    required this.preferredOutputId,
    required this.systemDefaultOutputId,
    this.prepareCapture,
    this.preferredCameraId,
    this.ringtoneVolume,
    this.ringtoneAsset,
  });

  /// Динамики из настроек; пустая строка — «как в системе».
  final String Function() preferredOutputId;

  /// Идентификатор устройства вывода, которое ОС сейчас считает основным,
  /// если его можно узнать (Windows), иначе `null`.
  final Future<String?> Function() systemDefaultOutputId;

  /// Выбрать микрофон перед захватом звука в звонке 1:1.
  final Future<void> Function()? prepareCapture;

  /// Камера из настроек; пустая строка — системная.
  final String Function()? preferredCameraId;

  /// Громкость мелодии входящего звонка из настроек ПК, 0…1 (30.09.2026).
  final double Function()? ringtoneVolume;

  /// Мелодия входящего по выбору в настройках ПК (01.10.2026): по значению
  /// настройки мелодии — путь к звуку в сборке; `null` — мелодия по умолчанию.
  final String? Function(String setting)? ringtoneAsset;
}

/// Точка подключения ПК. Общий код читает её, но сам не заполняет.
abstract final class DesktopCallDevices {
  static DesktopCallDeviceHooks? hooks;
}

/// Во сколько раз приглушить мелодию входящего звонка: 1 — как было.
///
/// 🔴 ТЕЛЕФОН НЕ ЗАТРОНУТ: точку [DesktopCallDevices.hooks] заполняет только
/// ПК, на телефоне здесь всегда 1, и мелодия звучит ровно как раньше.
double desktopRingtoneVolumeScale() {
  final read = DesktopCallDevices.hooks?.ringtoneVolume;
  if (read == null) return 1.0;
  try {
    final v = read();
    return v.isFinite ? v.clamp(0.0, 1.0).toDouble() : 1.0;
  } catch (_) {
    return 1.0;
  }
}

/// Какой файл играть входящему звонку: выбранный в настройках ПК или
/// [fallback].
///
/// 🔴 ТЕЛЕФОН НЕ ЗАТРОНУТ: точку [DesktopCallDevices.hooks] заполняет только
/// ПК, на телефоне здесь всегда [fallback] — та же мелодия, что и раньше.
String desktopIncomingRingtoneAsset(
  String setting, {
  required String fallback,
}) {
  final pick = DesktopCallDevices.hooks?.ringtoneAsset;
  if (pick == null) return fallback;
  try {
    final asset = pick(setting);
    return (asset == null || asset.isEmpty) ? fallback : asset;
  } catch (_) {
    return fallback;
  }
}

/// Решение для ПК: список для меню, что отмечено и что включить.
@immutable
class DesktopAudioRouteDecision {
  const DesktopAudioRouteDecision({
    required this.routes,
    required this.selectedRouteId,
    required this.applyDeviceId,
  });

  /// «Как в системе» первым, затем настоящие устройства.
  final List<CallAudioRouteOption> routes;

  /// [kSystemDefaultAudioRouteId] или идентификатор устройства.
  final String selectedRouteId;

  /// Что передать модулю звука; `null` — ничего не трогать.
  final String? applyDeviceId;
}

/// Правило выбора устройства вывода на ПК. Чистая функция.
///
/// Порядок: выбор в этом звонке → выбор в настройках → «как в системе».
/// «Как в системе» включает пункт модуля «default (…)», если он есть (macOS),
/// иначе устройство, которое ОС назвала основным (Windows). Не удалось ни то,
/// ни другое — ничего не трогаем: лучше звук там, где его оставила система,
/// чем в угаданном устройстве.
DesktopAudioRouteDecision resolveDesktopAudioRoute({
  required Iterable<MediaDeviceInfo> devices,
  required String inCallSelection,
  required String preferredId,
  required String? systemDefaultId,
}) {
  final real = <CallAudioRouteOption>[];
  final seen = <String>{};
  String? moduleDefaultId;
  for (final device in devices) {
    final id = device.deviceId.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    final label = device.label.trim();
    if (isSystemDefaultAudioDevice(deviceId: id, label: label)) {
      moduleDefaultId ??= id;
      continue;
    }
    real.add(
      CallAudioRouteOption(
        deviceId: id,
        label: label,
        kind: classifyCallAudioRouteKind(device),
      ),
    );
  }
  bool present(String id) => real.any((route) => route.deviceId == id);

  final wanted = inCallSelection.trim();
  final preferred = preferredId.trim();
  final String selected;
  if (wanted == kSystemDefaultAudioRouteId) {
    selected = kSystemDefaultAudioRouteId;
  } else if (wanted.isNotEmpty && present(wanted)) {
    selected = wanted;
  } else if (preferred.isNotEmpty && present(preferred)) {
    selected = preferred;
  } else {
    selected = kSystemDefaultAudioRouteId;
  }

  String? apply;
  if (selected != kSystemDefaultAudioRouteId) {
    apply = selected;
  } else if (moduleDefaultId != null) {
    apply = moduleDefaultId;
  } else if (systemDefaultId != null && present(systemDefaultId.trim())) {
    apply = systemDefaultId.trim();
  }

  return DesktopAudioRouteDecision(
    routes: <CallAudioRouteOption>[
      const CallAudioRouteOption(
        deviceId: kSystemDefaultAudioRouteId,
        label: '',
        kind: CallAudioRouteKind.unknown,
      ),
      ...real,
    ],
    selectedRouteId: selected,
    applyDeviceId: apply,
  );
}

bool _isDesktopAudioPlatform() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

class CallAudioRouteController {
  CallAudioRouteController({required this.logTag, bool? desktopMode})
      : _desktopMode = desktopMode ?? _isDesktopAudioPlatform();

  final String logTag;

  /// ПК: правило «как в системе» вместо телефонного (см. выше).
  final bool _desktopMode;

  /// ПК: что человек выбрал в ЭТОМ звонке ('' — не выбирал).
  String _desktopInCallSelection = '';

  /// ПК: что уже включено в модуле звука. Выбор модуля общий на процесс и
  /// переживает звонок, поэтому при сбросе не забывается.
  String _appliedDesktopDeviceId = '';

  final ValueNotifier<CallAudioRouteState> state = ValueNotifier(
    const CallAudioRouteState.idle(),
  );

  String _selectedRouteId = '';
  bool _disposed = false;
  bool _refreshInFlight = false;
  bool _queuedRefresh = false;
  bool _queuedForceApply = false;
  bool _queuedPreferSpeakerByDefault = false;
  void Function(dynamic)? _deviceChangeHandler;

  /// Whatever `ondevicechange` handler was installed before ours.
  /// `navigator.mediaDevices.ondevicechange` is a single global slot and
  /// LiveKit's `Hardware` singleton installs its own handler there when a
  /// room call runtime starts — blindly overwriting it would silently break
  /// LiveKit's device tracking (and vice versa), so we chain instead.
  Function(dynamic)? _previousDeviceChangeHandler;

  Future<void> ensureReady({
    required bool preferSpeakerByDefault,
    required String reason,
    bool reapplySelectedRoute = false,
  }) async {
    if (_disposed) {
      return;
    }
    _attachDeviceChangeHandler();
    await _refreshRoutes(
      preferSpeakerByDefault: preferSpeakerByDefault,
      reason: reason,
      forceApplyCurrentRoute: reapplySelectedRoute,
    );
  }

  Future<void> selectRoute({
    required String routeId,
    required bool preferSpeakerByDefault,
    required String reason,
  }) async {
    if (_disposed) {
      return;
    }
    _selectedRouteId = routeId.trim();
    if (_desktopMode) {
      _desktopInCallSelection = routeId.trim();
    }
    await _refreshRoutes(
      preferSpeakerByDefault: preferSpeakerByDefault,
      reason: reason,
      forceApplyCurrentRoute: true,
      userSelectionActive: true,
    );
  }

  Future<void> reset({bool keepPreference = false}) async {
    _detachDeviceChangeHandler();
    _selectedRouteId = '';
    _desktopInCallSelection = '';
    if (_disposed) {
      return;
    }
    state.value = CallAudioRouteState.idle(
      preferSpeakerByDefault: keepPreference
          ? state.value.preferSpeakerByDefault
          : false,
    );
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _detachDeviceChangeHandler();
    state.dispose();
  }

  void _attachDeviceChangeHandler() {
    if (_deviceChangeHandler != null) {
      return;
    }
    final previous = navigator.mediaDevices.ondevicechange;
    _previousDeviceChangeHandler = previous;
    _deviceChangeHandler = (event) {
      // Keep the pre-existing handler (LiveKit's Hardware tracker) alive —
      // the slot is global and last-writer-wins without this chaining.
      final chained = _previousDeviceChangeHandler;
      if (chained != null) {
        try {
          chained(event);
        } catch (_) {}
      }
      unawaited(
        _refreshRoutes(
          preferSpeakerByDefault: state.value.preferSpeakerByDefault,
          reason: 'device_change',
          forceApplyCurrentRoute: false,
        ),
      );
    };
    navigator.mediaDevices.ondevicechange = _deviceChangeHandler;
  }

  void _detachDeviceChangeHandler() {
    final handler = _deviceChangeHandler;
    if (handler != null &&
        identical(navigator.mediaDevices.ondevicechange, handler)) {
      // Restore whatever was installed before us instead of clearing the
      // slot, so LiveKit's device tracking keeps working after our call ends.
      navigator.mediaDevices.ondevicechange = _previousDeviceChangeHandler;
    }
    _deviceChangeHandler = null;
    _previousDeviceChangeHandler = null;
  }

  Future<void> _refreshRoutes({
    required bool preferSpeakerByDefault,
    required String reason,
    required bool forceApplyCurrentRoute,
    bool? userSelectionActive,
  }) async {
    if (_disposed) {
      return;
    }
    if (_refreshInFlight) {
      _queuedRefresh = true;
      _queuedForceApply = _queuedForceApply || forceApplyCurrentRoute;
      _queuedPreferSpeakerByDefault = preferSpeakerByDefault;
      if (userSelectionActive != null && !_disposed) {
        state.value = state.value.copyWith(
          preferSpeakerByDefault: preferSpeakerByDefault,
          userSelectionActive: userSelectionActive,
        );
      }
      return;
    }

    _refreshInFlight = true;
    var pendingPreferSpeakerByDefault = preferSpeakerByDefault;
    var pendingReason = reason;
    var pendingForceApplyCurrentRoute = forceApplyCurrentRoute;
    var pendingUserSelectionActive = userSelectionActive;

    try {
      do {
        _queuedRefresh = false;
        _queuedForceApply = false;

        final nextState = await _refreshRoutesOnce(
          preferSpeakerByDefault: pendingPreferSpeakerByDefault,
          reason: pendingReason,
          forceApplyCurrentRoute: pendingForceApplyCurrentRoute,
          userSelectionActive: pendingUserSelectionActive,
        );
        if (_disposed) {
          return;
        }
        state.value = nextState;

        pendingPreferSpeakerByDefault = _queuedPreferSpeakerByDefault;
        pendingReason = 'queued_refresh';
        pendingForceApplyCurrentRoute = _queuedForceApply;
        pendingUserSelectionActive = null;
      } while (_queuedRefresh);
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<CallAudioRouteState> _refreshRoutesOnce({
    required bool preferSpeakerByDefault,
    required String reason,
    required bool forceApplyCurrentRoute,
    bool? userSelectionActive,
  }) async {
    final previousState = state.value;
    final preservedUserSelection =
        userSelectionActive ?? previousState.userSelectionActive;

    List<MediaDeviceInfo> devices;
    try {
      devices = await Helper.audiooutputs;
    } catch (e) {
      callLog(logTag, 'audio route enumerate failed reason=$reason: $e');
      return previousState.copyWith(
        preferSpeakerByDefault: preferSpeakerByDefault,
        userSelectionActive: preservedUserSelection,
      );
    }

    if (_desktopMode) {
      return _refreshDesktopRoutes(
        devices: devices,
        preferSpeakerByDefault: preferSpeakerByDefault,
        reason: reason,
        forceApply: forceApplyCurrentRoute,
      );
    }

    final availableRoutes = ensureIosEarpieceRoute(
      normalizeCallAudioRouteOptions(devices),
    );
    if (availableRoutes.isEmpty) {
      _selectedRouteId = '';
      return CallAudioRouteState.idle(
        preferSpeakerByDefault: preferSpeakerByDefault,
      );
    }

    var nextSelectedRouteId = _selectedRouteId.trim();
    var nextUserSelectionActive = preservedUserSelection;

    if (audioRouteById(availableRoutes, nextSelectedRouteId) == null) {
      nextSelectedRouteId = '';
      nextUserSelectionActive = false;
    }

    if (shouldAutoPromoteExternalAudioRoute(
      availableRoutes: availableRoutes,
      currentRouteId: nextSelectedRouteId,
      userSelectionActive: nextUserSelectionActive,
    )) {
      final externalRoute = CallAudioRouteState(
        availableRoutes: availableRoutes,
        selectedRouteId: nextSelectedRouteId,
        selectedRouteKind: CallAudioRouteKind.unknown,
        preferSpeakerByDefault: preferSpeakerByDefault,
        userSelectionActive: nextUserSelectionActive,
      ).preferredExternalRoute;
      if (externalRoute != null) {
        nextSelectedRouteId = externalRoute.deviceId;
        nextUserSelectionActive = false;
        forceApplyCurrentRoute = true;
        callLog(
          logTag,
          'audio route auto-promoted to external output reason=$reason route=${externalRoute.deviceId}',
        );
      }
    }

    if (nextSelectedRouteId.isEmpty) {
      nextSelectedRouteId = resolvePreferredCallAudioRouteId(
        availableRoutes: availableRoutes,
        preferSpeakerByDefault: preferSpeakerByDefault,
      );
      nextUserSelectionActive = false;
      forceApplyCurrentRoute = true;
    }

    if (nextSelectedRouteId.isNotEmpty &&
        (forceApplyCurrentRoute || nextSelectedRouteId != _selectedRouteId)) {
      await _applyRoute(
        nextSelectedRouteId,
        reason: reason,
        availableRoutes: availableRoutes,
      );
    }

    _selectedRouteId = nextSelectedRouteId;
    final selectedRoute = audioRouteById(availableRoutes, nextSelectedRouteId);
    return CallAudioRouteState(
      availableRoutes: availableRoutes,
      selectedRouteId: nextSelectedRouteId,
      selectedRouteKind: selectedRoute?.kind ?? CallAudioRouteKind.unknown,
      preferSpeakerByDefault: preferSpeakerByDefault,
      userSelectionActive: nextUserSelectionActive,
    );
  }

  Future<CallAudioRouteState> _refreshDesktopRoutes({
    required List<MediaDeviceInfo> devices,
    required bool preferSpeakerByDefault,
    required String reason,
    required bool forceApply,
  }) async {
    final hooks = DesktopCallDevices.hooks;
    String? systemDefault;
    if (hooks != null) {
      try {
        systemDefault = await hooks.systemDefaultOutputId();
      } catch (e) {
        callLog(logTag, 'desktop default output lookup failed: $e');
      }
    }
    final decision = resolveDesktopAudioRoute(
      devices: devices,
      inCallSelection: _desktopInCallSelection,
      preferredId: hooks?.preferredOutputId() ?? '',
      systemDefaultId: systemDefault,
    );
    final apply = decision.applyDeviceId;
    if (apply != null && (forceApply || apply != _appliedDesktopDeviceId)) {
      try {
        await Helper.selectAudioOutput(apply);
        _appliedDesktopDeviceId = apply;
        callLog(
          logTag,
          'desktop audio output applied reason=$reason '
          'selected=${decision.selectedRouteId} device=$apply',
        );
      } catch (e) {
        callLog(logTag, 'desktop audio output apply failed reason=$reason: $e');
      }
    }
    return CallAudioRouteState(
      availableRoutes: decision.routes,
      selectedRouteId: decision.selectedRouteId,
      selectedRouteKind: CallAudioRouteKind.unknown,
      preferSpeakerByDefault: preferSpeakerByDefault,
      userSelectionActive: _desktopInCallSelection.isNotEmpty,
    );
  }

  Future<void> _applyRoute(
    String routeId, {
    required String reason,
    required List<CallAudioRouteOption> availableRoutes,
  }) async {
    final normalizedRouteId = routeId.trim();
    if (normalizedRouteId.isEmpty) {
      return;
    }

    // PR-H+1 (2026-05-20): iOS uses AVAudioSession routing rather than the
    // WebRTC device-id mechanism. Helper.selectAudioOutput on iOS maps to
    // AVAudioSession.setPreferredOutput, which the system silently ignores
    // when overriding to the built-in speaker in .voiceChat mode (the
    // WebRTC default). The correct iOS API is overrideOutputAudioPort,
    // which Helper.setSpeakerphoneOn* call internally. Branch by platform
    // so the speaker button actually engages the loudspeaker.
    //
    // Android and desktop keep the original selectAudioOutput path because
    // their AudioManager honours the device-id mechanism directly and the
    // legacy fallback already covers any throw.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final option = audioRouteById(availableRoutes, normalizedRouteId);
      final kind = option?.kind ?? CallAudioRouteKind.unknown;
      // PR-H+2 (2026-05-20): try the native AVAudioSession path first —
      // it sets the category with `.defaultToSpeaker` and survives
      // RTCAudioSession's auto-revert. Fall back to Helper.* only when
      // the native handler is unavailable (older build, simulator, etc.).
      var nativeOk = false;
      try {
        switch (kind) {
          case CallAudioRouteKind.speaker:
            nativeOk = await _iosSetSpeakerEnabled(true);
            break;
          case CallAudioRouteKind.bluetooth:
          case CallAudioRouteKind.wiredHeadset:
          case CallAudioRouteKind.earpiece:
          case CallAudioRouteKind.unknown:
            // For non-speaker routes, clear the speaker override. The
            // .defaultToSpeaker category option is removed, then the
            // explicit output port override is cleared. Bluetooth and
            // wired-headset are then picked up via AVAudioSession's
            // own route selection.
            nativeOk = await _iosSetSpeakerEnabled(false);
            // For bluetooth specifically, also nudge flutter_webrtc so
            // its internal `RTCAudioSession.preferredInput` matches.
            if (kind == CallAudioRouteKind.bluetooth) {
              try {
                await Helper.setSpeakerphoneOnButPreferBluetooth();
              } catch (_) {}
            }
            break;
        }
        if (nativeOk) {
          callLog(
            logTag,
            'audio route applied (iOS native) reason=$reason '
            'route=$normalizedRouteId kind=$kind',
          );
          return;
        }
      } catch (e) {
        callLog(
          logTag,
          'audio route iOS native path threw reason=$reason '
          'route=$normalizedRouteId kind=$kind: $e',
        );
      }
      // Fallback: legacy Helper.* path (works on builds without the
      // native MethodChannel handler).
      try {
        switch (kind) {
          case CallAudioRouteKind.speaker:
            await Helper.setSpeakerphoneOn(true);
            break;
          case CallAudioRouteKind.bluetooth:
            await Helper.setSpeakerphoneOnButPreferBluetooth();
            break;
          case CallAudioRouteKind.wiredHeadset:
          case CallAudioRouteKind.earpiece:
          case CallAudioRouteKind.unknown:
            await Helper.setSpeakerphoneOn(false);
            break;
        }
        callLog(
          logTag,
          'audio route applied (iOS Helper fallback) reason=$reason '
          'route=$normalizedRouteId kind=$kind',
        );
      } catch (e) {
        callLog(
          logTag,
          'audio route iOS Helper fallback failed reason=$reason '
          'route=$normalizedRouteId kind=$kind: $e',
        );
      }
      return;
    }

    try {
      await Helper.selectAudioOutput(normalizedRouteId);
      callLog(
        logTag,
        'audio route applied reason=$reason route=$normalizedRouteId',
      );
      return;
    } catch (e) {
      callLog(
        logTag,
        'audio route direct selection failed reason=$reason route=$normalizedRouteId: $e',
      );
    }

    try {
      switch (normalizedRouteId) {
        case 'speaker':
          await Helper.setSpeakerphoneOn(true);
          break;
        case 'bluetooth':
          await Helper.setSpeakerphoneOnButPreferBluetooth();
          break;
        default:
          await Helper.setSpeakerphoneOn(false);
          break;
      }
      callLog(
        logTag,
        'audio route fallback applied reason=$reason route=$normalizedRouteId',
      );
    } catch (e) {
      callLog(
        logTag,
        'audio route fallback failed reason=$reason route=$normalizedRouteId: $e',
      );
    }
  }
}

CallAudioRouteOption? _firstRouteOfKind(
  List<CallAudioRouteOption> availableRoutes,
  CallAudioRouteKind kind,
) {
  for (final route in availableRoutes) {
    if (route.kind == kind) {
      return route;
    }
  }
  return null;
}

int _audioRouteSortOrder(CallAudioRouteKind kind) {
  switch (kind) {
    case CallAudioRouteKind.bluetooth:
      return 0;
    case CallAudioRouteKind.wiredHeadset:
      return 1;
    case CallAudioRouteKind.earpiece:
      return 2;
    case CallAudioRouteKind.speaker:
      return 3;
    case CallAudioRouteKind.unknown:
      return 4;
  }
}