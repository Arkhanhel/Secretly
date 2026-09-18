// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/diag_log.dart';
import 'background_inbox_fetcher.dart';

const String _prefsPushWakePendingKey = 'push_wake_pending_v1';
const String _prefsPushWakeLastAtMsKey = 'push_wake_last_at_ms_v1';
const String _prefsPushWakeRoomCallsKey = 'push_wake_room_calls_v1';
const String _prefsPushWakeRecentMsgIdsKey = 'push_wake_recent_msg_ids_v1';
const String _prefsPushWakeOpenedConvoIdKey = 'push_wake_opened_convo_id_v1';
const String _prefsPushWakeOneToOneCallKey = 'push_wake_one_to_one_call_v1';
const String _roomCallWakeKind = 'room_call_sync_v1';
const String _oneToOneCallWakeKind = 'call_invite_v1';
const int _recentPushWakeRetentionMs = 10 * 60 * 1000;
const int _maxStoredRecentPushWakeMsgIds = 128;
const int _callInviteMaxAgeMs = 45 * 1000;

bool get _supportsFirebasePushWake =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class PushWakeRoomCallHint {
  const PushWakeRoomCallHint({
    required this.roomId,
    required this.callId,
    required this.callExists,
    required this.stateVersion,
    required this.receivedAtMs,
  });

  final String roomId;
  final String? callId;
  final bool callExists;
  final int stateVersion;
  final int receivedAtMs;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'room_id': roomId,
      'call_id': callId,
      'call_exists': callExists,
      'state_version': stateVersion,
      'received_at_ms': receivedAtMs,
    };
  }

  static PushWakeRoomCallHint? fromJsonMap(Map<Object?, Object?> json) {
    final roomId = ((json['room_id'] as String?) ?? '').trim();
    if (roomId.isEmpty) {
      return null;
    }
    final rawCallId = ((json['call_id'] as String?) ?? '').trim();
    return PushWakeRoomCallHint(
      roomId: roomId,
      callId: rawCallId.isEmpty ? null : rawCallId,
      callExists: _parseBool(json['call_exists']),
      stateVersion: _parseInt(json['state_version']),
      receivedAtMs: _parseInt(json['received_at_ms']),
    );
  }
}

/// Identity hint for a pending 1:1 incoming call from a relay push.
/// Stored in SharedPreferences so startup/foreground reconciliation can
/// dismiss stale native call UX before CallManager processes the signal.
class OneToOneCallWakeHint {
  const OneToOneCallWakeHint({
    required this.callId,
    required this.callAttemptId,
    required this.signalId,
    required this.createdAtMs,
    required this.receivedAtMs,
    required this.isVideo,
    required this.senderDeviceId,
  });

  final String callId;
  final String callAttemptId;
  final String signalId;
  final int createdAtMs;
  final int receivedAtMs;
  final bool isVideo;
  final String senderDeviceId;

  bool get isStale =>
      DateTime.now().millisecondsSinceEpoch - createdAtMs > _callInviteMaxAgeMs;

  Map<String, Object?> toJson() => <String, Object?>{
    'call_id': callId,
    'call_attempt_id': callAttemptId,
    'signal_id': signalId,
    'created_at_ms': createdAtMs,
    'received_at_ms': receivedAtMs,
    'is_video': isVideo,
    'sender_device_id': senderDeviceId,
  };

