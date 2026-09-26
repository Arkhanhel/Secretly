// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/app_controller.dart';
import '../app/desktop_app_view_model.dart';
import '../app/desktop_selector.dart';
import '../../../calls/call_audio_route.dart';
import '../../../rooms/room_call_manager.dart';
import '../../../transport/relay_client.dart'
    show RelayRoomCallMediaBackendKind;
import '../../../rooms/room_call_media_controller.dart';
import '../../../rooms/room_call_media_state.dart';
import '../../../rooms/room_call_state.dart';
import '../chat/details/room_invite_share.dart';
import '../chat/details/details_tabs.dart';
import '../primitives/context_menu.dart';
import '../primitives/desktop_snackbar.dart';
import '../primitives/desktop_tooltip.dart';
import '../chat/details/room_notes_pane.dart';
import '../design/tokens.dart';
import '../services/desktop_ui_prefs.dart';
import '../services/demo_rooms.dart';
import 'call_controls.dart';
import 'call_presence.dart';
import 'call_stage_pick.dart';
import '../primitives/avatar.dart';
import '../primitives/hover_listener.dart';
import '../shell/window_chrome.dart';

/// Окно комнатного созвона для десктопа.
///
/// 🔴 ЭТО ТОЛЬКО ВИД. ДВИЖОК ОСТАЁТСЯ ОБЩИМ С ТЕЛЕФОНОМ.
///
/// Соблазн переписать созвон под десктоп целиком велик и неправилен: вход,
/// выход, медиасессия, дорожки LiveKit, пересборка при переподключении — это
/// две с лишним тысячи строк, которые работают у тысяч людей. Вторая их
/// реализация разошлась бы с первой на первой же правке, и расходиться она
/// стала бы в самом дорогом месте — в звонке.
///
/// Поэтому здесь нет НИ ОДНОГО собственного шага жизненного цикла. Окно:
///
///  * читает состояние у [RoomCallManager.state] и снимка [CachedRoomCall];
///  * рисует дорожки через [RoomCallMediaController] — тем же способом, что и
///    телефон;
///  * вход, выход и смену своих флагов делает ТЕМИ ЖЕ вызовами контроллера, в
///    том же порядке, что мобильный экран.
///
/// Разница только в раскладке: на телефоне один столбец и крупные кнопки под
/// палец, на столе — сцена, список участников сбоку и панель снизу.
class DesktopRoomCallWindow extends StatefulWidget {
  const DesktopRoomCallWindow({
    super.key,
    required this.vm,
    required this.groupId,
    required this.title,
  });

  /// Шов к приложению. Снимок созвона читается ЧЕРЕЗ НЕГО, а не своей
  /// подпиской на `changed`: общий склад уже гасит бурю тиков и отдаёт
  /// значение только когда оно правда изменилось.
  final DesktopAppViewModel vm;

  AppController get controller => vm.controller;
  final String groupId;
  final String title;

  @override
  State<DesktopRoomCallWindow> createState() => _DesktopRoomCallWindowState();
}

class _DesktopRoomCallWindowState extends State<DesktopRoomCallWindow> {
  /// Подписи окна. Метод `_nameFor` и сборка списков зовутся из многих мест,
  /// и `AppLocalizations.of(context)!` в каждом читался бы хуже подписи.
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  late final DesktopSelector<CachedRoomCall?> _callSel;
  Timer? _ticker;

  CachedRoomCall? get _call => _callSel.value;
  List<RoomMember> _members = const <RoomMember>[];
  String _myProfileId = '';
  bool _fullScreen = false;

  /// 🔴 Одно действие за раз, как на телефоне.
  ///
  /// Вход, выход и смена флагов ходят на релей и возвращаются не мгновенно.
  /// Без этой защёлки два быстрых нажатия по «выключить микрофон» отправляют
  /// два встречных обновления, и побеждает то, что вернётся вторым, — а оно
  /// может нести устаревшее состояние.
  String? _busy;

  /// Комната ДЕМОНСТРАЦИОННАЯ — её нет на сервере, и созвона в ней не будет.
  ///
  /// 🔴 Владелец, 14.09: «эта группа видимо тестовая, в мобильной версии у меня
  /// её вообще нет, поэтому она не звонит». Ровно так: релей на попытку войти
  /// отвечает `404 room not found`, потому что демонстрационные комнаты живут
  /// только в местной базе.
  ///
  /// Значит кнопки «Голосом» и «С камерой» в такой комнате обещают то, чего
  /// быть не может. Их там нет; вместо них — одна строка правды.
  ///
  /// Сама проверка — общая: [isDemoRoomId]. Её же спрашивают подробности
  /// комнаты, чтобы не предлагать там ссылку-приглашение.
  bool get _isDemoRoom => isDemoRoomId(widget.groupId);

