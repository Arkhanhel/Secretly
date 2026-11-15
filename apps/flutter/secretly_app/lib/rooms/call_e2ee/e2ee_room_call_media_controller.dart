// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Медиа зашифрованного созвона (контракт `room_media_e2ee_v1`).
///
/// ТЗ: `docs/TZ_GROUP_CALL_E2EE_2026-10-06.md`, §4–§5.
///
/// **Своё шифрование поверх `flutter_webrtc`, а не E2EE-менеджер LiveKit.**
/// Комната LiveKit создаётся БЕЗ `e2eeOptions`: у менеджера `livekit_client
/// 2.4.0` найдены ловушки, которые снаружи не закрыть (ключ в журнале,
/// подмена трейлером SIF, выключатель `setE2EEEnabled`, шифратор вешается
/// после согласования, исключение оставляет дорожку открытой, пометке сервера
/// «дорожка зашифрована» верят на слово). Здесь шифраторы вешаются напрямую:
/// - **каждый** отправитель своего соединения получает шифратор — и тот, что
///   опубликован нами, и любой появившийся иначе (резервный кодек,
///   повторная публикация после переподключения): проверка идёт по списку
///   отправителей соединения, а не по событиям;
/// - **каждый** принятый поток проходит через расшифровщик; серверной
///   пометке «не зашифровано» не верим — в зашифрованном созвоне таких нет;
/// - своя дорожка публикуется ВЫКЛЮЧЕННОЙ (тишина, чёрный кадр) и
///   включается только когда шифратор её отправителя повешен и включён, а
///   свой ключ стоит. Защитному флагу натива «без шифратора не отправлять»
///   не верим: он теряется в копирующем конструкторе на всех платформах
///   (ЛК-13). Без ключа кадр выбрасывается (`missingKey`), открытым не уходит;
/// - чужая дорожка глушится в момент подписки и включается после того, как
///   расшифровщик повешен: всё, что придёт дальше, либо расшифруется, либо
///   будет выброшено;
/// - участник, чья идентичность в LiveKit не сошлась с функцией `I(P, D)` от
///   снимка созвона, — «неизвестный»: на него не подписываемся и ключей не
///   даём.
///
/// Отказ везде закрытый: нет платформы, нет идентичности, нет шифратора —
/// нет медиа, а не открытое медиа.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../calls/call_log.dart';
import '../../calls/screen_share_runtime.dart';
import '../../transport/relay_client.dart';
import '../room_call_media_controller.dart';
import '../room_call_media_state.dart';
import 'call_e2ee_protocol.dart';
import 'call_key_book.dart';
import 'call_key_transport.dart';
import 'room_call_e2ee_status.dart';
import '../room_call_stealth.dart';

/// Через сколько без расшифровки просить ключ (§4.3).
const Duration _kRequestKeyAfter = Duration(seconds: 3);

/// Через сколько без расшифровки показывать «не удаётся расшифровать».
const Duration _kFailingAfter = Duration(seconds: 10);

/// Не чаще одной просьбы одному участнику.
const Duration _kRequestKeyEvery = Duration(seconds: 5);

/// Не чаще одного ответа одному спрашивающему.
const Duration _kReplyKeyEvery = Duration(seconds: 10);

/// Как часто сверять отправителей и получателей с шифраторами.
const Duration _kSweepEvery = Duration(seconds: 2);

class _RemoteCryptor {
  _RemoteCryptor({
    required this.cryptor,
    required this.identity,
    required this.deviceId,
    required this.attachedAtMs,
  });

  final rtc.FrameCryptor cryptor;
  final String identity;
  final String deviceId;
  final int attachedAtMs;
  rtc.FrameCryptorState state = rtc.FrameCryptorState.FrameCryptorStateNew;
  int lastOkAtMs = 0;
}

class _VerifiedPeer {
  const _VerifiedPeer(this.profileId, this.deviceId);

  final String profileId;
  final String deviceId;
}

class _E2eeBinding {
  const _E2eeBinding({this.cameraTrack, this.screenShareTrack});

  final lk.VideoTrack? cameraTrack;
  final lk.VideoTrack? screenShareTrack;

  String get signature =>
      '${_trackSignature(cameraTrack)}|${_trackSignature(screenShareTrack)}';
}

String _trackSignature(lk.VideoTrack? track) {
  if (track == null) return 'none';
  final sid = ((track as lk.Track).sid ?? '').trim();
  return sid.isNotEmpty ? sid : track.hashCode.toString();
}

bool _defaultPlatformSupported() {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    _ => false,
  };
}