  static OneToOneCallWakeHint? fromJson(Map<Object?, Object?> json) {
    final callId = ((json['call_id'] as String?) ?? '').trim();
    if (callId.isEmpty) return null;
    return OneToOneCallWakeHint(
      callId: callId,
      callAttemptId: ((json['call_attempt_id'] as String?) ?? '').trim().let(
        (s) => s.isEmpty ? callId : s,
      ),
      signalId: ((json['signal_id'] as String?) ?? '').trim(),
      createdAtMs: _parseInt(json['created_at_ms']),
      receivedAtMs: _parseInt(json['received_at_ms']),
      isVideo: _parseBool(json['is_video']),
      senderDeviceId: ((json['sender_device_id'] as String?) ?? '').trim(),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

class PushWakeHintSnapshot {
  const PushWakeHintSnapshot({
    required this.pending,
    required this.lastAtMs,
    required this.roomCallHints,
    this.oneToOneCallHint,
  });

  final bool pending;
  final int? lastAtMs;
  final List<PushWakeRoomCallHint> roomCallHints;
  final OneToOneCallWakeHint? oneToOneCallHint;

  bool get hasWakeHint =>
      pending || roomCallHints.isNotEmpty || oneToOneCallHint != null;

  List<String> get roomCallRoomIds => roomCallHints
      .map((hint) => hint.roomId)
      .where((roomId) => roomId.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

class PushWakeRuntimeDiagnostics {
  const PushWakeRuntimeDiagnostics({
    required this.firebaseReady,
    required this.lastFirebaseInitAtMs,
    this.firebaseInitError,
    this.permissionStatus,
    this.permissionError,
    required this.lastPermissionAtMs,
    required this.currentTokenPresent,
    required this.lastTokenFetchAtMs,
    this.lastTokenFetchError,
  });

  final bool firebaseReady;
  final int lastFirebaseInitAtMs;
  final String? firebaseInitError;
  final String? permissionStatus;
  final String? permissionError;
  final int lastPermissionAtMs;
  final bool currentTokenPresent;
  final int lastTokenFetchAtMs;
  final String? lastTokenFetchError;
}

String _authorizationStatusLabel(AuthorizationStatus status) {
  switch (status) {
    case AuthorizationStatus.authorized:
      return 'authorized';
    case AuthorizationStatus.denied:
      return 'denied';
    case AuthorizationStatus.notDetermined:
      return 'not_determined';
    case AuthorizationStatus.provisional:
      return 'provisional';
  }
}

String _pushWakeDiagnosticsErrorSummary(Object error) {
  final raw = error.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  if (raw.isNotEmpty) {
    return raw.length <= 240 ? raw : raw.substring(0, 240);
  }
  return error.runtimeType.toString();
}

bool _parseBool(Object? value) {
  switch (value) {
    case true:
      return true;
    case 1:
      return true;
    case '1':
      return true;
    case 'true':
      return true;
    case 'TRUE':
      return true;
    default:
      return false;
  }
}

int _parseInt(Object? value) {
  return switch (value) {
    final int raw => raw,
    final num raw => raw.toInt(),
    final String raw => int.tryParse(raw) ?? 0,
    _ => 0,
  };
}

PushWakeRoomCallHint? _parseRoomCallHintFromData(
  Map<Object?, Object?> data,
  int receivedAtMs,
) {
  final wakeKind = ((data['wake_kind'] as String?) ?? '').trim();
  final type = ((data['type'] as String?) ?? '').trim();
  if (wakeKind != _roomCallWakeKind && type != _roomCallWakeKind) {
    return null;
  }
  final roomId = ((data['room_id'] as String?) ?? '').trim();
  if (roomId.isEmpty) {
    return null;
  }
  final rawCallId = ((data['call_id'] as String?) ?? '').trim();
  return PushWakeRoomCallHint(
    roomId: roomId,
    callId: rawCallId.isEmpty ? null : rawCallId,
    callExists: _parseBool(data['call_exists']),
    stateVersion: _parseInt(data['state_version']),
    receivedAtMs: receivedAtMs,
  );
}

OneToOneCallWakeHint? _parseOneToOneCallHintFromData(
  Map<Object?, Object?> data,
  int receivedAtMs,
) {
  final wakeKind = ((data['wake_kind'] as String?) ?? '').trim();
  if (wakeKind != _oneToOneCallWakeKind) return null;
  final action = ((data['action'] as String?) ?? '').trim().toLowerCase();
  final displayMode = ((data['display_mode'] as String?) ?? '')
      .trim()
      .toLowerCase();
  if ((action.isNotEmpty && action != 'invite') ||
      (displayMode.isNotEmpty && displayMode != 'incoming')) {
    return null;
  }
  final callId = ((data['call_id'] as String?) ?? '').trim();
  if (callId.isEmpty) return null;
  final createdAtMs = _parseInt(data['created_at_ms']);
  // Reject already-stale hints — no point storing them.
  if (createdAtMs > 0 && receivedAtMs - createdAtMs > _callInviteMaxAgeMs) {
    return null;
  }
  final rawAttemptId = ((data['call_attempt_id'] as String?) ?? '').trim();
  return OneToOneCallWakeHint(
    callId: callId,
    callAttemptId: rawAttemptId.isEmpty ? callId : rawAttemptId,
    signalId: ((data['signal_id'] as String?) ?? '').trim(),
    createdAtMs: createdAtMs,
    receivedAtMs: receivedAtMs,
    isVideo: _parseBool(data['is_video']),
    senderDeviceId: ((data['sender_device_id'] as String?) ?? '').trim(),
  );
}

OneToOneCallWakeHint? _readStoredOneToOneCallHint(SharedPreferences prefs) {
  final raw = (prefs.getString(_prefsPushWakeOneToOneCallKey) ?? '').trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return OneToOneCallWakeHint.fromJson(decoded.cast<Object?, Object?>());
  } catch (_) {
    return null;
  }
}

Future<void> _storeOneToOneCallHint(
  SharedPreferences prefs,
  OneToOneCallWakeHint hint,
) async {
  await prefs.setString(
    _prefsPushWakeOneToOneCallKey,
    jsonEncode(hint.toJson()),
  );
}

Map<String, PushWakeRoomCallHint> _readStoredRoomCallHints(
  SharedPreferences prefs,
) {
  final raw = (prefs.getString(_prefsPushWakeRoomCallsKey) ?? '').trim();
  if (raw.isEmpty) {
    return <String, PushWakeRoomCallHint>{};
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, PushWakeRoomCallHint>{};
    }
    final hints = <String, PushWakeRoomCallHint>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final hint = PushWakeRoomCallHint.fromJsonMap(
        value.cast<Object?, Object?>(),
      );
      if (hint == null) {
        continue;
      }
      hints[hint.roomId] = hint;
    }
    return hints;
  } catch (_) {
    return <String, PushWakeRoomCallHint>{};
  }
}

Future<void> _storeRoomCallHint(
  SharedPreferences prefs,
  PushWakeRoomCallHint hint,
) async {
  final hints = _readStoredRoomCallHints(prefs);
  final existing = hints[hint.roomId];
  if (existing == null || existing.receivedAtMs <= hint.receivedAtMs) {
    hints[hint.roomId] = hint;
  }
  await prefs.setString(
    _prefsPushWakeRoomCallsKey,
    jsonEncode(
      hints.map(
        (roomId, roomHint) =>
            MapEntry<String, Object?>(roomId, roomHint.toJson()),
      ),
    ),
  );
}

Map<String, int> _readStoredRecentMessageWakes(SharedPreferences prefs) {
  final raw = (prefs.getString(_prefsPushWakeRecentMsgIdsKey) ?? '').trim();
  if (raw.isEmpty) {
    return <String, int>{};
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, int>{};
    }
    final wakes = <String, int>{};
    for (final entry in decoded.entries) {
      final msgId = '${entry.key}'.trim();
      if (msgId.isEmpty) {
        continue;
      }
      final receivedAtMs = _parseInt(entry.value);
      if (receivedAtMs <= 0) {
        continue;
      }
      wakes[msgId] = receivedAtMs;
    }
    return wakes;
  } catch (_) {
    return <String, int>{};
  }
}

Future<void> _writeStoredRecentMessageWakes(
  SharedPreferences prefs,
  Map<String, int> wakes,
) async {
  await prefs.setString(_prefsPushWakeRecentMsgIdsKey, jsonEncode(wakes));
}

Future<void> _storeRecentMessageWake(
  SharedPreferences prefs,
  String messageId,
  int receivedAtMs,
) async {
  final normalizedMessageId = messageId.trim();
  if (normalizedMessageId.isEmpty) {
    return;
  }
  final cutoff = receivedAtMs - _recentPushWakeRetentionMs;
  final wakes = _readStoredRecentMessageWakes(prefs)
    ..removeWhere((msgId, atMs) => msgId.trim().isEmpty || atMs < cutoff)
    ..[normalizedMessageId] = receivedAtMs;
  if (wakes.length > _maxStoredRecentPushWakeMsgIds) {
    final entries = wakes.entries.toList(growable: false)
      ..sort((a, b) => a.value.compareTo(b.value));
    final removeCount = entries.length - _maxStoredRecentPushWakeMsgIds;
    for (var index = 0; index < removeCount; index += 1) {
      wakes.remove(entries[index].key);
    }
  }
  await _writeStoredRecentMessageWakes(prefs, wakes);
}

@pragma('vm:entry-point')
Future<void> secretlyFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // ignore: missing firebase runtime config
  }
  DiagLog.event('push', 'bg_msg', {
    'has_data': message.data.isNotEmpty,
    'type': (message.data['type'] as Object?)?.toString() ?? '',
    // 🔴 РЕШАЕТ НЕ `type`, А `wake_kind` (22.08.2026). Реле кладёт в `type`
    // всегда `relay_pending`, а род пробуждения — в `wake_kind`; именно по нему
    // приглашение звонка превращается в подсказку. Без этого поля разбор
    // «почему экран звонка не поднялся из пуша» упирался в стену: все строки
    // лога выглядели одинаково.
    'wake_kind': (message.data['wake_kind'] as Object?)?.toString() ?? '',
    'has_msg_id': message.data.containsKey('msg_id'),
  });
  await PushWakeService.markWakeHint(message.data);
  // BACKGROUND DRAIN (2026-07-16; decrypt added 2026-07-23): use the push-wake
  // window to FETCH the pending mailbox and, when it is the sole ratchet writer,
  // DECRYPT + persist + notify it right here — so a locked, killed phone shows
  // the message instead of only a contentless banner. Falls back to staging
  // when it cannot decrypt (see BackgroundInboxFetcher). Skips itself when the
  // main isolate is alive. Bounded + never throws.
  await BackgroundInboxFetcher.runFromPushWake();
}

