// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'scroll_feel.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'animations/animations.dart';
import 'icons/app_icons.dart';

import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/app_controller.dart';
import '../calls/call_failure.dart';
import '../calls/call_manager.dart';
import '../rooms/room_policy_failure.dart';
import 'app_asset_paths.dart';
import 'call_error_text.dart';
import 'call_history_screen.dart';
import '../entitlements/cosmetic_catalog.dart' show kNoProfileCoverId;
import 'chat_screen.dart';
import 'chat_screen_l10n.dart' show chatLastSeenText;
import 'contact_share_sheet.dart';
import 'edit_contact_screen.dart';
import 'emoji/noto_status_emoji.dart';
import 'favorites_title.dart';
import 'fullscreen_image_viewer.dart';
import 'l10n.dart';
import 'motion/app_dialogs.dart';
import 'motion/press_feedback.dart';
import 'premium/cosmetic_animation_scope.dart';
import 'premium/cosmetics_catalog.dart';
import 'premium/live_covers.dart';
import 'premium/live_frames.dart';
import 'report_abuse_sheet.dart';
import 'room_policy_error_text.dart';
import 'share_utils.dart';
import 'settings_group.dart';
import 'apple_settings_row.dart';
import 'wave1_l10n.dart';
import 'widgets/apple_menu.dart';
import 'widgets/conversation_media_gallery.dart';
import 'widgets/secretly_glass_sheet.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/broken_media_box.dart';
import 'disappearing_messages_ui.dart';
import '../messages/disappearing_flags.dart' show DisappearingPeerSupport;
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';
import 'package:secretly_app/ui/apple_glass.dart';
import 'widgets/elite_badge_mark.dart';
import 'profile/profile_motion.dart';
import 'profile/key_fingerprint.dart';
import 'media_viewer/media_flight.dart' show MediaFlightAnchor;
import 'animations/avatar_bridge_route.dart';
import '../storage/file_exists_cache.dart';

class ContactDetailsScreen extends StatefulWidget {
  const ContactDetailsScreen({
    super.key,
    required this.controller,
    required this.peerProfileId,
    this.convoId,
    this.initialTitle,
    this.initialAvatarPath,
    this.initialFrameId,
    this.initialCoverId,
    this.initialEmojiStatus,
    this.initialPremiumBadge = false,
    this.heroTag,
    this.openChatByPush = false,
  });

  final AppController controller;
  final String peerProfileId;
  final String? convoId;
  final String? initialTitle;
  final String? initialAvatarPath;

  /// Рамка, обложка, эмодзи-статус и знак собеседника, которые список уже
  /// знает (23.11.2026): первый кадр сразу с ними, а не «без рамки и с
  /// чужой обложкой» до загрузки профиля.
  final String? initialFrameId;
  final String? initialCoverId;
  final String? initialEmojiStatus;
  final bool initialPremiumBadge;
  final String? heroTag;

