// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_controller.dart';
import '../app/contact_action_failure.dart';
import '../diagnostics/diag_log.dart';
import '../push/push_wake_service.dart';
import '../ui/app_asset_paths.dart';
import '../transport/relay_client.dart';
import '../transport/native_network_path.dart';
import 'call_audio_route.dart';
import 'call_failure.dart';
import 'call_ice_config.dart';
import 'call_event.dart';
import 'call_journal.dart';
import 'call_log.dart';
import 'call_state.dart';
import 'call_state_machine.dart';
import 'webrtc_call_session.dart';

enum _RingtoneMode { incoming, outgoing, connecting }

enum RemoteVideoRecoveryStep {
  reattachRenderer,
  restartIce,
  renegotiate,
  failCall,
}

/// Global singleton that owns all call logic.
///
/// It listens to [AppController.callSignals], drives [WebRtcCallSession],
/// and exposes a [ValueNotifier<CallState>] that screens observe.
class CallManager {
  CallManager({required this.controller}) {
    _audioRouteController.state.addListener(_handleAudioRouteStateChanged);
  }

  static const String _incomingRingtoneAsset =
      AppAssetPaths.incomingRingtoneMp3;
  // Authentic ringback ("гудки дозвона") for outgoing calls instead of a
  // ringtone melody. (The previous pixel_tono.mp3 was also never audible — its
  // assets/app_ui/sounds/call/ dir was missing from pubspec's asset list.)
  static const String _outgoingRingtoneAsset = AppAssetPaths.ringbackToneWav;
  static const String _connectingToneAsset = AppAssetPaths.connectingToneMp3;
  static const MethodChannel _nativeCallUiChannel = MethodChannel(
    'secretly/call_ui',
  );
  static const EventChannel _nativeCallActionsChannel = EventChannel(
    'secretly/call_actions',
  );
  static const Duration _callUiRetryDelay = Duration(milliseconds: 250);
  static const int _activeCallUiRetryBudget = 120;

  /// Стандартный порт STUN. Тот же, на котором слушает наш coturn.
  static const int _stunPort = 3478;

  /// Запасной STUN, когда релей не отдал ни одного ICE-сервера.
  ///
  /// SEC-10② (26.08.2026). Здесь были зашиты публичные серверы Google. На
  /// проде они не использовались — релей отдаёт свои `stun:` и `turn:`, —
  /// но в том единственном случае, ради которого запасной вариант и
  /// существует, звонок уходил бы через чужую инфраструктуру, и ей
  /// становились видны адрес звонящего, время и сам факт звонка. Для
  /// приложения, обещающего не знать, откуда его открывают, это противоречие.
  ///
  /// 🔴 АДРЕС БЕРЁТСЯ ИЗ РЕЛЕЯ, А НЕ ЗАШИВАЕТСЯ. Подставить сюда
  /// `relay.secretlyapp.com` значило бы, что чужая установка (проект открыт
  /// под AGPL) молча слала бы адреса СВОИХ пользователей НАМ. Кто держит
  /// релей — тот держит и STUN; иного правильного ответа нет.
  ///
  /// Пустой список — честное вырождение: соберутся только локальные
  /// кандидаты, звонок в своей сети пройдёт, между сетями нет. Это лучше
  /// молчаливой отправки метаданных третьей стороне.
  static List<CallIceServerConfig> fallbackStunServersFor(Uri relayBaseUrl) {
    final host = relayBaseUrl.host.trim();
    if (host.isEmpty) return const <CallIceServerConfig>[];
    return <CallIceServerConfig>[
      CallIceServerConfig(urls: <String>['stun:$host:$_stunPort']),
    ];
  }

  final AppController controller;

  final ValueNotifier<CallState> state = ValueNotifier(CallState.empty);
  // Android 14+: whether USE_FULL_SCREEN_INTENT is granted. False means
  // incoming calls won't show when the app is killed. Checked at start().
  final ValueNotifier<bool> fullScreenIntentGranted = ValueNotifier(true);
  final CallAudioRouteController _audioRouteController =
      CallAudioRouteController(logTag: 'CallAudio');
  WebRtcCallSession? _session;
  WebRtcCallSession? get session => _session;
  // r11: dedup parallel session creation (prewarm + accept may race).
  Future<WebRtcCallSession>? _sessionInFlight;
  // r11: track which call we've already prewarmed so we don't prewarm twice
  // for the same incoming call attempt.
  String _prewarmedCallAttemptKey = '';
  ValueListenable<CallAudioRouteState> get audioRouteState =>
      _audioRouteController.state;

  StreamSubscription<CallSignalEvent>? _signalSub;
  StreamSubscription<bool>? _relayConnectionSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<dynamic>? _nativeNetworkPathSub;
  // Initialized to false so connectivity-triggered ICE recovery defers until
  // the relay socket has actually opened at least once. Toggled by
  // _onRelayConnectionChanged() — true on every relay-reconnect, false on
  // disconnect. Prevents a spurious recovery attempt before the relay is up.
  bool _relayConnected = false;
  String _lastNativeNetworkPathSignature = '';
  StreamSubscription<dynamic>? _nativeCallActionSub;
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  _RingtoneMode? _ringtoneMode;
  Timer? _incomingVibrationTimer;
  String _callVibrationSetting = 'off';
  String _callRingtoneSetting = 'default';
  Timer? _ringTimer;

  /// CALL AUDIT 2026-07-08 F2: while an outgoing call is still ringing, a
  /// TRANSIENT invite/offer send failure (slow uplink flush timeout, keys 429,
  /// momentary empty device resolve) no longer aborts the call — this timer
  /// re-sends the invite (+offer once its SDP exists) every few seconds with
  /// the SAME callId until the ring timeout ends the attempt. Idempotent: the
  /// callee dedups by callId/attempt.
  Timer? _inviteResendTimer;
  int _inviteResendTicks = 0;
  Timer? _connectTimer;
  Timer? _mobileInitialConnectAssistTimer;
  Timer? _answerResendTimer;
  Timer? _offerRequestTimer;
  Timer? _reconnectWatchdogTimer;
  Timer? _reconnectingPollTimer;
  Timer? _iceRestartInFlightSafetyTimer;
  int _iceRestartInFlightStartedAtMs = 0;
  Timer? _connectivityHandoffRecoveryTimer;
  // Grace window before reacting to a transient ICE/RTC "disconnected" state
  // (as opposed to the terminal "failed" state, which still reacts
  // immediately, untouched). WebRTC's disconnected state is explicitly
  // meant to be transient (brief Wi-Fi hiccup, cell handoff) and often
  // self-heals within a second or two without any restart — reacting to it
  // instantly flips the call's visible lifecycle + arms the reconnect
  // watchdog for every such blip.
  Timer? _disconnectDebounceTimer;
  static const Duration _disconnectDebounceWindow = Duration(
    milliseconds: 1500,
  );
  VoidCallback? _connListener;
  VoidCallback? _iceConnListener;
  VoidCallback? _mediaEstablishedListener;
  VoidCallback? _remoteVideoLifecycleListener;
  int _lastCallUiPushAtMs = 0;
  String _lastCallUiRoute = '';
  String _pendingCallUiRoute = '';
  String _pendingCallUiCallId = '';
  Timer? _pendingCallUiGuardTimer;
  String _visibleCallUiRoute = '';
  String _visibleCallUiCallId = '';

  // Buffered native accept/decline from killed/backgrounded state: user acted
  // on the native UI before Flutter processed the invite signal.
  String? _pendingNativeCallAction;
  String _pendingNativeActionCallId = '';
  String _pendingNativeActionAttemptId = '';

  // Safety net for a ring this isolate adopted but never got an invite for.
  // See _adoptNativeIncomingRing.
  Timer? _adoptedRingWatchdog;
  bool _missedTrailDrainInFlight = false;
  bool _persistedSignalDrainInFlight = false;

  // Buffered offer/ICE that arrive while still ringing (before user accepts).
  String? _pendingOfferSdp;
  String? _pendingRemoteAnswerSdp;
  final List<CallSignalEvent> _pendingIceCandidates = [];
  String? _lastLocalAnswerSdp;
  String? _lastLocalOfferSdp;
  String? _lastSentOfferFingerprint;
  String _lastSentOfferCallId = '';
  String _lastSentOfferCallAttemptId = '';
  int _lastSentOfferAtMs = 0;
  int _answerResendAttempts = 0;
  int _needOfferAttempts = 0;
  int _lastNeedOfferHandledAtMs = 0;
  int _lastOfferRecoveryRequestAtMs = 0;
  int _consecutiveMissingRelaySessions = 0;
  int _lastObservedRelaySessionAtMs = 0;
  bool _isProcessingOffer = false;
  String _endingCallAttemptId = '';
  String? _queuedOfferSdp;
  bool _awaitingRecoveryOffer = false;
  String? _lastOfferFingerprint;
  int _lastOfferProcessedAtMs = 0;
  String? _lastRemoteAnswerFingerprint;
  int _lastRemoteAnswerProcessedAtMs = 0;
  // Last ended call attempts — used to suppress relay re-delivery of the same
  // invite/offer/ICE for the same logical attempt. Persisted in
  // SharedPreferences so ghost calls are also filtered after app restarts
  // within the relay's 90-second delivery window.
  final Set<String> _lastEndedCallAttemptKeys = {};
  static const String _prefKeyEndedCallAttemptKeys =
      'call_manager_ended_call_attempt_keys';
  static const int _maxEndedCallAttemptKeysKept = 10;

  // AUD-025: Strictly serialized signal processing. `_onSignal` mutates
  // state.value and performs async work (ring tones, SDP, network I/O). Two
  // signals cannot be processed concurrently without corrupting state, so we
  // funnel every source (buffered replay + live broadcast) through a single
  // FIFO chain. Dedup by signalId prevents the same event from being
  // processed twice when the buffer overlaps with the live stream.
  Future<void> _signalProcessingChain = Future<void>.value();
  final Set<String> _processedSignalIds = <String>{};
  static const int _processedSignalIdCapacity = 512;
  // Timestamp of the last accept action. Used to suppress the duplicate
  // /call push that arises when IncomingCallActivity closes and triggers
  // an AppLifecycleState.resumed callback within a few seconds.
  int _lastAcceptedAtMs = 0;
  bool _iceRestartInFlight = false;
  // Monotonically incremented every time a new ICE restart attempt acquires
  // the in-flight lock. Used to ensure that a stale invocation's `finally`
  // block does not clobber the lock state of a successor that was launched
  // by the safety timer or `_forceReleaseIceRestartLockIfStale`.
  int _iceRestartInFlightGeneration = 0;
  // Tracks whether the Android CallForegroundService is currently running so
  // we avoid redundant start/stop round-trips.
  bool _callForegroundServiceRunning = false;

  /// 🔴 ЧЕЛОВЕК НАЖАЛ НА УВЕДОМЛЕНИЕ И ЖДЁТ ЭКРАН (14.08.2026).
  ///
  /// Замер холодного старта: нажатие доставляется В 10:43:38, а состояние звонка
  /// заводится в 10:43:39 — СЕКУНДОЙ ПОЗЖЕ. Обработчик нажатия видел «звонка
  /// нет» и не мог ничего открыть, а следом показывалась нативная плашка —
  /// второе уведомление, по которому и открывался экран. Отсюда «зачем ещё один
  /// посредник».
  ///
  /// Отдельный признак, а НЕ буфер решений: тот на один слот, и нажатие,
  /// положенное в него, затёрло бы настоящее «Принять» (шрам 04.08).
  /// Признак ничего не решает — он лишь помнит, что показать, когда будет чем.
  bool _incomingScreenRequested = false;
  bool _relaySessionReconcileInFlight = false;
  bool _remoteVideoRecoveryInFlight = false;
  bool _outgoingOfferBootstrapInFlight = false;
  String _lastObservedRelaySessionCallId = '';
  String _lastObservedRelaySessionAttemptId = '';
  String _lastObservedRelaySessionState = '';
  String _lastMissingRelaySessionAttemptId = '';
  String _lastNativeIncomingCallId = '';
  String _lastNativeIncomingCallAttemptId = '';
  String _remoteVideoRecoveryAttemptId = '';
  int _remoteVideoRecoveryAttempts = 0;
  int _lastRelayReconnectRecoveryAtMs = 0;
  List<ConnectivityResult> _lastConnectivityResults =
      const <ConnectivityResult>[];
  int _lastConnectivityRecoveryAtMs = 0;
  int _lastConnectivityRecoveryTriggerAtMs = 0;
  String _lastConnectivityRecoveryAttemptKey = '';
  int _connectivityFollowUpRecoveryAttempts = 0;
  bool _queuedConnectivityHandoffRecovery = false;
  // F9 (2026-05-16): set when a connectivity change fires while the relay
  // WS is down. Causes _handleRelayReconnect to bypass its throttle and
  // immediately fire a hard ICE-restart recovery on the very first
  // reconnect tick — instead of waiting for the next watchdog/poll cycle.
  bool _pendingRelayConnectivityRecovery = false;
  int _pendingRelayConnectivityRecoveryAtMs = 0;
  // Window during which a pending recovery flag is honored on relay
  // reconnect. After this we fall back to the normal throttled path.
  static const int _pendingRelayConnectivityRecoveryWindowMs = 15000;
  String _mobileInitialConnectAssistAttemptKey = '';
  int _mobileInitialConnectAssistAttempts = 0;
  Future<CallIceConfigSnapshot>? _recoveryIceConfigRefreshInFlight;

  static const Duration _reconnectWatchdogWindow = Duration(minutes: 4);
  // Periodic poll while in reconnecting phase to retry recovery if a previous
  // attempt silently failed or got stuck (top apps recover within seconds).
  static const Duration _reconnectingPollInterval = Duration(
    milliseconds: 1500,
  );
  // Hard cap on how long an ICE restart can hold the in-flight lock before
  // we force-unlock so subsequent connectivity events are not silently
  // ignored. Stuck SDP/relay sends would otherwise block all recovery for
  // up to 4 minutes (the watchdog window).
  //
  // 12 s: on a slow relay the full round-trip (offer gen → relay send →
  // remote answer → setRemoteDescription) can take up to ~8-10 s. 4 s was
  // too tight and caused the safety timer to fire mid-restart, releasing the
  // lock prematurely and triggering two concurrent ICE restarts which corrupt
  // the SDP state machine.
  static const Duration _iceRestartInFlightSafetyTimeout = Duration(
    seconds: 12,
  );
  // Require more consecutive misses before giving up — relay can transiently
  // disappear on flaky networks. 4 misses ≈ ~6s at the normal reconcile rate.
  static const int _missingRelaySessionTerminationThreshold = 4;
  // How long after we last saw an authoritative relay state we treat a missing
  // session as transient (e.g. relay restart during reconnect).
  static const int _recentRelayAuthorityGraceMs = 30000;
  // How long a connectivity-recovery event suppresses relay-miss termination.
  // Extended from 15s → 45s because mobile handoffs can take longer.
  static const int _recentConnectivityRecoveryRelayGraceMs = 45000;
  static const int _relayReconnectRecoveryThrottleMs = 1500;
  static const int _connectivityRecoveryThrottleMs = 400;
  static const Duration _fastRelayReconcileBudget = Duration(milliseconds: 250);
  static const Duration _connectivityRestoreRecoveryDelay = Duration(
    milliseconds: 200,
  );
  static const Duration _connectivityHandoffRecoveryDelay = Duration(
    milliseconds: 300,
  );
  static const Duration _connectivityLateRecoveryDelay = Duration(
    milliseconds: 800,
  );
  static const Duration _queuedConnectivityHandoffRecoveryDelay = Duration(
    milliseconds: 150,
  );
  static const Duration _mobileInitialConnectAssistDelay = Duration(
    milliseconds: 3200,
  );
  static const Duration _mobileInitialConnectAssistFollowUpDelay = Duration(
    milliseconds: 4200,
  );
  static const int _maxMobileInitialConnectAssistAttempts = 2;
  static const int _maxConnectivityFollowUpRecoveryAttempts = 2;

  // ── Global NavigatorKey (set from main.dart) ───────────────────────────
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Global instance — set from main.dart after creation.
  static CallManager? instance;

  static bool shouldIgnoreIncomingOffer({
    required CallPhase phase,
    required bool awaitingRemoteAnswer,
  }) {
    if (phase == CallPhase.ringingOutgoing) return true;
    if (!awaitingRemoteAnswer) return false;
    return phase != CallPhase.connected && phase != CallPhase.reconnecting;
  }

  static bool shouldResolveOfferGlareInActiveCall({
    required CallPhase phase,
    required bool awaitingRemoteAnswer,
  }) {
    if (!awaitingRemoteAnswer) return false;
    return phase == CallPhase.connected || phase == CallPhase.reconnecting;
  }

  /// Perfect-negotiation polite/impolite designation.
  ///
  /// When both peers create local offers simultaneously (offer/offer glare
  /// after a network change or PC FAILED), one side must yield. The polite
  /// peer rolls back its local offer and accepts the remote offer; the
  /// impolite peer ignores the remote offer and keeps its own.
  ///
  /// Designation is fully deterministic so both peers always agree:
  /// lexicographically smaller profileId == polite.
  static bool isPoliteFor({
    required String localProfileId,
    required String remoteProfileId,
  }) {
    if (localProfileId.isEmpty || remoteProfileId.isEmpty) {
      // Without both IDs we cannot guarantee a deterministic tiebreak; fall
      // back to "polite" so we accept the remote offer (safer than ignoring).
      return true;
    }
    return localProfileId.compareTo(remoteProfileId) < 0;
  }

  static bool shouldApplyRemoteAnswer({
    required bool awaitingRemoteAnswer,
    required bool hasRemoteDescription,
    required bool hasPendingLocalOffer,
  }) {
    return awaitingRemoteAnswer ||
        !hasRemoteDescription ||
        hasPendingLocalOffer;
  }

  static bool shouldSuppressDuplicateLocalOfferSend({
    required String previousCallId,
    required String previousCallAttemptId,
    required String previousFingerprint,
    required int previousSentAtMs,
    required String callId,
    required String callAttemptId,
    required String sdp,
    required int nowMs,
  }) {
    if (previousFingerprint.isEmpty || previousCallId.isEmpty) {
      return false;
    }
    final effectiveAttemptId = callAttemptId.isEmpty ? callId : callAttemptId;
    final previousEffectiveAttemptId = previousCallAttemptId.isEmpty
        ? previousCallId
        : previousCallAttemptId;
    if (previousCallId != callId ||
        previousEffectiveAttemptId != effectiveAttemptId) {
      return false;
    }
    final fingerprint = '${sdp.length}:${sdp.hashCode}';
    if (fingerprint != previousFingerprint) {
      return false;
    }
    return nowMs - previousSentAtMs < 1500;
  }

  static bool shouldRestartConnectingForIncomingOffer(CallPhase phase) {
    return phase != CallPhase.connected && phase != CallPhase.reconnecting;
  }

  static bool shouldBufferIncomingOfferUntilExplicitAccept(CallPhase phase) {
    return phase == CallPhase.ringingIncoming;
  }

  static double incomingRingtoneVolumeForSetting(String setting) {
    switch (setting.trim().toLowerCase()) {
      case 'beacon':
      case 'chime':
      case 'default':
      default:
        return 1.0;
    }
  }

  @visibleForTesting
  static bool shouldStartConnectingToneForRemoteAnswer({
    required CallPhase phase,
  }) {
    return phase == CallPhase.ringingOutgoing ||
        phase == CallPhase.ringingIncoming;
  }

  static bool shouldDeferNeedOfferDuringOutgoingBootstrap({
    required CallPhase phase,
    required bool outgoingOfferBootstrapInFlight,
  }) {
    if (!outgoingOfferBootstrapInFlight) {
      return false;
    }
    return phase == CallPhase.ringingOutgoing || phase == CallPhase.connecting;
  }

  static bool shouldKeepNeedOfferRetriesRunning({
    required CallPhase phase,
    required bool isActive,
    required bool hasPendingOffer,
    required bool awaitingRecoveryOffer,
  }) {
    if (!isActive || hasPendingOffer) {
      return false;
    }
    if (phase == CallPhase.connecting) {
      return true;
    }
    return phase == CallPhase.reconnecting && awaitingRecoveryOffer;
  }

  static bool shouldTerminateAfterMissingRelaySession({
    required CallPhase phase,
    required int consecutiveMisses,
    required bool wasEverConnected,
    bool recentConnectivityRecovery = false,
    bool pendingConnectivityRecovery = false,
  }) {
    if (consecutiveMisses < _missingRelaySessionTerminationThreshold) {
      return false;
    }
    if (recentConnectivityRecovery || pendingConnectivityRecovery) {
      return false;
    }
    if (phase == CallPhase.reconnecting) {
      return true;
    }
    return phase == CallPhase.connecting && wasEverConnected;
  }

  static int computeAutoRestartIceDelayMs({
    required int attemptNumber,
    required bool wasEverConnected,
    bool preferHardRecovery = false,
  }) {
    if (attemptNumber <= 0) {
      return 0;
    }
    if (wasEverConnected && preferHardRecovery) {
      return 200 * (attemptNumber - 1);
    }
    // Even for first connect failures we prefer fast retry: 0ms on attempt 1,
    // then mild ramp. Top-tier apps recover within hundreds of ms on mobile.
    if (preferHardRecovery) {
      return 150 * (attemptNumber - 1);
    }
    return 600 * attemptNumber;
  }

  static int? computeRelayReconcileBudgetMs({
    required bool wasEverConnected,
    bool preferHardRecovery = false,
  }) {
    if (preferHardRecovery && wasEverConnected) {
      return _fastRelayReconcileBudget.inMilliseconds;
    }
    return null;
  }

  static bool shouldTreatMissingRelaySessionAsTransient({
    required String callId,
    required String callAttemptId,
    required String lastObservedCallId,
    required String lastObservedCallAttemptId,
    required String lastObservedState,
    required int lastObservedAtMs,
    required int nowMs,
  }) {
    if (lastObservedAtMs <= 0) {
      return false;
    }
    final normalizedCallId = callId.trim();
    final normalizedAttemptId = callAttemptId.trim().isNotEmpty
        ? callAttemptId.trim()
        : normalizedCallId;
    final normalizedLastCallId = lastObservedCallId.trim();
    final normalizedLastAttemptId = lastObservedCallAttemptId.trim().isNotEmpty
        ? lastObservedCallAttemptId.trim()
        : normalizedLastCallId;
    if (normalizedCallId.isEmpty ||
        normalizedCallId != normalizedLastCallId ||
        normalizedAttemptId != normalizedLastAttemptId) {
      return false;
    }
    final ageMs = nowMs - lastObservedAtMs;
    if (ageMs < 0 || ageMs > _recentRelayAuthorityGraceMs) {
      return false;
    }
    return lastObservedState == 'ringing' ||
        lastObservedState == 'accepted' ||
        lastObservedState == 'reconnecting';
  }

  static bool shouldPromoteConnectingFromRelayAccepted({
    required CallDirection direction,
    required CallPhase phase,
    required RelayCallSessionSnapshot snapshot,
  }) {
    return direction == CallDirection.outgoing &&
        phase == CallPhase.ringingOutgoing &&
        snapshot.state == 'accepted';
  }

  static bool shouldPromoteReconnectingFromRelay({
    required CallPhase phase,
    required bool wasEverConnected,
    required RelayCallSessionSnapshot snapshot,
    RTCPeerConnectionState? rtcState,
    RTCIceConnectionState? iceState,
    bool mediaEstablished = false,
  }) {
    if (shouldPromoteConnectedFromSession(
      phase: phase,
      wasEverConnected: wasEverConnected,
      rtcState: rtcState,
      iceState: iceState,
      mediaEstablished: mediaEstablished,
    )) {
      return false;
    }
    if (phase == CallPhase.reconnecting) {
      return false;
    }
    final relayRequestsRecovery =
        snapshot.state == 'reconnecting' || snapshot.lastAction == 'need_offer';
    if (!relayRequestsRecovery) {
      return false;
    }
    if (phase == CallPhase.connected) {
      return true;
    }
    return phase == CallPhase.connecting && wasEverConnected;
  }

  static bool shouldRecoverOfferProcessingFailure({
    required CallPhase phase,
    required bool wasEverConnected,
  }) {
    if (phase == CallPhase.connected || phase == CallPhase.reconnecting) {
      return true;
    }
    return phase == CallPhase.connecting && wasEverConnected;
  }

  static bool shouldPromoteConnectedFromSession({
    required CallPhase phase,
    required bool wasEverConnected,
    required RTCPeerConnectionState? rtcState,
    required RTCIceConnectionState? iceState,
    required bool mediaEstablished,
  }) {
    final rtcConnected =
        rtcState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
    final iceConnected =
        iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted;
    final transportConnected = rtcConnected || iceConnected;
    if (phase != CallPhase.connecting &&
        phase != CallPhase.connected &&
        phase != CallPhase.reconnecting) {
      return false;
    }
    if (!transportConnected) {
      return false;
    }
    // For a call that was already live, transport recovery is enough to leave
    // reconnecting. Waiting for media stats can stall the UI for seconds after
    // a brief network blip even though ICE/DTLS already recovered.
    if (phase == CallPhase.reconnecting && wasEverConnected) {
      return true;
    }
    return mediaEstablished;
  }

  static bool hasTransportFailureState({
    required RTCPeerConnectionState? rtcState,
    required RTCIceConnectionState? iceState,
  }) {
    return rtcState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateFailed;
  }

  static bool hasTransportDisconnectionState({
    required RTCPeerConnectionState? rtcState,
    required RTCIceConnectionState? iceState,
  }) {
    if (hasTransportFailureState(rtcState: rtcState, iceState: iceState)) {
      return false;
    }
    return rtcState ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateDisconnected;
  }

  static bool shouldAttemptTransportRecoveryOnRelayReconnect({
    required CallPhase phase,
    required bool wasEverConnected,
    required RTCPeerConnectionState? rtcState,
    required RTCIceConnectionState? iceState,
    required bool mediaEstablished,
  }) {
    if (shouldPromoteConnectedFromSession(
      phase: phase,
      wasEverConnected: wasEverConnected,
      rtcState: rtcState,
      iceState: iceState,
      mediaEstablished: mediaEstablished,
    )) {
      return false;
    }
    if (phase == CallPhase.reconnecting || phase == CallPhase.connected) {
      return true;
    }
    return phase == CallPhase.connecting && wasEverConnected;
  }

  static bool shouldUseFreshTransportRecovery({
    required CallPhase phase,
    required bool wasEverConnected,
    required bool isVideo,
    required bool isCameraOff,
    required bool isScreenSharing,
    required int priorIceRestartAttempts,
    bool preferHardRecovery = false,
  }) {
    if (phase != CallPhase.connected && phase != CallPhase.reconnecting) {
      return false;
    }
    if (!wasEverConnected || isScreenSharing) {
      return false;
    }
    // A hard rebuild currently reboots local capture. Avoid it while a video
    // call intentionally has camera capture disabled until a recvonly-style
    // recovery path exists.
    if (isVideo && isCameraOff) {
      return false;
    }
    // For video calls prefer in-place ICE restart to avoid stopping and
    // restarting the camera (causes visible flicker on Android). Only escalate
    // to a full session rebuild after 4+ consecutive failures.
    if (isVideo) {
      return priorIceRestartAttempts >= 4;
    }
    return preferHardRecovery || priorIceRestartAttempts >= 2;
  }

  static bool hasUsableConnectivity(
    List<ConnectivityResult> connectivityResults,
  ) {
    for (final result in connectivityResults) {
      if (result != ConnectivityResult.none) {
        return true;
      }
    }
    return false;
  }

  static bool hasConnectivityPathChanged({
    required List<ConnectivityResult> previousResults,
    required List<ConnectivityResult> currentResults,
  }) {
    final previous = previousResults
        .where((result) => result != ConnectivityResult.none)
        .toSet();
    final current = currentResults
        .where((result) => result != ConnectivityResult.none)
        .toSet();
    if (previous.isEmpty || current.isEmpty) {
      return false;
    }
    if (previous.length != current.length) {
      return true;
    }
    for (final result in previous) {
      if (!current.contains(result)) {
        return true;
      }
    }
    return false;
  }

