// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../calls/call_manager.dart';
import '../../../rooms/room_call_manager.dart';
import '../calls/active_call_bar.dart';
import '../calls/call_mini_host.dart';
import '../calls/call_mini_window.dart' show desktopCallMiniDuration;
import '../calls/call_presence.dart';
import '../calls/direct_call_window.dart';
import '../calls/room_call_media_guard.dart';
import '../calls/room_call_window_host.dart';
import '../../call_error_text.dart';
import '../calls/room_call_window.dart';
import '../../../calls/call_state.dart';
import '../../../sync/peer_history_service.dart';
import '../calls/incoming_call_toast.dart';
import '../calls/call_peer_label.dart';
import '../calls/one_to_one_call_screen.dart';
import '../services/desktop_child_windows.dart';
import '../services/desktop_notification_windows.dart';
import '../services/desktop_taskbar.dart';
import 'desktop_child_window_app.dart';
import '../primitives/avatar.dart';
import '../chat/forward_target_dialog.dart';
import '../chat/details/details_drawer.dart';
import '../chat/details/desktop_selection_store.dart';
import '../design/material_theme.dart';
import '../design/theme_bridge.dart';
import '../design/tokens.dart';
import '../shell/desktop_app_menu.dart';
import '../shell/desktop_shell.dart';
import '../shell/now_playing_island.dart';
import '../primitives/desktop_snackbar.dart';
import '../primitives/desktop_dialog.dart'
    show DDialogAction, DDialogSize, DesktopDialog;
import '../shell/rail_live.dart';
import '../shell/window_chrome.dart';
import '../shell/sidebar.dart'
    show DesktopSection, ConnectionStatus, kRailWidth;
import '../workspace/settings_workspace.dart';
import '../onboarding/desktop_account_setup.dart';
import '../onboarding/desktop_auth_gate.dart';
import '../onboarding/desktop_recovery_kit_gate.dart';
import '../services/desktop_update_service.dart';
import '../services/desktop_absence.dart';
import '../services/desktop_diag_file_log.dart';
import '../services/desktop_history_catch_up.dart';
import '../services/desktop_nav_history.dart';
import '../services/desktop_deleted_chats.dart';
import '../services/desktop_app_lock_service.dart';
import '../../../security/app_security_manager.dart' show SecurityLockScope;
import '../../security_lock_flow.dart' show AppSecurityLockOverlay;
import '../services/desktop_dock_badge_service.dart';
import '../services/desktop_notification_service.dart';
import '../chat/desktop_wallpaper.dart' show desktopLegacyDefaultWallpaperId;
import '../chat/desktop_wallpaper_picker.dart' show DesktopChatWallpapers;
import '../services/desktop_call_devices.dart';
import '../services/desktop_tray_service.dart';
import '../services/desktop_ui_prefs.dart';
import '../services/desktop_window_activity.dart';
import '../services/desktop_window_state.dart';
import 'desktop_app_view_model.dart';
import 'desktop_calls_section.dart';
import 'desktop_chats_section.dart';
import 'desktop_contacts_section.dart';
import 'desktop_lock_overlay.dart';
import 'desktop_spotlight.dart';
import 'desktop_splash.dart';
import 'desktop_sync_status.dart';
import '../../room_invite_join_screen.dart' show RoomInviteJoinScreen;
import '../chat/chat_thread_panel.dart' show DesktopDraftStore;
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_offline_lock.dart';
import 'desktop_room_limit_dialog.dart' show desktopMayJoinRoom;
import '../chat/desktop_link_router.dart';
import '../primitives/desktop_screen_window.dart';

/// Top-level widget for the desktop production build.
///
/// Owns the [AppController] + [CallManager] lifecycle, gates on
/// identity/profile-selection state, and delivers per-section content to
/// [DesktopShell]. Active calls render as full-screen overlays above the shell;
/// incoming calls surface as [IncomingCallToast].
///
/// Mobile-only services (PushWakeService, app_links, CallForegroundService)
/// are NOT initialised here — by design. Desktop pushes will be added in a
/// later slice via WSS keep-alive + local notifications.
class DesktopProductionApp extends StatefulWidget {
  const DesktopProductionApp({super.key});

  @override
  State<DesktopProductionApp> createState() => _DesktopProductionAppState();
}