  /// Почему последнее действие не получилось. `null` — получилось.
  ///
  /// 🔴 ДЕЙСТВИЯ СОЗВОНА ПРОВАЛИВАЛИСЬ МОЛЧА.
  ///
  /// Проверено живьём 14.09: нажатие «Голосом» в комнате, которой нет на
  /// релее, отвечало `HTTP 404 room not found` — в журнале. В окне при этом не
  /// менялось НИЧЕГО: ни кружка ожидания, ни строчки, ни всплывашки. Человек
  /// жмёт кнопку, жмёт второй раз, третий — и не знает, сломано приложение,
  /// нет сети или он что-то делает не так.
  ///
  /// Причина была двойная: `joinRelayRoomCall` на отказе возвращает `null`, а
  /// не бросает (и `null` тут ничем не отличался от успеха), а обёртка `_run`
  /// не ловила исключений вовсе — брошенное улетало в никуда.
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _myProfileId = widget.controller.profileId;
    // Окно открыто — мини-окна этого созвона нет. Сообщаем после кадра:
    // корень и мини-окно перестраиваются по этому признаку, а менять дерево
    // посреди его постройки нельзя.
    final presence = DesktopCallPresence.instance;
    presence.rememberRoomTitle(widget.groupId, widget.title);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) presence.roomWindowOpened(widget.groupId, this);
    });
    unawaited(_loadMembers());
    // Камеры спрашиваем один раз при открытии окна: перечисление устройств —
    // обращение к системе, из `build` его звать нельзя.
    unawaited(_refreshCameras());
    _callSel = widget.vm.select<CachedRoomCall?>(
      debugName: 'roomCall:${widget.groupId}',
      initial: null,
      load: () async {
        final call = await widget.controller.getCachedRoomCall(widget.groupId);
        return (call != null && call.isActive) ? call : null;
      },
      // Перерисовываем только при смене созвона или его версии: снимок
      // обновляется чаще, чем меняется то, что видно в окне.
      signature: (call) =>
          call == null ? '' : '${call.callId}/${call.stateVersion}',
    )..addListener(_onRuntime);
    // Длительность идёт сама: состояние созвона меняется редко, и без этого
    // счётчик стоял бы на месте.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    RoomCallManager.instance?.state.addListener(_onRuntime);
    // Список устройств вывода приезжает отдельным состоянием и уже ПОСЛЕ
    // подключения. Без подписки шеврон у «Микрофона» не появился бы до
    // следующей перерисовки окна по другой причине.
    RoomCallManager.instance?.audioRouteState.addListener(_onRuntime);
    unawaited(_loadChatTail());
  }

  @override
  void dispose() {
    // Тоже после кадра: во время разборки дерева перестраивать его нельзя.
    final owner = this;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => DesktopCallPresence.instance.roomWindowClosed(owner),
    );
    RoomCallManager.instance?.state.removeListener(_onRuntime);
    RoomCallManager.instance?.audioRouteState.removeListener(_onRuntime);
    _callSel.removeListener(_onRuntime);
    _callSel.dispose();
    _chatInput.dispose();
    _ticker?.cancel();
    _statsTimer?.cancel();
    super.dispose();
  }

  /// Свернуть окно созвона в мини-окно. Созвон при этом идёт дальше.
  ///
  /// Признак «окно закрыто» снимаем СРАЗУ, не дожидаясь конца анимации:
  /// мини-окно проявляется, пока окно созвона уезжает, а не после.
  void _minimize() {
    DesktopCallPresence.instance.roomWindowClosed(this);
    Navigator.of(context).maybePop();
  }

  /// Сочетания окна созвона: Esc — свернуть; ⌘D / Ctrl+D — микрофон;
  /// ⌘E / Ctrl+E — камера; ⌘W / Ctrl+W — выйти.
  ///
  /// Работают и из поля чата созвона: ни одно из них поле ввода не занимает.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _minimize();
      return KeyEventResult.handled;
    }
    final hw = HardwareKeyboard.instance;
    final isMac = !kIsWeb && Platform.isMacOS;
    final command = isMac ? hw.isMetaPressed : hw.isControlPressed;
    if (!command || hw.isShiftPressed || hw.isAltPressed) {
      return KeyEventResult.ignored;
    }
    bool letter(LogicalKeyboardKey l, PhysicalKeyboardKey p) =>
        e.logicalKey == l || e.physicalKey == p;
    final call = _call;
    final self = call?.selfParticipant;
    final joined = self?.isJoined ?? false;
    if (letter(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW)) {
      if (!joined) return KeyEventResult.ignored;
      unawaited(_leave());
      return KeyEventResult.handled;
    }
    if (!joined || _busy != null) return KeyEventResult.ignored;
    if (letter(LogicalKeyboardKey.keyD, PhysicalKeyboardKey.keyD)) {
      unawaited(_updateSelf(muted: !self!.muted));
      return KeyEventResult.handled;
    }
    if (letter(LogicalKeyboardKey.keyE, PhysicalKeyboardKey.keyE)) {
      if (!_mediaBackendReady) return KeyEventResult.ignored;
      unawaited(_updateSelf(videoEnabled: !_videoLive(self!)));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Кто говорил последним — память сцены. См. [pickStageVideo].
  ///
  /// 🔴 Без неё сцена гасла в каждую паузу разговора: условие показа камеры
  /// было «говорит сейчас ИЛИ участник ровно один».
  String? _lastSpeaker;

  void _onRuntime() {
    // Медиа-канал появляется ПОЗЖЕ открытия окна: выбор из настроек
    // применяем, когда движку есть что переключать.
    unawaited(_applyPreferredDevices());
    _lastSpeaker = nextLastSpeaker(
      speaking: _speakingDeviceIds(),
      cameras: _cameraDeviceIds(),
      previous: _lastSpeaker,
    );
    if (mounted) setState(() {});
  }

  /// Те, чей вид камеры УЖЕ готов к показу, в порядке участников созвона.
  List<String> _cameraDeviceIds() {
    final media = _media;
    final runtime = _runtime;
    if (media == null || runtime == null) return const <String>[];
    return [
      for (final p in runtime.participants)
        if (p.publishVideo && media.hasParticipantCameraView(p.deviceId))
          p.deviceId,
    ];
  }

  /// То же для демонстрации экрана.
  List<String> _screenShareDeviceIds() {
    final media = _media;
    final runtime = _runtime;
    if (media == null || runtime == null) return const <String>[];
    return [
      for (final p in runtime.participants)
        if (p.publishScreenShare &&
            media.hasParticipantScreenShareView(p.deviceId))
          p.deviceId,
    ];
  }

  Set<String> _speakingDeviceIds() {
    final media = _media;
    final runtime = _runtime;
    if (media == null || runtime == null) return const <String>{};
    return {
      for (final p in runtime.participants)
        if (media.isParticipantSpeaking(p.deviceId)) p.deviceId,
    };
  }

  Future<void> _loadMembers() async {
    try {
      final list = await widget.controller.listRoomMembersDetailed(
        widget.groupId,
      );
      if (mounted) setState(() => _members = list);
    } catch (_) {
      // Имена — украшение списка: без них участник показывается по
      // идентификатору, и созвон от этого не ломается.
    }
  }

  /// 🔴 ЗАВИСШЕЕ ДЕЙСТВИЕ ЗАПИРАЛО ЧЕЛОВЕКА В СОЗВОНЕ (14.09.2026, живая
  /// проверка вдвоём).
  ///
  /// Было так: `_run` начинался с `if (_busy != null) return`, а все кнопки
  /// дока рисовались с `enabled: !busy`. Нажатие «Камера» ушло в запрос,
  /// который НЕ ВЕРНУЛСЯ — и `_busy` остался стоять навсегда. После этого не
  /// работало ничего, в том числе «ВЫЙТИ»: из созвона нельзя было выйти
  /// вообще. Проверено живьём: кнопка нажимается, ничего не происходит.
  ///
  /// Две правки, и обе обязательны:
  ///
  ///   • [force] — «Выйти» не спрашивает `_busy` и не ждёт чужого действия.
  ///     Выход из разговора не может зависеть от того, ответил ли сервер на
  ///     что-то другое;
  ///   • [timeout] — ни одно действие не висит вечно. Сервер молчит —
  ///     говорим словами и отпускаем кнопки.
  Future<void> _run(
    String tag,
    Future<void> Function() body, {
    bool force = false,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_busy != null && !force) return;
    setState(() {
      _busy = tag;
      _actionError = null;
    });
    try {
      await body().timeout(timeout);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _actionError =
              _l10n.desktopCallServerSilent,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _actionError = _describeCallError(e, _l10n));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Человеческий текст отказа вместо текста исключения.
  ///
  /// Разбираем ровно то, что здесь действительно встречается; всё остальное
  /// показываем как есть — придуманная формулировка хуже сырой правды.
  /// 🔴 СЛУЖЕБНЫЕ ПРИСТАВКИ DART СРЕЗАЕМ. `StateError` печатается как
  /// «Bad state: …», `Exception` — как «Exception: …». Проверено живьём: в
  /// окне так и было написано «Bad state: Не удалось войти в созвон» —
  /// половина строки на английском и про внутреннее устройство.
  ///
  /// Вынесено отдельно: тем же занимается отказ отправки в чате созвона, а
  /// вот перевод «404» в «созвон не начать» ему не подходит — он про созвон.
  static String _stripDartPrefix(Object error) {
    var text = error.toString();
    for (final prefix in const ['Bad state: ', 'Exception: ', 'Error: ']) {
      if (text.startsWith(prefix)) {
        return text.substring(prefix.length);
      }
    }
    return text;
  }

  static String _describeCallError(Object error, AppLocalizations l10n) {
    final text = _stripDartPrefix(error);
    if (text.contains('404') || text.contains('room not found')) {
      return l10n.desktopCallRoomMissing;
    }
    if (text.contains('SocketException') || text.contains('Failed host')) {
      return l10n.desktopCallNoServer;
    }
    return text;
  }

  // ── Действия: те же вызовы и в том же порядке, что на телефоне ───────────

  Future<void> _startOrJoin({
    required String mediaType,
    required bool videoEnabled,
  }) {
    return _run('join', () async {
      final effective = _call?.mediaType ?? mediaType;
      final result = await widget.controller.joinRelayRoomCall(
        roomId: widget.groupId,
        mediaType: effective,
        supportsVideo: true,
        supportsScreenShare: true,
        muted: false,
        deafened: false,
        videoEnabled: videoEnabled,
        screenShareEnabled: false,
      );
      if (result == null) {
        // 🔴 `null` — это ОТКАЗ, а не успех: `joinRelayRoomCall` ловит ошибку
        // сети внутри и возвращает пустоту. Раньше эта пустота молча
        // приравнивалась к успеху, и окно просто оставалось прежним.
        // Причина осталась в журнале контроллера (`joinRelayRoomCall` ловит
        // HTTP-ошибку внутри и возвращает пустоту), поэтому здесь — честное
        // общее объяснение и подсказка, что делать.
        throw StateError(
          _l10n.desktopCallJoinFailed,
        );
      }
      await RoomCallManager.instance?.ensureJoined(
        roomId: widget.groupId,
        callId: result.call.callId,
        forceRefresh: true,
      );
      await _callSel.refresh();
    });
  }

  /// Выдал ли сервер медиа-канал для этого созвона.
  ///
  /// 🔴 МОЛЧАНИЕ ЗДЕСЬ — ХУДШИЙ ОТВЕТ (14.09.2026, живая проверка вдвоём).
  ///
  /// Проверено на двух устройствах: оба «в эфире», а видео с телефона не
  /// доходит, камера на компьютере не включается, признака речи нет. Причина
  /// не в окне: relay отдал `backend.kind = unavailable` — то есть медиа-
  /// сервер (LiveKit) ему не настроен, и клиент честно падает в местный
  /// предпросмотр, где видео выключено константой, а удалённых дорожек нет
  /// вовсе.
  ///
  /// Окно об этом ЗНАЛО и молчало: кнопки «Камера» и «Экран» нажимались и
  /// ничего не делали. Человек в такой ситуации винит приложение.
  bool get _mediaBackendReady {
    final backend = RoomCallManager.instance?.session?.backend;
    if (backend == null) return true; // сессии ещё нет — молчим, а не пугаем
    return backend.kind == RelayRoomCallMediaBackendKind.livekit &&
        backend.isConfigured;
  }

  Future<void> _updateSelf({
    bool? muted,
    bool? videoEnabled,
    bool? screenShareEnabled,
  }) {
    final call = _call;
    final self = call?.selfParticipant;
    if (call == null || self == null) return Future<void>.value();
    return _run('self', () async {
      final result = await widget.controller.updateRelayRoomCallParticipant(
        roomId: widget.groupId,
        callId: call.callId,
        reconnecting: self.isReconnecting,
        muted: muted ?? self.muted,
        deafened: self.deafened,
        videoEnabled: videoEnabled ?? self.videoEnabled,
        screenShareEnabled: screenShareEnabled ?? self.screenShareEnabled,
        speaking: self.speaking,
      );
      // 🔴 `null` — это ОТКАЗ: релей не ответил, и переключение не
      // случилось. Раньше это молчало — кнопка оставалась прежней без
      // объяснения, и «думаю, что молчу» расходилось с правдой.
      if (result == null) throw StateError(_l10n.desktopCallToggleFailed);
      if (result.selfParticipant?.isJoined ?? false) {
        await RoomCallManager.instance?.ensureJoined(
          roomId: widget.groupId,
          callId: call.callId,
          forceRefresh: true,
        );
      }
      await _callSel.refresh();
    });
  }

  /// Выход — единственное действие, которое обязано работать ВСЕГДА.
  ///
  /// `force: true` не спрашивает `_busy`: см. [_run]. Срок ожидания больше
  /// обычного — выход стоит подождать дольше, чем переключение камеры.
  Future<void> _leave() {
    final call = _call;
    if (call == null) return Future<void>.value();
    return _run('leave', force: true, timeout: const Duration(seconds: 20), () async {
      final result = await widget.controller.leaveRelayRoomCall(
        roomId: widget.groupId,
        callId: call.callId,
      );
      if (result != null) {
        await RoomCallManager.instance?.clearIfMatches(
          roomId: widget.groupId,
          callId: call.callId,
        );
        if (mounted) Navigator.of(context).maybePop();
      } else {
        // Выйти не вышло — сказать, а не оставить человека жать «Выйти» ещё
        // и ещё, не понимая, почему он всё ещё в созвоне.
        throw StateError(_l10n.desktopCallLeaveFailed);
      }
    });
  }

  Future<void> _toggleFullScreen() async {
    try {
      final next = !(await windowManager.isFullScreen());
      await windowManager.setFullScreen(next);
      if (mounted) setState(() => _fullScreen = next);
    } catch (_) {
      // не десктопная система — кнопка просто ничего не делает
    }
  }

  // ── Данные для вида ──────────────────────────────────────────────────────

  RoomCallRuntimeState? get _runtime => RoomCallManager.instance?.state.value;

  RoomCallMediaController? get _media =>
      RoomCallManager.instance?.mediaController;

  String _nameFor(String profileId) {
    if (profileId == _myProfileId) return _l10n.desktopSupportYou;
    for (final m in _members) {
      if (m.profileId == profileId) {
        final n = m.displayName.trim();
        if (n.isNotEmpty) return n;
      }
    }
    return profileId;
  }

  String? _avatarFor(String profileId) {
    for (final m in _members) {
      if (m.profileId == profileId) return m.avatarPath;
    }
    return null;
  }

  /// Состояние участника по РУНТАЙМУ, а не по флагу снимка.
  ///
  /// 🔴 Снимок с релея и то, что реально передаётся, расходятся. Проверка
  /// 13.09: голосовой созвон, камера не включалась ни разу — а снимок нёс
  /// `videoEnabled = true`, и строка участника честно писала «камера
  /// включена». Никакой камеры при этом не было.
  ///
  /// Для показа правильный источник — медиаслой: он знает, есть ли дорожка.
  /// Флаг снимка остаётся тем, чем и является: намерением, которое мы
  /// отправили релею.
  RoomCallParticipantRuntimeState? _runtimeFor(String deviceId) {
    final runtime = _runtime;
    if (runtime == null) return null;
    for (final p in runtime.participants) {
      if (p.deviceId == deviceId) return p;
    }
    return null;
  }

  bool _videoLive(CachedRoomCallParticipant p) {
    final rt = _runtimeFor(p.deviceId);
    if (rt == null) return false;
    return rt.publishVideo &&
        (_media?.hasParticipantCameraView(p.deviceId) ?? false);
  }

  bool _shareLive(CachedRoomCallParticipant p) {
    final rt = _runtimeFor(p.deviceId);
    if (rt == null) return false;
    return rt.publishScreenShare &&
        (_media?.hasParticipantScreenShareView(p.deviceId) ?? false);
  }

  List<CachedRoomCallParticipant> get _joined =>
      (_call?.participants ?? const <CachedRoomCallParticipant>[])
          .where((p) => p.isJoined)
          .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final call = _call;
    final selfJoined = call?.selfParticipant?.isJoined ?? false;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _Header(
            title: widget.title,
            call: call,
            joinedCount: _joined.length,
            fullScreen: _fullScreen,
            anyoneSpeaking: _speakingDeviceIds().isNotEmpty,
            onBack: _minimize,
            onToggleFullScreen: _toggleFullScreen,
          ),
          Expanded(
            child: call == null
                ? _StartPanel(
                    demo: _isDemoRoom,
                    error: _actionError,
                    busy: _busy != null,
                    onVoice: () => unawaited(
                      _startOrJoin(mediaType: 'audio', videoEnabled: false),
                    ),
                    onVideo: () => unawaited(
                      _startOrJoin(mediaType: 'video', videoEnabled: true),
                    ),
                  )
                : !selfJoined
                ? _JoinPanel(
                    error: _actionError,
                    busy: _busy != null,
                    joinedCount: _joined.length,
                    onJoin: () => unawaited(
                      _startOrJoin(
                        mediaType: call.mediaType,
                        videoEnabled: false,
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 🔴 Панель управления живёт ПОД СЦЕНОЙ, а не под всем
                      // окном. Кнопки, растянутые под списком участников,
                      // читаются как относящиеся к списку — а они про созвон.
                      Expanded(
                        // 🔴 У СЦЕНЫ ЕСТЬ ПОЛЯ. Она упиралась в края окна и в
                        // панель участников: чёрный прямоугольник от края до
                        // края читается как «видео сломалось и залило экран»,
                        // а не как сцена созвона. В макете вокруг неё 14 точек
                        // и 12 до панели управления.
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: _stage(c)),
                                    // 🔴 ЛЕНТА ПЛИТОК — из макета. Без неё во
                                    // время демонстрации экрана не видно НИ
                                    // ОДНОГО лица: сцену занимает экран, а
                                    // список справа — это текстовые строки.
                                    // Разговор при этом идёт между людьми.
                                    //
                                    // Вдвоём ленты нет: она показала бы одну
                                    // плитку рядом с тем же самым кадром.
                                    if (_joined.length >= 2) ...[
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 212,
                                        child: _participantStrip(c),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _controls(c),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, color: c.borderSubtle),
                      SizedBox(width: 300, child: _participantsPanel(c)),
                    ],
                  ),
          ),
        ],
      ),
      ),
    );
  }

  /// Сцена: демонстрация экрана, если она есть; иначе говорящий; иначе сетка.
  ///
  /// 🔴 Порядок именно такой. Демонстрация экрана — то, ради чего созвон и
  /// собрали: если её отодвинуть ради чьего-то лица, смотреть станет не на
  /// что. Говорящий — следующий по важности: в разговоре важно видеть, кто
  /// сейчас держит слово.
  Widget _stage(DColorSet c) => _stageBody(c, _currentStagePick());

  /// Чей кадр сейчас на сцене. `null` — сетка портретов.
  ///
  /// Считается ОДИН раз за отрисовку и передаётся и сцене, и своему превью:
  /// иначе они спросили бы порядок выбора порознь и могли бы разойтись.
  StagePick? _currentStagePick() {
    final media = _media;
    final runtime = _runtime;
    if (media == null || runtime == null) return null;
    return pickStageVideo(
      screenShares: _screenShareDeviceIds(),
      cameras: _cameraDeviceIds(),
      speaking: _speakingDeviceIds(),
      lastSpeaker: _lastSpeaker,
    );
  }

  /// ◆ РЕЖИМ СЕТКИ: все камеры разом вместо одной большой.
  ///
  /// Одна сцена отвечает на вопрос «кто сейчас говорит». Сетка — на другой:
  /// «как они все выглядят». В разговоре вчетвером второй вопрос важнее, и без
  /// сетки трое из четверых видны были только плитками в ленте сбоку.
  ///
  /// Переключатель в доке, и его НЕТ, когда переключать нечего: на одного
  /// человека с камерой сетка из одной плитки — это та же сцена, только меньше.
  bool _gridMode = false;

  Widget _stageBody(DColorSet c, StagePick? pick) {
    final media = _media;
    final runtime = _runtime;
    final participants = _joined;

    if (_gridMode && media != null && runtime != null) {
      // Сетка показывает лица; показ экрана в неё не попадает — он крупный по
      // своей природе, и плитка 16/10 из него делает нечитаемый прямоугольник.
      _syncStatsTimer(null);
      return _StageGrid(
        tiles: [
          for (final p in participants.take(_kStageFacesMax))
            (
              name: _nameFor(p.profileId),
              avatarPath: _avatarFor(p.profileId),
              muted: p.muted,
              speaking: media.isParticipantSpeaking(p.deviceId),
              video: (_runtimeFor(p.deviceId)?.publishVideo ?? false) &&
                      media.hasParticipantCameraView(p.deviceId)
                  ? media.buildParticipantVideoView(
                      deviceId: p.deviceId,
                      mirror: _runtimeFor(p.deviceId)?.isSelf ?? false,
                      kind: RoomCallVideoKind.camera,
                    )
                  : null,
            ),
        ],
        overflow: participants.length > _kStageFacesMax
            ? participants.length - _kStageFacesMax
            : 0,
      );
    }

    if (media != null && runtime != null) {
      // Весь порядок выбора — в одной [pickStageVideo], чтобы его можно было
      // проверить тестом без камер, комнаты и второго человека.
      if (pick != null) {
        RoomCallParticipantRuntimeState? found;
        for (final p in runtime.participants) {
          if (p.deviceId == pick.deviceId) {
            found = p;
            break;
          }
        }
        if (found != null) {
          final view = media.buildParticipantVideoView(
            deviceId: pick.deviceId,
            // Зеркалим только СВОЮ камеру, и только её: демонстрация экрана
            // зеркальной быть не должна ни у кого.
            mirror: found.isSelf && !pick.screenShare,
            // Просим ИМЕННО то, что выбрали. Раньше вид был один на участника
            // и экран всегда побеждал камеру: сцена не могла показать лицо
            // того, кто параллельно показывает экран.
            kind: pick.screenShare
                ? RoomCallVideoKind.screenShare
                : RoomCallVideoKind.camera,
          );
          if (view != null) {
            // Показатели меряем только у ЧУЖОГО показа: у своего дорожка
            // исходящая, и «сколько дошло» к ней неприменимо.
            _syncStatsTimer(
              pick.screenShare && !found.isSelf ? pick.deviceId : null,
            );
            return _StageFrame(
              label: pick.screenShare
                  ? _l10n.desktopCallSharingScreen(_nameFor(found.profileId))
                  : _nameFor(found.profileId),
              stats: pick.screenShare && !found.isSelf ? _stageStats : null,
              icon: pick.screenShare
                  ? FluentIcons.share_screen_start_24_filled
                  : FluentIcons.video_24_filled,
              // Чип разворота — только над ЧУЖИМ экраном: см. [_StageFrame].
              // Свой собственный показ увеличивать незачем, его и так видно
              // на своём мониторе.
              onExpand: pick.screenShare && !found.isSelf
                  ? _toggleFullScreen
                  : null,
              expanded: _fullScreen,
              child: view,
            );
          }
        }
      }
    }

    // Никто не показывает картинку — сетка портретов. Это честнее пустого
    // чёрного прямоугольника: видно, кто в созвоне, даже когда смотреть не на
    // что.
    return Container(
      // Та же оболочка, что у сцены с видео: скругление и рамка. Иначе при
      // отсутствии картинки скругление пропадало, и окно «дёргалось» формой
      // каждый раз, когда кто-нибудь включал камеру.
      decoration: BoxDecoration(
        color: c.thread,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: c.success.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(DSpace.xl2),
      child: Wrap(
        spacing: DSpace.xl,
        runSpacing: DSpace.xl,
        alignment: WrapAlignment.center,
        children: [
          // 🔴 ПРЕДЕЛ ОБЯЗАТЕЛЕН. Сетка была без ограничения: на двенадцати
          // участниках портреты по 88 точек просто не помещались в сцену, и
          // ряд уезжал за край окна — тем вернее, чем крупнее созвон, то есть
          // ровно тогда, когда посмотреть, кто внутри, нужнее всего.
          for (final p in participants.take(_kStageFacesMax))
            _StageAvatar(
              name: _nameFor(p.profileId),
              avatarPath: _avatarFor(p.profileId),
              muted: p.muted,
              speaking: _media?.isParticipantSpeaking(p.deviceId) ?? false,
            ),
          if (participants.length > _kStageFacesMax)
            _StageOverflow(count: participants.length - _kStageFacesMax),
        ],
      ),
    );
  }

  /// Сколько лиц показывать на сцене, когда видео ни у кого нет. Девять —
  /// три ряда по три: столько помещается, не уезжая за край.
  static const int _kStageFacesMax = 9;

  /// Идёт получение ссылки-приглашения: кнопка не должна плодить ссылки от
  /// двойного нажатия.
  bool _inviting = false;

  /// Лента плиток справа от сцены.
  ///
  /// 🔴 ЗАЧЕМ ОНА, ЕСЛИ СПРАВА УЖЕ ЕСТЬ СПИСОК УЧАСТНИКОВ.
  ///
  /// Список отвечает на вопрос «кто в созвоне» строками текста. Лента
  /// отвечает на другой: «как они сейчас выглядят». Разница видна ровно тогда,
  /// когда кто-то показывает экран: сцену занимает экран, и до ленты в окне не
  /// было ни одного лица — при том что разговор идёт между людьми.
  ///
  /// 🔴 ЧЕЙ КАДР УЖЕ НА СЦЕНЕ — В ПЛИТКЕ НЕ ПОВТОРЯЕТСЯ.
  ///
  /// Раньше у этого была ещё и техническая причина:
  /// `buildParticipantVideoView` отдавал ОДИН вид на участника и всегда
  /// предпочитал демонстрацию камере, так что плитка показывающего экран
  /// показала бы второй раз тот же экран.
  ///
  /// С 15.09.2026 причины больше нет — вид спрашивается явно (`kind`), и
  /// плитка просит КАМЕРУ. Теперь один человек может одновременно занимать
  /// сцену демонстрацией и держать в ленте своё лицо, как просит макет. А
  /// правило «на сцене — не повторяем» осталось: оно про повтор ОДНОГО И ТОГО
  /// ЖЕ кадра, и работает теперь по виду, а не по участнику.
  /// Камеры, из которых можно выбирать. Пусто — движок их не перечисляет или
  /// камера в системе одна.
  ///
  /// 🔴 СПИСОК СПРАШИВАЕТСЯ ОДИН РАЗ, А НЕ КАЖДУЮ ОТРИСОВКУ: перечисление
  /// устройств — обращение к системе, и звать его из `build` значит дёргать
  /// её шестьдесят раз в секунду.
  List<RoomCallVideoDevice> _cameras = const <RoomCallVideoDevice>[];

  /// Показатели дорожки, которая сейчас на сцене. `null` — мерить нечем.
  ///
  /// 🔴 Чип качества из макета не рисовался вовсе, потому что чисел неоткуда
  /// было взять, а выдуманное число хуже отсутствующего: по нему судят, стоит
  /// ли просить показывающего сменить окно. Теперь числа настоящие — движок
  /// отдаёт их по принимаемой дорожке.
  RoomCallVideoStats? _stageStats;
  Timer? _statsTimer;
  String _statsDeviceId = '';

  /// Опрашиваем раз в две секунды и ТОЛЬКО пока на сцене чужой показ:
  /// статистика — обращение к движку, и чаще она не нужна (число на чипе
  /// меняется медленнее).
  void _syncStatsTimer(String? deviceId) {
    final want = (deviceId ?? '').trim();
    if (want == _statsDeviceId) return;
    _statsDeviceId = want;
    _statsTimer?.cancel();
    _statsTimer = null;
    if (want.isEmpty) {
      if (_stageStats != null && mounted) setState(() => _stageStats = null);
      return;
    }
    unawaited(_pollStats());
    _statsTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollStats()),
    );
  }

  Future<void> _pollStats() async {
    final media = _media;
    final device = _statsDeviceId;
    if (media == null || device.isEmpty) return;
    final next = await media.videoStats(
      deviceId: device,
      kind: RoomCallVideoKind.screenShare,
    );
    if (!mounted || device != _statsDeviceId) return;
    if (next?.width == _stageStats?.width &&
        next?.height == _stageStats?.height &&
        next?.fps?.round() == _stageStats?.fps?.round()) {
      return;
    }
    setState(() => _stageStats = next);
  }

  /// Применён ли выбор из настроек к ЭТОЙ сессии. Один раз: дальше человек
  /// может поменять камеру прямо в доке, и настройка не должна отматывать его
  /// выбор назад на каждом тике.
  bool _preferredDevicesApplied = false;

  /// 🔴 ВЫБОР ИЗ НАСТРОЕК ПРИМЕНЯЕТСЯ К ЖИВОМУ ЗВОНКУ.
  ///
  /// Иначе раздел «Звук и видео» был бы списком без последствий: человек
  /// выбрал гарнитуру, начал звонок — и говорит во встроенный микрофон.
  ///
  /// Пропавшее устройство молча откатывается к системному: движок не найдёт
  /// его в списке и ничего не переключит, а звонок не уйдёт в тишину.
  Future<void> _applyPreferredDevices() async {
    if (_preferredDevicesApplied) return;
    final media = _media;
    if (media == null || !_mediaBackendReady) return;
    _preferredDevicesApplied = true;
    final cam = DesktopUiPrefs.preferredCameraId.value;
    if (cam.isNotEmpty) await media.selectVideoInput(cam);
    final mic = DesktopUiPrefs.preferredMicId.value;
    if (mic.isNotEmpty) await media.selectAudioInput(mic);
  }

  Future<void> _refreshCameras() async {
    final media = _media;
    if (media == null) return;
    unawaited(_applyPreferredDevices());
    final next = await media.videoInputs();
    if (!mounted) return;
    if (next.length == _cameras.length &&
        List.generate(next.length, (i) => i).every(
          (i) => next[i].deviceId == _cameras[i].deviceId,
        )) {
      return;
    }
    setState(() => _cameras = next);
  }

  /// Список камер — по шеврону у «Камеры».
  Future<void> _pickCamera(BuildContext anchorContext) async {
    final media = _media;
    if (media == null || _cameras.length < 2) return;
    final selected = media.selectedVideoInputId;
    await ContextMenu.show(
      anchorContext,
      globalPosition: callMenuAnchorAbove(anchorContext, _cameras.length),
      sections: <List<CtxMenuItem>>[
        [
          for (final cam in _cameras)
            CtxMenuItem(
              label: cam.label,
              icon: cam.deviceId == selected
                  ? FluentIcons.checkmark_24_regular
                  : FluentIcons.video_24_regular,
              onTap: () => unawaited(
                _run(
                  'camera',
                  () async => media.selectVideoInput(cam.deviceId),
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// Доступные устройства вывода звука. Пусто — движок их ещё не собрал.
  List<CallAudioRouteOption> _audioRoutes() =>
      RoomCallManager.instance?.audioRouteState.value.availableRoutes ??
      const <CallAudioRouteOption>[];

  /// Список устройств вывода — по шеврону у «Микрофона».
  Future<void> _pickAudioRoute(BuildContext anchorContext) async {
    final manager = RoomCallManager.instance;
    if (manager == null) return;
    final routes = _audioRoutes();
    if (routes.length < 2) return;
    final selected = manager.audioRouteState.value.selectedRouteId;
    await ContextMenu.show(
      anchorContext,
      globalPosition: callMenuAnchorAbove(anchorContext, routes.length),
      sections: <List<CtxMenuItem>>[
        [
          for (final r in routes)
            CtxMenuItem(
              label: r.label,
              icon: r.deviceId == selected
                  ? FluentIcons.checkmark_24_regular
                  : callAudioRouteIcon(r.kind),
              onTap: () => unawaited(manager.selectAudioRoute(r.deviceId)),
            ),
        ],
      ],
    );
  }

  Widget _participantStrip(DColorSet c) {
    final pick = _currentStagePick();
    final media = _media;
    final tiles = <Widget>[];
    // 🔴 СВОЯ ПЛИТКА — ПЕРВОЙ, и это не вежливость к себе.
    //
    // Она отвечает на вопрос, который в созвоне задают чаще всего: «я в
    // кадре?». Стоя в общем порядке, в созвоне на восьмерых она уезжала бы
    // под нижний край ленты — то есть ровно тогда, когда проверить себя
    // тревожнее всего.
    final ordered = [
      ..._joined.where((p) => _runtimeFor(p.deviceId)?.isSelf ?? false),
      ..._joined.where((p) => !(_runtimeFor(p.deviceId)?.isSelf ?? false)),
    ];
    for (final p in ordered) {
      final runtime = _runtimeFor(p.deviceId);
      final onStage = pick != null && pick.deviceId == p.deviceId;
      final hasCamera =
          runtime != null &&
          runtime.publishVideo &&
          (media?.hasParticipantCameraView(p.deviceId) ?? false);
      // На сцене идёт ЭКРАН — значит лицо этого человека в ленте не повтор, а
      // второй его вид, и показать его можно. Повтором было бы лицо, когда на
      // сцене тоже лицо.
      final faceOnStage = onStage && !pick.screenShare;
      final view = (!faceOnStage && hasCamera && media != null)
          ? media.buildParticipantVideoView(
              deviceId: p.deviceId,
              mirror: runtime.isSelf,
              // Плитка — всегда ЛИЦО. Экран у неё показывать нечем: он на
              // сцене и во много раз больше.
              kind: RoomCallVideoKind.camera,
            )
          : null;
      tiles.add(
        _ParticipantTile(
          name: _nameFor(p.profileId),
          avatarPath: _avatarFor(p.profileId),
          muted: p.muted,
          speaking: media?.isParticipantSpeaking(p.deviceId) ?? false,
          onStage: onStage,
          video: view,
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => tiles[i],
    );
  }

  // ── ЧАТ СОЗВОНА ──────────────────────────────────────────────────────────
  //
  // 🔴 Это НЕ новый протокол и не отдельная переписка. Созвон идёт в комнате,
  // и чат здесь — та же самая переписка комнаты: те же сообщения, тот же путь
  // отправки (`sendGroupMessage`). Завести «чат созвона» отдельной сущностью
  // значило бы создать переписку, которой после звонка нигде нет.
  //
  // Показывается ХВОСТ ленты, а не вся история: во время разговора нужно
  // последнее, а полную переписку человек и так откроет в главном окне.

  int _panelTab = 0;

  /// Последние сообщения комнаты.
  List<_CallChatLine> _chatTail = const [];
  bool _chatLoading = true;
  final TextEditingController _chatInput = TextEditingController();
  bool _chatSending = false;
  String? _chatError;

  /// Сколько последних сообщений показывать в панели созвона.
  static const int _kChatTail = 30;

  Future<void> _loadChatTail() async {
    try {
      final events = await widget.controller.loadEvents(
        widget.groupId,
        limit: _kChatTail,
      );
      final out = <_CallChatLine>[];
      for (final e in events) {
        String text;
        try {
          text = await widget.controller.decryptPlainAsync(e);
        } catch (_) {
          continue; // одна нечитаемая строка не уносит весь хвост
        }
        if (text.trim().isEmpty) continue;
        var mine = false;
        String? pid;
        try {
          mine = widget.controller.isOwnDeviceId(e.senderDeviceId);
          if (!mine) {
            pid = await widget.controller.cachedProfileIdByDeviceId(
              e.senderDeviceId,
            );
          }
        } catch (_) {}
        out.add(
          _CallChatLine(
            author: mine ? _l10n.desktopSupportYou : _nameFor(pid ?? ''),
            avatarPath: mine ? null : _avatarFor(pid ?? ''),
            text: text.trim(),
            mine: mine,
            timestampMs: e.createdAtMs,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _chatTail = List.unmodifiable(out);
        _chatLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chatLoading = false);
    }
  }

  Future<void> _sendChat() async {
    final text = _chatInput.text.trim();
    if (text.isEmpty || _chatSending) return;
    setState(() {
      _chatSending = true;
      _chatError = null;
    });
    try {
      await widget.controller.sendGroupMessage(
        groupId: widget.groupId,
        text: text,
      );
      _chatInput.clear();
      await _loadChatTail();
    } catch (e) {
      // 🔴 Отказ говорится словами. В комнате «писать могут только админы»
      // отправка падает молча, и человек во время созвона решит, что
      // сломалось приложение.
      if (mounted) setState(() => _chatError = _stripDartPrefix(e));
    } finally {
      if (mounted) setState(() => _chatSending = false);
    }
  }

  Widget _callChat(DColorSet c) {
    if (_chatLoading) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(c.accentPrimary),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _chatTail.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DSpace.l),
                    child: Text(
                      _l10n.desktopCallRoomEmpty,
                      textAlign: TextAlign.center,
                      style: DType.caption.copyWith(color: c.textSecondary),
                    ),
                  ),
                )
              // Лента перевёрнута: свежее внизу, у поля ввода, как в любой
              // переписке. `loadEvents` отдаёт новейшие первыми, поэтому
              // порядок совпадает без сортировки.
              // 🔴 ПЕРЕДЕЛАНО ПО ЗАМЕЧАНИЮ ВЛАДЕЛЬЦА: «выглядит убого, ничего
              // не понятно» (14.09.2026).
              //
              // Было: стена одинаковых мелких строк «Вы / текст» — без
              // времени, без лиц, без единого разделения. В узкой панели это
              // читалось как список слов, а не как разговор.
              //
              // Стало то же, что в любой переписке: реплика своя — справа
              // плёнкой акцента, чужая — слева с лицом и именем. Имя и лицо
              // НЕ повторяются у подряд идущих реплик одного человека:
              // повтор каждой строки и делал из панели кашу. Время — у
              // последней реплики в связке.
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(
                    DSpace.m,
                    DSpace.s,
                    DSpace.m,
                    DSpace.m,
                  ),
                  itemCount: _chatTail.length,
                  itemBuilder: (ctx, i) {
                    final m = _chatTail[i];
                    // Лента перевёрнута: i+1 — это реплика ВЫШЕ, i-1 — ниже.
                    final above = i + 1 < _chatTail.length
                        ? _chatTail[i + 1]
                        : null;
                    final below = i > 0 ? _chatTail[i - 1] : null;
                    final startsGroup =
                        above == null ||
                        above.author != m.author ||
                        above.mine != m.mine;
                    final endsGroup =
                        below == null ||
                        below.author != m.author ||
                        below.mine != m.mine;
                    return _CallChatBubble(
                      line: m,
                      showAuthor: startsGroup,
                      showTime: endsGroup,
                      gapAbove: startsGroup ? 10.0 : 2.0,
                    );
                  },
                ),
        ),
        if (_chatError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(DSpace.m, 0, DSpace.m, DSpace.s),
            child: Text(
              _chatError!,
              style: DType.tiny.copyWith(color: c.danger),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DSpace.s,
            0,
            DSpace.s,
            DSpace.m,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInput,
                  enabled: !_chatSending,
                  style: DType.caption.copyWith(color: c.textPrimary),
                  cursorColor: c.accentPrimary,
                  onSubmitted: (_) => unawaited(_sendChat()),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    hintText: _l10n.desktopCallMessageHint,
                    hintStyle: DType.caption.copyWith(color: c.textDisabled),
                    filled: true,
                    fillColor: c.elevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DRadii.r11),
                      borderSide: BorderSide(color: c.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DRadii.r11),
                      borderSide: BorderSide(color: c.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DRadii.r11),
                      borderSide: BorderSide(color: c.accentPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              DesktopTooltip(
                message: _l10n.desktopCallSendToRoom,
                child: HoverListener(
                  onTap: _chatSending ? null : () => unawaited(_sendChat()),
                  cursor: _chatSending
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  builder: (ctx, hovered, pressed) => Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentPrimary.withValues(
                        alpha: _chatSending ? 0.4 : (hovered ? 1 : 0.85),
                      ),
                      borderRadius: BorderRadius.circular(DRadii.r11),
                    ),
                    child: const Icon(
                      FluentIcons.send_24_filled,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _participantsPanel(DColorSet c) {
    final participants = _joined;
    return Container(
      // Фон рейки, а не списка: у списка он почти совпадает с фоном сцены, и
      // граница между ними не читалась вовсе.
      color: c.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🔴 ВКЛАДКИ, ПОТОМУ ЧТО ПИСАТЬ ВО ВРЕМЯ СОЗВОНА БЫЛО НЕЧЕМ.
          //
          // Окно созвона лежит ПОВЕРХ приложения: переписка комнаты, пока оно
          // открыто, не видна. Скинуть ссылку или адрес, о котором только что
          // договорились, можно было только свернув созвон — то есть выйдя
          // из разговора глазами ровно в тот момент, когда он идёт.
          //
          // Полоса вкладок — та же [DetailsTabs], что в панели подробностей:
          // одна и та же форма на два места окна, а не вторая своя.
          // ◆ ТРЕТЬЯ ВКЛАДКА — «ЗАМЕТКИ» (макет). То, что остаётся ПОСЛЕ
          // разговора: адрес, цифра, «сделать к четвергу».
          //
          // Она личная и никуда не едет, и сказано об этом прямо под полем —
          // вкладка в окне общего разговора обязана объяснить, что она не
          // общая. Та же панель стоит в «Инфо» правой панели комнаты: заметка,
          // видная только пока идёт звонок, бесполезна ровно тогда, когда за
          // ней приходят.
          DetailsTabs(
            tabs: [
              _l10n.desktopCallParticipantsTab(participants.length),
              _l10n.contactDetailsChat,
              _l10n.desktopCallNotesTab,
            ],
            index: _panelTab,
            onChanged: (i) => setState(() => _panelTab = i),
          ),
          if (_panelTab == 2)
            Expanded(
              child: RoomNotesPane(
                convoId: widget.groupId,
                load: widget.vm.localConvoNote,
                save: widget.vm.setLocalConvoNote,
              ),
            )
          else if (_panelTab == 1)
            Expanded(child: _callChat(c))
          else ...[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: DSpace.s),
              itemCount: participants.length,
              itemBuilder: (ctx, i) {
                final p = participants[i];
                return _ParticipantRow(
                  name: _nameFor(p.profileId),
                  avatarPath: _avatarFor(p.profileId),
                  muted: p.muted,
                  video: _videoLive(p),
                  sharing: _shareLive(p),
                  reconnecting: p.isReconnecting,
                  speaking: _media?.isParticipantSpeaking(p.deviceId) ?? false,
                  deafened: p.deafened,
                  level: _media?.participantAudioLevel(p.deviceId) ?? 0,
                );
              },
            ),
          ),
          // 🔴 «ПРИГЛАСИТЬ» ИМЕННО ЗДЕСЬ. Механизм в приложении был, а точки
          // входа из созвона — нет: чтобы позвать ещё кого-нибудь, надо было
          // свернуть созвон, открыть комнату, найти панель подробностей и уже
          // там нажать «Пригласить». Между тем зовут как раз во время
          // разговора — «подключайся, мы уже начали».
          //
          // Пунктиром, а не заливкой: это не действие созвона, а добавление
          // в список рядом, и весить оно должно меньше кнопок дока.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DSpace.s,
              DSpace.s,
              DSpace.s,
              DSpace.m,
            ),
            child: _InviteButton(
              busy: _inviting,
              onTap: () => unawaited(_invite()),
            ),
          ),
          ],
        ],
      ),
    );
  }

  /// Скопировать ссылку-приглашение в буфер.
  ///
  /// Последовательность — общая [copyRoomInviteLink], та же, что у панели
  /// подробностей комнаты: сперва годная ссылка, потом новая, и новая
  /// наследует «вступление по подтверждению».
  Future<void> _invite() async {
    if (_inviting) return;
    setState(() => _inviting = true);
    try {
      final settings = await widget.controller.getRoomSettings(widget.groupId);
      final links = await widget.controller.listRoomInviteLinks(widget.groupId);
      final result = await copyRoomInviteLink(
        controller: widget.controller,
        groupId: widget.groupId,
        requiresApproval: settings.joinApprovalRequired,
        known: links,
      );
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: result.ok
            ? _l10n.desktopCallLinkCopied
            : (result.error ?? _l10n.desktopCallFailed),
        kind: result.ok ? DSnackKind.success : DSnackKind.error,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: _l10n.desktopCallFailedWith('$e'),
        kind: DSnackKind.error,
      );
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Widget _controls(DColorSet c) {
    final self = _call?.selfParticipant;
    final busy = _busy != null;
    // 🔴 Кнопки показывают ТО, ЧТО ИДЁТ, а не то, что мы просили.
    //
    // Флаг снимка это намерение, отправленное релею; кнопка же отвечает
    // человеку на вопрос «включена ли у меня сейчас камера». Когда эти два
    // расходятся — а 13.09 они разошлись, — верить надо дорожке.
    final videoOn = self != null && _videoLive(self);
    final shareOn = self != null && _shareLive(self);
    final muted = self?.muted ?? false;
    // 🔴 ДОК — КАРТОЧКА С ПОДПИСЯМИ, А НЕ ПОЛОСА КРУЖКОВ.
    //
    // Было: полоса во всю ширину с четырьмя одинаковыми кружками по 46 точек и
    // без единого слова. Понять, что перечёркнутый прямоугольник — это
    // «показать экран», а не «выключить видео», можно было только наведя
    // мышь и дождавшись подсказки; а во время созвона ищут глазами и быстро.
    //
    // В макете это отдельная карточка, приподнятая над сценой, и у трёх
    // главных переключателей есть ПОДПИСИ. «Выйти» отделён чертой: это
    // единственная кнопка, которая заканчивает разговор, и стоять вплотную к
    // «выключить микрофон» ей нельзя.
    final dock = CallDock(
      expand: true,
      children: [
          CallDockToggle(
            icon: muted
                ? FluentIcons.mic_off_24_filled
                : FluentIcons.mic_24_filled,
            label: _l10n.callControlMute,
            tooltip: callTooltipWithShortcut(
              muted ? _l10n.desktopCallMicOn : _l10n.desktopCallMicOff,
              'D',
            ),
            on: !muted,
            enabled: !busy,
            onTap: () => unawaited(_updateSelf(muted: !muted)),
            // 🔴 ВЫБОР УСТРОЙСТВА — ИЗ ТОГО ЖЕ ДВИЖКА, ЧТО НА ТЕЛЕФОНЕ.
            //
            // На компьютере устройств вывода почти всегда больше одного:
            // гарнитура, колонки, монитор. Поменять их можно было только
            // системными настройками — то есть уйдя из созвона глазами и
            // руками. Список берётся из `audioRouteState`, который уже
            // публикует движок; ничего нового для этого не заводится.
            //
            // Шеврона НЕТ, когда выбирать не из чего: стрелка, за которой
            // один пункт, обещает выбор, которого нет.
            onExpand: _audioRoutes().length > 1 ? _pickAudioRoute : null,
          ),
          const SizedBox(width: 8),
          CallDockToggle(
            icon: videoOn
                ? FluentIcons.video_24_filled
                : FluentIcons.video_off_24_filled,
            label: _l10n.callControlCamera,
            tooltip: _mediaBackendReady
                ? callTooltipWithShortcut(
                    videoOn ? _l10n.desktopCallCamOff : _l10n.desktopCallCamOn,
                    'E',
                  )
                : _l10n.desktopCallNoMediaVideo,
            on: videoOn,
            enabled: !busy && _mediaBackendReady,
            onTap: () => unawaited(_updateSelf(videoEnabled: !videoOn)),
            // Тот же приём, что у звука: шеврона НЕТ, когда выбирать не из
            // чего. На ноутбуке с одной камерой стрелка обещала бы выбор,
            // которого нет.
            onExpand: _cameras.length > 1 ? _pickCamera : null,
          ),
          const SizedBox(width: 8),
          // ◆ Переключатель сетки. Его НЕТ, когда переключать нечего: на
          // одного человека с камерой сетка из одной плитки — это та же
          // сцена, только меньше.
          if (_joined.length > 1) ...[
            CallDockToggle(
              icon: _gridMode
                  ? FluentIcons.person_24_filled
                  : FluentIcons.grid_24_filled,
              label: _gridMode ? _l10n.desktopCallLayoutSingle : _l10n.desktopCallLayoutGrid,
              tooltip: _gridMode
                  ? _l10n.desktopCallShowOneLarge
                  : _l10n.desktopCallShowGrid,
              on: _gridMode,
              // Одна большая сцена — не сбой: без этого «Сетка» стояла
              // красной, пока ею не пользуются.
              neutralWhenOff: true,
              enabled: !busy,
              onTap: () => setState(() => _gridMode = !_gridMode),
            ),
            const SizedBox(width: 8),
          ],
          CallDockToggle(
            icon: FluentIcons.share_screen_start_24_filled,
            label: _l10n.desktopCallScreen,
            tooltip: _mediaBackendReady
                ? (shareOn ? _l10n.desktopCallShareStop : _l10n.desktopCallShareStart)
                : _l10n.desktopCallNoMediaScreen,
            on: shareOn,
            // 🔴 Экран, который сейчас НЕ показывают, — обычное состояние, а
            // не тревога: кнопка стояла красной весь созвон. Идущий показ,
            // наоборот, подсвечен — его видят все, и об этом надо помнить.
            neutralWhenOff: true,
            highlighted: shareOn,
            enabled: !busy && _mediaBackendReady,
            onTap: () => unawaited(_updateSelf(screenShareEnabled: !shareOn)),
          ),
          const SizedBox(width: 8),
          // 🔴 СВЕРНУТЬ — В ДОКЕ, А НЕ ТОЛЬКО СТРЕЛКОЙ В УГЛУ (24.09.2026,
          // владелец: созвон «должен не мешать пользоваться другими чатами»).
          // Стрелка в шапке была единственным входом и не читалась как
          // «свернуть», а после неё от созвона оставалась одна строка.
          // Теперь созвон уходит в мини-окно с живой картинкой.
          CallDockToggle(
            icon: FluentIcons.picture_in_picture_enter_24_regular,
            label: _l10n.callMinimize,
            tooltip: callTooltipWithShortcut(
              _l10n.desktopCallMinimiseHint,
              'Esc',
            ),
            on: true,
            enabled: true,
            onTap: _minimize,
          ),
          const CallDockDivider(),
          CallDockToggle(
            icon: FluentIcons.call_end_24_filled,
            label: _l10n.desktopCallLeave,
            tooltip: callTooltipWithShortcut(_l10n.desktopCallLeaveCall, 'W'),
            on: false,
            danger: true,
            // 🔴 ВСЕГДА ДОСТУПЕН, даже когда идёт другое действие. Зависший
            // запрос по камере гасил и эту кнопку — человек оставался в
            // созвоне, из которого нечем выйти. См. [_run].
            enabled: true,
            onTap: () => unawaited(_leave()),
          ),
      ],
    );

    // 🔴 Сказать словами ровно один раз и над доком, а не подсказкой у каждой
    // погасшей кнопки: человек должен понять, что сломано не приложение.
    // Отказ последнего действия (микрофон, камера, выход) важнее сбоя
    // движка: он про то, что человек только что нажал.
    final notice = !_mediaBackendReady
        ? _l10n.desktopCallNoMediaBoth
        : (_actionError ?? _mediaProblem());
    if (notice == null) return dock;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: c.warning.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(DRadii.r11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.warning_24_filled,
                size: 15,
                color: c.warning,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  notice,
                  style: DType.tiny.copyWith(color: c.warning),
                ),
              ),
            ],
          ),
        ),
        dock,
      ],
    );
  }

  /// Что сломалось у своих камеры, микрофона или показа экрана — словами.
  ///
  /// 🔴 ОТКАЗЫ ДВИЖКА ПРОВАЛИВАЛИСЬ МОЛЧА. Камеру держит другое приложение,
  /// нет разрешения на запись экрана — движок пишет это в своё состояние, и
  /// телефон это показывает. Окно компьютера не читало его вовсе: кнопка
  /// нажималась, а камера так и не включалась, без единого слова почему.
  String? _mediaProblem() {
    final raw = _runtime?.localMedia.errorMessage?.trim() ?? '';
    if (raw.isEmpty) return null;
    switch (raw) {
      case 'camera unavailable':
        return _l10n.desktopCallMediaCameraUnavailable;
      case 'microphone unavailable':
        return _l10n.desktopCallMediaMicUnavailable;
      case 'screen share permission denied':
      case 'screen share unavailable':
        return (!kIsWeb && Platform.isMacOS)
            ? _l10n.desktopCallScreenShareFailedMac
            : _l10n.desktopCallScreenShareFailed;
      case 'screen share stopped':
        return _l10n.desktopCallMediaScreenStopped;
    }
    return _l10n.desktopCallMediaProblem(_stripDartPrefix(raw));
  }
}

