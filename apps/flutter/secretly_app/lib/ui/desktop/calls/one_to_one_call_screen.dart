// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:window_manager/window_manager.dart';

import '../../../calls/call_audio_route.dart';
import '../../../calls/call_manager.dart';
import '../../../calls/call_state.dart';
import '../../../calls/webrtc_call_session.dart';
import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../primitives/context_menu.dart';
import '../primitives/desktop_snackbar.dart';
import '../primitives/hover_listener.dart';
import '../shell/window_chrome.dart';
import 'call_controls.dart';
import 'call_mini_window.dart';
import 'call_peer_label.dart';

/// Сцена созвона — чёрная в любой теме.
const Color _kCallStage = Color(0xFF0A0B0E);

bool get _isMacOS => !kIsWeb && Platform.isMacOS;
bool get _isWindows => !kIsWeb && Platform.isWindows;

/// То, чем окна звонка один на один управляют звонком.
///
/// Отдельно от [CallManager], чтобы каждую кнопку окна можно было проверить
/// без настоящего звонка: тест подставляет свою реализацию и видит, какой
/// вызов ушёл. Приложение отдаёт сюда [CallManagerDesktopCall] — тонкую
/// обёртку, в которой нет ни одного своего шага.
abstract class DesktopDirectCall {
  ValueListenable<CallState> get state;

  /// Медиасессия. `null` — картинки нет (звонок ещё не поднят или тест).
  WebRtcCallSession? get session;

  ValueListenable<CallAudioRouteState> get audioRouteState;

  Future<void> toggleMute();

  Future<void> toggleCamera();

  Future<void> upgradeToVideo();

  /// `false` — показать экран не вышло (нет разрешения или нечем).
  Future<bool> toggleScreenShare();

  Future<void> selectAudioRoute(String routeId);

  Future<void> hangup();
}

/// [DesktopDirectCall] поверх настоящего [CallManager]: вызовы один в один.
class CallManagerDesktopCall implements DesktopDirectCall {
  CallManagerDesktopCall(this.manager);

  final CallManager manager;

  @override
  ValueListenable<CallState> get state => manager.state;

  @override
  WebRtcCallSession? get session => manager.session;

  @override
  ValueListenable<CallAudioRouteState> get audioRouteState =>
      manager.audioRouteState;

  @override
  Future<void> toggleMute() => manager.toggleMute();

  @override
  Future<void> toggleCamera() => manager.toggleCamera();

  @override
  Future<void> upgradeToVideo() => manager.upgradeToVideo();

  @override
  Future<bool> toggleScreenShare() => manager.toggleScreenShare();

  @override
  Future<void> selectAudioRoute(String routeId) =>
      manager.selectAudioRoute(routeId);

  @override
  Future<void> hangup() => manager.hangup();
}

/// Можно ли включить картинку в голосовом звонке сейчас.
///
/// Как на телефоне: только когда разговор уже соединяется или идёт. Пока
/// звоним, пересогласовывать нечего — собеседник ещё не взял трубку.
bool _canUpgrade(CallState s) =>
    s.phase == CallPhase.connected || s.phase == CallPhase.connecting;

/// Показ экрана — только в звонке с картинкой и только когда он поднят.
///
/// 🔴 В ГОЛОСОВОМ ЗВОНКЕ КНОПКА «ЭКРАН» НИЧЕГО НЕ ДЕЛАЛА. Экран подменяет
/// дорожку камеры на лету, без пересогласования; в голосовом звонке
/// подменять нечего, и нажатие молча проваливалось. Телефон показывает эту
/// кнопку по тому же правилу — теперь и компьютер.
bool _canShareScreen(CallState s) =>
    s.isVideo &&
    (s.phase == CallPhase.connected ||
        s.phase == CallPhase.connecting ||
        s.phase == CallPhase.reconnecting);

