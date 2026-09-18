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

class CallAudioRouteController {
  CallAudioRouteController({required this.logTag});

  final String logTag;

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