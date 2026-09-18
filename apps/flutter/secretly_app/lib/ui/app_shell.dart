// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../billing/app_update_sheet.dart';
import '../billing/premium_trial_sheet.dart';
import '../rooms/room_call_state.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'animations/animations.dart';
import 'chat_screen.dart';
import 'desktop_surface_policy.dart';
import 'liquid_glass_flags.dart';
import 'thermal_guard.dart';
import 'chats_screen.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/island_backdrop.dart';
import 'contacts_screen.dart';
import 'groups_screen.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'premium/cosmetics_catalog.dart';
import 'profile_screen.dart';
import 'room_call_screen.dart';
import 'settings_screen.dart';
import 'wave1_l10n.dart';
import 'widgets/room_call_return_banner.dart';
import 'widgets/system_bottom_fade.dart';
import 'widgets/support_badge.dart';
import '../version/native_update_prompt.dart';
import 'widgets/broken_media_box.dart';

/// Shared route name for a pushed [ChatScreen] so notification / deep-link
/// opens can detect an already-open chat and bring it to the front instead of
/// stacking a duplicate. Both the in-app banner (here) and the notification /
/// deep-link path in main.dart must use this same convention.
String chatRouteName(String convoId) => 'chat:$convoId';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  /// 🔴 ШТАТНОЕ РЕШЕНИЕ ВМЕСТО САМОДЕЛЬНОГО (20.08.2026, после двух неудач).
  ///
  /// Задача — «перейти на дальний раздел с анимацией, но не показывая те, что
  /// между» — уже решена во Flutter: `TabBarView` при переходе через несколько
  /// вкладок временно оставляет в своём ряду ТОЛЬКО две (откуда и куда),
  /// проигрывает один шаг и корректно возвращает полный ряд.
  ///
  /// Мои две попытки сделать то же руками на `PageView` провалились:
  ///
  ///   * «встать вплотную и шагнуть один раз» — `jumpToPage` к соседу тоже
  ///     рисует кадр, мелькание оставалось;
  ///   * временный ряд из двух страниц — подмена контроллера НЕ ставит его на
  ///     `initialPage`: `Scrollable` передаёт новой позиции старую, и та
  ///     ПОГЛОЩАЕТ смещение. Оставалась «одна ширина экрана», а в полном ряду
  ///     это индекс 1 — «Комнаты» всплывали через долю секунды;
  ///   * появление со сдвигом и прозрачностью — прозрачность и была тем самым
  ///     морганием.
  ///
  /// Свайп пальцем `TabBarView` держит сам, той же физикой.
  late TabController _tabController;

  // Nav-bar liquid lens: refract only WHILE the pill slides between tabs, then
  // fall back to a flat grey oval at rest so it stops bending the left edge of
  // long labels («Контакты» / «Настройки»). True for the ~pill-move window.
  bool _navLensRefract = false;
  Timer? _navLensTimer;

  void _pulseNavLens() {
    _navLensTimer?.cancel();
    if (!_navLensRefract && mounted) {
      setState(() => _navLensRefract = true);
    }
    // A touch longer than the 300 ms page slide so the pill has fully settled
    // before the lens goes flat.
    _navLensTimer = Timer(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _navLensRefract = false);
    });
  }

  StreamSubscription<ChatNotifEvent>? _bannerSub;
  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;

  /// Список бесед для значков непрочитанного, запомненный по версии изменений.
  ///
  /// 🔴 ПОЧЕМУ (02.09.2026, аудит скорости доставки). Три раскладки панели
  /// навигации — нижняя стеклянная, планшетная и обычная — вызывали
  /// `listConversations()` ПРЯМО в `build()`. Это давало два независимых
  /// дефекта.
  ///
  /// Первый — лишние обращения к базе. `build()` вызывается не только на тик
  /// `changed`: его дёргают смена темы, поворот экрана, появление клавиатуры,
  /// любой `MediaQuery`. Каждый такой вызов создавал НОВЫЙ `Future`, а значит
  /// новую загрузку — пять запросов к SQLCipher ради двух чисел, которые
  /// [_countUnreadNavBadges] потом из этого списка достаёт.
  ///
  /// Второй, заметный глазу, — мигание значка. `FutureBuilder` при смене
  /// `future` начинает с `ConnectionState.waiting` и `data == null`, ниже это
  /// сворачивается в пустой список, счётчики выходят нулевыми, и значок гаснет
  /// на кадр. Тот же дефект уже был найден в шапке чата и описан там же в
  /// `cachedConversation`.
  ///
  /// Лечение обоих: держать один `Future` на версию изменений, а на время его
  /// разрешения показывать последний известный список через `initialData`.
  int _navBadgesVersion = -1;
  Future<List<Conversation>>? _navBadgesFuture;

  Future<List<Conversation>> _conversationsForNavBadges() {
    final version = widget.controller.changeVersion;
    final cached = _navBadgesFuture;
    if (cached != null && _navBadgesVersion == version) {
      return cached;
    }
    _navBadgesVersion = version;
    final future = widget.controller.listConversations();
    _navBadgesFuture = future;
    return future;
  }

  ({int chats, int rooms}) _countUnreadNavBadges(
    List<Conversation> conversations,
  ) {
    final personalConvoIds = widget.controller.personalConvoIds;
    final unreadChatsCount = conversations
        .where(
          (c) =>
              !c.convoId.startsWith('group:') &&
              c.archivedAtMs == null &&
              !personalConvoIds.contains(c.convoId) &&
              c.unreadCount > 0,
        )
        .length;
    final unreadRoomsCount = conversations
        .where((c) => c.convoId.startsWith('group:') && c.unreadCount > 0)
        .length;
    return (chats: unreadChatsCount, rooms: unreadRoomsCount);
  }

  @override
  void initState() {
    super.initState();
    // 🔴 keepPage: false — ОБЯЗАТЕЛЬНО (20.08.2026).
    //
    // По умолчанию `PageController` запоминает позицию через `PageStorage` и
    // при подключении ВОССТАНАВЛИВАЕТ её, игнорируя `initialPage`. Мы держим
    // текущий раздел сами (`_tab`) и пересоздаём контроллер при смене состава
    // ряда — восстановление чужого смещения тут не помощь, а источник кадра с
    // посторонним разделом.
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: _tab,
    )..addListener(_onTabControllerChanged);
    _bannerSub = widget.controller.inAppNotifications.listen(_showInAppBanner);
    // Premium upsell teaser. Self-throttles (skip first launch, cooldown, max
    // shows) AND is gated to never-subscribed users only. Delayed so the
    // monetization bootstrap (signed /v1/config + entitlement) has settled and
    // the home screen is calm before anything pops. Best-effort — never throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 4), () async {
        if (!mounted) return;
        // Higher priority than the upsell: if a newer build is available, nudge
        // first (dismissible). Sequential so the two sheets never stack.
        await maybeShowUpdateNudge(context, widget.controller);
        if (!mounted) return;
        // Нативная плашка Google Play — ПОСЛЕ нашего напоминания и как
        // дополнение к нему: на iOS её не существует, а установленным из
        // ручной APK Play обновления не предлагает. Молча ничего не делает
        // везде, где неприменима.
        unawaited(NativeUpdatePrompt.maybePrompt());

        unawaited(
          maybeShowPremiumTrialAnnouncement(context, widget.controller),
        );
      });
    });
  }

  @override
  void dispose() {
    _bannerSub?.cancel();
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
    _bannerEntry = null;
    _navLensTimer?.cancel();
    _tabController
      ..removeListener(_onTabControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _showInAppBanner(ChatNotifEvent event) {
    if (!mounted) return;
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
    _bannerEntry = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final overlay = Overlay.of(context, rootOverlay: true);
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => _InAppNotifBannerWidget(
          event: event,
          onTap: () {
            entry.remove();
            _bannerEntry = null;
            _bannerTimer?.cancel();
            final nav = Navigator.of(context);
            final routeName = chatRouteName(event.convoId);
            // Single-instance: if the tapped chat is already open bring it to
            // the front; otherwise collapse to the home shell and open it once
            // — a banner tap must never stack a chat on top of another.
            var broughtToFront = false;
            nav.popUntil((route) {
              if (route.settings.name == routeName) {
                broughtToFront = true;
                return true;
              }
              return route.isFirst;
            });
            if (broughtToFront) return;
            nav.push(
              MaterialPageRoute<void>(
                settings: RouteSettings(name: routeName),
                builder: (_) => ChatScreen(
                  controller: widget.controller,
                  convoId: event.convoId,
                  title: event.title,
                  peerProfileIdForSend:
                      event.convoId.startsWith('group:') ||
                          event.convoId.startsWith('req:')
                      ? null
                      : event.convoId,
                ),
              ),
            );
          },
          onDismiss: () {
            entry.remove();
            _bannerEntry = null;
            _bannerTimer?.cancel();
          },
        ),
      );
      _bannerEntry = entry;
      overlay.insert(entry);
      _bannerTimer = Timer(const Duration(seconds: 4), () {
        if (_bannerEntry == entry) {
          entry.remove();
          _bannerEntry = null;
        }
      });
    });
  }

  String _roomsLabel(BuildContext context) {
    return wave1Text(context, ru: 'Комнаты', en: 'Rooms');
  }

  /// 🔴 ОДНО СКОЛЬЖЕНИЕ ВМЕСТО ПРОКРУТКИ ВСЕГО РЯДА (15.08.2026).
  ///
  /// `animateToPage` прокручивает КАЖДУЮ страницу между текущей и целевой:
  /// переход из «Чатов» в «Настройки» пролистывал все разделы между ними —
  /// мельтешение, которого нет ни в одном мессенджере. Голый `jumpToPage` это
  /// убирает, но вместе с ним пропадает и само движение: раздел появляется
  /// рывком, без направления.
  ///
  /// Владелец: «чтобы открывалось сразу, но с анимацией перелистывания — слева
  /// направо и наоборот».
  ///
  /// Приём: мгновенно встаём ВПЛОТНУЮ к цели (на соседнюю страницу с нужной
  /// стороны) и анимируем ровно один шаг. Человек видит одно скольжение в
  /// правильную сторону, сколько бы разделов ни лежало между ними.
  ///
  /// 🔴 ПОДАВЛЕНИЕ ОТКЛИКА ОБЯЗАТЕЛЬНО. `jumpToPage` дёргает `onPageChanged` с
  /// ПРОМЕЖУТОЧНЫМ индексом — без флага подсветка в нижней панели прыгала бы на
  /// соседний раздел и возвращалась. Флаг снимается в `finally`: иначе одна
  /// прерванная анимация навсегда оставила бы панель глухой к свайпу.
  ///
  /// Свайп пальцем не тронут: это тот же `PageView`, и заменять его стопкой
  /// экранов нельзя — листание бы исчезло.
  /// Число разделов нижней панели. Одно место на объявление контроллера и на
  /// список страниц — разойдутся, и `TabBarView` бросит на первом же переходе.
  static const int _tabCount = 5;

  /// Смена раздела: и по нажатию на панель, и свайпом.
  ///
  /// `TabController` сам сообщает о новом индексе — и в начале анимации по
  /// нажатию, и по завершении свайпа, — поэтому подсветка панели обновляется
  /// здесь одним местом.
  void _onTabControllerChanged() {
    final index = _tabController.index;
    if (!mounted || index == _tab) return;
    setState(() => _tab = index);
    _pulseNavLens();
  }

  void _setTab(int nextTab) {
    if (nextTab == _tab || nextTab < 0 || nextTab >= _tabCount) return;
    // Всё движение — на совести `TabBarView`: через соседний раздел это обычное
    // пролистывание, через несколько — тот же один шаг, но без тех, что между.
    _tabController.animateTo(nextTab);
  }

  void _openDesktopProfileDialog(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = (mq.size.height * 0.88).clamp(400.0, 720.0);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogCtx) {
        final cs = Theme.of(dialogCtx).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: 480,
                constraints: BoxConstraints(maxHeight: maxH),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 36,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 52,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              wave1Text(context, ru: 'Профиль', en: 'Profile'),
                              style: Theme.of(dialogCtx).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.of(dialogCtx).pop(),
                                  child: Center(
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                    Flexible(
                      child: ProfileScreen(controller: widget.controller),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Liquid glass shell (iOS only) ─────────────────────────────────────────
  // GlassScaffold wires the body as the refraction source and promotes the
  // bottom bar to premium quality with proper isolation — so it actually
  // refracts the scrolling content behind it (the "white sheet" pitfall from
  // spike V3: a bare Scaffold.bottomNavigationBar has NO wired background and
  // the shader renders flat white). Tab layout/badges/avatar are fed as custom
  // tab widgets; ONE island; the classic bar below stays byte-identical for
  // the kill-switch and the thermal governor.
  Widget _buildGlassScaffold(
    BuildContext context,
    Widget body,
    AppController controller,
  ) {
    return GlassScaffold(
      body: body,
      // EXPLICIT brightness control (2026-07-19): the content-aware flip fought
      // the theme tint — in light mode the bar refused to go white. We drive
      // the tint and the icon colours ourselves from the app theme instead.
      contentAwareBrightness: false,
      bottomBar: StreamBuilder<void>(
        stream: controller.changed,
        builder: (context, _) {
          final l10n = context.l10n;
          final cs = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          // FULLY OPAQUE (owner: "не полупрозрачные"): standard solid white in
          // dark, solid black in light; the active tab takes the app accent.
          final unselected = isDark ? Colors.white : Colors.black;
          final avatarPath = (controller.myAvatarPath ?? '').trim();
          return FutureBuilder<List<Conversation>>(
            future: _conversationsForNavBadges(),
            initialData: controller.cachedConversations,
            builder: (context, snapshot) {
              final convos = snapshot.data ?? const <Conversation>[];
              final counts = _countUnreadNavBadges(convos);
              return GlassTabBar.bottom(
                selectedIndex: _tab,
                onTabSelected: _setTab,
                // Explicit premium (the bar's own default is `standard`) — the
                // full lens is the centrepiece. Thermal step-down drops it to
                // the cheap path once the device reports `serious`.
                // Always premium: the thermal guard swaps the entire shell to
                // the classic bar rather than serving a flat, still-costly tier.
                quality: GlassQuality.premium,
                // NO adaptiveBrightness: it overrode the theme-driven colours.
                // The OWNER-TUNED lens, theme-adaptive tint (dark = the approved
                // grey; light = white). Shared with every island.
                settings: secretlyIslandGlass(
                  Theme.of(context).brightness,
                ),
                // The floating pill refracts ONLY while it slides between tabs;
                // at rest it swaps to the flat grey oval so it no longer bends
                // the left edge of long labels (Telegram-style). See
                // [secretlyIslandLensFlat].
                indicatorSettings: _navLensRefract
                    ? secretlyIslandGlass(Theme.of(context).brightness)
                    : secretlyIslandLensFlat(Theme.of(context).brightness),
                // Springier press so tapping a tab squishes the glass like
                // Telegram (built-in LiquidStretch; a Transform, not a shader —
                // cheap). Default 1.04.
                pressScale: 1.08,
                selectedIconColor: cs.primary,
                selectedLabelColor: cs.primary,
                unselectedIconColor: unselected,
                unselectedLabelColor: unselected,
                // Bold labels, fully opaque, colour inherited from the
                // selected/unselected label colours above.
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
                // SOLID icons everywhere (owner: the outlined inactive glyphs
                // read as "прозрачные с окантовкой"). Both states use the
                // FILLED variant; only the colour differs — inactive = solid
                // white/black, active = the app accent.
                tabs: [
                  GlassTab(
                    icon: _glassTabIcon(
                      AppIcons.chatsFilled,
                      badge: counts.chats,
                      color: unselected,
                    ),
                    activeIcon: _glassTabIcon(
                      AppIcons.chatsFilled,
                      badge: counts.chats,
                      color: cs.primary,
                    ),
                    label: l10n.tabChats,
                  ),
                  GlassTab(
                    icon: _glassTabIcon(
                      AppIcons.groupsFilled,
                      badge: counts.rooms,
                      color: unselected,
                    ),
                    activeIcon: _glassTabIcon(
                      AppIcons.groupsFilled,
                      badge: counts.rooms,
                      color: cs.primary,
                    ),
                    label: _roomsLabel(context),
                  ),
                  GlassTab(
                    icon: _glassCenterAvatar(avatarPath),
                    label: l10n.tabProfile,
                  ),
                  GlassTab(
                    icon: _glassTabIcon(
                      AppIcons.contactsFilled,
                      color: unselected,
                    ),
                    activeIcon: _glassTabIcon(
                      AppIcons.contactsFilled,
                      color: cs.primary,
                    ),
                    label: l10n.tabContacts,
                  ),
                  // Значок поддержки на «Настройках»: сама строка поддержки
                  // лежит внутри этой вкладки, поэтому иначе о непрочитанном
                  // ответе можно узнать, только зайдя туда.
                  GlassTab(
                    icon: _glassTabIcon(
                      AppIcons.settingsFilled,
                      color: unselected,
                      badge: widget.controller.supportUnreadCount,
                      dot: widget.controller.supportAwaitingReply,
                    ),
                    activeIcon: _glassTabIcon(
                      AppIcons.settingsFilled,
                      color: cs.primary,
                      badge: widget.controller.supportUnreadCount,
                      dot: widget.controller.supportAwaitingReply,
                    ),
                    label: l10n.settingsTitle,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // A custom GlassTab.icon is a Widget, so the bar's selected/unselectedIcon
  // COLOR does not reach the Icon inside — it has to be coloured here. Callers
  // pass the resolved colour (unselected fill for `icon`, accent for
  // `activeIcon`).
  Widget _glassTabIcon(
    IconData icon, {
    int badge = 0,
    bool dot = false,
    required Color color,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 24, color: color),
        if (badge > 0)
          Positioned(
            top: -5,
            right: -7,
            child: _NavUnreadBadge(count: badge),
          )
        // Точка без числа — «обращение в поддержку в работе». Показывается
        // только когда числа нет, иначе два значка налезли бы друг на друга.
        else if (dot)
          const Positioned(
            top: -3,
            right: -4,
            child: SupportBadge(count: 0, awaiting: true, compact: true),
          ),
      ],
    );
  }

  Widget _glassCenterAvatar(String avatarPath) {
    final hasAvatar = avatarPath.isNotEmpty && File(avatarPath).existsSync();
    return SizedBox(
      width: 26,
      height: 26,
      child: ClipOval(
        child: hasAvatar
            ? Image.file(
                File(avatarPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 16, rounded: true),
              )
            : const Icon(AppIcons.profile, size: 22),
      ),
    );
  }

  void _openRoomCall(CachedRoomCall call, String title) {
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => RoomCallScreen(
          controller: widget.controller,
          groupId: call.roomId,
          initialTitle: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    // Policy (incl. the desktop-OS opt-out) lives in one place —
    // see [useLegacyWideLayout].
    final isDesktopLike = useLegacyWideLayout(
      MediaQuery.of(context).size.width,
    );
    final pages = [
      ChatsScreen(key: const ValueKey('tab-chats'), controller: controller),
      GroupsScreen(key: const ValueKey('tab-groups'), controller: controller),
      ProfileScreen(key: const ValueKey('tab-profile'), controller: controller),
      ContactsScreen(
        key: const ValueKey('tab-contacts'),
        controller: controller,
      ),
      SettingsScreen(
        key: const ValueKey('tab-settings'),
        controller: controller,
      ),
    ];
    // Ряд держит `TabBarView`: он же даёт свайп пальцем и он же при переходе
    // через несколько разделов оставляет в ряду только два — откуда и куда.
    final pageView = TabBarView(
      controller: _tabController,
      physics: const BouncingScrollPhysics(),
      children: pages,
    );
    final mobileBottomInset = MediaQuery.of(context).viewPadding.bottom;
    // Pill sits at `bottom: inset + 10`, so its bottom edge is `inset + 10`
    // above the screen bottom. Stop the fade exactly at that edge so it only
    // darkens the strip BELOW the pill (system gesture area) and never overlaps
    // the pill itself — otherwise the fade + the pill's own background stacked
    // and looked like a doubled panel under the nav.
    final fadeHeight = mobileBottomInset + 10;
    final content = Stack(
      children: [
        pageView,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: fadeHeight,
          child: const IgnorePointer(child: SystemBottomFadeLayer()),
        ),
      ],
    );

    if (isDesktopLike) {
      return Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    StreamBuilder<void>(
                      stream: controller.changed,
                      builder: (context, _) {
                        final l10n = context.l10n;
                        return FutureBuilder<List<Conversation>>(
                          future: _conversationsForNavBadges(),
                          initialData: controller.cachedConversations,
                          builder: (context, snapshot) {
                            final convos =
                                snapshot.data ?? const <Conversation>[];
                            final counts = _countUnreadNavBadges(convos);
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 18,
                                  sigmaY: 18,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Theme.of(context).colorScheme.surface
                                            .withValues(alpha: 0.8),
                                        Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.72),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.34),
                                    ),
                                  ),
                                  child: NavigationRail(
                                    extended: false,
                                    minWidth: 78,
                                    selectedIndex: _tab <= 1 ? _tab : _tab - 1,
                                    onDestinationSelected: (value) {
                                      final newTab = value <= 1
                                          ? value
                                          : value + 1;
                                      if (newTab == _tab) return;
                                      setState(() {
                                        _tab = newTab;
                                      });
                                    },
                                    groupAlignment: -0.6,
                                    useIndicator: true,
                                    labelType: NavigationRailLabelType.all,
                                    leading: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 4,
                                      ),
                                      child: _DesktopRailAvatarButton(
                                        avatarPath: controller.myAvatarPath,
                                        onTap: () =>
                                            _openDesktopProfileDialog(context),
                                      ),
                                    ),
                                    destinations: [
                                      NavigationRailDestination(
                                        icon: _RailNavIcon(
                                          icon: AppIcons.chats,
                                          badgeCount: counts.chats,
                                        ),
                                        selectedIcon: _RailNavIcon(
                                          icon: AppIcons.chatsFilled,
                                          badgeCount: counts.chats,
                                        ),
                                        label: Text(l10n.tabChats),
                                      ),
                                      NavigationRailDestination(
                                        icon: _RailNavIcon(
                                          icon: AppIcons.groups,
                                          badgeCount: counts.rooms,
                                        ),
                                        selectedIcon: _RailNavIcon(
                                          icon: AppIcons.groupsFilled,
                                          badgeCount: counts.rooms,
                                        ),
                                        label: Text(_roomsLabel(context)),
                                      ),
                                      NavigationRailDestination(
                                        icon: const Icon(AppIcons.contacts),
                                        selectedIcon: const Icon(
                                          AppIcons.contactsFilled,
                                        ),
                                        label: Text(l10n.tabContacts),
                                      ),
                                      NavigationRailDestination(
                                        icon: const Icon(AppIcons.settings),
                                        selectedIcon: const Icon(
                                          AppIcons.settingsFilled,
                                        ),
                                        label: Text(l10n.settingsTitle),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChatsScreen(
                        controller: controller,
                        desktopShellTab: _tab,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: _RoomCallReturnSurface(
                controller: controller,
                onOpenRoomCall: _openRoomCall,
                margin: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
    }

    // Liquid glass — iOS ONLY, kill-switch + live thermal governor: a device
    // reporting serious/critical heat drops to the classic bar (the shader
    // both looks worse under GPU throttling and feeds the heat) and returns
    // to glass when it cools.
    if (kLiquidGlassNavBar && Platform.isIOS) {
      // Two reasons to drop to the classic matte bar, and they must BOTH count:
      //   * the user turned liquid glass OFF in Settings (GlassPrefs.enabled),
      //   * the device is running hot (ThermalGuard.effectsAllowed).
      // This gate used to watch only the thermal one, so the islands went matte
      // when the switch was flipped but the bottom bar kept its glass — the
      // exact "I turned it off and the panel is still glass" report. The heat
      // path already worked; mirror it for the switch.
      return ValueListenableBuilder<bool>(
        valueListenable: GlassPrefs.enabled,
        builder: (context, glassOn, __) {
          if (!glassOn) {
            return _buildClassicShell(context, content, controller);
          }
          return ValueListenableBuilder<bool>(
            valueListenable: ThermalGuard.effectsAllowed,
            builder: (context, effectsAllowed, _) {
              if (!effectsAllowed) {
                return _buildClassicShell(context, content, controller);
              }
              return _buildGlassScaffold(context, content, controller);
            },
          );
        },
      );
    }
    return _buildClassicShell(context, content, controller);
  }

  Widget _buildClassicShell(
    BuildContext context,
    Widget content,
    AppController controller,
  ) {
    return BottomSystemFadeVisibility(
      enabled: false,
      child: Scaffold(
        extendBody: true,
        // Defense-in-depth for the Android half-screen bug: the tab shell itself
        // has no text field (each tab is its own Scaffold that manages its own
        // keyboard inset, and chat opts out too), so it must never resize for the
        // IME. This keeps the shell body full-height even if a stale keyboard
        // inset ever slips through the main.dart unfocus-on-background guard.
        resizeToAvoidBottomInset: false,
        body: content,
        bottomNavigationBar: StreamBuilder<void>(
          stream: controller.changed,
          builder: (context, _) {
            final l10n = context.l10n;
            final avatarPath = controller.myAvatarPath;
            return FutureBuilder<List<Conversation>>(
              future: _conversationsForNavBadges(),
              initialData: controller.cachedConversations,
              builder: (context, snapshot) {
                final convos = snapshot.data ?? const <Conversation>[];
                final counts = _countUnreadNavBadges(convos);
                final bottomInset = MediaQuery.of(context).viewPadding.bottom;
                // Telegram-style matte glass (same recipe as the chat-header
                // islands): big blur + a very light white gradient veil (the
                // matte blur dominates) plus a specular top-edge highlight for
                // volume.
                final isDarkNav =
                    Theme.of(context).brightness == Brightness.dark;
                // LIGHT theme: dense near-white plate like the main-page top
                // islands (lifted by the outer shadow below). DARK unchanged.
                final navTopAlpha = isDarkNav ? 0.06 : 0.50;
                final navBottomAlpha = isDarkNav ? 0.03 : 0.40;
                final navHighlight = isDarkNav
                    ? Colors.white.withValues(alpha: 0.24)
                    : Colors.white.withValues(alpha: 0.42);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: bottomInset + 84,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: bottomInset + 10,
                            child: CustomPaint(
                              // LIGHT theme only: thin outer-ring shadow that
                              // lifts the nav plate (interior clipped, so the
                              // grey never shows through its translucency).
                              painter: isDarkNav
                                  ? null
                                  : const IslandOuterShadowPainter(
                                      radius: 28,
                                      color: Color(0x12000000),
                                    ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: _navBlur(
                                  frosted: PanelPrefs.frostedEnabled.value,
                                  child: CustomPaint(
                                    foregroundPainter:
                                        GlassHighlightBorderPainter(
                                          radius: 28,
                                          strokeWidth: 1.3,
                                          color: navHighlight,
                                        ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            // Frosted OFF ⇒ a solid plate.
                                            // These alphas are meant to sit on
                                            // a blur; alone they let the page
                                            // through and the bar disappears.
                                            if (!PanelPrefs
                                                .frostedEnabled
                                                .value) ...[
                                              opaquePanelFill(context),
                                              opaquePanelFill(context),
                                            ] else ...[
                                              Colors.white.withValues(
                                                alpha: navTopAlpha,
                                              ),
                                              Colors.white.withValues(
                                                alpha: navBottomAlpha,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          2,
                                          4,
                                          2,
                                          4,
                                        ),
                                        child: Row(
                                          children: [
                                            _NavItem(
                                              selected: _tab == 0,
                                              icon: AppIcons.chatsFilled,
                                              selectedIcon:
                                                  AppIcons.chatsFilled,
                                              label: l10n.tabChats,
                                              badgeCount: counts.chats,
                                              onTap: () => _setTab(0),
                                            ),
                                            _NavItem(
                                              selected: _tab == 1,
                                              icon: AppIcons.groupsFilled,
                                              selectedIcon:
                                                  AppIcons.groupsFilled,
                                              label: _roomsLabel(context),
                                              badgeCount: counts.rooms,
                                              onTap: () => _setTab(1),
                                            ),
                                            _CenterProfileNavItem(
                                              selected: _tab == 2,
                                              label: l10n.tabProfile,
                                              avatarPath: avatarPath,
                                              frameId: controller.myFrameId,
                                              onTap: () => _setTab(2),
                                            ),
                                            _NavItem(
                                              selected: _tab == 3,
                                              icon: AppIcons.contactsFilled,
                                              selectedIcon:
                                                  AppIcons.contactsFilled,
                                              label: l10n.tabContacts,
                                              onTap: () => _setTab(3),
                                            ),
                                            _NavItem(
                                              selected: _tab == 4,
                                              icon: AppIcons.settingsFilled,
                                              selectedIcon:
                                                  AppIcons.settingsFilled,
                                              label: l10n.settingsTitle,
                                              onTap: () => _setTab(4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RoomCallReturnSurface extends StatelessWidget {
  const _RoomCallReturnSurface({
    required this.controller,
    required this.onOpenRoomCall,
    required this.margin,
  });

  final AppController controller;
  final void Function(CachedRoomCall call, String title) onOpenRoomCall;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: controller.changed,
      builder: (context, _) {
        return FutureBuilder<(CachedRoomCall?, Conversation?)>(
          future: () async {
            final call = await controller.getPrimarySelfJoinedCachedRoomCall();
            if (call == null) {
              return (null, null);
            }
            final conversations = await controller.listConversations();
            Conversation? conversation;
            for (final item in conversations) {
              if (item.convoId == call.roomId) {
                conversation = item;
                break;
              }
            }
            return (call, conversation);
          }(),
          builder: (context, snapshot) {
            final call = snapshot.data?.$1;
            if (call == null) {
              return const SizedBox.shrink();
            }
            final titleSource = snapshot.data?.$2?.title ?? call.roomId;
            final title = titleSource.trim().isEmpty
                ? call.roomId
                : titleSource;
            return RuntimeAwareRoomCallReturnBanner(
              title: title,
              call: call,
              margin: margin,
              onTap: () => onOpenRoomCall(call, title),
            );
          },
        );
      },
    );
  }
}

class _RailNavIcon extends StatelessWidget {
  const _RailNavIcon({required this.icon, required this.badgeCount});

  final IconData icon;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = badgeCount > 99 ? '99+' : '$badgeCount';
    return SizedBox(
      width: 30,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (badgeCount > 0)
            _navIconWithBadgeCutout(Icon(icon))
          else
            Icon(icon),
          if (badgeCount > 0)
            Positioned(
              top: -6,
              right: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop rail avatar button — shown at the TOP of the NavigationRail (leading)
// Displays the user's profile photo (or initials fallback); tap → Profile dialog
// ---------------------------------------------------------------------------
class _DesktopRailAvatarButton extends StatefulWidget {
  const _DesktopRailAvatarButton({
    required this.avatarPath,
    required this.onTap,
  });

  final String? avatarPath;
  final VoidCallback onTap;

  @override
  State<_DesktopRailAvatarButton> createState() =>
      _DesktopRailAvatarButtonState();
}

class _DesktopRailAvatarButtonState extends State<_DesktopRailAvatarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = (widget.avatarPath ?? '').trim();
    final hasAvatar = path.isNotEmpty && File(path).existsSync();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _hovered
                  ? cs.primary.withValues(alpha: 0.85)
                  : cs.outlineVariant.withValues(alpha: 0.55),
              width: _hovered ? 2.5 : 1.8,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: ClipOval(
            child: hasAvatar
                ? Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 16, rounded: true),
                  )
                : Icon(
                    AppIcons.profile,
                    size: 22,
                    color: cs.onSurface.withValues(alpha: 0.82),
                  ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Owner-tuned to match the liquid-glass bar: inactive glyphs are FULLY
    // opaque — solid white in dark, solid black in light — and the active tab
    // takes the app accent.
    final active = selected
        ? cs.primary
        : (isDark ? Colors.white : Colors.black);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 30,
                height: 26,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (badgeCount > 0)
                      _navIconWithBadgeCutout(
                        AnimatedNavIcon(
                          icon: selectedIcon ?? icon,
                          selected: selected,
                          color: active,
                          size: 25,
                        ),
                      )
                    else
                      AnimatedNavIcon(
                        icon: selected ? (selectedIcon ?? icon) : icon,
                        selected: selected,
                        color: active,
                        size: 25,
                      ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -6,
                        right: -7,
                        child: _NavUnreadBadge(count: badgeCount),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: active,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedNavIndicator(selected: selected, color: active),
            ],
          ),
        ),
      ),
    );
  }
}

/// Punches a soft transparent circle in the top-right corner of a nav [icon]
/// where its unread badge sits, so the gap around the badge is a true "cutout"
/// that reveals the frosted nav panel (and the blurred content) behind it.
/// A solid-coloured ring can never match the translucent, scrolling
/// background; a real hole always does.
Widget _navIconWithBadgeCutout(Widget icon) {
  return ShaderMask(
    blendMode: BlendMode.dstOut,
    shaderCallback: (Rect bounds) {
      // Centre the hole on the badge. The badge sits at Positioned(top:-6,
      // right:-7) of the 30x26 stack while the icon (25px) is centred in it, so
      // the badge centre in icon-local coords is ~(25.5, 2.5) -> Alignment
      // (1.04, -0.8). Radius ~0.5 of the shortest side ≈ 12px leaves a clean
      // ~3px gap around the ~18px badge.
      return const RadialGradient(
        center: Alignment(1.04, -0.8),
        radius: 0.5,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.8, 1.0],
      ).createShader(bounds);
    },
    child: icon,
  );
}

class _NavUnreadBadge extends StatelessWidget {
  const _NavUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CenterProfileNavItem extends StatelessWidget {
  const _CenterProfileNavItem({
    required this.selected,
    required this.label,
    required this.avatarPath,
    required this.onTap,
    this.frameId,
  });

  final bool selected;
  final String label;
  final String? avatarPath;
  final VoidCallback onTap;
  final String? frameId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = selected ? cs.primary : cs.onSurface.withValues(alpha: 0.78);
    final path = (avatarPath != null && avatarPath!.isNotEmpty)
        ? avatarPath!
        : '';
    final hasAvatar = path.isNotEmpty && File(path).existsSync();
    final frame = frameById(frameId);

    return Expanded(
      flex: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1.0, end: selected ? 1.08 : 1.0),
                duration: const Duration(milliseconds: 250),
                curve: selected ? Curves.elasticOut : Curves.easeOutCubic,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // The premium frame ring replaces the plain selection border.
                    border: frame == null
                        ? Border.all(
                            color: active.withValues(alpha: 0.95),
                            width: selected ? 2.2 : 1.4,
                          )
                        : null,
                  ),
                  child: frame == null
                      ? ClipOval(
                          child: hasAvatar
                              ? Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    AppIcons.profile,
                                    size: 21,
                                    color: active,
                                  ),
                                )
                              : Icon(AppIcons.profile, size: 21, color: active),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            // Photo inset to 0.78·40 so the ring encircles it.
                            ClipOval(
                              child: SizedBox(
                                width: 40 * 0.86,
                                height: 40 * 0.86,
                                child: hasAvatar
                                    ? Image.file(
                                        File(path),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          AppIcons.profile,
                                          size: 17,
                                          color: active,
                                        ),
                                      )
                                    : Icon(
                                        AppIcons.profile,
                                        size: 17,
                                        color: active,
                                      ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(child: frame.builder(40)),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: active,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// In-app notification banner (Telegram-style slide-from-top overlay)
// ---------------------------------------------------------------------------

class _InAppNotifBannerWidget extends StatefulWidget {
  const _InAppNotifBannerWidget({
    required this.event,
    required this.onTap,
    required this.onDismiss,
  });

  final ChatNotifEvent event;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_InAppNotifBannerWidget> createState() =>
      _InAppNotifBannerWidgetState();
}

class _InAppNotifBannerWidgetState extends State<_InAppNotifBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: SafeArea(
          bottom: false,
          // Sit close against the status bar (native heads-up notifications
          // start right under it) rather than floating with a visible gap.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
            child: Dismissible(
              key: ValueKey(widget.event.convoId),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: GestureDetector(
                onTap: widget.onTap,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  // Neutral frosted-glass "island" — the same liquid-glass
                  // language as the app's headers (blur + translucent gradient +
                  // specular highlight), no solid colour.
                  child: FrostedHeaderIsland(
                    radius: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    // Material (transparency) supplies the default text style so
                    // the Text children don't fall back to the debug yellow
                    // underline (this banner has no other Material ancestor).
                    child: Material(
                      type: MaterialType.transparency,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: Row(
                          children: [
                            _InAppNotifAvatar(event: widget.event),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.event.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.event.body,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 13,
                                      height: 1.22,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }
}

class _InAppNotifAvatar extends StatelessWidget {
  const _InAppNotifAvatar({required this.event});

  final ChatNotifEvent event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarPath = event.avatarPath?.trim();
    final seed = event.avatarSeed?.trim() ?? '';
    final Widget fallback;
    if (seed.isNotEmpty) {
      // 🔴 Та же заглушка, что у этой переписки в списке чатов (17.09.2026):
      // тот же ключ, те же две буквы и те же цвета, что на компьютере. Была
      // плоская заливка темы с одной буквой — один человек в баннере и в
      // списке выглядел по-разному.
      fallback = AvatarInitials.fallbackBubble(
        context: context,
        radius: 26,
        seed: seed,
        displayName: event.title,
      );
    } else {
      // Отправитель скрыт настройками: заглушка одна на все переписки.
      final fallbackInitial = event.title.trim().isNotEmpty
          ? event.title.trim().characters.first.toUpperCase()
          : 'S';
      fallback = Container(
        color: cs.primaryContainer,
        alignment: Alignment.center,
        child: Text(
          fallbackInitial,
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return SizedBox(
      width: 52,
      height: 52,
      child: ClipOval(
        child: avatarPath == null || avatarPath.isEmpty
            ? fallback
            : Image.file(
                File(avatarPath),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}


/// The nav plate blurs only while frosted panels are on. Off, it paints a
/// solid fill and the backdrop pass would cost a full-screen capture per frame
/// for nothing — which is exactly what the Power setting exists to avoid.
Widget _navBlur({required bool frosted, required Widget child}) {
  if (!frosted) return child;
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
    child: child,
  );
}