String _statusLabel(CallState s, AppLocalizations l10n, {int? nowMs}) {
  switch (s.phase) {
    case CallPhase.ringingOutgoing:
      return l10n.desktopCallDialing;
    case CallPhase.connecting:
      return l10n.desktopCallConnecting;
    case CallPhase.reconnecting:
      return l10n.desktopCallReconnecting;
    case CallPhase.connected:
      final started = s.connectedAtMs ?? s.startedAtMs;
      if (started == null) return l10n.desktopCallEncrypted;
      return l10n.desktopCallEncryptedFor(
        desktopCallMiniDuration(started, nowMs: nowMs),
      );
    case CallPhase.ended:
      return l10n.desktopCallEnded;
    case CallPhase.ringingIncoming:
    case CallPhase.idle:
      return l10n.desktopCallEncrypted;
  }
}

/// Нажатие с ⌘ на Mac и с Ctrl на Windows — и без прочих модификаторов.
bool _commandOnly() {
  final hw = HardwareKeyboard.instance;
  final command = _isMacOS ? hw.isMetaPressed : hw.isControlPressed;
  return command && !hw.isShiftPressed && !hw.isAltPressed;
}

/// Буква нажата — по знаку или по месту клавиши: при русской раскладке
/// знаком приходит «в», а не «D», а сочетание должно работать при любой.
bool _isLetter(KeyEvent e, LogicalKeyboardKey logical, PhysicalKeyboardKey p) =>
    e.logicalKey == logical || e.physicalKey == p;

/// Telegram-style 1:1 call, driven by [DesktopDirectCall]. The big remote
/// stream (or avatar for audio) fills the window; the local self-view floats
/// as a draggable PIP. Controls reflect + drive real call state.
///
/// 🔴 СВЕРНУТЬ (24.09.2026, владелец). Звонок закрывал окно целиком, и
/// скрыть его было нечем: пока идёт разговор, приложением нельзя было
/// пользоваться вовсе. Теперь «Свернуть» стоит в доке внизу (и в шапке, и
/// на Esc): звонок уходит в мини-окно, приложение — снова в руках.
class OneToOneCallScreen extends StatefulWidget {
  const OneToOneCallScreen({
    super.key,
    required this.call,
    this.peerName = '',
    this.peerImage,
    this.onEnd,
    this.onMinimize,
    this.onOpenChat,
  });

  final DesktopDirectCall call;
  final String peerName;
  final ImageProvider? peerImage;
  final VoidCallback? onEnd;

  /// Свернуть в мини-окно. `null` — кнопки нет.
  final VoidCallback? onMinimize;

  /// Свернуть и открыть переписку с собеседником. `null` — кнопки нет
  /// (собеседник неизвестен — открывать нечего).
  final VoidCallback? onOpenChat;

  @override
  State<OneToOneCallScreen> createState() => _OneToOneCallScreenState();
}

class _OneToOneCallScreenState extends State<OneToOneCallScreen> {
  bool _controlsVisible = true;
  Offset _pipOffset = const Offset(-24, -120);

  Timer? _ticker; // 1s refresh for the duration label
  Timer? _hideTimer;

  /// Клавиатура — у окна звонка.
  ///
  /// 🔴 Окно звонка ложится поверх приложения, а фокус оставался там, где
  /// был: в поле ввода переписки под ним. Набранное во время звонка уходило
  /// в невидимое поле, а сочетания звонка не доходили до звонка.
  final FocusNode _focus = FocusNode(debugLabel: 'direct-call');

  /// Показ экрана включается не мгновенно: второе нажатие, пока первое не
  /// вернулось, запустило бы второй захват.
  bool _shareBusy = false;

  /// Полноэкранный режим окна.
  ///
  /// Состояние спрашивается у окна, а не хранится своё: окно можно развернуть
  /// и мимо этой кнопки — из меню или клавишей, — и своя память об этом
  /// разошлась бы с действительностью.
  bool _fullScreen = false;