/// Медиа зашифрованного созвона на LiveKit.
class E2eeLiveKitRoomCallMediaController
    implements RoomCallMediaController, RoomCallE2eeStatusSource {
  E2eeLiveKitRoomCallMediaController({
    required RoomCallKeyTransport transport,
    int Function()? keySwitchDelayMs,
    bool Function()? platformSupported,
    Future<RoomCallStealthPlan?> Function()? stealthPlan,
  }) : _transport = transport,
       _keySwitchDelayMs = keySwitchDelayMs ?? (() => 2000),
       _platformSupported = platformSupported ?? _defaultPlatformSupported,
       _stealthPlan = stealthPlan;

  final RoomCallKeyTransport _transport;
  final int Function() _keySwitchDelayMs;
  final bool Function() _platformSupported;
  final Future<RoomCallStealthPlan?> Function()? _stealthPlan;

  final ValueNotifier<RoomCallLocalMediaState> _state = ValueNotifier(
    const RoomCallLocalMediaState.idle(),
  );
  final ValueNotifier<RoomCallE2eeStatus?> _e2ee = ValueNotifier(
    const RoomCallE2eeStatus(own: RoomCallE2eeOwnState.connecting),
  );

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  RelayRoomCallMediaSession? _session;
  String _runtimeKey = '';
  Future<void>? _connectInFlight;
  bool _disposed = false;

  rtc.KeyProvider? _keyProvider;
  CallKeyBook? _book;
  String _bookCallKey = '';
  String _selfIdentity = '';
  StreamSubscription<InboundRoomCallKeyCommand>? _keySub;
  Timer? _sweepTimer;
  Future<void> _sweepChain = Future<void>.value();
  Future<void> _publishChain = Future<void>.value();
  Future<void> _sendChain = Future<void>.value();

  /// Шифраторы своих отправителей по идентификатору отправителя.
  final Map<String, rtc.FrameCryptor> _senderCryptors =
      <String, rtc.FrameCryptor>{};

  /// Расшифровщики чужих потоков по идентификатору получателя.
  final Map<String, _RemoteCryptor> _receiverCryptors =
      <String, _RemoteCryptor>{};

  /// Идентичность → (профиль, устройство) из снимка созвона.
  Map<String, _VerifiedPeer> _verified = const <String, _VerifiedPeer>{};

  /// Кому какой эпохой свой ключ уже отправлен.
  final Map<String, int> _ownEpochSentTo = <String, int>{};
  final Map<String, int> _lastRequestAtMs = <String, int>{};
  final Map<String, int> _lastReplyAtMs = <String, int>{};
  final Map<String, int> _unverifiedSinceMs = <String, int>{};

  /// Пока идёт полное переподключение — свои дорожки выключены.
  bool _restarting = false;

  ScreenShareRuntimeLease? _screenShareLease;
  bool _speakerEnabled = true;
  bool _usingFrontCamera = true;
  int _runtimeRevision = 0;
  int _speakingRevision = 0;
  String? _statusMessage;
  bool _statusMessageIsFatal = false;
  String? _errorCode;
  Set<String> _speakingDeviceIds = const <String>{};
  Map<String, _E2eeBinding> _bindings = const <String, _E2eeBinding>{};
  String _bindingsSignature = '';
  Map<String, lk.Participant> _participantsByDeviceId =
      const <String, lk.Participant>{};
  String? _selectedAudioInputId;
  String? _selectedVideoInputId;

  @override
  ValueListenable<RoomCallLocalMediaState> get state => _state;

  @override
  ValueListenable<RoomCallE2eeStatus?> get e2eeStatus => _e2ee;

  @override
  rtc.RTCVideoRenderer? get localRenderer => null;

  // ── Вид участников ──────────────────────────────────────────────────────

  @override
  bool hasParticipantCameraView(String deviceId) =>
      _bindings[deviceId.trim()]?.cameraTrack != null;

  @override
  bool hasParticipantScreenShareView(String deviceId) =>
      _bindings[deviceId.trim()]?.screenShareTrack != null;

  @override
  bool isParticipantSpeaking(String deviceId) =>
      _speakingDeviceIds.contains(deviceId.trim());

  @override
  Widget? buildParticipantVideoView({
    required String deviceId,
    bool mirror = false,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) {
    final binding = _bindings[deviceId.trim()];
    final track = switch (kind) {
      RoomCallVideoKind.auto =>
        binding?.screenShareTrack ?? binding?.cameraTrack,
      RoomCallVideoKind.screenShare => binding?.screenShareTrack,
      RoomCallVideoKind.camera => binding?.cameraTrack,
    };
    if (track == null) return null;
    Widget child = lk.VideoTrackRenderer(track);
    if (mirror) child = Transform.flip(flipX: true, child: child);
    return KeyedSubtree(
      key: ValueKey(
        'room-e2ee-video:${deviceId.trim()}:${kind.name}:'
        '${binding!.signature}:${_state.value.runtimeRevision}',
      ),
      child: child,
    );
  }

  // ── Устройства ──────────────────────────────────────────────────────────

  @override
  Future<List<RoomCallVideoDevice>> videoInputs() async {
    try {
      final devices = await lk.Hardware.instance.videoInputs();
      return devices
          .map(
            (d) => RoomCallVideoDevice(
              deviceId: d.deviceId,
              label: d.label.trim().isEmpty
                  ? RoomCallUnnamedDeviceLabels.camera
                  : d.label.trim(),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <RoomCallVideoDevice>[];
    }
  }

  @override
  Future<List<RoomCallVideoDevice>> audioInputs() async {
    try {
      final devices = await lk.Hardware.instance.audioInputs();
      return devices
          .map(
            (d) => RoomCallVideoDevice(
              deviceId: d.deviceId,
              label: d.label.trim().isEmpty
                  ? RoomCallUnnamedDeviceLabels.microphone
                  : d.label.trim(),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <RoomCallVideoDevice>[];
    }
  }

  @override
  String? get selectedAudioInputId => _selectedAudioInputId;

  @override
  String? get selectedVideoInputId => _selectedVideoInputId;

  /// Смена микрофона меняет дорожку на ТОМ ЖЕ отправителе (`replaceTrack`):
  /// его шифратор остаётся. До того как шифратор повешен, смена только
  /// запоминается и применится при публикации.
  @override
  Future<void> selectAudioInput(String deviceId) async {
    final want = deviceId.trim();
    if (want.isEmpty) return;
    _selectedAudioInputId = want;
    final pub = _ownPublication(lk.TrackSource.microphone);
    final track = pub?.track;
    if (track is! lk.LocalAudioTrack || !_isArmed(track)) return;
    try {
      await track.setDeviceId(want);
      _clearStatusMessage();
    } catch (e) {
      callLog('RoomE2ee', 'selectAudioInput failed: $e');
      _setStatusMessage(e.toString(), fatal: false);
    }
    _runtimeRevision += 1;
    _refreshState();
  }

  @override
  Future<void> selectVideoInput(String deviceId) async {
    final want = deviceId.trim();
    if (want.isEmpty) return;
    _selectedVideoInputId = want;
    final pub = _ownPublication(lk.TrackSource.camera);
    final track = pub?.track;
    if (track is! lk.LocalVideoTrack || !_isArmed(track)) return;
    try {
      await track.switchCamera(want);
      _clearStatusMessage();
    } catch (e) {
      callLog('RoomE2ee', 'selectVideoInput failed: $e');
      _setStatusMessage(e.toString(), fatal: false);
    }
    _rebuildBindings();
    _runtimeRevision += 1;
    _refreshState();
  }

  @override
  Future<void> switchCamera() async {
    final pub = _ownPublication(lk.TrackSource.camera);
    final track = pub?.track;
    if (track is! lk.LocalVideoTrack || !_isArmed(track)) return;
    try {
      await track.setCameraPosition(
        _usingFrontCamera ? lk.CameraPosition.back : lk.CameraPosition.front,
      );
      _usingFrontCamera = !_usingFrontCamera;
      _clearStatusMessage();
    } catch (e) {
      callLog('RoomE2ee', 'switchCamera failed: $e');
      _setStatusMessage(e.toString(), fatal: false);
    }
    _rebuildBindings();
    _refreshState();
  }

  @override
  Future<RoomCallVideoStats?> videoStats({
    required String deviceId,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) async {
    final binding = _bindings[deviceId.trim()];
    final track = switch (kind) {
      RoomCallVideoKind.auto =>
        binding?.screenShareTrack ?? binding?.cameraTrack,
      RoomCallVideoKind.screenShare => binding?.screenShareTrack,
      RoomCallVideoKind.camera => binding?.cameraTrack,
    };
    if (track is! lk.RemoteVideoTrack) return null;
    try {
      final stats = await track.getReceiverStats();
      if (stats == null) return null;
      final out = RoomCallVideoStats(
        width: stats.frameWidth?.toInt(),
        height: stats.frameHeight?.toInt(),
        fps: stats.framesPerSecond?.toDouble(),
      );
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  @override
  double participantAudioLevel(String deviceId) {
    final p = _participantsByDeviceId[deviceId.trim()];
    if (p == null) return 0;
    final level = p.audioLevel;
    return level.isFinite ? level.clamp(0.0, 1.0) : 0;
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    _speakerEnabled = enabled;
    final room = _room;
    if (room != null) await _applySpeakerRoute(room);
    _refreshState();
  }

  // ── Синхронизация со снимком реле ───────────────────────────────────────

  @override
  Future<void> syncSession({required RelayRoomCallMediaSession session}) async {
    if (_disposed) return;
    _session = session;
    final self = session.selfParticipant;
    if (self == null || !self.isJoined) {
      await _teardown();
      _bindings = const <String, _E2eeBinding>{};
      _bindingsSignature = '';
      _clearStatusMessage();
      _runtimeRevision += 1;
      _setState(
        RoomCallLocalMediaState.idle(
          speakerEnabled: _speakerEnabled,
          usingFrontCamera: _usingFrontCamera,
        ).copyWith(
          runtimeRevision: _runtimeRevision,
          speakingRevision: _speakingRevision,
        ),
      );
      return;
    }
    // Закрытый отказ: не тот контракт, нет платформы, не та идентичность.
    if (!isE2eeRoomMediaContract(session.contractVersion)) {
      _fail('contract_mismatch');
      return;
    }
    if (!_platformSupported()) {
      _fail('platform_unsupported');
      return;
    }
    final expected = roomMediaParticipantIdentity(
      session.selfProfileId.trim(),
      session.selfDeviceId.trim(),
    );
    if ((session.backend.participantIdentity ?? '').trim() != expected) {
      _fail('identity_mismatch');
      return;
    }
    _selfIdentity = expected;

    if (_room?.connectionState != lk.ConnectionState.connected) {
      _setState(
        _state.value.copyWith(
          phase: RoomCallLocalMediaPhase.acquiring,
          speakerEnabled: _speakerEnabled,
          usingFrontCamera: _usingFrontCamera,
          clearError: true,
        ),
      );
    }
    try {
      await _ensureConnected(session);
      _refreshVerified(session);
      _retryPendingInbound();
      await _syncLocalPublications(session);
      await _syncRemoteSubscriptions();
      _distributeOwnKeyToPeers(reason: RoomCallKeyReason.join);
      _rebuildBindings();
      _refreshState();
    } catch (e) {
      callLog(
        'RoomE2ee',
        'runtime sync failed roomId=${session.roomId} '
            'callId=${session.callId}: $e',
      );
      _setStatusMessage(e.toString(), fatal: true);
      _refreshState();
    }
  }

  void _fail(String code) {
    _errorCode = code;
    callLog('RoomE2ee', 'closed failure: $code');
    unawaited(_teardown());
    _setStatusMessage(code, fatal: true);
    _publishE2eeStatus();
    _refreshState();
  }

  Future<void> _ensureConnected(RelayRoomCallMediaSession session) async {
    final backend = session.backend;
    final url = backend.url?.trim() ?? '';
    final token = backend.accessToken?.trim() ?? '';
    final roomName = backend.roomName?.trim() ?? '';
    if (url.isEmpty || token.isEmpty || roomName.isEmpty) {
      throw StateError('room media session authority unavailable');
    }
    final runtimeKey = [
      session.roomId.trim(),
      session.callId.trim(),
      url,
      roomName,
      _selfIdentity,
    ].join('::');
    final room = _room;
    if (room != null &&
        _runtimeKey == runtimeKey &&
        room.connectionState != lk.ConnectionState.disconnected) {
      return;
    }
    final pending = _connectInFlight;
    if (pending != null) {
      await pending;
      final refreshed = _room;
      if (refreshed != null &&
          _runtimeKey == runtimeKey &&
          refreshed.connectionState != lk.ConnectionState.disconnected) {
        return;
      }
    }
    late final Future<void> future;
    future = _connect(
      session: session,
      url: url,
      token: token,
      runtimeKey: runtimeKey,
    );
    _connectInFlight = future;
    await future.whenComplete(() {
      if (identical(_connectInFlight, future)) _connectInFlight = null;
    });
  }

  Future<void> _connect({
    required RelayRoomCallMediaSession session,
    required String url,
    required String token,
    required String runtimeKey,
  }) async {
    await _disconnectRoom();
    await _ensureKeys(session);

    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        // ЛК-12: при dynacast сервер может включить резервный кодек, и
        // камера ушла бы вторым отправителем мимо шифратора.
        dynacast: false,
        defaultVideoPublishOptions: lk.VideoPublishOptions(
          videoCodec: 'vp8',
          simulcast: true,
          backupVideoCodec: lk.BackupVideoCodec(enabled: false),
        ),
      ),
    );
    room.addListener(_handleRoomChanged);
    final listener = room.createListener()
      ..on<lk.RoomDisconnectedEvent>((_) => _handleRoomChanged())
      ..on<lk.RoomReconnectingEvent>((_) => _onFullRestartBegins())
      ..on<lk.RoomReconnectedEvent>((_) => unawaited(_onFullRestartDone()))
      ..on<lk.ActiveSpeakersChangedEvent>(_onActiveSpeakers)
      ..on<lk.ParticipantConnectedEvent>((e) {
        _book?.onParticipantBack(e.participant.identity);
        _handleRoomChanged();
        unawaited(_syncRemoteSubscriptions());
        _distributeOwnKeyToPeers(reason: RoomCallKeyReason.join);
      })
      ..on<lk.ParticipantDisconnectedEvent>((e) {
        _ownEpochSentTo.remove(e.participant.identity);
        _book?.onParticipantGone(e.participant.identity, explicit: false);
        _handleRoomChanged();
      })
      ..on<lk.TrackPublishedEvent>((_) {
        unawaited(_syncRemoteSubscriptions());
        _handleRoomChanged();
      })
      ..on<lk.TrackSubscribedEvent>(_onTrackSubscribed)
      ..on<lk.TrackUnsubscribedEvent>((e) {
        unawaited(_detachReceiverFor(e.track));
        _handleRoomChanged();
      })
      ..on<lk.TrackUnpublishedEvent>((_) => _handleRoomChanged())
      ..on<lk.TrackMutedEvent>((_) => _handleRoomChanged())
      ..on<lk.TrackUnmutedEvent>((_) => _handleRoomChanged())
      ..on<lk.LocalTrackPublishedEvent>((_) {
        _scheduleSweep();
        _handleRoomChanged();
      })
      ..on<lk.LocalTrackUnpublishedEvent>((e) {
        unawaited(_forgetSenderOf(e.publication.track));
        if (e.publication.source == lk.TrackSource.screenShareVideo) {
          unawaited(_releaseScreenShareLease());
        }
        _handleRoomChanged();
      });

    try {
      await room.prepareConnection(url, token);
    } catch (_) {
      // только ускорение
    }
    await room.connect(
      url,
      token,
      // Подписываемся сами и только на проверенных участников; под цензурой
      // (Э5) — вдобавок только через сервер и только по TLS на 443.
      connectOptions: roomCallConnectOptions(
        plan: await _stealthPlan?.call(),
        autoSubscribe: false,
      ),
    );
    try {
      await room.startAudio();
    } catch (_) {}

    _room = room;
    _listener = listener;
    _runtimeKey = runtimeKey;
    _clearStatusMessage();
    _startKeyFlow();
    _sweepTimer?.cancel();
    _sweepTimer = Timer.periodic(_kSweepEvery, (_) => _scheduleSweep());
    await _applySpeakerRoute(room);
    _rebuildBindings();
    _refreshState();
  }

  /// Провайдер ключей и книга ключей созвона. Свой ключ ставится ДО
  /// подключения: без него ни один свой кадр не зашифровать, и он
  /// выбрасывался бы (`missingKey`).
  Future<void> _ensureKeys(RelayRoomCallMediaSession session) async {
    _keyProvider ??= await rtc.frameCryptorFactory.createDefaultKeyProvider(
      rtc.KeyProviderOptions(
        sharedKey: false,
        ratchetSalt: Uint8List.fromList(utf8.encode(kCallRatchetSalt)),
        // Окно 0: «храповик при ошибке» выключен — иначе мусорные кадры от
        // SFU запускали бы PBKDF2 прямо на медиапотоке.
        ratchetWindowSize: 0,
        // Пусто: кадров «без расшифровки» нет вовсе (ЛК-2).
        uncryptedMagicBytes: null,
        failureTolerance: -1,
        keyRingSize: kCallKeyRingSize,
        // Ставим, но не полагаемся (ЛК-13).
        discardFrameWhenCryptorNotReady: true,
      ),
    );
    final callKey = '${session.roomId}::${session.callId}';
    final existing = _book;
    if (existing != null && _bookCallKey == callKey) {
      // Тот же созвон, новое подключение: свои отправители будут новыми —
      // меняем свой ключ (ЗР-17).
      final rotated = await existing.rotateOwnKey();
      _ownEpochSentTo.clear();
      callLog(
        'RoomE2ee',
        'own key rotated on reconnect epoch=${rotated.epoch}',
      );
      return;
    }
    existing?.dispose();
    final book = CallKeyBook(
      ownIdentity: _selfIdentity,
      sink: _NativeKeySink(this),
      keySwitchDelay: Duration(milliseconds: _keySwitchDelayMs()),
    );
    book.onOwnKeyRotated = (_) {
      _ownEpochSentTo.clear();
      _distributeOwnKeyToPeers(reason: RoomCallKeyReason.rotate);
    };
    _book = book;
    _bookCallKey = callKey;
    _ownEpochSentTo.clear();
    await book.createInitialOwnKey();
  }

  // ── Проверенные участники ───────────────────────────────────────────────

  /// Идентичности участников из снимка реле. Ушедшие по снимку — явный уход:
  /// ротация своего ключа (§4.4).
  void _refreshVerified(RelayRoomCallMediaSession session) {
    final next = <String, _VerifiedPeer>{};
    for (final p in session.participants) {
      if (p.isSelf) continue;
      if (!_inCallState(p.joinState)) continue;
      final pid = p.profileId.trim();
      final did = p.deviceId.trim();
      if (pid.isEmpty || did.isEmpty) continue;
      next[roomMediaParticipantIdentity(pid, did)] = _VerifiedPeer(pid, did);
    }
    for (final gone in _verified.keys.where((k) => !next.containsKey(k))) {
      _ownEpochSentTo.remove(gone);
      _book?.onParticipantGone(gone, explicit: true);
    }
    _verified = next;
  }

  static bool _inCallState(String joinState) {
    final s = joinState.trim();
    return s == 'joined' || s == 'reconnecting' || s == 'joining';
  }

  _VerifiedPeer? _verifiedPeerOf(lk.Participant participant) =>
      _verified[participant.identity];

  // ── Свои публикации ─────────────────────────────────────────────────────

  lk.LocalTrackPublication? _ownPublication(lk.TrackSource source) {
    final local = _room?.localParticipant;
    if (local == null) return null;
    for (final pub in local.trackPublications.values) {
      if (pub.source == source) return pub;
    }
    return null;
  }

  bool _isArmed(lk.LocalTrack track) {
    final sender = track.sender;
    return sender != null && _senderCryptors.containsKey(sender.senderId);
  }

  Future<void> _syncLocalPublications(RelayRoomCallMediaSession session) {
    final next = _publishChain.then((_) => _syncLocalPublicationsNow(session));
    _publishChain = next.catchError((Object _) {});
    return next;
  }

  Future<void> _syncLocalPublicationsNow(
    RelayRoomCallMediaSession session,
  ) async {
    final room = _room;
    final local = room?.localParticipant;
    final self = session.selfParticipant;
    if (room == null || local == null || self == null || _disposed) return;
    String? warning;

    // Микрофон.
    final wantsAudio = self.publishAudio;
    try {
      await _syncSource(
        source: lk.TrackSource.microphone,
        wants: wantsAudio,
        create: () => lk.LocalAudioTrack.create(
          lk.AudioCaptureOptions(deviceId: _selectedAudioInputId),
        ),
        publish: (track) =>
            local.publishAudioTrack(track as lk.LocalAudioTrack),
      );
    } catch (e) {
      callLog('RoomE2ee', 'microphone sync failed: $e');
      if (wantsAudio) warning ??= 'microphone unavailable';
    }

    // Камера.
    final wantsVideo = self.publishVideo && self.supportsVideo;
    try {
      await _syncSource(
        source: lk.TrackSource.camera,
        wants: wantsVideo,
        create: () => lk.LocalVideoTrack.createCameraTrack(
          lk.CameraCaptureOptions(
            deviceId: _selectedVideoInputId,
            cameraPosition: _usingFrontCamera
                ? lk.CameraPosition.front
                : lk.CameraPosition.back,
          ),
        ),
        publish: (track) =>
            local.publishVideoTrack(track as lk.LocalVideoTrack),
      );
    } catch (e) {
      callLog('RoomE2ee', 'camera sync failed: $e');
      if (wantsVideo) warning ??= 'camera unavailable';
    }

    // Экран. Трансляция iOS публикуется внутри LiveKit мимо этого пути —
    // в зашифрованном созвоне её нет (Р-9).
    final wantsScreen = self.publishScreenShare && self.supportsScreenShare;
    final screenPub = _ownPublication(lk.TrackSource.screenShareVideo);
    if (wantsScreen && screenPub == null) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        warning ??= 'screen share unavailable in encrypted call';
      } else if (!await _ensureScreenShareLease()) {
        warning ??= 'screen share permission denied';
      } else {
        try {
          await _syncSource(
            source: lk.TrackSource.screenShareVideo,
            wants: true,
            create: () => lk.LocalVideoTrack.createScreenShareTrack(
              room.roomOptions.defaultScreenShareCaptureOptions,
            ),
            publish: (track) =>
                local.publishVideoTrack(track as lk.LocalVideoTrack),
          );
        } catch (e) {
          callLog('RoomE2ee', 'screen share sync failed: $e');
          warning ??= 'screen share unavailable';
          await _releaseScreenShareLease();
        }
      }
    } else if (!wantsScreen && screenPub != null) {
      try {
        await local.removePublishedTrack(screenPub.sid);
      } catch (e) {
        callLog('RoomE2ee', 'screen share stop failed: $e');
      }
      await _releaseScreenShareLease();
    } else if (!wantsScreen) {
      await _releaseScreenShareLease();
    }

    if (warning == null) {
      _clearStatusMessage();
    } else {
      _setStatusMessage(warning, fatal: false);
    }
  }

  /// Одна своя дорожка: создать → выключить → опубликовать → повесить
  /// шифратор на отправителя → проверить кодек → включить.
  Future<void> _syncSource({
    required lk.TrackSource source,
    required bool wants,
    required Future<lk.LocalTrack> Function() create,
    required Future<lk.LocalTrackPublication> Function(lk.LocalTrack) publish,
  }) async {
    final pub = _ownPublication(source);
    if (!wants) {
      if (pub != null && !pub.muted) await pub.mute();
      return;
    }
    if (pub != null) {
      final track = pub.track;
      if (track != null && !_isArmed(track)) {
        // Отправитель без шифратора: сначала шифратор, потом звук.
        track.mediaStreamTrack.enabled = false;
        await _armSender(track.sender);
      }
      if (track == null || !_isArmed(track)) return;
      if (pub.muted) {
        await pub.unmute();
      } else if (!_restarting &&
          !_disposed &&
          !track.mediaStreamTrack.enabled) {
        // Дорожка осталась выключенной (например, после полного
        // переподключения не все отправители сразу получили шифратор) —
        // теперь шифратор на месте, включаем.
        track.mediaStreamTrack.enabled = true;
      }
      return;
    }
    final track = await create();
    track.mediaStreamTrack.enabled = false;
    final published = await publish(track);
    if (_disposed) return;
    final codec = (published.track?.codec ?? '').toLowerCase();
    if (codec.contains('vp9') || codec.contains('av1')) {
      // ЛК-4: SVC в этих версиях идёт мимо шифратора — снимаем сразу.
      await _room?.localParticipant?.removePublishedTrack(published.sid);
      _errorCode = 'codec_rejected';
      throw StateError('svc codec rejected: $codec');
    }
    // 🔴 СЕРВЕР НЕ ДОЛЖЕН ВКЛЮЧАТЬ DYNACAST (livekit_client 2.13, 13.10.2026).
    //
    // С 2.13 клиент слушается сервера: если в `enabledPublishCodecs` нет VP8,
    // он берёт первый кодек сервера, а для VP9 или AV1 сам включает dynacast
    // на ВСЮ комнату (`local.dart:297-314`) — поверх нашего `dynacast: false`.
    // При включённом dynacast сервер может затребовать резервный кодек, и
    // камера уйдёт вторым отправителем БЕЗ шифратора (ЛК-12, в 2.13 не
    // исправлено). Проверка кодека выше снимает именно эту дорожку, но
    // dynacast остаётся включённым для следующих публикаций. Нашему серверу
    // включать его незачем, значит это либо ошибка настройки, либо
    // враждебный сервер — в обоих случаях зашифрованный созвон продолжать
    // нельзя.
    if (_room?.roomOptions.dynacast ?? false) {
      await _room?.localParticipant?.removePublishedTrack(published.sid);
      _errorCode = 'dynacast_forced';
      throw StateError('server forced dynacast in an encrypted call');
    }
    final armed = await _armSender(track.sender);
    if (!armed) {
      await _room?.localParticipant?.removePublishedTrack(published.sid);
      _errorCode = 'encryption_failed';
      throw StateError('sender cryptor unavailable');
    }
    await _sweepNow();
    if (!_restarting && !_disposed) {
      track.mediaStreamTrack.enabled = true;
    }
  }

  /// Повесить шифратор на своего отправителя. Повторно не вешает.
  Future<bool> _armSender(rtc.RTCRtpSender? sender) async {
    final provider = _keyProvider;
    final book = _book;
    if (sender == null || provider == null || book == null || _disposed) {
      return false;
    }
    final id = sender.senderId;
    if (_senderCryptors.containsKey(id)) return true;
    // Сверка и публикация могут вешать шифратор на один отправитель
    // одновременно — второй ждёт первого, а не вешает второй шифратор.
    final inFlight = _armInFlight[id];
    if (inFlight != null) return inFlight;
    final attempt = _armSenderNow(sender, id, provider, book);
    _armInFlight[id] = attempt;
    try {
      return await attempt;
    } finally {
      _armInFlight.remove(id);
    }
  }

  final Map<String, Future<bool>> _armInFlight = <String, Future<bool>>{};

  Future<bool> _armSenderNow(
    rtc.RTCRtpSender sender,
    String id,
    rtc.KeyProvider provider,
    CallKeyBook book,
  ) async {
    try {
      final cryptor = await rtc.frameCryptorFactory
          .createFrameCryptorForRtpSender(
            participantId: _selfIdentity,
            sender: sender,
            algorithm: rtc.Algorithm.kAesGcm,
            keyProvider: provider,
          );
      // Обработчик — до первого кадра, иначе первое состояние теряется.
      cryptor.onFrameCryptorStateChanged = (_, state) {
        if (state == rtc.FrameCryptorState.FrameCryptorStateEncryptionFailed ||
            state == rtc.FrameCryptorState.FrameCryptorStateInternalError) {
          callLog('RoomE2ee', 'sender cryptor state=$state');
        }
        _publishE2eeStatus();
      };
      await cryptor.setKeyIndex(book.activeOwnIndex);
      await cryptor.setEnabled(true);
      _senderCryptors[id] = cryptor;
      _publishE2eeStatus();
      return true;
    } catch (e) {
      callLog('RoomE2ee', 'sender cryptor attach failed: $e');
      return false;
    }
  }

  Future<void> _forgetSenderOf(lk.Track? track) async {
    final sender = track?.sender;
    if (sender == null) return;
    final cryptor = _senderCryptors.remove(sender.senderId);
    if (cryptor == null) return;
    try {
      await cryptor.dispose();
    } catch (_) {}
    _publishE2eeStatus();
  }

  // ── Сверка: каждый отправитель и получатель под шифратором ─────────────

  void _scheduleSweep() {
    _sweepChain = _sweepChain
        .then((_) => _sweepNow())
        .catchError((Object _) {});
  }

  /// Каждый отправитель соединения публикации получает шифратор, каким бы
  /// путём он ни появился. Каждому получателю проверенного участника —
  /// расшифровщик. Плюс просьбы о ключах для тех, кто молчит.
  Future<void> _sweepNow() async {
    final room = _room;
    if (room == null || _disposed) return;
    try {
      // Внутреннее поле LiveKit — сознательно: сверка идёт по НАСТОЯЩЕМУ
      // списку отправителей соединения, а не по событиям библиотеки, иначе
      // отправитель, созданный мимо событий (резервный кодек, ЛК-12), ушёл
      // бы без шифратора. Версия закреплена (2.4.0).
      // ignore: invalid_use_of_internal_member
      final publisher = room.engine.publisher;
      final senders =
          await publisher?.pc.getSenders() ?? const <rtc.RTCRtpSender>[];
      for (final sender in senders) {
        if (sender.track == null) continue;
        if (!_senderCryptors.containsKey(sender.senderId)) {
          callLog('RoomE2ee', 'sweep: arming unexpected sender');
          await _armSender(sender);
        }
      }
    } catch (e) {
      callLog('RoomE2ee', 'sender sweep failed: $e');
    }
    _requestMissingKeys();
    _publishE2eeStatus();
  }

  // ── Чужие дорожки ───────────────────────────────────────────────────────

  Future<void> _syncRemoteSubscriptions() async {
    final room = _room;
    if (room == null || _disposed) return;
    for (final participant in room.remoteParticipants.values) {
      final verified = _verifiedPeerOf(participant) != null;
      for (final pub in participant.trackPublications.values) {
        try {
          if (verified && !pub.subscribed) {
            await pub.subscribe();
          } else if (!verified && pub.subscribed) {
            await pub.unsubscribe();
          }
        } catch (e) {
          callLog('RoomE2ee', 'subscription sync failed: $e');
        }
      }
    }
  }

  void _onTrackSubscribed(lk.TrackSubscribedEvent event) {
    final track = event.track;
    // Синхронно, до любого await: пока не повешен расшифровщик, ничего не
    // играет (ЛК-16).
    track.mediaStreamTrack.enabled = false;
    final peer = _verifiedPeerOf(event.participant);
    if (peer == null) {
      unawaited(() async {
        try {
          await event.publication.unsubscribe();
        } catch (_) {}
      }());
      _handleRoomChanged();
      return;
    }
    unawaited(_armReceiver(event.participant.identity, peer, track));
  }

  Future<void> _armReceiver(
    String identity,
    _VerifiedPeer peer,
    lk.Track track,
  ) async {
    final provider = _keyProvider;
    final receiver = track.receiver;
    if (provider == null || receiver == null || _disposed) return;
    final id = receiver.receiverId;
    if (_receiverCryptors.containsKey(id)) {
      track.mediaStreamTrack.enabled = true;
      return;
    }
    try {
      final cryptor = await rtc.frameCryptorFactory
          .createFrameCryptorForRtpReceiver(
            participantId: identity,
            receiver: receiver,
            algorithm: rtc.Algorithm.kAesGcm,
            keyProvider: provider,
          );
      final record = _RemoteCryptor(
        cryptor: cryptor,
        identity: identity,
        deviceId: peer.deviceId,
        attachedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      cryptor.onFrameCryptorStateChanged = (_, state) {
        record.state = state;
        if (state == rtc.FrameCryptorState.FrameCryptorStateOk) {
          record.lastOkAtMs = DateTime.now().millisecondsSinceEpoch;
        }
        _publishE2eeStatus();
      };
      await cryptor.setEnabled(true);
      _receiverCryptors[id] = record;
      if (!_disposed) track.mediaStreamTrack.enabled = true;
      _publishE2eeStatus();
      _handleRoomChanged();
    } catch (e) {
      // Расшифровщика нет — дорожка так и остаётся заглушённой.
      callLog('RoomE2ee', 'receiver cryptor attach failed: $e');
    }
  }

  Future<void> _detachReceiverFor(lk.Track track) async {
    final receiver = track.receiver;
    if (receiver == null) return;
    final record = _receiverCryptors.remove(receiver.receiverId);
    if (record == null) return;
    try {
      await record.cryptor.dispose();
    } catch (_) {}
    _publishE2eeStatus();
  }

  // ── Ключи: рассылка, приём, просьбы ─────────────────────────────────────

  void _startKeyFlow() {
    if (_keySub != null) return;
    _keySub = _transport.inbound.listen(
      (c) => unawaited(_onInboundKeyCommand(c)),
    );
    final callId = _session?.callId ?? '';
    for (final c in _transport.drainBuffered(callId: callId)) {
      unawaited(_onInboundKeyCommand(c));
    }
  }

  /// Свой текущий ключ — каждому проверенному участнику, который есть и в
  /// снимке, и в комнате LiveKit, и ещё не получил эту эпоху.
  void _distributeOwnKeyToPeers({required RoomCallKeyReason reason}) {
    final room = _room;
    final book = _book;
    final own = book?.ownKey;
    final session = _session;
    if (room == null || book == null || own == null || session == null) {
      return;
    }
    for (final participant in room.remoteParticipants.values) {
      final peer = _verifiedPeerOf(participant);
      if (peer == null) continue;
      final identity = participant.identity;
      if (_ownEpochSentTo[identity] == own.epoch) continue;
      _ownEpochSentTo[identity] = own.epoch;
      _sendOwnKeyTo(peer, own, reason, session);
    }
  }

  void _sendOwnKeyTo(
    _VerifiedPeer peer,
    OwnCallKey own,
    RoomCallKeyReason reason,
    RelayRoomCallMediaSession session,
  ) {
    final grant = RoomCallKeyGrant(
      roomId: session.roomId.trim(),
      callId: session.callId.trim(),
      identity: _selfIdentity,
      sentAtMs: DateTime.now().millisecondsSinceEpoch,
      epoch: own.epoch,
      keyIndex: own.index,
      key: own.key,
      reason: reason,
    );
    // Отправки по одной: рассылка на 20 устройств не должна упираться в
    // ограничитель реле пачкой.
    _sendChain = _sendChain
        .then((_) async {
          final ok = await _transport.send(
            peerProfileId: peer.profileId,
            peerDeviceId: peer.deviceId,
            command: grant,
          );
          if (!ok) {
            final identity = roomMediaParticipantIdentity(
              peer.profileId,
              peer.deviceId,
            );
            if (_ownEpochSentTo[identity] == own.epoch) {
              _ownEpochSentTo.remove(identity);
            }
          }
        })
        .catchError((Object _) {});
  }

  /// Ключи, пришедшие раньше, чем их отправитель появился в снимке созвона
  /// (снимок реле догоняет LiveKit с задержкой). Ждут не дольше 10 с и
  /// перепроверяются при каждом обновлении снимка.
  final List<InboundRoomCallKeyCommand> _pendingInbound =
      <InboundRoomCallKeyCommand>[];

  void _retryPendingInbound() {
    if (_pendingInbound.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final pending = List<InboundRoomCallKeyCommand>.of(_pendingInbound);
    _pendingInbound.clear();
    for (final p in pending) {
      if (now - p.receivedAtMs > _kFailingAfter.inMilliseconds) continue;
      unawaited(_onInboundKeyCommand(p, retry: true));
    }
  }

  Future<void> _onInboundKeyCommand(
    InboundRoomCallKeyCommand inbound, {
    bool retry = false,
  }) async {
    final session = _session;
    final book = _book;
    if (session == null || book == null || _disposed) return;
    final command = inbound.command;
    if (command.callId != session.callId.trim()) return;
    final senderPid = inbound.senderProfileId.trim();
    final senderDid = inbound.senderDeviceId.trim();
    final senderIdentity = roomMediaParticipantIdentity(senderPid, senderDid);
    final inCall = _verified.containsKey(senderIdentity);
    RoomCallKeyPeerFacts facts;
    try {
      facts = await _transport.peerFacts(
        roomId: session.roomId,
        profileId: senderPid,
        deviceId: senderDid,
      );
    } catch (_) {
      facts = const RoomCallKeyPeerFacts(
        deviceBelongsToProfile: false,
        activeRoomMember: false,
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final input = RoomCallKeyCheckInput(
      pairwiseSenderDeviceId: senderDid,
      senderProfileId: senderPid,
      senderDeviceBelongsToProfile: facts.deviceBelongsToProfile,
      senderIsActiveRoomMember: facts.activeRoomMember,
      senderDeviceInCallSnapshot: inCall,
      activeRoomId: session.roomId,
      activeCallId: session.callId,
      activeCallIsE2ee: isE2eeRoomMediaContract(session.contractVersion),
      lastEpochFromSender: book.lastEpochFrom(senderIdentity),
      lastKeyFromSender: book.lastKeyFrom(senderIdentity),
      grantsFromSenderLastMinute: book.grantsFromLastMinute(senderIdentity),
      nowMs: now,
    );
    switch (command) {
      case RoomCallKeyGrant grant:
        final verdict = checkRoomCallKeyGrant(grant, input);
        if (verdict == RoomCallKeyVerdict.accept) {
          book.acceptRemoteKey(grant);
          _publishE2eeStatus();
        } else if (verdict == RoomCallKeyVerdict.rejectNotInCall && !retry) {
          // Отправителя ещё нет в снимке — подождём его до 10 с.
          _pendingInbound.add(inbound);
          while (_pendingInbound.length > 64) {
            _pendingInbound.removeAt(0);
          }
        } else if (verdict != RoomCallKeyVerdict.duplicate) {
          callLog('RoomE2ee', 'key rejected: ${verdict.name}');
        }
      case RoomCallKeyRequest request:
        final verdict = checkRoomCallKeyRequest(
          request,
          input,
          selfIdentity: _selfIdentity,
        );
        if (verdict != RoomCallKeyVerdict.accept) {
          callLog('RoomE2ee', 'key request rejected: ${verdict.name}');
          return;
        }
        final last = _lastReplyAtMs[senderIdentity] ?? 0;
        if (now - last < _kReplyKeyEvery.inMilliseconds) return;
        _lastReplyAtMs[senderIdentity] = now;
        final own = book.ownKey;
        final peer = _verified[senderIdentity];
        if (own != null && peer != null) {
          _sendOwnKeyTo(peer, own, RoomCallKeyReason.reply, session);
        }
    }
  }

  /// Дорожка молчит дольше 3 с без расшифровки — просим ключ у её хозяина.
  void _requestMissingKeys() {
    final session = _session;
    if (session == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final silentIdentities = <String>{};
    for (final r in _receiverCryptors.values) {
      final quietFor = now - (r.lastOkAtMs > 0 ? r.lastOkAtMs : r.attachedAtMs);
      final decrypting = r.state == rtc.FrameCryptorState.FrameCryptorStateOk;
      if (!decrypting && quietFor >= _kRequestKeyAfter.inMilliseconds) {
        silentIdentities.add(r.identity);
      }
    }
    for (final identity in silentIdentities) {
      final peer = _verified[identity];
      if (peer == null) continue;
      final last = _lastRequestAtMs[identity] ?? 0;
      if (now - last < _kRequestKeyEvery.inMilliseconds) continue;
      _lastRequestAtMs[identity] = now;
      final request = RoomCallKeyRequest(
        roomId: session.roomId.trim(),
        callId: session.callId.trim(),
        identity: _selfIdentity,
        sentAtMs: now,
        want: identity,
      );
      _sendChain = _sendChain
          .then(
            (_) => _transport.send(
              peerProfileId: peer.profileId,
              peerDeviceId: peer.deviceId,
              command: request,
            ),
          )
          .catchError((Object _) => false);
    }
  }

  // ── Полное переподключение ──────────────────────────────────────────────

  /// LiveKit начинает полное переподключение и затем заново опубликует те же
  /// дорожки на НОВЫХ отправителях. До сверки отправителей свои дорожки
  /// выключены: новый отправитель без шифратора несёт только тишину и
  /// чёрный кадр.
  void _onFullRestartBegins() {
    _restarting = true;
    final local = _room?.localParticipant;
    if (local != null) {
      for (final pub in local.trackPublications.values) {
        pub.track?.mediaStreamTrack.enabled = false;
      }
    }
    _handleRoomChanged();
  }

  Future<void> _onFullRestartDone() async {
    await _sweepNow();
    final local = _room?.localParticipant;
    var allArmed = true;
    if (local != null) {
      for (final pub in local.trackPublications.values) {
        final track = pub.track;
        if (track != null && !_isArmed(track)) allArmed = false;
      }
    }
    // Новые отправители — новый свой ключ (ЗР-17).
    final book = _book;
    if (book != null) {
      await book.rotateOwnKey();
      _ownEpochSentTo.clear();
      _distributeOwnKeyToPeers(reason: RoomCallKeyReason.rotate);
    }
    _restarting = false;
    if (allArmed && local != null && !_disposed) {
      for (final pub in local.trackPublications.values) {
        if (!pub.muted) pub.track?.mediaStreamTrack.enabled = true;
      }
    } else {
      callLog('RoomE2ee', 'restart: not all senders armed, media stays off');
    }
    unawaited(_syncRemoteSubscriptions());
    _handleRoomChanged();
  }

  // ── Состояние для интерфейса ────────────────────────────────────────────

  void _publishE2eeStatus() {
    if (_disposed) return;
    final code = _errorCode;
    if (code != null) {
      _e2ee.value = RoomCallE2eeStatus(
        own: RoomCallE2eeOwnState.failed,
        errorCode: code,
      );
      return;
    }
    final room = _room;
    final local = room?.localParticipant;
    var ownState = RoomCallE2eeOwnState.connecting;
    if (room != null &&
        local != null &&
        room.connectionState == lk.ConnectionState.connected &&
        _book?.ownKey != null) {
      var allArmed = true;
      for (final pub in local.trackPublications.values) {
        final track = pub.track;
        if (track != null && !_isArmed(track)) allArmed = false;
      }
      if (allArmed && !_restarting) ownState = RoomCallE2eeOwnState.encrypting;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final peers = <String, RoomCallE2eePeerState>{};
    for (final peer in _verified.values) {
      final records = _receiverCryptors.values.where(
        (r) => r.deviceId == peer.deviceId,
      );
      if (records.isEmpty) {
        peers[peer.deviceId] = RoomCallE2eePeerState.waitingKey;
        continue;
      }
      final decrypting = records.any(
        (r) => r.state == rtc.FrameCryptorState.FrameCryptorStateOk,
      );
      if (decrypting) {
        peers[peer.deviceId] = RoomCallE2eePeerState.decrypting;
        continue;
      }
      final since = records
          .map((r) => r.lastOkAtMs > 0 ? r.lastOkAtMs : r.attachedAtMs)
          .reduce((a, b) => a < b ? a : b);
      peers[peer.deviceId] = now - since >= _kFailingAfter.inMilliseconds
          ? RoomCallE2eePeerState.failing
          : RoomCallE2eePeerState.waitingKey;
    }
    // «Неизвестный» — только если идентичность не сошлась со снимком дольше
    // 10 с: новичок появляется в LiveKit раньше, чем в снимке реле, и не
    // должен на миг пугать остальных.
    var unknown = 0;
    final present = <String>{};
    if (room != null) {
      for (final p in room.remoteParticipants.values) {
        if (_verifiedPeerOf(p) != null) {
          _unverifiedSinceMs.remove(p.identity);
          continue;
        }
        present.add(p.identity);
        final since = _unverifiedSinceMs.putIfAbsent(p.identity, () => now);
        if (now - since >= _kFailingAfter.inMilliseconds) unknown += 1;
      }
    }
    _unverifiedSinceMs.removeWhere(
      (identity, _) => !present.contains(identity),
    );
    _e2ee.value = RoomCallE2eeStatus(
      own: ownState,
      peersByDeviceId: peers,
      unknownParticipants: unknown,
    );
  }

  void _onActiveSpeakers(lk.ActiveSpeakersChangedEvent event) {
    if (_disposed) return;
    final session = _session;
    final next = <String>{};
    for (final speaker in event.speakers) {
      if (speaker is lk.LocalParticipant) {
        final self = session?.selfDeviceId.trim() ?? '';
        if (self.isNotEmpty) next.add(self);
        continue;
      }
      final peer = _verified[speaker.identity];
      if (peer != null) next.add(peer.deviceId);
    }
    if (setEquals(next, _speakingDeviceIds)) return;
    _speakingDeviceIds = next;
    _speakingRevision += 1;
    _refreshState();
  }

  void _handleRoomChanged() {
    if (_disposed) return;
    _rebuildBindings();
    _publishE2eeStatus();
    _refreshState();
  }

  void _rebuildBindings() {
    final room = _room;
    final session = _session;
    if (room == null || session == null) {
      if (_bindings.isNotEmpty || _bindingsSignature.isNotEmpty) {
        _bindings = const <String, _E2eeBinding>{};
        _bindingsSignature = '';
        _runtimeRevision += 1;
      }
      return;
    }
    final next = <String, _E2eeBinding>{};
    final participants = <String, lk.Participant>{};
    final local = room.localParticipant;
    if (local != null) {
      lk.VideoTrack? camera;
      lk.VideoTrack? screen;
      for (final pub in local.videoTrackPublications) {
        final track = pub.track;
        if (track is! lk.VideoTrack || pub.muted) continue;
        if (pub.isScreenShare) {
          screen ??= track;
        } else {
          camera ??= track;
        }
      }
      final selfDevice = session.selfDeviceId.trim();
      next[selfDevice] = _E2eeBinding(
        cameraTrack: camera,
        screenShareTrack: screen,
      );
      participants[selfDevice] = local;
    }
    for (final participant in room.remoteParticipants.values) {
      final peer = _verifiedPeerOf(participant);
      if (peer == null) continue;
      lk.VideoTrack? camera;
      lk.VideoTrack? screen;
      for (final pub in participant.videoTrackPublications) {
        final track = pub.track;
        if (track is! lk.VideoTrack || pub.muted || !pub.subscribed) continue;
        final receiver = (track as lk.Track).receiver;
        // Видно только то, что прошло через наш расшифровщик.
        if (receiver == null ||
            !_receiverCryptors.containsKey(receiver.receiverId)) {
          continue;
        }
        if (pub.isScreenShare) {
          screen ??= track;
        } else {
          camera ??= track;
        }
      }
      next[peer.deviceId] = _E2eeBinding(
        cameraTrack: camera,
        screenShareTrack: screen,
      );
      participants[peer.deviceId] = participant;
    }
    _participantsByDeviceId = participants;
    final entries = next.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final signature = entries
        .map((e) => '${e.key}=${e.value.signature}')
        .join(';');
    _bindings = next;
    if (signature != _bindingsSignature) {
      _bindingsSignature = signature;
      _runtimeRevision += 1;
    }
  }

  void _refreshState() {
    final session = _session;
    if (_disposed || session == null) return;
    final self = session.selfParticipant;
    if (self == null || !self.isJoined) return;
    final room = _room;
    final local = room?.localParticipant;
    final micPub = _ownPublication(lk.TrackSource.microphone);
    final micTrack = micPub?.track;
    final audioCaptureActive =
        micPub != null &&
        !micPub.muted &&
        micTrack != null &&
        _isArmed(micTrack) &&
        micTrack.mediaStreamTrack.enabled;
    final localBinding = _bindings[session.selfDeviceId.trim()];
    final videoCaptureActive = localBinding?.cameraTrack != null;
    final screenShareActive = localBinding?.screenShareTrack != null;
    final phase = _statusMessageIsFatal
        ? RoomCallLocalMediaPhase.failed
        : switch (room?.connectionState) {
            lk.ConnectionState.connected => RoomCallLocalMediaPhase.ready,
            lk.ConnectionState.reconnecting => RoomCallLocalMediaPhase.ready,
            _ => RoomCallLocalMediaPhase.acquiring,
          };
    _setState(
      RoomCallLocalMediaState(
        phase: local == null && !_statusMessageIsFatal
            ? RoomCallLocalMediaPhase.acquiring
            : phase,
        audioCaptureActive: audioCaptureActive,
        videoCaptureActive: videoCaptureActive,
        screenShareActive: screenShareActive,
        localPreviewAvailable: videoCaptureActive || screenShareActive,
        speakerEnabled: _speakerEnabled,
        usingFrontCamera: _usingFrontCamera,
        runtimeConnected: room?.connectionState == lk.ConnectionState.connected,
        runtimeReconnecting:
            room?.connectionState == lk.ConnectionState.reconnecting ||
            _restarting,
        runtimeRevision: _runtimeRevision,
        speakingRevision: _speakingRevision,
        errorMessage: _statusMessage,
      ),
    );
  }

  void _setState(RoomCallLocalMediaState next) {
    if (_disposed) return;
    _state.value = next;
  }

  void _setStatusMessage(String? message, {required bool fatal}) {
    final normalized = (message ?? '').trim();
    _statusMessage = normalized.isEmpty ? null : normalized;
    _statusMessageIsFatal = _statusMessage != null && fatal;
  }

  void _clearStatusMessage() {
    if (_errorCode != null) return;
    _statusMessage = null;
    _statusMessageIsFatal = false;
  }

  Future<void> _applySpeakerRoute(lk.Room room) async {
    try {
      // livekit_client 2.13: `room.setSpeakerOn` устарел и сам лишь
      // пересылает сюда с force: false — поведение то же.
      await lk.AudioManager.instance.setSpeakerOutputPreferred(_speakerEnabled);
      return;
    } catch (_) {}
    try {
      final dynamic helper = rtc.Helper;
      await helper.setSpeakerphoneOn(_speakerEnabled);
    } catch (_) {}
  }

  Future<bool> _ensureScreenShareLease() async {
    if (_screenShareLease != null) return true;
    final lease = await ScreenShareRuntime.acquire();
    if (lease == null) return false;
    _screenShareLease = lease;
    return true;
  }

  Future<void> _releaseScreenShareLease() async {
    final lease = _screenShareLease;
    _screenShareLease = null;
    if (lease != null) await lease.release();
  }

  // ── Выход ───────────────────────────────────────────────────────────────

  Future<void> _disconnectRoom() async {
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;
    _runtimeKey = '';
    _sweepTimer?.cancel();
    _sweepTimer = null;
    if (_speakingDeviceIds.isNotEmpty) {
      _speakingDeviceIds = const <String>{};
      _speakingRevision += 1;
    }
    listener?.dispose();
    // Шифраторы — до соединения: на Windows обратный порядок роняет
    // приложение (нет проверки на null, `flutter_frame_cryptor.cc`).
    final senders = _senderCryptors.values.toList();
    final receivers = _receiverCryptors.values.toList();
    _senderCryptors.clear();
    _receiverCryptors.clear();
    for (final c in senders) {
      try {
        await c.setEnabled(false);
      } catch (_) {}
    }
    if (room != null) {
      room.removeListener(_handleRoomChanged);
      try {
        await room.disconnect();
      } catch (_) {}
      try {
        await room.dispose();
      } catch (_) {}
    }
    for (final c in senders) {
      try {
        await c.dispose();
      } catch (_) {}
    }
    for (final r in receivers) {
      try {
        await r.cryptor.dispose();
      } catch (_) {}
    }
    await _releaseScreenShareLease();
  }

  /// Конец созвона для этого устройства: соединение, шифраторы, ключи.
  /// Провайдер — после комнаты (ЛК-17).
  Future<void> _teardown() async {
    await _keySub?.cancel();
    _keySub = null;
    await _disconnectRoom();
    _book?.dispose();
    _book = null;
    _bookCallKey = '';
    _ownEpochSentTo.clear();
    _lastRequestAtMs.clear();
    _lastReplyAtMs.clear();
    _pendingInbound.clear();
    final provider = _keyProvider;
    _keyProvider = null;
    if (provider != null) {
      try {
        await provider.dispose();
      } catch (_) {}
    }
    _verified = const <String, _VerifiedPeer>{};
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await _teardown();
    _disposed = true;
    _state.dispose();
    _e2ee.dispose();
  }

  /// Для [_NativeKeySink].
  Future<void> _setNativeKey(String participantId, int index, Uint8List key) {
    final provider = _keyProvider;
    if (provider == null) return Future<void>.value();
    return provider.setKey(
      participantId: participantId,
      index: index,
      key: key,
    );
  }

  Future<void> _setOwnEncryptionIndex(int index) async {
    for (final c in _senderCryptors.values.toList()) {
      try {
        await c.setKeyIndex(index);
      } catch (_) {}
    }
  }
}

/// Ключи книги — прямо в нативный провайдер, без записи в журнал.
class _NativeKeySink implements CallKeySink {
  _NativeKeySink(this._owner);

  final E2eeLiveKitRoomCallMediaController _owner;

  @override
  Future<void> setKey(String participantId, int index, Uint8List key) =>
      _owner._setNativeKey(participantId, index, key);

  @override
  Future<void> setOwnEncryptionIndex(int index) =>
      _owner._setOwnEncryptionIndex(index);
}

/// Зашифрованный созвон, когда шифровать нечем (нет транспорта ключей):
/// закрытый отказ, а не открытое медиа.
class UnavailableE2eeRoomCallMediaController
    implements RoomCallMediaController, RoomCallE2eeStatusSource {
  UnavailableE2eeRoomCallMediaController(String code)
    : _status = ValueNotifier<RoomCallE2eeStatus?>(
        RoomCallE2eeStatus(own: RoomCallE2eeOwnState.failed, errorCode: code),
      ),
      _state = ValueNotifier<RoomCallLocalMediaState>(
        const RoomCallLocalMediaState.idle().copyWith(
          phase: RoomCallLocalMediaPhase.failed,
          errorMessage: code,
        ),
      );

  final ValueNotifier<RoomCallE2eeStatus?> _status;
  final ValueNotifier<RoomCallLocalMediaState> _state;

  @override
  ValueListenable<RoomCallE2eeStatus?> get e2eeStatus => _status;

  @override
  ValueListenable<RoomCallLocalMediaState> get state => _state;

  @override
  rtc.RTCVideoRenderer? get localRenderer => null;

  @override
  bool hasParticipantCameraView(String deviceId) => false;

  @override
  bool hasParticipantScreenShareView(String deviceId) => false;

  @override
  bool isParticipantSpeaking(String deviceId) => false;

  @override
  Widget? buildParticipantVideoView({
    required String deviceId,
    bool mirror = false,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) => null;

  @override
  Future<void> syncSession({
    required RelayRoomCallMediaSession session,
  }) async {}

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {}

  @override
  Future<void> switchCamera() async {}

  @override
  Future<List<RoomCallVideoDevice>> videoInputs() async =>
      const <RoomCallVideoDevice>[];

  @override
  Future<List<RoomCallVideoDevice>> audioInputs() async =>
      const <RoomCallVideoDevice>[];

  @override
  String? get selectedAudioInputId => null;

  @override
  Future<void> selectAudioInput(String deviceId) async {}

  @override
  String? get selectedVideoInputId => null;

  @override
  Future<void> selectVideoInput(String deviceId) async {}

  @override
  Future<RoomCallVideoStats?> videoStats({
    required String deviceId,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) async => null;

  @override
  double participantAudioLevel(String deviceId) => 0;

  @override
  Future<void> dispose() async {
    _status.dispose();
    _state.dispose();
  }
}
