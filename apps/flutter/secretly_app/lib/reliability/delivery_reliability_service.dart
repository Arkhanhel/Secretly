// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// DELIVERY RELIABILITY (2026-07-16, delivery-wake audit): status of the OS
/// settings that silently break message delivery. Server- and client-side
/// delivery fixes cannot overcome an OS-level block — only the user can flip
/// these switches, so the app must at least SEE and SHOW them (same approach
/// as WhatsApp's battery-optimization prompt and Telegram's "background
/// activity restricted" warning).
///
/// Read-only diagnostics + user-driven deep links; nothing is toggled
/// programmatically.
enum ReliabilityIssue {
  /// Android: app is subject to battery optimization (Doze can freeze it).
  batteryRestricted,

  /// Android: Data Saver is ON and the app is NOT whitelisted — background
  /// network (push-triggered fetches) is blocked on mobile data.
  backgroundDataBlocked,

  /// Notifications disabled at the OS level — banners never show.
  notificationsDisabled,

  /// iOS: Background App Refresh is off — background wakes are suppressed.
  backgroundRefreshOff,

  /// iOS: Low Power Mode — background activity is throttled (temporary).
  lowPowerMode,
}

class DeliveryReliabilityStatus {
  const DeliveryReliabilityStatus({
    required this.isAndroid,
    this.batteryUnrestricted,
    this.dataSaver = 'unknown',
    this.notificationsEnabled,
    this.manufacturer = '',
    this.backgroundRefresh = 'unknown',
    this.lowPowerMode,
  });

  final bool isAndroid;

  // Android
  final bool? batteryUnrestricted;

  /// disabled | whitelisted | enabled | unknown
  final String dataSaver;
  final String manufacturer;

  // Both platforms
  final bool? notificationsEnabled;

  // iOS
  /// available | denied | restricted | unknown
  final String backgroundRefresh;
  final bool? lowPowerMode;

  factory DeliveryReliabilityStatus.fromAndroidMap(Map<Object?, Object?> map) {
    return DeliveryReliabilityStatus(
      isAndroid: true,
      batteryUnrestricted: map['batteryUnrestricted'] as bool?,
      dataSaver: (map['dataSaver'] as String?) ?? 'unknown',
      notificationsEnabled: map['notificationsEnabled'] as bool?,
      manufacturer: ((map['manufacturer'] as String?) ?? '').toLowerCase(),
    );
  }

  factory DeliveryReliabilityStatus.fromIosMap(Map<Object?, Object?> map) {
    return DeliveryReliabilityStatus(
      isAndroid: false,
      backgroundRefresh: (map['backgroundRefresh'] as String?) ?? 'unknown',
      lowPowerMode: map['lowPowerMode'] as bool?,
      notificationsEnabled: map['notificationsEnabled'] as bool?,
    );
  }

  /// OEM skins with an autostart/"sleeping apps" manager that can force-stop
  /// the app with NO readable status API. For these we show an advisory row
  /// with a deep link; it is not counted as a warning (state unknowable).
  static const Set<String> _autostartOems = {
    'xiaomi',
    'redmi',
    'poco',
    'huawei',
    'honor',
    'oppo',
    'realme',
    'vivo',
    'iqoo',
    'oneplus',
    'meizu',
    'samsung',
  };

  bool get showAutostartAdvisory =>
      isAndroid && _autostartOems.contains(manufacturer);

  List<ReliabilityIssue> get issues {
    final out = <ReliabilityIssue>[];
    if (notificationsEnabled == false) {
      out.add(ReliabilityIssue.notificationsDisabled);
    }
    if (isAndroid) {
      if (batteryUnrestricted == false) {
        out.add(ReliabilityIssue.batteryRestricted);
      }
      if (dataSaver == 'enabled') {
        out.add(ReliabilityIssue.backgroundDataBlocked);
      }
    } else {
      if (backgroundRefresh == 'denied' || backgroundRefresh == 'restricted') {
        out.add(ReliabilityIssue.backgroundRefreshOff);
      }
      if (lowPowerMode == true) {
        out.add(ReliabilityIssue.lowPowerMode);
      }
    }
    return out;
  }

  bool get hasIssues => issues.isNotEmpty;
}

class DeliveryReliabilityService {
  DeliveryReliabilityService({
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting MethodChannel? batteryChannel,
    @visibleForTesting bool? forceIsAndroid,
  }) : _channel = channel ?? const MethodChannel('secretly/reliability'),
       _batteryChannel =
           batteryChannel ?? const MethodChannel('secretly/battery'),
       _forceIsAndroid = forceIsAndroid;

  final MethodChannel _channel;
  final MethodChannel _batteryChannel;
  final bool? _forceIsAndroid;

  bool get _isAndroid => _forceIsAndroid ?? Platform.isAndroid;
  bool get _isIos => _forceIsAndroid != null ? !_forceIsAndroid : Platform.isIOS;

  bool get isSupportedPlatform => _isAndroid || _isIos;

  /// Null when the platform has no reliability diagnostics (desktop) or the
  /// native side failed — callers render nothing rather than lying.
  Future<DeliveryReliabilityStatus?> getStatus() async {
    if (!isSupportedPlatform) return null;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getStatus',
      );
      if (raw == null) return null;
      return _isAndroid
          ? DeliveryReliabilityStatus.fromAndroidMap(raw)
          : DeliveryReliabilityStatus.fromIosMap(raw);
    } catch (_) {
      return null;
    }
  }

  /// Android: fires the system battery-exemption dialog (or jumps to the
  /// settings page when the dialog is unavailable).
  Future<bool> requestBatteryExemption() async {
    try {
      return await _batteryChannel.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openDataUsageSettings() => _open('openDataUsageSettings');
  Future<bool> openNotificationSettings() => _open('openNotificationSettings');
  Future<bool> openAutostartSettings() => _open('openAutostartSettings');
  Future<bool> openAppSettings() => _open('openAppSettings');

  Future<bool> _open(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }
}