  Future<void> _toggleFullScreen() async {
    try {
      final next = !(await windowManager.isFullScreen());
      await windowManager.setFullScreen(next);
      if (mounted) setState(() => _fullScreen = next);
    } catch (_) {
      // Не десктопная система или окно недоступно — кнопка просто ничего не
      // делает, и это лучше, чем упасть посреди звонка.
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _armHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hideTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _armHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      // 🔴 Прячем пульт только над картинкой: в голосовом звонке смотреть
      // не на что, а исчезающие кнопки заставляют искать, где положить
      // трубку.
      if (!widget.call.state.value.isVideo) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _onHover() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _armHideTimer();
  }

  void _toggleMic() => unawaited(widget.call.toggleMute());

  void _toggleCamera(CallState s) {
    if (s.isVideo) {
      unawaited(widget.call.toggleCamera());
    } else if (_canUpgrade(s)) {
      unawaited(widget.call.upgradeToVideo());
    }
  }

  Future<void> _toggleShare() async {
    if (_shareBusy) return;
    setState(() => _shareBusy = true);
    final wasSharing = widget.call.state.value.isScreenSharing;
    var ok = false;
    try {
      ok = await widget.call.toggleScreenShare();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _shareBusy = false);
    if (ok || wasSharing) return;
    // 🔴 ОТКАЗ — СЛОВАМИ. Раньше неудача показа экрана не значила ничего:
    // кнопка нажималась и оставалась прежней. На Mac причина почти всегда
    // одна — нет разрешения на запись экрана, — и назвать её дешевле, чем
    // заставить человека гадать.
    final l10n = AppLocalizations.of(context)!;
    DesktopSnackbar.show(
      context,
      message: _isMacOS
          ? l10n.desktopCallScreenShareFailedMac
          : l10n.desktopCallScreenShareFailed,
      kind: DSnackKind.error,
      duration: const Duration(seconds: 7),
    );
  }

  Future<void> _pickAudioRoute(BuildContext anchor) async {
    final routeState = widget.call.audioRouteState.value;
    final routes = routeState.availableRoutes;
    if (routes.length < 2) return;
    await ContextMenu.show(
      anchor,
      globalPosition: callMenuAnchorAbove(anchor, routes.length),
      sections: <List<CtxMenuItem>>[
        [
          for (final r in routes)
            CtxMenuItem(
              label: r.label,
              icon: r.deviceId == routeState.selectedRouteId
                  ? FluentIcons.checkmark_24_regular
                  : callAudioRouteIcon(r.kind),
              onTap: () => unawaited(widget.call.selectAudioRoute(r.deviceId)),
            ),
        ],
      ],
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      final minimize = widget.onMinimize;
      if (minimize == null) return KeyEventResult.ignored;
      minimize();
      return KeyEventResult.handled;
    }
    if (!_commandOnly()) return KeyEventResult.ignored;
    final s = widget.call.state.value;
    if (_isLetter(e, LogicalKeyboardKey.keyD, PhysicalKeyboardKey.keyD)) {
      _toggleMic();
      return KeyEventResult.handled;
    }
    if (_isLetter(e, LogicalKeyboardKey.keyE, PhysicalKeyboardKey.keyE)) {
      _toggleCamera(s);
      return KeyEventResult.handled;
    }
    if (_isLetter(e, LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW)) {
      widget.onEnd?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _peerNameFor(CallState s) => desktopCallPeerTitle(
    s,
    AppLocalizations.of(context)!,
    preferred: widget.peerName,
  );

  @override
  Widget build(BuildContext context) {
    // Сцена звонка чёрная в любой теме — значит, и всё, что на ней лежит,
    // берёт тёмные цвета: светлая карточка дока на чёрной сцене читалась бы
    // дырой в картинке.
    return DColors(
      colors: kDColorsDark,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: ValueListenableBuilder<CallState>(
          valueListenable: widget.call.state,
          builder: (ctx, s, _) => _buildForState(ctx, s),
        ),
      ),
    );
  }

  Widget _buildForState(BuildContext context, CallState s) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final session = widget.call.session;
    final name = _peerNameFor(s);
    final avatarName = desktopCallPeerKnownName(s, preferred: widget.peerName);
    final label = _statusLabel(s, l10n);

    final micOn = !s.isMuted;
    final camOn = s.isVideo && !s.isCameraOff;
    // Пульт прячем только над картинкой (см. [_armHideTimer]).
    final showControls = _controlsVisible || !s.isVideo;

    final Widget remote = (s.isVideo && session != null)
        ? _DesktopRemoteVideo(
            session: session,
            peerName: name,
            avatarName: avatarName,
            peerSeed: s.peerProfileId,
            peerImage: widget.peerImage,
            label: label,
          )
        : _AvatarStage(
            name: name,
            avatarName: avatarName,
            seed: s.peerProfileId,
            image: widget.peerImage,
            label: label,
          );

    final Widget pipChild = (camOn && session != null)
        ? _DesktopLocalVideo(session: session, mirror: s.isFrontCamera)
        : const _CameraOffTile();

    return MouseRegion(
      onHover: (_) => _onHover(),
      child: Container(
        color: _kCallStage,
        child: LayoutBuilder(
          builder: (ctx, box) => Stack(
            children: [
              Positioned.fill(child: remote),
              // 🔴 ШАПКА СОЗВОНА: С КЕМ, В КАКОМ СОСТОЯНИИ, СКОЛЬКО ИДЁТ.
              //
              // Раньше слева висел только ярлычок состояния. В видеозвонке имени
              // собеседника не было видно НИГДЕ: камера занимает весь экран, а
              // подпись под портретом видна лишь пока портрет показывается.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: DMotion.base,
                  opacity: showControls ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: _Header(
                      name: name,
                      label: label,
                      chipColor: c.success,
                      fullScreen: _fullScreen,
                      onToggleFullScreen: _toggleFullScreen,
                      onMinimize: widget.onMinimize,
                    ),
                  ),
                ),
              ),
              // Floating local self-view PIP (only meaningful for video calls).
              if (s.isVideo)
                _clampedPip(
                  box.biggest,
                  _PipSelfView(
                    muted: !micOn,
                    onDrag: (delta) => setState(
                      () => _pipOffset = _clampPip(
                        _pipOffset + delta,
                        box.biggest,
                      ),
                    ),
                    child: pipChild,
                  ),
                ),
              // Пульт.
              Positioned(
                left: 0,
                right: 0,
                bottom: DSpace.xl2,
                child: AnimatedOpacity(
                  duration: DMotion.base,
                  opacity: showControls ? 1.0 : 0.0,
                  // 🔴 Спрятанный пульт не нажимается. Прозрачная кнопка
                  // «Завершить» оставалась под курсором и клавишей и клала
                  // трубку от случайного щелчка по картинке.
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: Center(child: _dock(s, l10n, micOn, camOn)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const Size _pipSize = Size(200, 140);

  /// Своё окошко нельзя утащить за край сцены: утащенное туда уже не
  /// вернуть обратно.
  Offset _clampPip(Offset o, Size area) {
    // Смещение считается от правого нижнего угла и отрицательное.
    final minDx = -(area.width - _pipSize.width - 8).clamp(0.0, double.infinity);
    final minDy = -(area.height - _pipSize.height - 8).clamp(0.0, double.infinity);
    return Offset(o.dx.clamp(minDx, -8.0), o.dy.clamp(minDy, -8.0));
  }

  Widget _clampedPip(Size area, Widget child) {
    final o = _clampPip(_pipOffset, area);
    return Positioned(right: -o.dx, bottom: -o.dy, child: child);
  }

  Widget _dock(CallState s, AppLocalizations l10n, bool micOn, bool camOn) {
    final sharing = s.isScreenSharing;
    return ValueListenableBuilder<CallAudioRouteState>(
      valueListenable: widget.call.audioRouteState,
      builder: (ctx, routes, _) => CallDock(
        children: [
          CallDockToggle(
            icon: micOn
                ? FluentIcons.mic_24_filled
                : FluentIcons.mic_off_24_filled,
            label: l10n.callControlMute,
            tooltip: callTooltipWithShortcut(
              micOn ? l10n.desktopCallMicOff : l10n.desktopCallMicOn,
              'D',
            ),
            on: micOn,
            enabled: true,
            onTap: _toggleMic,
            // Шеврона нет, когда выбирать не из чего: стрелка, за которой
            // один пункт, обещает выбор, которого нет.
            onExpand: routes.availableRoutes.length > 1
                ? _pickAudioRoute
                : null,
          ),
          const SizedBox(width: 8),
          CallDockToggle(
            icon: camOn
                ? FluentIcons.video_24_filled
                : FluentIcons.video_off_24_filled,
            label: l10n.callControlCamera,
            tooltip: callTooltipWithShortcut(
              camOn ? l10n.desktopCallCamOff : l10n.desktopCallCamOn,
              'E',
            ),
            on: camOn,
            // В голосовом звонке выключенная камера — не сбой, а суть звонка.
            neutralWhenOff: !s.isVideo,
            enabled: s.isVideo || _canUpgrade(s),
            onTap: () => _toggleCamera(s),
          ),
          if (_canShareScreen(s)) ...[
            const SizedBox(width: 8),
            CallDockToggle(
              icon: sharing
                  ? FluentIcons.share_screen_stop_24_filled
                  : FluentIcons.share_screen_start_24_filled,
              label: l10n.desktopCallScreen,
              tooltip: sharing
                  ? l10n.desktopCallCtlShareStop
                  : l10n.desktopCallCtlShare,
              on: sharing,
              highlighted: sharing,
              neutralWhenOff: true,
              enabled: !_shareBusy,
              onTap: () => unawaited(_toggleShare()),
            ),
          ],
          if (widget.onOpenChat != null) ...[
            const SizedBox(width: 8),
            CallDockToggle(
              icon: FluentIcons.chat_24_regular,
              label: l10n.contactDetailsChat,
              tooltip: l10n.desktopCallOpenChat,
              on: true,
              enabled: true,
              onTap: widget.onOpenChat!,
            ),
          ],
          if (widget.onMinimize != null) ...[
            const SizedBox(width: 8),
            CallDockToggle(
              icon: FluentIcons.picture_in_picture_enter_24_regular,
              label: l10n.callMinimize,
              tooltip: callTooltipWithShortcut(
                l10n.desktopCallMinimiseHint,
                'Esc',
              ),
              on: true,
              enabled: true,
              onTap: widget.onMinimize!,
            ),
          ],
          const CallDockDivider(),
          CallDockToggle(
            icon: FluentIcons.call_end_24_filled,
            label: l10n.callControlEnd,
            tooltip: callTooltipWithShortcut(l10n.callControlEnd, 'W'),
            on: false,
            danger: true,
            // Положить трубку можно всегда — даже когда другое действие ещё
            // не вернулось.
            enabled: true,
            onTap: () => widget.onEnd?.call(),
          ),
        ],
      ),
    );
  }
}

/// Шапка звонка во всё окно: имя, состояние, «свернуть», «во весь экран» —
/// и то, что шапка окна приложения давала бы, не будь она под звонком:
/// место, за которое окно таскают, и кнопки окна на Windows.
class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.label,
    required this.chipColor,
    required this.fullScreen,
    required this.onToggleFullScreen,
    required this.onMinimize,
  });

  final String name;
  final String label;
  final Color chipColor;
  final bool fullScreen;
  final VoidCallback onToggleFullScreen;
  final VoidCallback? onMinimize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        // Затемнение сверху: белые подписи поверх светлого кадра камеры иначе
        // не читаются.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Окно звонка лежит поверх шапки приложения: без своей полосы окно
          // во время разговора нельзя было даже сдвинуть.
          const Positioned.fill(child: DesktopWindowDragRegion()),
          Positioned.fill(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🔴 Слева — место под «светофор» macOS: без него имя
              // собеседника ложилось под кнопки окна.
              SizedBox(width: _isMacOS ? 80 : DSpace.l),
              // 🔴 Левая группа — ОДНА растягиваемая часть строки. С
              // `Flexible` у имени и распоркой после чипа свободное место
              // делилось пополам, и кнопки «свернуть» и «во весь экран»
              // стояли посреди шапки, а не у правого края.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DType.bodyStrong.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: DSpace.m),
                    _CallChip(label: label, color: chipColor),
                  ],
                ),
              ),
              const SizedBox(width: DSpace.m),
              if (onMinimize != null) ...[
                _CallChromeButton(
                  icon: FluentIcons.picture_in_picture_enter_24_regular,
                  tooltip: callTooltipWithShortcut(
                    l10n.desktopCallMinimiseHint,
                    'Esc',
                  ),
                  onTap: onMinimize!,
                ),
                const SizedBox(width: 6),
              ],
              _CallChromeButton(
                icon: fullScreen
                    ? FluentIcons.full_screen_minimize_24_regular
                    : FluentIcons.full_screen_maximize_24_regular,
                tooltip: fullScreen
                    ? l10n.desktopCallExitFullscreen
                    : l10n.desktopCallFullscreen,
                onTap: onToggleFullScreen,
              ),
              if (_isWindows)
                const Padding(
                  padding: EdgeInsets.only(left: DSpace.s),
                  child: DesktopWindowsCaptionButtons(),
                )
              else
                const SizedBox(width: DSpace.m),
            ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Чип состояния созвона: замок, состояние и длительность.
///
/// 🔴 Замок, а не просто точка. Точка означает «связь есть» — это и так видно
/// по картинке. Здесь же сказано «Зашифровано», и знак рядом должен означать
/// ровно это: тот же замок и тот же зелёный, что у поля ввода в переписке.
///
/// Задержки в чипе НЕТ, хотя в макете она есть: `CallState` времени отклика не
/// несёт, а рисовать правдоподобное число, взятое ниоткуда, — худшее, что
/// можно сделать в окне, где человек решает, слышно его или нет.
class _CallChip extends StatelessWidget {
  const _CallChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(DRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.lock_closed_16_filled, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: DType.family,
              fontSize: 11.5,
              height: 1.0,
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка в шапке созвона. Полупрозрачная: она лежит поверх живого кадра.
class _CallChromeButton extends StatelessWidget {
  const _CallChromeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: HoverListener(
          onTap: onTap,
          builder: (ctx, hovered, pressed) => AnimatedContainer(
            duration: DMotion.fast,
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: pressed ? 0.20 : (hovered ? 0.14 : 0.06),
              ),
              borderRadius: BorderRadius.circular(DRadii.sm),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Мини-окно звонка один на один.
///
/// Кнопки — те же вызовы, что у пульта во всё окно: микрофон, камера,
/// развернуть, положить трубку. Время разговора идёт и здесь: человек,
/// свернувший звонок, не должен разворачивать его ради «сколько мы уже
/// говорим».
class OneToOneCallMini extends StatefulWidget {
  const OneToOneCallMini({
    super.key,
    required this.call,
    this.peerName = '',
    this.peerImage,
    required this.onExpand,
    required this.onEnd,
  });

  final DesktopDirectCall call;
  final String peerName;
  final ImageProvider? peerImage;
  final VoidCallback onExpand;
  final VoidCallback onEnd;

  /// Размер мини-окна для этого звонка: с картинкой — выше.
  static Size sizeFor(CallState s) => DesktopCallMiniSize.of(video: s.isVideo);

  @override
  State<OneToOneCallMini> createState() => _OneToOneCallMiniState();
}

class _OneToOneCallMiniState extends State<OneToOneCallMini> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DColors(
      colors: kDColorsDark,
      child: ValueListenableBuilder<CallState>(
        valueListenable: widget.call.state,
        builder: (ctx, s, _) => _build(ctx, s),
      ),
    );
  }

  Widget _build(BuildContext context, CallState s) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final session = widget.call.session;
    final name = desktopCallPeerTitle(s, l10n, preferred: widget.peerName);
    final avatarName = desktopCallPeerKnownName(s, preferred: widget.peerName);
    final connected = s.phase == CallPhase.connected;
    final status = _statusLabel(s, l10n);
    final micOn = !s.isMuted;
    final camOn = s.isVideo && !s.isCameraOff;

    final Widget stage;
    if (s.isVideo) {
      stage = Stack(
        fit: StackFit.expand,
        children: [
          if (session != null)
            _DesktopRemoteVideo(
              session: session,
              peerName: name,
              avatarName: avatarName,
              peerSeed: s.peerProfileId,
              peerImage: widget.peerImage,
              label: status,
              compact: true,
            )
          else
            _MiniAvatarStage(
              name: name,
              avatarName: avatarName,
              seed: s.peerProfileId,
              image: widget.peerImage,
            ),
          Positioned(
            left: 8,
            top: 8,
            right: 8,
            child: Row(
              children: [
                DesktopCallMiniChip(label: status, secure: connected),
              ],
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DType.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ),
        ],
      );
    } else {
      stage = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Avatar(
              name: avatarName,
              seed: s.peerProfileId,
              image: widget.peerImage,
              size: 44,
              background: kDesktopCallMiniStage,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.bodyStrong.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (connected) ...[
                        Icon(
                          FluentIcons.lock_closed_16_filled,
                          size: 11,
                          color: c.success,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DType.tiny.copyWith(
                            color: connected ? c.success : c.textSecondary,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DesktopCallMiniCard(
      video: s.isVideo,
      stage: stage,
      semanticLabel: '$name · $status',
      onExpand: widget.onExpand,
      expandTooltip: l10n.desktopCallExpand,
      controls: [
        DesktopCallMiniButton(
          icon: micOn ? FluentIcons.mic_20_filled : FluentIcons.mic_off_20_filled,
          tooltip: micOn ? l10n.desktopCallMicOff : l10n.desktopCallMicOn,
          tone: micOn ? DesktopCallMiniTone.normal : DesktopCallMiniTone.off,
          onTap: () => unawaited(widget.call.toggleMute()),
        ),
        DesktopCallMiniButton(
          icon: camOn
              ? FluentIcons.video_20_filled
              : FluentIcons.video_off_20_filled,
          tooltip: camOn ? l10n.desktopCallCamOff : l10n.desktopCallCamOn,
          onTap: s.isVideo
              ? () => unawaited(widget.call.toggleCamera())
              : (_canUpgrade(s)
                    ? () => unawaited(widget.call.upgradeToVideo())
                    : null),
        ),
      ],
      end: DesktopCallMiniButton(
        icon: FluentIcons.call_end_20_filled,
        tooltip: l10n.callControlEnd,
        tone: DesktopCallMiniTone.end,
        onTap: widget.onEnd,
      ),
    );
  }
}

/// Портрет на сцене мини-окна, пока картинки нет.
class _MiniAvatarStage extends StatelessWidget {
  const _MiniAvatarStage({
    required this.name,
    required this.avatarName,
    required this.seed,
    required this.image,
  });

  final String name;
  final String avatarName;
  final String seed;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Avatar(
        name: avatarName,
        seed: seed,
        image: image,
        size: 56,
        background: kDesktopCallMiniStage,
      ),
    );
  }
}

/// Big remote surface: avatar background with the live remote video mounted on
/// top once it's renderable (mirrors mobile's `_RemoteVideoSurface`).
class _DesktopRemoteVideo extends StatelessWidget {
  const _DesktopRemoteVideo({
    required this.session,
    required this.peerName,
    required this.avatarName,
    required this.peerSeed,
    required this.peerImage,
    required this.label,
    this.compact = false,
  });

  final WebRtcCallSession session;
  final String peerName;
  final String avatarName;
  final String peerSeed;
  final ImageProvider? peerImage;
  final String label;

  /// В мини-окне под картинкой — только портрет: имя и состояние там
  /// подписаны поверх сцены.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RemoteVideoLifecycle>(
      valueListenable: session.remoteVideoLifecycle,
      builder: (context, lifecycle, _) {
        final mount =
            lifecycle.isRenderable || _hasVideoTracks(session.remoteRenderer);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (compact)
              _MiniAvatarStage(
                name: peerName,
                avatarName: avatarName,
                seed: peerSeed,
                image: peerImage,
              )
            else
              _AvatarStage(
                name: peerName,
                avatarName: avatarName,
                seed: peerSeed,
                image: peerImage,
                label: label,
              ),
            if (mount)
              RTCVideoView(
                key: ValueKey(
                  'remote:${session.hashCode}:${lifecycle.state.name}:${_bindingToken(session.remoteRenderer)}',
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

class _DesktopLocalVideo extends StatelessWidget {
  const _DesktopLocalVideo({required this.session, required this.mirror});

  final WebRtcCallSession session;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      key: ValueKey(
        'local:${session.hashCode}:${_bindingToken(session.localRenderer)}',
      ),
      session.localRenderer,
      mirror: mirror,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

bool _hasVideoTracks(RTCVideoRenderer renderer) {
  final stream = renderer.srcObject;
  if (stream == null) return false;
  try {
    return stream.getVideoTracks().isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Stable token so [RTCVideoView] rebinds when the underlying stream/tracks
/// change. Mirrors mobile's `_videoRendererBindingToken`.
String _bindingToken(RTCVideoRenderer renderer) {
  final stream = renderer.srcObject;
  if (stream == null) return 'stream:none';
  try {
    final trackIds = stream.getVideoTracks().map((t) => t.id).join(',');
    return 'stream:${stream.id}|tracks:${trackIds.isEmpty ? 'none' : trackIds}';
  } catch (_) {
    return 'stream:${stream.id}|tracks:error';
  }
}

/// Audio / no-remote-video stage: centered avatar, name and status label.
class _AvatarStage extends StatelessWidget {
  const _AvatarStage({
    required this.name,
    this.avatarName = '',
    required this.seed,
    this.image,
    required this.label,
  });

  final String name;

  /// Настоящее имя для букв на заглушке; пустое — «?», а не буквы подписи.
  final String avatarName;

  /// Ключ цвета заглушки — профиль собеседника, как в списке чатов. По имени
  /// тот же человек выходил в звонке другого цвета (17.09.2026).
  final String seed;
  final ImageProvider? image;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заливка — от чёрной сцены, а не от фона окна: в светлой теме
          // иначе на сцене лежало бы бледное пятно.
          Avatar(
            name: avatarName,
            seed: seed,
            image: image,
            size: 160,
            background: _kCallStage,
          ),
          const SizedBox(height: DSpace.l),
          Text(name, style: DType.title.copyWith(color: Colors.white)),
          const SizedBox(height: DSpace.xs),
          Text(label, style: DType.label.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _CameraOffTile extends StatelessWidget {
  const _CameraOffTile();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16181D),
      alignment: Alignment.center,
      child: const Icon(
        Icons.videocam_off_rounded,
        color: Colors.white38,
        size: 28,
      ),
    );
  }
}

class _PipSelfView extends StatelessWidget {
  const _PipSelfView({
    required this.child,
    required this.muted,
    required this.onDrag,
  });
  final Widget child;
  final bool muted;
  final ValueChanged<Offset> onDrag;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        onPanUpdate: (d) => onDrag(d.delta),
        child: Container(
          width: 200,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DRadii.lg),
            boxShadow: DShadows.floating,
            border: Border.all(color: Colors.white24, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (muted)
                const Positioned(
                  left: 8,
                  bottom: 8,
                  child: Icon(
                    Icons.mic_off_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
