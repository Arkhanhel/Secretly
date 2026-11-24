// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../calls/call_audio_route.dart';
import '../calls/call_manager.dart';
import '../calls/call_state.dart';
import '../calls/webrtc_call_session.dart';
import '../l10n/app_localizations.dart';
import 'android_picture_in_picture.dart';
import 'call/call_parts.dart';
import 'call_error_text.dart';
import 'l10n.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/system_bottom_fade.dart';

/// Экран звонка один на один (макет «Calls», 4b, 21.11.2026).
///
/// Один экран и одна панель на голосовой и видео: Микрофон, Звук, Камера,
/// Ещё, Завершить. Камера в голосовом сразу включает видео — отдельной
/// плашки нет. Выключенное — белая кнопка с тёмным знаком.
///
/// * «Звук»: нажатие переключает громкую; подключены наушники/Bluetooth —
///   открывается список устройств с галочкой (долгое нажатие — всегда список).
/// * «Ещё» раскрывает панель вверх: показ экрана, поворот камеры, ключ звонка.
/// * Окно своей камеры тянется и прилипает к ближайшему углу, отступая от
///   шапки и панели; к краю — прячется в язычок; двойное касание меняет
///   местами. Через 4 секунды без касаний кнопки уходят, окно занимает угол.
/// * Живой фон, кольцо вокруг портрета, когда собеседник говорит; таймер —
///   спокойным белым (не зелёным).
/// * Замок в шапке — ключ звонка: четыре знака, одинаковые у обоих.
/// * Входящий: «Отклонить» и «Принять» по краям, нажатием или смахиванием.
class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key, required this.callManager});

  final CallManager callManager;

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