  /// When true (opened from a room member tap), the "Chat" action opens a real
  /// 1:1 conversation with [peerProfileId] instead of popping back — otherwise
  /// popping would return to the room this screen was opened from.
  final bool openChatByPush;

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen>
    with TickerProviderStateMixin {
  static const String _favoritesNoteAssetPath =
      AppAssetPaths.favoritesNotebookSvg;
  final ScrollController _scrollController = ScrollController();
  // Движение шапки — общий двигатель макета «Profile Motion» (21.11.2026).
  late final ProfileHeroDriver _hero = ProfileHeroDriver(
    vsync: this,
    onChanged: _onHeroChanged,
    maxPx: _avatarPullMaxPx,
    snap: _avatarSnapThreshold,
    hapticsEnabled: () => widget.controller.appHapticsEnabled,
  );
  double get _pullExpand => _hero.expand;

  void _onHeroChanged() {
    if (!mounted) return;
    _syncHeroAway();
    // Кадр движения шапки — только перерисовка, без перезагрузки профиля.
    _heroFrame = true;
    try {
      setState(() {});
    } finally {
      _heroFrame = false;
    }
  }

  /// «Мост аватара»: пока профиль прокручен и аватар летит в остров шапки,
  /// перелёт при закрытии берёт летящий аватар, а не уехавший из вида.
  final ValueNotifier<bool> _heroAway = ValueNotifier<bool>(false);

  void _syncHeroAway() {
    _heroAway.value = _hero.scroll.value > 0 && _hero.expand <= 0.001;
  }

  bool _heroFrame = false;

  /// 🔴 Прежде профиль перезагружался в КАЖДОЙ сборке (`future: _loadVm()`
  /// прямо в build) — так и подхватывались изменения после действий
  /// (`setState(() {})` после блокировки, правки и т. п.). Теперь будущее
  /// одно, а перезагрузку даёт любой setState, кроме кадров движения шапки.
  @override
  void setState(VoidCallback fn) {
    if (_heroFrame) {
      super.setState(fn);
      return;
    }
    super.setState(() {
      fn();
      _vmFuture = _loadVm();
    });
  }

  /// Отпечаток ключа собеседника — обложка по умолчанию, если он своей не
  /// выбрал (тот же узор он видит у себя в профиле).
  List<int>? _contactKeyBytes;
  // Магнитная привязка страницы (шапка → имя в шапке → галерея у шапки).
  late final ProfileScrollSnapper _snap = ProfileScrollSnapper(
    controller: _scrollController,
    hapticsEnabled: () => widget.controller.appHapticsEnabled,
  );

  void _onHeroScroll() {
    if (!_scrollController.hasClients) return;
    _hero.setScroll(_scrollController.offset);
    _syncHeroAway();
  }
  bool _avatarViewerOpening = false;
  // 240px finger travel for a full open → the photo expands at half the finger
  // speed (2× slower / more gradual) than a 1:1 drag.
  static const double _avatarPullMaxPx = 240;
  static const double _avatarSnapThreshold = 0.45;

  // Memoized profile VM (agent audit 2026-07-23). _loadVm() awaits several DB
  // reads + file-exists checks (and a network fetch for unknown peers); it used
  // to be recreated inline in build() by BOTH the header and body FutureBuilders
  // AND on every `changed` tick, churning queries right through the enter
  // transition. Cache the future, reload it throttled on `changed` so the
  // live "online"/last-seen still refreshes, and keep the last resolved VM so a
  // reload never flashes the shimmer.
  Future<_ContactDetailsVm>? _vmFuture;
  _ContactDetailsVm? _lastVm;

  /// Над обложкой собеседника тёмная сцена (живая обложка или фото) —
  /// значки строки состояния светлые и в светлой теме (24.11.2026).
  bool _coverLightStatusBar = false;
  int _vmReloadAtMs = 0;
  StreamSubscription<void>? _changedSub;
  Timer? _vmReloadTimer;
  static const int _vmReloadThrottleMs = 1500;

  /// Профиль из того, что список уже знает (имя, фото): первый кадр сразу
  /// с аватаром — Hero находит пару, полёт начинается (макет «Peer Profile
  /// Transition», 22.11.2026). Без рубильника — прежний шиммер.
  /// Последний собранный профиль и ключ по собеседнику — на время работы
  /// приложения (23.11.2026). Повторный вход в профиль сразу показывает всё
  /// как было, без мигания рамки, обложки и пустой шапки.
  static final Map<String, _ContactDetailsVm> _vmByPeer = {};
  static final Map<String, List<int>> _keyByPeer = {};

  _ContactDetailsVm? _seedVm() {
    final cached = _vmByPeer[widget.peerProfileId];
    if (cached != null) return cached;
    if (!kAvatarBridgeTransition) return null;
    final title = widget.initialTitle?.trim() ?? '';
    final path = widget.initialAvatarPath?.trim() ?? '';
    final name = title.isEmpty ? widget.peerProfileId : title;
    final username = name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final pid = widget.peerProfileId;
    // Список уже держит беседу в памяти — рамка, обложка, статус оттуда.
    final known =
        widget.controller.cachedConversation(widget.convoId ?? pid) ??
        widget.controller.cachedConversation(pid);
    return _ContactDetailsVm(
      isSeed: true,
      profileId: pid,
      title: name,
      avatarPath: path.isNotEmpty && FileExistsCache.exists(path) ? path : null,
      aboutText: null,
      isVerified: false,
      isBlocked: false,
      // «Добавить в контакты» пусть появится, а не мелькнёт и исчезнет.
      isContact: true,
      isOnline: false,
      lastSeenAtMs: null,
      usernameText: username.isEmpty
          ? '@${pid.length > 8 ? pid.substring(0, 8) : pid}'
          : '@$username',
      resolvedConvoId: widget.convoId ?? pid,
      autoDeleteSeconds: null,
      emoji: null,
      isFavoritesConvo: widget.controller.isSavedMessagesConvo(
        widget.convoId ?? '',
      ),
      frameId: widget.initialFrameId ?? known?.frameId,
      coverId: widget.initialCoverId ?? known?.coverId,
      emojiStatus: widget.initialEmojiStatus ?? known?.emojiStatus,
      premiumBadge: widget.initialPremiumBadge || (known?.premiumBadge ?? false),
    );
  }

  @override
  void initState() {
    super.initState();
    _lastVm = _seedVm();
    _contactKeyBytes = _keyByPeer[widget.peerProfileId];
    _scrollController.addListener(_onHeroScroll);
    unawaited(
      contactFingerprintKey(widget.controller, widget.peerProfileId).then((v) {
        if (v == null) return;
        _keyByPeer[widget.peerProfileId] = v;
        if (mounted && !listEquals(v, _contactKeyBytes)) {
          setState(() => _contactKeyBytes = v);
        }
      }),
    );
    _vmFuture = _loadVm();
    _changedSub = widget.controller.changed.listen((_) => _maybeReloadVm());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPeerProfileMeta();
    });
  }

  /// Reload the memoized VM at most once per [_vmReloadThrottleMs] so live
  /// presence still refreshes, without re-querying on every `changed` tick.
  void _maybeReloadVm() {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final wait = _vmReloadThrottleMs - (now - _vmReloadAtMs);
    if (wait > 0) {
      // Последнее изменение в окне не теряется: перезагрузка — по его концу.
      _vmReloadTimer ??= Timer(Duration(milliseconds: wait), () {
        _vmReloadTimer = null;
        _maybeReloadVm();
      });
      return;
    }
    _vmReloadAtMs = now;
    setState(() {}); // перезагружает vm (см. setState)
  }

  Future<void> _refreshPeerProfileMeta() async {
    final peerProfileId = widget.peerProfileId.trim();
    if (peerProfileId.isEmpty) return;
    try {
      await widget.controller.refreshProfileMeta(peerProfileId);
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // Best-effort refresh only.
    }
  }

  @override
  void dispose() {
    _changedSub?.cancel();
    _vmReloadTimer?.cancel();
    _heroAway.dispose();
    _scrollController.removeListener(_onHeroScroll);
    _scrollController.dispose();
    _hero.dispose();
    _snap.dispose();
    super.dispose();
  }

  Future<void> _openAvatarFullScreen(String? avatarPath, String title) async {
    final existingPath = _existingAvatarPath(avatarPath);
    if (existingPath == null || _avatarViewerOpening) {
      return;
    }
    // «Мост аватара»: просмотр фото под той же меткой — только когда
    // страница доехала, иначе два перелёта одного аватара наложатся.
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (kAvatarBridgeTransition &&
        routeAnimation != null &&
        !routeAnimation.isCompleted) {
      return;
    }
    _hero.releaseStretch();
    _avatarViewerOpening = true;
    try {
      await openFullscreenImageViewer(
        context,
        imagePath: existingPath,
        title: title,
        heroTag: widget.heroTag,
      );
    } finally {
      _avatarViewerOpening = false;
    }
  }

  String? _existingAvatarPath(String? rawPath) {
    final path = rawPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    try {
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() <= 0) {
        return null;
      }
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _bestExistingAvatarPath(List<String?> rawPaths) async {
    final paths = <String>[];
    for (final rawPath in rawPaths) {
      final path = _existingAvatarPath(rawPath);
      if (path == null || paths.contains(path)) continue;
      paths.add(path);
    }
    if (paths.isEmpty) return null;

    String bestPath = paths.first;
    var bestPixels = -1;
    var bestBytes = -1;
    for (final path in paths) {
      final score = await _avatarFileScore(path);
      if (score == null) continue;
      if (score.pixels > bestPixels ||
          (score.pixels == bestPixels && score.bytes > bestBytes)) {
        bestPath = path;
        bestPixels = score.pixels;
        bestBytes = score.bytes;
      }
    }
    return bestPath;
  }

  Future<({int pixels, int bytes})?> _avatarFileScore(String path) async {
    try {
      final file = File(path);
      final byteCount = await file.length();
      final bytes = await file.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      final pixels = decoded.width * decoded.height;
      decoded.dispose();
      return (pixels: pixels, bytes: byteCount);
    } catch (_) {
      return null;
    }
  }

  bool _handleAvatarPull(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.depth != 0) return false;
    // Фото тянет и ведёт слой пальца (ProfileHeroGestureLayer); здесь —
    // только магнитная привязка страницы, когда фото не «в игре».
    if (notification is ScrollEndNotification && !_hero.heroActive) {
      _snap.onScrollEnd();
    }
    return false;
  }

  /// Остров шапки. Пока страница въезжает «мостом» (Android) — сплошная
  /// плашка без размытия: размытие под кругом раскрытия — пропущенные кадры.
  Widget _bridgeIsland({required Widget child}) => AvatarBridgeEntrance(
    child: child,
    builder: (context, settled, child) => FrostedHeaderIsland(
      radius: 24,
      height: 48,
      frosted: settled ? null : false,
      child: child!,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Stack(
      children: [
        Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        // No full top bar — it cropped the cover/photo. Suppress frostedAppBar's
        // default FrostedTopBarBackground; back + more live in floating islands
        // so the cover/photo shows through behind them.
        flexibleSpace: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        systemOverlayStyle: _coverLightStatusBar
            ? const SystemUiOverlayStyle(
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : null,
        leadingWidth: 64,
        leading: Opacity(
          opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: _bridgeIsland(
              child: SizedBox(
                width: 48,
                height: 48,
                child: PressFeedback(child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: Icon(appleBackIcon(AdaptiveIcons.arrow_back)),
                  onPressed: () => Navigator.of(context).maybePop(),
                )),
              ),
            ),
          ),
        ),
        title:
            widget.controller.isSavedMessagesConvo(
              widget.convoId ?? widget.peerProfileId,
            )
            ? Opacity(
                opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
                child: Text(localizedFavoritesTitle(context)),
              )
            : null,
        actions: [
          Opacity(
            opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              child: FutureBuilder<_ContactDetailsVm>(
                future: _vmFuture,
                builder: (context, snap) {
                  final vm = snap.data;
                  if ((vm ?? _lastVm)?.isFavoritesConvo == true) {
                    return const SizedBox.shrink();
                  }
                  return _bridgeIsland(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: PressFeedback(child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: context.l10n.more,
                        onPressed: (vm == null || vm.isFavoritesConvo)
                            ? null
                            : () => _showFrostedMenu(vm),
                        icon: const Icon(AppIcons.moreVert, size: 23),
                      )),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<void>(
        stream: widget.controller.changed,
        builder: (context, _) {
          return FutureBuilder<_ContactDetailsVm>(
            future: _vmFuture,
            initialData: _lastVm,
            builder: (context, infoSnap) {
              // Retain the last resolved VM so a throttled reload never drops
              // back to the shimmer while the fresh query is in flight.
              final vm = infoSnap.data ?? _lastVm;
              if (vm != null && !vm.isSeed) {
                _vmByPeer[widget.peerProfileId] = vm;
              }
              if (vm == null) {
                return const ShimmerContactDetails();
              }
              _lastVm = vm;

              final screen = MediaQuery.of(context).size;
              final safeTop = MediaQuery.of(context).padding.top;
              final screenW = screen.width;
              final expandedImageHeight = (screen.height * 0.52).clamp(
                320.0,
                520.0,
              );
              // Animated-hero geometry — IDENTICAL formulas to own-profile
              // (profile_screen.dart): avatar + name + status + buttons all
              // live in a single Stack(Clip.none) whose positions/sizes lerp
              // on _pullExpand (0 collapsed → 1 fully-expanded photo).
              final avatarSize = lerpDouble(112, screenW, _pullExpand)!;
              // Раскрытое фото тянется вниз за пальцем и возвращается.
              final avatarHeight = lerpDouble(
                112,
                expandedImageHeight + _hero.stretchPx,
                _pullExpand,
              )!;
              final avatarRadius = lerpDouble(56, 0, _pullExpand)!;
              final collapsedAvatarTop = safeTop + 8;
              const expandedAvatarTop = 0.0;
              final avatarTop = lerpDouble(
                collapsedAvatarTop,
                expandedAvatarTop,
                _pullExpand,
              )!;

              final collapsedNameTop = collapsedAvatarTop + 112 + 18;
              final expandedNameTop = expandedAvatarTop + avatarHeight - 126;
              final nameTop = lerpDouble(
                collapsedNameTop,
                expandedNameTop,
                _pullExpand,
              )!;

              final collapsedStatusTop = collapsedNameTop + 42;
              final expandedStatusTop = expandedNameTop + 38;
              final statusTop = lerpDouble(
                collapsedStatusTop,
                expandedStatusTop,
                _pullExpand,
              )!;

              final collapsedButtonsTop = collapsedStatusTop + 38;
              final expandedButtonsTop = expandedNameTop + 58;
              final buttonsTop = lerpDouble(
                collapsedButtonsTop,
                expandedButtonsTop,
                _pullExpand,
              )!;

              final collapsedHeroBottom = collapsedButtonsTop + 66 + 20;
              final expandedHeroBottom = expandedAvatarTop + avatarHeight + 18;
              final heroHeight = lerpDouble(
                collapsedHeroBottom,
                expandedHeroBottom,
                _pullExpand,
              )!;
              final titleScale = lerpDouble(1.0, 1.06, _pullExpand)!;
              final subtitleScale = lerpDouble(1.0, 1.04, _pullExpand)!;
              // 🔴 Раскрытая шапка без фото — это заливка заглушки, а в
              // светлой теме она почти белая: белые имя и статус по ней не
              // читались (1,3–1,6 : 1). Там они остаются цветом темы; над фото
              // и над тёмной заливкой белеют, как раньше (17.09.2026).
              final heroPhoto = vm.avatarPath;
              final heroOnLightFallback =
                  !vm.isFavoritesConvo &&
                  !(heroPhoto != null &&
                      heroPhoto.isNotEmpty &&
                      FileExistsCache.exists(heroPhoto)) &&
                  AvatarInitials.fillIsLight(
                    context,
                    seed: vm.profileId.trim().isNotEmpty
                        ? vm.profileId.trim()
                        : vm.title,
                  );
              // 24.11.2026: ночная живая обложка (или своё фото) — тёмная
              // сцена в любой теме: имя на ней белое. Дневные обложки в
              // светлой теме светлые — на них имя остаётся тёмным.
              final liveCoverText =
                  !vm.isFavoritesConvo &&
                  vm.coverId != kNoProfileCoverId &&
                  (coverIsNightScene(vm.coverId) ||
                      (vm.coverImagePath ?? '').isNotEmpty);
              final heroTextWhite =
                  (_pullExpand > 0.35 && !heroOnLightFallback) || liveCoverText;
              if (liveCoverText != _coverLightStatusBar) {
                _coverLightStatusBar = liveCoverText;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {});
                });
              }
              // Back/front cover split (black hole): the peer's photo must
              // sit INSIDE the scene exactly like on the own-profile page —
              // back layer under the photo, near disk edge drawn over it.
              // 🔴 Сцены вокруг фотографии (затмение, дорожка, круги,
              // прожектор) должны знать, где портрет стоит на самом деле —
              // так же, как в своём профиле. Доли — от полосы обложки.
              final coverH = collapsedButtonsTop + 66;
              _hero.fadeY = buttonsTop + 6;
              _snap
                ..dockAt = kProfileScrollCollapse // магнит: аватар целиком в острове
                ..headerBottom = safeTop;
              final coverAvatarCenter = Offset(
                0.5,
                (avatarTop + avatarSize / 2) / coverH,
              );
              final pickedCover = vm.isFavoritesConvo
                  ? null
                  : coverBackWidgetFor(
                      vm.coverId,
                      customImagePath: vm.coverImagePath,
                      avatarCenter: Offset(
                        0.5,
                        (avatarTop + avatarSize / 2) / coverH,
                      ),
                      avatarRadius: avatarSize / 2 / screenW,
                      // Обложки команды видны всем — но только в профиле со
                      // знаком команды (23.11.2026).
                      ownerProfileId: widget.peerProfileId,
                    );
              // Своей обложки нет — «Отпечаток ключа» из его ключа. 🔴 Только
              // когда ключ известен: без него рисовался один и тот же
              // образец у всех, и при сверке «узоры не совпали» выглядело бы
              // как подмена, которой нет (разбор 22.11.2026).
              final cover =
                  vm.isFavoritesConvo || vm.coverId == kNoProfileCoverId
                  ? null
                  : (pickedCover ??
                        // Обложки нет — «Отпечаток S» (23.11.2026).
                        (kSPrintDefaultCover
                            ? coverBackWidgetFor(
                                kDefaultProfileCoverId,
                                avatarCenter: coverAvatarCenter,
                                avatarRadius: avatarSize / 2 / screenW,
                              )
                            : _contactKeyBytes == null
                            ? null
                            : coverBackWidgetFor(
                          kKeyFingerprintCoverId,
                          avatarCenter: coverAvatarCenter,
                          avatarRadius: avatarSize / 2 / screenW,
                        )));
              final coverFront = vm.isFavoritesConvo
                  ? null
                  : coverFrontWidgetFor(
                      vm.coverId,
                      customImagePath: vm.coverImagePath,
                    );
              final frame = vm.isFavoritesConvo ? null : frameById(vm.frameId);
              // Держатель нажатия — над всей шапкой: кнопка у строки
              // присутствия и портрет с рамкой стоят в разных её ветках. У
              // обычных рамок держателя нет — будить нечего.
              Widget wrapPress(Widget child) => isLiveFrameId(vm.frameId)
                  ? LiveFramePressHost(frameId: vm.frameId, child: child)
                  : child;

              final bottomInset = MediaQuery.of(context).padding.bottom;

              return Stack(
                children: [
                  ProfileHeroGestureLayer(
  driver: _hero,
  scrollController: _scrollController,
  // У «Избранного» раскрывающейся шапки нет: потягивание прятало «назад»
  // и заголовок, а страница не листалась (разбор 22.11.2026).
  enabled: !vm.isFavoritesConvo,
  onPullToFullscreen: () => _openAvatarFullScreen(vm.avatarPath, vm.title),
  child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: null,
                onVerticalDragEnd: null,
                // 🔴 23.11.2026: вкладка галереи стала короче («Файлы» →
                // «Нет файлов») — список сам подвинулся вверх, но слушатель
                // прокрутки об этом не узнаёт. Шапка оставалась «свёрнутой»
                // при почти верхнем положении: обложка и рамка пропадали,
                // страница дёргалась. Размеры поменялись — сверяем шапку.
                child: NotificationListener<Notification>(
                  onNotification: (n) {
                    if (n is ScrollMetricsNotification) {
                      _onHeroScroll();
                      return false;
                    }
                    return n is ScrollNotification && _handleAvatarPull(n);
                  },
                  child: ListView(
                    controller: _scrollController,
                    // Пока фото «в игре», страница стоит — палец ведёт фото.
                physics: ProfileHeroScrollPhysics(
                  frozen: () => _hero.freezesScroll,
                  parent: secretlyProfileScrollPhysics(),
                ),
                    padding: EdgeInsets.only(top: 0, bottom: 12 + bottomInset),
                    children: [
                      if (vm.isFavoritesConvo) ...[
                        // Favorites: no cover/frame, no pull-expand photo —
                        // keep the simple static hero (a green notes card).
                        SizedBox(height: safeTop + kToolbarHeight + 8),
                        Center(
                          child: _LargeAvatar(
                            avatarPath: null,
                            fallbackTitle: localizedFavoritesTitle(context),
                            fallbackId: widget.peerProfileId,
                            isFavoritesConvo: true,
                            favoritesAssetPath: _favoritesNoteAssetPath,
                            // «Мост аватара»: «Избранное» тоже летит из
                            // строки списка.
                            heroTag: kAvatarBridgeTransition
                                ? widget.heroTag
                                : null,
                            width: 112,
                            height: 112,
                            borderRadius: 56,
                            fallbackIconSize: 42,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            localizedFavoritesTitle(context),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            wave1Text(
                              context,
                              ru: 'Ваши личные заметки',
                              en: 'Your personal notes',
                              uk: 'Ваші особисті нотатки',
                              es: 'Tus notas personales',
                              pt: 'Suas notas pessoais',
                              ptBr: 'Suas notas pessoais',
                              fr: 'Vos notes personnelles',
                              de: 'Ihre persönlichen Notizen',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!vm.isFavoritesConvo)
                        // ANIMATED HERO — mirrors own-profile exactly: a
                        // SizedBox(heroHeight) holding a Stack(Clip.none) of
                        // cover + decoupled scrim + Positioned-lerp avatar /
                        // frame / name / status / 4 action buttons. Pulling
                        // the avatar (or overscrolling the list) drives
                        // _pullExpand and the whole hero animates together.
                        wrapPress(
                          SizedBox(
                          height: heroHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (cover != null) ...[
                                // 1) Cover image — bottom-aligned to the
                                //    buttons row; fades out as we pull-expand.
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: collapsedButtonsTop + 66,
                                  // Живая сцена слышит палец, как и в своём
                                  // профиле; фото-обложка собеседника — нет.
                                  child: LiveCoverTouch(
                                    listen:
                                        isLiveCoverId(vm.coverId) &&
                                        (vm.coverImagePath ?? '').isEmpty,
                                    child: Opacity(
                                      opacity: (1.0 - _pullExpand * 2.0).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      // Showcase: the banner is the biggest thing on this page,
                                      // so it rasterises at full resolution here.
                                      child: ProfileCoverParallax(
                                        driver: _hero,
                                        child: CoverBottomFade(
                                          coverId: vm.coverId,
                                          child: CosmeticShowcaseScope(
                                            child: CoverAvatarGeometry(
                                              center: coverAvatarCenter,
                                              radius: avatarSize / 2 / screenW,
                                              child: ProfileMotionScope(
                                                motion: _hero.motion,
                                                tint: AvatarInitials.accentColor(
                                                  seed: vm.profileId,
                                                ),
                                                child: PatternCoverKey(
                                                  keyBytes: _contactKeyBytes,
                                                  // Живая обложка не тикает,
                                                  // пока страница въезжает.
                                                  child: AvatarBridgeEntrance(
                                                    child: cover,
                                                    builder:
                                                        (context, settled, c) =>
                                                            TickerMode(
                                                              enabled: settled,
                                                              child: c!,
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
                                ),
                                // 🔴 Плашки «под цвет страницы» здесь больше
                                // нет: низ обложки сам уходит в прозрачность
                                // (`CoverBottomFade`). Плашка давала линию на
                                // стыке, особенно заметную на светлой теме.
                              ],
                              Positioned(
                                top: avatarTop,
                                left: (screenW - avatarSize) / 2,
                                child: ProfileHideWhileFlying(driver: _hero, child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _openAvatarFullScreen(
                                    vm.avatarPath,
                                    vm.title,
                                  ),
                                  onVerticalDragUpdate: null,
                                  onVerticalDragEnd: null,
                                  child: _LargeAvatar(
                                    avatarPath: vm.avatarPath,
                                    fallbackTitle: vm.title,
                                    fallbackId: vm.profileId,
                                    heroTag: widget.heroTag,
                                    heroAway: _heroAway,
                                    isFavoritesConvo: vm.isFavoritesConvo,
                                    favoritesAssetPath: _favoritesNoteAssetPath,
                                    width: avatarSize,
                                    height: avatarHeight,
                                    borderRadius: avatarRadius,
                                    fallbackIconSize: lerpDouble(
                                      42,
                                      88,
                                      _pullExpand,
                                    )!,
                                  ),
                                )),
                              ),
                              if (frame != null)
                                // Frame ring encircles the photo: box =
                                // photo/0.86 (matches FramedAvatar's gap).
                                Positioned(
                                  top:
                                      avatarTop +
                                      avatarHeight / 2 -
                                      (avatarSize / 0.86) / 2,
                                  left: (screenW - avatarSize / 0.86) / 2,
                                  child: ProfileHideWhileFlying(driver: _hero, frame: true, child: IgnorePointer(
                                    child: Opacity(
                                      opacity: (1.0 - _pullExpand * 3.0).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: SizedBox(
                                        width: avatarSize / 0.86,
                                        height: avatarSize / 0.86,
                                        // Showcase: this one big avatar paints live from vectors —
                                  // full resolution and one frame per vsync,
                                  // instead of the list-sized baked texture.
                                  child: CosmeticShowcaseScope(
                                    child: AvatarBridgeEntrance(
                                      builder: (context, settled, _) =>
                                          TickerMode(
                                            enabled: settled,
                                            child: frame.builder(
                                              avatarSize / 0.86,
                                            ),
                                          ),
                                    ),
                                  ),
                                      ),
                                    ),
                                  )),
                                ),
                              if (coverFront != null)
                                // Foreground cover pass (black hole's near
                                // disk edge) OVER the peer's photo+frame —
                                // the avatar reads as sitting INSIDE the
                                // event horizon. Transparent where empty.
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: collapsedButtonsTop + 66,
                                  child: ProfileAvatarScroll(driver: _hero, child: IgnorePointer(
                                    child: Opacity(
                                      opacity: (1.0 - _pullExpand * 2.0).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: coverFront,
                                    ),
                                  )),
                                ),
                              Positioned(
                                top: nameTop,
                                left: 24,
                                right: 24,
                                child: ProfileHideWhileFlying(driver: _hero, child: Align(
                                  alignment: Alignment.lerp(
                                    Alignment.topCenter,
                                    Alignment.topLeft,
                                    _pullExpand,
                                  )!,
                                  child: Transform.scale(
                                    scale: titleScale,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            vm.title,
                                            textAlign: _pullExpand > 0.35
                                                ? TextAlign.left
                                                : TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: heroTextWhite
                                                      ? Colors.white
                                                      : null,
                                                ),
                                          ),
                                        ),
                                        // Order: name → emoji status → premium
                                        // star. The local contact emoji (vm.emoji)
                                        // is intentionally not shown here so there
                                        // is only ONE emoji (the synced status).
                                        if (vm.emojiStatus != null &&
                                            vm.emojiStatus!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          // Rendered through the Noto catalog
                                          // so supported statuses animate and
                                          // unknown ones still draw an image
                                          // (fixes the Android tofu box). Hero
                                          // can afford the looping Lottie.
                                          NotoStatusEmoji(
                                            emoji: vm.emojiStatus!,
                                            size: 24,
                                          ),
                                        ],
                                        // Звёздочку премиума убрали; знак
                                        // «важного» — H2 (21.11.2026). Зелёная
                                        // галочка проверки — у имени
                                        // пользователя над ID (ниже).
                                        EliteBadgeMark(
                                          profileId: vm.profileId,
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                              ),
                              Positioned(
                                top: statusTop,
                                left: 24,
                                right: 24,
                                child: ProfileTextCollapse(driver: _hero, status: true, child: Align(
                                  alignment: Alignment.lerp(
                                    Alignment.topCenter,
                                    Alignment.topLeft,
                                    _pullExpand,
                                  )!,
                                  child: Transform.scale(
                                    scale: subtitleScale,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _statusText(
                                        context,
                                        vm.isOnline,
                                        vm.lastSeenAtMs,
                                      ),
                                      textAlign: _pullExpand > 0.35
                                          ? TextAlign.left
                                          : TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: heroTextWhite
                                                ? Colors.white.withValues(
                                                    alpha: 0.9,
                                                  )
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                )),
                              ),
                              // 🔴 Кнопка «разбудить» — и на странице
                              // СОБЕСЕДНИКА, если у него живая рамка: его
                              // персонажа можно погладить так же, как своего
                              // (решение владельца 24.09.2026). Нажатие живёт
                              // только на этом экране и никуда не уходит.
                              if (isLiveFrameId(vm.frameId))
                                Positioned(
                                  top: statusTop - 4,
                                  right: 20,
                                  child: Builder(
                                    builder: (ctx) => LiveFrameWakeButton(
                                      frameId: vm.frameId!,
                                      onCover: _pullExpand > 0.35,
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: buttonsTop,
                                left: 12,
                                right: 12,
                                // Four equal-width action chips (chat / sound /
                                // call / video) — same chips/onTaps as before,
                                // now animating with the hero.
                                child: ProfileFadeUnderHeader(driver: _hero, restTop: collapsedButtonsTop, line: safeTop - kToolbarHeight + 52, child: Row(
                                  children: [
                                    Expanded(
                                      child: _ActionChip(
                                        icon: AppIcons.chatBubbleSolid,
                                        label: l10n.contactDetailsChat,
                                        onTap: () => _openChatAction(vm),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ActionChip(
                                        icon: AppIcons.bellSolid,
                                        label: l10n.contactDetailsSound,
                                        onTap:
                                            _showContactNotificationPrivacySheet,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ActionChip(
                                        icon: AppIcons.callSolid,
                                        label: l10n.contactDetailsCall,
                                        onTap: () => _startSecureCall(
                                          video: false,
                                          peerName: vm.title,
                                          peerAvatarPath: vm.avatarPath,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ActionChip(
                                        icon: AppIcons.videoSolid,
                                        label: l10n.contactDetailsVideo,
                                        onTap: () => _startSecureCall(
                                          video: true,
                                          peerName: vm.title,
                                          peerAvatarPath: vm.avatarPath,
                                        ),
                                      ),
                                    ),
                                  ],
                                )),
                              ),
                            ],
                          ),
                        ),
                        ),
                      if (!vm.isFavoritesConvo) ...[
                        // The "about" text dropped out of the static column
                        // and now lives just under the animated hero so it
                        // still scrolls with the rest of the page.
                        if (vm.aboutText != null &&
                            vm.aboutText!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Text(
                              vm.aboutText!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _InfoBlock(
                            children: [
                              _InfoRow(
                                icon: AppIcons.tag,
                                tint: SettingsRowTint.teal,
                                title: vm.usernameText,
                                subtitle: l10n.contactDetailsUsernameLabel,
                                // Зелёная галочка проверки — справа от имени
                                // пользователя, сразу над ID (21.11.2026;
                                // раньше стояла у имени в шапке).
                                titleSuffix: vm.isVerified
                                    ? Padding(
                                        key: const ValueKey(
                                          'contact-verified-check',
                                        ),
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              start: 6,
                                            ),
                                        child: Icon(
                                          AppIcons.verified,
                                          color: Colors.green.shade500,
                                          size: 18,
                                          semanticLabel: l10n.verifiedLower,
                                        ),
                                      )
                                    : null,
                              ),
                              const Divider(height: 1),
                              _InfoRow(
                                icon: AppIcons.badge,
                                tint: SettingsRowTint.grey,
                                title: vm.profileId,
                                subtitle: l10n.secretlyIdLabel,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: PressFeedback(child: FilledButton.tonal(
                                        style: _idButtonStyle(context),
                                        onPressed: () => _shareContactId(vm),
                                        child: Icon(
                                          appleShareIcon(AdaptiveIcons.share_outlined),
                                          size: 18,
                                        ),
                                      )),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: PressFeedback(child: FilledButton.tonal(
                                        style: _idButtonStyle(context),
                                        onPressed: () => _copyContactId(vm),
                                        child: const Icon(
                                          AdaptiveIcons.copy_rounded,
                                          size: 18,
                                        ),
                                      )),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              _InfoRow(
                                icon: AppIcons.call,
                                tint: SettingsRowTint.green,
                                title: wave1Text(
                                  context,
                                  ru: 'История звонков',
                                  en: 'Call history',
                                  uk: 'Історія дзвінків',
                                  es: 'Historial de llamadas',
                                  pt: 'Histórico de chamadas',
                                  ptBr: 'Histórico de chamadas',
                                  fr: 'Historique des appels',
                                  de: 'Anrufverlauf',
                                ),
                                subtitle: wave1Text(
                                  context,
                                  ru: 'Все звонки с этим контактом',
                                  en: 'All calls with this contact',
                                  uk: 'Усі дзвінки з цим контактом',
                                  es: 'Todas las llamadas con este contacto',
                                  pt: 'Todas as chamadas com este contato',
                                  ptBr: 'Todas as chamadas com este contato',
                                  fr: 'Tous les appels avec ce contact',
                                  de: 'Alle Anrufe mit diesem Kontakt',
                                ),
                                trailing: const Icon(AppIcons.chevronRight),
                                onTap: () {
                                  Navigator.of(context).push(
                                    SecretlyPageRoute(
                                      builder: (_) => CallHistoryScreen(
                                        controller: widget.controller,
                                        convoId:
                                            widget.convoId ??
                                            widget.peerProfileId,
                                        peerProfileId: widget.peerProfileId,
                                        title: vm.title,
                                        avatarPath: vm.avatarPath,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: FutureBuilder<bool>(
                            future: widget.controller.isContactCallsAllowed(
                              widget.peerProfileId,
                            ),
                            builder: (context, permissionSnap) {
                              final allowed = permissionSnap.data ?? true;
                              return _InfoBlock(
                                children: [
                                  SwitchListTile.adaptive(
                                    value: allowed,
                                    // Android: отступы и цветной квадрат —
                                    // как у строк настроек (23.11.2026).
                                    contentPadding: settingsAndroidPanels
                                        ? null
                                        : const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                    secondary: settingsAndroidPanels
                                        ? const AppleRowIcon(
                                            tint: SettingsRowTint.indigo,
                                            icon: AppIcons.callAlt,
                                          )
                                        : null,
                                    title: Text(
                                      wave1Text(
                                        context,
                                        ru: 'Разрешить звонки',
                                        en: 'Allow calls',
                                        uk: 'Дозволити дзвінки',
                                        es: 'Permitir llamadas',
                                        pt: 'Permitir chamadas',
                                        ptBr: 'Permitir chamadas',
                                        fr: 'Autoriser les appels',
                                        de: 'Anrufe erlauben',
                                      ),
                                    ),
                                    subtitle: Text(
                                      wave1Text(
                                        context,
                                        ru: 'Индивидуальное разрешение на звонки для этого контакта',
                                        en: 'Per-contact call permission',
                                        uk: 'Індивідуальний дозвіл на дзвінки для цього контакту',
                                        es: 'Permiso de llamadas para este contacto',
                                        pt: 'Permissão de chamadas para este contato',
                                        ptBr:
                                            'Permissão de chamadas para este contato',
                                        fr: 'Autorisation d’appels pour ce contact',
                                        de: 'Anrufberechtigung für diesen Kontakt',
                                      ),
                                    ),
                                    onChanged: (v) => widget.controller
                                        .setContactCallsAllowed(
                                          profileId: widget.peerProfileId,
                                          allowed: v,
                                        ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                      if (!vm.isFavoritesConvo && !vm.isContact) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _InfoBlock(
                            children: [
                              ListTile(
                                leading: settingsRowLeading(
                                  icon: AppIcons.personAdd,
                                  tint: SettingsRowTint.green,
                                  fallback: const Icon(AppIcons.personAdd),
                                ),
                                title: Text(l10n.contactDetailsAddToContacts),
                                onTap: () async {
                                  await widget.controller.addContact(
                                    profileId: widget.peerProfileId,
                                    displayName: vm.title,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      // The SHARED gallery — the same widget the room
                      // profile and the chat's "Media and files" sheet use.
                      // This screen used to carry its own copy of the loader,
                      // the grid and the file list, so every improvement had
                      // to be written twice; the copy had silently fallen
                      // behind, opening photos in a bare dialog and ignoring
                      // taps on video outright.
                      SizedBox(key: _snap.galleryKey, height: 0),
// Галерея строится, когда страница доехала (и данные
                      // настоящие, а не затравка из списка).
                      AvatarBridgeEntrance(
                        // 23.11.2026: галерее нужен только id беседы — он
                        // известен и у затравки из списка; ждать полной
                        // загрузки профиля (секунды) незачем.
                        builder: (context, settled, _) =>
                            settled &&
                                (!vm.isSeed || (widget.convoId ?? '').isNotEmpty)
                            ? ConversationMediaGallerySection(
                                controller: widget.controller,
                                convoId: vm.resolvedConvoId,
                                title: vm.title,
                              )
                            : const SizedBox(height: 160),
                      ),
                      const SizedBox(height: 12),
                    ProfileSnapSpacer(snapper: _snap),
],
                  ),
                ),
              ),
),
                  // Шапка при прокрутке: фон проявляется, имя причаливает
                  // заголовком (макет «Profile Motion»).
                  if (!vm.isFavoritesConvo)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ProfileTopFade(driver: _hero),
                    ),
                    if (!vm.isFavoritesConvo) Positioned(
                      top: MediaQuery.paddingOf(context).top - kToolbarHeight + (kToolbarHeight - 48) / 2,
                      left: kProfileMiniIslandLeft,
                      right: 112,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ProfileMiniIsland(
                          driver: _hero,
                          scrollController: _scrollController,
                          child: ProfileMiniIdentity(
                          name: vm.title,
                          ghost: true,
                          reserve: 22,
                          avatar: const SizedBox.shrink(),
                          trailing: [
                            if (vm.emojiStatus != null &&
                                vm.emojiStatus!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              NotoStatusEmoji(emoji: vm.emojiStatus!, size: 16),
                            ],
                            EliteBadgeMark(
                              profileId: vm.profileId,
                              size: 15,
                              gap: 4,
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    ),
        // Один аватар летит ПОВЕРХ шапки в остров рядом с «назад».
        Positioned.fill(
          child: Builder(
            builder: (context) {
              final mq = MediaQuery.of(context);
              final safeTop = mq.padding.top;
              final vm = _lastVm;
              if (vm == null || vm.isFavoritesConvo) {
                return const SizedBox.shrink();
              }
              final label = ProfileFlyingLabel(
                driver: _hero,
                restTop: safeTop + kToolbarHeight + 8 + 112 + 18,
                restCenterX: mq.size.width / 2,
                targetLeft: kProfileMiniIslandLeft + 7 + 34 + 8,
                targetCenterY: safeTop + kToolbarHeight / 2,
                targetMaxWidth: mq.size.width - kProfileMiniIslandLeft - 112 - 49 - 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        vm.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                    if (vm.emojiStatus != null &&
                        vm.emojiStatus!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      NotoStatusEmoji(emoji: vm.emojiStatus!, size: 24),
                    ],
                    EliteBadgeMark(profileId: vm.profileId, size: 20),
                  ],
                ),
              );
              final avatar = ProfileFlyingAvatar(
                driver: _hero,
                restCenter: Offset(
                  mq.size.width / 2,
                  safeTop + kToolbarHeight + 8 + 56,
                ),
                islandCenter: Offset(kProfileMiniIslandLeft + 7 + 17, safeTop + kToolbarHeight / 2),
                child: _flyingBridge(
                  vm,
                  ProfileMiniPhoto(
                    path: vm.avatarPath,
                    seed: vm.profileId,
                    name: vm.title,
                  ),
                ),
              );
              return Stack(children: [avatar, label]);
            },
          ),
        ),
      ],
    );
  }

  /// Летящий в остров аватар несёт Hero, пока аватар страницы «в стороне»
  /// ([_heroAway]): возврат в список начинается оттуда, где аватар виден.
  Widget _flyingBridge(_ContactDetailsVm vm, Widget child) {
    final tag = widget.heroTag;
    if (!kAvatarBridgeTransition || tag == null) return child;
    final px = (112 * MediaQuery.devicePixelRatioOf(context)).round();
    final p = vm.avatarPath;
    return AvatarBridgeHero(
      tag: tag,
      side: AvatarBridgeSide.destination,
      spec: AvatarBridgeSpec(
        seed: vm.profileId,
        name: vm.title,
        fallbackId: vm.profileId,
        imagePath: p != null && p.isNotEmpty && FileExistsCache.exists(p)
            ? p
            : null,
        decodeWidth: px,
        decodeHeight: px,
        labelFraction: 0.34,
      ),
      child: child,
    );
  }

  Future<_ContactDetailsVm> _loadVm() async {
    final contacts = await widget.controller.listContacts();
    final contact = contacts
        .where((c) => c.profileId == widget.peerProfileId)
        .cast<Contact?>()
        .firstOrNull;

    final convos = await widget.controller.listConversations();
    Conversation? convo;
    if (widget.convoId != null && widget.convoId!.isNotEmpty) {
      convo = convos
          .where((c) => c.convoId == widget.convoId)
          .cast<Conversation?>()
          .firstOrNull;
    }
    convo ??= convos
        .where((c) => c.convoId == widget.peerProfileId)
        .cast<Conversation?>()
        .firstOrNull;
    convo ??= convos
        .where((c) => c.convoId == 'req:${widget.peerProfileId}')
        .cast<Conversation?>()
        .firstOrNull;

    // Prefer the RAW stored display name. widget.initialTitle is only a
    // pre-load hint and may carry a trailing emoji-status / premium glyph (the
    // chat list & header append the synced emoji to the displayed title) —
    // using it as the title would double up with the emoji-status widget shown
    // next to the name. Fall back to the hint only when nothing else is known.
    String? title;
    final loadedName = contact?.displayName?.trim();
    if (loadedName != null && loadedName.isNotEmpty) {
      title = loadedName;
    }
    final convoTitle = convo?.title.trim();
    if (title == null && convoTitle != null && convoTitle.isNotEmpty) {
      title = convoTitle;
    }
    final hintTitle = widget.initialTitle?.trim();
    if (title == null && hintTitle != null && hintTitle.isNotEmpty) {
      title = hintTitle;
    }
    // Unknown peer (e.g. a room member not in contacts): their published
    // profile was never fetched, so the only "name" we have is the raw id.
    // Pull it from the keys server once and re-resolve so the profile opens
    // with a real name instead of the id.
    if (contact == null &&
        (title == null ||
            title.trim().isEmpty ||
            title.trim() == widget.peerProfileId)) {
      try {
        await widget.controller.refreshProfileMeta(widget.peerProfileId);
        final fetched = (await widget.controller.resolveConvoTitle(
          widget.peerProfileId,
        )).trim();
        if (fetched.isNotEmpty && fetched != widget.peerProfileId) {
          title = fetched;
        }
      } catch (_) {
        // best-effort; fall back to the id below
      }
    }
    if (title == null || title.trim().isEmpty) {
      title = widget.peerProfileId;
    }

    final publishedAvatarPath = await widget.controller
        .cachedPublishedProfileAvatarPath(widget.peerProfileId);
    final cachedAvatarPath = await widget.controller.cachedProfileAvatarPath(
      widget.peerProfileId,
    );
    final avatarPath = await _bestExistingAvatarPath([
      publishedAvatarPath,
      widget.initialAvatarPath,
      contact?.avatarPath,
      convo?.avatarPath,
      cachedAvatarPath,
    ]);

    final devices = await widget.controller.listContactDevices(
      widget.peerProfileId,
    );
    final verified =
        devices.isNotEmpty && devices.every((d) => d.verifiedAtMs != null);

    final displayForUsername =
        (contact?.displayName?.trim().isNotEmpty ?? false)
        ? contact!.displayName!.trim()
        : title;

    final username = displayForUsername
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final aboutText = await widget.controller.cachedProfileBio(
      widget.peerProfileId,
    );
    // Исчезающие (ТЗ 22.10.2026): видимость решает флаг сервера; без него
    // ни пункта, ни переименования соседнего.
    final disappearConvoId =
        (convo?.convoId ?? widget.convoId ?? widget.peerProfileId);
    var disappearingVisible = false;
    int? disappearSeconds;
    try {
      disappearingVisible = await widget.controller
          .disappearingVisibleForConvo(disappearConvoId);
      if (disappearingVisible) {
        disappearSeconds = await widget.controller.getChatDisappearSeconds(
          disappearConvoId,
        );
      }
    } catch (_) {
      disappearingVisible = false;
    }

    return _ContactDetailsVm(
      disappearingVisible: disappearingVisible,
      disappearSeconds: disappearSeconds,
      profileId: widget.peerProfileId,
      title: title,
      avatarPath: avatarPath,
      aboutText: aboutText,
      isVerified: verified,
      isBlocked: await widget.controller.isProfileBlocked(widget.peerProfileId),
      isContact: contact != null,
      isOnline: convo?.isOnline ?? false,
      lastSeenAtMs: convo?.peerLastSeenAtMs,
      usernameText: username.isEmpty
          ? '@${widget.peerProfileId.substring(0, 8)}'
          : '@$username',
      resolvedConvoId:
          (convo?.convoId ?? widget.convoId ?? widget.peerProfileId),
      autoDeleteSeconds: convo?.autoDeleteSeconds,
      emoji: contact?.emoji,
      isFavoritesConvo: widget.controller.isSavedMessagesConvo(
        convo?.convoId ?? widget.convoId ?? '',
      ),
      frameId: contact?.frameId,
      coverId: contact?.coverId,
      coverImagePath: contact?.coverImagePath,
      emojiStatus: contact?.emojiStatus,
      premiumBadge: contact?.premiumBadge ?? false,
    );
  }

  String _statusText(BuildContext context, bool isOnline, int? lastSeenAtMs) {
    final l10n = context.l10n;
    if (isOnline) return l10n.onlineStatus;
    if (lastSeenAtMs == null || lastSeenAtMs <= 0) {
      return l10n.contactDetailsStatusRecently;
    }
    // Та же подпись, что в шапке чата: «был(а) в 14:32» только сегодня,
    // дальше — «вчера в …» или дата (раньше здесь всегда было одно время).
    return chatLastSeenText(
      context,
      timestampMs: lastSeenAtMs,
      now: DateTime.now(),
    );
  }

  /// "Chat" action. From a 1:1 this screen sits on top of the peer's chat, so
  /// popping returns to it. From a room member tap ([openChatByPush]) there is
  /// no such chat behind us — open a real 1:1 with this person instead of
  /// popping back into the room.
  void _openChatAction(_ContactDetailsVm vm) {
    if (!widget.openChatByPush) {
      Navigator.of(context).pop();
      return;
    }
    final pid = widget.peerProfileId.trim();
    if (pid.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          convoId: pid,
          title: vm.title,
          peerProfileIdForSend: pid,
        ),
      ),
    );
  }

  Future<void> _copyContactId(_ContactDetailsVm vm) async {
    final id = vm.profileId.trim();
    if (id.isEmpty || id == 'unknown') return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    final msg = wave1Text(
      context,
      ru: 'ID скопирован',
      en: 'ID copied',
      uk: 'ID скопійовано',
      es: 'ID copiado',
      pt: 'ID copiado',
      ptBr: 'ID copiado',
      fr: 'ID copié',
      de: 'ID kopiert',
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(msg)));
  }

  Future<void> _shareContactId(_ContactDetailsVm vm) async {
    final id = vm.profileId.trim();
    if (id.isEmpty || id == 'unknown') return;
    final text = buildProfileShareText(
      profileId: id,
      isRu: wave1LocaleIsRussian(context),
      displayName: vm.title,
    );
    await shareTextExternally(text: text);
  }

  Future<void> _openContactShareSheet(_ContactDetailsVm vm) async {
    final action = await showContactShareSheet(
      context,
      controller: widget.controller,
      profileId: widget.peerProfileId,
      title: vm.title,
      avatarPath: vm.avatarPath,
    );
    if (!mounted || action == null) return;

    final shareText = buildProfileShareText(
      profileId: widget.peerProfileId,
      isRu: wave1LocaleIsRussian(context),
      displayName: vm.title,
    );

    if (action.externalShare) {
      await shareTextExternally(text: shareText);
      return;
    }

    final conversation = action.conversation;
    if (conversation == null) return;
    await _sendSharedContactToConversation(conversation, shareText: shareText);
  }

  Future<void> _sendSharedContactToConversation(
    Conversation conversation, {
    required String shareText,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (conversation.convoId.startsWith('group:')) {
        await widget.controller.sendGroupMessage(
          groupId: conversation.convoId,
          text: shareText,
        );
      } else {
        final rawProfileId =
            (conversation.peerProfileId ?? conversation.convoId).trim();
        final peerProfileId = rawProfileId.startsWith('req:')
            ? rawProfileId.substring(4)
            : rawProfileId;
        if (peerProfileId.isEmpty) {
          throw StateError('Missing peer profile id');
        }
        await widget.controller.sendMessage(
          peerProfileId: peerProfileId,
          text: shareText,
        );
      }

      if (!mounted) return;
      final sentLabel = wave1Text(
        context,
        ru: 'Контакт отправлен в ${conversation.title}',
        en: 'Contact sent to ${conversation.title}',
        uk: 'Контакт надіслано в ${conversation.title}',
        es: 'Contacto enviado a ${conversation.title}',
        pt: 'Contato enviado para ${conversation.title}',
        ptBr: 'Contato enviado para ${conversation.title}',
        fr: 'Contact envoyé à ${conversation.title}',
        de: 'Kontakt an ${conversation.title} gesendet',
      );
      messenger
        ..clearSnackBars()
        ..showSnackBar(SecretlySnackBar(content: Text(sentLabel)));
    } on RoomPolicyFailure catch (error) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SecretlySnackBar(
            content: Text(roomPolicyErrorText(context.l10n, error)),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SecretlySnackBar(
            content: Text(context.l10n.sendFailed(error.toString())),
          ),
        );
    }
  }

  String _notificationPrivacyLevelLabel(BuildContext context, int level) {
    switch (level.clamp(0, 2)) {
      case 0:
        return wave1Text(
          context,
          ru: 'Скрыто',
          en: 'Hidden',
          uk: 'Приховано',
          es: 'Oculto',
          pt: 'Oculto',
          fr: 'Masqué',
          de: 'Verborgen',
        );
      case 1:
        return wave1Text(
          context,
          ru: 'Только отправитель',
          en: 'Sender only',
          uk: 'Лише відправник',
          es: 'Solo remitente',
          pt: 'Apenas remetente',
          fr: 'Expéditeur uniquement',
          de: 'Nur Absender',
        );
      default:
        return wave1Text(
          context,
          ru: 'Отправитель и текст',
          en: 'Sender + message',
          uk: 'Відправник і текст',
          es: 'Remitente y mensaje',
          pt: 'Remetente e mensagem',
          fr: 'Expéditeur et message',
          de: 'Absender und Nachricht',
        );
    }
  }

  Future<void> _showContactNotificationPrivacySheet() async {
    final sheetTitle = wave1Text(
      context,
      ru: 'Уведомления контакта',
      en: 'Contact notifications',
      uk: 'Сповіщення контакту',
      es: 'Notificaciones del contacto',
      pt: 'Notificações do contato',
      ptBr: 'Notificações do contato',
      fr: 'Notifications du contact',
      de: 'Kontaktbenachrichtigungen',
    );
    final globalDefaultLabel = wave1Text(
      context,
      ru: 'По умолчанию',
      en: 'Use global default',
      uk: 'За замовчуванням',
      es: 'Usar valor global',
      pt: 'Usar padrão global',
      ptBr: 'Usar padrão global',
      fr: 'Utiliser le réglage global',
      de: 'Globale Vorgabe verwenden',
    );
    final globalSettingsAppliedText = wave1Text(
      context,
      ru: 'Применены глобальные настройки',
      en: 'Using global notification privacy',
      uk: 'Застосовано глобальні налаштування',
      es: 'Usando la privacidad global de notificaciones',
      pt: 'Usando privacidade global de notificações',
      ptBr: 'Usando privacidade global de notificações',
      fr: 'Confidentialité globale des notifications utilisée',
      de: 'Globale Benachrichtigungsoptionen werden verwendet',
    );
    final notificationPrivacyUpdatedText = wave1Text(
      context,
      ru: 'Настройка уведомлений сохранена',
      en: 'Notification privacy updated',
      uk: 'Налаштування сповіщень збережено',
      es: 'Privacidad de notificaciones actualizada',
      pt: 'Privacidade das notificações atualizada',
      ptBr: 'Privacidade das notificações atualizada',
      fr: 'Confidentialité des notifications mise à jour',
      de: 'Benachrichtigungsschutz aktualisiert',
    );
    // Source of truth is the per-conversation override (for a 1:1 the
    // conversation id IS the peer profile id), shared with the in-chat
    // notifications menu so both screens — and the notification code — agree.
    final currentOverride = await widget.controller
        .getChatNotificationPrivacyOverride(widget.peerProfileId.trim());
    if (!mounted) return;
    final selected = await showModalBottomSheet<int>(
  sheetAnimationStyle: appSheetAnimationStyle,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        const options = <int>[0, 1, 2];
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: SecretlyGlassSheetSurface(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: SecretlyGlassSheetHandle()),
                    const SizedBox(height: 14),
                    Text(
                      sheetTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final option in options)
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          _notificationPrivacyLevelLabel(context, option),
                        ),
                        trailing: currentOverride == option
                            ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(option),
                      ),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: const Icon(AppIcons.refresh),
                      title: Text(globalDefaultLabel),
                      trailing: currentOverride == null
                          ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(-1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    // selected < 0 → clear the override (fall back to the global default).
    await widget.controller.setChatNotificationPrivacyOverride(
      widget.peerProfileId.trim(),
      selected < 0 ? null : selected.clamp(0, 2).toInt(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(
          selected < 0
              ? globalSettingsAppliedText
              : notificationPrivacyUpdatedText,
        ),
      ),
    );
  }

  Future<void> _startSecureCall({
    required bool video,
    required String peerName,
    String? peerAvatarPath,
  }) async {
    final cm = CallManager.instance;
    if (cm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            callErrorText(
              context.l10n,
              CallFailure(CallFailureCode.serviceUnavailable),
            ),
          ),
        ),
      );
      return;
    }
    if (cm.state.value.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            callErrorText(
              context.l10n,
              CallFailure(CallFailureCode.alreadyInProgress),
            ),
          ),
        ),
      );
      return;
    }
    try {
      await cm.startCall(
        peerProfileId: widget.peerProfileId,
        peerName: peerName.isNotEmpty ? peerName : widget.peerProfileId,
        peerAvatarPath: peerAvatarPath,
        video: video,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(callErrorText(context.l10n, e))),
      );
    }
  }

  Future<void> _showFrostedMenu(_ContactDetailsVm vm) async {
    final selected = await showFrostedPopup<String>(
      context: context,
      alignment: Alignment.topRight,
      builder: (context) {
        final l10n = context.l10n;
        final topPad = MediaQuery.of(context).padding.top + kToolbarHeight - 8;
        final cs = Theme.of(context).colorScheme;

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: topPad,
                right: 12,
                child: FrostedPopupContainer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 210,
                      maxWidth: 250,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _menuItem(
                          context,
                          value: 'share',
                          icon: AppIcons.reply,
                          title: l10n.contactDetailsShareContact,
                        ),
                        // Исчезающие у всех участников (ТЗ 22.10.2026) —
                        // только при открытом флаге сервера; без него меню
                        // ровно прежнее.
                        if (vm.disappearingVisible)
                          _menuItem(
                            context,
                            value: 'disappearing',
                            icon: AppIcons.timer,
                            title: l10n.disappearingTitle,
                            trailing: const Icon(
                              AppIcons.chevronRight,
                              size: 20,
                            ),
                          ),
                        _menuItem(
                          context,
                          value: 'autodelete',
                          icon: AppIcons.timer,
                          // Локальная уборка называется честно всегда —
                          // «на моих устройствах» (14.11.2026): у собеседника
                          // она ничего не удаляет, и «Автоудаление» без
                          // уточнения обещало больше, чем делает.
                          title: l10n.desktopContactDisappearing,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
                        ),
                        _menuItem(
                          context,
                          value: 'block',
                          icon: AppIcons.block,
                          title: vm.isBlocked ? l10n.unblock : l10n.block,
                        ),
                        _menuItem(
                          context,
                          value: 'report',
                          icon: AppIcons.errorOutline,
                          title: reportAbuseMenuLabel(context),
                          iconColor: cs.error,
                          textColor: cs.error,
                        ),
                        _menuItem(
                          context,
                          value: 'edit',
                          icon: AppIcons.edit,
                          title: l10n.contactDetailsEditContact,
                        ),
                        if (vm.isContact)
                          _menuItem(
                            context,
                            value: 'delete',
                            icon: AppIcons.delete,
                            title: l10n.contactDetailsDeleteContact,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    switch (selected) {
      case 'share':
        await _openContactShareSheet(vm);
        return;
      case 'disappearing':
        await _showDisappearingDialog(vm);
        return;
      case 'autodelete':
        await _showAutoDeleteDialog(vm);
        return;
      case 'block':
        await widget.controller.setProfileBlocked(
          profileId: widget.peerProfileId,
          blocked: !vm.isBlocked,
          deleteChatHistory: false,
        );
        if (mounted) setState(() {});
        return;
      case 'report':
        await _reportContact(vm);
        return;
      case 'edit':
        final changed = await Navigator.of(context).push<bool>(
          SecretlyPageRoute(
            builder: (_) => EditContactScreen(
              controller: widget.controller,
              profileId: widget.peerProfileId,
              initialName: vm.title,
              initialEmoji: vm.emoji,
              initialAvatarPath: vm.avatarPath,
            ),
          ),
        );
        if (changed == true && mounted) setState(() {});
        return;
      case 'delete':
        await _deleteContact(vm);
        return;
    }
  }

  Future<void> _reportContact(_ContactDetailsVm vm) async {
    final result = await showReportAbuseSheet(
      context: context,
      target: ReportAbuseTarget(
        type: ReportAbuseTargetType.profile,
        id: widget.peerProfileId,
        title: vm.title,
        conversationId: vm.resolvedConvoId,
      ),
      buildMarker: widget.controller.buildMarker,
      reporterDeviceId: widget.controller.deviceId,
      reporterProfileId: widget.controller.profileId,
      additionalTechnicalLines:
          widget.controller.pushRegistrationTechnicalLines,
      allowBlockTarget: true,
      targetAlreadyBlocked: vm.isBlocked,
    );
    if (!mounted || result == null) return;

    if (result.blockTarget && !vm.isBlocked) {
      await widget.controller.setProfileBlocked(
        profileId: widget.peerProfileId,
        blocked: true,
        deleteChatHistory: false,
      );
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(reportAbuseDeliveryMessage(context, result)),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return AppMenuRow(
      title: title,
      icon: icon,
      trailing: trailing,
      iconColor: iconColor,
      textColor: textColor,
      destructive: textColor != null || iconColor != null,
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  Future<void> _deleteContact(_ContactDetailsVm vm) async {
    if (!vm.isContact) return;
    final l10n = context.l10n;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) {
        return SecretlyAlertDialog(
          title: Text(l10n.contactDetailsDeleteConfirmTitle),
          content: Text(widget.peerProfileId),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.deleteContact),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await widget.controller.deleteContact(profileId: widget.peerProfileId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showAutoDeleteDialog(_ContactDetailsVm vm) async {
    final l10n = context.l10n;
    final options = <({int? secs, String label})>[
      (secs: null, label: l10n.contactAutoDeleteOff),
      (secs: 24 * 60 * 60, label: l10n.contactAutoDelete1Day),
      (secs: 7 * 24 * 60 * 60, label: l10n.contactAutoDelete7Days),
      (secs: 30 * 24 * 60 * 60, label: l10n.contactAutoDelete30Days),
    ];

    final selected = await showAppDialog<int?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.desktopContactDisappearing),
          children: [
            for (final opt in options)
              ListTile(
                leading: Icon(
                  vm.autoDeleteSeconds == opt.secs
                      ? AppIcons.radioChecked
                      : AppIcons.radioUnchecked,
                ),
                title: Text(opt.label),
                onTap: () => Navigator.of(context).pop(opt.secs),
              ),
          ],
        );
      },
    );

    if (selected == vm.autoDeleteSeconds) return;
    await widget.controller.setChatAutoDeleteSeconds(
      convoId: vm.resolvedConvoId,
      autoDeleteSeconds: selected,
    );
    if (!mounted) return;
    setState(() {});
  }

  /// Общий таймер чата (ТЗ 22.10.2026, шаг 3).
  Future<void> _showDisappearingDialog(_ContactDetailsVm vm) async {
    final l10n = context.l10n;
    // Проверка версий — до выбора (§2.4): человек решает, зная, что у
    // собеседника может не исчезнуть. Ответ реле кэшируется на час.
    DisappearingPeerSupport? support;
    try {
      support = await widget.controller.disappearingPeerSupport(
        vm.resolvedConvoId,
      );
    } catch (_) {
      support = DisappearingPeerSupport.unknown;
    }
    if (!mounted) return;
    final choice = await showDisappearingTimerPicker(
      context,
      current: vm.disappearSeconds,
      customMinSeconds: widget.controller.disappearCustomMinSeconds,
      customMaxSeconds: widget.controller.disappearCustomMaxSeconds,
      warning: disappearingSupportWarning(support, l10n),
    );
    if (choice == null || choice.seconds == vm.disappearSeconds) return;
    try {
      await widget.controller.setChatDisappearSeconds(
        convoId: vm.resolvedConvoId,
        seconds: choice.seconds,
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.disappearingUpdated)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.disappearingSetFailed)));
    }
    if (!mounted) return;
    setState(() {});
  }
}

class _ContactDetailsVm {
  const _ContactDetailsVm({
    required this.profileId,
    required this.title,
    required this.avatarPath,
    required this.aboutText,
    required this.isVerified,
    required this.isBlocked,
    required this.isContact,
    required this.isOnline,
    required this.lastSeenAtMs,
    required this.usernameText,
    required this.resolvedConvoId,
    required this.autoDeleteSeconds,
    required this.emoji,
    required this.isFavoritesConvo,
    this.frameId,
    this.coverId,
    this.coverImagePath,
    this.emojiStatus,
    this.premiumBadge = false,
    this.disappearingVisible = false,
    this.disappearSeconds,
    this.isSeed = false,
  });

  /// Затравка из списка до первой загрузки (см. `_seedVm`).
  final bool isSeed;

  final String profileId;
  final String title;
  final String? avatarPath;
  final String? aboutText;
  final bool isVerified;
  final bool isBlocked;
  final bool isContact;
  final bool isOnline;
  final int? lastSeenAtMs;
  final String usernameText;
  final String resolvedConvoId;
  final int? autoDeleteSeconds;

  /// Исчезающие у всех участников (ТЗ 22.10.2026): показывать ли пункт и
  /// текущий общий таймер.
  final bool disappearingVisible;
  final int? disappearSeconds;
  final String? emoji;
  final bool isFavoritesConvo;

  /// Peer's premium emoji status (cosmetic, from profile_meta).
  final String? emojiStatus;

  /// Whether the peer has a genuine paid tier (premium_badge).
  final bool premiumBadge;

  /// Peer's premium animated frame/cover ids (cosmetic, from profile_meta).
  final String? frameId;
  final String? coverId;

  /// Peer's custom cover image (cached file) when coverId == 'custom'.
  final String? coverImagePath;
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({
    required this.avatarPath,
    required this.fallbackTitle,
    this.fallbackId,
    this.heroTag,
    this.heroAway,
    required this.isFavoritesConvo,
    required this.favoritesAssetPath,
    this.width = 112,
    this.height = 112,
    this.borderRadius = 56,
    this.fallbackIconSize = 42,
  });

  final String? avatarPath;
  final String fallbackTitle;
  final String? fallbackId;
  final String? heroTag;

  /// `true` — Hero сейчас несёт летящий в остров аватар; этот «в стороне».
  final ValueListenable<bool>? heroAway;
  final bool isFavoritesConvo;
  final String favoritesAssetPath;
  final double width;
  final double height;
  final double borderRadius;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final p = avatarPath;
    final has = p != null && p.isNotEmpty && FileExistsCache.exists(p);
    final cs = Theme.of(context).colorScheme;
    // Decode the peer photo at DISPLAY resolution, not its native size. This
    // avatar lerps up to the full screen width on pull-expand, and a 2000×2000
    // source decoded at full res hitched the whole profile-enter transition
    // (agent audit 2026-07-23). cacheWidth/Height cap the decode to the box in
    // physical pixels — the image is shown at that size anyway, so it is
    // pixel-for-pixel identical on screen, just far cheaper to rasterize.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeW = (width * dpr).round().clamp(1, 4096);
    final decodeH = (height * dpr).round().clamp(1, 4096);
    final seed = (fallbackId ?? '').trim().isNotEmpty
        ? fallbackId!.trim()
        : fallbackTitle;
    // Заглушка — в общих с компьютером цветах: приглушённая заливка оттенка и
    // цветные буквы (17.09.2026).
    final fallback = AvatarInitials.colors(context, seed: seed);
    final fallbackFg = fallback.ink;
    final initials = AvatarInitials.label(
      displayName: fallbackTitle,
      fallbackId: fallbackId,
    );
    Widget avatar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: has ? cs.surfaceContainerHighest : fallback.fill,
      ),
      clipBehavior: Clip.antiAlias,
      child: isFavoritesConvo
          ? ColoredBox(
              color: const Color(0xFF0D5F38),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SvgPicture.asset(
                  favoritesAssetPath,
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            )
          : has
          ? Image.file(
              File(p),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 28, rounded: true),
              cacheWidth: decodeW,
              cacheHeight: decodeH,
            )
          : Center(
              child: Text(
                initials,
                maxLines: 1,
                style: TextStyle(
                  color: fallbackFg,
                  fontSize: fallbackIconSize * 0.62,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
    );
    if (heroTag != null) {
      final tag = heroTag!;
      if (kAvatarBridgeTransition) {
        final shortest = width < height ? width : height;
        final spec = AvatarBridgeSpec(
          seed: seed,
          name: fallbackTitle,
          fallbackId: fallbackId,
          imagePath: has && !isFavoritesConvo ? p : null,
          decodeWidth: decodeW,
          decodeHeight: decodeH,
          cornerFraction: shortest <= 0
              ? 0.5
              : (borderRadius / shortest).clamp(0.0, 0.5),
          labelFraction: shortest <= 0
              ? 0.23
              : fallbackIconSize * 0.62 / shortest,
          favoritesAsset: isFavoritesConvo ? favoritesAssetPath : null,
        );
        final inner = avatar;
        final away = heroAway;
        avatar = away == null
            ? AvatarBridgeHero(
                tag: tag,
                spec: spec,
                side: AvatarBridgeSide.destination,
                child: inner,
              )
            : ValueListenableBuilder<bool>(
                valueListenable: away,
                child: inner,
                builder: (context, isAway, child) => AvatarBridgeHero(
                  tag: isAway ? AvatarBridgeParkedTag(tag) : tag,
                  spec: spec,
                  side: AvatarBridgeSide.destination,
                  child: child!,
                ),
              );
      } else {
        avatar = Hero(tag: tag, child: avatar);
      }
      // Точка перелёта просмотра фото (тот же ключ, что у Hero).
      avatar = MediaFlightAnchor(
        tag: tag,
        borderRadius: BorderRadius.circular(borderRadius),
        child: avatar,
      );
    }
    return avatar;
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Matches own-profile's _circleAction (profile_screen.dart): frosted glass
    // island, icon + label tinted with colorScheme.onSurface (theme-aware,
    // not hard white). Horizontal padding kept at 8 so four chips fit a row
    // without overflow; other metrics (radius 18, icon 22, w600) match own.
    // Кнопка-островок сжимается при нажатии, как в профиле Telegram.
    return PressFeedback(child: FrostedHeaderIsland(
      radius: 18,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: cs.onSurface),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

/// Круглые кнопки «Поделиться» и «Копировать» у ID. Android (23.11.2026,
/// владелец: «значки ещё и синие»): нейтральные — серая подложка и значок
/// цвета текста, без цвета темы. iPhone и компьютер — прежние.
ButtonStyle _idButtonStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    shape: const CircleBorder(),
    padding: EdgeInsets.zero,
    backgroundColor: settingsAndroidPanels
        ? cs.onSurface.withValues(alpha: 0.08)
        : null,
    foregroundColor: settingsAndroidPanels ? cs.onSurface : null,
  );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Android (23.11.2026, владелец: «плашки и строки везде как в
    // настройках; прозрачность — настройкой»): та же панель и те же строки,
    // что в настройках, без линий между строками.
    if (settingsAndroidPanels) return SettingsRowsPanel(children: children);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: appleGlassDecorationOr(
        context,
        BoxDecoration(
        color: theme.cardTheme.color ?? cs.surfaceContainerHigh,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(18),
      ),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.titleSuffix,
    this.onTap,
    this.tint = SettingsRowTint.blue,
  });

  final IconData icon;

  /// Цвет квадрата значка на Android.
  final Color tint;
  final String title;
  final String subtitle;
  final Widget? trailing;

  /// Значок сразу справа от заголовка (галочка проверки у имени пользователя).
  final Widget? titleSuffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Text(title, maxLines: 1, overflow: TextOverflow.ellipsis);
    final suffix = titleSuffix;
    return ListTile(
      leading: settingsRowLeading(
        icon: icon,
        tint: tint,
        fallback: Icon(icon, color: cs.primary.withValues(alpha: 0.9)),
      ),
      title: suffix == null
          ? text
          : Row(children: [Flexible(child: text), suffix]),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