class PushWakeService {
  PushWakeService._();

  static const MethodChannel _androidPushTokenChannel = MethodChannel(
    'secretly/push_token',
  );

  static bool _initialized = false;
  static Future<void>? _initializing;
  static bool _firebaseReady = false;
  static int _lastFirebaseInitAtMs = 0;
  static String? _lastFirebaseInitError;
  static String? _lastPermissionStatus;
  static String? _lastPermissionError;
  static int _lastPermissionAtMs = 0;
  static int _lastTokenFetchAtMs = 0;
  static String? _lastTokenFetchError;
  static bool _lastKnownTokenPresent = false;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  static final StreamController<String> _openedConversationController =
      StreamController<String>.broadcast();
  // DELIVERY FIX (2026-06-19): fires on every foreground data push so the app
  // force-drains the inbox even when it is ALREADY in the foreground. The
  // lifecycle.foreground force-pump only covers the background→foreground
  // transition; a push that lands while the app is open was previously handled
  // only by markWakeHint, leaving the fetch to the WS / non-force timer pump.
  // That pump short-circuits while the WS looks "fresh" — but a flapping WS
  // keeps refreshing the freshness stamp without ever delivering, so the
  // message stayed stranded in the relay mailbox (relay re-pushes, user sees
  // the notification but the message never lands in the chat).
  static final StreamController<void> _messageWakeController =
      StreamController<void>.broadcast();