  static List<ConnectivityResult> connectivityResultsFromNativePathEvent(
    Object? event,
  ) {
    if (event is! Map) {
      return const <ConnectivityResult>[];
    }
    final available = event['available'] == true;
    final rawTransports = event['transports'];
    final transports = rawTransports is Iterable
        ? rawTransports
              .map((value) => value.toString().trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toSet()
        : <String>{};
    if (!available || transports.isEmpty) {
      return const <ConnectivityResult>[ConnectivityResult.none];
    }
    final results = <ConnectivityResult>{};
    for (final transport in transports) {
      switch (transport) {
        case 'wifi':
          results.add(ConnectivityResult.wifi);
        case 'cellular':
        case 'mobile':
          results.add(ConnectivityResult.mobile);
        case 'ethernet':
        case 'wired':
          results.add(ConnectivityResult.ethernet);
        case 'vpn':
          results.add(ConnectivityResult.vpn);
        case 'bluetooth':
          results.add(ConnectivityResult.bluetooth);
        default:
          results.add(ConnectivityResult.other);
      }
    }
    return results.isEmpty
        ? const <ConnectivityResult>[ConnectivityResult.none]
        : List<ConnectivityResult>.unmodifiable(results);
  }

  static bool shouldAttemptTransportRecoveryOnConnectivityChange({
    required CallPhase phase,
    required bool wasEverConnected,
    required bool hasUsableConnectivity,
    required bool connectivityRestored,
    required bool connectivityPathChanged,
  }) {
    if (!hasUsableConnectivity) {
      return false;
    }
    if (!connectivityRestored && !connectivityPathChanged) {
      return false;
    }
    if (phase == CallPhase.connected || phase == CallPhase.reconnecting) {
      return true;
    }
    return phase == CallPhase.connecting && wasEverConnected;
  }

  static bool shouldScheduleConnectivityFollowUpRecovery({
    required bool connectivityRestored,
    required bool connectivityPathChanged,
  }) {
    return connectivityRestored || connectivityPathChanged;
  }

  static bool shouldScheduleAdditionalConnectivityFollowUpRecovery({
    required CallPhase phase,
    required bool wasEverConnected,
    required RTCPeerConnectionState? rtcState,
    required RTCIceConnectionState? iceState,
    required bool mediaEstablished,
    required bool hasUsableConnectivity,
    required int attemptsSoFar,
  }) {
    if (!hasUsableConnectivity) {
      return false;
    }
    if (attemptsSoFar >= _maxConnectivityFollowUpRecoveryAttempts) {
      return false;
    }
    return shouldAttemptTransportRecoveryOnRelayReconnect(
      phase: phase,
      wasEverConnected: wasEverConnected,
      rtcState: rtcState,
      iceState: iceState,
      mediaEstablished: mediaEstablished,
    );
  }

  bool get _supportsNativeCallUiPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static String? validateIceConfigForSession(CallIceConfigSnapshot iceConfig) {
    // After augmentation with fallback STUN, a config without servers is only
    // rejected if it has relay_only policy with no TURN servers.
    if (iceConfig.policy == CallNetworkPolicy.relayOnly &&
        !iceConfig.hasUsableRelayServers) {
      return 'relay_only policy active but no usable TURN servers are available';
    }
    return null;
  }

  /// Injects fallback STUN servers into [iceConfig] when the relay has not
  /// configured any ICE servers. This ensures cross-network calls can at least
  /// attempt srflx candidate gathering; a TURN server is still required for
  /// calls behind symmetric NAT or strict firewalls.
  static CallIceConfigSnapshot _augmentIceConfigWithFallback(
    CallIceConfigSnapshot iceConfig, {
    required Uri relayBaseUrl,
  }) {
    if (iceConfig.hasConfiguredIceServers) return iceConfig;
    final fallback = fallbackStunServersFor(relayBaseUrl);
    callLog(
      'CallManager',
      'relay returned no ICE servers — falling back to '
          '${fallback.isEmpty ? 'host candidates only' : 'STUN on the relay host'}; '
          'configure SECRETLY_RELAY_ICE_STUN_URLS / SECRETLY_RELAY_ICE_TURN_URLS '
          'on the relay for production use',
    );
    return CallIceConfigSnapshot(
      policy: iceConfig.policy == CallNetworkPolicy.relayOnly
          ? CallNetworkPolicy.p2pPreferred
          : iceConfig.policy,
      iceServers: fallback,
      expiresAtMs: iceConfig.expiresAtMs,
    );
  }

  static RemoteVideoRecoveryStep selectRemoteVideoRecoveryStep({
    required RemoteVideoFailureReason reason,
    required int attemptsSoFar,
  }) {
    switch (reason) {
      case RemoteVideoFailureReason.waitingForTrackTimeout:
        if (attemptsSoFar == 0) {
          return RemoteVideoRecoveryStep.renegotiate;
        }
        if (attemptsSoFar == 1) {
          return RemoteVideoRecoveryStep.restartIce;
        }
        return RemoteVideoRecoveryStep.failCall;
      case RemoteVideoFailureReason.rendererBindingTimeout:
        if (attemptsSoFar == 0) {
          return RemoteVideoRecoveryStep.reattachRenderer;
        }
        if (attemptsSoFar == 1) {
          return RemoteVideoRecoveryStep.restartIce;
        }
        if (attemptsSoFar == 2) {
          return RemoteVideoRecoveryStep.renegotiate;
        }
        return RemoteVideoRecoveryStep.failCall;
      case RemoteVideoFailureReason.rendererNoFrames:
        if (attemptsSoFar == 0) {
          return RemoteVideoRecoveryStep.reattachRenderer;
        }
        if (attemptsSoFar == 1) {
          return RemoteVideoRecoveryStep.restartIce;
        }
        if (attemptsSoFar == 2) {
          return RemoteVideoRecoveryStep.renegotiate;
        }
        return RemoteVideoRecoveryStep.failCall;
    }
  }

  static CallEndReason? relayTerminalEndReason(
    RelayCallSessionSnapshot snapshot,
  ) {
    if (!(snapshot.isEnded ||
        snapshot.lastAction == 'superseded' ||
        snapshot.lastAction == 'hangup' ||
        snapshot.lastAction == 'decline')) {
      return null;
    }
    if (snapshot.lastAction == 'decline') {
      return CallEndReason.remoteDecline;
    }
    if (snapshot.lastAction == 'timeout') {
      return CallEndReason.timeout;
    }
    if (snapshot.lastAction == 'superseded') {
      return CallEndReason.remoteSuperseded;
    }
    return CallEndReason.remoteHangup;
  }

  static bool shouldRequestOfferRecoveryFromRelay({
    required CallDirection direction,
    required CallPhase phase,
    required bool awaitingRemoteOfferLocally,
    required RelayCallSessionSnapshot snapshot,
  }) {
    if (direction != CallDirection.incoming || !awaitingRemoteOfferLocally) {
      return false;
    }
    if (phase == CallPhase.connecting) {
      return true;
    }
    if (phase != CallPhase.reconnecting) {
      return false;
    }
    return snapshot.state == 'accepted' ||
        snapshot.state == 'reconnecting' ||
        snapshot.lastAction == 'offer' ||
        snapshot.lastAction == 'need_offer';
  }

  static bool shouldResendOfferRecoveryFromRelay({
    required CallDirection direction,
    required CallPhase phase,
    required bool awaitingRemoteAnswerLocally,
    required RelayCallSessionSnapshot snapshot,
  }) {
    if (direction != CallDirection.outgoing) {
      return false;
    }
    if (snapshot.state == 'accepted' &&
        (phase == CallPhase.reconnecting ||
            (awaitingRemoteAnswerLocally &&
                (phase == CallPhase.ringingOutgoing ||
                    phase == CallPhase.connecting)))) {
      return true;
    }
    return direction == CallDirection.outgoing &&
        (snapshot.state == 'reconnecting' ||
            snapshot.lastAction == 'need_offer');
  }

  static bool shouldHandleIncomingNeedOffer({
    required CallDirection direction,
    required CallPhase phase,
  }) {
    if (direction != CallDirection.outgoing) {
      return false;
    }
    return phase == CallPhase.ringingOutgoing ||
        phase == CallPhase.connecting ||
        phase == CallPhase.connected ||
        phase == CallPhase.reconnecting;
  }

  static bool shouldAcceptNativeCallAction({
    required String currentCallId,
    required String currentCallAttemptId,
    required String actionCallId,
    required String actionCallAttemptId,
  }) {
    if (actionCallId.isEmpty || currentCallId != actionCallId) {
      return false;
    }
    final expectedAttemptId = currentCallAttemptId.isNotEmpty
        ? currentCallAttemptId
        : currentCallId;
    final normalizedActionAttemptId = actionCallAttemptId.isNotEmpty
        ? actionCallAttemptId
        : actionCallId;
    return expectedAttemptId == normalizedActionAttemptId;
  }

  static bool shouldBufferNativeCallActionWithoutState({
    required String currentCallId,
    required String action,
  }) {
    if (currentCallId.isNotEmpty) return false;
    return action == 'accept' || action == 'decline';
  }

  /// A tap on the BODY of the incoming-call notification, for a call this
  /// isolate has never heard of — the cold start: the ring was posted by the
  /// native FCM service while Flutter wasn't running.
  ///
  /// Deliberately NOT part of [shouldBufferNativeCallActionWithoutState]: a tap
  /// is not a decision and must never queue up as one. Buffering it would also
  /// let it overwrite a real accept/decline in that single-slot buffer. What it
  /// warrants instead is ADOPTION of the ring — see [_adoptNativeIncomingRing].
  ///
  /// `restore` is excluded: it comes from the ongoing-call notification, which
  /// implies a live call, so adopting it as an incoming ring would seed a
  /// notification id that was never posted.
  static bool shouldAdoptNativeIncomingRingWithoutState({
    required String currentCallId,
    required String action,
  }) {
    if (currentCallId.isNotEmpty) return false;
    return action == 'tap';
  }

  static bool shouldAcceptSignalForCurrentCall({
    required String currentCallId,
    required String currentCallAttemptId,
    required String signalCallId,
    required String signalCallAttemptId,
  }) {
    if (signalCallId.isEmpty || currentCallId != signalCallId) {
      return false;
    }
    final expectedAttemptId = currentCallAttemptId.isNotEmpty
        ? currentCallAttemptId
        : currentCallId;
    final normalizedSignalAttemptId = signalCallAttemptId.isNotEmpty
        ? signalCallAttemptId
        : signalCallId;
    return expectedAttemptId == normalizedSignalAttemptId;
  }

  static bool shouldIgnoreInviteForCurrentCall({
    required String currentCallId,
    required String currentCallAttemptId,
    required String inviteCallId,
    required String inviteCallAttemptId,
  }) {
    return shouldAcceptSignalForCurrentCall(
      currentCallId: currentCallId,
      currentCallAttemptId: currentCallAttemptId,
      signalCallId: inviteCallId,
      signalCallAttemptId: inviteCallAttemptId,
    );
  }

  /// Помечает попытку звонка завершённой, чтобы опоздавшее приглашение по ней
  /// не подняло звонок. Тот же список, что гасит протухшие подсказки.
  void _rememberEndedCallAttempt({
    required String callId,
    required String callAttemptId,
    required String reason,
  }) {
    final key = endedCallAttemptKey(
      callId: callId,
      callAttemptId: callAttemptId,
    );
    if (key.isEmpty || _lastEndedCallAttemptKeys.contains(key)) return;
    _lastEndedCallAttemptKeys.add(key);
    while (_lastEndedCallAttemptKeys.length > _maxEndedCallAttemptKeysKept) {
      _lastEndedCallAttemptKeys.remove(_lastEndedCallAttemptKeys.first);
    }
    callOpLog(
      'CallManager',
      'call_attempt_marked_ended',
      fields: <String, Object?>{'callId': callId, 'reason': reason},
    );
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setStringList(
            _prefKeyEndedCallAttemptKeys,
            _lastEndedCallAttemptKeys.toList(),
          );
        })
        .catchError((_) {});
  }

  static String endedCallAttemptKey({
    required String callId,
    required String callAttemptId,
  }) {
    final normalizedCallId = callId.trim();
    if (normalizedCallId.isEmpty) {
      return '';
    }
    final normalizedAttemptId = callAttemptId.trim().isNotEmpty
        ? callAttemptId.trim()
        : normalizedCallId;
    return '$normalizedCallId::$normalizedAttemptId';
  }

  static bool shouldSuppressSignalForEndedCallAttempt({
    required Set<String> endedCallAttemptKeys,
    required String signalCallId,
    required String signalCallAttemptId,
  }) {
    return endedCallAttemptKeys.contains(
      endedCallAttemptKey(
        callId: signalCallId,
        callAttemptId: signalCallAttemptId,
      ),
    );
  }

  bool _transitionLifecycle(
    CallLifecycleEvent event, {
    String source = '',
    CallEndReason? endReason,
    int? connectedAtMs,
  }) {
    final current = state.value;
    final next = reduceCallLifecycle(
      current: current.lifecycle,
      event: event,
      wasEverConnected: current.connectedAtMs != null,
    );
    if (next == null) {
      callLog(
        'CallManager',
        'fsm rejected event=${event.name} lifecycle=${current.lifecycle.name} phase=${current.phase.name} source=$source',
      );
      return false;
    }
    final nextPhase = callPhaseForLifecycle(next);
    final clearFailure =
        nextPhase != CallPhase.ended || endReason != CallEndReason.error;
    if (next != current.lifecycle ||
        nextPhase != current.phase ||
        connectedAtMs != null ||
        endReason != null ||
        (clearFailure && current.failure != null)) {
      state.value = current.copyWith(
        lifecycle: next,
        phase: nextPhase,
        connectedAtMs: connectedAtMs ?? current.connectedAtMs,
        endReason: endReason ?? current.endReason,
        clearFailure: clearFailure,
      );
      callLog(
        'CallManager',
        'fsm transition ${current.lifecycle.name} -> ${next.name} event=${event.name} source=$source',
      );
      final updated = state.value;
      if (updated.phase == CallPhase.connecting &&
          updated.connectedAtMs == null) {
        _scheduleMobileInitialConnectAssist(
          reason: source.isEmpty ? event.name : source,
        );
      } else if (updated.phase != CallPhase.connecting ||
          updated.connectedAtMs != null) {
        _cancelMobileInitialConnectAssist(
          resetAttempt:
              updated.phase == CallPhase.ended || updated.connectedAtMs != null,
        );
      }
    }
    return true;
  }

  CallLifecycleEvent _endLifecycleEvent(CallEndReason reason) {
    switch (reason) {
      case CallEndReason.localHangup:
        return CallLifecycleEvent.localHangup;
      case CallEndReason.remoteHangup:
      case CallEndReason.remoteSuperseded:
        return CallLifecycleEvent.remoteHangup;
      case CallEndReason.remoteDecline:
        return CallLifecycleEvent.remoteDecline;
      case CallEndReason.timeout:
        return state.value.isRinging
            ? CallLifecycleEvent.ringTimeout
            : CallLifecycleEvent.connectTimeout;
      case CallEndReason.error:
        return CallLifecycleEvent.fatalError;
      case CallEndReason.localDecline:
        return CallLifecycleEvent.localDecline;
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  // Per-signal timeout so a single stuck handler (e.g. relay send on a frozen
  // connection) cannot block ALL subsequent signals for the full 4-minute
  // reconnect watchdog window. 30 s is generous enough for slow relays but
  // short enough to unblock ICE-candidate / hangup signals that must flow
  // even while an offer round-trip is in progress.
  static const Duration _signalProcessingTimeout = Duration(seconds: 30);

  // AUD-025: enqueue a signal onto the serial processing chain. Duplicate
  // signalIds are dropped so the buffered replay path cannot re-deliver a
  // signal that the live subscription already picked up.
  void _enqueueSignal(CallSignalEvent sig) {
    // Звонок начался (с любой стороны) — просим фоновое обслуживание уступить
    // дорогу к серверу ключей: бакет считается по IP и делится между всеми
    // устройствами за одним Wi-Fi. Подробности — в `markCallPriorityWindow`.
    controller.markCallPriorityWindow();
    final id = sig.signalId.trim();
    if (id.isNotEmpty) {
      if (_processedSignalIds.contains(id)) {
        return;
      }
      _processedSignalIds.add(id);
      if (_processedSignalIds.length > _processedSignalIdCapacity) {
        _processedSignalIds.remove(_processedSignalIds.first);
      }
    }
    _signalProcessingChain = _signalProcessingChain
        .then(
          (_) => _onSignal(sig).timeout(
            _signalProcessingTimeout,
            onTimeout: () {
              callLog(
                'CallManager',
                'signal_processing_timeout action=${sig.action}',
              );
            },
          ),
        )
        .catchError((_) {});
  }

  void start() {
    // ПРОГРЕВ КОНФИГУРАЦИИ ICE (22.08.2026).
    //
    // Кэш ICE живёт только в памяти, поэтому на холодном старте его нет, а
    // звонок на убитом приложении случается ровно там: приняли трубку —
    // приложение поднялось — сессия создаётся через секунду. Без прогрева
    // TURN пришлось бы запрашивать ПРЯМО в этот момент, то есть на самой
    // неудачной секунде и, если сеть плохая, до таймаута.
    //
    // Запрос без ожидания: он либо успеет к сессии (обычный случай), либо
    // сессия сама сходит за конфигурацией — с починенным `isExpired` она это
    // теперь делает. Отказ гасится собственным откатом внутри контроллера.
    unawaited(
      controller.getCallIceConfig().then(
        (_) {},
        onError: (Object _) {},
      ),
    );
    _signalSub?.cancel();
    // Subscribe first so signals dispatched after we drain the buffer below
    // are captured. The enqueue helper preserves order with buffered replay.
    _signalSub = controller.callSignals.listen(_enqueueSignal);
    _relayConnectionSub?.cancel();
    _relayConnectionSub = controller.relayConnectionChanges.listen(
      _onRelayConnectionChanged,
    );
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) => unawaited(_handleConnectivityChanged(results)),
      onError: (_) {},
    );
    _nativeNetworkPathSub?.cancel();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // Общий поток: свой `receiveBroadcastStream()` отнимал события у
      // приложения (N-2, `NativeNetworkPath`).
      _nativeNetworkPathSub = NativeNetworkPath.events.listen(
        _onNativeNetworkPathEvent,
        onError: (_) {},
      );
    }
    Connectivity()
        .checkConnectivity()
        .then((results) {
          _lastConnectivityResults = List<ConnectivityResult>.unmodifiable(
            results,
          );
        })
        .catchError((_) {});
    // Restore persisted ended-call IDs so ghost calls are filtered even after
    // the app restarts within the relay's 90 s delivery window.
    SharedPreferences.getInstance()
        .then((prefs) {
          final saved = prefs.getStringList(_prefKeyEndedCallAttemptKeys);
          if (saved != null) _lastEndedCallAttemptKeys.addAll(saved);
        })
        .catchError((_) {});
    _nativeCallActionSub?.cancel();
    if (_supportsNativeCallUiPlatform) {
      _nativeCallActionSub = _nativeCallActionsChannel
          .receiveBroadcastStream()
          .listen(_onNativeCallAction, onError: (_) {});
    }
    // Android 14+: check USE_FULL_SCREEN_INTENT so the UI can warn the user
    // if incoming calls won't appear when the app is killed.
    if (defaultTargetPlatform == TargetPlatform.android) {
      _nativeCallUiChannel
          .invokeMethod<bool>('canUseFullScreenIntent')
          .then((granted) {
            fullScreenIntentGranted.value = granted ?? true;
          })
          .catchError((_) {});
      unawaited(drainMissedCallTrail());
    }
    // Drain signals that arrived during AppController.init() before
    // CallManager subscribed (broadcast stream has no buffer).
    // Signals older than 60 s are stale and must be discarded to prevent
    // ghost calls after reconnects / app restarts.
    // AUD-025: Drain after subscribe and route buffered signals through the
    // same serial queue as live signals. Ordering is preserved because
    // enqueue is synchronous; dedup by signalId prevents double-processing
    // for events that raced with subscribe().
    final buffered = controller.drainCallSignalBuffer();
    if (buffered.isNotEmpty) {
      callLog(
        'CallManager',
        '[OP] event=call_signal_buffer_drain count=${buffered.length}',
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final sig in buffered) {
        final ageMs = nowMs - sig.createdAtMs;
        // 🔴 AGE MAY ONLY SILENCE A SIGNAL THAT STARTS OR ADVANCES A CALL —
        // NEVER ONE THAT ENDS IT (2026-07-31).
        //
        // This filter was written to prevent ghost calls. For a terminal signal
        // it CREATES them: the caller cancels, our app is suspended so nothing
        // processes it, and by the time we drain the buffer the cancel is "too
        // old" and gets thrown away — while the ringing UI it was meant to
        // dismiss is exactly what stays on screen. That is the phantom call the
        // user reported.
        //
        // A late `hangup` is never harmful: if the call already ended it is a
        // no-op (each branch checks the current phase), and if it has not, it is
        // the only thing that can end it. The live signal path already draws
        // this line — it age-gates `invite` and `offer` and never a hangup;
        // only this startup drain treated every action alike.
        if (ageMs > 60000 && !isTerminalCallSignalAction(sig.action)) {
          callLog(
            'CallManager',
            '[OP] dropping stale buffered signal action=${sig.action} age=${ageMs}ms',
          );
          continue;
        }
        _enqueueSignal(sig);
      }
    }

    // Очередь, записанная ФОНОВЫМ изолятом — см. `drainPersistedCallSignalQueue`.
    // `start` синхронный, поэтому вдогонку: чтение базы не имеет права задержать
    // подписку на живые сигналы.
    unawaited(drainPersistedCallSignalQueue());
  }

  /// 🔴 СИГНАЛЫ ЗВОНКА, ПРИНЯТЫЕ ФОНОВЫМ ИЗОЛЯТОМ (14.08.2026).
  ///
  /// ЗАМЕР, звонок `d41fdf11`: приглашение и предложение приехали за ТРИ СЕКУНДЫ
  /// до того, как человек нажал «Принять», — но в фоновый изолят. Он их
  /// расшифровал, применил, подтвердил реле (`applied=11 acked=11`) и тем
  /// очистил ящик. Разложил он их в буфер в ОЗУ СВОЕГО изолята, а `start()`
  /// вычерпывает буфер СВОЕГО. Главный изолят поднялся через три секунды на
  /// пустой ящик (`outcome=empty`) и о звонке не узнал никогда: `phase=idle`
  /// вплоть до отбоя, экран пустой.
  ///
  /// Звонок был доставлен на устройство и потерян ВНУТРИ устройства.
  ///
  /// Очередь в базе — единственное, что переживает смерть изолята. Обработка та
  /// же самая (`_enqueueSignal`), поэтому дедуп по `signalId`, разрешение
  /// двойного звонка и все проверки фазы работают без изменений.
  ///
  /// Зовётся из [start] и на возобновлении приложения: `start` выполняется один
  /// раз за жизнь изолята, а процесс переживает смахивание из недавних — тот же
  /// урок, что со следом пропущенных 08.08.
  Future<void> drainPersistedCallSignalQueue() async {
    if (_persistedSignalDrainInFlight) return;
    _persistedSignalDrainInFlight = true;
    try {
      final events = await controller.drainPersistedCallSignals();
      if (events.isEmpty) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final sig in events) {
        final ageMs = nowMs - sig.createdAtMs;
        // 🔴 ВОЗРАСТ ГЛУШИТ ТОЛЬКО ТО, ЧТО НАЧИНАЕТ ИЛИ ПРОДВИГАЕТ ЗВОНОК, И
        // НИКОГДА ТО, ЧТО ЕГО ЗАВЕРШАЕТ (шрам 31.07). Выброшенный отбой
        // оставляет на экране ровно ту звонящую плашку, которую он был обязан
        // погасить.
        if (ageMs > 60000 && !isTerminalCallSignalAction(sig.action)) {
          callLog(
            'CallManager',
            '[OP] dropping stale queued signal action=${sig.action} age=${ageMs}ms',
          );
          continue;
        }
        _enqueueSignal(sig);
      }
    } catch (e) {
      callLog('CallManager', 'persisted call signal drain failed: $e');
    } finally {
      _persistedSignalDrainInFlight = false;
    }
  }

  /// Забирает у натива след о звонках, которые прозвонили при УБИТОЙ Activity,
  /// и пишет по ним пропущенные.
  ///
  /// 🔴 ЗАЧЕМ (07.08.2026, поле: «на Андроид только в шторке, в чате информации
  /// о неотвеченом вызове нет»). Запись в ленту чата умеет писать только
  /// [_endCall], а он требует, чтобы Dart обработал приглашение. Когда Activity
  /// убита, приглашение обрабатывает FCM-служба, Dart о звонке не узнаёт
  /// никогда, и в чате не остаётся ничего. Этот след — единственный мост через
  /// ту пропасть.
  ///
  /// 🔴 ПОЧЕМУ ИСХОД `timeout`, А НЕ `remoteHangup`. Мы знаем ровно одно:
  /// плашка прозвонила, и человек её не отработал. Кто оборвал звонок —
  /// звонивший или таймаут — из следа неизвестно. Для входящего `timeout` даёт
  /// `missed` и не притворяется знанием, которого у нас нет.
  ///
  /// 🔴 ПОЧЕМУ ПОВТОРА НЕ БУДЕТ. Натив снимает след при «Принять» и «Отклонить»
  /// (`MissedCallTrail.remove`), а если звонок всё же успел пройти через Dart —
  /// у [AppController.recordCallOutcome] свой дедуп по попытке.
  /// 🔴 ЗОВЁТСЯ НЕ ТОЛЬКО ИЗ [start] (08.08.2026, найдено ПО ЛОГУ ПОЛЕВОГО
  /// ТЕСТА: `missed_call_trail_drained` не появилось ни разу).
  ///
  /// [start] выполняется РОВНО ОДИН РАЗ за жизнь изолята — при создании
  /// `CallManager` в main.dart. А процесс на MIUI переживает смахивание из
  /// недавних: Activity убита, изолят жив. Тогда плашку показывает FCM-служба,
  /// след пишется, человек открывает приложение — и вычерпывать некому, потому
  /// что `start` давно отработал. Пропущенный не появлялся бы вовсе, то есть
  /// вся Э-2 не работала бы ровно в том сценарии, ради которого делалась.
  /// Поэтому метод публичный и зовётся ещё и на возобновлении приложения.
  Future<void> drainMissedCallTrail() async {
    if (!_supportsNativeCallUiPlatform) return;
    // Возобновление может прийти встык с запуском; параллельные заходы не
    // опасны (натив отдаёт след и сразу чистит, а запись идёт с onlyIfAbsent),
    // но и смысла в них нет.
    if (_missedTrailDrainInFlight) return;
    _missedTrailDrainInFlight = true;
    try {
      await _drainMissedCallTrail();
    } finally {
      _missedTrailDrainInFlight = false;
    }
  }

  Future<void> _drainMissedCallTrail() async {
    List<Object?>? raw;
    try {
      raw = await _nativeCallUiChannel.invokeMethod<List<Object?>>(
        'drainMissedCallTrail',
      );
    } catch (_) {
      // Натив без этого метода (или канал ещё не поднят) — не повод шуметь.
      return;
    }
    if (raw == null || raw.isEmpty) return;

    callOpLog(
      'CallManager',
      'missed_call_trail_drained',
      fields: <String, Object?>{'count': raw.length},
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final item in raw) {
      if (item is! Map) continue;
      final callId = (item['call_id'] as String?)?.trim() ?? '';
      final peerProfileId = (item['caller_profile_id'] as String?)?.trim() ?? '';
      // Без звонка или без собеседника писать некуда и не о чем.
      if (callId.isEmpty || peerProfileId.isEmpty) continue;
      final rawAttemptId = (item['call_attempt_id'] as String?)?.trim() ?? '';
      final startedAtMs = (item['created_at_ms'] as num?)?.toInt() ?? 0;
      if (startedAtMs <= 0) continue;
      // Конец звонка — не позже «сейчас»: отметка приходит с часов звонившего,
      // и вперёд она уехать не имеет права.
      final ringEndsAtMs = startedAtMs + ringTimeoutSeconds * 1000;
      try {
        await controller.recordCallOutcome(
          callId: callId,
          callAttemptId: rawAttemptId.isEmpty ? callId : rawAttemptId,
          peerProfileId: peerProfileId,
          peerName: (item['caller_name'] as String?)?.trim() ?? '',
          peerAvatarPath: null,
          direction: CallRecordDirection.incoming,
          isVideo: item['is_video'] == true,
          hadScreenShare: false,
          startedAtMs: startedAtMs,
          connectedAtMs: null,
          endedAtMs: ringEndsAtMs > nowMs ? nowMs : ringEndsAtMs,
          endReason: CallEndReason.timeout,
          // 🔴 Ни при каких обстоятельствах не переписывать уже существующую
          // запись: след видел лишь то, что плашка прозвонила, и знает о звонке
          // МЕНЬШЕ, чем машина состояний. Без этого принятый разговор
          // превратился бы в «пропущенный» на ближайшем запуске.
          onlyIfAbsent: true,
        );
      } catch (e) {
        callLog('CallManager', 'missed call trail record failed: $e');
      }
    }
  }

  /// Processes a [OneToOneCallWakeHint] that was stored by [PushWakeService]
  /// when a `call_invite_v1` push arrived while the app was killed/backgrounded.
  /// Must be called after [start()].
  ///
  /// Stale hint  → dismisses native incoming UI and records the attempt as
  ///               ended so any late-arriving relay signals are suppressed.
  /// Fresh hint  → seeds [_lastNativeIncomingCallId] so [_hideNativeIncomingUi]
  ///               can target the right call before the invite signal arrives.
  Future<void> processStartupCallHint(OneToOneCallWakeHint hint) async {
    controller.markCallPriorityWindow();
    final attemptKey = endedCallAttemptKey(
      callId: hint.callId,
      callAttemptId: hint.callAttemptId,
    );
    if (hint.isStale) {
      callLog(
        'CallManager',
        'startup call hint stale — dismissing native UI '
            'callId=${hint.callId.length > 8 ? hint.callId.substring(0, 8) : hint.callId} '
            'ageMs=${DateTime.now().millisecondsSinceEpoch - hint.createdAtMs}',
      );
      if (attemptKey.isNotEmpty) {
        _lastEndedCallAttemptKeys.add(attemptKey);
        while (_lastEndedCallAttemptKeys.length >
            _maxEndedCallAttemptKeysKept) {
          _lastEndedCallAttemptKeys.remove(_lastEndedCallAttemptKeys.first);
        }
        SharedPreferences.getInstance()
            .then((prefs) {
              prefs.setStringList(
                _prefKeyEndedCallAttemptKeys,
                _lastEndedCallAttemptKeys.toList(),
              );
            })
            .catchError((_) {});
      }
      if (_supportsNativeCallUiPlatform) {
        try {
          await _nativeCallUiChannel.invokeMethod<void>('hideIncomingNative', {
            'callId': hint.callId,
            'callAttemptId': hint.callAttemptId,
          });
        } catch (_) {}
      }
      unawaited(PushWakeService.clearOneToOneCallHint());
    } else {
      callLog(
        'CallManager',
        'startup call hint fresh — seeding native call ID '
            'callId=${hint.callId.length > 8 ? hint.callId.substring(0, 8) : hint.callId}',
      );
      _lastNativeIncomingCallId = hint.callId;
      _lastNativeIncomingCallAttemptId = hint.callAttemptId;
      await _seedIncomingFromHint(hint);
    }
  }

  /// 🔴 Ш-1: СОСТОЯНИЕ ВХОДЯЩЕГО ЗВОНКА ИЗ ПУША (13.08.2026).
  ///
  /// Замер 12.08: пуш приходит мгновенно, а приглашение едет обычным сообщением
  /// через ящик реле — в поле опоздало на ВОСЕМЬ секунд. До приглашения
  /// CallManager про звонок не знал, а из состояния рисуется И экран, И островок.
  /// Отсюда «открылось пустое приложение» и «островок не гаснет».
  ///
  /// Попытка 12.08 обойти это ОТДЕЛЬНЫМ каналом для интерфейса провалилась и дала
  /// три новых дефекта: «неизвестно» вместо имени, повторное уведомление на каждое
  /// нажатие, островок не гас после отмены звонящим. Отдельный источник не знает
  /// ни имени, ни отмены — и знать не может. Поэтому источник ОДИН: состояние.
  ///
  /// Почему это безопасно (проверено чтением 13.08):
  ///  * приглашение не несёт ничего, чего нет в пуше — предложение соединения
  ///    приходит ОТДЕЛЬНЫМ сигналом `offer`, а не приглашением. Поэтому даже
  ///    когда обработчик приглашения сочтёт его дубликатом и пропустит (К-1),
  ///    звонок соединится;
  ///  * `acceptIncoming` уже умеет работать БЕЗ предложения: при его отсутствии
  ///    зовёт `_requestOfferRecovery`. То есть «Принять» до приезда приглашения
  ///    сработает;
  ///  * `hangup` сверяется по callId/attemptId — а они у нас те же, что в пуше,
  ///    значит отмена звонящим ПОГАСИТ и состояние, и островок (К-2).
  Future<void> _seedIncomingFromHint(OneToOneCallWakeHint hint) async {
    // К-6: чужой звонок не трогаем. Разрешение двойного звонка живёт в
    // обработчике приглашения, и дублировать его здесь нельзя.
    if (state.value.isActive) return;

    // К-3: для уже завершённой попытки не заводим — это фантомный входящий,
    // который чинили 06.08.
    final attemptKey = endedCallAttemptKey(
      callId: hint.callId,
      callAttemptId: hint.callAttemptId,
    );
    if (attemptKey.isNotEmpty &&
        _lastEndedCallAttemptKeys.contains(attemptKey)) {
      return;
    }
    if (hint.callId.trim().isEmpty) return;

    // К-8: имя разрешаем по устройству звонящего. Не разрешилось — оставляем
    // ПУСТЫМ: островок и экран сами подставят «Входящий звонок». Слово
    // «неизвестно» я уже показал владельцу 12.08 и повторять не буду.
    String peerProfileId = '';
    try {
      peerProfileId = await controller.contactProfileIdForDevice(
        hint.senderDeviceId,
      );
    } catch (_) {
      peerProfileId = '';
    }

    // Ещё раз: пока мы искали профиль, могло прийти настоящее приглашение.
    if (state.value.isActive) return;

    callOpLog(
      'CallManager',
      'incoming_seeded_from_push',
      fields: <String, Object?>{
        'callId': hint.callId,
        'callAttemptId': hint.callAttemptId,
        'isVideo': hint.isVideo,
        'peerResolved': peerProfileId.isNotEmpty,
      },
    );

    state.value = CallState(
      lifecycle: CallLifecycleState.incomingRinging,
      phase: CallPhase.ringingIncoming,
      callId: hint.callId,
      callAttemptId: hint.callAttemptId,
      direction: CallDirection.incoming,
      startedAtMs: hint.createdAtMs,
      peerProfileId: peerProfileId,
      peerName: '',
      isVideo: hint.isVideo,
      isSpeaker: hint.isVideo,
      isCameraOff: hint.isVideo,
      isUiMinimized: false,
    );

    // К-4: буфер нативного действия — на ОДИН слот, и «Принять», нажатое в
    // уведомлении, лежит именно в нём. Порядок тот же, что у приглашения.
    if (_consumePendingNativeActionForCurrentRinging()) return;

    _setCallActive(true);
    // К-5: нативную плашку НЕ показываем заново и НЕ гасим — она уже показана
    // службой пушей, а `hideIncomingNative` стирает токен и убивает плашку
    // активного разговора (шрам 04.08).
    _startRingTimeout();
    // К-7: мелодия — ровно один раз. Приглашение, придя дубликатом, её не
    // тронет, потому что обработчик пропустит его целиком.
    if (!_shouldSuppressFlutterIncomingRingtone()) {
      unawaited(_startRingtone(incoming: true));
    }
    if (peerProfileId.isNotEmpty) {
      unawaited(_refreshIncomingPeerDetails(peerProfileId));
    }
  }

  void onAppLifecycleStateChanged(AppLifecycleState appState) {
    final inForeground =
        appState == AppLifecycleState.resumed ||
        appState == AppLifecycleState.inactive;
    final current = state.value;
    // 🔴 Judge the ring by the WALL CLOCK before doing anything with it. The
    // 45 s timer does not run while the app is suspended, so on the way back in
    // the state can still say "ringing" for a call that died long ago — and
    // both branches below would faithfully put it back on screen. That is the
    // phantom incoming call the user reported after cancelling from their side.
    if (current.phase == CallPhase.ringingIncoming &&
        incomingRingExpired(
          startedAtMs: current.startedAtMs,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        )) {
      callOpLog(
        'CallManager',
        'incoming_ring_expired_on_lifecycle',
        fields: <String, Object?>{
          'callId': current.callId,
          'callAttemptId': current.callAttemptId,
          'ageMs':
              DateTime.now().millisecondsSinceEpoch -
              (current.startedAtMs ?? 0),
          'foreground': inForeground,
        },
      );
      unawaited(_hideNativeIncomingUi());
      unawaited(_endCall(CallEndReason.timeout));
      return;
    }
    if (!inForeground) {
      if (current.phase == CallPhase.ringingIncoming) {
        unawaited(_showNativeIncomingUi());
      } else if (current.isActive) {
        unawaited(_showOngoingCallNotification());
      }
      return;
    }
    if (current.phase == CallPhase.ringingIncoming) {
      if (_shouldKeepNativeIncomingUiForCurrentCall()) {
        callOpLog(
          'CallManager',
          'incoming_lifecycle_keep_native',
          fields: <String, Object?>{
            'callId': current.callId,
            'callAttemptId': current.callAttemptId,
          },
        );
        return;
      }
      // Плашку НЕ показываем заново, если человек уже нажал и экран открыт:
      // иначе она ляжет поверх него при каждом возврате приложения.
      if (!_incomingScreenRequested) {
        unawaited(_showNativeIncomingUi());
      }
      return;
    }
    if (current.isActive && !current.isUiMinimized) {
      // Skip re-push when the app resumes within 4 s of an accept — the accept
      // flow already pushed /call and the IncomingCallActivity closing triggers
      // a spurious lifecycle resume that would create a second screen.
      final msSinceAccept =
          DateTime.now().millisecondsSinceEpoch - _lastAcceptedAtMs;
      if (msSinceAccept > 4000) {
        _pushCallScreen();
      }
    }
  }

  Future<void> dispose() async {
    _signalSub?.cancel();
    _relayConnectionSub?.cancel();
    _connectivitySub?.cancel();
    _nativeNetworkPathSub?.cancel();
    _nativeNetworkPathSub = null;
    _connectivityHandoffRecoveryTimer?.cancel();
    _connectivityHandoffRecoveryTimer = null;
    _cancelMobileInitialConnectAssist(resetAttempt: true);
    _connectivityFollowUpRecoveryAttempts = 0;
    _queuedConnectivityHandoffRecovery = false;
    _nativeCallActionSub?.cancel();
    _nativeCallActionSub = null;
    _adoptedRingWatchdog?.cancel();
    _adoptedRingWatchdog = null;
    _ringTimer?.cancel();
    _connectTimer?.cancel();
    _cancelMobileInitialConnectAssist(resetAttempt: true);
    _answerResendTimer?.cancel();
    _offerRequestTimer?.cancel();
    _incomingVibrationTimer?.cancel();
    await _stopRingtone();
    await _ringtonePlayer.dispose();
    await _disposeSession();
    _audioRouteController.state.removeListener(_handleAudioRouteStateChanged);
    await _audioRouteController.dispose();
    await _hideNativeIncomingUi();
    // Safety net: ensure the Android foreground service is stopped even if
    // _endCall() was bypassed (e.g. app killed by dev or hot-restart).
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_stopCallForegroundService());
    }
    state.dispose();
  }

  void _handleAudioRouteStateChanged() {
    final current = state.value;
    final isSpeakerSelected =
        _audioRouteController.state.value.isSpeakerSelected;
    if (current.isSpeaker == isSpeakerSelected) {
      return;
    }
    state.value = current.copyWith(isSpeaker: isSpeakerSelected);
  }

  void _onRelayConnectionChanged(bool connected) {
    _relayConnected = connected;
    if (!connected) return;
    unawaited(_handleRelayReconnect());
  }

  void _onNativeNetworkPathEvent(Object? event) {
    final results = connectivityResultsFromNativePathEvent(event);
    if (results.isEmpty) return;
    final signature = event is Map
        ? (event['signature']?.toString().trim() ?? '')
        : '';
    final forcePathChanged =
        signature.isNotEmpty &&
        _lastNativeNetworkPathSignature.isNotEmpty &&
        signature != _lastNativeNetworkPathSignature;
    if (signature.isNotEmpty) {
      _lastNativeNetworkPathSignature = signature;
    }
    unawaited(
      _handleConnectivityChanged(results, forcePathChanged: forcePathChanged),
    );
  }

  Future<void> _handleConnectivityChanged(
    List<ConnectivityResult> results, {
    bool forcePathChanged = false,
  }) async {
    final normalizedResults = List<ConnectivityResult>.unmodifiable(results);
    final previousResults = _lastConnectivityResults;
    _lastConnectivityResults = normalizedResults;
    final current = state.value;
    // Only drop the very first connectivity event when no call is active.
    // If a call is already in flight (e.g. accepted before connectivity_plus
    // delivered its initial snapshot), treat the first event as a real
    // signal so we do not lose the recovery trigger.
    if (previousResults.isEmpty && !current.isActive) {
      return;
    }
    if (!current.isActive) {
      _connectivityHandoffRecoveryTimer?.cancel();
      _connectivityHandoffRecoveryTimer = null;
      _connectivityFollowUpRecoveryAttempts = 0;
      _queuedConnectivityHandoffRecovery = false;
      return;
    }
    final hadUsableConnectivity = hasUsableConnectivity(previousResults);
    final hasUsableConnectivityNow = hasUsableConnectivity(normalizedResults);
    final connectivityRestored =
        !hadUsableConnectivity && hasUsableConnectivityNow;
    final connectivityPathChanged =
        forcePathChanged ||
        hasConnectivityPathChanged(
          previousResults: previousResults,
          currentResults: normalizedResults,
        );
    if (!hasUsableConnectivityNow) {
      _connectivityHandoffRecoveryTimer?.cancel();
      _connectivityHandoffRecoveryTimer = null;
      _connectivityFollowUpRecoveryAttempts = 0;
      _queuedConnectivityHandoffRecovery = false;
      callLog(
        'CallManager',
        'connectivity lost during active call callId=${current.callId} callAttemptId=${current.callAttemptId}',
      );
      if (current.phase == CallPhase.connected) {
        _transitionLifecycle(
          CallLifecycleEvent.transportLost,
          source: 'connectivity_lost',
        );
      }
      _ensureReconnectWatchdog();
      return;
    }
    if (!shouldAttemptTransportRecoveryOnConnectivityChange(
      phase: current.phase,
      wasEverConnected: current.connectedAtMs != null,
      hasUsableConnectivity: hasUsableConnectivityNow,
      connectivityRestored: connectivityRestored,
      connectivityPathChanged: connectivityPathChanged,
    )) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastConnectivityRecoveryAtMs <
        _connectivityRecoveryThrottleMs) {
      return;
    }
    _lastConnectivityRecoveryAtMs = nowMs;

    final reason = connectivityPathChanged
        ? 'connectivity_path_changed'
        : 'connectivity_restored';
    if (connectivityPathChanged || connectivityRestored) {
      _lastConnectivityRecoveryTriggerAtMs = nowMs;
      _lastConnectivityRecoveryAttemptKey = endedCallAttemptKey(
        callId: current.callId,
        callAttemptId: current.callAttemptId,
      );
      _connectivityFollowUpRecoveryAttempts = 0;
      _queuedConnectivityHandoffRecovery = false;
    }
    callLog(
      'CallManager',
      'connectivity change recovery reason=$reason callId=${current.callId} callAttemptId=${current.callAttemptId}',
    );

    if (current.phase != CallPhase.reconnecting) {
      _transitionLifecycle(CallLifecycleEvent.transportLost, source: reason);
    }
    if (_iceRestartAttempts > 0) {
      callLog(
        'CallManager',
        'connectivity changed while transport is degraded; reopening ICE restart budget',
      );
      _iceRestartAttempts = 0;
    }
    _ensureReconnectWatchdog();
    _ensureReconnectingPoll();
    // If a previous restart is still marked in-flight from before the
    // network changed, force-release the lock — the underlying SDP/relay
    // send is almost certainly dead on the old transport and would block
    // recovery for up to 6s (or 4min via the watchdog).
    _forceReleaseIceRestartLockIfStale(reason: 'connectivity_changed');
    if (shouldScheduleConnectivityFollowUpRecovery(
      connectivityRestored: connectivityRestored,
      connectivityPathChanged: connectivityPathChanged,
    )) {
      _scheduleConnectivityHandoffRecovery(
        delay: connectivityPathChanged
            ? _connectivityHandoffRecoveryDelay
            : _connectivityRestoreRecoveryDelay,
      );
    }
    // F9 (A1): the old WS socket is bound to the previous IP and will sit
    // idle until TCP keepalive expires (minutes on iOS LTE). Drop it now
    // with a reset backoff so the next reconnect fires within ~400ms.
    try {
      controller.requestUrgentRelayReconnect();
    } catch (e) {
      callLog(
        'CallManager',
        'requestUrgentRelayReconnect failed: $e (continuing recovery)',
      );
    }
    // F9 (A6): if the cached TURN credentials are stale we must refresh
    // them BEFORE issuing the restart, otherwise the new ICE pass will
    // use expired credentials and the cellular peer will fall back to
    // srflx-only which usually fails on CGNAT.
    final cachedIce = controller.cachedCallIceConfig;
    if (cachedIce.isExpired()) {
      try {
        await _getCallIceConfigForRecovery(forceRefresh: true)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        callLog(
          'CallManager',
          'TURN refresh on connectivity change failed: $e (continuing with cached)',
        );
      }
    } else {
      _refreshCallIceConfigForRecoveryInBackground(
        source: 'connectivity-triggered',
      );
    }
    if (!_relayConnected) {
      // F9 (A2): instead of dropping the recovery on the floor, queue it.
      // _handleRelayReconnect picks this up on the next WS-up tick and
      // immediately fires the ICE restart, bypassing its throttle.
      _pendingRelayConnectivityRecovery = true;
      _pendingRelayConnectivityRecoveryAtMs = nowMs;
      callLog(
        'CallManager',
        'connectivity recovery queued for next relay reconnect callId=${current.callId}',
      );
      return;
    }
    // Skip the relay reconcile gate on connectivity-triggered recovery:
    // the relay snapshot is stale on a fresh network and adds latency
    // before the actual ICE restart. The watchdog/poll path will still
    // reconcile periodically.
    // GLARE-FIX (2026-05-16): use soft restartIce here — hard recovery
    // recreates the whole PC and triggers offer/offer collision when the
    // remote peer does the same on its end. Soft restart keeps the PC alive
    // and only re-gathers ICE; escalation to fresh transport still happens
    // after 2+ failed attempts via shouldUseFreshTransportRecovery.
    await _autoRestartIce(preferHardRecovery: false, skipRelayReconcile: true);
  }

  void _forceReleaseIceRestartLockIfStale({required String reason}) {
    if (!_iceRestartInFlight) {
      return;
    }
    callLog(
      'CallManager',
      'force-releasing stuck ICE restart lock reason=$reason',
    );
    _iceRestartInFlightSafetyTimer?.cancel();
    _iceRestartInFlightSafetyTimer = null;
    _iceRestartInFlight = false;
    // Bump the generation so any in-flight `_autoRestartIce` whose finally
    // block runs after this point does not flip the lock back off / cancel
    // the safety timer of a successor attempt.
    _iceRestartInFlightGeneration++;
  }

  Future<CallIceConfigSnapshot> _getCallIceConfigForRecovery({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      return controller.getCallIceConfig();
    }
    final inFlight = _recoveryIceConfigRefreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final refresh = controller.getCallIceConfig(forceRefresh: true);
    _recoveryIceConfigRefreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_recoveryIceConfigRefreshInFlight, refresh)) {
        _recoveryIceConfigRefreshInFlight = null;
      }
    }
  }

  bool _isMobileOnlyConnectivity(List<ConnectivityResult> results) {
    var hasMobile = false;
    var hasFixedBroadband = false;
    for (final result in results) {
      switch (result) {
        case ConnectivityResult.mobile:
          hasMobile = true;
          break;
        case ConnectivityResult.wifi:
        case ConnectivityResult.ethernet:
          hasFixedBroadband = true;
          break;
        case ConnectivityResult.none:
        case ConnectivityResult.bluetooth:
        case ConnectivityResult.vpn:
        case ConnectivityResult.satellite:
        case ConnectivityResult.other:
          break;
      }
    }
    return hasMobile && !hasFixedBroadband;
  }

  CallIceConfigSnapshot _optimizeIceConfigForConnectivity(
    CallIceConfigSnapshot iceConfig, {
    required String source,
  }) {
    if (!iceConfig.hasUsableRelayServers) {
      return iceConfig;
    }
    if (!_isMobileOnlyConnectivity(_lastConnectivityResults)) {
      return iceConfig;
    }
    if (iceConfig.policy == CallNetworkPolicy.relayPreferred ||
        iceConfig.policy == CallNetworkPolicy.relayOnly) {
      return iceConfig;
    }
    callLog(
      'CallManager',
      '$source switching ICE policy to relay_preferred for mobile connectivity',
    );
    return CallIceConfigSnapshot(
      policy: CallNetworkPolicy.relayPreferred,
      iceServers: iceConfig.iceServers,
      expiresAtMs: iceConfig.expiresAtMs,
    );
  }

  Future<bool> _applyIceConfigToActiveSession({
    required CallIceConfigSnapshot iceConfig,
    required String source,
  }) async {
    final session = _session;
    final current = state.value;
    if (session == null || !current.isActive) {
      return false;
    }

    // 🔴 ПРОВЕРЯЕМ ДО ПОДСТАНОВКИ (SEC-10, 25.08.2026).
    //
    // `validateIceConfigForSession` отвергает политику «только через сервер»,
    // если TURN-серверов нет. Раньше она стояла ПОСЛЕ
    // `_augmentIceConfigWithFallback` — а подстановка сама переписывает такую
    // политику на прямое соединение и добавляет запасные серверы. К моменту
    // проверки конфигурация выглядела исправной, и проверка не срабатывала
    // никогда: человек, которому назначено скрывать адрес, молча звонил
    // напрямую.
    //
    // Тот же класс, что страховка повторов 24.08: защита стоит после того, как
    // проблему замаскировали. Порядок сторожит `call_ice_policy_order_test`.
    final iceConfigError = validateIceConfigForSession(iceConfig);
    if (iceConfigError != null) {
      callLog(
        'CallManager',
        '$source ICE config rejected for active session: $iceConfigError',
      );
      return false;
    }

    final effectiveIceConfig = _optimizeIceConfigForConnectivity(
      _augmentIceConfigWithFallback(
        iceConfig,
        relayBaseUrl: controller.relayHttpBaseUrl,
      ),
      source: source,
    );

    try {
      final applied = await session.applyIceConfiguration(
        iceServers: effectiveIceConfig.toRtcIceServers(),
        iceTransportPolicy: effectiveIceConfig.rtcIceTransportPolicy,
        networkPolicy: effectiveIceConfig.policy,
      );
      if (applied) {
        callLog(
          'CallManager',
          '$source applied runtime ICE reconfiguration callId=${current.callId} callAttemptId=${current.callAttemptId}',
        );
      }
      return applied;
    } catch (e, stack) {
      callLog(
        'CallManager',
        '$source runtime ICE reconfigure failed: $e\n$stack',
      );
      return false;
    }
  }

  void _refreshCallIceConfigForRecoveryInBackground({required String source}) {
    unawaited(() async {
      try {
        final iceConfig = await _getCallIceConfigForRecovery(
          forceRefresh: true,
        );
        await _applyIceConfigToActiveSession(
          iceConfig: iceConfig,
          source: source,
        );
      } catch (e) {
        callLog('CallManager', '$source ICE refresh failed: $e');
      }
    }());
  }

  void _cancelMobileInitialConnectAssist({bool resetAttempt = false}) {
    _mobileInitialConnectAssistTimer?.cancel();
    _mobileInitialConnectAssistTimer = null;
    if (resetAttempt) {
      _mobileInitialConnectAssistAttemptKey = '';
      _mobileInitialConnectAssistAttempts = 0;
    }
  }

  void _scheduleMobileInitialConnectAssist({required String reason}) {
    final snapshot = state.value;
    if (!snapshot.isActive ||
        snapshot.phase != CallPhase.connecting ||
        snapshot.connectedAtMs != null) {
      return;
    }
    final attemptKey = endedCallAttemptKey(
      callId: snapshot.callId,
      callAttemptId: snapshot.callAttemptId,
    );
    if (attemptKey.isEmpty) {
      return;
    }
    if (_mobileInitialConnectAssistAttemptKey != attemptKey) {
      _mobileInitialConnectAssistAttemptKey = attemptKey;
      _mobileInitialConnectAssistAttempts = 0;
    }
    if (_mobileInitialConnectAssistAttempts >=
        _maxMobileInitialConnectAssistAttempts) {
      return;
    }
    if (_mobileInitialConnectAssistTimer != null) {
      return;
    }
    final delay = _mobileInitialConnectAssistAttempts == 0
        ? _mobileInitialConnectAssistDelay
        : _mobileInitialConnectAssistFollowUpDelay;
    callOpLog(
      'CallManager',
      'mobile_initial_connect_assist_scheduled',
      fields: <String, Object?>{
        'callId': snapshot.callId,
        'callAttemptId': snapshot.callAttemptId,
        'reason': reason,
        'attempt': _mobileInitialConnectAssistAttempts + 1,
        'delayMs': delay.inMilliseconds,
      },
    );
    _mobileInitialConnectAssistTimer = Timer(delay, () {
      _mobileInitialConnectAssistTimer = null;
      unawaited(_runMobileInitialConnectAssist(reason: reason));
    });
  }

  Future<void> _runMobileInitialConnectAssist({required String reason}) async {
    final snapshot = state.value;
    if (!snapshot.isActive ||
        snapshot.phase != CallPhase.connecting ||
        snapshot.connectedAtMs != null) {
      return;
    }
    final attemptKey = endedCallAttemptKey(
      callId: snapshot.callId,
      callAttemptId: snapshot.callAttemptId,
    );
    if (attemptKey.isEmpty) {
      return;
    }
    if (_mobileInitialConnectAssistAttemptKey != attemptKey) {
      _mobileInitialConnectAssistAttemptKey = attemptKey;
      _mobileInitialConnectAssistAttempts = 0;
    }
    if (_mobileInitialConnectAssistAttempts >=
        _maxMobileInitialConnectAssistAttempts) {
      return;
    }

    var connectivityResults = _lastConnectivityResults;
    if (connectivityResults.isEmpty) {
      try {
        connectivityResults = List<ConnectivityResult>.unmodifiable(
          await Connectivity().checkConnectivity(),
        );
        _lastConnectivityResults = connectivityResults;
      } catch (_) {}
    }
    if (!_isMobileOnlyConnectivity(connectivityResults)) {
      return;
    }

    final session = _session;
    if (session == null) {
      _scheduleMobileInitialConnectAssist(reason: 'session_not_ready');
      return;
    }
    final rtcState = session.connectionState.value;
    final iceState = session.iceConnectionState.value;
    final transportConnected =
        rtcState == RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted;
    if (transportConnected || session.mediaEstablished.value) {
      return;
    }

    _mobileInitialConnectAssistAttempts++;
    callOpLog(
      'CallManager',
      'mobile_initial_connect_assist_start',
      fields: <String, Object?>{
        'callId': snapshot.callId,
        'callAttemptId': snapshot.callAttemptId,
        'reason': reason,
        'attempt': _mobileInitialConnectAssistAttempts,
        'rtcState': rtcState,
        'iceState': iceState,
      },
    );

    try {
      final fetchedIceConfig = await _getCallIceConfigForRecovery(
        forceRefresh: true,
      );
      final baseIceConfig = _augmentIceConfigWithFallback(
        fetchedIceConfig,
        relayBaseUrl: controller.relayHttpBaseUrl,
      );
      // SEC-10: здесь порядок обратный намеренно, и это безопасно. Проверка
      // ниже требует именно TURN (`hasUsableRelayServers` смотрит только на
      // него), а подстановка добавляет STUN — то есть подставленное сервером
      // условие не удовлетворяет и путь честно пропускается.
      if (!baseIceConfig.hasUsableRelayServers) {
        callLog(
          'CallManager',
          'mobile initial connect assist skipped: no usable TURN servers',
        );
        return;
      }
      final relayOnlyIceConfig = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.relayOnly,
        iceServers: baseIceConfig.iceServers,
        expiresAtMs: baseIceConfig.expiresAtMs,
      );
      final applied = await _applyIceConfigToActiveSession(
        iceConfig: relayOnlyIceConfig,
        source: 'mobile_initial_connect_assist',
      );
      callOpLog(
        'CallManager',
        'mobile_initial_connect_assist_relay_only',
        fields: <String, Object?>{
          'callId': snapshot.callId,
          'callAttemptId': snapshot.callAttemptId,
          'applied': applied,
        },
      );
      _forceReleaseIceRestartLockIfStale(
        reason: 'mobile_initial_connect_assist',
      );
      await _autoRestartIce(skipRelayReconcile: true);
    } catch (e, stack) {
      callLog(
        'CallManager',
        'mobile initial connect assist failed: $e\n$stack',
      );
    } finally {
      final latest = state.value;
      if (latest.isActive &&
          latest.phase == CallPhase.connecting &&
          latest.connectedAtMs == null &&
          _mobileInitialConnectAssistAttempts <
              _maxMobileInitialConnectAssistAttempts) {
        _scheduleMobileInitialConnectAssist(reason: 'follow_up');
      }
    }
  }

  void _scheduleConnectivityHandoffRecovery({
    Duration delay = _connectivityHandoffRecoveryDelay,
  }) {
    _connectivityHandoffRecoveryTimer?.cancel();
    _connectivityHandoffRecoveryTimer = Timer(
      delay,
      () => unawaited(_runConnectivityHandoffRecovery()),
    );
  }

  Future<void> _runConnectivityHandoffRecovery() async {
    _connectivityHandoffRecoveryTimer = null;
    final current = state.value;
    final session = _session;
    if (!current.isActive || session == null) {
      return;
    }
    if (!hasUsableConnectivity(_lastConnectivityResults)) {
      return;
    }
    if (_iceRestartInFlight) {
      _queuedConnectivityHandoffRecovery = true;
      callLog(
        'CallManager',
        'connectivity handoff follow-up queued while restart is in flight callId=${current.callId} callAttemptId=${current.callAttemptId}',
      );
      return;
    }

    final rtcState = session.connectionState.value;
    final iceState = session.iceConnectionState.value;
    final mediaEstablished = session.mediaEstablished.value;
    if (!shouldAttemptTransportRecoveryOnRelayReconnect(
      phase: current.phase,
      wasEverConnected: current.connectedAtMs != null,
      rtcState: rtcState,
      iceState: iceState,
      mediaEstablished: mediaEstablished,
    )) {
      return;
    }

    callLog(
      'CallManager',
      'connectivity handoff follow-up recovery callId=${current.callId} callAttemptId=${current.callAttemptId}',
    );
    _connectivityFollowUpRecoveryAttempts += 1;
    if (_iceRestartAttempts > 0) {
      _iceRestartAttempts = 0;
    }
    _ensureReconnectWatchdog();
    _refreshCallIceConfigForRecoveryInBackground(
      source: 'connectivity handoff',
    );
    // GLARE-FIX: soft restart; let escalation happen via attempt counter.
    await _autoRestartIce(preferHardRecovery: false);

    final latest = state.value;
    final latestSession = _session;
    if (latestSession == null || !latest.isActive) {
      return;
    }
    if (shouldScheduleAdditionalConnectivityFollowUpRecovery(
      phase: latest.phase,
      wasEverConnected: latest.connectedAtMs != null,
      rtcState: latestSession.connectionState.value,
      iceState: latestSession.iceConnectionState.value,
      mediaEstablished: latestSession.mediaEstablished.value,
      hasUsableConnectivity: hasUsableConnectivity(_lastConnectivityResults),
      attemptsSoFar: _connectivityFollowUpRecoveryAttempts,
    )) {
      callLog(
        'CallManager',
        'connectivity recovery still degraded after follow-up; scheduling one more pass callId=${latest.callId} callAttemptId=${latest.callAttemptId}',
      );
      _scheduleConnectivityHandoffRecovery(
        delay: _connectivityLateRecoveryDelay,
      );
    }
  }

  bool _hasRecentConnectivityRecoveryForSnapshot(
    CallState snapshot, {
    required int nowMs,
  }) {
    final attemptKey = endedCallAttemptKey(
      callId: snapshot.callId,
      callAttemptId: snapshot.callAttemptId,
    );
    if (attemptKey.isEmpty ||
        attemptKey != _lastConnectivityRecoveryAttemptKey) {
      return false;
    }
    final ageMs = nowMs - _lastConnectivityRecoveryTriggerAtMs;
    return ageMs >= 0 && ageMs <= _recentConnectivityRecoveryRelayGraceMs;
  }

  Future<void> _handleRelayReconnect() async {
    final session = _session;
    final current = state.value;
    if (session == null || !current.isActive) {
      unawaited(_reconcileActiveCallWithRelay(trigger: 'relay_connected'));
      return;
    }

    unawaited(_reconcileActiveCallWithRelay(trigger: 'relay_connected'));

    final rtcState = session.connectionState.value;
    final iceState = session.iceConnectionState.value;
    final mediaEstablished = session.mediaEstablished.value;
    if (current.phase == CallPhase.reconnecting &&
        shouldPromoteConnectedFromSession(
          phase: current.phase,
          wasEverConnected: current.connectedAtMs != null,
          rtcState: rtcState,
          iceState: iceState,
          mediaEstablished: mediaEstablished,
        )) {
      _transitionLifecycle(
        CallLifecycleEvent.mediaEstablished,
        source: 'relay_connected_session_resync',
        connectedAtMs:
            current.connectedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      );
      _setCallActive(true);
      unawaited(_showOngoingCallNotification());
      return;
    }
    if (!shouldAttemptTransportRecoveryOnRelayReconnect(
      phase: current.phase,
      wasEverConnected: current.connectedAtMs != null,
      rtcState: rtcState,
      iceState: iceState,
      mediaEstablished: mediaEstablished,
    )) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // F9 (A2): a connectivity change queued recovery while the WS was
    // down. Bypass the throttle and the relay-reconcile gate so we fire
    // a hard ICE restart on the very first reconnect tick.
    final hasPendingConnectivityRecovery =
        _pendingRelayConnectivityRecovery &&
        (nowMs - _pendingRelayConnectivityRecoveryAtMs) <=
            _pendingRelayConnectivityRecoveryWindowMs;
    if (hasPendingConnectivityRecovery) {
      _pendingRelayConnectivityRecovery = false;
      _pendingRelayConnectivityRecoveryAtMs = 0;
      callLog(
        'CallManager',
        'relay reconnected — firing pending connectivity-triggered ICE recovery callId=${current.callId}',
      );
    } else if (nowMs - _lastRelayReconnectRecoveryAtMs <
        _relayReconnectRecoveryThrottleMs) {
      return;
    }
    _lastRelayReconnectRecoveryAtMs = nowMs;

    final transportFailed = hasTransportFailureState(
      rtcState: rtcState,
      iceState: iceState,
    );
    if (current.phase != CallPhase.reconnecting) {
      _transitionLifecycle(
        transportFailed
            ? CallLifecycleEvent.peerconnectionFailed
            : CallLifecycleEvent.transportLost,
        source: 'relay_connected_transport_recovery',
      );
    }

    if (_iceRestartAttempts > 0) {
      callLog(
        'CallManager',
        'relay reconnected while call transport is degraded; reopening ICE restart budget',
      );
      _iceRestartAttempts = 0;
    }

    _ensureReconnectWatchdog();
    _refreshCallIceConfigForRecoveryInBackground(source: 'relay reconnect');
    // Pending-connectivity path uses skipRelayReconcile because the relay
    // session snapshot is stale on a freshly reconnected WS — the same
    // reason the connectivity handler uses skipRelayReconcile=true.
    // GLARE-FIX: soft restart to avoid PC-recreation glare with remote peer.
    await _autoRestartIce(
      preferHardRecovery: false,
      skipRelayReconcile: hasPendingConnectivityRecovery,
    );
  }

  // ── Public actions (from UI) ───────────────────────────────────────────

  /// Place an outgoing call.
  /// CALL AUDIT 2026-07-08 F2: errors that mean the call can NEVER succeed —
  /// abort immediately with the usual toast. Everything else (network flush
  /// timeouts, keys 429 / service unavailable, momentary empty device list) is
  /// transient: the signal is durably queued or retryable, so the call keeps
  /// ringing and the invite resend loop takes over.
  static bool isFatalCallSetupError(Object error) {
    if (error is ContactActionFailure) {
      switch (error.code) {
        case ContactActionFailureCode.callsDisabledGlobally:
        case ContactActionFailureCode.callsDisabledForContact:
        case ContactActionFailureCode.transportBlocked:
        case ContactActionFailureCode.profileNotFound:
          return true;
        case ContactActionFailureCode.recipientNoDevices:
        case ContactActionFailureCode.serviceUnavailable:
        case ContactActionFailureCode.generic:
          return false;
      }
    }
    final message = error.toString().toLowerCase();
    return message.contains('contact is blocked') ||
        message.contains('transport blocked');
  }

  /// Re-sends the (idempotent) invite — and the offer once its SDP exists —
  /// every 3 s while THIS attempt is still ringing. Self-terminating: stops
  /// when the call changes/ends, after [maxTicks], or when a resend cycle
  /// fully succeeds; the 30-s ring timeout remains the overall cap.
  void _startInviteResendLoop({
    required String peerProfileId,
    required String callId,
    required String callAttemptId,
    required bool video,
    int maxTicks = 8,
  }) {
    if (_inviteResendTimer != null) return; // already running
    _inviteResendTicks = 0;
    callLog('CallManager', 'invite resend loop started callId=$callId');
    _inviteResendTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      final s = state.value;
      final stillThisRing =
          s.callId == callId &&
          s.direction == CallDirection.outgoing &&
          (s.phase == CallPhase.ringingOutgoing ||
              s.lifecycle == CallLifecycleState.outgoingInviting);
      if (!stillThisRing || _inviteResendTicks >= maxTicks) {
        timer.cancel();
        if (identical(_inviteResendTimer, timer)) _inviteResendTimer = null;
        return;
      }
      _inviteResendTicks++;
      var inviteOk = false;
      try {
        await controller.sendCallInvite(
          peerProfileId: peerProfileId,
          video: video,
          callId: callId,
        );
        inviteOk = true;
      } catch (e) {
        callLog(
          'CallManager',
          'invite resend tick=$_inviteResendTicks failed: $e',
        );
        if (isFatalCallSetupError(e)) {
          timer.cancel();
          if (identical(_inviteResendTimer, timer)) _inviteResendTimer = null;
          await _failCallAndNotifyRemote(error: e, stackTrace: null);
          return;
        }
      }
      var offerOk = true;
      final offerSdp = _lastLocalOfferSdp;
      if (offerSdp != null && offerSdp.isNotEmpty) {
        try {
          await controller.sendCallOffer(
            peerProfileId: peerProfileId,
            callId: callId,
            callAttemptId: callAttemptId,
            video: video,
            sdp: offerSdp,
          );
        } catch (e) {
          offerOk = false;
          callLog(
            'CallManager',
            'offer resend tick=$_inviteResendTicks failed: $e',
          );
        }
      }
      if (inviteOk && offerOk) {
        callLog(
          'CallManager',
          'invite resend loop delivered (tick=$_inviteResendTicks)',
        );
        timer.cancel();
        if (identical(_inviteResendTimer, timer)) _inviteResendTimer = null;
      }
    });
  }

  Future<void> startCall({
    required String peerProfileId,
    required String peerName,
    String? peerAvatarPath,
    required bool video,
  }) async {
    if (state.value.isActive) return; // already in a call
    controller.markCallPriorityWindow();
    try {
      _awaitingRecoveryOffer = false;
      // Generate the callId locally so we can run invite delivery in parallel
      // with WebRTC session bootstrap. On mobile networks this saves the full
      // round-trip latency of the relay HTTP send before media setup begins.
      final callId = controller.newCallId();
      final callAttemptId = callId;
      callOpLog(
        'CallManager',
        'outgoing_call_started',
        fields: <String, Object?>{
          'callId': callId,
          'callAttemptId': callAttemptId,
          'peerProfileId': peerProfileId,
          'isVideo': video,
        },
      );
      state.value = CallState(
        lifecycle: CallLifecycleState.outgoingInviting,
        phase: CallPhase.ringingOutgoing,
        callId: callId,
        callAttemptId: callAttemptId,
        direction: CallDirection.outgoing,
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
        peerProfileId: peerProfileId,
        peerName: peerName,
        peerAvatarPath: peerAvatarPath,
        isVideo: video,
        isSpeaker: video,
        isUiMinimized: false,
      );
      _pushCallScreen();
      // FIX (2026-07-13, call avatar): if the launching surface had no avatar
      // path (e.g. a non-contact conversation whose avatarPath was null),
      // resolve it via the same resolver the chat uses and update the live call
      // state, so the outgoing/ringing/connected screen shows the peer photo
      // instead of initials.
      if (peerAvatarPath == null || peerAvatarPath.trim().isEmpty) {
        unawaited(() async {
          try {
            final resolved = await controller.cachedProfileAvatarPath(
              peerProfileId,
            );
            if (resolved != null &&
                state.value.callId == callId &&
                state.value.peerProfileId == peerProfileId) {
              state.value = state.value.copyWith(peerAvatarPath: resolved);
            }
          } catch (_) {}
        }());
      }
      await _hideNativeIncomingUi();
      _setCallActive(true);
      unawaited(_showOngoingCallNotification());
      unawaited(_startRingtone(incoming: false));
      _startRingTimeout();
      // Fire invite delivery in parallel with media setup.
      // CALL AUDIT 2026-07-08 F2: only FATAL errors (calls disabled / blocked /
      // wrong server / no such profile) propagate and abort the call. Any
      // transient failure (flush timeout on a slow uplink, keys 429, momentary
      // empty device resolve) keeps the call ringing and hands delivery to the
      // invite resend loop — previously ANY error here tore the whole call
      // down within ~2s ("Не удалось начать звонок") and the end signal then
      // suppressed the callee's wake push on the relay.
      final inviteFuture = controller
          .sendCallInvite(
            peerProfileId: peerProfileId,
            video: video,
            callId: callId,
          )
          .then(
            (_) {},
            onError: (Object error, StackTrace stack) {
              callLog(
                'CallManager',
                'parallel sendCallInvite failed: $error\n$stack',
              );
              if (isFatalCallSetupError(error)) {
                throw error;
              }
              _startInviteResendLoop(
                peerProfileId: peerProfileId,
                callId: callId,
                callAttemptId: callAttemptId,
                video: video,
              );
            },
          );
      // Create session and place the initial offer immediately, but avoid
      // racing a remote need_offer recovery into a second fresh offer.
      _outgoingOfferBootstrapInFlight = true;
      try {
        final session = await _createSession();
        final awaitingRemoteAnswer = await session.isAwaitingRemoteAnswer();
        final localOfferAlreadyPrepared =
            (_lastLocalOfferSdp?.isNotEmpty ?? false);
        if (!awaitingRemoteAnswer &&
            !session.hasRemoteDescription &&
            !localOfferAlreadyPrepared) {
          await session.startOutgoing(
            video: video,
            onOffer: (sdp) async {
              _transitionLifecycle(
                CallLifecycleEvent.localOfferCreated,
                source: 'startCall_onOffer',
              );
              _lastLocalOfferSdp = sdp;
              // Ensure invite is on the wire before the offer to keep the
              // peer's signaling order predictable. Both sides handle the
              // reverse order too, but ordering avoids a state-machine round.
              try {
                await inviteFuture;
              } catch (_) {
                // invite errors are surfaced via the outer catch below.
              }
              // CALL AUDIT 2026-07-08 F2: a transient offer-send failure keeps
              // the call ringing — the resend loop re-fires the offer (its SDP
              // is in _lastLocalOfferSdp) instead of aborting the whole call.
              try {
                await _sendCallOfferDeduped(
                  peerProfileId: peerProfileId,
                  callId: callId,
                  callAttemptId: callAttemptId,
                  video: video,
                  sdp: sdp,
                );
              } catch (e) {
                if (isFatalCallSetupError(e)) rethrow;
                callLog(
                  'CallManager',
                  'offer send failed (transient) — resend loop takes over: $e',
                );
                _startInviteResendLoop(
                  peerProfileId: peerProfileId,
                  callId: callId,
                  callAttemptId: callAttemptId,
                  video: video,
                );
              }
            },
            onIceCandidate: (c, mid, idx) => controller.sendCallIceCandidate(
              peerProfileId: peerProfileId,
              callId: callId,
              callAttemptId: callAttemptId,
              candidate: c,
              sdpMid: mid,
              sdpMLineIndex: idx,
              recovery: _shouldUseRecoveryIceDelivery(),
            ),
          );
        } else {
          callLog(
            'CallManager',
            'skipping redundant outgoing bootstrap because session already progressed awaitingRemoteAnswer=$awaitingRemoteAnswer hasRemoteDescription=${session.hasRemoteDescription} localOfferPrepared=$localOfferAlreadyPrepared',
          );
        }
        // Make sure invite finished before we exit bootstrap; surfaces errors.
        await inviteFuture;
        await _syncAudioRoutesForCurrentCall(
          reason: 'start_call_session_ready',
          reapplyCurrentRoute: true,
        );
        await _tryApplyPendingRemoteAnswer();
      } finally {
        _outgoingOfferBootstrapInFlight = false;
      }
    } catch (e, st) {
      if (!kReleaseMode) {
        debugPrint('CallManager.startCall error: $e');
      }
      await _failCallAndNotifyRemote(error: e, stackTrace: st);
      Error.throwWithStackTrace(e, st);
    }
  }

  /// Accept an incoming call.
  Future<void> acceptIncoming() async {
    controller.markCallPriorityWindow();
    final s = state.value;
    if (s.phase != CallPhase.ringingIncoming) {
      // 🔴 МОЛЧАЛИВЫЙ ВЫХОД БЫЛ ГЛАВНОЙ СЛЕПОЙ ЗОНОЙ (аудит 15.08).
      //
      // Экран звонка на iOS показывает РОДНОЙ слой (CallKit) — он обязан
      // появиться немедленно и к состоянию Dart отношения не имеет. Если
      // приглашение до главного изолята ещё не доехало, фаза здесь не
      // «звонит входящий», и приём звонка выходил, не оставив следа: человек
      // видит живой разговор, звонящий ждёт 45 секунд и сдаётся.
      //
      // Печать успеха стояла НИЖЕ этой двери, отказа не было вовсе — то есть
      // самый вероятный корень жалобы был единственным местом без прибора.
      callOpLog(
        'CallManager',
        'accept_ignored_wrong_phase',
        fields: <String, Object?>{
          'phase': s.phase,
          'callId': s.callId,
          'callAttemptId': s.callAttemptId,
        },
      );
      return;
    }
    // Stamp the accept time so onAppLifecycleStateChanged can skip
    // the redundant _pushCallScreen triggered by the activity transition.
    _lastAcceptedAtMs = DateTime.now().millisecondsSinceEpoch;
    callOpLog(
      'CallManager',
      'incoming_call_accepted',
      fields: <String, Object?>{
        'callId': s.callId,
        'callAttemptId': s.callAttemptId,
        'peerProfileId': s.peerProfileId,
      },
    );
    try {
      _ringTimer?.cancel();
      await _stopRingtone(
        keepNativeAudioActive: defaultTargetPlatform == TargetPlatform.iOS,
      );
      _transitionLifecycle(
        CallLifecycleEvent.localAccept,
        source: 'accept_incoming',
      );
      _setCallActive(true);
      unawaited(_showOngoingCallNotification());
      _startConnectTimeout();
      unawaited(_startConnectingTone());
      // r11: surface the call screen immediately (before any heavy native
      // calls) so the user sees the connecting UI without waiting on PC
      // creation, ICE config fetch, or renderer init.
      state.value = state.value.copyWith(isUiMinimized: false);
      _pushCallScreen();
      // Reuses the prewarmed session that was kicked off when the invite
      // arrived; falls back to creating one if prewarm failed/was skipped.
      final session = await _createSession();
      await session.setSpeakerEnabled(s.isVideo);

      // Process buffered offer that arrived while we were ringing.
      final pendingSdp = _pendingOfferSdp;
      _pendingOfferSdp = null;
      callLog(
        'CallManager',
        'pendingOffer=${pendingSdp != null ? '${pendingSdp.length} chars' : 'null'}, pendingICE=${_pendingIceCandidates.length}',
      );
      if (pendingSdp != null && pendingSdp.isNotEmpty) {
        await _handleIncomingOffer(pendingSdp);
      } else {
        callLog('CallManager', 'no offer at accept; requesting offer resend');
        await _requestOfferRecovery(reason: 'accept_incoming_missing_offer');
      }
      // Flush any ICE candidates that arrived before we had the session.
      final pending = List<CallSignalEvent>.from(_pendingIceCandidates);
      _pendingIceCandidates.clear();
      for (final ice in pending) {
        if (!shouldAcceptSignalForCurrentCall(
          currentCallId: s.callId,
          currentCallAttemptId: s.callAttemptId,
          signalCallId: ice.callId,
          signalCallAttemptId: ice.callAttemptId,
        )) {
          continue;
        }
        await _session?.addRemoteIceCandidate(
          candidate: ice.candidate ?? '',
          sdpMid: ice.sdpMid,
          sdpMLineIndex: ice.sdpMLineIndex,
        );
      }
    } catch (e, stack) {
      callLog('CallManager', 'acceptIncoming failed: $e\n$stack');
      await _failCallAndNotifyRemote(error: e, stackTrace: stack);
    }
  }

  /// Decline incoming call.
  Future<void> declineIncoming() async {
    final s = state.value;
    if (s.phase != CallPhase.ringingIncoming) return;
    callOpLog(
      'CallManager',
      'incoming_call_declined_local',
      fields: <String, Object?>{
        'callId': s.callId,
        'callAttemptId': s.callAttemptId,
        'peerProfileId': s.peerProfileId,
      },
    );
    // Local-first: close UI immediately so network delays/errors can never
    // leave the user stuck on the incoming call screen.
    await _endCall(CallEndReason.localDecline);
    // Best-effort: relay/remote notification; errors are logged, not rethrown.
    if (s.peerProfileId.isNotEmpty && s.callId.isNotEmpty) {
      try {
        await controller.sendCallDecline(
          peerProfileId: s.peerProfileId,
          callId: s.callId,
          callAttemptId: s.callAttemptId,
        );
      } catch (e) {
        callLog('CallManager', 'sendCallDecline failed (best-effort): $e');
      }
    }
  }

  /// Hang up active call.
  Future<void> hangup() async {
    final s = state.value;
    if (!s.isActive) return;
    callOpLog(
      'CallManager',
      'call_hangup_local',
      fields: <String, Object?>{
        'callId': s.callId,
        'callAttemptId': s.callAttemptId,
        'peerProfileId': s.peerProfileId,
      },
    );
    // PR-G (bug 18): fire the cancel/hangup signal BEFORE local teardown so
    // the peer's incoming-call UI dismisses promptly. Previously `_endCall`
    // ran first and any cleanup-induced delay (or platform shutdown) could
    // starve the hangup transport — manifesting as "iOS caller ends, callee
    // keeps ringing". Bounded with 2s timeout so a stuck network never
    // freezes local teardown.
    if (s.peerProfileId.isNotEmpty && s.callId.isNotEmpty) {
      try {
        await controller
            .sendCallHangup(
              peerProfileId: s.peerProfileId,
              callId: s.callId,
              callAttemptId: s.callAttemptId,
            )
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                callLog(
                  'CallManager',
                  'sendCallHangup timed out — proceeding to local teardown',
                );
              },
            );
      } catch (e) {
        callLog('CallManager', 'sendCallHangup failed (best-effort): $e');
      }
    }
    // Local-first teardown.
    await _endCall(CallEndReason.localHangup);
  }

  /// Marks the call as active/inactive on both Dart and iOS native sides.
  /// Suppresses message notification banners while any call phase is active.
  void _setCallActive(bool active) {
    controller.setActiveCallInProgress(active);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _nativeCallUiChannel
          .invokeMethod<void>('setCallActive', active)
          .catchError((_) {});
    }
  }

  /// Android 14+: opens system settings to grant USE_FULL_SCREEN_INTENT.
  /// Может ли уведомление поднять экран звонка само.
  ///
  /// 🔴 С Android 14 полноэкранное намерение требует разрешения, и БЕЗ него оно
  /// молча вырождается в обычную плашку: экран звонка из фона не поднимается, а
  /// причина нигде не видна. Отдаём её в диагностику.
  Future<({bool supported, bool granted})> canUseFullScreenIntent() async {
    if (!_supportsNativeCallUiPlatform) {
      return (supported: false, granted: true);
    }
    try {
      final r = await _nativeCallUiChannel.invokeMapMethod<String, Object?>(
        'canUseFullScreenIntent',
      );
      return (
        supported: r?['supported'] == true,
        granted: r?['granted'] == true,
      );
    } catch (_) {
      return (supported: false, granted: true);
    }
  }

  Future<void> requestFullScreenIntentPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _nativeCallUiChannel.invokeMethod(
        'requestFullScreenIntentPermission',
      );
    } catch (_) {}
  }

  void minimizeActiveCallUi() {
    final s = state.value;
    if (!s.isActive) return;
    if (!s.isUiMinimized) {
      state.value = s.copyWith(isUiMinimized: true);
    }
    unawaited(_showOngoingCallNotification());
    _clearVisibleCallUi();
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.popUntil((route) {
        final name = route.settings.name;
        return name != '/call' && name != '/incoming-call';
      });
    }
  }

  void resumeCallUi() {
    final s = state.value;
    if (!s.isActive) return;
    if (s.isUiMinimized) {
      state.value = s.copyWith(isUiMinimized: false);
    }
    _pushCallScreen();
  }

  Future<void> toggleMute() async {
    final s = state.value;
    final next = !s.isMuted;
    await _session?.setAudioEnabled(!next);
    state.value = s.copyWith(isMuted: next);
  }

  bool _shouldUseRecoveryIceDelivery() {
    final phase = state.value.phase;
    return phase == CallPhase.reconnecting ||
        _awaitingRecoveryOffer ||
        _iceRestartInFlight ||
        _remoteVideoRecoveryInFlight;
  }

  Future<void> _sendCurrentCallIceCandidate({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) async {
    final snapshot = state.value;
    if (!snapshot.isActive ||
        snapshot.peerProfileId.isEmpty ||
        snapshot.callId.isEmpty) {
      return;
    }
    await controller.sendCallIceCandidate(
      peerProfileId: snapshot.peerProfileId,
      callId: snapshot.callId,
      callAttemptId: snapshot.callAttemptId,
      candidate: candidate,
      sdpMid: sdpMid,
      sdpMLineIndex: sdpMLineIndex,
      recovery: _shouldUseRecoveryIceDelivery(),
    );
  }

  Future<void> toggleSpeaker() async {
    final routeState = _audioRouteController.state.value;
    final speakerRoute = routeState.speakerRoute;
    final privateRoute = routeState.preferredPrivateRoute;

    // 🔴 СКАЗАТЬ, КАКОЙ ПУТЬ ВЫБРАН И ПОЧЕМУ (12.08.2026).
    //
    // Полевая жалоба «громкую не выключить» разбиралась вслепую: в логе не было
    // ни строки о маршруте, и понять, что переключатель ушёл в ОБХОДНУЮ ветку,
    // удалось только чтением кода. Обходная берётся когда маршруты не
    // перечислились — а именно это и надо было увидеть сразу.
    callLog(
      'CallManager',
      'toggleSpeaker path=${speakerRoute != null && privateRoute != null ? 'routes' : 'fallback'} '
          'hasSpeakerRoute=${speakerRoute != null} '
          'hasPrivateRoute=${privateRoute != null} '
          'routes=${routeState.availableRoutes.length} '
          'isSpeakerSelected=${routeState.isSpeakerSelected} '
          'stateIsSpeaker=${state.value.isSpeaker}',
    );

    if (speakerRoute != null && privateRoute != null) {
      final targetRoute = routeState.isSpeakerSelected
          ? privateRoute
          : speakerRoute;
      await selectAudioRoute(targetRoute.deviceId);
      return;
    }

    final s = state.value;
    final next = !s.isSpeaker;
    if (_session == null) {
      // Раньше это молча ничего не делало и оставляло состояние нетронутым.
      callLog('CallManager', 'toggleSpeaker: no session, ignored');
      return;
    }
    await _session?.setSpeakerEnabled(next);
    state.value = s.copyWith(isSpeaker: next);
  }

  Future<void> selectAudioRoute(String routeId) async {
    final current = state.value;
    if (!current.isActive) {
      return;
    }
    await _audioRouteController.selectRoute(
      routeId: routeId,
      preferSpeakerByDefault: current.isVideo,
      reason: 'call_ui_route_select',
    );
  }

  Future<void> toggleCamera() async {
    final s = state.value;
    if (!s.isVideo) return;
    final session = _session;
    if (session == null) return;
    final next = !s.isCameraOff;
    if (!next && !session.hasLocalVideoTrack) {
      try {
        await session.addVideoTrack();
        await session.renegotiate(
          video: true,
          onOffer: (sdp) async {
            _transitionLifecycle(
              CallLifecycleEvent.localOfferCreated,
              source: 'toggleCamera_enable_onOffer',
            );
            _lastLocalOfferSdp = sdp;
            await _sendCallOfferDeduped(
              peerProfileId: s.peerProfileId,
              callId: s.callId,
              callAttemptId: s.callAttemptId,
              video: true,
              sdp: sdp,
            );
          },
        );
      } catch (e) {
        await session.rollbackVideoUpgrade(keepReceivingRemoteVideo: true);
        if (!kReleaseMode) {
          debugPrint('toggleCamera enable failed: $e');
        }
        return;
      }
    }
    await session.setVideoEnabled(!next);
    state.value = s.copyWith(isCameraOff: next);
  }

  Future<void> switchCamera() async {
    final s = state.value;
    if (!s.isVideo) return;
    await _session?.switchCamera();
    state.value = s.copyWith(isFrontCamera: !s.isFrontCamera);
  }

  /// Upgrade audio → video (SDP renegotiation, no hangup).
  Future<void> upgradeToVideo() async {
    final s = state.value;
    if (s.isVideo) return;
    final session = _session;
    if (session == null) return;
    callOpLog(
      'CallManager',
      'video_upgrade_start',
      fields: <String, Object?>{
        'callId': s.callId,
        'callAttemptId': s.callAttemptId,
        'phase': s.phase,
      },
    );
    try {
      await session.addVideoTrack();
      final upgradedState = state.value;
      if (!upgradedState.isVideo ||
          upgradedState.isCameraOff ||
          !upgradedState.isSpeaker) {
        state.value = upgradedState.copyWith(
          isVideo: true,
          isSpeaker: true,
          isCameraOff: false,
        );
        await _syncAudioRoutesForCurrentCall(
          reason: 'upgrade_to_video',
          reapplyCurrentRoute: false,
        );
      }
      callOpLog(
        'CallManager',
        'video_upgrade_local_track_ready',
        fields: <String, Object?>{
          'callId': s.callId,
          'callAttemptId': s.callAttemptId,
        },
      );
      await session.renegotiate(
        video: true,
        onOffer: (sdp) async {
          _transitionLifecycle(
            CallLifecycleEvent.localOfferCreated,
            source: 'upgradeToVideo_onOffer',
          );
          _lastLocalOfferSdp = sdp;
          await _sendCallOfferDeduped(
            peerProfileId: s.peerProfileId,
            callId: s.callId,
            callAttemptId: s.callAttemptId,
            video: true,
            sdp: sdp,
          );
          callOpLog(
            'CallManager',
            'video_upgrade_offer_sent',
            fields: <String, Object?>{
              'callId': s.callId,
              'callAttemptId': s.callAttemptId,
            },
          );
        },
      );
    } catch (e) {
      await session.rollbackVideoUpgrade();
      final failedState = state.value;
      state.value = failedState.copyWith(
        isVideo: s.isVideo,
        isCameraOff: s.isCameraOff,
      );
      callOpLog(
        'CallManager',
        'video_upgrade_failed',
        fields: <String, Object?>{
          'callId': s.callId,
          'callAttemptId': s.callAttemptId,
          'error': e.runtimeType,
        },
      );
      if (!kReleaseMode) {
        debugPrint('upgradeToVideo failed: $e');
      }
    }
  }

  /// Toggle screen share on / off during an active video call.
  /// No SDP renegotiation is needed — the sender's track is replaced in-place.
  /// Returns true when the resulting state matches the intent (started or stopped).
  /// Returns false when starting was requested but permission was denied.
  Future<bool> toggleScreenShare() async {
    final s = state.value;
    if (!s.isActive) return false;
    final session = _session;
    if (session == null) return false;
    if (s.isScreenSharing) {
      await session.stopScreenShare();
      state.value = s.copyWith(isScreenSharing: false);
      return true;
    } else {
      final started = await session.startScreenShare();
      if (started) {
        state.value = s.copyWith(isScreenSharing: true);
        return true;
      }
      return false;
    }
  }

  void _handleSessionScreenShareStopped() {
    final snapshot = state.value;
    if (!snapshot.isScreenSharing) {
      return;
    }
    state.value = snapshot.copyWith(isScreenSharing: false);
  }

  // ── Signal handling ────────────────────────────────────────────────────

  Future<void> _onSignal(CallSignalEvent sig) async {
    final s = state.value;
    callLog(
      'CallManager',
      '_onSignal action=${sig.action} callId=${sig.callId} phase=${s.phase}',
    );
    callOpLog(
      'CallManager',
      'call_signal_received',
      fields: <String, Object?>{
        'action': sig.action,
        'callId': sig.callId,
        'callAttemptId': sig.callAttemptId,
        'signalId': sig.signalId,
        'phase': s.phase,
        'fromProfileId': sig.fromProfileId,
      },
    );

    switch (sig.action) {
      case 'invite':
        if (s.phase == CallPhase.ringingOutgoing &&
            s.peerProfileId == sig.fromProfileId) {
          // AUD-026: glare is resolved by whichever invite was initiated
          // earlier (real-world timing). Random callIds gave a statistically
          // unfair, order-of-generation-dependent result that did not
          // correspond to user intent. We compare `createdAtMs` first; if
          // the timestamps tie (rare), fall back to a deterministic lex
          // tiebreak on profile IDs so both peers reach the same verdict.
          final localStartedAt = s.startedAtMs ?? 0;
          final remoteStartedAt = sig.createdAtMs;
          bool keepOutgoing;
          if (localStartedAt > 0 && remoteStartedAt > 0) {
            if (localStartedAt < remoteStartedAt) {
              keepOutgoing = true;
            } else if (localStartedAt > remoteStartedAt) {
              keepOutgoing = false;
            } else {
              // Deterministic tiebreak consistent on both peers.
              keepOutgoing =
                  controller.profileId.compareTo(sig.fromProfileId) <= 0;
            }
          } else {
            // Legacy fallback — preserve prior behaviour so tests and any
            // unexpectedly zero-timestamp events still make progress.
            keepOutgoing = s.callId.compareTo(sig.callId) <= 0;
          }
          if (keepOutgoing) {
            await controller.sendCallDecline(
              peerProfileId: sig.fromProfileId,
              callId: sig.callId,
              callAttemptId: sig.callAttemptId,
            );
            callLog(
              'CallManager',
              'glare resolved: keep local outgoing callId=${s.callId}',
            );
            return;
          }

          callLog(
            'CallManager',
            'glare resolved: switch to remote incoming callId=${sig.callId}',
          );
          _ringTimer?.cancel();
          _connectTimer?.cancel();
          _answerResendTimer?.cancel();
          _answerResendTimer = null;
          _offerRequestTimer?.cancel();
          _offerRequestTimer = null;
          _awaitingRecoveryOffer = false;
          _pendingOfferSdp = null;
          _queuedOfferSdp = null;
          _pendingIceCandidates.clear();
          _isProcessingOffer = false;
          _lastOfferFingerprint = null;
          _lastOfferProcessedAtMs = 0;
          _answerResendAttempts = 0;
          _lastLocalAnswerSdp = null;
          _iceRestartAttempts = 0;
          await _stopRingtone();
          await _disposeSession();
          _transitionLifecycle(
            CallLifecycleEvent.localHangup,
            source: 'glare_resolution_abandon_outgoing',
          );
          _transitionLifecycle(
            CallLifecycleEvent.cleanupCompleted,
            source: 'glare_resolution_cleanup',
          );
          _transitionLifecycle(
            CallLifecycleEvent.reset,
            source: 'glare_resolution_reset',
          );
          // Clear the previous attempt payload so the incoming-setup below works.
          state.value = CallState.empty;
        }

        // Re-read state after potential glare resolution.
        final currentStateForInvite = state.value;
        if (currentStateForInvite.isActive) {
          // If this invite is for the call we're already handling
          // (offer arrived before invite — same attempt), just ignore.
          if (shouldIgnoreInviteForCurrentCall(
            currentCallId: currentStateForInvite.callId,
            currentCallAttemptId: currentStateForInvite.callAttemptId,
            inviteCallId: sig.callId,
            inviteCallAttemptId: sig.callAttemptId,
          )) {
            callLog(
              'CallManager',
              'invite for current call attempt callId=${sig.callId} callAttemptId=${sig.callAttemptId}; ignoring',
            );
            return;
          }
          // Busy — decline automatically.
          await controller.sendCallDecline(
            peerProfileId: sig.fromProfileId,
            callId: sig.callId,
            callAttemptId: sig.callAttemptId,
          );
          return;
        }
        // Guard: drop stale invites (relay can re-deliver up to 90s; ring
        // timeout is 45s, so anything older is a ghost call).
        final inviteAgeMs =
            DateTime.now().millisecondsSinceEpoch - sig.createdAtMs;
        if (inviteAgeMs > 45000) {
          callLog(
            'CallManager',
            'dropping stale invite age=${inviteAgeMs}ms callId=${sig.callId}',
          );
          return;
        }
        // Guard: ignore relay re-delivery of the invite from a call that already ended.
        if (shouldSuppressSignalForEndedCallAttempt(
          endedCallAttemptKeys: _lastEndedCallAttemptKeys,
          signalCallId: sig.callId,
          signalCallAttemptId: sig.callAttemptId,
        )) {
          callLog(
            'CallManager',
            'ignoring re-delivered invite for ended call attempt callId=${sig.callId} callAttemptId=${sig.callAttemptId}',
          );
          return;
        }
        // 🔴 ПРИГЛАШЕНИЕ ПО УЖЕ ЗАВЕРШЁННОЙ ПОПЫТКЕ (13.08.2026).
        //
        // Сигналы едут через ящик реле и приходят в ЛЮБОМ порядке: отбой может
        // обогнать приглашение. Раньше список завершённых попыток ПИСАЛСЯ в
        // нескольких местах и не читался НИГДЕ — то есть отметка ни на что не
        // влияла, и телефон звонил по отменённому звонку.
        final inviteAttemptKey = endedCallAttemptKey(
          callId: sig.callId,
          callAttemptId: sig.callAttemptId,
        );
        if (inviteAttemptKey.isNotEmpty &&
            _lastEndedCallAttemptKeys.contains(inviteAttemptKey)) {
          callOpLog(
            'CallManager',
            'invite_ignored_attempt_ended',
            fields: <String, Object?>{
              'callId': sig.callId,
              'callAttemptId': sig.callAttemptId,
            },
          );
          unawaited(_hideNativeIncomingUi());
          break;
        }

        // Show incoming UI immediately and enrich contact details asynchronously.
        callOpLog(
          'CallManager',
          'invite_received',
          fields: <String, Object?>{
            'callId': sig.callId,
            'callAttemptId': sig.callAttemptId,
            'fromProfileId': sig.fromProfileId,
            'isVideo': sig.media == CallMedia.video,
          },
        );
        // 🔴 НЕ ПОДСТАВЛЯЕМ profile_id ВМЕСТО ИМЕНИ (22.08.2026). Идентификатор
        // на экране разговора («3XBC-F5DJ-…») — это не имя, а признак того, что
        // резолв не отработал. Пустое имя экран и островок показывают как
        // «Входящий звонок», а настоящее подставит [_refreshIncomingPeerDetails]
        // строкой ниже — из контакта или из метаданных профиля.
        String peerName = '';
        String? peerAvatarPath;
        state.value = CallState(
          lifecycle: CallLifecycleState.incomingRinging,
          phase: CallPhase.ringingIncoming,
          callId: sig.callId,
          callAttemptId: sig.callAttemptId,
          direction: CallDirection.incoming,
          startedAtMs: sig.createdAtMs,
          peerProfileId: sig.fromProfileId,
          peerName: peerName,
          peerAvatarPath: peerAvatarPath,
          isVideo: sig.media == CallMedia.video,
          isSpeaker: sig.media == CallMedia.video,
          isCameraOff: sig.media == CallMedia.video,
          isUiMinimized: false,
        );
        if (_consumePendingNativeActionForCurrentRinging()) {
          break;
        }
        _setCallActive(true);
        await _presentIncomingCallSurface();
        _startRingTimeout();
        if (!_shouldSuppressFlutterIncomingRingtone()) {
          unawaited(_startRingtone(incoming: true));
        }
        unawaited(_refreshIncomingPeerDetails(sig.fromProfileId));
        // r11: prewarm WebRTC session in background while ringing.
        _prewarmIncomingSession(reason: 'invite_received');
        break;

      case 'offer':
        if (s.callId.isNotEmpty &&
            (s.isActive || s.phase == CallPhase.ringingIncoming) &&
            !shouldAcceptSignalForCurrentCall(
              currentCallId: s.callId,
              currentCallAttemptId: s.callAttemptId,
              signalCallId: sig.callId,
              signalCallAttemptId: sig.callAttemptId,
            )) {
          callLog(
            'CallManager',
            'dropping stale/mismatched offer signal callId=${sig.callId} callAttemptId=${sig.callAttemptId} currentCallId=${s.callId} currentCallAttemptId=${s.callAttemptId}',
          );
          return;
        }
        final sdp = sig.sdp;
        if (sdp == null || sdp.isEmpty) return;
        // Guard: ignore relay re-delivery of offer from a call that already ended.
        if (shouldSuppressSignalForEndedCallAttempt(
          endedCallAttemptKeys: _lastEndedCallAttemptKeys,
          signalCallId: sig.callId,
          signalCallAttemptId: sig.callAttemptId,
        )) {
          callLog(
            'CallManager',
            'ignoring re-delivered offer for ended call attempt callId=${sig.callId} callAttemptId=${sig.callAttemptId}',
          );
          return;
        }
        final fromProfileId = sig.fromProfileId.trim();

        if (!s.isActive && s.phase != CallPhase.ringingIncoming) {
          // Guard: same stale-age check as invite — offer-before-invite must
          // not create ghost incoming UX for delayed/replayed offers.
          final offerAgeMs =
              DateTime.now().millisecondsSinceEpoch - sig.createdAtMs;
          if (offerAgeMs > 45000) {
            callLog(
              'CallManager',
              'dropping stale offer-before-invite age=${offerAgeMs}ms callId=${sig.callId}',
            );
            return;
          }

          // Та же причина, что и в ветке приглашения: ни 'Unknown', ни сырой
          // profile_id именем не являются. Пустая строка → экран показывает
          // «Входящий звонок», а [_refreshIncomingPeerDetails] ниже подставит
          // настоящее имя из контакта или из метаданных профиля.
          String peerName = '';
          String? peerAvatarPath;

          state.value = CallState(
            lifecycle: CallLifecycleState.incomingRinging,
            phase: CallPhase.ringingIncoming,
            callId: sig.callId,
            callAttemptId: sig.callAttemptId,
            direction: CallDirection.incoming,
            startedAtMs: sig.createdAtMs,
            peerProfileId: fromProfileId,
            peerName: peerName,
            peerAvatarPath: peerAvatarPath,
            isVideo: sig.media == CallMedia.video,
            isSpeaker: sig.media == CallMedia.video,
            isCameraOff: sig.media == CallMedia.video,
            isUiMinimized: false,
          );
          _pendingOfferSdp = sdp;
          if (_consumePendingNativeActionForCurrentRinging()) {
            return;
          }
          await _presentIncomingCallSurface();
          _startRingTimeout();
          if (!_shouldSuppressFlutterIncomingRingtone()) {
            unawaited(_startRingtone(incoming: true));
          }
          if (fromProfileId.isNotEmpty) {
            unawaited(_refreshIncomingPeerDetails(fromProfileId));
          }
          callLog(
            'CallManager',
            'offer arrived before invite; synthesized incoming ringing state',
          );
          // r11: prewarm WebRTC session immediately so accept is instant.
          _prewarmIncomingSession(reason: 'offer_before_invite');
          return;
        }

        // Only treat the offer as a real video upgrade when the remote side is
        // actually requesting to send video, not merely advertising a recvonly
        // transceiver for future upgrade capability.
        final incomingHasVideo =
            sig.media == CallMedia.video ||
            WebRtcCallSession.remoteDescriptionRequestsSendingVideo(sdp);
        callLog(
          'CallManager',
          'offer: incomingHasVideo=$incomingHasVideo localIsVideo=${state.value.isVideo}',
        );
        if (incomingHasVideo &&
            !s.isVideo &&
            (s.phase == CallPhase.connecting ||
                s.phase == CallPhase.connected ||
                s.phase == CallPhase.reconnecting)) {
          state.value = s.copyWith(
            isVideo: true,
            isCameraOff: true,
            isSpeaker: true,
          );
          await _session?.setSpeakerEnabled(true);
        }
        // Ignore remote offer only when we are the side currently awaiting answer
        // for our own local offer (caller path). On incoming path we can be in
        // connecting phase while still waiting for first/resent offer.
        if (shouldIgnoreIncomingOffer(
          phase: s.phase,
          awaitingRemoteAnswer: false,
        )) {
          callLog(
            'CallManager',
            'ignoring remote offer during outgoing ringing',
          );
          return;
        }
        if (shouldBufferIncomingOfferUntilExplicitAccept(s.phase)) {
          _pendingOfferSdp = sdp;
          if (incomingHasVideo && !s.isVideo) {
            state.value = s.copyWith(
              isVideo: true,
              isCameraOff: true,
              isSpeaker: true,
            );
          }
          callLog(
            'CallManager',
            'incoming offer buffered until explicit accept call=${sig.callId} callAttemptId=${sig.callAttemptId}',
          );
          return;
        }
        final offerSession = _session;
        var shouldResolveGlare = false;
        if (offerSession != null) {
          final awaitingRemoteAnswer = await offerSession
              .isAwaitingRemoteAnswer();
          shouldResolveGlare = shouldResolveOfferGlareInActiveCall(
            phase: s.phase,
            awaitingRemoteAnswer: awaitingRemoteAnswer,
          );
          if (shouldIgnoreIncomingOffer(
            phase: s.phase,
            awaitingRemoteAnswer: awaitingRemoteAnswer,
          )) {
            callLog(
              'CallManager',
              'ignoring remote offer while awaiting answer in signaling state',
            );
            return;
          }
        }
        if (!s.isActive && s.phase != CallPhase.ringingIncoming) {
          callLog(
            'CallManager',
            'ignoring remote offer while call is not active (phase=${s.phase})',
          );
          return;
        }
        if (shouldResolveGlare) {
          // GLARE-FIX (perfect negotiation, 2026-05-16):
          // Both peers can land here simultaneously after a network change —
          // each creates a fresh local offer, then receives the other's
          // offer while in signalingState=have-local-offer. Without a tie-
          // breaker, both try to rollback + apply remote → bounce →
          // CONNECTING→CLOSED loop. We pick a polite/impolite designation
          // from profileIds so exactly one side yields.
          final polite = isPoliteFor(
            localProfileId: controller.profileId,
            remoteProfileId: s.peerProfileId,
          );
          DiagLog.event('call', 'glare.remote_offer', <String, Object?>{
            'callId': DiagLog.pfx(s.callId),
            'phase': s.phase,
            'role': polite ? 'polite' : 'impolite',
            'action': polite ? 'rollback_and_accept' : 'ignore',
          });
          if (!polite) {
            callLog(
              'CallManager',
              'glare: impolite peer ignoring remote offer (our local offer wins) callId=${s.callId}',
            );
            return;
          }
          callLog(
            'CallManager',
            'glare: polite peer rolling back local offer to accept remote callId=${s.callId}',
          );
          _clearPendingLocalOfferTracking(reason: 'remote_offer_glare');
        }
        await _handleIncomingOffer(sdp);
        break;

      case 'need_offer':
        if (!shouldAcceptSignalForCurrentCall(
          currentCallId: s.callId,
          currentCallAttemptId: s.callAttemptId,
          signalCallId: sig.callId,
          signalCallAttemptId: sig.callAttemptId,
        )) {
          return;
        }
        if (!shouldHandleIncomingNeedOffer(
          direction: s.direction,
          phase: s.phase,
        )) {
          return;
        }
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - _lastNeedOfferHandledAtMs < 1000) {
          return;
        }
        if (shouldDeferNeedOfferDuringOutgoingBootstrap(
          phase: s.phase,
          outgoingOfferBootstrapInFlight: _outgoingOfferBootstrapInFlight,
        )) {
          callLog(
            'CallManager',
            'deferring need_offer because outgoing bootstrap is already creating the initial offer',
          );
          return;
        }
        _lastNeedOfferHandledAtMs = nowMs;
        callLog('CallManager', 'received need_offer; resending fresh offer');
        await _resendOfferRecovery(reason: 'remote_need_offer');
        break;

      case 'answer':
        if (!shouldAcceptSignalForCurrentCall(
          currentCallId: s.callId,
          currentCallAttemptId: s.callAttemptId,
          signalCallId: sig.callId,
          signalCallAttemptId: sig.callAttemptId,
        )) {
          return;
        }
        final sdp = sig.sdp;
        if (sdp == null || sdp.isEmpty) return;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final answerFingerprint = '${sdp.length}:${sdp.hashCode}';
        if (_lastRemoteAnswerFingerprint == answerFingerprint &&
            nowMs - _lastRemoteAnswerProcessedAtMs < 8000) {
          callLog('CallManager', 'deduped repeated remote answer');
          return;
        }
        final session = _session;
        if (session == null) {
          _pendingRemoteAnswerSdp = sdp;
          callLog(
            'CallManager',
            'answer arrived before session ready; buffered for retry',
          );
          return;
        }
        final awaitingAnswer = await session.isAwaitingRemoteAnswer();
        final shouldApplyAnswer = shouldApplyRemoteAnswer(
          awaitingRemoteAnswer: awaitingAnswer,
          hasRemoteDescription: session.hasRemoteDescription,
          hasPendingLocalOffer: _lastLocalOfferSdp?.isNotEmpty ?? false,
        );
        if (!shouldApplyAnswer) {
          _lastRemoteAnswerFingerprint = answerFingerprint;
          _lastRemoteAnswerProcessedAtMs = nowMs;
          callLog(
            'CallManager',
            'ignoring late/duplicate remote answer while signaling is not awaiting',
          );
          return;
        }
        if (!awaitingAnswer) {
          callLog(
            'CallManager',
            'applying remote answer despite signaling drift because a local offer is still pending',
          );
        }
        _ringTimer?.cancel();
        await _stopRingtone();
        if (shouldStartConnectingToneForRemoteAnswer(phase: s.phase)) {
          _transitionLifecycle(
            CallLifecycleEvent.remoteAnswerReceived,
            source: 'signal_answer',
          );
          _startConnectTimeout();
          unawaited(_startConnectingTone());
        } else if (s.phase == CallPhase.reconnecting) {
          _transitionLifecycle(
            CallLifecycleEvent.remoteAnswerReceived,
            source: 'signal_answer_reconnect',
          );
        }
        try {
          await session.applyRemoteAnswer(sdp);
          _lastRemoteAnswerFingerprint = answerFingerprint;
          _lastRemoteAnswerProcessedAtMs = nowMs;
          _lastLocalOfferSdp = null;
          _pendingRemoteAnswerSdp = null;
          _stopNeedOfferRetries();
          _resyncConnectedFromCurrentSession(
            source: 'signal_answer_after_apply',
          );
          // 🔴 ГАСИМ ЗВОНОК НА ОСТАЛЬНЫХ УСТРОЙСТВАХ СОБЕСЕДНИКА (11.09.2026).
          //
          // С правкой В-1 приглашение уходит ВСЕМ устройствам. Ответили на
          // одном — остальные обязаны замолчать, иначе у человека продолжает
          // звонить телефон, пока он уже говорит с ноутбука.
          //
          // Ставится ПОСЛЕ успешного применения ответа: пока разговор не
          // состоялся, гасить соседей не за что. Отправка на устройство, где
          // ответили, исключена внутри — иначе оборвали бы сам разговор.
          //
          // Лучшее усилие: неудача здесь не имеет права уронить разговор,
          // худший исход — сосед дозвонит до своего таймаута, как и раньше.
          // 🔴 Без устройства-ответчика НЕ шлём ничего: не зная, кого исключить,
          // мы оборвали бы сам разговор.
          final answeredDevice = (sig.fromDeviceId ?? '').trim();
          if (answeredDevice.isNotEmpty) {
            unawaited(
              controller
                  .sendCallHangupToOtherDevices(
                    peerProfileId: s.peerProfileId,
                    callId: s.callId,
                    callAttemptId: s.callAttemptId,
                    answeredDeviceId: answeredDevice,
                  )
                  .catchError((Object e) {
                    callLog(
                      'CallManager',
                      'silence-other-devices failed (best-effort): $e',
                    );
                  }),
            );
          }
        } catch (e) {
          _pendingRemoteAnswerSdp = sdp;
          callLog(
            'CallManager',
            'applyRemoteAnswer failed (buffered for retry): $e',
          );
        }
        // Will transition to connected via ICE listener.
        break;

      case 'ice':
        final matchesCurrentCall = shouldAcceptSignalForCurrentCall(
          currentCallId: s.callId,
          currentCallAttemptId: s.callAttemptId,
          signalCallId: sig.callId,
          signalCallAttemptId: sig.callAttemptId,
        );
        if (s.callId.isNotEmpty &&
            !matchesCurrentCall &&
            (s.isActive || _session != null)) {
          return;
        }
        // Guard: ignore ICE for ended calls.
        if (shouldSuppressSignalForEndedCallAttempt(
          endedCallAttemptKeys: _lastEndedCallAttemptKeys,
          signalCallId: sig.callId,
          signalCallAttemptId: sig.callAttemptId,
        )) {
          return;
        }
        final candidate = sig.candidate;
        if (candidate == null || candidate.isEmpty) return;
        // Buffer ICE if session not ready yet (ringing).
        if (_session == null) {
          if (s.callId.isNotEmpty && !matchesCurrentCall) return;
          if (_pendingIceCandidates.length >= 128) {
            _pendingIceCandidates.removeAt(0);
          }
          _pendingIceCandidates.add(sig);
          return;
        }
        await _session?.addRemoteIceCandidate(
          candidate: candidate,
          sdpMid: sig.sdpMid,
          sdpMLineIndex: sig.sdpMLineIndex,
        );
        break;

      case 'decline':
        if (shouldAcceptSignalForCurrentCall(
          currentCallId: s.callId,
          currentCallAttemptId: s.callAttemptId,
          signalCallId: sig.callId,
          signalCallAttemptId: sig.callAttemptId,
        )) {
          await _endCall(CallEndReason.remoteDecline);
        }
        break;

      case 'hangup':
        if (shouldAcceptSignalForCurrentCall(
          currentCallId: s.callId,
          currentCallAttemptId: s.callAttemptId,
          signalCallId: sig.callId,
          signalCallAttemptId: sig.callAttemptId,
        )) {
          await _endCall(CallEndReason.remoteHangup);
        } else {
          // 🔴 ОТБОЙ, ПРИШЕДШИЙ РАНЬШЕ ПРИГЛАШЕНИЯ (13.08.2026).
          //
          // Сигналы едут через ящик реле и приходят в ЛЮБОМ порядке. Если отбой
          // обогнал приглашение, он сверяется с ПУСТЫМ состоянием, не совпадает
          // и молча отбрасывается — а следом приезжает приглашение, и телефон
          // звонит по звонку, который звонящий уже отменил. Ровно то, что
          // владелец описал как «островок не уходит после отмены».
          //
          // Запоминаем попытку завершённой: тот же список, которым гасятся
          // протухшие подсказки, и приглашение по нему будет отвергнуто.
          _rememberEndedCallAttempt(
            callId: sig.callId,
            callAttemptId: sig.callAttemptId,
            reason: 'hangup_before_invite',
          );
        }
        break;
    }
  }

  bool _isAwaitingRemoteOfferLocally() {
    if (_pendingOfferSdp?.isNotEmpty ?? false) {
      return false;
    }
    if (_awaitingRecoveryOffer) {
      return true;
    }
    final session = _session;
    if (session == null) {
      return true;
    }
    return !session.hasRemoteDescription;
  }

  Future<bool> _isAwaitingRemoteAnswerLocally() async {
    if (_pendingRemoteAnswerSdp?.isNotEmpty ?? false) {
      return false;
    }
    final session = _session;
    if (session == null) {
      return true;
    }
    final awaitingAnswer = await session.isAwaitingRemoteAnswer();
    return shouldApplyRemoteAnswer(
      awaitingRemoteAnswer: awaitingAnswer,
      hasRemoteDescription: session.hasRemoteDescription,
      hasPendingLocalOffer: _lastLocalOfferSdp?.isNotEmpty ?? false,
    );
  }

  Future<void> _requestOfferRecovery({required String reason}) async {
    final current = state.value;
    if (!current.isActive ||
        current.peerProfileId.isEmpty ||
        current.callId.isEmpty) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastOfferRecoveryRequestAtMs < 1200) {
      return;
    }
    _lastOfferRecoveryRequestAtMs = nowMs;
    _awaitingRecoveryOffer = true;
    callLog(
      'CallManager',
      'requesting offer recovery reason=$reason callId=${current.callId}',
    );
    // 🔴 СТРАХОВКА ВКЛЮЧАЛАСЬ ТОЛЬКО ПРИ УСПЕХЕ (24.08.2026).
    //
    // Повторы `need_offer` (8 попыток раз в 2 с) запускались ЛИШЬ когда первая
    // отправка прошла — то есть ровно тогда, когда они не нужны. Стоило первой
    // отправке упасть (24.08 — `fetchBundle failed: 429 rate_limited` от
    // сервера ключей, бакет которого делят два устройства за одним IP), как
    // звонок оставался без единого повтора: принявшая сторона показывала экран
    // разговора, а звонящий продолжал слушать гудки до самого таймаута.
    //
    // Повторы обязаны идти ИМЕННО при провале: причина почти всегда временная,
    // а бакет сервера восстанавливается за секунду. Сами повторы
    // самоограничены (`shouldKeepNeedOfferRetriesRunning` + потолок попыток),
    // поэтому запуск после ошибки не превращается в шторм.
    try {
      await controller.sendCallNeedOffer(
        peerProfileId: current.peerProfileId,
        callId: current.callId,
        callAttemptId: current.callAttemptId,
      );
    } catch (e) {
      callLog('CallManager', 'offer recovery request failed: $e');
    } finally {
      _startNeedOfferRetries();
    }
  }

  Future<void> _resendOfferRecovery({required String reason}) async {
    final current = state.value;
    if (!current.isActive ||
        current.peerProfileId.isEmpty ||
        current.callId.isEmpty) {
      return;
    }
    callLog(
      'CallManager',
      'resending offer for recovery reason=$reason callId=${current.callId}',
    );
    final existingSession = _session;
    try {
      final shouldUseFreshTransport =
          existingSession == null ||
          shouldUseFreshTransportRecovery(
            phase: current.phase,
            wasEverConnected: current.connectedAtMs != null,
            isVideo: current.isVideo,
            isCameraOff: current.isCameraOff,
            isScreenSharing: current.isScreenSharing,
            priorIceRestartAttempts: _iceRestartAttempts,
            preferHardRecovery: true,
          );
      if (shouldUseFreshTransport) {
        await _startRecoveryOfferWithFreshSession(
          snapshot: current,
          reason: reason,
          source: '_resendOfferRecovery_fresh_session',
        );
        return;
      }
      final awaitingRemoteAnswer = await existingSession
          .isAwaitingRemoteAnswer();
      if (awaitingRemoteAnswer && (_lastLocalOfferSdp?.isNotEmpty ?? false)) {
        await _sendCallOfferDeduped(
          peerProfileId: current.peerProfileId,
          callId: current.callId,
          callAttemptId: current.callAttemptId,
          video: current.isVideo,
          sdp: _lastLocalOfferSdp!,
        );
        return;
      }
      await existingSession.restartIce(
        video: current.isVideo,
        onOffer: (sdp) async {
          _transitionLifecycle(
            CallLifecycleEvent.localOfferCreated,
            source: '_resendOfferRecovery_restartIce',
          );
          _lastLocalOfferSdp = sdp;
          await _sendCallOfferDeduped(
            peerProfileId: current.peerProfileId,
            callId: current.callId,
            callAttemptId: current.callAttemptId,
            video: current.isVideo,
            sdp: sdp,
          );
        },
      );
    } catch (e) {
      callLog('CallManager', 'offer recovery resend failed: $e');
    }
  }

  Future<bool> _reconcileActiveCallWithRelay({required String trigger}) async {
    final current = state.value;
    if (!controller.relayOnline ||
        !current.isActive ||
        current.callId.isEmpty ||
        _relaySessionReconcileInFlight) {
      return false;
    }
    final callId = current.callId;
    final callAttemptId = current.callAttemptId.isEmpty
        ? current.callId
        : current.callAttemptId;
    final reconcileStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    _relaySessionReconcileInFlight = true;
    try {
      final snapshot = await controller.fetchRelayCallSession(
        callId: callId,
        callAttemptId: callAttemptId,
      );
      final latest = state.value;
      if (snapshot == null ||
          !latest.isActive ||
          latest.callId != callId ||
          (latest.callAttemptId.isNotEmpty &&
              latest.callAttemptId != callAttemptId)) {
        return false;
      }
      callLog(
        'CallManager',
        'relay reconcile trigger=$trigger exists=${snapshot.exists} state=${snapshot.state} lastAction=${snapshot.lastAction} callId=$callId',
      );
      if (!snapshot.exists) {
        if (shouldTreatMissingRelaySessionAsTransient(
          callId: callId,
          callAttemptId: callAttemptId,
          lastObservedCallId: _lastObservedRelaySessionCallId,
          lastObservedCallAttemptId: _lastObservedRelaySessionAttemptId,
          lastObservedState: _lastObservedRelaySessionState,
          lastObservedAtMs: _lastObservedRelaySessionAtMs,
          nowMs: reconcileStartedAtMs,
        )) {
          _consecutiveMissingRelaySessions = 0;
          _lastMissingRelaySessionAttemptId = callAttemptId;
          callLog(
            'CallManager',
            'relay reconcile treating missing session as transient after recent authoritative state=$_lastObservedRelaySessionState callId=$callId',
          );
          return false;
        }
        if (_lastMissingRelaySessionAttemptId != callAttemptId) {
          _lastMissingRelaySessionAttemptId = callAttemptId;
          _consecutiveMissingRelaySessions = 0;
        }
        _consecutiveMissingRelaySessions++;
        callLog(
          'CallManager',
          'relay reconcile missing session trigger=$trigger misses=$_consecutiveMissingRelaySessions callId=$callId',
        );
        final recentConnectivityRecovery =
            _hasRecentConnectivityRecoveryForSnapshot(
              latest,
              nowMs: reconcileStartedAtMs,
            );
        final pendingConnectivityRecovery =
            _connectivityHandoffRecoveryTimer != null ||
            _queuedConnectivityHandoffRecovery;
        if (shouldTerminateAfterMissingRelaySession(
          phase: latest.phase,
          consecutiveMisses: _consecutiveMissingRelaySessions,
          wasEverConnected: latest.connectedAtMs != null,
          recentConnectivityRecovery: recentConnectivityRecovery,
          pendingConnectivityRecovery: pendingConnectivityRecovery,
        )) {
          callLog(
            'CallManager',
            'ending call after repeated missing relay session truth callId=$callId',
          );
          await _endCall(CallEndReason.error);
          return true;
        }
        return false;
      }
      _lastObservedRelaySessionCallId = callId;
      _lastObservedRelaySessionAttemptId = callAttemptId;
      _lastObservedRelaySessionState = snapshot.state ?? '';
      _lastObservedRelaySessionAtMs = reconcileStartedAtMs;
      _consecutiveMissingRelaySessions = 0;
      _lastMissingRelaySessionAttemptId = '';
      if (shouldPromoteConnectingFromRelayAccepted(
        direction: latest.direction,
        phase: latest.phase,
        snapshot: snapshot,
      )) {
        _ringTimer?.cancel();
        await _stopRingtone();
        _transitionLifecycle(
          CallLifecycleEvent.remoteAnswerReceived,
          source: 'relay_${trigger}_accepted',
        );
        _startConnectTimeout();
        unawaited(_startConnectingTone());
      }
      final promotedState = state.value;
      final session = _session;
      if (shouldPromoteReconnectingFromRelay(
        phase: promotedState.phase,
        wasEverConnected: promotedState.connectedAtMs != null,
        snapshot: snapshot,
        rtcState: session?.connectionState.value,
        iceState: session?.iceConnectionState.value,
        mediaEstablished: session?.mediaEstablished.value ?? false,
      )) {
        _transitionLifecycle(
          CallLifecycleEvent.peerconnectionFailed,
          source: 'relay_${trigger}_reconnecting',
        );
        _ensureReconnectWatchdog();
      }
      final latestAfterRelayPromotion = state.value;
      final endReason = relayTerminalEndReason(snapshot);
      if (endReason != null) {
        if (endReason == CallEndReason.remoteSuperseded) {
          callLog(
            'CallManager',
            'ending local attempt because relay marked it superseded callId=$callId callAttemptId=$callAttemptId',
          );
        }
        await _endCall(endReason);
        return true;
      }
      if (shouldRequestOfferRecoveryFromRelay(
        direction: latestAfterRelayPromotion.direction,
        phase: latestAfterRelayPromotion.phase,
        awaitingRemoteOfferLocally: _isAwaitingRemoteOfferLocally(),
        snapshot: snapshot,
      )) {
        await _requestOfferRecovery(reason: 'relay_$trigger');
        return true;
      }
      if (shouldResendOfferRecoveryFromRelay(
        direction: latestAfterRelayPromotion.direction,
        phase: latestAfterRelayPromotion.phase,
        awaitingRemoteAnswerLocally: await _isAwaitingRemoteAnswerLocally(),
        snapshot: snapshot,
      )) {
        await _resendOfferRecovery(reason: 'relay_$trigger');
        return true;
      }
      return false;
    } finally {
      _relaySessionReconcileInFlight = false;
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────

  /// Process an incoming SDP offer (create session, set remote desc, send answer).
  Future<void> _processOffer(String sdp) async {
    callLog('CallManager', '_processOffer start, sdp length=${sdp.length}');
    _transitionLifecycle(
      CallLifecycleEvent.remoteOfferReceived,
      source: '_processOffer_start',
    );
    _awaitingRecoveryOffer = false;
    _stopNeedOfferRetries();
    final session = await _createSession();
    // Renegotiation during an active call must not demote the UI back to
    // connecting or restart the initial 30 s watchdog.
    if (shouldRestartConnectingForIncomingOffer(state.value.phase) &&
        state.value.phase != CallPhase.connecting) {
      _startConnectTimeout();
    }
    try {
      await session.startIncomingFromOffer(
        video: state.value.isVideo && !state.value.isCameraOff,
        remoteOfferSdp: sdp,
        onAnswer: (answerSdp) async {
          _transitionLifecycle(
            CallLifecycleEvent.localAnswerCreated,
            source: '_processOffer_onAnswer',
          );
          _lastLocalAnswerSdp = answerSdp;
          _startAnswerResend();
          // Signaling failure must NOT kill the WebRTC session.
          try {
            await controller.sendCallAnswer(
              peerProfileId: state.value.peerProfileId,
              callId: state.value.callId,
              callAttemptId: state.value.callAttemptId,
              sdp: answerSdp,
            );
            callOpLog(
              'CallManager',
              'local_answer_sent',
              fields: <String, Object?>{
                'callId': state.value.callId,
                'callAttemptId': state.value.callAttemptId,
              },
            );
            callLog('CallManager', 'answer sent OK');
          } catch (e) {
            // 🔴 УСПЕХ БЫЛ ВИДЕН, ОТКАЗ — НЕТ. Ровно в том месте, о котором
            // жалоба: `local_answer_sent` печатался операционным событием, а
            // отказ уходил свободным текстом, который в релизе отбрасывается.
            // Тип ошибки, а не её текст: текст может нести чужие данные.
            callOpLog(
              'CallManager',
              'local_answer_send_failed',
              fields: <String, Object?>{
                'error': e.runtimeType,
                'callId': state.value.callId,
                'callAttemptId': state.value.callAttemptId,
              },
            );
            callLog('CallManager', 'sendCallAnswer failed (non-fatal): $e');
          }
        },
        onIceCandidate: (c, mid, idx) async {
          try {
            await _sendCurrentCallIceCandidate(
              candidate: c,
              sdpMid: mid,
              sdpMLineIndex: idx,
            );
          } catch (e) {
            callLog(
              'CallManager',
              'sendCallIceCandidate failed (non-fatal): $e',
            );
          }
        },
      );
      await _syncAudioRoutesForCurrentCall(
        reason: 'process_offer_session_ready',
        reapplyCurrentRoute: true,
      );
      _stopNeedOfferRetries();
      _resyncConnectedFromCurrentSession(source: 'process_offer_done_resync');
      callLog('CallManager', '_processOffer completed OK');
    } catch (e, stack) {
      callLog('CallManager', '_processOffer FAILED: $e\n$stack');
      final currentPhase = state.value.phase;
      final wasEverConnected = state.value.connectedAtMs != null;
      if (shouldRecoverOfferProcessingFailure(
        phase: currentPhase,
        wasEverConnected: wasEverConnected,
      )) {
        if (currentPhase == CallPhase.connected) {
          _transitionLifecycle(
            CallLifecycleEvent.peerconnectionFailed,
            source: '_processOffer_error',
          );
        }
        _ensureReconnectWatchdog();
        final reconciled = await _reconcileActiveCallWithRelay(
          trigger: 'offer_processing_error',
        );
        if (!reconciled) {
          await _requestOfferRecovery(reason: 'offer_processing_error');
        }
        callLog(
          'CallManager',
          'offer processing error converted to recovery phase=$currentPhase wasEverConnected=$wasEverConnected',
        );
        return;
      }
      await _failCallAndNotifyRemote(error: e, stackTrace: stack);
    }
  }

  Future<void> _sendCallOfferDeduped({
    required String peerProfileId,
    required String callId,
    required String callAttemptId,
    required bool video,
    required String sdp,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (shouldSuppressDuplicateLocalOfferSend(
      previousCallId: _lastSentOfferCallId,
      previousCallAttemptId: _lastSentOfferCallAttemptId,
      previousFingerprint: _lastSentOfferFingerprint ?? '',
      previousSentAtMs: _lastSentOfferAtMs,
      callId: callId,
      callAttemptId: callAttemptId,
      sdp: sdp,
      nowMs: nowMs,
    )) {
      callLog('CallManager', 'suppressed duplicate local offer send');
      return;
    }

    final fingerprint = '${sdp.length}:${sdp.hashCode}';
    _lastSentOfferCallId = callId;
    _lastSentOfferCallAttemptId = callAttemptId;
    _lastSentOfferFingerprint = fingerprint;
    _lastSentOfferAtMs = nowMs;

    try {
      await controller.sendCallOffer(
        peerProfileId: peerProfileId,
        callId: callId,
        callAttemptId: callAttemptId,
        video: video,
        sdp: sdp,
      );
    } catch (_) {
      if (_lastSentOfferCallId == callId &&
          _lastSentOfferCallAttemptId == callAttemptId &&
          _lastSentOfferFingerprint == fingerprint &&
          _lastSentOfferAtMs == nowMs) {
        _lastSentOfferCallId = '';
        _lastSentOfferCallAttemptId = '';
        _lastSentOfferFingerprint = null;
        _lastSentOfferAtMs = 0;
      }
      rethrow;
    }
  }

  void _clearPendingLocalOfferTracking({required String reason}) {
    _lastLocalOfferSdp = null;
    _pendingRemoteAnswerSdp = null;
    _stopNeedOfferRetries();
    _lastSentOfferFingerprint = null;
    _lastSentOfferCallId = '';
    _lastSentOfferCallAttemptId = '';
    _lastSentOfferAtMs = 0;
    callOpLog(
      'CallManager',
      'local_offer_abandoned',
      fields: <String, Object?>{
        'callId': state.value.callId,
        'callAttemptId': state.value.callAttemptId,
        'reason': reason,
      },
    );
  }

  Future<void> _handleIncomingOffer(String sdp) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final fingerprint = '${sdp.length}:${sdp.hashCode}';
    if (_lastOfferFingerprint == fingerprint &&
        nowMs - _lastOfferProcessedAtMs < 4000) {
      callLog('CallManager', 'deduped repeated offer');
      return;
    }

    if (_isProcessingOffer) {
      _queuedOfferSdp = sdp;
      callLog('CallManager', 'queued offer while previous offer is processing');
      return;
    }

    _isProcessingOffer = true;
    try {
      var currentSdp = sdp;
      while (true) {
        await _processOffer(currentSdp);
        _lastOfferFingerprint = '${currentSdp.length}:${currentSdp.hashCode}';
        _lastOfferProcessedAtMs = DateTime.now().millisecondsSinceEpoch;

        final queued = _queuedOfferSdp;
        _queuedOfferSdp = null;
        if (queued == null || queued == currentSdp) {
          break;
        }
        currentSdp = queued;
      }
    } finally {
      _isProcessingOffer = false;
    }
  }

  Future<WebRtcCallSession> _createSession({
    bool forceNew = false,
    bool forceIceRefresh = false,
  }) async {
    final existing = _session;
    if (!forceNew && existing != null) {
      final connState = existing.connectionState.value;
      // Bug fix: "not yet Closed" alone isn't enough to reuse — a session
      // whose owning call already ended can still be mid-teardown (async
      // dispose) when a fresh call starts right after a quick hang-up +
      // redial. Reusing it silently carries over its actual WebRTC audio
      // track state (e.g. still-muted) even though the new CallState
      // correctly shows isMuted=false, so the peer doesn't hear the user.
      // Only reuse when the session is still tagged for the SAME call
      // attempt we're setting up right now.
      final currentSnapshot = state.value;
      final expectedAttemptId = currentSnapshot.callAttemptId.isNotEmpty
          ? currentSnapshot.callAttemptId
          : currentSnapshot.callId;
      final sameCallAttempt =
          expectedAttemptId.isEmpty ||
          existing.debugCallAttemptId.isEmpty ||
          existing.debugCallAttemptId == expectedAttemptId;
      if (connState != RTCPeerConnectionState.RTCPeerConnectionStateClosed &&
          sameCallAttempt) {
        return existing;
      }
      await _disposeSession();
    } else if (forceNew && existing != null) {
      await _disposeSession();
    }
    // r11: dedup concurrent createSession requests (e.g. prewarm + accept).
    if (!forceNew) {
      final inFlight = _sessionInFlight;
      if (inFlight != null) {
        return inFlight;
      }
    }
    final future = _createSessionInternal(forceIceRefresh: forceIceRefresh);
    _sessionInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_sessionInFlight, future)) {
        _sessionInFlight = null;
      }
    }
  }

  Future<WebRtcCallSession> _createSessionInternal({
    required bool forceIceRefresh,
  }) async {
    final session = WebRtcCallSession();
    final fetchedIceConfig = await _getCallIceConfigForRecovery(
      forceRefresh: forceIceRefresh,
    );
    // SEC-10: проверка ДО подстановки — см. пояснение выше по файлу.
    final iceConfigError = validateIceConfigForSession(fetchedIceConfig);
    if (iceConfigError != null) {
      throw CallFailure(
        CallFailureCode.iceConfigUnavailable,
        message: iceConfigError,
      );
    }
    final iceConfig = _optimizeIceConfigForConnectivity(
      _augmentIceConfigWithFallback(
        fetchedIceConfig,
        relayBaseUrl: controller.relayHttpBaseUrl,
      ),
      source: 'create_session',
    );
    await session.initializeRenderers();
    final snapshot = state.value;
    session.attachDebugContext(
      callId: snapshot.callId,
      callAttemptId: snapshot.callAttemptId.isEmpty
          ? snapshot.callId
          : snapshot.callAttemptId,
    );
    session.configureIce(
      iceServers: iceConfig.toRtcIceServers(),
      iceTransportPolicy: iceConfig.rtcIceTransportPolicy,
      networkPolicy: iceConfig.policy,
    );
    // BUG-FIX (ICE-STALE-CACHE 2026-05-29) — production observability.
    // Surface the «we are starting a call without any TURN relay
    // available» condition so a recurring NAT-traversal failure is
    // visible in operational telemetry instead of silently degrading
    // to «call connects but no audio/video». A single missing TURN
    // server here is the strongest predictor of an upcoming ICE
    // failure between two NAT'd peers.
    if (!iceConfig.hasUsableRelayServers) {
      DiagLog.event('call', 'ice_no_turn_servers', <String, Object?>{
        'callId': DiagLog.pfx(snapshot.callId),
        'policy': iceConfig.policy.name,
        'totalIceServers': iceConfig.iceServers.length,
        'stunOnly': iceConfig.iceServers
            .every((server) => server.isStun),
        'forceIceRefresh': forceIceRefresh,
      });
    }
    session.onScreenShareStopped = _handleSessionScreenShareStopped;
    await session.setSpeakerEnabled(state.value.isSpeaker);
    _session = session;
    _bindConnectionListener(session);
    return session;
  }

  /// r11: Eagerly create the WebRTC session as soon as we know an incoming
  /// call exists (invite or buffered offer received), before the user taps
  /// accept. Cuts 200–1500 ms off the post-accept critical path because the
  /// peer connection, ICE config fetch and renderers are all ready when
  /// [acceptIncoming] runs.
  void _prewarmIncomingSession({required String reason}) {
    final s = state.value;
    if (s.phase != CallPhase.ringingIncoming) return;
    final key = '${s.callId}::${s.callAttemptId}';
    if (key == '::') return;
    if (_prewarmedCallAttemptKey == key) return;
    if (_session != null || _sessionInFlight != null) {
      _prewarmedCallAttemptKey = key;
      return;
    }
    _prewarmedCallAttemptKey = key;
    callOpLog(
      'CallManager',
      'incoming_session_prewarm_start',
      fields: <String, Object?>{
        'callId': s.callId,
        'callAttemptId': s.callAttemptId,
        'reason': reason,
      },
    );
    unawaited(() async {
      try {
        await _createSession();
        callOpLog(
          'CallManager',
          'incoming_session_prewarm_done',
          fields: <String, Object?>{
            'callId': s.callId,
            'callAttemptId': s.callAttemptId,
            'reason': reason,
          },
        );
      } catch (e) {
        // Non-fatal — acceptIncoming will retry through the normal path.
        callLog('CallManager', 'prewarm session failed (non-fatal): $e');
        if (_prewarmedCallAttemptKey == key) {
          _prewarmedCallAttemptKey = '';
        }
      }
    }());
  }

  Future<void> _restoreRecoverySessionPreferences(
    WebRtcCallSession session,
    CallState snapshot,
  ) async {
    try {
      await session.setSpeakerEnabled(snapshot.isSpeaker);
    } catch (e) {
      callLog('CallManager', 'recovery speaker restore failed: $e');
    }
    try {
      await session.setAudioEnabled(!snapshot.isMuted);
    } catch (e) {
      callLog('CallManager', 'recovery mute restore failed: $e');
    }
    if (!snapshot.isVideo) {
      return;
    }
    if (!snapshot.isFrontCamera && session.hasLocalVideoTrack) {
      try {
        await session.switchCamera();
      } catch (e) {
        callLog('CallManager', 'recovery camera facing restore failed: $e');
      }
    }
    if (snapshot.isCameraOff) {
      try {
        await session.setVideoEnabled(false);
      } catch (e) {
        callLog('CallManager', 'recovery camera mute restore failed: $e');
      }
    }
  }

  Future<void> _syncAudioRoutesForCurrentCall({
    required String reason,
    bool reapplyCurrentRoute = false,
  }) async {
    final current = state.value;
    if (!current.isActive) {
      return;
    }
    await _audioRouteController.ensureReady(
      preferSpeakerByDefault: current.isVideo,
      reason: reason,
      reapplySelectedRoute: reapplyCurrentRoute,
    );
  }

  Future<void> _startRecoveryOfferWithFreshSession({
    required CallState snapshot,
    required String reason,
    required String source,
  }) async {
    callLog(
      'CallManager',
      'starting fresh transport recovery reason=$reason callId=${snapshot.callId} callAttemptId=${snapshot.callAttemptId}',
    );
    final newSession = await _createSession(
      forceNew: true,
      forceIceRefresh: true,
    );
    await newSession.startOutgoing(
      video: snapshot.isVideo,
      onOffer: (sdp) async {
        _transitionLifecycle(
          CallLifecycleEvent.localOfferCreated,
          source: source,
        );
        _lastLocalOfferSdp = sdp;
        await _sendCallOfferDeduped(
          peerProfileId: snapshot.peerProfileId,
          callId: snapshot.callId,
          callAttemptId: snapshot.callAttemptId,
          video: snapshot.isVideo,
          sdp: sdp,
        );
      },
      onIceCandidate: (c, mid, idx) => controller.sendCallIceCandidate(
        peerProfileId: snapshot.peerProfileId,
        callId: snapshot.callId,
        callAttemptId: snapshot.callAttemptId,
        candidate: c,
        sdpMid: mid,
        sdpMLineIndex: idx,
        recovery: true,
      ),
    );
    await _restoreRecoverySessionPreferences(newSession, snapshot);
    await _syncAudioRoutesForCurrentCall(
      reason: 'fresh_recovery_session_ready',
      reapplyCurrentRoute: true,
    );
  }

  Future<void> _tryApplyPendingRemoteAnswer() async {
    final pendingSdp = _pendingRemoteAnswerSdp;
    if (pendingSdp == null || pendingSdp.isEmpty) return;
    final session = _session;
    if (session == null) return;
    final s = state.value;
    if (s.callId.isEmpty ||
        (s.phase != CallPhase.ringingOutgoing &&
            s.phase != CallPhase.connecting)) {
      return;
    }

    final awaitingAnswer = await session.isAwaitingRemoteAnswer();
    final shouldApplyAnswer = shouldApplyRemoteAnswer(
      awaitingRemoteAnswer: awaitingAnswer,
      hasRemoteDescription: session.hasRemoteDescription,
      hasPendingLocalOffer: _lastLocalOfferSdp?.isNotEmpty ?? false,
    );
    if (!shouldApplyAnswer) {
      _pendingRemoteAnswerSdp = null;
      _lastRemoteAnswerFingerprint =
          '${pendingSdp.length}:${pendingSdp.hashCode}';
      _lastRemoteAnswerProcessedAtMs = DateTime.now().millisecondsSinceEpoch;
      callLog(
        'CallManager',
        'dropping buffered remote answer because signaling is no longer awaiting',
      );
      return;
    }
    if (!awaitingAnswer) {
      callLog(
        'CallManager',
        'retrying buffered remote answer despite signaling drift because a local offer is still pending',
      );
    }

    try {
      await session.applyRemoteAnswer(pendingSdp);
      _lastRemoteAnswerFingerprint =
          '${pendingSdp.length}:${pendingSdp.hashCode}';
      _lastRemoteAnswerProcessedAtMs = DateTime.now().millisecondsSinceEpoch;
      _lastLocalOfferSdp = null;
      _pendingRemoteAnswerSdp = null;
      _stopNeedOfferRetries();
      _ringTimer?.cancel();
      if (s.phase != CallPhase.connecting && s.phase != CallPhase.connected) {
        _transitionLifecycle(
          CallLifecycleEvent.remoteAnswerReceived,
          source: '_tryApplyPendingRemoteAnswer',
        );
        _startConnectTimeout();
      }
      _resyncConnectedFromCurrentSession(source: 'buffered_answer_after_apply');
      callLog('CallManager', 'applied buffered remote answer');
    } catch (e) {
      callLog(
        'CallManager',
        'buffered answer apply failed (will keep buffered): $e',
      );
    }
  }

  void _bindConnectionListener(WebRtcCallSession session) {
    _connListener?.call(); // remove previous
    _iceConnListener?.call();
    _mediaEstablishedListener?.call();
    _remoteVideoLifecycleListener?.call();

    void markConnected(CallState s, {required String source}) {
      _connectTimer?.cancel();
      _reconnectWatchdogTimer?.cancel();
      _reconnectWatchdogTimer = null;
      _stopReconnectingPoll();
      _iceRestartInFlightSafetyTimer?.cancel();
      _iceRestartInFlightSafetyTimer = null;
      _iceRestartAttempts = 0;
      _iceRestartInFlight = false;
      // Cancel any pending connectivity-handoff recovery — the call is
      // connected, so the follow-up recovery attempt is no longer needed.
      _connectivityHandoffRecoveryTimer?.cancel();
      _connectivityHandoffRecoveryTimer = null;
      _connectivityFollowUpRecoveryAttempts = 0;
      unawaited(_stopRingtone());
      if (s.phase != CallPhase.connected) {
        _transitionLifecycle(
          CallLifecycleEvent.mediaEstablished,
          source: source,
          connectedAtMs:
              s.connectedAtMs ?? DateTime.now().millisecondsSinceEpoch,
        );
        _setCallActive(true);
        unawaited(_showOngoingCallNotification());
        // iOS locked-answer no-audio fix (2026-07-09): this listener-driven
        // promotion is the path taken when ICE connects AFTER the SDP exchange
        // (the common answer-from-lockscreen cold-launch case) — it MUST also
        // restart the WebRTC audio unit so it renders the remote track, exactly
        // like the top-level `_markConnectedFromSession`. Guarded by the phase
        // check above, so whichever connected path fires first is the only one
        // that reasserts (no double restart).
        _reassertIosCallAudio();
      }
    }

    bool resyncConnectedPhase({required String source}) {
      final rtcState = session.connectionState.value;
      final iceState = session.iceConnectionState.value;
      final mediaEstablished = session.mediaEstablished.value;
      final s = state.value;
      final iceConnected =
          iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted;
      final rtcConnected =
          rtcState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (!shouldPromoteConnectedFromSession(
        phase: s.phase,
        wasEverConnected: s.connectedAtMs != null,
        rtcState: rtcState,
        iceState: iceState,
        mediaEstablished: mediaEstablished,
      )) {
        return false;
      }
      if (!rtcConnected && iceConnected && s.phase != CallPhase.connected) {
        callLog(
          'CallManager',
          'promoting call to connected after media truth confirmed via ICE state while peerConnectionState=$rtcState',
        );
      }
      if (!iceConnected && !rtcConnected && s.phase != CallPhase.connected) {
        callLog(
          'CallManager',
          'suppressing connected promotion because media exists without confirmed connected transport peerConnectionState=$rtcState iceState=$iceState',
        );
        return false;
      }
      markConnected(s, source: source);
      return true;
    }

    void listener() {
      final rtcState = session.connectionState.value;
      final iceState = session.iceConnectionState.value;
      final mediaEstablished = session.mediaEstablished.value;
      final s = state.value;
      final iceConnected =
          iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted;
      final rtcConnected =
          rtcState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      final transportFailed = hasTransportFailureState(
        rtcState: rtcState,
        iceState: iceState,
      );
      final transportDisconnected = hasTransportDisconnectionState(
        rtcState: rtcState,
        iceState: iceState,
      );
      if (resyncConnectedPhase(source: 'peer_connection_connected')) {
        _disconnectDebounceTimer?.cancel();
        _disconnectDebounceTimer = null;
        return;
      } else if ((rtcConnected || iceConnected) &&
          s.phase != CallPhase.connected) {
        _disconnectDebounceTimer?.cancel();
        _disconnectDebounceTimer = null;
        callLog(
          'CallManager',
          'transport connected but waiting for confirmed media before connected promotion peerConnectionState=$rtcState iceState=$iceState mediaEstablished=$mediaEstablished',
        );
      } else if (transportFailed) {
        _disconnectDebounceTimer?.cancel();
        _disconnectDebounceTimer = null;
        callLog(
          'CallManager',
          'transport failed, phase=${s.phase} peerConnectionState=$rtcState iceState=$iceState',
        );
        if (s.phase == CallPhase.connected ||
            s.phase == CallPhase.reconnecting) {
          _transitionLifecycle(
            CallLifecycleEvent.peerconnectionFailed,
            source: 'peer_connection_failed',
          );
          _ensureReconnectWatchdog();
          _autoRestartIce();
        } else if (s.phase == CallPhase.connecting) {
          // ICE failed during initial connection — retry once then give up.
          _autoRestartIce();
        }
      } else if (transportDisconnected) {
        callLog(
          'CallManager',
          'transport disconnected, phase=${s.phase} peerConnectionState=$rtcState iceState=$iceState — debouncing ${_disconnectDebounceWindow.inMilliseconds}ms before reacting',
        );
        if ((s.phase == CallPhase.connected ||
                s.phase == CallPhase.reconnecting) &&
            (_disconnectDebounceTimer == null ||
                !_disconnectDebounceTimer!.isActive)) {
          _disconnectDebounceTimer = Timer(_disconnectDebounceWindow, () {
            _disconnectDebounceTimer = null;
            // Re-check current state fresh — the values captured above may
            // be stale by the time this fires (WebRTC state read directly
            // off the session, not off a snapshot).
            final freshRtc = session.connectionState.value;
            final freshIce = session.iceConnectionState.value;
            final stillDisconnected = hasTransportDisconnectionState(
              rtcState: freshRtc,
              iceState: freshIce,
            );
            final nowFailed = hasTransportFailureState(
              rtcState: freshRtc,
              iceState: freshIce,
            );
            if (!stillDisconnected && !nowFailed) {
              callLog(
                'CallManager',
                'transport disconnected self-healed within debounce window, no action taken',
              );
              return;
            }
            final freshPhase = state.value.phase;
            if (freshPhase != CallPhase.connected &&
                freshPhase != CallPhase.reconnecting) {
              return;
            }
            _transitionLifecycle(
              nowFailed
                  ? CallLifecycleEvent.peerconnectionFailed
                  : CallLifecycleEvent.transportLost,
              source: 'peer_connection_disconnected_debounced',
            );
            _ensureReconnectWatchdog();
            _autoRestartIce();
          });
        }
      }
    }

    session.connectionState.addListener(listener);
    session.iceConnectionState.addListener(listener);
    session.mediaEstablished.addListener(listener);
    session.remoteVideoLifecycle.addListener(_onRemoteVideoLifecycleChanged);
    _connListener = () => session.connectionState.removeListener(listener);
    _iceConnListener = () =>
        session.iceConnectionState.removeListener(listener);
    _mediaEstablishedListener = () =>
        session.mediaEstablished.removeListener(listener);
    _remoteVideoLifecycleListener = () => session.remoteVideoLifecycle
        .removeListener(_onRemoteVideoLifecycleChanged);

    if (state.value.phase == CallPhase.reconnecting) {
      resyncConnectedPhase(source: 'session_bind_resync');
    }
  }

  void _onRemoteVideoLifecycleChanged() {
    final session = _session;
    if (session == null) {
      return;
    }
    final lifecycle = session.remoteVideoLifecycle.value;
    final current = state.value;
    if (!current.isActive || !current.isVideo) {
      return;
    }
    if (lifecycle.state == RemoteVideoLifecycleState.renderingFrames) {
      _remoteVideoRecoveryAttemptId = '';
      _remoteVideoRecoveryAttempts = 0;
      return;
    }
    if (lifecycle.state != RemoteVideoLifecycleState.failed ||
        lifecycle.failureReason == null) {
      return;
    }
    unawaited(_handleRemoteVideoFailure(lifecycle.failureReason!));
  }

  Future<void> _handleRemoteVideoFailure(
    RemoteVideoFailureReason reason,
  ) async {
    if (_remoteVideoRecoveryInFlight) {
      return;
    }
    final session = _session;
    final snapshot = state.value;
    if (session == null || !snapshot.isActive || !snapshot.isVideo) {
      return;
    }
    final attemptId = snapshot.callAttemptId.isEmpty
        ? snapshot.callId
        : snapshot.callAttemptId;
    if (_remoteVideoRecoveryAttemptId != attemptId) {
      _remoteVideoRecoveryAttemptId = attemptId;
      _remoteVideoRecoveryAttempts = 0;
    }
    final step = selectRemoteVideoRecoveryStep(
      reason: reason,
      attemptsSoFar: _remoteVideoRecoveryAttempts,
    );
    _remoteVideoRecoveryAttempts++;
    _remoteVideoRecoveryInFlight = true;
    callOpLog(
      'CallManager',
      'remote_video_recovery_plan',
      fields: <String, Object?>{
        'callId': snapshot.callId,
        'callAttemptId': attemptId,
        'failureReason': reason.name,
        'step': step.name,
        'attempt': _remoteVideoRecoveryAttempts,
      },
    );
    try {
      session.beginRemoteVideoRecoveryWindow(reason: reason);
      switch (step) {
        case RemoteVideoRecoveryStep.reattachRenderer:
          await session.forceRemoteVideoRendererRecovery(
            reason:
                'lifecycle_${reason.name}_attempt_$_remoteVideoRecoveryAttempts',
          );
          break;
        case RemoteVideoRecoveryStep.restartIce:
          if (snapshot.phase == CallPhase.connected) {
            _transitionLifecycle(
              CallLifecycleEvent.peerconnectionFailed,
              source: 'remote_video_restart_ice',
            );
          }
          _ensureReconnectWatchdog();
          await _autoRestartIce();
          break;
        case RemoteVideoRecoveryStep.renegotiate:
          if (snapshot.phase == CallPhase.connected) {
            _transitionLifecycle(
              CallLifecycleEvent.peerconnectionFailed,
              source: 'remote_video_renegotiate',
            );
          }
          _ensureReconnectWatchdog();
          final reconciled = await _reconcileActiveCallWithRelay(
            trigger: 'remote_video_failure',
          );
          if (!reconciled) {
            if (snapshot.direction == CallDirection.outgoing) {
              await _resendOfferRecovery(reason: 'remote_video_failure');
            } else {
              await _requestOfferRecovery(reason: 'remote_video_failure');
            }
          }
          break;
        case RemoteVideoRecoveryStep.failCall:
          await _failCallAndNotifyRemote(
            error: CallFailure(
              CallFailureCode.connectionInterrupted,
              message: 'remote video recovery exhausted for ${reason.name}',
            ),
          );
          break;
      }
    } finally {
      _remoteVideoRecoveryInFlight = false;
    }
  }

  int _iceRestartAttempts = 0;

  void _ensureReconnectWatchdog() {
    _ensureReconnectingPoll();
    _reconnectWatchdogTimer ??= Timer(_reconnectWatchdogWindow, () async {
      final s = state.value;
      _reconnectWatchdogTimer = null;
      if (s.phase != CallPhase.reconnecting) {
        return;
      }
      final reconciled = await _reconcileActiveCallWithRelay(
        trigger: 'reconnect_watchdog',
      );
      final latest = state.value;
      if (reconciled) {
        if (latest.phase == CallPhase.reconnecting) {
          callLog(
            'CallManager',
            'reconnect watchdog extended after relay-authoritative recovery',
          );
          _ensureReconnectWatchdog();
        }
        return;
      }
      if (latest.phase == CallPhase.reconnecting) {
        callLog('CallManager', 'reconnect watchdog expired; ending call');
        await _failCallAndNotifyRemote();
      }
    });
  }

  Future<bool> _reconcileActiveCallForRecovery({
    required String trigger,
    required bool wasEverConnected,
    required bool preferHardRecovery,
  }) async {
    final budgetMs = computeRelayReconcileBudgetMs(
      wasEverConnected: wasEverConnected,
      preferHardRecovery: preferHardRecovery,
    );
    if (budgetMs == null || budgetMs <= 0) {
      return _reconcileActiveCallWithRelay(trigger: trigger);
    }
    var timedOut = false;
    final reconciled = await Future.any<bool>([
      _reconcileActiveCallWithRelay(trigger: trigger),
      Future<bool>.delayed(Duration(milliseconds: budgetMs), () {
        timedOut = true;
        return false;
      }),
    ]);
    if (timedOut) {
      callLog(
        'CallManager',
        'relay reconcile exceeded ${budgetMs}ms fast-recovery budget trigger=$trigger; continuing transport recovery',
      );
    }
    return reconciled;
  }

  Future<void> _autoRestartIce({
    bool preferHardRecovery = false,
    bool skipRelayReconcile = false,
  }) async {
    if (_iceRestartInFlight) {
      callLog(
        'CallManager',
        'autoRestartIce skipped: restart already in flight',
      );
      return;
    }
    if (!skipRelayReconcile) {
      final snapshotBeforeReconcile = state.value;
      final reconciled = await _reconcileActiveCallForRecovery(
        trigger: 'auto_restart_ice',
        wasEverConnected: snapshotBeforeReconcile.connectedAtMs != null,
        preferHardRecovery: preferHardRecovery,
      );
      if (reconciled) {
        return;
      }
    }
    final snapshot = state.value;
    final maxAttempts = snapshot.connectedAtMs == null ? 3 : 12;
    if (_iceRestartAttempts >= maxAttempts) {
      if (snapshot.connectedAtMs == null) {
        await _failCallAndNotifyRemote();
      } else {
        callLog(
          'CallManager',
          'ICE restart budget exhausted during active call; waiting for reconnect watchdog',
        );
      }
      return;
    }
    _iceRestartInFlight = true;
    _iceRestartAttempts++;
    _iceRestartInFlightStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    final generation = ++_iceRestartInFlightGeneration;
    _iceRestartInFlightSafetyTimer?.cancel();
    _iceRestartInFlightSafetyTimer = Timer(_iceRestartInFlightSafetyTimeout, () {
      if (!_iceRestartInFlight) return;
      if (generation != _iceRestartInFlightGeneration) return;
      final ageMs =
          DateTime.now().millisecondsSinceEpoch -
          _iceRestartInFlightStartedAtMs;
      callLog(
        'CallManager',
        'ICE restart safety timeout: forcing in-flight lock release after ${ageMs}ms',
      );
      _iceRestartInFlight = false;
      _iceRestartInFlightSafetyTimer = null;
      // Bump the generation so the original attempt's `finally` block does
      // not undo the release / cancel the successor's safety timer.
      _iceRestartInFlightGeneration++;
      // If still reconnecting, kick another recovery cycle.
      final s = state.value;
      if (s.isActive &&
          (s.phase == CallPhase.reconnecting ||
              s.phase == CallPhase.connecting)) {
        unawaited(
          _autoRestartIce(preferHardRecovery: true, skipRelayReconcile: true),
        );
      }
    });
    try {
      final delayMs = computeAutoRestartIceDelayMs(
        attemptNumber: _iceRestartAttempts,
        wasEverConnected: snapshot.connectedAtMs != null,
        preferHardRecovery: preferHardRecovery,
      );
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      final session = _session;
      final s = state.value;
      if (session == null || !s.isActive) return;
      if (s.phase == CallPhase.connecting) {
        _startConnectTimeout();
      }
      final awaitingRemoteAnswer = await session.isAwaitingRemoteAnswer();
      if (awaitingRemoteAnswer && (_lastLocalOfferSdp?.isNotEmpty ?? false)) {
        callLog(
          'CallManager',
          'autoRestartIce suppressed while awaiting answer; resending cached offer',
        );
        await _sendCallOfferDeduped(
          peerProfileId: s.peerProfileId,
          callId: s.callId,
          callAttemptId: s.callAttemptId,
          video: s.isVideo,
          sdp: _lastLocalOfferSdp!,
        );
        return;
      }
      final shouldUseFreshTransport = shouldUseFreshTransportRecovery(
        phase: s.phase,
        wasEverConnected: s.connectedAtMs != null,
        isVideo: s.isVideo,
        isCameraOff: s.isCameraOff,
        isScreenSharing: s.isScreenSharing,
        priorIceRestartAttempts: _iceRestartAttempts,
        preferHardRecovery: preferHardRecovery,
      );
      if (shouldUseFreshTransport) {
        await _startRecoveryOfferWithFreshSession(
          snapshot: s,
          reason: preferHardRecovery
              ? 'auto_restart_ice_prefer_hard'
              : 'auto_restart_ice_budget_escalation',
          source: '_autoRestartIce_fresh_session',
        );
        return;
      }
      await session.restartIce(
        video: s.isVideo,
        onOffer: (sdp) async {
          _transitionLifecycle(
            CallLifecycleEvent.localOfferCreated,
            source: '_autoRestartIce_onOffer',
          );
          _lastLocalOfferSdp = sdp;
          await _sendCallOfferDeduped(
            peerProfileId: s.peerProfileId,
            callId: s.callId,
            callAttemptId: s.callAttemptId,
            video: s.isVideo,
            sdp: sdp,
          );
        },
      );
    } catch (e, stack) {
      callLog('CallManager', 'autoRestartIce failed: $e\n$stack');
      final latest = state.value;
      final shouldKeepTrying =
          latest.phase == CallPhase.connected ||
          latest.phase == CallPhase.reconnecting ||
          latest.connectedAtMs != null;
      if (shouldKeepTrying) {
        if (latest.phase == CallPhase.connected) {
          _transitionLifecycle(
            CallLifecycleEvent.peerconnectionFailed,
            source: 'auto_restart_ice_error',
          );
        }
        _ensureReconnectWatchdog();
        callLog(
          'CallManager',
          'autoRestartIce error treated as transient during active call; waiting for reconnect watchdog',
        );
      } else {
        await _failCallAndNotifyRemote(error: e, stackTrace: stack);
      }
    } finally {
      // Only release the lock and cancel the safety timer if WE still own
      // the generation. Otherwise a safety timer (or connectivity-driven
      // force-release) has already started a successor attempt; clobbering
      // the lock here would cause two ICE restarts to overlap and would
      // strand subsequent recovery cycles.
      if (generation == _iceRestartInFlightGeneration) {
        _iceRestartInFlight = false;
        _iceRestartInFlightSafetyTimer?.cancel();
        _iceRestartInFlightSafetyTimer = null;
        if (_queuedConnectivityHandoffRecovery) {
          _queuedConnectivityHandoffRecovery = false;
          _scheduleConnectivityHandoffRecovery(
            delay: _queuedConnectivityHandoffRecoveryDelay,
          );
        }
      }
    }
  }

  void _ensureReconnectingPoll() {
    if (_reconnectingPollTimer != null) return;
    _reconnectingPollTimer = Timer.periodic(
      _reconnectingPollInterval,
      (_) => unawaited(_runReconnectingPoll()),
    );
  }

  void _stopReconnectingPoll() {
    _reconnectingPollTimer?.cancel();
    _reconnectingPollTimer = null;
  }

  Future<void> _runReconnectingPoll() async {
    final s = state.value;
    if (!s.isActive || s.phase != CallPhase.reconnecting) {
      _stopReconnectingPoll();
      return;
    }
    if (!hasUsableConnectivity(_lastConnectivityResults)) {
      // Nothing we can do without a network — keep the timer alive
      // so we resume polling as soon as connectivity returns.
      return;
    }
    final session = _session;
    if (session != null) {
      final rtcState = session.connectionState.value;
      final iceState = session.iceConnectionState.value;
      final transportConnected =
          rtcState == RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted;
      if (transportConnected && session.mediaEstablished.value) {
        // Transport is back; promotion will happen via the listener bind.
        return;
      }
    }
    callLog(
      'CallManager',
      'reconnecting poll tick: kicking another recovery attempt',
    );
    _forceReleaseIceRestartLockIfStale(reason: 'reconnecting_poll');
    if (_iceRestartAttempts >= 6) {
      // Reset the soft budget periodically so the poll can keep retrying.
      _iceRestartAttempts = 3;
    }
    // GLARE-FIX: at the reconnecting-poll point we've already gone through the
    // attempt counter; let shouldUseFreshTransportRecovery decide based on
    // _iceRestartAttempts instead of forcing hard recovery every tick.
    await _autoRestartIce(preferHardRecovery: false, skipRelayReconcile: true);
  }

  Future<void> _failCallAndNotifyRemote({
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final snapshot = state.value;
    final failure = error == null ? null : describeCallFailure(error);
    if (error != null) {
      callLog(
        'CallManager',
        'fatal call error: $error${stackTrace == null ? '' : '\n$stackTrace'}',
      );
    }
    if (snapshot.callId.isNotEmpty && snapshot.peerProfileId.isNotEmpty) {
      try {
        await controller.sendCallHangup(
          peerProfileId: snapshot.peerProfileId,
          callId: snapshot.callId,
          callAttemptId: snapshot.callAttemptId,
        );
      } catch (hangupError) {
        callLog(
          'CallManager',
          'sendCallHangup after fatal error failed: $hangupError',
        );
      }
    }
    await _endCall(CallEndReason.error, failure: failure);
  }

  Future<void> _endCall(CallEndReason reason, {CallFailure? failure}) async {
    _incomingScreenRequested = false;
    final endingSnapshot = state.value;
    final endingCallAttemptId = endingSnapshot.callAttemptId.isEmpty
        ? endingSnapshot.callId
        : endingSnapshot.callAttemptId;
    if (endingCallAttemptId.isNotEmpty &&
        (_endingCallAttemptId == endingCallAttemptId ||
            endingSnapshot.phase == CallPhase.ended)) {
      callLog(
        'CallManager',
        '[OP] event=call_end_duplicate_suppressed attempt=$endingCallAttemptId reason=$reason phase=${endingSnapshot.phase.name}',
      );
      return;
    }
    if (endingCallAttemptId.isNotEmpty) {
      _endingCallAttemptId = endingCallAttemptId;
    }
    _transitionLifecycle(
      _endLifecycleEvent(reason),
      source: '_endCall_start',
      endReason: reason,
    );
    if (failure != null) {
      state.value = state.value.copyWith(failure: failure);
    }
    callOpLog(
      'CallManager',
      'call_ended',
      fields: <String, Object?>{
        'callId': endingSnapshot.callId,
        'callAttemptId': endingCallAttemptId,
        'reason': reason,
        'phase': endingSnapshot.phase,
      },
    );
    // Brief cooldown so messages arriving immediately after a call end
    // don't trigger notification banners over the call-ended screen.
    Future.delayed(const Duration(seconds: 2), () {
      _setCallActive(false);
    });
    // Record ended call attempt so re-delivered relay signals are ignored.
    final endingCallAttemptKey = endedCallAttemptKey(
      callId: endingSnapshot.callId,
      callAttemptId: endingSnapshot.callAttemptId,
    );
    if (endingCallAttemptKey.isNotEmpty) {
      _lastEndedCallAttemptKeys.add(endingCallAttemptKey);
      // Keep the set bounded; remove oldest if over limit.
      while (_lastEndedCallAttemptKeys.length > _maxEndedCallAttemptKeysKept) {
        _lastEndedCallAttemptKeys.remove(_lastEndedCallAttemptKeys.first);
      }
      // Persist asynchronously — ignore errors.
      SharedPreferences.getInstance()
          .then((prefs) {
            prefs.setStringList(
              _prefKeyEndedCallAttemptKeys,
              _lastEndedCallAttemptKeys.toList(),
            );
          })
          .catchError((_) {});
    }
    // Stop screen share if active so we release the screen capture stream.
    if (endingSnapshot.isScreenSharing) {
      await _session?.stopScreenShare();
    }
    _ringTimer?.cancel();
    _inviteResendTimer?.cancel();
    _inviteResendTimer = null;
    _inviteResendTicks = 0;
    await _stopRingtone();
    _connectTimer?.cancel();
    _answerResendTimer?.cancel();
    _answerResendTimer = null;
    _stopNeedOfferRetries();
    _answerResendAttempts = 0;
    _reconnectWatchdogTimer?.cancel();
    _reconnectWatchdogTimer = null;
    _stopReconnectingPoll();
    _iceRestartInFlightSafetyTimer?.cancel();
    _iceRestartInFlightSafetyTimer = null;
    _connectivityHandoffRecoveryTimer?.cancel();
    _connectivityHandoffRecoveryTimer = null;
    _lastLocalAnswerSdp = null;
    _lastLocalOfferSdp = null;
    _lastSentOfferFingerprint = null;
    _lastSentOfferCallId = '';
    _lastSentOfferCallAttemptId = '';
    _lastSentOfferAtMs = 0;
    _iceRestartAttempts = 0;
    _iceRestartInFlight = false;
    _connectivityFollowUpRecoveryAttempts = 0;
    _queuedConnectivityHandoffRecovery = false;
    _pendingRelayConnectivityRecovery = false;
    _pendingRelayConnectivityRecoveryAtMs = 0;
    _consecutiveMissingRelaySessions = 0;
    _lastObservedRelaySessionAtMs = 0;
    _lastObservedRelaySessionCallId = '';
    _lastObservedRelaySessionAttemptId = '';
    _lastObservedRelaySessionState = '';
    _lastMissingRelaySessionAttemptId = '';
    _lastConnectivityRecoveryTriggerAtMs = 0;
    _lastConnectivityRecoveryAttemptKey = '';
    _awaitingRecoveryOffer = false;
    _pendingOfferSdp = null;
    _pendingNativeCallAction = null;
    _pendingNativeActionCallId = '';
    _pendingNativeActionAttemptId = '';
    _pendingRemoteAnswerSdp = null;
    _queuedOfferSdp = null;
    _isProcessingOffer = false;
    _lastOfferFingerprint = null;
    _lastOfferProcessedAtMs = 0;
    _lastRemoteAnswerFingerprint = null;
    _lastRemoteAnswerProcessedAtMs = 0;
    _pendingCallUiGuardTimer?.cancel();
    _pendingCallUiGuardTimer = null;
    _pendingCallUiRoute = '';
    _pendingCallUiCallId = '';
    _pendingIceCandidates.clear();
    await _audioRouteController.reset();
    _transitionLifecycle(
      CallLifecycleEvent.cleanupCompleted,
      source: '_endCall_cleanup',
      endReason: reason,
    );
    state.value = state.value.copyWith(isUiMinimized: false);
    final metrics = _session?.qualityMetrics.value;
    if (endingSnapshot.callId.isNotEmpty &&
        endingSnapshot.peerProfileId.isNotEmpty &&
        endingSnapshot.startedAtMs != null) {
      final qualitySummary = metrics == null
          ? null
          : CallQualitySummary(
              rttMs: metrics.rttMs,
              jitterMs: metrics.jitterMs,
              packetLossPct: metrics.packetLossPct,
              qualityLevel: metrics.qualityLevel.name,
            );
      unawaited(
        // Persist the typed failure code so history/diagnostics can explain
        // why the call failed after the active session is gone.
        controller.recordCallOutcome(
          callId: endingSnapshot.callId,
          callAttemptId: endingSnapshot.callAttemptId.isEmpty
              ? endingSnapshot.callId
              : endingSnapshot.callAttemptId,
          peerProfileId: endingSnapshot.peerProfileId,
          peerName: endingSnapshot.peerName,
          peerAvatarPath: endingSnapshot.peerAvatarPath,
          direction: endingSnapshot.direction == CallDirection.incoming
              ? CallRecordDirection.incoming
              : CallRecordDirection.outgoing,
          isVideo: endingSnapshot.isVideo,
          hadScreenShare: endingSnapshot.isScreenSharing,
          startedAtMs: endingSnapshot.startedAtMs!,
          connectedAtMs: endingSnapshot.connectedAtMs,
          endedAtMs: DateTime.now().millisecondsSinceEpoch,
          endReason: reason,
          failureCode: failure?.code ?? state.value.failure?.code,
          qualitySummary: qualitySummary,
        ),
      );
    }
    await _hideNativeIncomingUi();
    unawaited(_hideOngoingCallNotification());
    await _disposeSession();
    // Auto-reset to idle after brief delay so UI can show "Call ended".
    // Only reset if the callId is still the same one we ended — prevents
    // clobbering a new incoming call that arrived during the 2 s window.
    final endedCallIdSnapshot = endingSnapshot.callId;
    Future.delayed(const Duration(seconds: 2), () {
      if (state.value.phase == CallPhase.ended &&
          state.value.callId == endedCallIdSnapshot) {
        _transitionLifecycle(
          CallLifecycleEvent.reset,
          source: '_endCall_auto_reset',
        );
        state.value = CallState.empty;
        _popCallScreens();
      }
    });
  }

  Future<void> _disposeSession() async {
    _disconnectDebounceTimer?.cancel();
    _disconnectDebounceTimer = null;
    final s = _session;
    if (s != null) {
      s.onScreenShareStopped = null;
      _connListener?.call();
      _connListener = null;
      _iceConnListener?.call();
      _iceConnListener = null;
      _mediaEstablishedListener?.call();
      _mediaEstablishedListener = null;
      _remoteVideoLifecycleListener?.call();
      _remoteVideoLifecycleListener = null;
      _remoteVideoRecoveryAttemptId = '';
      _remoteVideoRecoveryAttempts = 0;
      _remoteVideoRecoveryInFlight = false;
      await s.dispose();
      _session = null;
    }
    // r11: allow the next incoming attempt to prewarm a fresh session.
    _prewarmedCallAttemptKey = '';
  }

  /// Does this signal END a call?
  ///
  /// Such a signal must never be discarded for being old: it can only ever
  /// CLOSE state, and applying it late is at worst a no-op. Everything else —
  /// `invite`, `offer`, `answer`, ICE — opens or advances a call and is
  /// correctly age-gated, because acting on those late is what produces a ghost.
  @visibleForTesting
  static bool isTerminalCallSignalAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'hangup':
      case 'cancel':
      case 'decline':
      case 'busy':
        return true;
      default:
        return false;
    }
  }

  /// How long a call may ring before it is dead. Also the WALL-CLOCK yardstick
  /// used by [incomingRingExpired] — see there for why a timer alone is not
  /// enough.
  static const int ringTimeoutSeconds = 45;

  /// Has this ringing call outlived the ring window in REAL time?
  ///
  /// 🔴 THE PHANTOM CALL (2026-07-31, user report: "я отменил звонок, а он при
  /// следующем заходе всё ещё видит дозвон").
  ///
  /// [_startRingTimeout] is a plain `Timer`. On iOS a backgrounded app is
  /// SUSPENDED: timers do not fire and do not accrue, they resume counting
  /// where they stopped. So a call that was ringing when the user switched away
  /// still believes only a few seconds have passed hours later — and
  /// `onAppLifecycleStateChanged` then RE-DISPLAYS the incoming UI for it.
  ///
  /// The caller's cancel does not save us either: it may never have been
  /// delivered (the app was suspended, and there is no cancel push), and the
  /// startup drain DROPS buffered signals older than 60 s — including the very
  /// hangup that would have cleared this.
  ///
  /// So the ring window has to be judged against the clock on the wall, not
  /// against a timer that was asleep. [startedAtMs] is the INVITE's creation
  /// time for an incoming call, which is exactly the right origin.
  ///
  /// Null/absurd stamps return false: without a trustworthy origin we keep the
  /// old behaviour rather than cancel a call that might be real.
  @visibleForTesting
  static bool incomingRingExpired({
    required int? startedAtMs,
    required int nowMs,
  }) {
    if (startedAtMs == null || startedAtMs <= 0) return false;
    final ageMs = nowMs - startedAtMs;
    if (ageMs < 0) return false; // clock skew — never treat as expired
    return ageMs > ringTimeoutSeconds * 1000;
  }

  void _startRingTimeout() {
    _ringTimer?.cancel();
    _ringTimer = Timer(const Duration(seconds: ringTimeoutSeconds), () async {
      final s = state.value;
      if (s.isRinging) {
        // Local-first: end call immediately, then best-effort notify remote.
        await _endCall(CallEndReason.timeout);
        if (s.phase == CallPhase.ringingOutgoing &&
            s.peerProfileId.isNotEmpty &&
            s.callId.isNotEmpty) {
          try {
            await controller.sendCallHangup(
              peerProfileId: s.peerProfileId,
              callId: s.callId,
              callAttemptId: s.callAttemptId,
            );
          } catch (e) {
            callLog(
              'CallManager',
              'ring timeout hangup failed (best-effort): $e',
            );
          }
        }
      }
    });
  }

  Future<void> _startRingtone({required bool incoming}) async {
    await _startTone(
      incoming ? _RingtoneMode.incoming : _RingtoneMode.outgoing,
    );
  }

  Future<void> _startConnectingTone() async {
    await _startTone(_RingtoneMode.connecting);
  }

  Future<void> _startTone(_RingtoneMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _callVibrationSetting =
          prefs.getString('settings_notif_call_vibration_v1') ?? 'off';
      _callRingtoneSetting =
          prefs.getString('settings_notif_call_ringtone_v1') ?? 'default';

      // Stop previous playback before switching assets.
      if (_ringtonePlayer.playing) {
        await _ringtonePlayer.stop();
      }

      // Pick the right audio asset for this mode.
      final String assetPath;
      final double volume;
      final double speed;
      final bool loop;
      switch (mode) {
        case _RingtoneMode.incoming:
          assetPath = _incomingRingtoneAsset;
          volume = incomingRingtoneVolumeForSetting(_callRingtoneSetting);
          speed = switch (_callRingtoneSetting) {
            'beacon' => 1.03,
            'chime' => 0.96,
            _ => 1.0,
          };
          loop = true;
        case _RingtoneMode.outgoing:
          assetPath = _outgoingRingtoneAsset;
          volume = 0.58;
          speed = 1.0;
          loop = true;
        case _RingtoneMode.connecting:
          assetPath = _connectingToneAsset;
          volume = 0.32;
          speed = 1.0;
          loop = false;
      }

      await _ringtonePlayer.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      await _ringtonePlayer.setAsset(assetPath);
      _ringtoneMode = mode;
      await _ringtonePlayer.setVolume(volume);
      await _ringtonePlayer.setSpeed(speed);
      await _ringtonePlayer.seek(Duration.zero);
      // Switch native audio into ringing/playback mode before playing so the
      // incoming ringtone and outgoing ringback use the loud route instead of
      // call/earpiece audio.
      if ((defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS) &&
          (mode == _RingtoneMode.incoming || mode == _RingtoneMode.outgoing)) {
        try {
          await _nativeCallUiChannel.invokeMethod<void>('setRingtoneMode');
        } catch (_) {}
      }
      await _ringtonePlayer.play();

      _incomingVibrationTimer?.cancel();
      if (mode == _RingtoneMode.incoming) {
        _startIncomingVibrationLoop();
      }
    } catch (e) {
      callLog('CallManager', 'tone start failed (mode=$mode): $e');
    }
  }

  Future<void> _stopRingtone({bool keepNativeAudioActive = false}) async {
    try {
      _incomingVibrationTimer?.cancel();
      _incomingVibrationTimer = null;
      if (_ringtonePlayer.playing) {
        await _ringtonePlayer.stop();
      }
      final stoppedMode = _ringtoneMode;
      _ringtoneMode = null;
      if (stoppedMode != null) {
        callLog('CallManager', 'ringtone stopped (was $stoppedMode)');
        // Restore normal audio mode after ringtone ends.
        if (!keepNativeAudioActive &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS) &&
            (stoppedMode == _RingtoneMode.incoming ||
                stoppedMode == _RingtoneMode.outgoing)) {
          try {
            await _nativeCallUiChannel.invokeMethod<void>('clearAudioMode');
          } catch (_) {}
        }
      }
    } catch (e) {
      callLog('CallManager', 'ringtone stop failed: $e');
    }
  }

  Future<void> _pulseIncomingVibration() async {
    switch (_callVibrationSetting) {
      case 'short':
        try {
          await HapticFeedback.lightImpact();
        } catch (_) {}
        return;
      case 'long':
        try {
          await HapticFeedback.mediumImpact();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 120));
        try {
          await HapticFeedback.heavyImpact();
        } catch (_) {}
        return;
      case 'system':
        try {
          await HapticFeedback.vibrate();
        } catch (_) {}
        return;
      default:
        return;
    }
  }

  void _startIncomingVibrationLoop() {
    if (_callVibrationSetting == 'off') return;
    unawaited(_pulseIncomingVibration());
    final period = _callVibrationSetting == 'long'
        ? const Duration(milliseconds: 1900)
        : const Duration(milliseconds: 1100);
    _incomingVibrationTimer = Timer.periodic(period, (_) {
      unawaited(_pulseIncomingVibration());
    });
  }

  void _startConnectTimeout() {
    _connectTimer?.cancel();
    _connectTimer = Timer(const Duration(seconds: 30), () async {
      final s = state.value;
      if (s.phase == CallPhase.connecting) {
        // Local-first: close UI before network send.
        await _endCall(CallEndReason.timeout);
        if (s.peerProfileId.isNotEmpty && s.callId.isNotEmpty) {
          try {
            await controller.sendCallHangup(
              peerProfileId: s.peerProfileId,
              callId: s.callId,
              callAttemptId: s.callAttemptId,
            );
          } catch (e) {
            callLog(
              'CallManager',
              'connect timeout hangup failed (best-effort): $e',
            );
          }
        }
      }
    });
  }

  void _startAnswerResend() {
    _answerResendTimer?.cancel();
    _answerResendAttempts = 0;
    _answerResendTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      final s = state.value;
      final answerSdp = _lastLocalAnswerSdp;
      if (answerSdp == null || answerSdp.isEmpty) {
        timer.cancel();
        _answerResendTimer = null;
        return;
      }
      if (s.phase == CallPhase.connected || !s.isActive) {
        timer.cancel();
        _answerResendTimer = null;
        return;
      }
      // Don't spend an attempt while the relay socket is down: on a cold VoIP
      // wake the WS is still reconnecting and an answer sent now is silently
      // dropped — the old 3-attempt/6 s budget burned out before the relay was
      // back, so the call connected only "every other time". Mirror
      // _startNeedOfferRetries: wait for relayOnline, and allow more attempts
      // (still well inside the 30 s connect timeout).
      // (Call-reliability audit 2026-06-27, BUG B.)
      if (!controller.relayOnline) {
        return;
      }
      if (_answerResendAttempts >= 6) {
        timer.cancel();
        _answerResendTimer = null;
        return;
      }
      _answerResendAttempts++;
      try {
        await controller.sendCallAnswer(
          peerProfileId: s.peerProfileId,
          callId: s.callId,
          callAttemptId: s.callAttemptId,
          sdp: answerSdp,
        );
        callOpLog(
          'CallManager',
          'answer_resend_sent',
          fields: <String, Object?>{
            'callId': s.callId,
            'callAttemptId': s.callAttemptId,
            'attempt': _answerResendAttempts,
          },
        );
        callLog('CallManager', 'answer resend #$_answerResendAttempts sent');
      } catch (e) {
        // Переотправка — последняя страховка ответа. Её отказ обязан быть
        // виден: шесть молчаливых неудач подряд и есть «звонок не соединился».
        callOpLog(
          'CallManager',
          'answer_resend_failed',
          fields: <String, Object?>{
            'attempt': _answerResendAttempts,
            'error': e.runtimeType,
          },
        );
        callLog(
          'CallManager',
          'answer resend #$_answerResendAttempts failed: $e',
        );
      }
    });
  }

  void _markConnectedFromSession({required String source}) {
    final s = state.value;
    _connectTimer?.cancel();
    _reconnectWatchdogTimer?.cancel();
    _reconnectWatchdogTimer = null;
    _stopReconnectingPoll();
    _iceRestartInFlightSafetyTimer?.cancel();
    _iceRestartInFlightSafetyTimer = null;
    _iceRestartAttempts = 0;
    _iceRestartInFlight = false;
    _connectivityHandoffRecoveryTimer?.cancel();
    _connectivityHandoffRecoveryTimer = null;
    _connectivityFollowUpRecoveryAttempts = 0;
    unawaited(_stopRingtone());
    if (s.phase != CallPhase.connected) {
      _transitionLifecycle(
        CallLifecycleEvent.mediaEstablished,
        source: source,
        connectedAtMs: s.connectedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      );
      _setCallActive(true);
      unawaited(_showOngoingCallNotification());
      // iOS single-owner audio (redesign 2026-07-09): one restart of the WebRTC
      // unit now that media is flowing, so it renders the remote track that (on
      // an answered call) attached after didActivate enabled the unit. Native
      // side does a single bounce; the route observer no longer loops on it, so
      // no delayed retries / churn are needed.
      _reassertIosCallAudio();
    }
  }

  void _reassertIosCallAudio() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    unawaited(
      _nativeCallUiChannel
          .invokeMethod<void>('reassertCallAudio')
          .catchError((_) {}),
    );
  }

  bool _resyncConnectedFromCurrentSession({required String source}) {
    final session = _session;
    if (session == null) return false;
    final rtcState = session.connectionState.value;
    final iceState = session.iceConnectionState.value;
    final mediaEstablished = session.mediaEstablished.value;
    final s = state.value;
    final iceConnected =
        iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted;
    final rtcConnected =
        rtcState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
    if (!shouldPromoteConnectedFromSession(
      phase: s.phase,
      wasEverConnected: s.connectedAtMs != null,
      rtcState: rtcState,
      iceState: iceState,
      mediaEstablished: mediaEstablished,
    )) {
      return false;
    }
    if (!rtcConnected && iceConnected && s.phase != CallPhase.connected) {
      callLog(
        'CallManager',
        'promoting call to connected after media truth confirmed via ICE state while peerConnectionState=$rtcState source=$source',
      );
    }
    if (!iceConnected && !rtcConnected && s.phase != CallPhase.connected) {
      callLog(
        'CallManager',
        'suppressing connected promotion because media exists without confirmed connected transport peerConnectionState=$rtcState iceState=$iceState source=$source',
      );
      return false;
    }
    _markConnectedFromSession(source: source);
    return true;
  }

  void _startNeedOfferRetries() {
    _offerRequestTimer?.cancel();
    _offerRequestTimer = null;
    _needOfferAttempts = 0;
    _offerRequestTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      final current = state.value;
      if (!shouldKeepNeedOfferRetriesRunning(
        phase: current.phase,
        isActive: current.isActive,
        hasPendingOffer: _pendingOfferSdp != null,
        awaitingRecoveryOffer: _awaitingRecoveryOffer,
      )) {
        timer.cancel();
        _offerRequestTimer = null;
        return;
      }
      if (!controller.relayOnline) {
        return;
      }
      if (_needOfferAttempts >= 8) {
        timer.cancel();
        _offerRequestTimer = null;
        return;
      }
      final reconciled = await _reconcileActiveCallWithRelay(
        trigger: 'need_offer_retry',
      );
      if (reconciled) {
        return;
      }
      _needOfferAttempts++;
      callLog(
        'CallManager',
        'offer missing while ${current.phase}; need_offer retry #$_needOfferAttempts',
      );
      try {
        await controller.sendCallNeedOffer(
          peerProfileId: current.peerProfileId,
          callId: current.callId,
          callAttemptId: current.callAttemptId,
        );
        callOpLog(
          'CallManager',
          'need_offer_retry_sent',
          fields: <String, Object?>{
            'callId': current.callId,
            'callAttemptId': current.callAttemptId,
            'attempt': _needOfferAttempts,
          },
        );
      } catch (e) {
        callLog(
          'CallManager',
          'need_offer retry #$_needOfferAttempts failed (non-fatal): $e',
        );
      }
    });
  }

  void _stopNeedOfferRetries() {
    _offerRequestTimer?.cancel();
    _offerRequestTimer = null;
    _needOfferAttempts = 0;
  }

  // Cold-launch caller-avatar resolve (2026-07-15). On a killed-app wake the
  // relay invite/offer signal that drives _refreshIncomingPeerDetails can land
  // before the local DB is open, so cachedProfileAvatarPath returns null
  // (app_controller returns null while _db == null) and the in-call screen shows
  // initials even after the user answers. Re-resolve a bounded number of times
  // until the photo lands (or the call ends) — ~6 * 700ms ≈ 4s covers the DB
  // open + first profile_meta sync on a fresh boot.
  static const int _incomingAvatarMaxRetries = 6;
  static const Duration _incomingAvatarRetryDelay = Duration(milliseconds: 700);

  bool _incomingCallStillLiveFor(String profileId) {
    final s = state.value;
    return s.peerProfileId == profileId &&
        s.phase != CallPhase.idle &&
        s.phase != CallPhase.ended;
  }

  Future<void> _refreshIncomingPeerDetails(
    String fromProfileId, {
    int attempt = 0,
  }) async {
    if (fromProfileId.trim().isEmpty) return;
    if (state.value.peerProfileId != fromProfileId) return;
    try {
      // FIX (2026-07-13, call avatar): resolve the peer photo via the SAME
      // resolver the chat uses — cachedProfileAvatarPath (contact avatar OR the
      // synced profile_meta photo) — instead of scanning saved contacts only.
      // That is why calls from a non-contact (or before meta sync) showed only
      // initials. The name still comes from the saved contact when available.
      // 🔴 ИМЯ — ТЕМ ЖЕ ПУТЁМ, ЧТО И ФОТО (22.08.2026). Раньше здесь перебирались
      // только СОХРАНЁННЫЕ контакты, поэтому звонок от того, кого нет в
      // контактах, оставался с сырым profile_id на экране, хотя никнейм лежит
      // в метаданных профиля — там же, откуда строкой ниже успешно берётся
      // фотография.
      String? nextName;
      try {
        final resolved = await controller.cachedProfileDisplayName(
          fromProfileId,
        );
        final trimmed = (resolved ?? '').trim();
        if (trimmed.isNotEmpty) nextName = trimmed;
      } catch (_) {}
      final avatar = await controller.cachedProfileAvatarPath(fromProfileId);
      final latest = state.value;
      if (latest.peerProfileId != fromProfileId) return;
      // No longer gated to ringingIncoming: a late-resolved avatar must still
      // land after the user accepts (connecting/connected) so the in-call screen
      // shows the photo. Only re-push the native incoming UI while ringing.
      state.value = latest.copyWith(
        peerName: nextName ?? latest.peerName,
        peerAvatarPath: avatar ?? latest.peerAvatarPath,
      );
      if (latest.phase == CallPhase.ringingIncoming) {
        unawaited(_showNativeIncomingUi());
      }
      // Retry until the avatar lands (cold-boot DB race, see above). Re-check
      // emptiness before each retry so ALL chains stop the moment one resolves,
      // and stop as soon as the call ends.
      final haveAvatar = (avatar ?? '').trim().isNotEmpty ||
          (latest.peerAvatarPath ?? '').trim().isNotEmpty;
      if (!haveAvatar &&
          attempt < _incomingAvatarMaxRetries &&
          _incomingCallStillLiveFor(fromProfileId)) {
        Future.delayed(_incomingAvatarRetryDelay, () {
          if (_incomingCallStillLiveFor(fromProfileId) &&
              (state.value.peerAvatarPath ?? '').trim().isEmpty) {
            unawaited(_refreshIncomingPeerDetails(
              fromProfileId,
              attempt: attempt + 1,
            ));
          }
        });
      }
    } catch (_) {}
  }

  bool _shouldThrottleCallUiPush(String routeName) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastCallUiRoute == routeName && nowMs - _lastCallUiPushAtMs < 300) {
      return true;
    }
    _lastCallUiRoute = routeName;
    _lastCallUiPushAtMs = nowMs;
    return false;
  }

  bool _isDuplicateCallUiPush(String routeName, String callId) {
    if (_pendingCallUiRoute == routeName && _pendingCallUiCallId == callId) {
      return true;
    }
    _pendingCallUiRoute = routeName;
    _pendingCallUiCallId = callId;
    _pendingCallUiGuardTimer?.cancel();
    _pendingCallUiGuardTimer = Timer(const Duration(milliseconds: 1200), () {
      _pendingCallUiRoute = '';
      _pendingCallUiCallId = '';
      _pendingCallUiGuardTimer = null;
    });
    return false;
  }

  bool _isVisibleCallUi(String routeName, String callId) {
    return _visibleCallUiRoute == routeName && _visibleCallUiCallId == callId;
  }

  void _markVisibleCallUi(String routeName, String callId) {
    _visibleCallUiRoute = routeName;
    _visibleCallUiCallId = callId;
  }

  void _clearVisibleCallUi() {
    _visibleCallUiRoute = '';
    _visibleCallUiCallId = '';
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  void _pushCallScreen({int retries = _activeCallUiRetryBudget}) {
    final s = state.value;
    if (!s.isActive) return;
    if (s.isUiMinimized) {
      state.value = s.copyWith(isUiMinimized: false);
    }
    final nav = navigatorKey.currentState;
    if (nav == null) {
      if (retries > 0) {
        Timer(_callUiRetryDelay, () => _pushCallScreen(retries: retries - 1));
      } else {
        callLog(
          'CallManager',
          '[OP] event=call_ui_push_failed reason=navigator_null',
        );
      }
      return;
    }
    if (_isVisibleCallUi('/call', s.callId)) {
      callOpLog(
        'CallManager',
        'call_ui_already_visible',
        fields: <String, Object?>{
          'route': '/call',
          'callId': s.callId,
          'callAttemptId': s.callAttemptId,
        },
      );
      return;
    }
    if (_isDuplicateCallUiPush('/call', s.callId)) return;
    if (_shouldThrottleCallUiPush('/call')) return;
    try {
      callLog('CallManager', '[OP] event=call_ui_push');
      unawaited(_hideNativeIncomingUi());
      _markVisibleCallUi('/call', s.callId);
      nav.pushNamedAndRemoveUntil('/call', (route) {
        final name = route.settings.name;
        return name != '/call' && name != '/incoming-call';
      });
    } catch (_) {
      if (retries > 0) {
        Timer(_callUiRetryDelay, () => _pushCallScreen(retries: retries - 1));
      } else {
        callLog(
          'CallManager',
          '[OP] event=call_ui_push_failed reason=push_exception',
        );
      }
    }
  }

  void _popCallScreens() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _clearVisibleCallUi();
    // Pop until we're back to a non-call route.
    nav.popUntil((route) {
      final name = route.settings.name;
      return name != '/call' && name != '/incoming-call';
    });
  }

  Future<void> _presentIncomingCallSurface() async {
    final current = state.value;
    if (current.phase != CallPhase.ringingIncoming || current.callId.isEmpty) {
      return;
    }
    // 🔴 ПРИ ОТКРЫТОМ ПРИЛОЖЕНИИ — ЭКРАН, А НЕ ВТОРАЯ ПЛАШКА (14.08.2026).
    //
    // Жалоба: на холодном старте нажал на уведомление, приложение открылось —
    // и следом выскочило ВТОРОЕ уведомление, и только оно открывало экран.
    //
    // Причина: нажатие на холодном старте доставляется ПОЗЖЕ, чем приезжает
    // приглашение (оно ждёт подписки на канал событий), а приглашение звало эту
    // функцию, и она показывала нативную плашку БЕЗУСЛОВНО — поверх уже
    // открытого приложения. Вторая плашка и была следствием.
    //
    // Нативная плашка нужна ровно тогда, когда показывать больше нечем: приложение
    // закрыто или в фоне. Если оно открыто — открываем экран входящего, он уже
    // умеет «Принять» и «Отклонить».
    // 🔴 ЭКРАН ОТКРЫВАЕТСЯ ТОЛЬКО ПО НАЖАТИЮ (14.08.2026, требование владельца).
    //
    // Раньше здесь стояло «приложение открыто → показать экран», и экран
    // выскакивал САМ поверх того, чем человек занят. Это неверно: входящий
    // звонок обязан заявлять о себе уведомлением, а решение открыть экран
    // принимает человек. Так работает Telegram, и так ожидаемо.
    //
    // Единственное исключение — он УЖЕ нажал: на холодном старте нажатие
    // приходит раньше, чем заводится состояние звонка, и просьбу надо
    // исполнить, когда появится чем.
    final showScreen = _incomingScreenRequested;
    callOpLog(
      'CallManager',
      showScreen ? 'incoming_surface_screen' : 'incoming_surface_native',
      fields: <String, Object?>{
        'callId': current.callId,
        'callAttemptId': current.callAttemptId,
      },
    );
    if (showScreen) {
      _pushCallScreen();
      return;
    }
    await _showNativeIncomingUi();
  }

  // ── Native ongoing-call surface ────────────────────────────────────────

  Future<void> _startOutgoingNativeCallUi() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final s = state.value;
    if (!s.isActive || s.callId.isEmpty) return;
    if (s.direction != CallDirection.outgoing) return;
    try {
      await _nativeCallUiChannel.invokeMethod('startOutgoingNative', {
        'callId': s.callId,
        'callAttemptId': s.callAttemptId,
        'peerName': s.peerName,
        'isVideo': s.isVideo,
      });
    } catch (_) {
      // best-effort only
    }
  }

  /// Show a persistent "Call in progress — tap to return" notification so the
  /// user can restore the call screen or keep the native system call surface
  /// in sync while the app is backgrounded.
  ///
  /// On Android this also starts CallForegroundService (foregroundServiceType=
  /// phoneCall), which is the only guarantee that the OS won't kill the
  /// Flutter process mid-call on MIUI / EMUI / OneUI.
  Future<void> _showOngoingCallNotification() async {
    if (!_supportsNativeCallUiPlatform) return;
    final s = state.value;
    if (!s.isActive || s.callId.isEmpty) return;
    if (s.phase == CallPhase.ringingIncoming) return;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        s.direction == CallDirection.outgoing &&
        s.phase == CallPhase.ringingOutgoing) {
      await _startOutgoingNativeCallUi();
      return;
    }
    // 🔴 НА ANDROID ВО ВРЕМЯ РАЗГОВОРА ДОЛЖНО БЫТЬ ОДНО УВЕДОМЛЕНИЕ (14.08.2026).
    //
    // Жалоба владельца: их два, одно «неизвестное». Так и есть — служба
    // переднего плана держит своё (канал secretly_active_call, ID 42001), а
    // приложение показывало ещё одно (secretly_ongoing_calls, ID 2). Оба с
    // кнопкой отбоя, поэтому «с уведомления не сбрасывается» — человек жал то,
    // которое не ждали.
    //
    // Уведомление службы убрать НЕЛЬЗЯ: без него Android вправе убить процесс
    // во время разговора. Значит лишнее — второе. Служба показывает имя
    // собеседника и тип звонка и несёт свой отбой, то есть покрывает то же.
    //
    // На iOS роль службы играет CallKit, поэтому там всё как было — оттого у
    // владельца «на айфоне как часы».
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _startCallForegroundService();
      return;
    }
    try {
      callOpLog(
        'CallManager',
        'native_ongoing_notification_show',
        fields: <String, Object?>{
          'callId': s.callId,
          'callAttemptId': s.callAttemptId,
          'isVideo': s.isVideo,
        },
      );
      await _nativeCallUiChannel.invokeMethod('showOngoingCallNative', {
        'callId': s.callId,
        'callAttemptId': s.callAttemptId,
        'peerName': s.peerName,
        'isVideo': s.isVideo,
        'avatarPath': s.peerAvatarPath,
      });
    } catch (_) {
      // best-effort only
    }
  }

  Future<void> _hideOngoingCallNotification() async {
    if (!_supportsNativeCallUiPlatform) return;
    final current = state.value;
    final callId = current.callId;
    if (callId.isEmpty) return;
    // Android: stop the foreground service so the OS process-priority
    // elevation is released once the call is truly over.
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_stopCallForegroundService());
    }
    try {
      await _nativeCallUiChannel.invokeMethod('hideOngoingCallNative', {
        'callId': callId,
        'callAttemptId': current.callAttemptId,
      });
    } catch (_) {
      // best-effort only
    }
  }

  // ── Android foreground-service helpers ──────────────────────────────────

  Future<void> _startCallForegroundService() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (_callForegroundServiceRunning) return;
    final s = state.value;
    if (!s.isActive || s.callId.isEmpty) return;
    try {
      _callForegroundServiceRunning = true;
      // Ensure the app has runtime permissions (microphone / bluetooth) that
      // are required by Android when starting a foreground service with
      // microphone/camera types.
      //
      // A 12-second timeout protects against the Future hanging when the
      // permission dialog is dismissed by backgrounding the activity on some
      // Android versions where onRequestPermissionsResult doesn't fire. The
      // native onPause hook also resolves the pending Future as a safety net.
      final granted = await _nativeCallUiChannel
          .invokeMethod<bool>('requestCallPermissions')
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              callOpLog(
                'CallManager',
                'call_perms_request_timeout',
                fields: <String, Object?>{'callId': s.callId},
              );
              return false;
            },
          );
      if (granted != true) {
        callOpLog('CallManager', 'call_perms_denied', fields: <String, Object?>{
          'callId': s.callId,
        });
        // Start FGS anyway: native startForegroundCompat dynamically excludes
        // MICROPHONE/CAMERA service types when their runtime perms are absent,
        // so the service still elevates process priority and protects against
        // OEM background kill. Audio capture itself will be blocked at the
        // WebRTC layer until the user grants RECORD_AUDIO — but at least the
        // signalling stays alive long enough for the user to receive the
        // "permission required" UX prompt without dropping the entire call.
      }

      await _nativeCallUiChannel.invokeMethod('startCallForegroundService', {
        'callId': s.callId,
        'callAttemptId': s.callAttemptId,
        'peerName': s.peerName,
        'isVideo': s.isVideo,
      });
    } catch (_) {
      _callForegroundServiceRunning = false;
    }
  }

  Future<void> _stopCallForegroundService() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (!_callForegroundServiceRunning) return;
    _callForegroundServiceRunning = false;
    try {
      await _nativeCallUiChannel.invokeMethod('stopCallForegroundService');
    } catch (_) {
      // best-effort
    }
  }

  void _logNativeActionNoOp({
    required String action,
    required CallState current,
  }) {
    callOpLog(
      'CallManager',
      'native_call_action_no_op_phase',
      fields: <String, Object?>{
        'action': action,
        'phase': current.phase,
        'callId': current.callId,
        'callAttemptId': current.callAttemptId,
      },
    );
  }

  bool _consumePendingNativeActionForCurrentRinging() {
    final s = state.value;
    if (s.phase != CallPhase.ringingIncoming) return false;
    final pendingAction = _pendingNativeCallAction;
    if (pendingAction == null) return false;
    final pendingCallId = _pendingNativeActionCallId;
    final pendingAttemptId = _pendingNativeActionAttemptId;
    _pendingNativeCallAction = null;
    _pendingNativeActionCallId = '';
    _pendingNativeActionAttemptId = '';
    if (!shouldAcceptNativeCallAction(
      currentCallId: s.callId,
      currentCallAttemptId: s.callAttemptId,
      actionCallId: pendingCallId,
      actionCallAttemptId: pendingAttemptId,
    )) {
      // 🔴 РЕШЕНИЕ ЧЕЛОВЕКА ПОТЕРЯНО БЕЗВОЗВРАТНО: буфер очищен строками выше
      // ДО этой проверки, а слот всего один. Нажатие, относившееся к другому
      // звонку, больше нигде не всплывёт.
      callOpLog(
        'CallManager',
        'buffered_native_action_mismatch',
        fields: <String, Object?>{
          'action': pendingAction,
          'callId': pendingCallId,
          'callAttemptId': pendingAttemptId,
        },
      );
      return false;
    }
    callOpLog(
      'CallManager',
      'buffered_native_action_flushed',
      fields: <String, Object?>{
        'action': pendingAction,
        'callId': pendingCallId,
        'callAttemptId': pendingAttemptId,
      },
    );
    if (pendingAction == 'accept') {
      unawaited(acceptIncoming());
      return true;
    }
    if (pendingAction == 'decline') {
      unawaited(declineIncoming());
      return true;
    }
    return false;
  }

  /// The user tapped the body of an incoming-call notification for a call this
  /// isolate knows nothing about — the cold start (see
  /// [shouldAdoptNativeIncomingRingWithoutState]).
  ///
  /// There is no screen to raise yet, and that is the correct outcome: the ring
  /// is still up (the tap deliberately no longer dismisses it — see
  /// `MainActivity.handleCallDecisionIntent`), so Accept/Decline keep working,
  /// and the relay redelivers the invite moments later, which raises the real
  /// incoming surface through the ordinary path.
  ///
  /// Two things still have to happen here:
  ///
  ///  1. **Adopt the ring.** Seed [_lastNativeIncomingCallId] so every existing
  ///     dismissal path can target a notification this isolate never posted.
  ///     Same seeding [processStartupCallHint] performs for a fresh push hint.
  ///  2. **Arm a watchdog.** The ring is `ongoing` — it cannot be swiped away.
  ///     If the invite never arrives (relay hiccup, call already dead and its
  ///     signals long since drained) nothing else on this device would ever
  ///     take that notification down. The window is the ring window: past it,
  ///     a ring is dead by definition everywhere else in this class.
  void _adoptNativeIncomingRing({
    required String callId,
    required String callAttemptId,
  }) {
    _lastNativeIncomingCallId = callId;
    _lastNativeIncomingCallAttemptId = callAttemptId;
    // We may already know this attempt is dead: the ended-attempt keys survive a
    // restart in prefs. No reason to make the user stare at a ring for a call
    // that is over — take it down now rather than at the watchdog.
    if (shouldSuppressSignalForEndedCallAttempt(
      endedCallAttemptKeys: _lastEndedCallAttemptKeys,
      signalCallId: callId,
      signalCallAttemptId: callAttemptId,
    )) {
      callOpLog(
        'CallManager',
        'native_incoming_ring_already_ended',
        fields: <String, Object?>{
          'callId': callId,
          'callAttemptId': callAttemptId,
        },
      );
      unawaited(_hideNativeIncomingUi());
      return;
    }
    // Нажали на уведомление — значит хотят видеть экран. Состояния ещё нет,
    // поэтому запоминаем просьбу и исполним её, как только оно появится.
    _incomingScreenRequested = true;
    callOpLog(
      'CallManager',
      'native_incoming_ring_adopted',
      fields: <String, Object?>{
        'callId': callId,
        'callAttemptId': callAttemptId,
      },
    );
    _adoptedRingWatchdog?.cancel();
    _adoptedRingWatchdog = Timer(
      const Duration(seconds: ringTimeoutSeconds),
      () async {
        _adoptedRingWatchdog = null;
        if (state.value.callId == callId) {
          // The invite landed. Whatever phase this call is in now — still
          // ringing, connecting, talking — it belongs to the state machine, and
          // the state machine owns its notifications.
          //
          // 🔴 Checked on the callId ALONE, not on `phase == ringingIncoming`.
          // `hideIncomingNative` also clears the call's decision token
          // (MainActivity), and that token is what authorises a tap on the
          // ONGOING-call notification. Firing this at a call that got answered
          // would leave the user with a live call whose notification no longer
          // responds to being tapped.
          return;
        }
        if (_lastNativeIncomingCallId != callId) {
          // Something already took ownership of this notification.
          return;
        }
        callOpLog(
          'CallManager',
          'native_incoming_ring_orphaned',
          fields: <String, Object?>{
            'callId': callId,
            'callAttemptId': callAttemptId,
          },
        );
        _lastNativeIncomingCallId = '';
        _lastNativeIncomingCallAttemptId = '';
        if (!_supportsNativeCallUiPlatform) return;
        // Addressed by explicit id rather than through _hideNativeIncomingUi:
        // by now the state may hold a DIFFERENT call, and that helper would
        // dismiss whatever the state points at instead of this orphan.
        try {
          await _nativeCallUiChannel.invokeMethod<void>('hideIncomingNative', {
            'callId': callId,
            'callAttemptId': callAttemptId,
          });
        } catch (_) {
          // best-effort only
        }
      },
    );
  }

  bool _isNativeIncomingUiActiveFor(CallState s) {
    if (s.phase != CallPhase.ringingIncoming || s.callId.isEmpty) return false;
    if (_lastNativeIncomingCallId != s.callId) return false;
    final expectedAttemptId = s.callAttemptId.isNotEmpty
        ? s.callAttemptId
        : s.callId;
    final nativeAttemptId = _lastNativeIncomingCallAttemptId.isNotEmpty
        ? _lastNativeIncomingCallAttemptId
        : _lastNativeIncomingCallId;
    return expectedAttemptId == nativeAttemptId;
  }

  bool _shouldKeepNativeIncomingUiForCurrentCall() {
    return _isNativeIncomingUiActiveFor(state.value);
  }

  bool _shouldSuppressFlutterIncomingRingtone() {
    return _supportsNativeCallUiPlatform;
  }

  Future<void> _showNativeIncomingUi() async {
    if (!_supportsNativeCallUiPlatform) return;
    final s = state.value;
    if (s.phase != CallPhase.ringingIncoming || s.callId.isEmpty) return;
    try {
      callOpLog(
        'CallManager',
        'native_incoming_ui_show',
        fields: <String, Object?>{
          'callId': s.callId,
          'callAttemptId': s.callAttemptId,
          'isVideo': s.isVideo,
        },
      );
      _lastNativeIncomingCallId = s.callId;
      _lastNativeIncomingCallAttemptId = s.callAttemptId;
      await _nativeCallUiChannel.invokeMethod('showIncomingNative', {
        'callId': s.callId,
        'callAttemptId': s.callAttemptId,
        'peerName': s.peerName,
        'isVideo': s.isVideo,
        'avatarPath': s.peerAvatarPath,
      });
    } catch (_) {
      if (_lastNativeIncomingCallId == s.callId &&
          _lastNativeIncomingCallAttemptId == s.callAttemptId) {
        _lastNativeIncomingCallId = '';
        _lastNativeIncomingCallAttemptId = '';
      }
      // best-effort only
    }
  }

  Future<void> _hideNativeIncomingUi() async {
    if (!_supportsNativeCallUiPlatform) return;
    final current = state.value;
    final callId = current.callId.isNotEmpty
        ? current.callId
        : _lastNativeIncomingCallId;
    if (callId.isEmpty) return;
    try {
      await _nativeCallUiChannel.invokeMethod('hideIncomingNative', {
        'callId': callId,
        'callAttemptId': current.callAttemptId.isNotEmpty
            ? current.callAttemptId
            : _lastNativeIncomingCallAttemptId,
      });
      _lastNativeIncomingCallId = '';
      _lastNativeIncomingCallAttemptId = '';
    } on MissingPluginException catch (e) {
      // PR-G bug 20: older native builds never registered the
      // `hideIncomingNative` handler — the notification would silently linger
      // because the catch-all below swallowed the exception. Log explicitly
      // so we can spot this in DebugConsole on mixed-version installs.
      callLog(
        'CallManager',
        'hideIncomingNative MissingPluginException — native build is outdated: $e',
      );
    } catch (e) {
      callLog('CallManager', 'hideIncomingNative failed (best-effort): $e');
    }
  }

  void _onNativeCallAction(dynamic event) {
    if (event is! Map) return;
    final map = Map<String, dynamic>.from(event);
    final action = (map['action'] as String?)?.trim().toLowerCase() ?? '';
    final callId = (map['callId'] as String?)?.trim() ?? '';
    final callAttemptId = (map['callAttemptId'] as String?)?.trim() ?? callId;
    final current = state.value;
    if (action.isEmpty || callId.isEmpty) return;
    if (!shouldAcceptNativeCallAction(
      currentCallId: current.callId,
      currentCallAttemptId: current.callAttemptId,
      actionCallId: callId,
      actionCallAttemptId: callAttemptId,
    )) {
      if (shouldAdoptNativeIncomingRingWithoutState(
        currentCallId: current.callId,
        action: action,
      )) {
        _adoptNativeIncomingRing(callId: callId, callAttemptId: callAttemptId);
        return;
      }
      if (shouldBufferNativeCallActionWithoutState(
        currentCallId: current.callId,
        action: action,
      )) {
        _pendingNativeCallAction = action;
        _pendingNativeActionCallId = callId;
        _pendingNativeActionAttemptId = callAttemptId;
        // 🔴 РЕШЕНИЕ ЧЕЛОВЕКА ЛЁГЛО В БУФЕР — ЭТО ОБЯЗАНО БЫТЬ ВИДНО.
        //
        // Буфер разбирается ТОЛЬКО при переходе в «звонит входящий». Если
        // приглашение до Dart не доедет, нажатие останется здесь навсегда, и
        // снаружи это выглядит как полная тишина: человек нажал «Принять»,
        // звонящий ждёт 45 секунд и сдаётся. Свободный текст в релизе
        // отбрасывается, поэтому прошлый разбор (15.08) этой строки не увидел.
        callOpLog(
          'CallManager',
          'native_call_action_buffered',
          fields: <String, Object?>{
            'action': action,
            'callId': callId,
            'callAttemptId': callAttemptId,
          },
        );
      } else {
        callOpLog(
          'CallManager',
          'native_call_action_dropped_stale',
          fields: <String, Object?>{
            'action': action,
            'callId': callId,
            'callAttemptId': callAttemptId,
            'phase': current.phase,
          },
        );
      }
      return;
    }
    callOpLog(
      'CallManager',
      'native_call_action_received',
      fields: <String, Object?>{
        'action': action,
        'callId': callId,
        'callAttemptId': callAttemptId,
      },
    );
    switch (action) {
      case 'accept':
        if (current.phase == CallPhase.ringingIncoming) {
          unawaited(acceptIncoming());
        } else {
          // 🔴 НАЖАТИЕ ПРИНЯТО И НАПЕЧАТАНО ВЫШЕ, НО НЕ ДЕЛАЕТ НИЧЕГО.
          // Без этой строки лог показывает `native_call_action_received
          // action=accept` и дальше тишину — неотличимо от успешного приёма,
          // у которого что-то сломалось позже.
          _logNativeActionNoOp(action: action, current: current);
        }
        return;
      case 'decline':
        if (current.phase == CallPhase.ringingIncoming) {
          unawaited(declineIncoming());
        } else {
          _logNativeActionNoOp(action: action, current: current);
        }
        return;
      case 'hangup':
        if (current.isActive) {
          unawaited(hangup());
        }
        return;
      // PR-G (bug 18): CallKit on iOS emits "cancel" when the caller hangs
      // up an outgoing call before media connects (auto-fail or user-tap on
      // the CallKit "End" button). Treat it identically to a local hangup —
      // hangup() snapshots the call state, runs `_endCall` for local
      // teardown, and fires the hangup control to the callee.
      case 'cancel':
        if (current.isActive) {
          unawaited(hangup());
        }
        return;
      // Two notifications, one wish: "put that call back in front of me".
      // `tap` is the body of the INCOMING notification, `restore` the body of
      // the ONGOING one. Neither is a decision — they only ask for the surface.
      //
      // `tap` arrives here on the warm path only: the app was alive and already
      // knows this call (the cold path has no state to match and is adopted
      // above). Two things it settles that nothing else would:
      //   • the call is already ACTIVE — the user tapped a stale ring for a call
      //     answered moments ago; without this they land on the chat list
      //     instead of the call they asked for;
      //   • still ringing, but the ring was swept off the shade by an OEM shell
      //     — onAppLifecycleStateChanged skips the re-post in that case,
      //     trusting _lastNativeIncomingCallId to mean the ring is still up.
      case 'tap':
      case 'restore':
        // 🔴 НАЖАТИЕ НА УВЕДОМЛЕНИЕ ОТКРЫВАЕТ ЭКРАН ВХОДЯЩЕГО (13.08.2026).
        //
        // 12.08 я уже пробовал так и СЛОМАЛ звонки: направил сюда, а на экране
        // единственной кнопкой со звонком был отбой — человек жал «ответить» и
        // сбрасывал себе вызов. Правка была откачена.
        //
        // Теперь порядок обратный и потому безопасный: на экране при
        // ringingIncoming стоят ДВЕ кнопки — зелёная «Принять» и красная
        // «Отклонить», — и только после этого сюда направлено нажатие.
        //
        // Правило 06.08 соблюдено: `tap` не решение. Мы лишь ПОКАЗЫВАЕМ, а
        // решает человек, глядя на того, кто звонит.
        if (current.phase == CallPhase.ringingIncoming) {
          _pushCallScreen();
          return;
        }
        if (current.isActive) {
          if (current.isUiMinimized) {
            resumeCallUi();
          } else {
            _pushCallScreen();
          }
        }
        return;
    }
    callOpLog(
      'CallManager',
      'native_call_action_ignored',
      fields: <String, Object?>{
        'action': action,
        'callId': callId,
        'callAttemptId': callAttemptId,
        'phase': current.phase,
      },
    );
  }
}
