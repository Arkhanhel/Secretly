// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../calls/call_manager.dart';
import '../../../rooms/room_call_manager.dart';
import '../calls/active_call_bar.dart';
import '../calls/room_call_window.dart';
import '../../../calls/call_state.dart';
import '../../../sync/peer_history_service.dart';
import '../calls/incoming_call_toast.dart';
import '../calls/call_peer_label.dart';
import '../calls/one_to_one_call_screen.dart';
import '../primitives/avatar.dart';
import '../chat/forward_target_dialog.dart';
import '../chat/details/details_drawer.dart';
import '../chat/details/desktop_selection_store.dart';
import '../design/theme_bridge.dart';
import '../design/tokens.dart';
import '../shell/desktop_app_menu.dart';
import '../shell/desktop_shell.dart';
import '../primitives/desktop_snackbar.dart';
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
import '../services/desktop_nav_history.dart';
import '../services/desktop_deleted_chats.dart';
import '../services/desktop_app_lock_service.dart';
import '../../../security/app_security_manager.dart' show SecurityLockScope;
import '../../security_lock_flow.dart' show AppSecurityLockOverlay;
import '../services/desktop_notification_service.dart';
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
import '../chat/desktop_link_router.dart';

/// Top-level widget for the desktop production build.
///
/// Owns the [AppController] + [CallManager] lifecycle, gates on
/// identity/profile-selection state, and delivers per-section content to
/// [DesktopShell]. Active calls render as full-screen overlays above the shell;
/// incoming calls surface as [IncomingCallToast].
///
/// Mobile-only services (PushWakeService, app_links, CallForegroundService)
/// are NOT initialised here — by design. Desktop pushes will be added in a
/// later slice via WSS keep-alive + local notifications (see
/// docs/DESKTOP_PRODUCTION_TZ_2026-05-17.md §5.6).
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
  /// `MaterialApp`. Это тот же запасной путь, которым пользуются уведомления
  /// (`DesktopNotificationService`), и он не умеет не найтись:
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
  StreamSubscription<bool>? _relaySub;
  StreamSubscription<void>? _securitySub;
  StreamSubscription<void>? _restartSub;
  StreamSubscription<String>? _notifTapSub;
  StreamSubscription<Uri>? _deepLinkSub;
  VoidCallback? _callStateListener;
  Uri? _pendingDeepLink;
  bool _ready = false;
  String _error = '';
  Timer? _winSaveDebounce; // persists window geometry on resize/move
  ConnectionStatus _connection = ConnectionStatus.connecting;
  DesktopSection _section = DesktopSection.chats;
  Widget? _modalOverlay;

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
      await _controller.updateRelayRoomCallParticipant(
        roomId: roomId,
        callId: callId,
        reconnecting: self.isReconnecting,
        muted: !self.muted,
        deafened: self.deafened,
        videoEnabled: self.videoEnabled,
        screenShareEnabled: self.screenShareEnabled,
        speaking: self.speaking,
      );
      await RoomCallManager.instance?.ensureJoined(
        roomId: roomId,
        callId: callId,
        forceRefresh: true,
      );
    } catch (_) {
      // Отказ виден сразу: кнопка вернётся в прежнее состояние, потому что
      // рисуется по снимку, а не по нажатию.
    }
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

  void _onChatsSelectionChanged() =>
      _recordVisit(DesktopSection.chats, _chatsSelection.selected);
  void _onRoomsSelectionChanged() =>
      _recordVisit(DesktopSection.rooms, _roomsSelection.selected);

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
    }
    // D-2: single subscription so EVERY show/hide path updates presence,
    // including tray paths that raise the window without a focus event.
    _windowActivity.visible.addListener(_onWindowVisibilityChanged);
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
    if (prevent) {
      await _hideToTray();
    }
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
    _trayDebounce?.cancel();
    _winSaveDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final bounds = await windowManager.getBounds();
        await DesktopWindowState.save(bounds);
      } catch (_) {}
    });
  }

  Future<void> _boot() async {
    try {
      await _lockService.init();
      await _controller.init();
      if (!mounted) return;
      // PR4 (SPRINT2_AUDIT §16): construct AFTER controller.init() so the
      // ChangeNotifier subscribes to a populated `relayConnectionChanges`
      // stream. Dispose handled below in [dispose] / [_restart].
      _syncStatus?.dispose();
      _syncStatus = DesktopSyncStatusController(controller: _controller);
      _vm?.dispose();
      _vm = DesktopAppViewModel(controller: _controller);
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
      unawaited(PeerHistoryService.instance.maybeSyncOnBoot());
      _wireListeners();
      _initCallManager();
      await _initNotificationService();
      // Окно могли закрыть прямо во время запуска — тогда обновлять состояние
      // уже некому.
      if (!mounted) return;
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
      setState(() {
        _ready = true;
        _connection = _controller.relayOnline
            ? ConnectionStatus.connected
            : ConnectionStatus.connecting;
      });
      // If a deep-link was buffered while we were booting, dispatch it now.
      final pending = _pendingDeepLink;
      if (pending != null) {
        _pendingDeepLink = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleDeepLink(pending);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = false;
        _error = e.toString();
      });
    }
  }

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
      unawaited(_openProfileChatByDeepLink(profileId));
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
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => RoomInviteJoinScreen(
          controller: _controller,
          target: target,
          onJoined: _openConvoOrReport,
        ),
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
    for (final c in convos) {
      // Архив не считается: человек убрал переписку с глаз, и счётчик на рейке
      // возвращал бы её обратно.
      if (c.archivedAtMs != null) continue;
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

  /// Открыть (при необходимости — завести) личную переписку с профилем.
  ///
  /// Сюда приходят кнопка «Написать сообщение» в разделе «Контакты» и ссылка
  /// на профиль. Раньше оба отказа были молчаливыми.
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
      if (total == _lastTrayUnread) return;
      _lastTrayUnread = total;
      try {
        await trayManager.setToolTip(
          total > 0 ? l10n.desktopUnreadTitle(total) : 'Secretly',
        );
      } catch (_) {
        // Tray may be unavailable (headless, CI); never let it break the app.
      }
    });
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

    _relaySub?.cancel();
    _relaySub = _controller.relayConnectionChanges.listen((online) {
      if (!mounted) return;
      setState(() {
        _connection = online
            ? ConnectionStatus.connected
            : ConnectionStatus.connecting;
      });
    });

    _restartSub?.cancel();
    _restartSub = _controller.restartRequested.listen((_) => _restart());

    // Замок «Вход в приложение» заперли или открыли — перерисовать корень:
    // экран блокировки живёт здесь.
    _securitySub?.cancel();
    _securitySub = _controller.security.changed.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _initCallManager() {
    _disposeCallManager();
    final cm = CallManager(controller: _controller)..start();
    CallManager.instance = cm;
    _callStateListener = _onCallStateChanged;
    cm.state.addListener(_callStateListener!);
    _callManager = cm;
    _notifService?.attachCallManager(cm);
    // Комнатные созвоны — свой управляющий, ровно как на телефоне.
    final rcm = RoomCallManager(controller: _controller)..start();
    RoomCallManager.instance = rcm;
    _roomCallManager = rcm;
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
    _notifTapSub = svc.onTap.listen(_onNotificationTap);
  }

  Future<void> _disposeNotificationService() async {
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
    if (isCallPayload) {
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
    final rcm = _roomCallManager;
    if (RoomCallManager.instance == rcm) {
      RoomCallManager.instance = null;
    }
    if (rcm != null) {
      unawaited(rcm.dispose());
    }
    _roomCallManager = null;
    _dismissIncomingToast();
  }

  void _onCallStateChanged() {
    if (!mounted) return;
    setState(() {});
    _syncIncomingToast();
  }

  void _syncIncomingToast() {
    final cm = _callManager;
    if (cm == null) {
      _dismissIncomingToast();
      return;
    }
    final s = cm.state.value;
    final shouldShow = s.phase == CallPhase.ringingIncoming;
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
    setState(() {
      _ready = false;
      _error = '';
    });
    await _disposeNotificationService();
    _disposeCallManager();
    // Drop the peer-history binding so a stale controller can't be poked
    // mid-restart. `_boot()` re-attaches once the new controller is up.
    PeerHistoryService.instance.detach();
    await _changedSub?.cancel();
    await _relaySub?.cancel();
    await _restartSub?.cancel();
    await _securitySub?.cancel();
    _vm?.dispose();
    _vm = null;
    try {
      await _controller.dispose();
    } catch (_) {}
    _controller = AppController();
    await _boot();
  }

  @override
  void dispose() {
    DesktopLinkRouter.handler = null;
    if (_windowListenerAttached) {
      try {
        windowManager.removeListener(this);
      } catch (_) {}
      _windowListenerAttached = false;
    }
    _winSaveDebounce?.cancel();
    unawaited(_disposeNotificationService());
    _disposeCallManager();
    _changedSub?.cancel();
    _relaySub?.cancel();
    _restartSub?.cancel();
    _securitySub?.cancel();
    _deepLinkSub?.cancel();
    _chatsSelection.removeListener(_dropSelfProfileOnSelection);
    _roomsSelection.removeListener(_dropSelfProfileOnSelection);
    _chatsSelection.removeListener(_onChatsSelectionChanged);
    _roomsSelection.removeListener(_onRoomsSelectionChanged);
    DesktopUiPrefs.themeMode.removeListener(_onThemeModeChanged);
    _navHistory.dispose();
    _chatsSelection.dispose();
    _roomsSelection.dispose();
    _syncStatus?.dispose();
    _syncStatus = null;
    _vm?.dispose();
    _vm = null;
    PeerHistoryService.instance.detach();
    _controller.dispose();
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

  void _openSpotlight() {
    final selectSection = _shellSelectSection;
    if (selectSection == null) return;
    setState(() {
      _modalOverlay = SpotlightPalette(
        controller: _controller,
        chatsSelection: _chatsSelection,
        roomsSelection: _roomsSelection,
        selectSection: selectSection,
        onClose: _closeOverlay,
        onOpenSettings: _openSettings,
        onOpenProfile: _openProfile,
        onOpenProfileChat: (pid) =>
            unawaited(_openProfileChatByDeepLink(pid)),
      );
    });
  }

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
      // U-01 (DESKTOP_COMPLETION_TZ §5.2): the desktop MaterialApp now registers
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
      theme: ThemeData(
        brightness: _controller.darkMode ? Brightness.dark : Brightness.light,
        fontFamily: DType.family,
        useMaterial3: true,
        scaffoldBackgroundColor: colors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colors.accentPrimary,
          brightness: _controller.darkMode ? Brightness.dark : Brightness.light,
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
  /// привязки, и настроек в обоих случаях ещё нет.
  bool get _menuReady =>
      _ready && !_controller.requiresDesktopProfileSelection;

  Widget _buildRoot() {
    if (!_ready) {
      return DesktopSplash(error: _error.isEmpty ? null : _error);
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
            );
          case DesktopSection.rooms:
            if (vm == null) return const SizedBox.shrink();
            return DesktopChatsSection(
              vm: vm,
              shellApi: api,
              selection: _roomsSelection,
              filter: ConversationFilter.groups,
              syncStatus: _syncStatus,
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
    final children = <Widget>[shell];
    if (modal != null) children.add(modal);
    if (callOverlay != null) children.add(callOverlay);
    return ValueListenableBuilder<bool>(
      valueListenable: _lockService.locked,
      builder: (ctx, locked, _) {
        final stack = children.length == 1 ? shell : Stack(children: children);
        final layers = <Widget>[
          stack,
          if (_appScopeLocked) AppSecurityLockOverlay(controller: _controller),
          if (locked) DesktopLockOverlay(service: _lockService),
        ];
        if (layers.length == 1) return stack;
        return Stack(children: layers);
      },
    );
  }

  /// 🔴 ПАРОЛЬ «ВХОД В ПРИЛОЖЕНИЕ» НА КОМПЬЮТЕРЕ (17.09.2026).
  ///
  /// Настройки компьютера включали этот замок, а проверял его только
  /// телефонный `main.dart`: пароль задавался — и ни разу не спрашивался.
  /// Правило — как у телефона (`_shouldShowAppLockOverlay`): только когда
  /// приложение готово и не идёт звонок, чтобы входящий можно было принять.
  /// Замок Touch ID этого компьютера — отдельный и рисуется поверх.
  bool get _appScopeLocked {
    if (!_ready || _controller.requiresDesktopProfileSelection) return false;
    if (!_controller.security.isLocked(SecurityLockScope.app)) return false;
    final call = _callManager?.state.value;
    if (call != null && (call.isActive || call.isRinging)) return false;
    return true;
  }

  Widget? _buildActiveCallOverlay() {
    final cm = _callManager;
    if (cm == null) return null;
    final s = cm.state.value;
    if (!s.isActive) return null;
    // Ringing-incoming surfaces as a toast, not a full screen.
    if (s.phase == CallPhase.ringingIncoming) return null;
    return Positioned.fill(
      child: OneToOneCallScreen(
        callManager: cm,
        // Пустое имя экран звонка подпишет сам — без сырого profile_id.
        peerName: s.peerName.trim(),
        // FIX (2026-07-13, call avatar): the shared CallState now carries the
        // peer photo (resolved via the chat resolver in call_manager), so wire
        // it into the desktop call screen instead of showing initials only.
        peerImage: Avatar.fileImage(s.peerAvatarPath),
        onEnd: () => unawaited(cm.hangup()),
      ),
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