class _DesktopProductionAppState extends State<DesktopProductionApp>
    with WindowListener {
  /// Переводы для кода САМОГО КОРНЯ.
  ///
  /// 🔴 `AppLocalizations.of(context)!` ЗДЕСЬ ВСЕГДА ПАДАЛ — и падал молча.
  ///
  /// Этот класс СТРОИТ `MaterialApp`, значит его собственный `context` лежит
  /// ВЫШЕ `Localizations`, которые `MaterialApp` вставляет под собой. Поиск
  /// идёт среди предков, наверху его нет — `of` возвращал null, а `!` бросал
  /// исключение. Не иногда, а на каждом обращении.
  ///
  /// Так было не всегда: до 20.09.2026 (`224f2a63`, перевод окна на ARB) в
  /// этих двенадцати местах стояли строки прямо в коде, и обращаться к
  /// переводам корню было незачем. Перевод заменил их на `l10n.…` — и хлебные
  /// крошки в шапке окна начали бросать исключение при КАЖДОЙ сборке шапки.
  /// `_installDesktopErrorGuard` гасит красное полотно, поэтому наружу это
  /// вышло не поломкой, а ПРОПАЖЕЙ: строка заголовка со стрелками «назад» и
  /// «вперёд», полем ⌘K и кнопкой «не беспокоить» просто не рисовалась.
  /// В журнале это видно как шесть `ui.widget_error` подряд на старте.
  ///
  /// Контекст берётся у [_OverlayHost] — он уже есть и уже лежит ВНУТРИ
  /// `MaterialApp` (его завели ровно за тем же: корню неоткуда взять слой,
  /// чтобы показать всплывашку). Пока его ещё нет — первые кадры до первой
  /// отрисовки — переводы ищутся напрямую по языку, который выбрал бы сам
  /// `MaterialApp`. Это тот же путь, что у уведомлений
  /// (`desktopNotificationStrings`; до 30.09.2026 они брали язык системы как
  /// есть и на незнакомом языке падали), и он не умеет не найтись:
  /// `resolveAppUiLocale` в худшем случае отвечает английским.
  AppLocalizations get l10n {
    final ctx = _overlayHostKey.currentContext;
    if (ctx != null) {
      final found = AppLocalizations.of(ctx);
      if (found != null) return found;
    }
    return lookupAppLocalizations(_localeForStrings);
  }

  /// Язык для запасного пути [l10n]: выбор человека, иначе — язык системы,
  /// разрешённый теми же правилами, что и у `MaterialApp` ниже.
  Locale get _localeForStrings {
    if (!_ready) return const Locale('en');
    final override = _controller.appLocaleOverride;
    if (override != null) return override;
    return _controller.resolveAppUiLocale(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
  }

  AppController _controller = AppController();
  CallManager? _callManager;

  /// Тот же [CallManager], поданный окнам звонка через [DesktopDirectCall].
  DesktopDirectCall? _directCall;

  /// Звонок один на один в своём окне ОС (29.09.2026, Р1) — см.
  /// [DesktopDirectCallWindow]. `null` — менеджера звонков ещё нет.
  DesktopDirectCallWindow? _callWindow;

  /// Фаза звонка один на один до последнего изменения — чтобы отличить
  /// «положили трубку в разговоре» от «не взяли входящий».
  CallPhase _prevDirectPhase = CallPhase.idle;

  /// Звонок, о завершении которого уже сказали.
  String _endAnnouncedFor = '';

  /// 🔴 БЕЗ НЕГО КОМНАТНЫЙ СОЗВОН НА ДЕСКТОПЕ БЫЛ ПУСТОЙ ОБОЛОЧКОЙ
  /// (14.09.2026, живая проверка вдвоём).
  ///
  /// Телефон создаёт ДВА управляющих: `CallManager` для личных звонков и
  /// `RoomCallManager` для комнатных (`main.dart`). Десктопный вход создавал
  /// только первый — второго не было ВООБЩЕ.
  ///
  /// Снаружи это выглядело как работающий созвон: список участников и
  /// счётчик «2 в эфире» приходят из снимка звонка с релея, а не из
  /// менеджера. А вот медиа-сессию (`joinRelayRoomCallMedia`), LiveKit,
  /// дорожки, признак речи и выбор устройства даёт именно он — и на
  /// десктопе не давал ничего.
  ///
  /// Поэтому видео с телефона не приходило, камера не включалась и зелёного
  /// признака речи не было: включать было нечему.
  RoomCallManager? _roomCallManager;
  DesktopNotificationService? _notifService;
  final DesktopAppLockService _lockService = DesktopAppLockService();
  // Drives a TickerMode around the whole tree so animations stop while the
  // window is hidden to the tray or minimised — a tray-resident app must not
  // keep painting frames nobody can see.
  final DesktopWindowActivity _windowActivity = DesktopWindowActivity();
  StreamSubscription<void>? _changedSub;
  /// Отписка от выдержанного состояния связи (см. [_wireListeners]).
  VoidCallback? _detachSyncPhase;
  StreamSubscription<void>? _securitySub;
  StreamSubscription<void>? _restartSub;
  StreamSubscription<String>? _notifTapSub;
  StreamSubscription<Uri>? _deepLinkSub;
  VoidCallback? _callStateListener;
  Uri? _pendingDeepLink;
  bool _ready = false;
  String _error = '';

  /// Запуск идёт дольше [_kBootSlowAfter] — заставка предлагает выход.
  bool _bootSlow = false;
  Timer? _bootSlowTimer;

  /// Номер текущего запуска. Запуск, чей номер уже не текущий (его сменил
  /// «Повторить»), по возвращении из ожидания ничего не трогает.
  int _bootGeneration = 0;

  /// Идёт разборка перед новым запуском — второй «Повторить» ждёт.
  bool _restartTeardown = false;

  /// Сколько ждать запуска, прежде чем честно сказать, что он затянулся.
  /// С запасом: миграция большой базы или системный запрос доступа к связке
  /// ключей законно занимают десятки секунд.
  static const Duration _kBootSlowAfter = Duration(seconds: 60);
  Timer? _winSaveDebounce; // persists window geometry on resize/move
  ConnectionStatus _connection = ConnectionStatus.connecting;
  DesktopSection _section = DesktopSection.chats;
  Widget? _modalOverlay;

  /// Фокус поля поиска в шапке: по ⌘K курсор ставится туда.
  final FocusNode _searchFocus = FocusNode(debugLabel: 'window-search');

  /// 🔴 Нужен, чтобы корень мог что-то СКАЗАТЬ человеку.
  ///
  /// Корень строит `MaterialApp`, поэтому его собственный контекст лежит выше
  /// навигатора и Overlay: `DesktopSnackbar.show(context, ...)` отсюда просто
  /// не находит слоя. Ключ даёт контекст изнутри приложения.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _windowListenerAttached = false;

  bool get _isNativeDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  // Incoming-toast dismissal handle. Non-null while a toast is visible so we
  // can dismiss it once the state changes (accept / decline / hangup).
  VoidCallback? _incomingToastDismiss;
  String _toastForCallId = '';
  String _toastPeerKey = '';
  // PR-G bug 19 (defense-in-depth): hard watchdog that force-dismisses a
  // stuck toast if the FSM somehow never transitions out of ringingIncoming
  // (e.g. caller's hangup signal was lost). The CallManager already has its
  // own 45s _startRingTimeout that calls _endCall(timeout); this is a UI-only
  // safety net in case the controller's notifier ever fails to fire.
  Timer? _incomingToastWatchdog;
  static const Duration _kIncomingToastMaxVisible = Duration(seconds: 60);

  // Shared selection store for the third-column details drawer. Written by
  // DesktopChatsSection (one per Chats / Rooms tab); read by detailsBuilder.
  // Each tab has its own store so switching tabs doesn't bleed state.
  /// Имя комнаты по идентификатору — для полосы идущего созвона.
  ///
  /// Берём из складов выбора, потому что они и так держат открытые переписки;
  /// отдельного запроса ради подписи полосы не делаем. Не нашли — полоса
  /// покажется без имени, и это честнее, чем идентификатор комнаты в строке.
  String _roomTitleFor(String roomId) {
    for (final store in [_roomsSelection, _chatsSelection]) {
      final convo = store.selected;
      if (convo != null && convo.convoId == roomId) return convo.title;
    }
    // Созвон свёрнут, а комната уже не открыта: имя помнит окно созвона.
    final remembered = DesktopCallPresence.instance.roomTitle(roomId);
    if (remembered.isNotEmpty) return remembered;
    return '';
  }

  /// Выключить/включить свой микрофон из полосы созвона.
  ///
  /// 🔴 ТОТ ЖЕ ПУТЬ, ЧТО У ДОКА в окне созвона
  /// (`updateRelayRoomCallParticipant`), и состояние читается из СВЕЖЕГО
  /// снимка звонка, а не из того, что помнит полоса. Два места, меняющие одно
  /// состояние разными путями, рано или поздно разъезжаются — а тут это
  /// значит «думаю, что молчу, а меня слышно».
  Future<void> _toggleRoomCallMic() async {
    final state = RoomCallManager.instance?.state.value;
    final roomId = state?.roomId.trim() ?? '';
    final callId = state?.callId.trim() ?? '';
    if (roomId.isEmpty || callId.isEmpty) return;
    final cached = await _controller.getCachedRoomCall(roomId);
    final self = cached?.selfParticipant;
    if (cached == null || self == null || cached.callId != callId) return;
    try {
      final result = await _controller.updateRelayRoomCallParticipant(
        roomId: roomId,
        callId: callId,
        reconnecting: self.isReconnecting,
        muted: !self.muted,
        deafened: self.deafened,
        videoEnabled: self.videoEnabled,
        screenShareEnabled: self.screenShareEnabled,
        speaking: self.speaking,
      );
      if (result == null) {
        _roomCallActionFailed(leave: false);
        return;
      }
      await RoomCallManager.instance?.ensureJoined(
        roomId: roomId,
        callId: callId,
        forceRefresh: true,
      );
    } catch (_) {
      // Кнопка вернётся в прежнее состояние сама — она рисуется по снимку,
      // а не по нажатию. Но «почему» надо сказать словами.
      _roomCallActionFailed(leave: false);
    }
  }

  /// Включить или выключить свою камеру в созвоне, не открывая его окно.
  ///
  /// Тот же путь, что у дока окна созвона: намерение уходит релею, а
  /// медиа-движок включает дорожку по ответу.
  Future<void> _toggleRoomCallCamera(bool enable) async {
    final state = RoomCallManager.instance?.state.value;
    final roomId = state?.roomId.trim() ?? '';
    final callId = state?.callId.trim() ?? '';
    if (roomId.isEmpty || callId.isEmpty) return;
    final cached = await _controller.getCachedRoomCall(roomId);
    final self = cached?.selfParticipant;
    if (cached == null || self == null || cached.callId != callId) return;
    try {
      final result = await _controller.updateRelayRoomCallParticipant(
        roomId: roomId,
        callId: callId,
        reconnecting: self.isReconnecting,
        muted: self.muted,
        deafened: self.deafened,
        videoEnabled: enable,
        screenShareEnabled: self.screenShareEnabled,
        speaking: self.speaking,
      );
      if (result == null) {
        _roomCallActionFailed(leave: false);
        return;
      }
      await RoomCallManager.instance?.ensureJoined(
        roomId: roomId,
        callId: callId,
        forceRefresh: true,
      );
    } catch (_) {
      _roomCallActionFailed(leave: false);
    }
  }

  /// Выйти из созвона, не открывая его окно, — те же вызовы и в том же
  /// порядке, что у кнопки «Выйти» в окне созвона и на телефоне.
  Future<void> _leaveRoomCall() async {
    final state = RoomCallManager.instance?.state.value;
    final roomId = state?.roomId.trim() ?? '';
    final callId = state?.callId.trim() ?? '';
    if (roomId.isEmpty || callId.isEmpty) return;
    try {
      final result = await _controller
          .leaveRelayRoomCall(roomId: roomId, callId: callId)
          .timeout(const Duration(seconds: 20));
      if (result == null) {
        _roomCallActionFailed(leave: true);
        return;
      }
      await RoomCallManager.instance?.clearIfMatches(
        roomId: roomId,
        callId: callId,
      );
      // Вышли с полосы главного окна, а созвон был в своём окне ОС — оно
      // не должно остаться с пустой панелью «начать созвон».
      if (DesktopRoomCallWindows.openRoomId == roomId) {
        unawaited(DesktopRoomCallWindows.close());
      }
    } catch (_) {
      _roomCallActionFailed(leave: true);
    }
  }

  /// Отказ действия созвона вне его окна — всплывашкой.
  ///
  /// 🔴 Релей не ответил — и нажатие «выключить микрофон» или «выйти» не
  /// меняло ничего, без единого слова. «Думаю, что молчу, а меня слышно» —
  /// худшее, что может случиться в созвоне.
  void _roomCallActionFailed({required bool leave}) {
    final ctx = _overlayHostKey.currentContext;
    if (ctx == null || !mounted) return;
    final l10n = AppLocalizations.of(ctx)!;
    DesktopSnackbar.show(
      ctx,
      message: leave ? l10n.desktopCallLeaveFailed : l10n.desktopCallToggleFailed,
      kind: DSnackKind.error,
    );
  }

  /// Свернуть звонок один на один и открыть переписку с собеседником.
  void _openDirectCallChat(String peerProfileId) {
    DesktopCallPresence.instance.minimizeDirect();
    unawaited(_openProfileChatByDeepLink(peerProfileId));
  }

  /// Вернуться в окно созвона из полосы.
  ///
  /// 🔴 НАВИГАТОР БЕРЁМ У КЛЮЧА, А НЕ ПО КОНТЕКСТУ. Этот виджет САМ строит
  /// `MaterialApp`, то есть навигатора среди его предков нет: `Navigator.of`
  /// здесь не находит ничего и кнопка молча не работает. Проверено живьём —
  /// нажатие «Вернуться» не открывало окно.
  void _returnToRoomCall(String roomId, String title) {
    final vm = _vm;
    final nav = _navigatorKey.currentState;
    if (vm == null || nav == null) return;
    // Созвон в своём окне ОС (Р1) — это окно вперёд.
    if (DesktopRoomCallWindows.openRoomId == roomId) {
      unawaited(DesktopRoomCallWindows.focus());
      return;
    }
    // Окно этого созвона уже открыто — второе поверх него было бы тем же
    // созвоном дважды.
    if (DesktopCallPresence.instance.roomWindowOpen.value == roomId) return;
    unawaited(() async {
      final own = await DesktopRoomCallWindows.open(
        vm: vm,
        groupId: roomId,
        title: title,
      );
      if (own || !mounted) return;
      _pushRoomCallRoute(vm, roomId, title);
    }());
  }

  /// Созвон поверх главного окна — как до Р1: своего окна нет.
  void _pushRoomCallRoute(DesktopAppViewModel vm, String roomId, String title) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    if (DesktopCallPresence.instance.roomWindowOpen.value == roomId) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => DesktopRoomCallWindow(
          vm: vm,
          groupId: roomId,
          // Пустое имя передаём как есть: окно само покажет «Обсуждение»
          // без хвоста, а не «Обсуждение · Созвон».
          title: title,
        ),
      ),
    );
  }

  final DesktopChatSelectionStore _chatsSelection = DesktopChatSelectionStore();
  final DesktopChatSelectionStore _roomsSelection = DesktopChatSelectionStore();

  /// История открытых переписок — за ней ходят стрелки «назад» и «вперёд» в
  /// шапке окна. Живёт ЗДЕСЬ, а не в оболочке и не в складах выбора: разделов
  /// два, склада выбора тоже два, а путь человека по окну один.
  final DesktopNavHistory _navHistory = DesktopNavHistory();

  /// Идёт шаг по истории. Пока он идёт, изменение склада выбора НЕ считается
  /// новым посещением — иначе «назад» дописывало бы историю на каждом шаге и
  /// никуда бы не уводило.
  bool _navigatingHistory = false;

  void _onChatsSelectionChanged() {
    _recordVisit(DesktopSection.chats, _chatsSelection.selected);
    _dismissPopupsOnOpen(_chatsSelection.selectedConvoId);
  }

  void _onRoomsSelectionChanged() {
    _recordVisit(DesktopSection.rooms, _roomsSelection.selected);
    _dismissPopupsOnOpen(_roomsSelection.selectedConvoId);
  }

  /// Последняя открытая переписка, чьи окошки уведомлений уже погашены.
  String _popupsDismissedFor = '';

  /// Открыли переписку в главном окне — её окошко уведомления в углу больше
  /// не нужно (Windows, как у Telegram; 29.09.2026).
  ///
  /// 🔴 Только при СМЕНЕ открытой переписки: склад оповещает и на каждом
  /// обновлении списка, а окошко о новом сообщении в уже открытой, но не
  /// видной переписке (окно за другими) гасить нельзя.
  void _dismissPopupsOnOpen(String convoId) {
    if (convoId.isEmpty || convoId == _popupsDismissedFor) return;
    _popupsDismissedFor = convoId;
    unawaited(DesktopNotificationWindows.instance.dismissFor(convoId));
  }

  void _recordVisit(DesktopSection section, Conversation? convo) {
    if (_navigatingHistory || convo == null) return;
    _navHistory.visit(DesktopNavEntry(section: section, convo: convo));
  }

  /// Применить шаг по истории: переключить раздел и открыть переписку тем же
  /// путём, каким её открывает ⌘K.
  void _applyHistoryEntry(DesktopNavEntry entry) {
    // Удалённая здесь переписка из пути выбрасывается: стрелка, ведущая в
    // чат, которого в списке уже нет, — сломанная стрелка. Выбросив её, идём
    // дальше В ТУ ЖЕ СТОРОНУ, чтобы одно нажатие оставалось одним шагом.
    if (DesktopDeletedChats.isSuppressed(
      convoId: entry.convoId,
      lastEventAtMs: entry.convo.lastEventAtMs,
    )) {
      // Шаг сюда уже сдвинул курсор на эту запись; [forget] выбросит её и
      // поставит курсор на соседнюю — её и открываем.
      _navHistory.forget(entry.convoId);
      final next = _navHistory.current;
      if (next != null && next.convoId != entry.convoId) {
        _applyHistoryEntry(next);
      }
      return;
    }
    // Личная переписка при закрытых «Личных» — сначала пароль, как у любого
    // другого входа (см. [desktopUnlockPersonalChat]).
    if (desktopPersonalChatHidden(_controller, entry.convoId)) {
      final navContext = _navigatorKey.currentContext;
      if (navContext == null) return;
      unawaited(() async {
        final ok = await desktopUnlockPersonalChat(
          navContext,
          _controller,
          entry.convoId,
        );
        if (ok && mounted) _applyHistoryEntry(entry);
      }());
      return;
    }
    final selectSection = _shellSelectSection;
    _navigatingHistory = true;
    try {
      selectSection?.call(entry.section);
      final store = entry.section == DesktopSection.rooms
          ? _roomsSelection
          : _chatsSelection;
      store.select(entry.convo);
      if (_selfProfileOpen) setState(() => _selfProfileOpen = false);
    } finally {
      _navigatingHistory = false;
    }
  }

  // PR4 (SPRINT2_AUDIT §16): owns the connecting / syncing / online /
  // reconnecting state for the chat-list banner. Lazy because it needs
  // [_controller] which is constructed at field-init time, but we'd
  // rather not run the subscription until [initState] to avoid leaking
  // in case the widget never mounts. Disposed in [dispose].
  DesktopSyncStatusController? _syncStatus;

  /// The controller↔UI seam (see [DesktopAppViewModel]).
  ///
  /// One debounced subscription to `changed` feeding diffing selectors, so a
  /// section no longer has to open its own subscription and re-query on every
  /// tick. Created per controller instance — [_restart] replaces the
  /// controller wholesale, so the view model goes with it.
  DesktopAppViewModel? _vm;

  /// Число непрочитанных на значке приложения в Dock (macOS).
  final DesktopDockBadgeService _dockBadge = DesktopDockBadgeService();

  @override
  void initState() {
    super.initState();
    // Ссылки в переписке: приглашение в комнату открываем сами, остальное —
    // как раньше, во внешнем браузере.
    DesktopLinkRouter.handler = (uri) {
      final target = tryParseRoomInviteUri(uri);
      if (target == null) return false;
      unawaited(_openRoomInviteFromLink(target));
      return true;
    };
    if (_isNativeDesktop) {
      windowManager.addListener(this);
      _windowListenerAttached = true;
      DesktopWindowActivity.hideHandler = _hideToTray;
      if (DesktopWindowActivity.startedHidden) {
        // Автозапуск «свёрнутым»: окна нет на экране с самого начала.
        _windowActivity.onHidden();
        _lockService.setWindowFocused(false);
      }
      // Микрофон, динамики и камера звонков — «как в системе» или выбор
      // человека, а не угадывание по названию (desktop_call_devices.dart).
      installDesktopCallDevices();
      // Трей ходит теми же путями, что и окно: спрятать — с учётом
      // видимости, показать — с фокусом, «без звука» — через службу
      // уведомлений, чтобы кнопка в шапке и значок видели одно и то же.
      DesktopTrayService.instance.bind(
        DesktopTrayActions(
          show: _showFromTray,
          hide: _hideToTray,
          quit: quitDesktopApp,
          isWindowInFront: () =>
              _windowActivity.visible.value &&
              DesktopWindowActivity.focused.value,
          mute: (duration) async =>
              _notifService?.setDoNotDisturbFor(duration),
          unmute: () async => _notifService?.setDoNotDisturb(false),
        ),
      );
    }
    // D-2: single subscription so EVERY show/hide path updates presence,
    // including tray paths that raise the window without a focus event.
    _windowActivity.visible.addListener(_onWindowVisibilityChanged);
    // Touch ID заперли или открыли — от этого зависят слой над навигатором и
    // строка меню, а живут они в корне.
    _lockService.locked.addListener(_onDeviceLockChanged);
    // Открыл переписку — правая панель снова про НЕЁ, а не про меня. Иначе
    // свой профиль висел бы поверх чужих чатов, пока его не закроют руками.
    _chatsSelection.addListener(_dropSelfProfileOnSelection);
    _roomsSelection.addListener(_dropSelfProfileOnSelection);
    // Путь человека по окну: каждый открытый чат — шаг в истории, по которой
    // ходят стрелки в шапке.
    _chatsSelection.addListener(_onChatsSelectionChanged);
    _roomsSelection.addListener(_onRoomsSelectionChanged);
    // Выбор «Тёмная / Светлая / Авто» живёт в настройках окна, а применяет его
    // корень: без этой подписки переключение на «Авто» ничего бы не сделало до
    // следующей перерисовки по любому другому поводу.
    DesktopUiPrefs.themeMode.addListener(_onThemeModeChanged);
    // Звонок свернули или развернули — перестроить: окно звонка во всё окно
    // живёт здесь.
    DesktopCallPresence.instance.directMinimized.addListener(
      _onCallPresenceChanged,
    );
    // «Звонок в отдельном окне» переключили посреди звонка, или на macOS
    // включили экранный диктор — звонок переезжает сразу.
    DesktopUiPrefs.callInOwnWindow.addListener(_onCallPresentationChanged);
    DesktopChildWindows.instance.availability.addListener(
      _onCallPresentationChanged,
    );
    _boot();
  }

  /// Последняя переписка, о которой мы знаем. По ней и только по ней
  /// решается, СМЕНИЛСЯ ли выбор.
  String _lastSelectionId = '';

  /// Открыли ДРУГУЮ переписку — правая панель снова про неё, а не про меня.
  ///
  /// 🔴 РЕАГИРУЕМ НА СМЕНУ ВЫБОРА, А НЕ НА ЛЮБОЕ ОПОВЕЩЕНИЕ СКЛАДА.
  ///
  /// Склад оповещает слушателей и тогда, когда переписка ТА ЖЕ, но обновился
  /// её снимок: `refresh()` уведомляет всегда — это его работа. А список чатов
  /// перечитывается сам по себе, раз в тридцать секунд, чтобы «вчера» не
  /// протухало. Значит своя страница профиля закрывалась сама, без единого
  /// действия человека, в среднем через полминуты после открытия — и тем
  /// вернее, чем активнее переписка.
  ///
  /// Тот же дефект ломал переход «Настройки → Профиль»: настройки
  /// закрывались, секция чатов перечитывала список, склад оповещал — и
  /// профиль, только что открытый, закрывался в том же кадре.
  void _dropSelfProfileOnSelection() {
    final next = _chatsSelection.selectedConvoId.isNotEmpty
        ? _chatsSelection.selectedConvoId
        : _roomsSelection.selectedConvoId;
    if (next == _lastSelectionId) return;
    _lastSelectionId = next;
    if (!_selfProfileOpen) return;
    setState(() => _selfProfileOpen = false);
  }

  @override
  void onWindowClose() async {
    // Cmd/Ctrl+W and the OS «close» button should hide, not quit. The actual
    // termination path is the tray «Выйти» menu item (see main_desktop.dart).
    if (!_isNativeDesktop) return;
    final prevent = await windowManager.isPreventClose();
    if (!prevent) return;
    // 🔴 ЗАКРЫТЬ ПРОСЯТ НЕ ВСЕГДА РУКОЙ ЧЕЛОВЕКА (26.09.2026). Windows шлёт то
    // же самое сообщение из «Диспетчера задач» по «Завершить задачу» и при
    // выключении компьютера. Спрятать окно в ответ на такую просьбу — это
    // процесс, который не уходит: человек «закрыл» приложение, а оно живёт в
    // списке. Спрятанное окно закрыть рукой нельзя, поэтому просьба закрыть
    // уже спрятанное окно — всегда системная, и она означает «выйти».
    final visible = await windowManager.isVisible();
    // «Закрывать в трей» выключено — крестик закрывает приложение
    // (28.09.2026, настройки → Общие).
    if (!visible ||
        !DesktopWindowActivity.trayReady ||
        !DesktopUiPrefs.closeToTray.value) {
      await quitDesktopApp();
      return;
    }
    await _hideToTray();
  }

  /// Спрятать окно в трей: кнопка закрытия, ⌘W и пункт трея «Скрыть окно»
  /// идут одним путём (17.09.2026). Пункт трея раньше звал
  /// `windowManager.hide()` напрямую, и приложение продолжало считать себя на
  /// экране: присутствие «в сети», анимации идут.
  Future<void> _hideToTray() async {
    await windowManager.hide();
    _notifService?.setWindowFocused(false);
    _lockService.setWindowFocused(false);
    // Now off screen entirely — stop animating, and (via the visibility
    // listener) stop claiming the user is present.
    _windowActivity.onHidden();
    // 🔴 ОДИН РАЗ ГОВОРИМ, КУДА ДЕЛОСЬ ОКНО (28.09.2026). На Windows крестик —
    // это «закрыть»: человек, не знающий про трей, решит, что приложение
    // вышло и сообщения больше не придут. Windows 11 к тому же прячет новые
    // значки под «^». Как у Telegram — одно уведомление при первом скрытии.
    if (Platform.isWindows && !DesktopUiPrefs.trayHintShown.value) {
      unawaited(DesktopUiPrefs.markTrayHintShown());
      unawaited(
        _notifService?.showAppNotice(
          title: l10n.desktopTrayHintTitle,
          body: l10n.desktopTrayHintBody,
        ),
      );
    }
  }

  /// D-2: tells the controller whether a human can actually see this app.
  ///
  /// Desktop hides to the tray instead of quitting, so without this the
  /// controller's `_appInForeground` stayed at its `true` default from launch
  /// to process death and the 3-second watchdog kept publishing a presence
  /// heartbeat — a desktop left in the tray overnight showed its user as
  /// online all night. That is precisely the lie the server-side fix
  /// (`last_presence_at_ms` split from `last_active_at_ms`) exists to remove,
  /// reproduced from the client side.
  ///
  /// Driven off [_windowActivity] rather than called from each window
  /// callback, so a path that shows the window WITHOUT raising focus — the
  /// tray icon and tray menu both call `windowManager.show()` directly, and
  /// window_manager has no "shown" event — cannot leave presence stale.
  /// One signal, one listener, every path covered.
  ///
  /// Gated on VISIBILITY rather than focus: a visible-but-unfocused window
  /// means the user is right there, with the chat beside whatever else they
  /// are doing.
  ///
  /// Calls an existing public controller method — no controller internals are
  /// touched (principle P-1).
  void _onWindowVisibilityChanged() {
    if (!_ready) return;
    final visible = _windowActivity.visible.value;
    try {
      _controller.setAppInForeground(visible);
    } catch (_) {
      // Presence is best-effort; never let it break window handling.
    }
    // Общие замки («Вход в приложение», «Личные») перезапираются по уходу в
    // фон — телефон сообщает об этом жизненным циклом, а окно компьютера,
    // спрятанное в трей, жизненного цикла не меняет. Скрытое окно и есть фон
    // (17.09.2026). Срок ожидания задаёт сам замок.
    try {
      _controller.security.onAppLifecycleStateChanged(
        visible ? AppLifecycleState.resumed : AppLifecycleState.hidden,
      );
    } catch (_) {}
  }

  @override
  void onWindowFocus() {
    _notifService?.setWindowFocused(true);
    _lockService.setWindowFocused(true);
    _windowActivity.onShown();
    _windowActivity.onFocused();
    // Вернулись в окно с открытой перепиской — её окошки в углу не нужны.
    final open = _section == DesktopSection.rooms
        ? _roomsSelection.selectedConvoId
        : _chatsSelection.selectedConvoId;
    if (open.isNotEmpty) {
      unawaited(DesktopNotificationWindows.instance.dismissFor(open));
    }
  }

  @override
  void onWindowBlur() {
    _notifService?.setWindowFocused(false);
    _lockService.setWindowFocused(false);
    // Deliberately does NOT pause animations: the window is still on screen,
    // and a frozen spinner next to another app reads as a hang.
    //
    // 🔴 НО ДЕКОРАЦИЮ — ГАСИМ. Рассуждение выше верно для того, что ЧТО-ТО
    // сообщает: замерший кружок рядом с чужим окном читается как зависание.
    // Постоянный дрейф обоев не сообщает ничего, а стоит непрерывной
    // перерисовки всего экрана на каждом вsync. Замер 12.09.2026: открытый чат
    // жёг 34,5% в фоне против 35,8% спереди, то есть защита
    // «в фоне не рисуем» на macOS не срабатывает совсем — окно без фокуса
    // остаётся `resumed`. См. [desktopWallpaperAnimModeFor].
    _windowActivity.onBlurred();
  }

  @override
  void onWindowMinimize() {
    _notifService?.setWindowFocused(false);
    _lockService.setWindowFocused(false);
    _windowActivity.onHidden();
  }

  @override
  void onWindowRestore() {
    _notifService?.setWindowFocused(true);
    _lockService.setWindowFocused(true);
    _windowActivity.onShown();
  }

  @override
  void onWindowResized() => _saveWindowGeometryDebounced();

  @override
  void onWindowMoved() => _saveWindowGeometryDebounced();

  /// Persists the window's current bounds shortly after the user stops
  /// resizing / moving (debounced to avoid a write per pixel).
  void _saveWindowGeometryDebounced() {
    if (!_isNativeDesktop) return;
    _winSaveDebounce?.cancel();
    _winSaveDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final bounds = await windowManager.getBounds();
        await DesktopWindowState.save(bounds);
      } catch (_) {}
    });
  }

  Future<void> _boot() async {
    // 🔴 Запуск, сменённый «Повторить», — выдохшийся: всё, что он сделает
    // после своего ожидания, относилось бы уже к НОВОМУ контроллеру.
    final gen = ++_bootGeneration;
    bool stale() => !mounted || gen != _bootGeneration;
    _bootSlowTimer?.cancel();
    _bootSlowTimer = Timer(_kBootSlowAfter, () {
      if (stale() || _ready || _error.isNotEmpty) return;
      setState(() => _bootSlow = true);
    });
    try {
      // Журнал событий — первым: разбирать потерю сообщения без него нечем.
      await DesktopDiagFileLog.start();
      await _lockService.init();
      await _controller.init();
      if (stale()) return;
      // Громкость плеера помнится между запусками (см.
      // [DesktopUiPrefs.playerVolume]) — ставим её до первого звука.
      unawaited(
        _controller.setSharedAudioVolume(DesktopUiPrefs.playerVolume.value),
      );
      if (!mounted) return;
      // PR4 (SPRINT2_AUDIT §16): construct AFTER controller.init() so the
      // ChangeNotifier subscribes to a populated `relayConnectionChanges`
      // stream. Dispose handled below in [dispose] / [_restart].
      _syncStatus?.dispose();
      _syncStatus = DesktopSyncStatusController(controller: _controller);
      _vm?.dispose();
      _vm = DesktopAppViewModel(
        controller: _controller,
        windowVisible: _windowActivity.visible,
      );
      // DLV-3: notice, once, that this desktop was offline long enough to have
      // missed mail. Purely local bookkeeping — see [DesktopAbsence].
      unawaited(DesktopAbsence.start());
      // Which chats were deleted on THIS desktop — read before the first chat
      // list is built, so a re-imported one never flashes into view.
      unawaited(DesktopDeletedChats.load());
      // Eager backfill kicker: bypass the WS-fresh short-circuit so HTTP
      // /v1/pending runs immediately. Idempotent — repeated calls dedup
      // by per-device seq cursor. Fire-and-forget; the 1-second pump
      // timer will retry on failure.
      unawaited(_controller.forceDesktopInboxBackfill());
      // Parity P1: pull the paired account's entitlement/premium state so the
      // user's OWN premium cosmetics (frame / cover / emoji-status / star) can
      // light up. Billing fails OPEN; fire-and-forget, never blocks boot.
      unawaited(_controller.refreshEntitlementsNow());
      // PR5 (SPRINT2_AUDIT §17): once relay catch-up is in flight, ask
      // one of the user's other devices (typically mobile) for a
      // recent-history window. Covers the fresh-pair / >24h-stale case
      // where the relay's 7-day mailbox doesn't suffice. Fire-and-
      // forget — the service has its own busy gate, staleness check,
      // and timeout, so it's safe to call on every boot.
      PeerHistoryService.instance.attach(_controller);
      // 🔴 25.09.2026: вместо «последних 250 раз в сутки» — догон с момента,
      // когда ПК последний раз был на связи, и повтор, пока телефон не ответит.
      unawaited(
        DesktopHistoryCatchUp.start(
          relayConnectionChanges: _controller.relayConnectionChanges,
          ownDeviceActivity: _controller.ownDeviceActivity,
          relayOnline: () => _controller.relayOnline,
        ),
      );
      _wireListeners();
      _initCallManager();
      await _initNotificationService();
      // Окно могли закрыть прямо во время запуска — тогда обновлять состояние
      // уже некому.
      if (stale()) return;
      _wireDeepLinks();
      // 🔴 Потерянный компьютер: команду «отключить» он не получит, а срок
      // без связи получит. Давно не связывался — спрашиваем пароль входа.
      unawaited(_lockIfOfflineTooLong());
      // Черновики переезжают из открытых настроек в зашифрованную базу: она
      // открыта только теперь, когда контроллер поднялся.
      unawaited(
        DesktopDraftStore.attachStorage(
          read: () => _controller.localValueGet(DesktopDraftStore.storageKey),
          write: (json) =>
              _controller.localValueSet(DesktopDraftStore.storageKey, json),
        ),
      );
      // Обои отдельных чатов (ключ телефона) и разовый перевод прежнего
      // `default` ПК в картинку «Ночной синий» — см. desktop_wallpaper.dart.
      unawaited(DesktopChatWallpapers.load());
      unawaited(_migrateDesktopDefaultWallpaper());
      _bootSlowTimer?.cancel();
      setState(() {
        _ready = true;
        _bootSlow = false;
        _connection = _syncStatus?.connection ?? ConnectionStatus.connecting;
      });
      // 🔴 Автозапуск «свёрнутым» (Windows): окно спрятали ещё до готовности,
      // и слушатель видимости тогда промолчал — `_ready` не было. Контроллер
      // так и считал себя на экране: «в сети» всю ночь, замки «в фоне» не
      // взводились (30.09.2026). Сообщаем пропущенное состояние сейчас.
      if (!_windowActivity.visible.value) _onWindowVisibilityChanged();
      // Замок, запертый ещё до готовности (Touch ID при запуске), — теперь он
      // виден и корню.
      _afterLockChange();
      // If a deep-link was buffered while we were booting, dispatch it now.
      final pending = _pendingDeepLink;
      if (pending != null) {
        _pendingDeepLink = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleDeepLink(pending);
        });
      }
    } catch (e) {
      if (stale()) return;
      _bootSlowTimer?.cancel();
      // Причину — в журнал: «Открыть папку журнала» ведёт именно туда.
      DesktopDiagFileLog.write('boot.failed ${e.runtimeType}: $e');
      final text = e.toString().trim();
      setState(() {
        _ready = false;
        _bootSlow = false;
        _error = text.isEmpty ? '${e.runtimeType}' : text;
      });
    }
  }

  /// «Повторить» на заставке: тот же путь, что у перезапуска после выхода, —
  /// свежий контроллер и новый запуск.
  void _retryBoot() => unawaited(_restart());

  /// Subscribes to `secretly://` URL events and resolves the cold-launch URL
  /// (if any) into the same handler used for runtime events. Safe to call
  /// multiple times — we cancel + resubscribe.
  void _wireDeepLinks() {
    final links = AppLinks();
    _deepLinkSub?.cancel();
    _deepLinkSub = links.uriLinkStream.listen((uri) {
      if (!_ready) {
        _pendingDeepLink = uri;
        return;
      }
      _handleDeepLink(uri);
    }, onError: (_) {});
    // Cold-launch URL (e.g. `open secretly://room/<convoId>` while Secretly
    // wasn't running). Wrapped in best-effort: the API is still flaky on some
    // Linux distros and we don't want to crash boot.
    unawaited(() async {
      try {
        final initial = await links.getInitialLink();
        if (initial == null) return;
        if (!mounted) return;
        if (!_ready) {
          _pendingDeepLink = initial;
          return;
        }
        _handleDeepLink(initial);
      } catch (_) {}
    }());
  }

  /// Dispatches a `secretly://` URI to the appropriate desktop view.
  ///
  /// Supported shapes (matches the schema used by mobile [main.dart]):
  ///   • `secretly://room/<convoId>`         — open an existing conversation
  ///   • profile-share URIs                  — open the chat with that profile
  void _handleDeepLink(Uri uri) {
    if (!_ready || !mounted) {
      _pendingDeepLink = uri;
      return;
    }
    // 🔴 Запертое окно ссылок не исполняет (30.09.2026): ссылку может открыть
    // любая веб-страница, а окно входа в комнату или переписка встали бы под
    // замок. Последняя пришедшая ссылка ждёт разблокировки
    // ([_afterLockChange]).
    if (_anyLockEngaged) {
      _pendingDeepLink = uri;
      return;
    }
    // 🔴 Приглашение в комнату: тот же экран входа, что на телефоне, с
    // проверкой и понятными отказами. Раньше ссылка на компьютере была
    // тупиком — её открывал браузер.
    final invite = tryParseRoomInviteUri(uri);
    if (invite != null) {
      unawaited(_openRoomInviteFromLink(invite));
      return;
    }
    // Profile-share URI ("secretly.app/profile/...") → resolve to a convo.
    final profileId = tryParseProfileShareUri(uri);
    if (profileId != null) {
      unawaited(_openProfileFromLink(profileId));
      return;
    }
    if (uri.scheme != 'secretly') return;
    if (uri.host == 'room') {
      final convoId = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first.trim()
          : '';
      if (convoId.isEmpty) return;
      unawaited(_openConvoOrReport(convoId));
      return;
    }
  }

  /// Запирает приложение, если компьютер слишком давно не выходил на связь.
  Future<void> _lockIfOfflineTooLong() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lock = _controller.security;
      final should = DesktopOfflineLock.shouldLock(
        lastContactAtMs:
            prefs.getInt(AppController.prefsLastServerContactAtMsKey) ?? 0,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        days: DesktopOfflineLock.normalizeDays(
          prefs.getInt(DesktopOfflineLock.prefsDaysKey),
        ),
        lockEnabled: lock.isEnabled(SecurityLockScope.app),
      );
      if (!should) return;
      await lock.lockNow(SecurityLockScope.app);
      if (mounted) setState(() {});
    } catch (_) {
      // Замок — защита, а не условие запуска: сбой не должен ронять окно.
    }
  }

  /// Показывает экран входа в комнату и, если вход удался, открывает её.
  Future<void> _openRoomInviteFromLink(RoomInviteTarget target) async {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    if (_isNativeDesktop) {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (_) {
        // Окно могло быть уже впереди — экран важнее.
      }
    }
    // Окном посередине — как «Вступить» в Telegram Desktop. Контекст —
    // навигатора окна: вызов приходит из ссылки, а не из раздела.
    final navContext = nav.context;
    if (!navContext.mounted) return;
    // Предел комнат — окном ПК, а не телефонной страницей покупки
    // (30.09.2026, см. `desktop_room_limit_dialog.dart`).
    if (!await desktopMayJoinRoom(navContext, _controller, target)) return;
    if (!navContext.mounted) return;
    await showDesktopScreenWindow<void>(
      navContext,
      builder: (_) => RoomInviteJoinScreen(
        controller: _controller,
        target: target,
        onJoined: _openConvoOrReport,
      ),
    );
  }

  /// Говорит человеку, что открыть переписку не вышло.
  ///
  /// 🔴 Молчание здесь — худший из возможных ответов. Человек нажал
  /// «Написать сообщение», нажал на уведомление, открыл ссылку — и НИЧЕГО не
  /// произошло. Он повторит нажатие, решит, что сломано приложение, и будет
  /// прав: сломано именно сообщение о причине.
  ///
  /// Тихо пропускаем только когда сказать физически некому: приложение ещё не
  /// собрано (ссылка пришла при запуске) — тогда и показывать некуда.
  void _reportOpenChatFailed(String message) {
    // 🔴 Слой берём У НАВИГАТОРА, а не ищем по контексту.
    //
    // `Overlay.of` ищет среди ПРЕДКОВ. У корня, который строит `MaterialApp`,
    // таких предков нет; не спасает ни контекст навигатора, ни контекст самого
    // `Overlay` — оба лежат ВЫШЕ слоя. Обе попытки падали «No Overlay widget
    // found», причём МОЛЧА: вызов асинхронный, исключение уходило в
    // неперехваченные, и снаружи это выглядело ровно как прежнее отсутствие
    // ответа. Нашлось только запуском приложения с захватом вывода.
    final overlay = _navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    DesktopSnackbar.showIn(overlay, message: message, kind: DSnackKind.error);
  }

  /// Путь до того, что человек сейчас читает: раздел → чат → тема.
  ///
  /// 🔴 Подписка на склад выбора стоит вокруг САМИХ крошек, а не в корне.
  /// Корень намеренно не перерисовывается на тике контроллера; склад выбора —
  /// другой источник, но и его подписка не должна пересобирать всё окно.
  Widget? _buildBreadcrumbs(BuildContext ctx, DesktopSection section) {
    final store = switch (section) {
      DesktopSection.rooms => _roomsSelection,
      DesktopSection.chats => _chatsSelection,
      _ => null,
    };
    final sectionName = switch (section) {
      DesktopSection.chats => l10n.chatsTitle,
      DesktopSection.rooms => l10n.desktopChatsRooms,
      DesktopSection.calls => l10n.desktopPrivacyCalls,
      DesktopSection.contacts => l10n.desktopNavContacts,
    };
    if (store == null) {
      return DesktopBreadcrumbs(crumbs: <String>[sectionName]);
    }
    return ListenableBuilder(
      listenable: store,
      builder: (_, _) {
        final convo = store.selected;
        final title = (convo?.title ?? '').trim();
        // Тема показывается только когда она ВЫБРАНА: «Общий» это отсутствие
        // темы, и писать его крошкой значит сообщать, что ничего не выбрано.
        final topicId = store.currentTopicId;
        final topic = topicId == null
            ? ''
            : store.topics
                      .where((t) => t.id == topicId)
                      .map((t) => t.title)
                      .firstOrNull ??
                  '';
        // 🔴 Имя раздела крошкой НЕ ставим, пока открыт чат: раздел уже
        // назван подсвеченной плиткой рейки в двух сантиметрах левее, и
        // повторять его значит отодвигать вправо то, ради чего строку и
        // читают. Без открытого чата раздел остаётся единственной крошкой —
        // иначе строка была бы пустой.
        return DesktopBreadcrumbs(
          crumbs: <String>[
            if (title.isEmpty) sectionName,
            if (title.isNotEmpty) title,
            if (topic.isNotEmpty) topic,
          ],
        );
      },
    );
  }

  /// Снимок рейки: непрочитанное по видам, закреплённые комнаты, свой профиль.
  ///
  /// 🔴 Собирается ЗДЕСЬ, потому что здесь уже есть шов к приложению. Сама
  /// рейка контроллер не импортирует: виджет с контроллером на руках заводит
  /// свою подписку, и именно так десктоп однажды набрал восемнадцать подписок.
  ///
  /// Закреплённые комнаты — не новая сущность: это то же закрепление, что и в
  /// списке чатов, и на телефоне тоже. Плитка появляется, когда комнату
  /// закрепляют, и исчезает, когда открепляют.
  Future<RailSnapshot> _loadRailSnapshot() async {
    final convos = await _controller.listConversations();
    // 🔴 ПЛИТКА РАЗДЕЛА СЧИТАЕТ РАЗГОВОРЫ, А НЕ СООБЩЕНИЯ (15.09.2026,
    // указание владельца).
    //
    // Складывалась сумма непрочитанных сообщений по всем чатам — и это число
    // ничего не сообщало: «347» бывает у любого, кто неделю не заходил, и по
    // нему не понять, это один шумный чат или тридцать ждущих ответа. Сама
    // плитка — не разговор, а ВХОД В СПИСОК, и отвечает она на вопрос
    // «сколько там меня ждёт», то есть сколько РАЗГОВОРОВ.
    //
    // У закреплённой переписки ниже число остаётся сообщениями: там плитка и
    // есть разговор.
    var directUnread = 0;
    var roomUnread = 0;
    final spaces = <RailSpace>[];
    // «Личные» под паролем на рейку не попадают и в счёт не идут: рейка видна
    // всегда, а плитка закреплённого личного чата открывала его без пароля
    // (30.09.2026).
    final hidePersonal = _controller.security.isEnabled(
      SecurityLockScope.personal,
    );
    for (final c in convos) {
      // Архив не считается: человек убрал переписку с глаз, и счётчик на рейке
      // возвращал бы её обратно.
      if (c.archivedAtMs != null) continue;
      if (hidePersonal && _controller.isPersonalChat(c.convoId)) continue;
      if (c.unreadCount > 0) {
        if (c.peerProfileId == null) {
          roomUnread += 1;
        } else {
          directUnread += 1;
        }
      }
      // 🔴 В ИЗБРАННОЕ МОЖНО ПОЛОЖИТЬ ЛЮБУЮ ПЕРЕПИСКУ, а не только комнату
      // (14.09.2026, указание владельца). Раньше на рейку попадали лишь
      // закреплённые КОМНАТЫ: человек, с которым переписываешься каждый день,
      // положить туда себя не мог.
      if (c.pinnedAtMs != null) {
        spaces.add(
          RailSpace(
            convoId: c.convoId,
            title: c.title.isEmpty ? '—' : c.title,
            unread: c.unreadCount,
            avatarPath: c.avatarPath,
            isRoom: c.peerProfileId == null,
          ),
        );
      }
    }
    return RailSnapshot(
      directUnread: directUnread,
      roomUnread: roomUnread,
      spaces: spaces,
      selfName: _controller.myNickname,
      // Не `myAvatarPath`: на спаренном компьютере своего файла нет, там
      // своё лицо приезжает вместе с метаданными профиля.
      selfAvatarPath: await _controller.resolvedOwnAvatarPath(),
      selfFrameId: _controller.myFrameId,
      // Отметка поддержки берётся оттуда же, откуда её берёт телефон, — из
      // контроллера. Считать её заново здесь значило бы завести второй ответ
      // на тот же вопрос.
      supportUnread: _controller.supportUnreadCount,
      supportAwaiting: _controller.supportAwaitingReply,
    );
  }

  /// 🔴 ССЫЛКА НА ПРОФИЛЬ ОТКРЫВАЕТ ПЕРЕПИСКУ ТОЛЬКО ПО СОГЛАСИЮ (30.09.2026).
  ///
  /// Ссылку `secretly://profile/…` может открыть любая веб-страница, а общий
  /// путь ([AppController.prepareSharedProfileConversation]) молча принимает
  /// запрос переписки от этого профиля и отправляет ему отметки «доставлено»
  /// и «прочитано» — страница узнавала, что аккаунт жив и чей он. Теперь
  /// сначала спрашиваем; ожидающий запрос открываем как запрос, не принимая.
  Future<void> _openProfileFromLink(String profileId) async {
    final pid = normalizeSharedProfileId(profileId);
    if (pid.isEmpty) return;
    Conversation? request;
    var name = '';
    try {
      for (final c in await _controller.listConversations()) {
        if (c.convoId == 'req:$pid') {
          request = c;
          break;
        }
      }
      final resolved = (await _controller.resolveConvoTitle(pid)).trim();
      if (resolved != pid) name = resolved;
    } catch (_) {
      // Без имени и запроса спросим по короткому номеру профиля.
    }
    if (!mounted) return;
    if (_isNativeDesktop) {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (_) {}
    }
    final ok = await _confirmProfileLink(name: name, profileId: pid);
    if (!ok || !mounted) return;
    if (request != null) {
      await _openConvoOrReport(request.convoId);
      return;
    }
    await _openProfileChatByDeepLink(pid);
  }

  /// «Открыть этот чат?» — с именем, если оно известно, и коротким номером.
  Future<bool> _confirmProfileLink({
    required String name,
    required String profileId,
  }) async {
    final nav = _navigatorKey.currentState;
    final navContext = _navigatorKey.currentContext;
    if (nav == null || navContext == null || !navContext.mounted) return false;
    final shortId = profileId.length <= 12
        ? profileId
        : '${profileId.substring(0, 6)}…'
              '${profileId.substring(profileId.length - 4)}';
    final strings = l10n;
    final ok = await DesktopDialog.show<bool>(
      navContext,
      title: strings.desktopProfileLinkTitle,
      size: DDialogSize.small,
      body: Text(
        name.isEmpty
            ? strings.desktopProfileLinkBodyUnknown(shortId)
            : strings.desktopProfileLinkBody(name, shortId),
        style: DType.body.copyWith(
          color: DColors.of(navContext).textSecondary,
        ),
      ),
      primary: DDialogAction(
        label: strings.desktopProfileLinkOpen,
        onPressed: () => nav.maybePop(true),
      ),
      secondary: DDialogAction(
        label: strings.cancel,
        onPressed: () => nav.maybePop(false),
      ),
    );
    return ok == true;
  }

  /// Открыть (при необходимости — завести) личную переписку с профилем.
  ///
  /// Сюда приходят кнопка «Написать сообщение» в разделе «Контакты» и
  /// подтверждённая ссылка на профиль ([_openProfileFromLink]). Раньше оба
  /// отказа были молчаливыми.
  Future<void> _openProfileChatByDeepLink(String profileId) async {
    String? convoId;
    try {
      convoId = await _controller.prepareSharedProfileConversation(profileId);
    } catch (_) {
      convoId = null;
    }
    if (!mounted) return;
    if (convoId == null || convoId.isEmpty) {
      // Ровно та же подпись, что у выбора человека в «Новом чате»: причина
      // одна и та же — профиля нет на сервере ключей либо переписку не удалось
      // подготовить к отправке.
      _reportOpenChatFailed(l10n.desktopChatsStartFailed);
      return;
    }
    await _openConvoOrReport(convoId);
  }

  /// Открыть переписку и СКАЗАТЬ, если не вышло.
  ///
  /// Через это ходят все, кто открывает переписку «извне»: нажатие на
  /// уведомление, ссылка `secretly://room/...`, плитка комнаты на рейке. У
  /// всех троих отказ выглядел одинаково — как будто нажатия не было.
  Future<void> _openConvoOrReport(String convoId) async {
    final opened = await _openConvoByIdFromDeepLink(convoId);
    if (!opened && mounted) {
      _reportOpenChatFailed(l10n.desktopChatNotFound);
    }
  }

  /// Открывает переписку по идентификатору. Возвращает `false`, если её нет —
  /// чтобы вызывающая сторона могла сказать об этом, а не промолчать.
  Future<bool> _openConvoByIdFromDeepLink(String convoId) async {
    try {
      final convos = await _controller.listConversations();
      Conversation? match;
      for (final c in convos) {
        if (c.convoId == convoId) {
          match = c;
          break;
        }
      }
      if (match == null || !mounted) return false;
      // 🔴 Личная переписка — только после пароля «Личных» (30.09.2026): сюда
      // приходят уведомления, ссылки `secretly://room/…` и плитки рейки, и
      // все они открывали личный чат без вопросов. Окно — вперёд до вопроса:
      // спрашивать пароль в спрятанном окне некому.
      if (desktopPersonalChatHidden(_controller, match.convoId)) {
        if (_isNativeDesktop) {
          try {
            await windowManager.show();
            await windowManager.focus();
          } catch (_) {}
        }
        final navContext = _navigatorKey.currentContext;
        if (navContext == null || !navContext.mounted) return true;
        final ok = await desktopUnlockPersonalChat(
          navContext,
          _controller,
          match.convoId,
        );
        // Отказ от пароля — не «переписка не найдена»: молчим.
        if (!ok || !mounted) return true;
      }
      final isGroup = match.peerProfileId == null;
      if (isGroup) {
        _roomsSelection.select(match);
      } else {
        _chatsSelection.select(match);
      }
      // 🔴 РАЗДЕЛ ПЕРЕКЛЮЧАЕТ ОБОЛОЧКА, А НЕ КОРЕНЬ.
      //
      // Здесь стоял `setState(() => _section = ...)`, и это была мёртвая
      // запись: `_section` у корня — ЗЕРКАЛО, его пишет сама оболочка в
      // `contentBuilder`, а `initialSection` она читает один раз при создании.
      // То есть переписка выбиралась в нужном складе, но раздел оставался
      // прежним — и человек не видел ничего.
      //
      // Путь этот не редкий: по нему открываются нажатие на уведомление,
      // ссылка `secretly://room/...`, ссылка на профиль, кнопка «Написать
      // сообщение» в контактах и плитка комнаты на рейке. Во всех этих
      // случаях, если открытая комната была не в текущем разделе, ничего
      // видимого не происходило.
      //
      // Тот же способ уже использует поиск ⌘K — он единственный делал это
      // правильно.
      final target = isGroup ? DesktopSection.rooms : DesktopSection.chats;
      _shellSelectSection?.call(target);
      if (mounted) setState(() => _section = target);
      // Surface the window so the user actually sees the chat.
      if (_isNativeDesktop) {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
      }
      return true;
    } catch (_) {
      // Причину не разбираем: для человека «не открылось» это одно событие
      // независимо от того, упал ли запрос списка или чего-то не хватило в
      // базе. Сказать об этом — забота вызывающей стороны.
      return false;
    }
  }

  /// Keeps the tray tooltip showing the unread count.
  ///
  /// A tray-resident app spends most of its life with the window hidden, so
  /// the tray icon is the only thing the user can see — and it said only
  /// "Secretly" no matter how much was waiting.
  ///
  /// Debounced and gated on the number actually CHANGING: the controller's
  /// change bus fires constantly on a paired client, and setToolTip is a
  /// platform-channel round trip.
  Timer? _trayDebounce;
  int _lastTrayUnread = -1;

  void _refreshTrayBadgeSoon() {
    if (!_isNativeDesktop) return;
    _trayDebounce?.cancel();
    _trayDebounce = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted || !_ready) return;
      var total = 0;
      try {
        for (final c in await _controller.listConversations()) {
          // Archived chats are deliberately out of sight; counting them would
          // send the user hunting for messages they chose to put away.
          if (c.archivedAtMs != null) continue;
          total += c.unreadCount;
        }
      } catch (_) {
        return;
      }
      if (total != _lastTrayUnread) {
        _lastTrayUnread = total;
        // 🔴 Значок в Dock — ЕДИНСТВЕННЫЙ видимый след непрочитанного, когда
        // окно спрятано: подсказку в трее надо ещё навести и подождать, а
        // заголовка у спрятанного окна нет вовсе.
        unawaited(_dockBadge.set(total));
      }
      // Значок, подсказка и меню трея. Служба сама пропускает то, что не
      // изменилось, — звать её на каждое событие шины дёшево.
      final notif = _notifService;
      final until = notif?.doNotDisturbUntil;
      // Windows: число поверх кнопки на панели задач — как у Telegram.
      unawaited(
        DesktopTaskbar.setUnread(
          total,
          muted: notif?.doNotDisturb ?? false,
          description: l10n.desktopThreadUnreadCount(total),
        ),
      );
      await DesktopTrayService.instance.update(
        l10n: l10n,
        unread: total,
        muted: notif?.doNotDisturb ?? false,
        mutedUntilLabel: until == null ? null : _trayTimeLabel(until),
      );
    });
  }

  /// «до 14:30» — сегодня; «до 29 сент., 09:00» — если срок за полночью.
  String _trayTimeLabel(DateTime until) {
    final now = DateTime.now();
    final sameDay = until.year == now.year &&
        until.month == now.month &&
        until.day == now.day;
    final locale = l10n.localeName;
    return sameDay
        ? DateFormat.Hm(locale).format(until)
        : DateFormat.MMMd(locale).add_Hm().format(until);
  }

  /// 🔴 ОДИН РАЗ: `default` ПК → картинка «Ночной синий» (28.09.2026).
  ///
  /// До 28.09 плитка «Ночной синий» на ПК носила id `default`, а телефон под
  /// тем же id рисует «Классику» — градиент. Теперь ПК рисует `default` как
  /// телефон, и тем, у кого он был выбран, ставим ту картинку, которую они
  /// видели, — фон не меняется без спроса.
  Future<void> _migrateDesktopDefaultWallpaper() async {
    const flag = 'desktop_wallpaper_default_migrated_v1';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(flag) ?? false) return;
      if (_controller.defaultChatWallpaperId == 'default') {
        await _controller.setDefaultChatWallpaperId(
          desktopLegacyDefaultWallpaperId(),
        );
      }
      await prefs.setBool(flag, true);
    } catch (_) {
      // Не вышло сейчас — попробуем при следующем запуске.
    }
  }

  Future<void> _showFromTray() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
    _windowActivity.onShown();
  }

  /// Everything the ROOT widget reads out of the controller. Any change here
  /// must repaint the root; anything else is a section's own business.
  String _rootSignature() => <String>[
    _controller.appThemePresetId,
    _controller.darkMode ? 'dark' : 'light',
    _controller.indicatorColorPresetId,
    _controller.chatBubbleStylePresetId,
    _controller.appLocalePreference,
    _controller.requiresDesktopProfileSelection ? '1' : '0',
  ].join('|');

  String _lastRootSignature = '';

  void _wireListeners() {
    _changedSub?.cancel();
    _changedSub = _controller.changed.listen((_) {
      // D-5: keep the leaf-readable mirror in step with the controller so the
      // «Анимация рамок и статусов» setting reaches widgets that have no
      // controller reference. Idempotent — a no-op write notifies nobody.
      DesktopUiPrefs.syncPeerCosmeticAnim(_controller.peerCosmeticAnimEnabled);

      // Rebuild the ROOT only when something the root itself renders has
      // changed.
      //
      // `changed` is the controller's catch-all invalidation bus and it fires
      // constantly on a paired client — the outbox pump, the service watchdog,
      // presence heartbeats, drains, receipts. Rebuilding the whole desktop
      // tree on each of those kept the rasteriser submitting frames
      // continuously: measured at ~22% of a core sitting idle on a paired
      // account, with `flutter::Rasterizer::Draw` live in every sample.
      //
      // Nothing is lost by skipping: every section (chats, contacts, details,
      // settings) owns its own `changed` subscription and reloads itself. The
      // root only renders the theme preset, the locale and the
      // splash/onboarding/shell choice.
      _refreshTrayBadgeSoon();
      final sig = _rootSignature();
      if (sig == _lastRootSignature) return;
      _lastRootSignature = sig;
      if (mounted) setState(() {});
    });

    // 🔴 ОДИН ИСТОЧНИК НА ОБА УКАЗАТЕЛЯ (26.09.2026). Точка на портрете и
    // пилюля в подвале показывают одно и то же состояние связи, но считали
    // его порознь: пилюля — по выдержанному состоянию, точка — по каждому
    // событию сокета. На запуске, где подключений подряд несколько, они
    // мигали вразнобой. Теперь точка берёт то же выдержанное состояние.
    _detachSyncPhase?.call();
    _detachSyncPhase = null;
    final sync = _syncStatus;
    if (sync != null) {
      void onSyncPhase() {
        if (!mounted) return;
        final next = sync.connection;
        if (next == _connection) return;
        setState(() => _connection = next);
      }

      sync.addListener(onSyncPhase);
      _detachSyncPhase = () => sync.removeListener(onSyncPhase);
    }

    _restartSub?.cancel();
    _restartSub = _controller.restartRequested.listen((_) => _restart());

    // Замок «Вход в приложение» заперли или открыли — перерисовать корень:
    // экран блокировки живёт здесь.
    _securitySub?.cancel();
    _securitySub = _controller.security.changed.listen((_) {
      if (!mounted) return;
      setState(() {});
      _afterLockChange();
    });
  }

  void _initCallManager() {
    _disposeCallManager();
    final cm = CallManager(controller: _controller)..start();
    CallManager.instance = cm;
    _callStateListener = _onCallStateChanged;
    cm.state.addListener(_callStateListener!);
    _callManager = cm;
    _directCall = CallManagerDesktopCall(cm);
    // Слой отдельных окон опрашиваем сразу: решение «где рисовать звонок»
    // принимается при построении кадра и ждать ответа не может.
    unawaited(DesktopChildWindows.instance.isSupported());
    final callWindow = DesktopDirectCallWindow(
      builder: _buildCallWindowApp,
      onCloseRequested: _onCallWindowCloseRequested,
      // Звонка уже нет — крестик закрывает окно сам (см. окно звонка).
      callActive: () => cm.state.value.isActive,
    );
    callWindow.changes.addListener(_onCallWindowChanged);
    _callWindow = callWindow;
    // Входящий в своём окне — системное уведомление о нём не нужно.
    DesktopNotificationService.callShownInOwnWindow = (s) =>
        _callWindow?.handles(s) ?? false;
    // Окошки уведомлений (Windows) говорят на языке приложения.
    DesktopNotificationWindows.instance
      ..locale = (() => _controller.appLocaleOverride)
      ..resolveLocale = _controller.resolveAppUiLocale;
    _notifService?.attachCallManager(cm);
    // Комнатные созвоны — свой управляющий, ровно как на телефоне.
    final rcm = RoomCallManager(controller: _controller)..start();
    RoomCallManager.instance = rcm;
    // Движок созвона отпускается при любом переходе в «нет созвона» — с
    // первой минуты, а не с первого открытого окна созвона (30.09.2026).
    DesktopRoomCallMediaGuard.attach(rcm);
    _roomCallManager = rcm;
    rcm.state.addListener(_syncScreenShareGuard);
  }

  Future<void> _initNotificationService() async {
    if (!_isNativeDesktop) return;
    await _disposeNotificationService();
    // Уведомления здесь показывает служба компьютера, в том числе когда окно
    // скрыто: без флага контроллер отправлял их на системный путь телефона,
    // которого на компьютере нет, и скрытое окно молчало (17.09.2026).
    _controller.setDesktopHostedNotifications(true);
    final svc = DesktopNotificationService(controller: _controller);
    await svc.init(callManager: _callManager);
    if (!mounted) {
      await svc.dispose();
      return;
    }
    _notifService = svc;
    DesktopNotificationService.instance = svc;
    // Окно в фокусе молчит только об открытой переписке — как Telegram.
    svc.openConvoId = () => switch (_section) {
      DesktopSection.chats => _chatsSelection.selectedConvoId,
      DesktopSection.rooms => _roomsSelection.selectedConvoId,
      _ => '',
    };
    // Замки знает корень: пока заперто, уведомления без имени, текста и
    // кнопок (см. [desktopEffectivePreviewLevel]).
    svc.lockEngaged = () => _anyLockEngaged;
    svc.personalHidden = (convoId) =>
        _controller.isPersonalChat(convoId) &&
        _controller.security.isLocked(SecurityLockScope.personal);
    _syncScreenShareGuard();
    _notifTapSub = svc.onTap.listen(_onNotificationTap);
    // «Без звука» меняет значок и меню трея — в том числе когда срок «на
    // час» истекает сам.
    svc.doNotDisturbListenable.addListener(_refreshTrayBadgeSoon);
    _refreshTrayBadgeSoon();
    // Запущены свёрнутыми — окно не в фокусе, уведомления должны идти.
    if (!_windowActivity.visible.value) svc.setWindowFocused(false);
  }

  Future<void> _disposeNotificationService() async {
    _notifService?.doNotDisturbListenable.removeListener(_refreshTrayBadgeSoon);
    // Окошки уведомлений (Windows) уходят вместе со службой: щелчок по ним
    // вёл бы в её закрытый поток, а при смене профиля — в чужую переписку.
    unawaited(DesktopNotificationWindows.instance.dismissAll());
    await _notifTapSub?.cancel();
    _notifTapSub = null;
    final svc = _notifService;
    _notifService = null;
    if (DesktopNotificationService.instance == svc) {
      DesktopNotificationService.instance = null;
    }
    if (svc != null) {
      await svc.dispose();
    }
  }

  void _onNotificationTap(String payload) {
    if (!_isNativeDesktop) return;
    final isCallPayload = payload.startsWith('call:');
    // Под замком нажатие только выводит окно с замком: переписку за замком
    // не открываем (30.09.2026).
    if (isCallPayload ||
        payload == kDesktopNotificationShowAppPayload ||
        _anyLockEngaged) {
      // The toast / full-screen call UI already reflects state via CallManager;
      // just surface the window so the user can react.
      unawaited(() async {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
      }());
      return;
    }
    final convoId = payload.trim();
    if (convoId.isEmpty || !mounted) return;
    // Open the actual conversation the notification is about — selects it in
    // the right section (chat / room) and raises the window — instead of just
    // switching to the Chats tab. Reuses the deep-link open path.
    unawaited(_openConvoOrReport(convoId));
  }

  void _disposeCallManager() {
    final cm = _callManager;
    final listener = _callStateListener;
    if (cm != null && listener != null) {
      cm.state.removeListener(listener);
    }
    _callStateListener = null;
    if (CallManager.instance == cm) {
      CallManager.instance = null;
    }
    if (cm != null) {
      unawaited(cm.dispose());
    }
    _callManager = null;
    _directCall = null;
    final callWindow = _callWindow;
    _callWindow = null;
    DesktopNotificationService.callShownInOwnWindow = null;
    if (callWindow != null) {
      callWindow.changes.removeListener(_onCallWindowChanged);
      unawaited(callWindow.dispose());
    }
    DesktopCallPresence.instance.syncDirect(active: false, callId: '');
    final rcm = _roomCallManager;
    if (RoomCallManager.instance == rcm) {
      RoomCallManager.instance = null;
    }
    if (rcm != null) {
      rcm.state.removeListener(_syncScreenShareGuard);
      unawaited(rcm.dispose());
    }
    _roomCallManager = null;
    // Окно созвона комнаты уходит вместе с его управляющим: перезапуск (смена
    // профиля) не должен оставить на экране окно созвона, которого уже нет.
    // Закрытие отменяет и окно, которое ещё открывается.
    unawaited(DesktopRoomCallWindows.close());
    _dismissIncomingToast();
  }

  void _onCallPresenceChanged() {
    if (mounted) setState(() {});
  }

  void _onDeviceLockChanged() {
    if (!mounted) return;
    setState(() {});
    _afterLockChange();
  }

  /// Было ли заперто в прошлый раз — действуем на смене, а не на каждом
  /// оповещении замка.
  bool _lockWasEngaged = false;

  /// Замок заперли или открыли.
  ///
  /// Заперли — гасим окошки уведомлений Windows: они висят поверх всех окон
  /// с именем, текстом и кнопкой «Ответить», показанными ещё до замка.
  /// Открыли — исполняем ссылку, пришедшую под замком ([_handleDeepLink]).
  void _afterLockChange() {
    final engaged = _anyLockEngaged;
    if (engaged == _lockWasEngaged) return;
    _lockWasEngaged = engaged;
    if (engaged) {
      unawaited(DesktopNotificationWindows.instance.dismissAll());
      return;
    }
    final pending = _pendingDeepLink;
    if (pending == null || !_ready) return;
    _pendingDeepLink = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleDeepLink(pending);
    });
  }

  /// Показ экрана был включён в прошлый раз.
  bool _screenShareGuardOn = false;

  /// 🔴 СВОЙ ПОКАЗ ЭКРАНА — УВЕДОМЛЕНИЯ МОЛЧАТ (30.09.2026). Защита в службе
  /// была, но включать её было нечему: имена и текст сообщений попадали в
  /// показ. Уже показанные окошки Windows (поверх всех окон, то есть в кадре)
  /// гасим сразу.
  void _syncScreenShareGuard() {
    final on = desktopScreenShareActive(
      direct: _callManager?.state.value,
      room: _roomCallManager?.state.value,
    );
    _notifService?.setScreenShareActive(on);
    if (on && !_screenShareGuardOn) {
      unawaited(DesktopNotificationWindows.instance.dismissAll());
    }
    _screenShareGuardOn = on;
  }

  void _onCallStateChanged() {
    if (!mounted) return;
    final s = _callManager?.state.value;
    if (s != null) {
      // Новый звонок — во всё окно, даже если прошлый был свёрнут.
      DesktopCallPresence.instance.syncDirect(
        active: s.isActive,
        callId: s.callId,
      );
      _announceCallEnd(s);
      _prevDirectPhase = s.phase;
      unawaited(_callWindow?.sync(s, title: _callWindowTitle(s)));
    }
    _syncScreenShareGuard();
    setState(() {});
    _syncIncomingToast();
  }

  /// Окно звонка открылось, закрылось или не смогло открыться.
  ///
  /// Не открылось — звонок возвращается в главное окно: слой поверх окна и
  /// всплывашка входящего снова рисуются здесь.
  void _onCallWindowChanged() {
    if (!mounted) return;
    setState(() {});
    _syncIncomingToast();
    // Окно не открылось — системное уведомление о входящем тоже прежним
    // путём: пока звонок числился «в своём окне», его пропустили.
    _notifService?.recheckIncomingCall();
  }

  /// «Звонок в отдельном окне» переключили посреди звонка — или на macOS
  /// включили экранный диктор, и своих окон больше нет (29.09.2026).
  ///
  /// 🔴 Раньше настройка действовала только со следующего звонка: выключили —
  /// окно идущего разговора оставалось, а главное окно его не рисовало, ведь
  /// «звонок в своём окне» больше не считался; включили — наоборот.
  void _onCallPresentationChanged() {
    if (!mounted) return;
    final cm = _callManager;
    final window = _callWindow;
    if (cm != null && window != null) {
      final s = cm.state.value;
      // Свёрнутый в главном окне разговор, уехавший в своё окно, не должен
      // остаться ещё и мини-окном.
      if (window.handles(s)) DesktopCallPresence.instance.expandDirect();
      unawaited(window.sync(s, title: _callWindowTitle(s)));
    }
    // Созвон комнаты: своё окно больше нельзя — оно уходит, созвон идёт
    // дальше мини-окном и полосой «Вернуться», как после крестика.
    final ownAllowed = DesktopUiPrefs.callInOwnWindow.value &&
        DesktopChildWindows.instance.supportedCached == true;
    if (!ownAllowed && DesktopRoomCallWindows.openRoomId != null) {
      unawaited(DesktopRoomCallWindows.close());
    }
    setState(() {});
    _syncIncomingToast();
  }

  /// Шапка окна звонка: имя собеседника, как в Telegram.
  String _callWindowTitle(CallState s) {
    final name = desktopCallPeerKnownName(s);
    return name.isEmpty ? 'Secretly' : name;
  }

  /// Крестик окна звонка: входящий — отклонить, разговор — положить трубку.
  void _onCallWindowCloseRequested() {
    final cm = _callManager;
    if (cm == null) return;
    if (cm.state.value.phase == CallPhase.ringingIncoming) {
      unawaited(cm.declineIncoming());
    } else {
      unawaited(cm.hangup());
    }
  }

  /// «Написать» из окна звонка: главное окно выходит вперёд с перепиской,
  /// окно звонка остаётся на месте.
  Future<void> _openChatFromCallWindow(String peerProfileId) async {
    if (_isNativeDesktop) {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (_) {}
    }
    await _openProfileChatByDeepLink(peerProfileId);
  }

  /// Содержимое окна звонка — целиком: своё окно, свой навигатор и слой
  /// всплывающих (меню устройств, подсказки открываются в НЁМ, а не в главном
  /// окне). Язык и размер текста — те же, что у приложения; палитра всегда
  /// тёмная, как у звонка.
  Widget _buildCallWindowApp(BuildContext _) {
    final cm = _callManager;
    return DesktopChildWindowApp(
      locale: _controller.appLocaleOverride,
      resolveLocale: _controller.resolveAppUiLocale,
      home: cm == null
          ? const SizedBox.shrink()
          : ValueListenableBuilder<CallState>(
              valueListenable: cm.state,
              builder: (ctx, s, _) => s.phase == CallPhase.ringingIncoming
                  ? _buildIncomingCallWindow(ctx, cm, s)
                  : _buildCallWindowScreen(cm, s),
            ),
    );
  }

  /// Входящий — в своём маленьком окне поверх всех.
  Widget _buildIncomingCallWindow(
    BuildContext ctx,
    CallManager cm,
    CallState s,
  ) {
    final l10n = AppLocalizations.of(ctx)!;
    final knownName = desktopCallPeerKnownName(s);
    final peer = s.peerProfileId.trim();
    return ColoredBox(
      color: kDColorsDark.bg,
      child: Center(
        child: IncomingCallToast(
          callerName: desktopCallPeerTitle(s, l10n),
          avatarName: knownName,
          subtitle: knownName.isEmpty
              ? l10n.appTitle
              : l10n.callRecordIncomingCall,
          callerSeed: s.peerProfileId,
          callerImage: Avatar.fileImage(s.peerAvatarPath),
          video: s.isVideo,
          onAccept: () => unawaited(cm.acceptIncoming()),
          onDecline: () => unawaited(cm.declineIncoming()),
          onReplyWithText: peer.isEmpty
              ? null
              : () {
                  unawaited(cm.declineIncoming());
                  unawaited(_openChatFromCallWindow(peer));
                },
        ),
      ),
    );
  }

  /// Разговор — тот же экран, что внутри приложения, в режиме своего окна.
  Widget _buildCallWindowScreen(CallManager cm, CallState s) {
    final call = _directCall;
    if (call == null || !s.isActive) {
      return ColoredBox(color: kDColorsDark.bg);
    }
    final peer = s.peerProfileId.trim();
    return OneToOneCallScreen(
      call: call,
      peerName: s.peerName.trim(),
      peerImage: Avatar.fileImage(s.peerAvatarPath),
      onEnd: () => unawaited(cm.hangup()),
      onOpenChat: peer.isEmpty
          ? null
          : () => unawaited(_openChatFromCallWindow(peer)),
      ownWindow: DesktopCallOwnWindow(
        pinned: DesktopUiPrefs.callWindowPinned,
        onTogglePin: () => unawaited(_callWindow?.togglePin()),
        onSetFullScreen: (on) async => _callWindow?.setFullScreen(on),
      ),
    );
  }

  /// 🔴 ЗВОНОК КОНЧАЛСЯ МОЛЧА (24.09.2026). Окно звонка просто исчезало — а
  /// свёрнутое мини-окно тем более: «не ответил», «отклонил», «связь
  /// оборвалась» выглядели одинаково, как пропавшее окно. Телефон на этот
  /// случай держит экран «звонок завершён» две секунды; компьютер говорит
  /// то же всплывашкой, которая не мешает дальше работать.
  ///
  /// Не говорим, когда трубку положил сам человек (он знает) и когда не
  /// взяли входящий (о пропущенном скажет журнал звонков).
  void _announceCallEnd(CallState s) {
    if (s.phase != CallPhase.ended) return;
    if (s.callId.isEmpty || s.callId == _endAnnouncedFor) return;
    _endAnnouncedFor = s.callId;
    final reason = s.endReason;
    if (reason == CallEndReason.localHangup ||
        reason == CallEndReason.localDecline) {
      return;
    }
    if (_prevDirectPhase == CallPhase.ringingIncoming) return;
    final ctx = _overlayHostKey.currentContext;
    if (ctx == null) return;
    final l10n = AppLocalizations.of(ctx)!;
    final connectedAt = s.connectedAtMs;
    final failure = s.failure;
    final String message;
    switch (reason) {
      case CallEndReason.remoteDecline:
        message = l10n.callDeclined;
      case CallEndReason.timeout:
        message = l10n.callNoAnswer;
      case CallEndReason.remoteSuperseded:
        message = l10n.callReplacedByNewerAttempt;
      case CallEndReason.error:
        message = failure != null
            ? callErrorText(l10n, failure)
            : l10n.callConnectionError;
      case CallEndReason.remoteHangup:
      case CallEndReason.localHangup:
      case CallEndReason.localDecline:
      case null:
        message = connectedAt == null
            ? l10n.callEnded
            : l10n.desktopCallEndedAfter(desktopCallMiniDuration(connectedAt));
    }
    DesktopSnackbar.show(
      ctx,
      message: message,
      kind: reason == CallEndReason.error ? DSnackKind.error : DSnackKind.info,
    );
  }

  void _syncIncomingToast() {
    final cm = _callManager;
    if (cm == null) {
      _dismissIncomingToast();
      return;
    }
    final s = cm.state.value;
    // Входящий в своём окне поверх всех — всплывашка в главном окне не нужна,
    // и главное окно вперёд не выводим (29.09.2026, Р1).
    final shouldShow = s.phase == CallPhase.ringingIncoming &&
        !(_callWindow?.handles(s) ?? false);
    if (!shouldShow) {
      _dismissIncomingToast();
      return;
    }
    // Имя и фото звонящего приходят ПОЗЖЕ самого звонка (контакт или
    // метаданные профиля). Окно, собранное один раз, так и показывало бы
    // «Входящий звонок» — поэтому при их появлении оно пересобирается
    // (17.09.2026).
    final toastKey = '${s.peerName.trim()}|${s.peerAvatarPath ?? ''}';
    if (_toastForCallId == s.callId &&
        _incomingToastDismiss != null &&
        _toastPeerKey == toastKey) {
      return;
    }
    final isNewCall = _toastForCallId != s.callId;
    _dismissIncomingToast();
    _toastForCallId = s.callId;
    _toastPeerKey = toastKey;
    // E11: surface the window so an incoming call is visible even when Secretly
    // is hidden to tray / minimized / unfocused (no CallKit on desktop).
    if (_isNativeDesktop && isNewCall) {
      unawaited(() async {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
      }());
    }
    // Defer to next frame so we have a live BuildContext with an Overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final overlayCtx = _overlayHostKey.currentContext;
      if (overlayCtx == null) return;
      final stillRinging =
          cm.state.value.phase == CallPhase.ringingIncoming &&
          cm.state.value.callId == _toastForCallId;
      if (!stillRinging) return;
      final l10n = AppLocalizations.of(overlayCtx)!;
      final live = cm.state.value;
      final knownName = desktopCallPeerKnownName(live);
      _incomingToastDismiss = IncomingCallToast.show(
        overlayCtx,
        // Без сырого profile_id: неизвестный — «Входящий звонок» и «?».
        callerName: desktopCallPeerTitle(live, l10n),
        avatarName: knownName,
        subtitle: knownName.isEmpty ? l10n.appTitle : l10n.callRecordIncomingCall,
        callerSeed: s.peerProfileId,
        callerImage: Avatar.fileImage(s.peerAvatarPath),
        video: s.isVideo,
        onAccept: () {
          _dismissIncomingToast();
          unawaited(cm.acceptIncoming());
        },
        onDecline: () {
          _dismissIncomingToast();
          unawaited(cm.declineIncoming());
        },
        // · ОТВЕТИТЬ ТЕКСТОМ. Сбрасываем звонок ТЕМ ЖЕ путём, что «Отклонить»,
        // и открываем переписку с этим человеком. Само сообщение пишет он —
        // приложение за него ничего не отправляет: «сейчас не могу» бывает
        // разным, и подставлять слова за человека значит говорить за него.
        onReplyWithText: s.peerProfileId.trim().isEmpty
            ? null
            : () {
                _dismissIncomingToast();
                unawaited(cm.declineIncoming());
                unawaited(_openProfileChatByDeepLink(s.peerProfileId.trim()));
              },
      );
      // PR-G bug 19: arm a hard watchdog so a stuck toast can never outlive
      // its expected lifetime. Cancelled in _dismissIncomingToast.
      _incomingToastWatchdog?.cancel();
      _incomingToastWatchdog = Timer(_kIncomingToastMaxVisible, () {
        if (!mounted) return;
        final live = _callManager;
        if (live == null) {
          _dismissIncomingToast();
          return;
        }
        final still = live.state.value;
        if (still.phase != CallPhase.ringingIncoming ||
            still.callId != _toastForCallId) {
          _dismissIncomingToast();
          return;
        }
        // Toast outlived expected ring window — force-end the call locally
        // so the UI never stays frozen even if upstream signals were lost.
        _dismissIncomingToast();
        unawaited(live.declineIncoming());
      });
    });
  }

  void _dismissIncomingToast() {
    final dismiss = _incomingToastDismiss;
    _incomingToastDismiss = null;
    _toastForCallId = '';
    _incomingToastWatchdog?.cancel();
    _incomingToastWatchdog = null;
    if (dismiss != null) {
      try {
        dismiss();
      } catch (_) {}
    }
  }

  Future<void> _restart() async {
    if (_restartTeardown) return;
    _restartTeardown = true;
    try {
      await _restartTeardownSteps();
    } finally {
      _restartTeardown = false;
    }
    await _boot();
  }

  /// Разборка перед новым запуском: всё прежнего контроллера — вон.
  Future<void> _restartTeardownSteps() async {
    // 🔴 СОСТОЯНИЕ ОКНА ПРЕЖНЕГО ПРОФИЛЯ НЕ ПЕРЕЖИВАЕТ ПЕРЕЗАПУСК (01.10.2026).
    // Сюда приходят выход, новая привязка, новый аккаунт и восстановление —
    // то есть профиль меняется, а окно остаётся. Раньше после новой привязки
    // поверх окна снова вставали настройки со старой моделью, стрелки
    // «назад»/«вперёд» вели в переписки прежнего аккаунта, а открытая
    // переписка из склада выбора открывалась в новом.
    setState(() {
      _ready = false;
      _error = '';
      _bootSlow = false;
      _modalOverlay = null;
    });
    _navHistory.clear();
    _chatsSelection.clear();
    _roomsSelection.clear();
    _popupsDismissedFor = '';
    await _disposeNotificationService();
    _disposeCallManager();
    // Drop the peer-history binding so a stale controller can't be poked
    // mid-restart. `_boot()` re-attaches once the new controller is up.
    DesktopHistoryCatchUp.stop();
    PeerHistoryService.instance.detach();
    await _changedSub?.cancel();
    _detachSyncPhase?.call();
    _detachSyncPhase = null;
    await _restartSub?.cancel();
    await _securitySub?.cancel();
    _vm?.dispose();
    _vm = null;
    // Чужое число на своём значке хуже, чем его отсутствие: при смене
    // профиля значок снимается сразу, не дожидаясь пересчёта.
    _lastTrayUnread = -1;
    unawaited(_dockBadge.clear());
    // Черновики уходящего профиля — в его базу и из памяти вон, ДО закрытия
    // контроллера: иначе новый профиль унаследовал бы их (см.
    // [DesktopDraftStore.detachStorage]).
    await DesktopDraftStore.detachStorage();
    try {
      await _controller.dispose();
    } catch (_) {}
    _controller = AppController();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    DesktopLinkRouter.handler = null;
    if (_windowListenerAttached) {
      try {
        windowManager.removeListener(this);
      } catch (_) {}
      _windowListenerAttached = false;
    }
    _winSaveDebounce?.cancel();
    _bootSlowTimer?.cancel();
    unawaited(_disposeNotificationService());
    _disposeCallManager();
    _changedSub?.cancel();
    _detachSyncPhase?.call();
    _detachSyncPhase = null;
    _restartSub?.cancel();
    _securitySub?.cancel();
    _deepLinkSub?.cancel();
    _chatsSelection.removeListener(_dropSelfProfileOnSelection);
    _roomsSelection.removeListener(_dropSelfProfileOnSelection);
    _chatsSelection.removeListener(_onChatsSelectionChanged);
    _roomsSelection.removeListener(_onRoomsSelectionChanged);
    DesktopUiPrefs.themeMode.removeListener(_onThemeModeChanged);
    DesktopCallPresence.instance.directMinimized.removeListener(
      _onCallPresenceChanged,
    );
    DesktopUiPrefs.callInOwnWindow.removeListener(_onCallPresentationChanged);
    DesktopChildWindows.instance.availability.removeListener(
      _onCallPresentationChanged,
    );
    _navHistory.dispose();
    _chatsSelection.dispose();
    _roomsSelection.dispose();
    _syncStatus?.dispose();
    _syncStatus = null;
    _vm?.dispose();
    _vm = null;
    // Чужое число на своём значке хуже, чем его отсутствие: при смене
    // профиля значок снимается сразу, не дожидаясь пересчёта.
    _lastTrayUnread = -1;
    unawaited(_dockBadge.clear());
    DesktopHistoryCatchUp.stop();
    PeerHistoryService.instance.detach();
    _controller.dispose();
    _lockService.locked.removeListener(_onDeviceLockChanged);
    _lockService.dispose();
    DesktopAbsence.stop();
    if (DesktopWindowActivity.hideHandler == _hideToTray) {
      DesktopWindowActivity.hideHandler = null;
    }
    _windowActivity.visible.removeListener(_onWindowVisibilityChanged);
    _windowActivity.dispose();
    super.dispose();
  }

  void _closeOverlay() => setState(() => _modalOverlay = null);

  /// Положить переписку в избранное — плитка «+» на рейке.
  ///
  /// 🔴 Избранное и закрепление — ОДНО И ТО ЖЕ, и это осознанно. Закреплённая
  /// переписка стоит сверху списка и плиткой на рейке; заводить рядом вторую
  /// сущность «избранное» значило бы держать два списка, которые разойдутся,
  /// и объяснять человеку разницу, которой нет.
  ///
  /// Выбор — тем же окном, которым выбирают, куда переслать: список всех
  /// переписок с поиском уже написан и ведёт себя привычно.
  Future<void> _addFavourite() async {
    final convo = await ForwardTargetDialog.show(
      _navigatorKey.currentContext ?? context,
      controller: _controller,
      title: l10n.desktopListAddFavourite,
    );
    if (convo == null) return;
    try {
      await _controller.setChatPinned(convoId: convo.convoId, pinned: true);
    } catch (_) {
      // Закрепление — местная настройка, падать тут нечему; молчим, а список
      // на следующем тике покажет правду.
    }
  }

  void _onThemeModeChanged() {
    if (mounted) setState(() {});
  }

  /// Держит схему окна в согласии с системной, пока выбрано «Авто».
  void _applyAutoThemeIfNeeded(BuildContext context) {
    if (!_ready) return;
    if (DesktopUiPrefs.themeMode.value != 'auto') return;
    final systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    if (_controller.darkMode == systemDark) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (DesktopUiPrefs.themeMode.value != 'auto') return;
      unawaited(_controller.setDarkMode(systemDark));
    });
  }

  void _openProfile() {
    setState(() => _selfProfileOpen = true);
    _shellOpenDetails?.call();
  }

  void _closeSelfProfile() {
    if (!_selfProfileOpen) return;
    setState(() => _selfProfileOpen = false);
    _shellCloseDetails?.call();
  }

  /// Открыть настройки; [sectionId] — сразу нужный раздел (например
  /// 'devices'), иначе первый.
  void _openSettings({String? sectionId}) {
    setState(() {
      _modalOverlay = SettingsWorkspace(
        onClose: _closeOverlay,
        vm: _vm,
        lockService: _lockService,
        initialSectionId: sectionId,
        // Профиль и настройки — соседние окна одного приложения, и строка
        // «Имя, фото, статус» теперь ОТКРЫВАЕТ профиль, а не рассказывает, где
        // он. Настройки при этом закрываются: два окна поверх друг друга ради
        // одного перехода.
        onOpenProfile: () {
          _closeOverlay();
          // 🔴 Открываем профиль СЛЕДУЮЩИМ кадром, а не в том же.
          //
          // Закрытие окна настроек перестраивает корень, и оболочка получает
          // новый экземпляр виджета. Просьба «открой правую панель», поданная
          // до этой перестройки, терялась между старым и новым деревом:
          // настройки закрывались, а профиль не открывался — и человек
          // оставался просто на списке чатов, без всякого объяснения.
          //
          // Пост-кадровый обработчик ждёт, пока дерево устаканится, и только
          // потом просит панель открыться. Задержки на глаз нет: это тот же
          // кадр анимации закрытия.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openProfile();
          });
        },
      );
    });
  }

  // Spotlight (Cmd+K) — captured here to share controller + selection stores
  // and to drive section switching through the shell API. We keep a handle to
  // [selectSection] that the shell publishes through its DesktopShellApi; the
  // first contentBuilder call captures the current ValueChanged<DesktopSection>
  // into [_shellSelectSection] for later use by the spotlight palette.
  ValueChanged<DesktopSection>? _shellSelectSection;
  VoidCallback? _shellOpenDetails;
  VoidCallback? _shellCloseDetails;

  /// Показана ли в правой панели МОЯ страница профиля.
  ///
  /// 🔴 Раньше свой профиль открывался отдельной страницей поверх всего окна —
  /// так, как не открывается больше ни один профиль в приложении. Теперь он в
  /// той же правой панели, что и чужие, а этот признак говорит панели, кого
  /// показывать: выбранную переписку или меня.
  bool _selfProfileOpen = false;

  /// ⌘K — курсор в поле поиска в шапке окна.
  ///
  /// Отдельного окна поиска больше нет: печатают прямо в шапке, выдача
  /// выпадает под полем. См. [WindowSearchField].
  void _openSpotlight() {
    if (_modalOverlay != null) return;
    _searchFocus.requestFocus();
  }

  /// Поле поиска в шапке — со всем, что ему нужно, чтобы довести находку
  /// до открытой переписки.
  Widget _buildSearchField(
    BuildContext context,
    ValueChanged<DesktopSection> selectSection,
  ) => WindowSearchField(
    controller: _controller,
    chatsSelection: _chatsSelection,
    roomsSelection: _roomsSelection,
    selectSection: selectSection,
    focusNode: _searchFocus,
    onOpenSettings: _openSettings,
    onOpenProfile: _openProfile,
    onOpenProfileChat: (pid) => unawaited(_openProfileChatByDeepLink(pid)),
  );

  /// Островок «сейчас играет» — управляет тем же общим плеером, что и
  /// пузыри голосовых и песен.
  Widget _buildNowPlaying() => ValueListenableBuilder<SharedAudioPlaybackState>(
    valueListenable: _controller.sharedAudioPlayback,
    builder: (ctx, playback, _) => DesktopNowPlayingIsland(
      state: desktopNowPlayingOf(playback),
      onTogglePlay: () => unawaited(_controller.toggleSharedAudioPlayback()),
      onSeek: (position) => unawaited(_controller.seekSharedAudio(position)),
      onClose: () => unawaited(_controller.stopSharedAudio()),
      onPrevious: () => unawaited(_controller.playPreviousSharedAudio()),
      onNext: () => unawaited(_controller.playNextSharedAudio()),
      // Очередь берём свежую, в миг щелчка: пока список был открыт, плеер
      // мог уйти к следующей записи сам.
      onPlayIndex: (index) {
        final queue = _controller.sharedAudioPlayback.value.queue;
        if (index < 0 || index >= queue.length) return;
        unawaited(_controller.playSharedAudioQueue(queue: queue, index: index));
      },
      onOpenSource: (convoId) => unawaited(_openConvoOrReport(convoId)),
      onSetSpeed: (speed) => unawaited(_controller.setSharedAudioSpeed(speed)),
      volume: DesktopUiPrefs.playerVolume,
      onSetVolume: (volume) {
        unawaited(DesktopUiPrefs.setPlayerVolume(volume));
        unawaited(_controller.setSharedAudioVolume(volume));
      },
    ),
  );

  // GlobalKey on a child of the Overlay so we can target it for showing the
  // IncomingCallToast.
  final GlobalKey _overlayHostKey = GlobalKey();

  /// ◆ Свой цвет акцента живёт не в контроллере, а в настройках окна, —
  /// поэтому тик `changed` о нём ничего не знает и корень надо подписать
  /// отдельно. Подписка стоит НАД всем деревом: цвет меняет палитру целиком,
  /// а не один экран настроек.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: DesktopUiPrefs.customAccentArgb,
    builder: (ctx, _, __) => _buildApp(ctx),
  );

  Widget _buildApp(BuildContext context) {
    // 🔴 «АВТО» — СХЕМА ПО СИСТЕМНОЙ, И СЛЕДИТ ЗА НЕЙ ОКНО.
    //
    // Само значение живёт в общем `AppController.darkMode`, но пишется оно
    // только в локальные настройки и с телефоном не синхронизируется. Поэтому
    // «Авто» устроено так: окно смотрит на системную тему и, если она
    // разошлась с текущей, ставит нужную. Третьего состояния в контроллере не
    // появилось — там по-прежнему «темно» или «светло», и телефон об этой
    // настройке ничего не знает.
    //
    // Пост-кадром, а не прямо здесь: `setDarkMode` дёргает `changed`, а менять
    // состояние во время построения нельзя.
    _applyAutoThemeIfNeeded(context);
    // Apply the user's theme-preset choice to the desktop palette. When the
    // pref changes the controller fires `changed` → `_changedSub` rebuilds
    // this widget, so the derived set updates live.
    final DColorSet colors = _ready
        ? applyThemePreset(
            // `darkMode` is a shared profile setting; desktop ignored it and
            // was dark unconditionally, so a user who chose light on their
            // phone got two different-looking apps for one account.
            _controller.darkMode ? kDColorsDark : kDColorsLight,
            _controller.appThemePresetId,
            dark: _controller.darkMode,
            indicatorPresetId: _controller.indicatorColorPresetId,
            bubblePresetId: _controller.chatBubbleStylePresetId,
            customAccent: DesktopUiPrefs.customAccentArgb.value == 0
                ? null
                : Color(DesktopUiPrefs.customAccentArgb.value),
          )
        : kDColorsDark;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Secretly',
      // U-01: the desktop MaterialApp now registers
      // AppLocalizations, exactly like mobile [main.dart]. Before this, any
      // widget calling `context.l10n` crashed on desktop, which is why parts of
      // the desktop tree had to reimplement mobile widgets and why
      // DesktopNotificationService falls back to `lookupAppLocalizations`.
      // Registering the delegates also localises the built-in Material /
      // Cupertino widgets (date pickers, text-selection menus, tooltips).
      locale: _ready ? _controller.appLocaleOverride : null,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Mirror of mobile: an unsupported device language must fall back to
      // ENGLISH, never to supportedLocales.first (de) or a "nearest language"
      // guess. Delegated to the controller so desktop and mobile resolve the
      // same locale from the same source of truth. Returns null before boot so
      // Flutter's default resolution applies until the controller is live.
      localeListResolutionCallback: (deviceLocales, supportedLocales) {
        if (!_ready) return null;
        return _controller.resolveAppUiLocale(
          (deviceLocales == null || deviceLocales.isEmpty)
              ? WidgetsBinding.instance.platformDispatcher.locales
              : deviceLocales,
        );
      },
      // Каждая поверхность Material (диалог, меню, подсказка, выбор даты)
      // берёт цвет, рамку и радиус из той же палитры, что наши окна.
      theme: desktopMaterialTheme(colors, dark: _controller.darkMode),
      // 🔴 РАЗМЕР ТЕКСТА — ОДНОЙ ТОЧКОЙ НА ВСЁ ОКНО, а не настройкой в каждом
      // стиле. `MediaQuery` здесь охватывает и окна поверх (настройки, просмотр,
      // диалоги): они строятся тем же навигатором и наследуют его. Иначе
      // крупный текст был бы только в переписке, а в настройках прежний — и
      // человек решил бы, что настройка не сработала.
      //
      // 🔴 ПАЛИТРА — ЗДЕСЬ, НАД НАВИГАТОРОМ (28.09.2026). Ниже, в `home`, её
      // видело только само окно, а диалоги, меню, всплывающие окна, плашки и
      // входящий звонок строятся маршрутами и слоями корневого навигатора —
      // выше `home`. Не найдя палитры, они брали яркость ОС: на светлой
      // Windows при тёмной теме приложения все они были белыми.
      builder: (ctx, child) => DColors(
        colors: colors,
        child: ValueListenableBuilder<double>(
          valueListenable: DesktopUiPrefs.textScale,
          builder: (ctx2, scale, _) => MediaQuery(
            data: MediaQuery.of(ctx2).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            // Эмодзи Windows — Noto (Э1): и для текста вне `Material`. Слой
            // замков — под своим `Material`, чья тема несёт тот же запасной.
            child: _buildLockGate(
              desktopEmojiTextFallback(child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
      home: ValueListenableBuilder<bool>(
        valueListenable: _windowActivity.visible,
        // One TickerMode for the whole tree: while the window is off screen
        // every ticker in the subtree is muted, so no animation can keep
        // requesting frames. Doing it here rather than per-animation means new
        // animations inherit the behaviour instead of each one being a fresh
        // opportunity to burn CPU in the tray.
        builder: (ctx, windowVisible, child) =>
            TickerMode(enabled: windowVisible, child: child!),
        // Material ancestor for the WHOLE desktop tree.
        //
        // Without one, Flutter falls back to its error text style — yellow,
        // double-underlined — and, crucially, that style leaks into text that
        // DOES set its own: a `TextStyle` specifying colour and size still
        // inherits `decoration` from the ambient default, so every label in
        // the app was drawn with a yellow underline. It reads exactly like a
        // debug build, which is what it was reported as.
        //
        // `Material` rather than `Scaffold`: the desktop shell paints its own
        // background, chrome and layout, and a Scaffold would add an app bar
        // slot and body padding we would immediately have to undo.
        child: Material(
          color: colors.bg,
          child: DColors(
            colors: colors,
            child: Builder(
              // Строка меню macOS — здесь, ВНУТРИ `MaterialApp`: она берёт
              // подписи из тех же переводов, что и окно, и перестраивается
              // вместе с ним, когда язык меняют в настройках. Снаружи
              // переводов нет (см. геттер `l10n` выше).
              //
              // Пункты выдаются ровно тогда, когда за ними что-то есть:
              // до готовности и на экране привязки настроек ещё нет, и
              // «Настройки… ⌘,» в меню были бы обещанием впустую.
              // Ответ «настроена ли проверка обновлений» приходит с нативной
              // стороны уже после первого кадра. Без подписки пункт меню
              // появлялся бы только со следующей перерисовки окна — то есть
              // иногда никогда.
              builder: (ctx) => ValueListenableBuilder<bool>(
                valueListenable: DesktopUpdateService.instance.configured,
                builder: (ctx, updatesReady, child) => DesktopAppMenu(
                  onOpenSettings: _menuReady ? () => _openSettings() : null,
                  onOpenShortcuts: _menuReady
                      ? () => _openSettings(sectionId: 'shortcuts')
                      : null,
                  onOpenAbout: _menuReady
                      ? () => _openSettings(sectionId: 'about')
                      : null,
                  // Проверка обновлений не ждёт готовности приложения: она про
                  // саму программу, а не про переписку, и нужна в том числе
                  // тогда, когда программа поднимается плохо.
                  onCheckUpdates: updatesReady
                      ? () => unawaited(DesktopUpdateService.instance.check())
                      : null,
                  child: child!,
                ),
                // Признак «набор ещё не сделан» меняется уже после того, как
                // корень построен: без подписки человек остался бы на шаге
                // после того, как ключ сохранён.
                child: ValueListenableBuilder<bool>(
                  valueListenable: DesktopAccountSetup.kitPending,
                  builder: (ctx, _, __) =>
                      _OverlayHost(key: _overlayHostKey, child: _buildRoot()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Готово ли приложение показывать пункты меню, ведущие в настройки.
  ///
  /// Те же два условия, по которым `_buildRoot` решает, рисовать ли оболочку:
  /// до готовности внизу заставка, а при непривязанном профиле — экран
  /// привязки, и настроек в обоих случаях ещё нет. Запертое окно меню тоже не
  /// открывает: настройки встали бы под замок и выскочили после него.
  bool get _menuReady =>
      _ready &&
      !_controller.requiresDesktopProfileSelection &&
      !_anyLockEngaged;

  Widget _buildRoot() {
    if (!_ready) {
      return DesktopSplash(
        error: _error.isEmpty ? null : _error,
        slow: _bootSlow,
        onRetry: _retryBoot,
        onOpenLogs: () => unawaited(openDesktopLogFolder()),
      );
    }
    final rootVm = _vm;
    if (_controller.requiresDesktopProfileSelection) {
      // `_vm` is created in `_boot`, and `_ready` is only true after `_boot`
      // finished — so it is non-null here. The splash is the honest fallback
      // if that ever stops holding.
      if (rootVm == null) return const DesktopSplash();
      // 🔴 ВЫБОР ИЗ ТРЁХ, А НЕ СРАЗУ QR (23.09.2026). Компьютерная версия
      // делалась вторым экраном к платному телефонному приложению, поэтому
      // телефон был по условию. Приложение стало бесплатным — к нам приходят
      // и те, у кого телефонной версии нет вовсе.
      return DesktopAuthGate(vm: rootVm);
    }
    // 🔴 ОБЯЗАТЕЛЬНЫЙ ШАГ ПОСЛЕ СОЗДАНИЯ АККАУНТА ЗДЕСЬ.
    //
    // Создание снимает запрет входа в тот же кадр, и экран создания уходит со
    // сцены — шаг «сохраните набор восстановления», живущий внутри него,
    // исчез бы вместе с ним. Поэтому его показывает КОРЕНЬ, по признаку,
    // который лежит в настройках устройства и переживает закрытие окна.
    //
    // Признак взводится ТОЛЬКО при создании аккаунта на компьютере: привязка
    // по телефону и восстановление его не ставят — там ключ либо уже есть,
    // либо аккаунт живёт ещё где-то.
    if (rootVm != null && DesktopAccountSetup.kitPending.value) {
      return DesktopRecoveryKitGate(vm: rootVm);
    }

    final shell = DesktopShell(
      initialSection: _section,
      connectionStatus: _connection,
      onOpenProfile: _openProfile,
      onOpenSettings: _openSettings,
      onOpenSpotlight: _openSpotlight,
      searchBuilder: _buildSearchField,
      nowPlaying: _buildNowPlaying(),
      windowTitle: 'Secretly',
      // · 330 из макета. На 360 правая панель забирала тридцать точек у
      // переписки — самого узкого места в трёхполосном окне.
      detailsWidth: 330,
      // 🔴 Полоса идущего созвона — над всем окном. Плашка внутри комнаты
      // остаётся: там зовут ПРИСОЕДИНИТЬСЯ к чужому созвону, здесь —
      // ВЕРНУТЬСЯ в свой, из любого раздела.
      activeCallBar: DesktopActiveCallBar(
        titleFor: _roomTitleFor,
        onReturn: _returnToRoomCall,
        onToggleMic: _toggleRoomCallMic,
        onLeave: _leaveRoomCall,
        direct: _callManager?.state,
        // «Вернуться»: звонок в своём окне — это окно вперёд.
        onDirectReturn: () {
          final w = _callWindow;
          if (w != null && w.isOpen) {
            unawaited(w.focus());
          } else {
            DesktopCallPresence.instance.expandDirect();
          }
        },
        onDirectToggleMic: () async => _callManager?.toggleMute(),
        onDirectEnd: () => unawaited(_callManager?.hangup()),
      ),
      // Крошки собираются ЗДЕСЬ: знание о выбранном чате и открытой теме
      // живёт в складах выбора, а оболочка про них не знает.
      breadcrumbsBuilder: _buildBreadcrumbs,
      navHistory: _navHistory,
      onNavigateHistory: _applyHistoryEntry,
      // Рейка собирается ЗДЕСЬ и подписывается сама — корень на тике
      // контроллера не перерисовывается намеренно, см. `_wireListeners`.
      sidebarBuilder: (ctx, active, onSelect) {
        final vm = _vm;
        // Заглушка ТОЙ ЖЕ ширины, что рейка: иначе окно дёргается на старте.
        if (vm == null) return const SizedBox(width: kRailWidth);
        return DesktopLiveRail(
          vm: vm,
          load: _loadRailSnapshot,
          active: active,
          onSelect: onSelect,
          connectionStatus: _connection,
          onOpenSettings: _openSettings,
          onOpenProfile: _openProfile,
          // 🔴 ОТМЕТКА У ЗАКРЕПЛЁННОЙ ПЛИТКИ СЧИТАЕТСЯ ПО ТЕКУЩЕМУ РАЗДЕЛУ.
          //
          // Раньше сюда всегда шёл выбор КОМНАТ, независимо от того, где
          // человек стоит. Из этого выходило две беды сразу:
          //
          // 1. Открыл комнату, вернулся в «Чаты» — обводка у её плитки
          //    осталась. На рейке горели две отметки: залитая плитка раздела
          //    и обведённая плитка комнаты, в которой человека уже нет.
          // 2. Закреплённая переписка с ЧЕЛОВЕКОМ выбирается в складе чатов,
          //    а сравнивалась со складом комнат — её плитка не подсвечивалась
          //    НИКОГДА.
          activeSpaceConvoId: switch (active) {
            DesktopSection.rooms => _roomsSelection.selectedConvoId,
            DesktopSection.chats => _chatsSelection.selectedConvoId,
            _ => null,
          },
          onOpenSpace: (convoId) => unawaited(_openConvoOrReport(convoId)),
          onAddFavourite: () => unawaited(_addFavourite()),
        );
      },
      contentBuilder: (ctx, section, api) {
        _section = section;
        // Capture the shell's selectSection callback so Cmd+K can drive
        // section switching from outside the shell tree.
        _shellSelectSection = api.selectSection;
        // Свой профиль живёт в правой панели, и открыть её надо оттуда, где
        // рейка, — то есть снаружи оболочки. Захватываем те же ручки.
        _shellOpenDetails = api.openDetails;
        _shellCloseDetails = api.closeDetails;
        final vm = _vm;
        switch (section) {
          case DesktopSection.chats:
            if (vm == null) return const SizedBox.shrink();
            return DesktopChatsSection(
              vm: vm,
              shellApi: api,
              selection: _chatsSelection,
              syncStatus: _syncStatus,
              // Комната из личного чата (приглашение) — в раздел «Комнаты».
              onOpenConversation: _openConvoOrReport,
            );
          case DesktopSection.rooms:
            if (vm == null) return const SizedBox.shrink();
            return DesktopChatsSection(
              vm: vm,
              shellApi: api,
              selection: _roomsSelection,
              filter: ConversationFilter.groups,
              syncStatus: _syncStatus,
              onOpenConversation: _openConvoOrReport,
              emptyTitleNoItems: l10n.desktopRoomsNone,
              emptySubtitleNoItems:
                  l10n.desktopRoomsNoneHintDot,
              emptyTitleSelect: l10n.desktopRoomsPickOne,
            );
          case DesktopSection.calls:
            if (vm == null) return const SizedBox.shrink();
            return DesktopCallsSection(vm: vm, shellApi: api);
          case DesktopSection.contacts:
            if (vm == null) return const SizedBox.shrink();
            return DesktopContactsSection(
              vm: vm,
              shellApi: api,
              // Start (or open) the 1:1 chat with this contact and jump to it.
              onOpenChat: (profileId) =>
                  unawaited(_openProfileChatByDeepLink(profileId)),
            );
        }
      },
      detailsBuilder: (ctx, section, api) {
        // Pick the matching per-tab selection store. Contacts and Calls have
        // no chat-detail context yet — fall back to chats store, which will
        // simply render the empty state on those tabs.
        final store = section == DesktopSection.rooms
            ? _roomsSelection
            : _chatsSelection;
        final vm = _vm;
        if (vm == null) return const SizedBox.shrink();
        return DetailsDrawer(
          vm: vm,
          selection: store,
          onClose: api.closeDetails,
          showSelfProfile: _selfProfileOpen,
          onCloseSelfProfile: _closeSelfProfile,
          onOpenDeviceSettings: () => _openSettings(sectionId: 'devices'),
          onOpenAppearanceSettings: () =>
              _openSettings(sectionId: 'appearance'),
          // Карточка участника комнаты пишет человеку ТЕМ ЖЕ путём, что и
          // ссылка-приглашение с телефона: переписки с ним может ещё не
          // существовать, и её сперва надо завести.
          onOpenProfileChat: (pid) => unawaited(_openProfileChatByDeepLink(pid)),
        );
      },
    );

    final modal = _modalOverlay;
    final callOverlay = _buildActiveCallOverlay();
    // 🔴 ПОД НАСТРОЙКАМИ И ЗВОНКОМ ОКНО НЕ ДВИЖЕТСЯ (01.10.2026). Оба слоя
    // непрозрачны и закрывают окно целиком, а под ними продолжали крутиться
    // обои, рамки и статусы, и каждый цикл перерисовывал экран, которого не
    // видно. Здесь гасится всё, включая кружки: невидимый кружок ни о чём не
    // сообщает. `TickerMode` стоит всегда, меняется только флаг — оболочка
    // не пересоздаётся и ничего не теряет.
    final covered = modal != null || callOverlay != null;
    final children = <Widget>[TickerMode(enabled: !covered, child: shell)];
    if (modal != null) children.add(modal);
    if (callOverlay != null) children.add(callOverlay);
    // Мини-окна свёрнутых звонков — поверх всего окна, но ПОД замками: запертое
    // приложение не должно показывать, с кем идёт разговор.
    children.add(Positioned.fill(child: _buildCallMiniHost()));
    // 🔴 Замков здесь больше нет — они над навигатором ([_buildLockGate]):
    // отсюда их перекрывал любой маршрут поверх главного экрана, а обёртка
    // запертого окна пересоздавала оболочку (30.09.2026).
    return Stack(children: children);
  }

  /// 🔴 ПАРОЛЬ «ВХОД В ПРИЛОЖЕНИЕ» НА КОМПЬЮТЕРЕ (17.09.2026).
  ///
  /// Настройки компьютера включали этот замок, а проверял его только
  /// телефонный `main.dart`: пароль задавался — и ни разу не спрашивался.
  /// Замок Touch ID этого компьютера — отдельный и рисуется поверх.
  ///
  /// 🔴 ЗВОНОК ЗАМОК БОЛЬШЕ НЕ СНИМАЕТ (30.09.2026). Правило было телефонное
  /// (`_shouldShowAppLockOverlay`): «не идёт звонок, чтобы входящий можно было
  /// принять». Но снимался замок целиком — позвони на запертый компьютер, и
  /// открыта вся переписка. Звонком теперь управляют поверх замка (см.
  /// [_lockCall]), а окна звонков ОС замок не накрывает вовсе.
  bool get _appScopeLocked {
    if (!_ready || _controller.requiresDesktopProfileSelection) return false;
    return _controller.security.isLocked(SecurityLockScope.app);
  }

  /// Замок Touch ID этого компьютера — свой, отдельный от общего.
  bool get _deviceLocked {
    if (!_ready || _controller.requiresDesktopProfileSelection) return false;
    return _lockService.locked.value;
  }

  /// Заперто ли окно хоть одним замком.
  bool get _anyLockEngaged => _appScopeLocked || _deviceLocked;

  /// Замки окна над навигатором — см. [DesktopLockGate]. Touch ID рисуется
  /// поверх общего замка, звонок — поверх обоих.
  Widget _buildLockGate(Widget navigator) {
    final appLocked = _appScopeLocked;
    final deviceLocked = _deviceLocked;
    return DesktopLockGate(
      locked: appLocked || deviceLocked,
      animate: _windowActivity.visible,
      layers: <Widget>[
        if (appLocked)
          AppSecurityLockOverlay(
            key: const ValueKey<String>('lock-app'),
            controller: _controller,
          ),
        if (deviceLocked)
          DesktopLockOverlay(
            key: const ValueKey<String>('lock-device'),
            service: _lockService,
            windowVisible: _windowActivity.visible,
          ),
        ListenableBuilder(
          key: const ValueKey<String>('lock-call'),
          listenable: Listenable.merge(<Listenable?>[
            _callManager?.state,
            _roomCallManager?.state,
            DesktopCallPresence.instance.roomWindowOpen,
          ]),
          builder: (ctx, _) => _buildLockCallStrip(),
        ),
      ],
      child: navigator,
    );
  }

  /// Звонок, которым дать управлять поверх замка. `null` — такого нет: звонка
  /// нет или он в своём окне ОС, которое замок не накрывает.
  DesktopLockCall? _lockCall() {
    final s = _callManager?.state.value;
    if (s != null && s.isActive && !(_callWindow?.handles(s) ?? false)) {
      if (s.phase == CallPhase.ringingIncoming) {
        return DesktopLockCall(
          kind: DesktopLockCallKind.incoming,
          video: s.isVideo,
        );
      }
      return DesktopLockCall(
        kind: DesktopLockCallKind.direct,
        muted: s.isMuted,
      );
    }
    final room = _roomCallManager?.state.value;
    final self = room?.session?.selfParticipant;
    if (room != null && room.hasActiveSession && self != null && self.isJoined) {
      final roomId = room.roomId.trim();
      if (roomId.isNotEmpty && DesktopRoomCallWindows.openRoomId != roomId) {
        return DesktopLockCall(
          kind: DesktopLockCallKind.room,
          muted: self.muted,
        );
      }
    }
    return null;
  }

  Widget _buildLockCallStrip() {
    final call = _lockCall();
    final cm = _callManager;
    if (call == null) return const SizedBox.shrink();
    final room = call.kind == DesktopLockCallKind.room;
    return DesktopLockCallStrip(
      call: call,
      onAccept: cm == null ? null : () => unawaited(cm.acceptIncoming()),
      onDecline: cm == null ? null : () => unawaited(cm.declineIncoming()),
      onToggleMic: room
          ? () => unawaited(_toggleRoomCallMic())
          : (cm == null ? null : () => unawaited(cm.toggleMute())),
      onEnd: room
          ? () => unawaited(_leaveRoomCall())
          : (cm == null ? null : () => unawaited(cm.hangup())),
    );
  }

  Widget? _buildActiveCallOverlay() {
    final cm = _callManager;
    final call = _directCall;
    if (cm == null || call == null) return null;
    final s = cm.state.value;
    if (!s.isActive) return null;
    // Звонок в своём окне ОС — здесь его не рисуем (29.09.2026, Р1).
    if (_callWindow?.handles(s) ?? false) return null;
    // Ringing-incoming surfaces as a toast, not a full screen.
    if (s.phase == CallPhase.ringingIncoming) return null;
    // Свёрнут — живёт мини-окном (см. [_buildCallMiniHost]).
    final presence = DesktopCallPresence.instance;
    if (presence.directMinimized.value) return null;
    final peer = s.peerProfileId.trim();
    return Positioned.fill(
      child: OneToOneCallScreen(
        call: call,
        // Пустое имя экран звонка подпишет сам — без сырого profile_id.
        peerName: s.peerName.trim(),
        // FIX (2026-07-13, call avatar): the shared CallState now carries the
        // peer photo (resolved via the chat resolver in call_manager), so wire
        // it into the desktop call screen instead of showing initials only.
        peerImage: Avatar.fileImage(s.peerAvatarPath),
        onEnd: () => unawaited(cm.hangup()),
        onMinimize: presence.minimizeDirect,
        onOpenChat: peer.isEmpty ? null : () => _openDirectCallChat(peer),
      ),
    );
  }

  /// Мини-окна свёрнутых звонков. Сами решают, показываться ли.
  Widget _buildCallMiniHost() {
    return DesktopCallMiniHost(
      direct: _directCall,
      onDirectEnd: () => unawaited(_callManager?.hangup()),
      selfProfileId: _controller.profileId,
      loadRoomMembers: _controller.listRoomMembersDetailed,
      loadRoomCall: _controller.getCachedRoomCall,
      roomTitleFor: _roomTitleFor,
      onRoomToggleMic: _toggleRoomCallMic,
      onRoomToggleCamera: _toggleRoomCallCamera,
      onRoomLeave: _leaveRoomCall,
      onRoomExpand: _returnToRoomCall,
    );
  }
}

/// Trivial container exposing a stable BuildContext (via [GlobalKey]) so that
/// [IncomingCallToast.show] can locate an Overlay even when the underlying
/// tree (splash / onboarding / shell) rebuilds.
class _OverlayHost extends StatelessWidget {
  const _OverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Состояние общего плеера — в описание для островка в шапке.
///
/// Открыто и вынесено наружу, чтобы перевод проверялся без окна: островок
/// сам контроллера не знает (см. [DesktopNowPlaying]).
DesktopNowPlaying? desktopNowPlayingOf(SharedAudioPlaybackState s) {
  final track = s.currentTrack;
  if (track == null) return null;
  return DesktopNowPlaying(
    title: track.title,
    artist: track.artist,
    sourceConvoId: track.sourceConvoId,
    playing: s.playing,
    loading: s.loadingTrackId == track.trackId,
    position: s.position,
    duration: s.duration,
    queue: [
      for (final t in s.queue)
        DesktopNowPlayingEntry(title: t.title, artist: t.artist),
    ],
    queueIndex: s.queueIndex,
    speed: s.speed,
  );
}