/// Шапка окна созвона.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.call,
    required this.joinedCount,
    required this.fullScreen,
    required this.anyoneSpeaking,
    required this.onBack,
    required this.onToggleFullScreen,
  });

  final String title;
  final CachedRoomCall? call;
  final int joinedCount;
  final bool fullScreen;

  /// Говорит ли СЕЙЧАС хоть кто-нибудь. Только по этому признаку эквалайзер в
  /// чипе и оживает — см. [_Equalizer].
  final bool anyoneSpeaking;

  final VoidCallback onBack;
  final VoidCallback onToggleFullScreen;

  static String _duration(int startedAtMs) {
    var total = (DateTime.now().millisecondsSinceEpoch - startedAtMs) ~/ 1000;
    if (total < 0) total = 0;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    // 🔴 Слева резервируется место под «светофор» macOS.
    //
    // Окно созвона открывается маршрутом поверх оболочки и своей рамки не
    // имеет: системные кнопки закрытия ложатся прямо на эту шапку. Без отступа
    // кнопка «свернуть созвон» оказывалась ПОД ними — то есть нажать на неё
    // было нельзя, а выглядело это как неработающая кнопка.
    final isMacOS = !kIsWeb && Platform.isMacOS;
    // 🔴 КНОПКИ ОКНА WINDOWS — ЗДЕСЬ (24.09.2026). Окно созвона ложится
    // поверх шапки приложения целиком, а на Windows «свернуть, развернуть,
    // закрыть» рисуем мы сами, в той шапке: пока шёл созвон, окно нельзя было
    // ни свернуть, ни закрыть, ни даже сдвинуть.
    final isWindows = !kIsWeb && Platform.isWindows;
    return Container(
      // 46 и поля 14 — из макета. Было 52: лишние шесть точек у окна, где
      // ценность имеет площадь сцены.
      height: 46,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: DesktopWindowDragRegion()),
          Row(
            children: [
              Expanded(
                child: Padding(
      padding: EdgeInsets.fromLTRB(isMacOS ? 78 : 14, 0, 14, 0),
      child: Row(
        children: [
          _ChromeButton(
            icon: FluentIcons.picture_in_picture_enter_24_regular,
            tooltip: callTooltipWithShortcut(l10n.desktopCallMinimiseHint, 'Esc'),
            onTap: onBack,
          ),
          const SizedBox(width: DSpace.s),
          // Эквалайзер вместо говорящей головы — как в макете.
          Icon(FluentIcons.pulse_24_filled, size: 18, color: c.success),
          const SizedBox(width: 6),
          // 🔴 Имя и чип — ОДНОЙ растягиваемой частью строки: с `Flexible` у
          // имени и распоркой после чипа свободное место делилось пополам, и
          // кнопка «во весь экран» стояла посреди шапки.
          Expanded(
            child: Row(
              children: [
          Flexible(
            child: Text(
              // Имя комнаты бывает неизвестно — например, когда вернулись в
              // созвон полосой сразу после перезапуска, и склад выбора ещё
              // пуст. Тогда «Обсуждение» без хвоста честнее, чем
              // «Обсуждение · Созвон».
              title.trim().isEmpty ? l10n.desktopCallDiscussion : l10n.desktopCallDiscussionOf(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DType.label.copyWith(
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: DSpace.m),
          if (call != null)
            // 🔴 ЗАМОК ИЗ ЧИПА НЕ ВЫБРОШЕН, А ПЕРЕЕХАЛ В ПОДСКАЗКУ. Признак
            // шифрования полезен, но в макете чип занят другим, и держать
            // замок рядом с таймером значило бы отдать ему место эквалайзера.
            // 🔴 26.09.2026: групповой созвон идёт через LiveKit БЕЗ сквозного
            // шифрования — сервер видит звук и видео. Поэтому здесь не
            // `desktopCallEncrypted` (он для 1:1), а честное «шифруется при
            // передаче». Вернуть «сквозное» — только вместе с E2EE созвонов
            // (docs/TZ_GRANT_READINESS_V2_2026-09-26.md, часть ЗВ).
            DesktopTooltip(
              message: l10n.desktopRoomCallTransportEncrypted,
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  // rgba(34,197,94,.14) из макета — это «голос», а не мята.
                  color: c.voice.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(DRadii.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Equalizer(speaking: anyoneSpeaking),
                    const SizedBox(width: 7),
                    Text(
                      // 🔴 Задержки здесь нет, хотя в макете она есть: снимок
                      // созвона времени отклика не несёт, а правдоподобное
                      // число ниоткуда — худшее, что можно показать в окне,
                      // где человек решает, слышно его или нет.
                      //
                      // «N в эфире» оставлено сверх макета: в комнате это
                      // первый вопрос, а место в чипе есть.
                      l10n.desktopCallDurationOnAir(_duration(call!.startedAtMs), joinedCount),
                      // Цифры таймера не должны дёргать строку каждую
                      // секунду — но не моноширинным шрифтом (24.09.2026,
                      // владелец о таком же таймере мини-плеера: «убери этот
                      // ужасный шрифт, сделай обычный, как в Telegram»).
                      // Обычный шрифт окна с цифрами одной ширины.
                      style: TextStyle(
                        fontFamily: DType.family,
                        fontSize: 10.5,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                        color: c.mintSoft,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ],
            ),
          ),
          const SizedBox(width: DSpace.m),
          _ChromeButton(
            icon: fullScreen
                ? FluentIcons.full_screen_minimize_24_regular
                : FluentIcons.full_screen_maximize_24_regular,
            tooltip: fullScreen
                ? l10n.desktopCallExitFullScreen
                : l10n.desktopCallFullScreen,
            onTap: onToggleFullScreen,
          ),
        ],
      ),
                ),
              ),
              if (isWindows) const DesktopWindowsCaptionButtons(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Три полоски эквалайзера в чипе созвона: 2 точки шириной, высоты 4/6/9.
///
/// 🔴 НЕ АНИМИРОВАН, И ЭТО РЕШЕНИЕ, А НЕ ЭКОНОМИЯ. В макете это картинка;
/// «оживить» её просто, но уровня звука в состоянии НЕТ — есть только
/// двухпозиционный признак «кто-то говорит». Полоски, пляшущие по таймеру,
/// изображали бы громкость, которой никто не измерял, — то есть врали бы ровно
/// в том окне, где человек решает, слышно его или нет.
///
/// Поэтому признак честный и один: говорит кто-то — полоски зелёные, тихо —
/// приглушённые.
class _Equalizer extends StatelessWidget {
  const _Equalizer({required this.speaking});

  final bool speaking;

  static const List<double> _heights = [4, 6, 9];

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final color = speaking ? c.voice : c.voice.withValues(alpha: 0.4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < _heights.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          AnimatedContainer(
            duration: DMotion.fast,
            width: 2,
            height: _heights[i],
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Tooltip(
      message: tooltip,
      child: HoverListener(
        onTap: onTap,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.fast,
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed
                ? c.pressed
                : (hovered ? c.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(DRadii.sm),
          ),
          child: Icon(icon, size: 17, color: c.textSecondary),
        ),
      ),
    );
  }
}

/// Созвона ещё нет — его можно начать.
class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.busy,
    required this.onVoice,
    required this.onVideo,
    this.error,
    this.demo = false,
  });

  final bool busy;
  final VoidCallback onVoice;
  final VoidCallback onVideo;

  /// Комната демонстрационная — созвона в ней не бывает. См. [_isDemoRoom].
  final bool demo;

  /// Почему прошлая попытка не удалась. `null` — попыток не было или удалась.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: c.thread,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            demo ? FluentIcons.beaker_24_regular : FluentIcons.call_24_regular,
            size: 40,
            color: c.textDisabled,
          ),
          const SizedBox(height: DSpace.m),
          Text(
            demo ? l10n.desktopCallDemoRoom : l10n.desktopCallNoCallYet,
            style: DType.bodyStrong.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              demo
                  ? l10n.desktopCallDemoExplain
                  : l10n.desktopCallStartHint,
              textAlign: TextAlign.center,
              style: DType.caption.copyWith(color: c.textDisabled),
            ),
          ),
          if (demo) const SizedBox(height: DSpace.s),
          if (!demo) const SizedBox(height: DSpace.xl),
          if (!demo)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WideButton(
                  icon: FluentIcons.call_24_filled,
                  label: l10n.desktopCallVoiceOnly,
                  enabled: !busy,
                  onTap: onVoice,
                ),
                const SizedBox(width: DSpace.m),
                _WideButton(
                  icon: FluentIcons.video_24_filled,
                  label: l10n.desktopCallWithCamera,
                  enabled: !busy,
                  onTap: onVideo,
                ),
              ],
            ),
          // 🔴 Ожидание и отказ ВИДНЫ. Раньше нажатие на «Голосом» не меняло
          // в окне ничего: ни кружка, ни строчки — хоть получилось, хоть
          // ответил сервер отказом.
          if (busy) ...[
            const SizedBox(height: DSpace.m),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(c.textSecondary),
                  ),
                ),
                const SizedBox(width: DSpace.s),
                Text(
                  l10n.desktopCallConnecting,
                  style: DType.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ] else if (error != null) ...[
            const SizedBox(height: DSpace.m),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    FluentIcons.warning_24_filled,
                    size: 15,
                    color: c.danger,
                  ),
                  const SizedBox(width: DSpace.s),
                  Flexible(
                    child: Text(
                      error!,
                      style: DType.caption.copyWith(color: c.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Созвон идёт, но нас в нём нет.
class _JoinPanel extends StatelessWidget {
  const _JoinPanel({
    required this.busy,
    required this.joinedCount,
    required this.onJoin,
    this.error,
  });

  final bool busy;
  final int joinedCount;
  final VoidCallback onJoin;

  /// Почему прошлая попытка войти не удалась — см. [_StartPanel.error].
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return Container(
      color: c.thread,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.person_voice_20_filled, size: 40, color: c.success),
          const SizedBox(height: DSpace.m),
          Text(
            l10n.desktopCallOngoing,
            style: DType.bodyStrong.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DSpace.xs),
          Text(
            l10n.desktopCallOnAir(joinedCount),
            style: DType.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DSpace.xl),
          _WideButton(
            icon: FluentIcons.person_add_24_filled,
            label: l10n.desktopCallJoin,
            enabled: !busy,
            onTap: onJoin,
          ),
          // Ожидание и отказ — как на панели начала созвона.
          if (busy) ...[
            const SizedBox(height: DSpace.m),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(c.textSecondary),
                  ),
                ),
                const SizedBox(width: DSpace.s),
                Text(
                  l10n.desktopCallConnecting,
                  style: DType.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ] else if (error != null) ...[
            const SizedBox(height: DSpace.m),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    FluentIcons.warning_24_filled,
                    size: 15,
                    color: c.danger,
                  ),
                  const SizedBox(width: DSpace.s),
                  Flexible(
                    child: Text(
                      error!,
                      style: DType.caption.copyWith(color: c.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: enabled ? onTap : null,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: DSpace.l),
        decoration: BoxDecoration(
          color: c.success.withValues(
            alpha: !enabled ? 0.06 : (pressed ? 0.30 : (hovered ? 0.22 : 0.14)),
          ),
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(color: c.success.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: enabled ? c.success : c.textDisabled),
            const SizedBox(width: 6),
            Text(
              label,
              style: DType.label.copyWith(
                color: enabled ? c.success : c.textDisabled,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кадр сцены с подписью, кто её занимает.
/// · ЧИПА «РИСОВАТЬ» ЗДЕСЬ НЕТ, И ЭТО РЕШЕНИЕ (15.09.2026).
///
/// Макет рисует слева-снизу на сцене чип «Рисовать»: общие штрихи поверх
/// демонстрации экрана. Прежняя причина отказа — «канала данных между
/// участниками в протоколе нет» — ОКАЗАЛАСЬ НЕВЕРНОЙ и здесь исправлена:
/// созвон идёт через настоящую `lk.Room`, у которой есть и `publishData`, и
/// событие о приходе данных. Канал есть.
///
/// Причины другие, и их три.
///
/// 1. ЭТО НЕ ЧИП, А ФУНКЦИЯ. Штрихи надо переводить в координаты САМОГО
///    КАДРА, а не окна: у каждого участника своя ширина окна и свои поля по
///    краям, и «обвёл кнопку» обязано попасть в ту же кнопку у всех.
///    Дальше — цвет на участника, стирание, судьба штрихов того, кто вышел.
///
/// 2. НАДО РЕШИТЬ, КТО ВПРАВЕ РИСОВАТЬ. Роли в комнате есть, но правило
///    («любой» / «только ведущий» / «тот, кто показывает, разрешает») — это
///    решение владельца, а не умолчание, которое можно выбрать молча.
///
/// 3. И ГЛАВНОЕ: ПРОВЕРИТЬ ЭТО С ОДНОЙ МАШИНЫ НЕЛЬЗЯ. Весь смысл подписи
///    «Рисовать» в том, что штрих УВИДЯТ ДРУГИЕ. Своя посылка по каналу
///    данных обратно не возвращается, а телефон рисовать не умеет — значит
///    единственная проверка была бы «у меня в окне линия появилась», то есть
///    проверка местного рисования, выданная за общее.
///
/// Локальное рисование «для себя» поэтому тоже не заведено: подпись обещает
/// общий холст, и чип, который рисует только у тебя, — это обещание,
/// нарушенное в первый же раз, когда собеседник спросит «где?».
class _StageFrame extends StatelessWidget {
  const _StageFrame({
    required this.label,
    required this.icon,
    required this.child,
    this.onExpand,
    this.expanded = false,
    this.stats,
  });

  final String label;
  final IconData icon;
  final Widget child;

  /// Показатели дорожки для чипа качества. `null` — мерить нечем, и чипа нет.
  final RoomCallVideoStats? stats;

  /// Развернуть сцену во весь экран. `null` — чипа нет.
  ///
  /// ◆ СЛУЖЕБНЫЕ НАЛОЖЕНИЯ НАД ДЕМОНСТРАЦИЕЙ (из макета) — их два, и взято
  /// только одно.
  ///
  /// 1. «В отдельное окно» — второго нативного окна в проекте нет
  ///    (`desktop_multi_window` не подключён), обещать его нельзя. Вместо
  ///    него разворот сцены во весь экран — то, чего человек на самом деле
  ///    хочет от чужого экрана, и подписано это своими словами, а не
  ///    макетными.
  ///
  /// 2. Чип качества «1080p · 30 fps» НЕ РИСУЕТСЯ: показателей дорожки
  ///    движок наружу не отдаёт вовсе (в `RoomCallMediaController` нет ни
  ///    одного метода статистики). Выдуманное число хуже отсутствующего:
  ///    по нему судят, стоит ли просить показывающего сменить окно.
  ///
  /// Чип появляется ТОЛЬКО над демонстрацией экрана: над лицом собеседника
  /// он был бы второй кнопкой того же действия в сорока точках от кнопки в
  /// шапке — а вот на чужой экран смотрят в упор, и тянуться в шапку за
  /// увеличением там неудобно.
  final VoidCallback? onExpand;

  /// Сцена уже развёрнута — чип предлагает вернуться.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    // 🔴 Скругление и рамка из макета. Прямой чёрный прямоугольник без краёв
    // не отличался от «видео не загрузилось»; зелёная рамка называет сцену
    // живой — тем же цветом, которым в этом окне отмечено всё звучащее.
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: c.success.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: DSpace.m,
            top: DSpace.m,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(DRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: c.success),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: DType.caption.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          // · ЧИП КАЧЕСТВА — СПРАВА-СНИЗУ (макет). Числа НАСТОЯЩИЕ, из
          // движка: раньше их неоткуда было взять, и чип не рисовался вовсе.
          // Выдуманное число хуже отсутствующего — по нему судят, стоит ли
          // просить показывающего сменить окно.
          if (stats != null)
            Positioned(
              right: DSpace.m,
              bottom: DSpace.m,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(DRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.video_24_regular, size: 13, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _statsLabel(stats!, l10n),
                      style: DType.mono.copyWith(
                        fontSize: 10.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (onExpand != null)
            Positioned(
              left: DSpace.m,
              bottom: DSpace.m,
              child: HoverListener(
                onTap: onExpand,
                cursor: SystemMouseCursors.click,
                builder: (ctx, hovered, pressed) => Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: hovered ? 0.62 : 0.45,
                    ),
                    borderRadius: BorderRadius.circular(DRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        expanded
                            ? FluentIcons.full_screen_minimize_24_regular
                            : FluentIcons.full_screen_maximize_24_regular,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        expanded ? l10n.callMinimize : l10n.desktopCallFullScreenShort,
                        style: DType.caption.copyWith(
                          fontSize: 11.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Портрет участника на сцене, когда картинки нет.
/// Одна реплика в чате созвона.
class _CallChatLine {
  const _CallChatLine({
    required this.author,
    required this.avatarPath,
    required this.text,
    required this.mine,
    required this.timestampMs,
  });

  final String author;
  final String? avatarPath;
  final String text;
  final bool mine;
  final int timestampMs;
}

/// Реплика чата созвона — пузырём, как в обычной переписке.
///
/// 🔴 ПЕРЕДЕЛАНО ПО ЗАМЕЧАНИЮ ВЛАДЕЛЬЦА (14.09.2026): «выглядит убого, ничего
/// не понятно».
///
/// Было: стена одинаковых мелких строк «Вы / текст» — без времени, без лиц,
/// без единого разделения. В узкой панели это читалось как список слов, а не
/// как разговор: непонятно, где чья реплика и где кончается одна и начинается
/// другая.
///
/// Имя и лицо показываются только у ПЕРВОЙ реплики в связке одного человека,
/// время — у последней. Повтор их у каждой строки и делал из панели кашу.
class _CallChatBubble extends StatelessWidget {
  const _CallChatBubble({
    required this.line,
    required this.showAuthor,
    required this.showTime,
    required this.gapAbove,
  });

  final _CallChatLine line;
  final bool showAuthor;
  final bool showTime;
  final double gapAbove;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: line.mine
            ? c.accentPrimary.withValues(alpha: 0.18)
            : c.elevated,
        borderRadius: BorderRadius.circular(DRadii.r11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAuthor && !line.mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.tiny.copyWith(
                  fontSize: 10.5,
                  color: c.accentPrimary,
                ),
              ),
            ),
          Text(
            line.text,
            style: DType.caption.copyWith(color: c.textPrimary, height: 1.35),
          ),
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                _hhmm(line.timestampMs),
                style: DType.timeSmall.copyWith(
                  fontSize: 9.5,
                  color: c.textDisabled,
                ),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: gapAbove),
      child: Row(
        mainAxisAlignment: line.mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Лицо — только у первой реплики в связке; у остальных на его месте
          // отступ, чтобы пузыри стояли по одной вертикали.
          if (!line.mine)
            SizedBox(
              width: 26,
              child: showAuthor
                  ? Avatar(
                      name: line.author,
                      image: Avatar.fileImage(line.avatarPath),
                      size: 22,
                    )
                  : null,
            ),
          Flexible(child: bubble),
          if (line.mine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  static String _hhmm(int ms) {
    if (ms <= 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Плитка участника в ленте справа от сцены.
///
/// Равной высоты, радиус 14 — как в макете. Говорящего называет зелёная
/// рамка 1.5 и подложка-градиент: тем же цветом, каким в этом окне отмечено
/// всё звучащее.
///
/// Уровня звука в состоянии НЕТ — только признак «говорит». Поэтому вместо
/// столбиков уровня из макета стоит один спокойный признак: нарисовать
/// «громкость» тремя полосками, которые на самом деле двухпозиционные, значит
/// показать человеку измеритель, который ничего не измеряет.
class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.name,
    required this.avatarPath,
    required this.muted,
    required this.speaking,
    required this.onStage,
    required this.video,
  });

  final String name;
  final String? avatarPath;
  final bool muted;
  final bool speaking;

  /// Его кадр уже занимает сцену — в плитке показываем портрет.
  final bool onStage;

  /// Живая камера, если её можно показать здесь. `null` — портрет.
  final Widget? video;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      height: 128,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.bubblePeer, c.elevated],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: speaking ? c.voice : c.borderSubtle,
          width: speaking ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (video != null)
            Positioned.fill(child: video!)
          else
            Center(
              child: Avatar(
                name: name,
                image: Avatar.fileImage(avatarPath),
                size: 54,
              ),
            ),
          // Подпись читается и на светлом кадре: под ней своя плёнка.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    muted
                        ? FluentIcons.mic_off_24_filled
                        : FluentIcons.mic_24_filled,
                    size: 13,
                    color: muted
                        ? c.textDisabled
                        : (speaking ? c.voice : c.textSecondary),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.tiny.copyWith(color: c.textPrimary),
                    ),
                  ),
                  if (onStage)
                    Icon(
                      FluentIcons.slide_layout_24_filled,
                      size: 13,
                      color: c.textSecondary,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageAvatar extends StatelessWidget {
  const _StageAvatar({
    required this.name,
    required this.avatarPath,
    required this.muted,
    required this.speaking,
  });

  final String name;
  final String? avatarPath;
  final bool muted;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🔴 Говорящего обводим кольцом, а не подсвечиваем фон: на сетке из
        // восьми портретов подсветка фона сливается в кашу, а кольцо видно
        // боковым зрением — ради этого признак и нужен.
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: speaking ? c.voice : Colors.transparent,
              width: 2,
            ),
          ),
          child: Avatar(
            name: name,
            image: Avatar.fileImage(avatarPath),
            size: 88,
          ),
        ),
        const SizedBox(height: DSpace.s),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (muted) ...[
              Icon(
                FluentIcons.mic_off_24_filled,
                size: 13,
                color: c.textDisabled,
              ),
              const SizedBox(width: 4),
            ],
            Text(name, style: DType.body.copyWith(color: c.textPrimary)),
          ],
        ),
      ],
    );
  }
}

/// Строка участника в боковом списке.
class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.name,
    required this.avatarPath,
    required this.muted,
    required this.video,
    required this.sharing,
    required this.reconnecting,
    required this.speaking,
    required this.deafened,
    this.level = 0,
  });

  final String name;
  final String? avatarPath;
  final bool muted;
  final bool video;
  final bool sharing;
  final bool reconnecting;
  final bool speaking;

  /// Человек ВЫКЛЮЧИЛ СЕБЕ ЗВУК — он не слышит созвон.
  ///
  /// 🔴 Признак был в снимке созвона с самого начала и не читался окном НИ
  /// РАЗУ. Человек, надевший наушники и выключивший звук, выглядел в списке
  /// обычным участником с включённым микрофоном: ему говорили, а он не
  /// слышал, и никто за столом об этом не знал.
  final bool deafened;

  /// Громкость, 0…1. Отличается от [speaking] тем же, чем «насколько» от
  /// «говорит ли»: по признаку красится кольцо портрета, по громкости — эта
  /// полоска. Ноль — тихо или движок громкости не отдаёт.
  final double level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.s,
        vertical: DSpace.s - 2,
      ),
      decoration: BoxDecoration(
        color: speaking
            ? c.voice.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Opacity(
        // Кто не слышит — тот и не участвует прямо сейчас. Приглушение
        // говорит это боковым зрением, до чтения подписи.
        opacity: deafened ? 0.7 : 1.0,
        child: Row(
          children: [
            // Кольцо у говорящего — то же, что на сцене: в списке из двенадцати
            // человек глаз ищет, кто сейчас звучит, и подпись он читает вторым
            // движением.
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: speaking ? c.voice : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Avatar(
                name: name,
                image: Avatar.fileImage(avatarPath),
                size: 32,
              ),
            ),
            const SizedBox(width: DSpace.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.label.copyWith(color: c.textPrimary),
                  ),
                  if (reconnecting)
                    Text(
                      l10n.desktopCallReconnecting,
                      style: DType.tiny.copyWith(color: c.warning),
                    )
                  else if (deafened)
                    Text(
                      l10n.desktopCallCannotHear,
                      style: DType.tiny.copyWith(color: c.textTertiary),
                    )
                  else if (sharing)
                    Text(
                      l10n.desktopCallSharingShort,
                      style: DType.tiny.copyWith(color: c.success),
                    )
                  else if (video)
                    Text(
                      l10n.desktopCallCameraOn,
                      style: DType.tiny.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
            // · УРОВЕНЬ ЗВУКА — ПОЛОСКОЙ У ЗНАЧКА (макет).
            //
            // Признак «говорит» отвечает только «да/нет», и в созвоне на
            // пятерых по нему не понять, кто говорит, а у кого просто шумит
            // вентилятор. Числа теперь настоящие — движок отдаёт громкость
            // участника.
            //
            // Полоски НЕТ у того, кто молчит или не слышит: пустая шкала
            // рядом с выключенным микрофоном — шум, а не сведения.
            if (!muted && !deafened && level > 0.02) ...[
              _LevelBar(level: level),
              const SizedBox(width: 6),
            ],
            // Наушники важнее микрофона: выключенный себе звук значит, что
            // человек не слышит НИЧЕГО, и состояние его микрофона в этот момент
            // ничего не решает.
            Icon(
              deafened
                  ? FluentIcons.speaker_off_24_filled
                  : (muted
                        ? FluentIcons.mic_off_24_filled
                        : FluentIcons.mic_24_filled),
              size: 16,
              color: deafened
                  ? c.warning
                  : (muted ? c.textDisabled : c.voice),
            ),
          ],
        ),
      ),
    );
  }
}

/// Пунктирная кнопка «Пригласить» под списком участников созвона.
class _InviteButton extends StatelessWidget {
  const _InviteButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return HoverListener(
      onTap: busy ? null : onTap,
      cursor: busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hovered && !busy
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(c.textSecondary),
                ),
              )
            else
              Icon(
                FluentIcons.person_add_24_regular,
                size: 17,
                color: c.textSecondary,
              ),
            const SizedBox(width: 7),
            Text(
              busy ? l10n.desktopCallPreparingLink : l10n.desktopCallInvite,
              style: DType.tiny.copyWith(
                fontSize: 11.5,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Плитка «+N» в конце сетки лиц: сколько участников не поместилось.
///
/// Показывать ЧИСЛО, а не многоточие: «ещё трое» и «ещё тридцать» — разные
/// новости, и обрыв без числа заставляет открывать список, чтобы узнать какая.
class _StageOverflow extends StatelessWidget {
  const _StageOverflow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return SizedBox(
      width: 88,
      height: 88,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Text(
          '+$count',
          style: DType.title.copyWith(
            color: c.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Подпись чипа качества: «1080p · 30 к/с».
///
/// 🔴 ПИШЕМ ТОЛЬКО ТО, ЧТО ИЗМЕРЕНО. Движок может отдать высоту без частоты
/// или наоборот — тогда в чипе стоит одна половина, а не выдуманная вторая.
/// «1080p · — к/с» было бы честнее нуля, но и оно лишнее: пустое место не
/// обещает ничего.
String _statsLabel(RoomCallVideoStats s, AppLocalizations l10n) {
  final parts = <String>[];
  final h = s.height;
  if (h != null && h > 0) parts.add('${h}p');
  final fps = s.fps;
  if (fps != null && fps > 0) parts.add(l10n.desktopCallFps(fps.round()));
  return parts.join(' · ');
}

/// Полоска громкости: три столбика, которые зажигаются по уровню.
///
/// Не плавная шкала, а три ступени — ровно столько, сколько человек успевает
/// прочесть боковым зрением в идущем разговоре. Плавная полоска в списке из
/// пяти строк читалась бы как мигание.
class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    // Пороги подобраны под то, как движок отдаёт громкость: обычная речь
    // держится около 0,1–0,4, и линейная шкала зажигала бы только первый
    // столбик.
    final lit = level >= 0.30
        ? 3
        : level >= 0.12
        ? 2
        : 1;
    return SizedBox(
      width: 13,
      height: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Container(
              width: 3,
              height: 4.0 + i * 4,
              decoration: BoxDecoration(
                color: i < lit ? c.voice : c.voice.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Сетка участников: три колонки, плитки 16/10.
///
/// ◆ Одна сцена отвечает на вопрос «кто сейчас говорит». Сетка — на другой:
/// «как они все выглядят». В разговоре вчетвером второй вопрос важнее, и без
/// сетки трое из четверых видны были только плитками в ленте сбоку.
///
/// 🔴 ПРЕДЕЛ ТОТ ЖЕ, ЧТО У СЕТКИ ПОРТРЕТОВ, и по той же причине: на двенадцати
/// участниках плитки становятся меньше значка и перестают что-либо показывать.
/// Остаток уходит в последнюю плитку «+N» — она не прячет людей, а называет,
/// сколько их ещё.
class _StageGrid extends StatelessWidget {
  const _StageGrid({required this.tiles, required this.overflow});

  final List<
    ({
      String name,
      String? avatarPath,
      bool muted,
      bool speaking,
      Widget? video,
    })
  >
  tiles;

  /// Сколько участников не поместилось. Ноль — плитки «+N» нет.
  final int overflow;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      // Та же оболочка, что у сцены с видео: скругление и рамка. Иначе окно
      // «дёргалось» бы формой при каждом переключении.
      decoration: BoxDecoration(
        color: c.thread,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: c.success.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(DSpace.m),
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 16 / 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final t in tiles)
            _GridTile(
              name: t.name,
              avatarPath: t.avatarPath,
              muted: t.muted,
              speaking: t.speaking,
              video: t.video,
            ),
          if (overflow > 0) _GridOverflowTile(count: overflow),
        ],
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.name,
    required this.avatarPath,
    required this.muted,
    required this.speaking,
    required this.video,
  });

  final String name;
  final String? avatarPath;
  final bool muted;
  final bool speaking;
  final Widget? video;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(DRadii.md),
        // Говорящий в рамке — тем же мятным, которым в этом окне отмечено всё
        // звучащее. Рамка, а не подпись: на плитке 16/10 подписи места нет.
        border: speaking
            ? Border.all(color: c.success, width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video != null)
            video!
          else
            // Камеры нет — портрет. Честнее чёрного прямоугольника: видно,
            // кто здесь, даже когда смотреть не на что.
            ColoredBox(
              color: c.thread,
              child: Center(
                child: Avatar(
                  name: name,
                  image: Avatar.fileImage(avatarPath),
                  size: 44,
                ),
              ),
            ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 5,
            child: Row(
              children: [
                if (muted) ...[
                  Icon(
                    FluentIcons.mic_off_24_filled,
                    size: 12,
                    color: c.danger,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.tiny.copyWith(
                      fontSize: 10.5,
                      color: Colors.white,
                      // Тень, а не подложка: имя лежит поверх кадра, и плашка
                      // под ним закрывала бы то, ради чего плитка и нужна.
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Последняя плитка сетки: «+4».
class _GridOverflowTile extends StatelessWidget {
  const _GridOverflowTile({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(DRadii.md),
      ),
      child: Text(
        '+$count',
        style: DType.label.copyWith(
          fontSize: 14,
          color: c.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