enum _PipCorner { topLeft, topRight, bottomLeft, bottomRight }

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const double _pipW = 104;
  static const double _pipH = 148;
  static const Duration _autoHide = Duration(seconds: 4);

  Timer? _durationTimer;
  String _durationText = '00:00';

  // Панель и шапка: в видеозвонке уходят через 4 секунды без касаний.
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _moreOpen = false;
  bool _routeOpen = false;
  bool _keyOpen = false;

  // Окно своей камеры.
  _PipCorner _corner = _PipCorner.topRight;
  bool? _pipHiddenLeft;
  Offset? _pipDrag;
  Offset _pipDragStart = Offset.zero;
  Offset _pipFingerStart = Offset.zero;
  bool _swapped = false;

  // Громкость собеседника — кольцо «говорит».
  final ValueNotifier<double> _remoteLevel = ValueNotifier(0);
  Timer? _levelTimer;
  bool _levelBusy = false;

  // Ключ звонка.
  Future<List<String>?>? _keyFuture;

  bool? _lastAndroidPipEnabled;

  // Пока сессии нет — пустые источники (не создавать их в build).
  static final ValueNotifier<RemoteVideoLifecycle> _noVideo = ValueNotifier(
    const RemoteVideoLifecycle.notExpected(),
  );
  static final ValueNotifier<CallQualityMetrics> _noQuality = ValueNotifier(
    const CallQualityMetrics.empty(),
  );

  CallManager get _cm => widget.callManager;

  @override
  void initState() {
    super.initState();
    _cm.state.addListener(_onStateChange);
    _startDurationTimer();
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
    _syncNativePictureInPicture();
    _syncLevelSampling();
    _armAutoHide();
  }

  void _onStateChange() {
    final s = _cm.state.value;
    if (s.phase == CallPhase.ended || s.phase == CallPhase.idle) {
      _routeOpen = false;
      _moreOpen = false;
      // Лист ключа звонка тоже закрывается с концом звонка (разбор
      // 22.11.2026).
      _keyOpen = false;
      // Длительность на экране «завершён» больше не растёт.
      _durationTimer?.cancel();
    }
    _syncNativePictureInPicture();
    _syncLevelSampling();
    _armAutoHide();
    if (mounted) setState(() {});
  }

  void _syncNativePictureInPicture() {
    final state = _cm.state.value;
    final enabled = state.isActive && state.isVideo;
    if (_lastAndroidPipEnabled == enabled) return;
    _lastAndroidPipEnabled = enabled;
    unawaited(
      NativePictureInPicture.setAutoEnterEnabled(
        enabled: enabled,
        peerName: state.peerName,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.callManager.onAppResumedDuringCall());
      return;
    }
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused) {
      return;
    }
    final callState = widget.callManager.state.value;
    if (!callState.isActive || !callState.isVideo) return;
    // 🔴 13.11.2026: просить окно отсюда — ТОЛЬКО на iPhone. Android входит в
    // окно сам (Android 12+ — `setAutoEnterEnabled`, старее — по жесту
    // «домой» в `onUserLeaveHint`). А `inactive` Android даёт и при
    // РАЗВОРАЧИВАНИИ окна нажатием: просьба срабатывала снова, звонок
    // сворачивался обратно — экран дёргался и перестраивался, самопросмотр
    // пропадал (проверка 13.11, Android + iPhone).
    if (Platform.isIOS) {
      unawaited(NativePictureInPicture.enter());
    }
    if (state == AppLifecycleState.paused) {
      unawaited(widget.callManager.onAppBackgroundedDuringCall());
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _tickDuration(initial: true);
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickDuration(),
    );
  }

  /// Длительность: считается сразу (без «00:00» в первом кадре) и замирает,
  /// когда звонок завершён.
  void _tickDuration({bool initial = false}) {
    if (!mounted) return;
    final s = _cm.state.value;
    final ms = s.connectedAtMs;
    if (ms == null) return;
    if (s.phase == CallPhase.ended && !initial && _durationText != '00:00') {
      return;
    }
    final total = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
    final text = _fmt(total);
    if (text == _durationText) return;
    if (initial) {
      _durationText = text;
    } else {
      setState(() => _durationText = text);
    }
  }

  static String _fmt(int totalSec) {
    final h = totalSec ~/ 3600;
    final m = (totalSec ~/ 60) % 60;
    final s = totalSec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// Кольцо «говорит» — только в голосовом соединённом звонке (в видео лицо
  /// и так видно). Чтение статистики раз в 300 мс, плавно.
  void _syncLevelSampling() {
    final s = _cm.state.value;
    final want =
        !s.isVideo &&
        (s.phase == CallPhase.connected || s.phase == CallPhase.reconnecting);
    if (want && _levelTimer == null) {
      _levelTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        unawaited(_sampleLevel());
      });
    } else if (!want && _levelTimer != null) {
      _levelTimer?.cancel();
      _levelTimer = null;
      _remoteLevel.value = 0;
    }
  }

  Future<void> _sampleLevel() async {
    if (_levelBusy) return;
    // В фоне кольцо «говорит» никто не видит — статистику не опрашиваем
    // (разбор 22.11.2026).
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) return;
    final session = _cm.session;
    if (session == null) return;
    _levelBusy = true;
    try {
      final raw = await session.sampleRemoteAudioLevel() ?? 0;
      if (!mounted) return;
      // Речь в статистике тихая (0,02…0,3) — растягиваем и сглаживаем.
      final target = math.min(1.0, math.sqrt(raw) * 1.6);
      final now = _remoteLevel.value;
      _remoteLevel.value = now + (target - now) * (target > now ? 0.6 : 0.25);
    } finally {
      _levelBusy = false;
    }
  }

  // ── Панель: показ и автоскрытие ─────────────────────────────────────────

  bool get _autoHideAllowed {
    final s = _cm.state.value;
    return s.isVideo &&
        s.phase == CallPhase.connected &&
        !_moreOpen &&
        !_routeOpen &&
        !_keyOpen &&
        _pipDrag == null;
  }

  void _armAutoHide() {
    _hideTimer?.cancel();
    if (!_autoHideAllowed) {
      if (!_controlsVisible && !_cm.state.value.isVideo) {
        _controlsVisible = true;
      }
      return;
    }
    _hideTimer = Timer(_autoHide, () {
      if (!mounted || !_autoHideAllowed) return;
      setState(() => _controlsVisible = false);
    });
  }

  /// Любое касание: кнопки возвращаются, таймер заново.
  void _touch() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _armAutoHide();
  }

  void _onBackgroundTap() {
    final s = _cm.state.value;
    if (_moreOpen || _routeOpen) {
      setState(() {
        _moreOpen = false;
        _routeOpen = false;
      });
      _armAutoHide();
      return;
    }
    if (s.isVideo && s.isActive) {
      setState(() => _controlsVisible = !_controlsVisible);
      if (_controlsVisible) _armAutoHide();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cm.state.removeListener(_onStateChange);
    _durationTimer?.cancel();
    _hideTimer?.cancel();
    _levelTimer?.cancel();
    _remoteLevel.dispose();
    unawaited(NativePictureInPicture.setAutoEnterEnabled(enabled: false));
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  // ── Звук ────────────────────────────────────────────────────────────────

  bool _hasExternalRoute(CallAudioRouteState r) => r.availableRoutes.any(
    (o) =>
        o.kind == CallAudioRouteKind.bluetooth ||
        o.kind == CallAudioRouteKind.wiredHeadset,
  );

  /// 🔴 ОБЫЧНОЕ НАЖАТИЕ ПЕРЕКЛЮЧАЕТ ГРОМКУЮ (12.08.2026), пока нет наушников.
  ///
  /// Раньше при трёх и более маршрутах кнопка лишь разворачивала полоску
  /// выбора, и громкая не менялась — человек жал «громкую», а звук стоял.
  /// По макету 4b список открывается ТОЛЬКО когда подключены наушники или
  /// Bluetooth (тогда «переключить громкую» неоднозначно: куда — в трубку
  /// или в наушники?), и это уже не полоска, а список с галочкой.
  void _onSoundTap(CallAudioRouteState routeState) {
    _touch();
    if (_hasExternalRoute(routeState) && routeState.hasMultipleChoices) {
      HapticFeedback.selectionClick();
      setState(() {
        _routeOpen = !_routeOpen;
        _moreOpen = false;
      });
      _armAutoHide();
      return;
    }
    unawaited(_cm.toggleSpeaker());
  }

  Future<void> _selectAudioRoute(String routeId) async {
    await _cm.selectAudioRoute(routeId);
    if (!mounted) return;
    setState(() => _routeOpen = false);
    _armAutoHide();
  }

  // ── Окно своей камеры ───────────────────────────────────────────────────

  EdgeInsets _pipInsets(BuildContext context, CallState s, {bool? banner}) {
    final pad = MediaQuery.paddingOf(context);
    final showControls = _controlsVisible;
    final top = showControls
        ? pad.top + 64 + ((banner ?? false) ? 42 : 0) + 8
        : pad.top + 12;
    final moreRows = _moreOpen ? (_moreItems(s).length / 3).ceil() : 0;
    final bottom = showControls
        ? pad.bottom + 30 + 104 + (moreRows > 0 ? moreRows * 82 + 22 : 0) + 12
        : pad.bottom + 24;
    return EdgeInsets.fromLTRB(12, top, 12, bottom);
  }

  Offset _cornerPos(Size screen, EdgeInsets ins, _PipCorner c) {
    final left = c == _PipCorner.topLeft || c == _PipCorner.bottomLeft;
    final top = c == _PipCorner.topLeft || c == _PipCorner.topRight;
    return Offset(
      left ? ins.left : screen.width - ins.right - _pipW,
      top ? ins.top : screen.height - ins.bottom - _pipH,
    );
  }

  void _onPipPanStart(DragStartDetails d, Offset current) {
    _hideTimer?.cancel();
    setState(() {
      _pipDragStart = current;
      _pipFingerStart = d.globalPosition;
      _pipDrag = current;
    });
  }

  void _onPipPanUpdate(DragUpdateDetails d) {
    setState(() {
      _pipDrag = _pipDragStart + (d.globalPosition - _pipFingerStart);
    });
  }

  void _onPipPanEnd(DragEndDetails d, Size screen) {
    final g = _pipDrag;
    if (g == null) return;
    final v = d.velocity.pixelsPerSecond;
    // Бросок учитывается: летим туда, куда толкнули.
    final cx = g.dx + _pipW / 2 + v.dx * 0.12;
    final cy = g.dy + _pipH / 2 + v.dy * 0.12;
    bool? hidden;
    if (g.dx < -_pipW * 0.35) hidden = true;
    if (g.dx + _pipW > screen.width + _pipW * 0.35) hidden = false;
    final topHalf = cy < screen.height / 2;
    final leftHalf = hidden ?? (cx < screen.width / 2);
    HapticFeedback.selectionClick();
    setState(() {
      _pipDrag = null;
      _pipHiddenLeft = hidden;
      _corner = topHalf
          ? (leftHalf ? _PipCorner.topLeft : _PipCorner.topRight)
          : (leftHalf ? _PipCorner.bottomLeft : _PipCorner.bottomRight);
    });
    _armAutoHide();
  }

  // ── Ключ звонка ─────────────────────────────────────────────────────────

  Future<List<String>?> _loadKey() async {
    final fps = await _cm.session?.mediaFingerprints();
    if (fps == null) return null;
    final digest = sha256.convert(utf8.encode(fps.join('|'))).bytes;
    return callKeyEmoji(digest);
  }

  void _openKey() {
    _touch();
    HapticFeedback.selectionClick();
    setState(() {
      _keyOpen = true;
      _moreOpen = false;
      _routeOpen = false;
      _keyFuture = _loadKey();
    });
    _hideTimer?.cancel();
  }

  void _closeSheets() {
    setState(() => _keyOpen = false);
    _armAutoHide();
  }

  // ── Сборка ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BottomSystemFadeVisibility(
      enabled: false,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_keyOpen || _moreOpen || _routeOpen) {
            setState(() {
              _keyOpen = false;
              _moreOpen = false;
              _routeOpen = false;
            });
            return;
          }
          _cm.minimizeActiveCallUi();
        },
        child: ValueListenableBuilder<CallState>(
          valueListenable: _cm.state,
          builder: (context, state, _) {
            return ValueListenableBuilder<CallAudioRouteState>(
              valueListenable: _cm.audioRouteState,
              builder: (context, routeState, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: NativePictureInPicture.isInPipMode,
                  // Качество связи живое: сигнал в шапке и плашка меняются
                  // сами, без смены фазы звонка.
                  builder: (context, isInPip, _) =>
                      ValueListenableBuilder<CallQualityMetrics>(
                        valueListenable:
                            _cm.session?.qualityMetrics ?? _noQuality,
                        builder: (context, _, _) => _buildScaffold(
                          context: context,
                          state: state,
                          routeState: routeState,
                          isInPip: isInPip,
                        ),
                      ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _peerTitle(BuildContext context, CallState state) =>
      // 🔴 Пустое имя — не пустая строка на экране (22.08.2026). Имя
      // приходит из контакта или метаданных профиля, и пока резолв не
      // отработал (или собеседник неизвестен), показываем осмысленную
      // подпись. Раньше сюда подставлялся сырой profile_id — владелец
      // видел «3XBC-F5DJ-…» вместо имени.
      state.peerName.trim().isNotEmpty
      ? state.peerName
      : wave1Text(
          context,
          ru: 'Звонок',
          en: 'Call',
          uk: 'Дзвінок',
          es: 'Llamada',
          pt: 'Chamada',
          ptBr: 'Chamada',
          fr: 'Appel',
          de: 'Anruf',
        );

  // 🔴 ЗАГЛУШКА — ОБЩАЯ С ОСТАЛЬНЫМ ПРИЛОЖЕНИЕМ И С КОМПЬЮТЕРОМ (17.09.2026).
  // Ключ цвета — профиль собеседника, буквы — общий счётчик.
  Widget _avatar(BuildContext context, CallState state, double size) {
    Widget letters() => AvatarInitials.fallbackBubble(
      context: context,
      radius: size / 2,
      seed: state.peerProfileId.trim().isNotEmpty
          ? state.peerProfileId.trim()
          : state.peerName,
      displayName: state.peerName,
    );
    final path = state.peerAvatarPath;
    if (path == null || path.isEmpty) return letters();
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => letters(),
    );
  }

  bool _remoteVideoShown(WebRtcCallSession? session) {
    if (session == null) return false;
    if (session.remoteVideoLifecycle.value.isRenderable) return true;
    final stream = session.remoteRenderer.srcObject;
    return stream != null && stream.getVideoTracks().isNotEmpty;
  }

  Widget _buildScaffold({
    required BuildContext context,
    required CallState state,
    required CallAudioRouteState routeState,
    required bool isInPip,
  }) {
    final l10n = context.l10n;
    final session = _cm.session;
    final phase = state.phase;
    final isEnded = phase == CallPhase.ended;
    final incoming =
        phase == CallPhase.ringingIncoming &&
        state.direction == CallDirection.incoming;
    final outgoing =
        phase == CallPhase.ringingOutgoing ||
        (phase == CallPhase.connecting &&
            state.direction == CallDirection.outgoing &&
            state.connectedAtMs == null);
    final videoCall = state.isVideo && session != null && !incoming;
    final quality = session?.qualityMetrics.value.qualityLevel;
    final poor =
        phase == CallPhase.reconnecting || quality == CallQualityLevel.poor;
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);

    // Окно ОС (PiP): только видео собеседника, без надстроек.
    if (isInPip && videoCall) {
      return Scaffold(
        backgroundColor: kCallBg,
        body: _RemoteVideoSurface(session: session, animateAmbient: false),
      );
    }

    final banner = _banner(context, state, poor);
    // Плашка «Слабая связь · переподключаемся» важнее автоскрытия: пока она
    // есть, шапка видна (разбор 22.11.2026).
    final chrome = !videoCall || _controlsVisible || banner != null;
    final insets = _pipInsets(context, state, banner: banner != null);

    return Scaffold(
      backgroundColor: kCallBg,
      body: ValueListenableBuilder<RemoteVideoLifecycle>(
        valueListenable: session?.remoteVideoLifecycle ?? _noVideo,
        builder: (context, _, _) {
          final remoteShown = videoCall && _remoteVideoShown(session);
          // Конец звонка — всегда портрет с причиной («Звонок завершён ·
          // 04:12», «Отклонён»), и у видеозвонка тоже: иначе ~2 с висел
          // застывший кадр без объяснения (разбор 22.11.2026).
          final showIdentity =
              isEnded || !videoCall || (!remoteShown && !_swapped);
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Фон: видео или живое свечение ─────────────────────────
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onBackgroundTap,
                child: videoCall
                    ? (_swapped && !state.isCameraOff
                          ? _FullscreenLocalVideo(
                              session: session,
                              mirror:
                                  state.isFrontCamera &&
                                  !state.isScreenSharing,
                            )
                          : _RemoteVideoSurface(
                              session: session,
                              animateAmbient: !remoteShown,
                              warn: poor,
                            ))
                    : CallAmbientBackground(warn: poor),
              ),
              if (videoCall && remoteShown && !_swapped)
                // Затемнение под шапкой и панелью — белое читается на любом
                // кадре.
                IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: chrome ? 1 : 0,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x66080C11),
                            Color(0x00080C11),
                            Color(0x00080C11),
                            Color(0x8C080C11),
                          ],
                          stops: [0, 0.22, 0.7, 1],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Портрет (голосовой, вызов, камера собеседника выкл.) ──
              if (showIdentity)
                Positioned(
                  top: math.max(pad.top + 120, screen.height * 0.23),
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: _identity(
                      context,
                      state,
                      incoming: incoming,
                      outgoing: outgoing,
                      ended: isEnded,
                      videoCamOff: videoCall && !remoteShown,
                    ),
                  ),
                ),

              // ── Окно своей камеры ──────────────────────────────────────
              if (videoCall && !isEnded) ..._pip(context, state, session, screen, insets),

              // ── Шапка ─────────────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _Chrome(
                  visible: chrome,
                  offset: const Offset(0, -20),
                  child: Padding(
                    padding: EdgeInsets.only(top: pad.top + 10),
                    child: _topBar(context, state, l10n, poor, banner,
                        incoming: incoming),
                  ),
                ),
              ),

              // ── Панель ────────────────────────────────────────────────
              if (!incoming && !isEnded)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: pad.bottom + 30,
                  child: _Chrome(
                    visible: chrome,
                    offset: const Offset(0, 30),
                    child: _dock(context, state, routeState, l10n,
                        outgoing: outgoing),
                  ),
                ),

              // ── Входящий ──────────────────────────────────────────────
              if (incoming)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: pad.bottom + 44,
                  child: _IncomingCallControls(
                    video: state.isVideo,
                    onAccept: () => unawaited(_cm.acceptIncoming()),
                    onDecline: () => unawaited(_cm.declineIncoming()),
                  ),
                ),

              // ── Ключ звонка ───────────────────────────────────────────
              if (_keyOpen) ..._keySheet(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _identity(
    BuildContext context,
    CallState state, {
    required bool incoming,
    required bool outgoing,
    required bool ended,
    required bool videoCamOff,
  }) {
    final l10n = context.l10n;
    final size = incoming || outgoing ? 132.0 : (ended ? 104.0 : 148.0);
    String status;
    if (incoming) {
      status = state.isVideo
          ? wave1Text(
              context,
              ru: 'Входящий видеозвонок',
              en: 'Incoming video call',
              uk: 'Вхідний відеодзвінок',
              es: 'Videollamada entrante',
              pt: 'Videochamada recebida',
              ptBr: 'Chamada de vídeo recebida',
              fr: 'Appel vidéo entrant',
              de: 'Eingehender Videoanruf',
            )
          : wave1Text(
              context,
              ru: 'Входящий звонок',
              en: 'Incoming call',
              uk: 'Вхідний дзвінок',
              es: 'Llamada entrante',
              pt: 'Chamada recebida',
              ptBr: 'Chamada recebida',
              fr: 'Appel entrant',
              de: 'Eingehender Anruf',
            );
    } else if (ended) {
      final reason = _endReasonText(context, state, l10n);
      status = state.connectedAtMs != null
          ? '$reason · $_durationText'
          : reason;
    } else {
      switch (state.phase) {
        case CallPhase.ringingOutgoing:
          status = l10n.callStatusCalling;
        case CallPhase.connecting:
          status = l10n.callStatusConnecting;
        case CallPhase.reconnecting:
          status = '${l10n.callStatusReconnecting} · $_durationText';
        case CallPhase.connected:
          status = videoCamOff
              ? '${wave1Text(context, ru: 'камера выключена', en: 'camera off', uk: 'камера вимкнена', es: 'cámara apagada', pt: 'câmara desligada', ptBr: 'câmera desligada', fr: 'caméra éteinte', de: 'Kamera aus')} · $_durationText'
              : _durationText;
        default:
          status = '';
      }
    }
    final connected = state.phase == CallPhase.connected;
    return CallIdentity(
      name: _peerTitle(context, state),
      avatar: _avatar(context, state, size),
      status: status,
      size: size,
      ringing: incoming || outgoing,
      level: connected && !state.isVideo ? _remoteLevel : null,
    );
  }

  ({String text, IconData icon, Color bg, Color fg, bool spin})? _banner(
    BuildContext context,
    CallState state,
    bool poor,
  ) {
    if (state.phase == CallPhase.reconnecting) {
      return (
        text: wave1Text(
          context,
          ru: 'Слабая связь · переподключаемся',
          en: 'Weak connection · reconnecting',
          uk: 'Слабкий зв’язок · перепідключаємося',
          es: 'Conexión débil · reconectando',
          pt: 'Ligação fraca · a religar',
          ptBr: 'Conexão fraca · reconectando',
          fr: 'Connexion faible · reconnexion',
          de: 'Schwache Verbindung · verbinde neu',
        ),
        icon: CallIcons.spin,
        bg: const Color(0xEBE09A2B),
        fg: const Color(0xFF1B1405),
        spin: true,
      );
    }
    if (poor && state.phase == CallPhase.connected) {
      return (
        text: wave1Text(
          context,
          ru: 'Слабая связь',
          en: 'Weak connection',
          uk: 'Слабкий зв’язок',
          es: 'Conexión débil',
          pt: 'Ligação fraca',
          ptBr: 'Conexão fraca',
          fr: 'Connexion faible',
          de: 'Schwache Verbindung',
        ),
        icon: CallIcons.signalWeak,
        bg: const Color(0xEBE09A2B),
        fg: const Color(0xFF1B1405),
        spin: false,
      );
    }
    if (state.isScreenSharing) {
      return (
        text: wave1Text(
          context,
          ru: 'Идёт показ экрана',
          en: 'Sharing your screen',
          uk: 'Показ екрана',
          es: 'Compartiendo pantalla',
          pt: 'A partilhar o ecrã',
          ptBr: 'Compartilhando a tela',
          fr: 'Partage d’écran en cours',
          de: 'Bildschirm wird geteilt',
        ),
        icon: CallIcons.screen,
        bg: const Color(0xB3141A22),
        fg: Colors.white,
        spin: false,
      );
    }
    return null;
  }

  Widget _topBar(
    BuildContext context,
    CallState state,
    AppLocalizations l10n,
    bool poor,
    ({String text, IconData icon, Color bg, Color fg, bool spin})? banner, {
    required bool incoming,
  }) {
    final videoTitle =
        state.isVideo && state.phase == CallPhase.connected;
    final title = videoTitle
        ? '${_peerTitle(context, state)} · $_durationText'
        : l10n.callEncryptedBadge;
    final showSide = !incoming && state.phase != CallPhase.ended;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: showSide
                    ? CallHeaderButton(
                        icon: CallIcons.minimize,
                        size: 24,
                        label: l10n.callMinimize,
                        onTap: _cm.minimizeActiveCallUi,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: title,
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: state.isActive ? _openKey : null,
                      child: CallGlass(
                        radius: 18,
                        color: const Color(0x73141A22),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: SizedBox(
                          height: 36,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CallIcons.lock,
                                size: 14,
                                color: kCallSafe,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                // Длинные языки — чуть мельче, а не обрезка.
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                  title,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: showSide
                    ? CallHeaderButton(
                        icon: poor ? CallIcons.signalWeak : CallIcons.signal,
                        color: poor ? kCallWarn : kCallSafe,
                        label: poor
                            ? wave1Text(
                                context,
                                ru: 'Слабая связь',
                                en: 'Weak connection',
                              )
                            : wave1Text(
                                context,
                                ru: 'Хорошая связь',
                                en: 'Good connection',
                              ),
                      )
                    : null,
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SizeTransition(sizeFactor: a, child: child),
          ),
          child: banner == null
              ? const SizedBox(key: ValueKey('none'), width: double.infinity)
              : Padding(
                  key: ValueKey(banner.text),
                  padding: const EdgeInsets.only(top: 10),
                  child: CallBanner(
                    text: banner.text,
                    icon: banner.icon,
                    background: banner.bg,
                    foreground: banner.fg,
                    spinning: banner.spin,
                  ),
                ),
        ),
      ],
    );
  }

  List<({IconData icon, String label, bool active, VoidCallback onTap})>
  _moreItems(CallState state) {
    final live =
        state.phase == CallPhase.connected ||
        state.phase == CallPhase.connecting ||
        state.phase == CallPhase.reconnecting;
    final ctx = context;
    final l10n = ctx.l10n;
    return [
      if (state.isVideo && live)
        (
          icon: CallIcons.screen,
          label: state.isScreenSharing
              ? wave1Text(ctx, ru: 'Идёт показ', en: 'Sharing')
              : l10n.callControlShare,
          active: state.isScreenSharing,
          onTap: () => unawaited(_toggleScreenShare()),
        ),
      if (state.isVideo && !state.isCameraOff && !state.isScreenSharing)
        (
          icon: CallIcons.flip,
          label: l10n.callControlFlip,
          active: false,
          onTap: () {
            _touch();
            HapticFeedback.selectionClick();
            unawaited(_cm.switchCamera());
          },
        ),
      (
        icon: CallIcons.key,
        label: wave1Text(
          ctx,
          ru: 'Ключ звонка',
          en: 'Call key',
          uk: 'Ключ дзвінка',
          es: 'Clave',
          pt: 'Chave',
          ptBr: 'Chave',
          fr: 'Clé d’appel',
          de: 'Anrufschlüssel',
        ),
        active: false,
        onTap: _openKey,
      ),
    ];
  }

  Future<void> _toggleScreenShare() async {
    _touch();
    final messenger = ScaffoldMessenger.of(context);
    final denied = wave1Text(
      context,
      ru: 'Нет разрешения на демонстрацию экрана',
      en: 'Screen share permission denied',
      uk: 'Немає дозволу на демонстрацію екрана',
      es: 'Permiso de compartir pantalla denegado',
      pt: 'Permissão de partilha de ecrã negada',
      ptBr: 'Permissão para compartilhar tela negada',
      fr: 'Autorisation de partage d’écran refusée',
      de: 'Berechtigung zur Bildschirmfreigabe verweigert',
    );
    final ok = await _cm.toggleScreenShare();
    if (!ok) {
      messenger.showSnackBar(SecretlySnackBar(content: Text(denied)));
    }
  }

  Widget _dock(
    BuildContext context,
    CallState state,
    CallAudioRouteState routeState,
    AppLocalizations l10n, {
    required bool outgoing,
  }) {
    // До соединения маршрут ещё «трубка», а нажатие «Звук» — желание
    // (исполнится при соединении): показываем желание, иначе нажатие не
    // меняло экран, а второе его отменяло (разбор 22.11.2026).
    final route = (routeState.selectedRoute == null ||
            (state.connectedAtMs == null &&
                routeState.selectedRouteKind != CallAudioRouteKind.bluetooth &&
                routeState.selectedRouteKind !=
                    CallAudioRouteKind.wiredHeadset))
        ? (state.isSpeaker
              ? CallAudioRouteKind.speaker
              : CallAudioRouteKind.earpiece)
        : routeState.selectedRouteKind;
    final routeIcon = _routeIcon(route);
    final routeLabel = switch (route) {
      CallAudioRouteKind.speaker => l10n.callControlSpeaker,
      CallAudioRouteKind.bluetooth =>
        (routeState.selectedRoute?.label.isNotEmpty ?? false)
            ? routeState.selectedRoute!.label
            : 'Bluetooth',
      CallAudioRouteKind.wiredHeadset => wave1Text(
        context,
        ru: 'Наушники',
        en: 'Headset',
      ),
      _ => wave1Text(
        context,
        ru: 'Звук',
        en: 'Audio',
        uk: 'Звук',
        es: 'Audio',
        pt: 'Áudio',
        ptBr: 'Áudio',
        fr: 'Son',
        de: 'Ton',
      ),
    };
    final cameraOn = state.isVideo && !state.isCameraOff;
    final canUpgrade =
        state.phase == CallPhase.connected ||
        state.phase == CallPhase.connecting;
    final more = _moreItems(state);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CallGlass(
          radius: 30,
          blur: 28,
          shadow: true,
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: const Cubic(0.2, 0.9, 0.3, 1),
                alignment: Alignment.bottomCenter,
                child: _moreOpen
                    ? Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 14),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0x14FFFFFF)),
                          ),
                        ),
                        child: _MoreGrid(items: more),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              Row(
                children: [
                  Expanded(
                    child: CallDockButton(
                      icon: state.isMuted ? CallIcons.micOff : CallIcons.mic,
                      label: state.isMuted
                          ? wave1Text(
                              context,
                              ru: 'Без звука',
                              en: 'Muted',
                              uk: 'Без звуку',
                              es: 'Silencio',
                              pt: 'Sem som',
                              ptBr: 'Mudo',
                              fr: 'Muet',
                              de: 'Stumm',
                            )
                          : l10n.callControlMute,
                      inverted: state.isMuted,
                      semanticOn: !state.isMuted,
                      onTap: () {
                        _touch();
                        HapticFeedback.selectionClick();
                        unawaited(_cm.toggleMute());
                      },
                    ),
                  ),
                  Expanded(
                    child: CallDockButton(
                      icon: routeIcon,
                      label: routeLabel,
                      inverted: route != CallAudioRouteKind.earpiece,
                      onTap: () => _onSoundTap(routeState),
                      onLongPress: routeState.hasMultipleChoices
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _routeOpen = !_routeOpen;
                                _moreOpen = false;
                              });
                              _armAutoHide();
                            }
                          : null,
                    ),
                  ),
                  Expanded(
                    child: CallDockButton(
                      icon: cameraOn ? CallIcons.camera : CallIcons.cameraOff,
                      label: l10n.callControlCamera,
                      inverted: !cameraOn,
                      semanticOn: cameraOn,
                      onTap: () {
                        _touch();
                        HapticFeedback.selectionClick();
                        if (!state.isVideo) {
                          // Камера в голосовом сразу включает видео.
                          if (canUpgrade) unawaited(_cm.upgradeToVideo());
                        } else {
                          unawaited(_cm.toggleCamera());
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: CallDockButton(
                      icon: _moreOpen ? CallIcons.close : CallIcons.more,
                      label: wave1Text(
                        context,
                        ru: 'Ещё',
                        en: 'More',
                        uk: 'Ще',
                        es: 'Más',
                        pt: 'Mais',
                        ptBr: 'Mais',
                        fr: 'Plus',
                        de: 'Mehr',
                      ),
                      inverted: _moreOpen,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _moreOpen = !_moreOpen;
                          _routeOpen = false;
                        });
                        _touch();
                      },
                    ),
                  ),
                  Expanded(
                    child: CallDockButton(
                      icon: CallIcons.end,
                      label: outgoing ? l10n.cancel : l10n.callControlEnd,
                      danger: true,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        unawaited(_cm.hangup());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Список устройств — над кнопкой «Звук».
        if (_routeOpen)
          Positioned(
            left: 48,
            bottom: 122,
            width: 236,
            child: RecordPop(
              child: CallGlass(
                radius: 20,
                blur: 24,
                shadow: true,
                color: const Color(0xEB181F28),
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final r in routeState.availableRoutes)
                      CallRouteRow(
                        icon: _routeIcon(r.kind),
                        label: _routeName(context, r, l10n),
                        selected: r.deviceId == routeState.selectedRouteId,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          unawaited(_selectAudioRoute(r.deviceId));
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _pip(
    BuildContext context,
    CallState state,
    WebRtcCallSession session,
    Size screen,
    EdgeInsets insets,
  ) {
    final hidden = _pipHiddenLeft;
    final resting = _cornerPos(screen, insets, _corner);
    final drag = _pipDrag;
    final pos = drag ??
        (hidden == null
            ? resting
            : Offset(hidden ? -_pipW - 16 : screen.width + 16, resting.dy));
    final dragging = drag != null;
    return [
      AnimatedPositioned(
        duration: dragging
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: const Cubic(0.2, 0.9, 0.25, 1.08),
        left: pos.dx,
        top: pos.dy,
        width: _pipW,
        height: _pipH,
        child: GestureDetector(
          onPanStart: (d) => _onPipPanStart(d, pos),
          onPanUpdate: _onPipPanUpdate,
          onPanEnd: (d) => _onPipPanEnd(d, screen),
          onDoubleTap: () {
            HapticFeedback.selectionClick();
            setState(() => _swapped = !_swapped);
            _touch();
          },
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: dragging ? 1.04 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x73000000),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF25303C)),
                    if (_swapped)
                      _RemoteVideoView(session: session)
                    else if (state.isCameraOff)
                      const Center(
                        child: Icon(
                          CallIcons.cameraOff,
                          size: 26,
                          color: Color(0xFF8FA3B7),
                        ),
                      )
                    else
                      _LocalVideoView(
                        session: session,
                        mirror: state.isFrontCamera && !state.isScreenSharing,
                      ),
                    if (state.isMuted && !_swapped)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xA60A0E13),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CallIcons.micOff,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0x24FFFFFF)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Язычок спрятанного окна.
      if (hidden != null && drag == null)
        Positioned(
          left: hidden ? 0 : screen.width - 24,
          top: resting.dy + 38,
          child: RecordPop(
            child: Semantics(
              button: true,
              label: wave1Text(context, ru: 'Показать камеру', en: 'Show camera'),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _pipHiddenLeft = null);
                  _touch();
                },
                child: ClipRRect(
                  borderRadius: hidden
                      ? const BorderRadius.horizontal(
                          right: Radius.circular(14),
                        )
                      : const BorderRadius.horizontal(
                          left: Radius.circular(14),
                        ),
                  child: CallGlass(
                    radius: 0,
                    blur: 16,
                    color: const Color(0xB3141A22),
                    child: SizedBox(
                      width: 24,
                      height: 72,
                      child: Icon(
                        hidden ? CallIcons.chevronRight : CallIcons.chevronLeft,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _keySheet(BuildContext context, CallState state) {
    final name = _peerTitle(context, state);
    return [
      Positioned.fill(
        child: GestureDetector(
          onTap: _closeSheets,
          child: const ColoredBox(color: Color(0x73000000)),
        ),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: RecordPop(
            child: CallGlass(
              radius: 28,
              blur: 30,
              shadow: true,
              color: const Color(0xF5181F28),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
              child: FutureBuilder<List<String>?>(
                future: _keyFuture,
                builder: (context, snap) {
                  final emoji = snap.data;
                  final ready = emoji != null && emoji.length == 4;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CallIcons.key, size: 30, color: kCallSafe),
                      const SizedBox(height: 14),
                      Text(
                        wave1Text(
                          context,
                          ru: 'Ключ этого звонка',
                          en: 'This call’s key',
                          uk: 'Ключ цього дзвінка',
                          es: 'Clave de esta llamada',
                          pt: 'Chave desta chamada',
                          ptBr: 'Chave desta chamada',
                          fr: 'Clé de cet appel',
                          de: 'Schlüssel dieses Anrufs',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (ready)
                        Row(
                          children: [
                            for (final e in emoji)
                              Expanded(
                                child: Container(
                                  height: 56,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0x1A9BE3B0),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    e,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        SizedBox(
                          height: 56,
                          child: Center(
                            child: snap.connectionState ==
                                    ConnectionState.done
                                ? Text(
                                    wave1Text(
                                      context,
                                      ru: 'Ключ появится, когда звонок соединится',
                                      en: 'The key appears once the call connects',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFA9B8C6),
                                      fontSize: 13.5,
                                    ),
                                  )
                                : const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kCallSafe,
                                    ),
                                  ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        wave1Text(
                          context,
                          ru: 'Если у собеседника ($name) на экране те же четыре знака, разговор слышите только вы двое.',
                          en: 'If $name sees the same four symbols, only the two of you can hear this call.',
                          uk: 'Якщо співрозмовник ($name) бачить ті самі чотири знаки, розмову чуєте лише ви двоє.',
                          es: 'Si $name ve los mismos cuatro símbolos, solo vosotros dos oís la llamada.',
                          pt: 'Se $name vir os mesmos quatro símbolos, só vocês os dois ouvem a chamada.',
                          ptBr: 'Se $name vir os mesmos quatro símbolos, só vocês dois ouvem a chamada.',
                          fr: 'Si $name voit les mêmes quatre symboles, vous seuls entendez l’appel.',
                          de: 'Sieht $name dieselben vier Symbole, hört nur ihr beide das Gespräch.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFA9B8C6),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: _closeSheets,
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0x14FFFFFF),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              wave1Text(
                                context,
                                ru: 'Понятно',
                                en: 'Got it',
                                uk: 'Зрозуміло',
                                es: 'Entendido',
                                pt: 'Percebi',
                                ptBr: 'Entendi',
                                fr: 'Compris',
                                de: 'Verstanden',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ];
  }

  String _endReasonText(
    BuildContext context,
    CallState state,
    AppLocalizations l10n,
  ) {
    switch (state.endReason) {
      case CallEndReason.localHangup:
      case CallEndReason.remoteHangup:
        return l10n.callEnded;
      case CallEndReason.remoteSuperseded:
        return l10n.callReplacedByNewerAttempt;
      case CallEndReason.remoteDecline:
        return l10n.callDeclined;
      case CallEndReason.localDecline:
        return l10n.callYouDeclined;
      case CallEndReason.timeout:
        return l10n.callNoAnswer;
      case CallEndReason.error:
        if (state.failure != null) {
          return callErrorText(context.l10n, state.failure!);
        }
        return l10n.callConnectionError;
      case null:
        return l10n.callEnded;
    }
  }
}

IconData _routeIcon(CallAudioRouteKind kind) => switch (kind) {
  CallAudioRouteKind.bluetooth => CallIcons.bluetooth,
  CallAudioRouteKind.wiredHeadset => CallIcons.headphones,
  CallAudioRouteKind.earpiece => CallIcons.earpiece,
  CallAudioRouteKind.speaker => CallIcons.speaker,
  CallAudioRouteKind.unknown => CallIcons.speaker,
};

String _routeName(
  BuildContext context,
  CallAudioRouteOption route,
  AppLocalizations l10n,
) {
  switch (route.kind) {
    case CallAudioRouteKind.bluetooth:
      return route.label.isNotEmpty ? route.label : 'Bluetooth';
    case CallAudioRouteKind.wiredHeadset:
      return wave1Text(context, ru: 'Наушники', en: 'Headset');
    case CallAudioRouteKind.earpiece:
      return Platform.isIOS
          ? 'iPhone'
          : wave1Text(context, ru: 'Телефон', en: 'Phone');
    case CallAudioRouteKind.speaker:
      return l10n.callControlSpeaker;
    case CallAudioRouteKind.unknown:
      return route.label.isNotEmpty
          ? route.label
          : wave1Text(context, ru: 'Аудио', en: 'Audio');
  }
}

/// Шапка и панель: уходят и возвращаются вместе (прозрачность + сдвиг).
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.visible,
    required this.offset,
    required this.child,
  });

  final bool visible;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 350),
          curve: const Cubic(0.2, 0.9, 0.3, 1),
          offset: visible ? Offset.zero : Offset(0, offset.dy / 100),
          child: child,
        ),
      ),
    );
  }
}

class _MoreGrid extends StatelessWidget {
  const _MoreGrid({required this.items});
  final List<({IconData icon, String label, bool active, VoidCallback onTap})>
  items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 3) {
      final slice = items.skip(i).take(3).toList();
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: Row(
            children: [
              for (var j = 0; j < 3; j++) ...[
                if (j > 0) const SizedBox(width: 8),
                Expanded(
                  child: j < slice.length
                      ? CallMoreTile(
                          icon: slice[j].icon,
                          label: slice[j].label,
                          active: slice[j].active,
                          onTap: slice[j].onTap,
                        )
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// Появление пружинкой (листы, язычок).
class RecordPop extends StatelessWidget {
  const RecordPop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Видео
// ═══════════════════════════════════════════════════════════════════════════

class _RemoteVideoView extends StatelessWidget {
  const _RemoteVideoView({required this.session});

  final WebRtcCallSession session;

  @override
  Widget build(BuildContext context) {
    final token =
        'remote:${session.hashCode}:${_videoRendererBindingToken(session.remoteRenderer)}';
    return RTCVideoView(
      key: ValueKey(token),
      session.remoteRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

/// Видео собеседника во весь экран; пока кадров нет — живой фон.
class _RemoteVideoSurface extends StatelessWidget {
  const _RemoteVideoSurface({
    required this.session,
    this.animateAmbient = true,
    this.warn = false,
  });

  final WebRtcCallSession session;
  final bool animateAmbient;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RemoteVideoLifecycle>(
      valueListenable: session.remoteVideoLifecycle,
      builder: (context, lifecycle, _) {
        final stream = session.remoteRenderer.srcObject;
        final mount =
            lifecycle.isRenderable ||
            (stream != null && stream.getVideoTracks().isNotEmpty);
        return Stack(
          fit: StackFit.expand,
          children: [
            CallAmbientBackground(warn: warn, animate: animateAmbient),
            if (mount)
              RTCVideoView(
                key: ValueKey(
                  'remote-video:${session.hashCode}:${lifecycle.state.name}:${_videoRendererBindingToken(session.remoteRenderer)}',
                ),
                session.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
          ],
        );
      },
    );
  }
}

class _LocalVideoView extends StatelessWidget {
  const _LocalVideoView({required this.session, required this.mirror});

  final WebRtcCallSession session;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final token =
        'local:${session.hashCode}:${_videoRendererBindingToken(session.localRenderer)}';
    return RTCVideoView(
      key: ValueKey(token),
      session.localRenderer,
      mirror: mirror,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

class _FullscreenLocalVideo extends StatelessWidget {
  const _FullscreenLocalVideo({required this.session, required this.mirror});

  final WebRtcCallSession session;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final token =
        'local-fs:${session.hashCode}:${_videoRendererBindingToken(session.localRenderer)}';
    return RTCVideoView(
      key: ValueKey(token),
      session.localRenderer,
      mirror: mirror,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

String _videoRendererBindingToken(RTCVideoRenderer renderer) {
  final stream = renderer.srcObject;
  if (stream == null) return 'stream:none';
  try {
    final ids = stream.getVideoTracks().map((t) => t.id).join(',');
    return 'stream:${stream.id}|tracks:${ids.isEmpty ? 'none' : ids}';
  } catch (_) {
    return 'stream:${stream.id}|tracks:error';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Входящий
// ═══════════════════════════════════════════════════════════════════════════

/// Управление входящим звонком: две большие кнопки, разнесённые по краям.
///
/// 🔴 ПОЧЕМУ ОТДЕЛЬНЫЙ УЗЕЛ, А НЕ КНОПКИ ПАНЕЛИ. Для решения «принять или
/// отклонить» кнопки должны быть КРУПНЫМИ и РАЗНЕСЁННЫМИ, чтобы в спешке нельзя
/// было промахнуться и сбросить звонок вместо ответа (12.08 человек именно так
/// и сбрасывал себе вызовы).
class _IncomingCallControls extends StatelessWidget {
  const _IncomingCallControls({
    required this.video,
    required this.onAccept,
    required this.onDecline,
  });

  final bool video;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IncomingActionButton(
            icon: CallIcons.end,
            color: kCallRed,
            label: wave1Text(
              context,
              ru: 'Отклонить',
              en: 'Decline',
              uk: 'Відхилити',
              es: 'Rechazar',
              pt: 'Rejeitar',
              ptBr: 'Recusar',
              fr: 'Refuser',
              de: 'Ablehnen',
            ),
            pulse: false,
            onTrigger: onDecline,
          ),
          _IncomingActionButton(
            icon: video ? CallIcons.camera : CallIcons.accept,
            color: kCallGreen,
            label: wave1Text(
              context,
              ru: 'Принять',
              en: 'Accept',
              uk: 'Прийняти',
              es: 'Aceptar',
              pt: 'Atender',
              ptBr: 'Atender',
              fr: 'Répondre',
              de: 'Annehmen',
            ),
            pulse: true,
            onTrigger: onAccept,
          ),
        ],
      ),
    );
  }
}

/// Одна кнопка входящего звонка: нажатие ИЛИ смахивание вверх.
///
/// 🔴 ОБА ЖЕСТА, А НЕ ТОЛЬКО СМАХИВАНИЕ: нажатие остаётся полноценным путём
/// для людей с трясущимися руками, в перчатках, с крупной моторикой.
class _IncomingActionButton extends StatefulWidget {
  const _IncomingActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.pulse,
    required this.onTrigger,
  });

  final IconData icon;
  final Color color;
  final String label;

  /// Лёгкое «дыхание» у кнопки приёма — она главная.
  final bool pulse;
  final VoidCallback onTrigger;

  @override
  State<_IncomingActionButton> createState() => _IncomingActionButtonState();
}

class _IncomingActionButtonState extends State<_IncomingActionButton>
    with SingleTickerProviderStateMixin {
  static const double _size = 76;

  /// Порог смахивания: меньше — сработало бы от случайного движения у уха.
  static const double _triggerDy = 56;

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  double _dragDy = 0;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _breath.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    HapticFeedback.mediumImpact();
    widget.onTrigger();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragDy.abs() / _triggerDy).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _fire,
        onVerticalDragUpdate: (d) {
          final next = (_dragDy + d.delta.dy).clamp(-_triggerDy * 1.4, 0.0);
          setState(() => _dragDy = next);
        },
        onVerticalDragEnd: (_) {
          if (_dragDy.abs() >= _triggerDy) _fire();
          setState(() => _dragDy = 0);
        },
        onVerticalDragCancel: () => setState(() => _dragDy = 0),
        child: SizedBox(
          width: 88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                opacity: 0.25 + 0.75 * progress,
                duration: const Duration(milliseconds: 120),
                child: Icon(
                  CallIcons.up,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: _breath,
                builder: (context, child) {
                  final breath = widget.pulse
                      ? 1 +
                            0.05 *
                                Curves.easeInOut.transform(_breath.value) *
                                (1 - progress)
                      : 1.0;
                  return Transform.translate(
                    offset: Offset(0, _dragDy * 0.6),
                    child: Transform.scale(scale: breath, child: child),
                  );
                },
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(
                          alpha: 0.38 + 0.3 * progress,
                        ),
                        blurRadius: 30 + 10 * progress,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