  static PushWakeRuntimeDiagnostics get runtimeDiagnostics =>
      PushWakeRuntimeDiagnostics(
        firebaseReady: _firebaseReady,
        lastFirebaseInitAtMs: _lastFirebaseInitAtMs,
        firebaseInitError: _lastFirebaseInitError,
        permissionStatus: _lastPermissionStatus,
        permissionError: _lastPermissionError,
        lastPermissionAtMs: _lastPermissionAtMs,
        currentTokenPresent: _lastKnownTokenPresent,
        lastTokenFetchAtMs: _lastTokenFetchAtMs,
        lastTokenFetchError: _lastTokenFetchError,
      );

  static Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final active = _initializing;
    if (active != null) return active;

    final future = _initialize();
    _initializing = future;
    return future.whenComplete(() {
      if (identical(_initializing, future)) {
        _initializing = null;
      }
    });
  }

  static Future<void> _initialize() async {
    _firebaseReady = false;
    _lastFirebaseInitAtMs = DateTime.now().millisecondsSinceEpoch;
    _lastFirebaseInitError = null;

    if (!_supportsFirebasePushWake) {
      _lastFirebaseInitError = 'unsupported_platform';
      _initialized = true;
      return;
    }

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      _lastFirebaseInitError = _pushWakeDiagnosticsErrorSummary(e);
      _initialized = false;
      if (kDebugMode) {
        debugPrint('PushWakeService: Firebase init skipped: $e');
      }
      return;
    }

    FirebaseMessaging.onBackgroundMessage(
      secretlyFirebaseMessagingBackgroundHandler,
    );

    try {
      _lastPermissionAtMs = DateTime.now().millisecondsSinceEpoch;
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _lastPermissionStatus = _authorizationStatusLabel(
        settings.authorizationStatus,
      );
      _lastPermissionError = null;
    } catch (error) {
      _lastPermissionStatus = 'request_error';
      _lastPermissionError = _pushWakeDiagnosticsErrorSummary(error);
      // ignore
    }

    try {
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        await markWakeHint(initialMessage.data);
        await _markOpenedConversation(initialMessage.data);
      }
    } catch (_) {
      // ignore
    }

    await _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      DiagLog.event('push', 'fg_msg', {
        'has_data': message.data.isNotEmpty,
        'type': (message.data['type'] as Object?)?.toString() ?? '',
      });
      unawaited(markWakeHint(message.data));
      // Nudge the app to force-drain the inbox now (see _messageWakeController).
      if (!_messageWakeController.isClosed) {
        _messageWakeController.add(null);
      }
    });

    await _onMessageOpenedAppSub?.cancel();
    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      DiagLog.event('push', 'opened_app', {
        'type': (message.data['type'] as Object?)?.toString() ?? '',
        'has_convo': message.data.containsKey('convo_id'),
      });
      unawaited(markWakeHint(message.data));
      unawaited(_markOpenedConversation(message.data));
    });
    _initialized = true;
  }

  static Stream<String> get onTokenRefresh => _firebaseReady
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream<String>.empty();

  static Stream<String> get onOpenedConversation =>
      _openedConversationController.stream;

  /// Emits whenever a foreground data push arrives. The app controller listens
  /// and force-drains the inbox (debounced) so a message that lands while the
  /// app is open is fetched immediately instead of waiting on a flapping WS.
  static Stream<void> get onMessageWake => _messageWakeController.stream;

  static Future<int?> recentMessageWakeReceivedAtMs(
    String messageId, {
    SharedPreferences? prefs,
    bool reloadPrefs = true,
  }) async {
    final normalizedMessageId = messageId.trim();
    if (normalizedMessageId.isEmpty) {
      return null;
    }
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    if (reloadPrefs) {
      try {
        await resolvedPrefs.reload();
      } catch (_) {
        // ignore cache refresh failures
      }
    }
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - _recentPushWakeRetentionMs;
    final wakes = _readStoredRecentMessageWakes(resolvedPrefs);
    var changed = false;
    wakes.removeWhere((msgId, atMs) {
      final shouldRemove = msgId.trim().isEmpty || atMs < cutoff;
      changed = changed || shouldRemove;
      return shouldRemove;
    });
    if (changed) {
      await _writeStoredRecentMessageWakes(resolvedPrefs, wakes);
    }
    return wakes[normalizedMessageId];
  }

  static Future<String?> currentToken() async {
    _lastTokenFetchAtMs = DateTime.now().millisecondsSinceEpoch;
    if (!_firebaseReady) {
      final fallback = await _storedAndroidFcmToken();
      final hasFallback = (fallback ?? '').trim().isNotEmpty;
      _lastKnownTokenPresent = hasFallback;
      _lastTokenFetchError = 'firebase_not_ready';
      return fallback;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final normalized = (token ?? '').trim();
      final fallback = normalized.isEmpty
          ? await _storedAndroidFcmToken()
          : null;
      final resolvedToken = normalized.isNotEmpty ? normalized : fallback;
      final hasToken = (resolvedToken ?? '').trim().isNotEmpty;
      _lastKnownTokenPresent = hasToken;
      _lastTokenFetchError = null;
      return resolvedToken;
    } catch (error) {
      final fallback = await _storedAndroidFcmToken();
      final hasFallback = (fallback ?? '').trim().isNotEmpty;
      _lastKnownTokenPresent = hasFallback;
      _lastTokenFetchError = _pushWakeDiagnosticsErrorSummary(error);
      return fallback;
    }
  }

  static Future<String?> _storedAndroidFcmToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final token = await _androidPushTokenChannel.invokeMethod<String>(
        'storedFcmToken',
      );
      final normalized = (token ?? '').trim();
      return normalized.isEmpty ? null : normalized;
    } catch (_) {
      return null;
    }
  }

  static Future<void> markWakeHint([Map<Object?, Object?>? data]) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsPushWakePendingKey, true);
    await prefs.setInt(_prefsPushWakeLastAtMsKey, now);
    final recentMessageId = ((data?['msg_id'] as String?) ?? '').trim();
    if (recentMessageId.isNotEmpty) {
      await _storeRecentMessageWake(prefs, recentMessageId, now);
    }
    if (data != null) {
      final roomCallHint = _parseRoomCallHintFromData(data, now);
      if (roomCallHint != null) {
        await _storeRoomCallHint(prefs, roomCallHint);
      }
      final callHint = _parseOneToOneCallHintFromData(data, now);
      if (callHint != null) {
        await _storeOneToOneCallHint(prefs, callHint);
      }
      // Итог разбора — единственное место, где видно, СТАЛО ли приглашение
      // подсказкой. Молчание здесь и означало «экран поднялся не из пуша».
      final wakeKind = ((data['wake_kind'] as String?) ?? '').trim();
      if (wakeKind == _oneToOneCallWakeKind) {
        DiagLog.event('push', 'call_hint_stored', <String, Object?>{
          'stored': callHint != null,
          'action': ((data['action'] as String?) ?? '').trim(),
          'display_mode': ((data['display_mode'] as String?) ?? '').trim(),
          'has_call_id': ((data['call_id'] as String?) ?? '').trim().isNotEmpty,
        });
      }
    }
  }

  static Future<String?> consumeOpenedConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    final convoId = (prefs.getString(_prefsPushWakeOpenedConvoIdKey) ?? '')
        .trim();
    if (convoId.isEmpty) {
      return null;
    }
    await prefs.remove(_prefsPushWakeOpenedConvoIdKey);
    return convoId;
  }

  @visibleForTesting
  static Future<void> markOpenedConversationForTesting(
    Map<Object?, Object?>? data,
  ) async {
    await _markOpenedConversation(data);
  }

  static Future<void> _markOpenedConversation(
    Map<Object?, Object?>? data,
  ) async {
    final convoId = _extractOpenedConversationId(data);
    if (convoId == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPushWakeOpenedConvoIdKey, convoId);
    _openedConversationController.add(convoId);
  }

  static String? _extractOpenedConversationId(Map<Object?, Object?>? data) {
    final rawConvoId =
        ((data?['convo_id'] as String?) ??
                (data?['convoId'] as String?) ??
                (data?['room_id'] as String?))
            ?.trim();
    if (rawConvoId == null || rawConvoId.isEmpty) {
      return null;
    }
    return rawConvoId;
  }

  static Future<PushWakeHintSnapshot> consumeWakeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_prefsPushWakePendingKey) ?? false;
    final lastAtMs = prefs.getInt(_prefsPushWakeLastAtMsKey);
    final roomCallHints = _readStoredRoomCallHints(
      prefs,
    ).values.toList(growable: false);
    final rawOneToOneHint = _readStoredOneToOneCallHint(prefs);
    // Discard stale call hints at consume time — the call is too old to ring.
    final oneToOneCallHint =
        (rawOneToOneHint != null && !rawOneToOneHint.isStale)
        ? rawOneToOneHint
        : null;
    if (pending) {
      await prefs.remove(_prefsPushWakePendingKey);
    }
    await prefs.remove(_prefsPushWakeRoomCallsKey);
    await prefs.remove(_prefsPushWakeOneToOneCallKey);
    return PushWakeHintSnapshot(
      pending: pending,
      lastAtMs: lastAtMs,
      roomCallHints: roomCallHints,
      oneToOneCallHint: oneToOneCallHint,
    );
  }

  /// Clears any stored one-to-one call wake hint without consuming the full
  /// snapshot. Called when CallManager confirms the attempt is already ended.
  static Future<void> clearOneToOneCallHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsPushWakeOneToOneCallKey);
  }
}
