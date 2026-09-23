// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'animations/animations.dart';
import 'icons/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../attachments/attachment_failure.dart';
import '../app/app_controller.dart';
import '../billing/show_paywall.dart';
import '../media/music_tags.dart';
import '../entitlements/cosmetic_catalog.dart';
import 'app_asset_paths.dart';
import 'attachment_error_text.dart';
import 'chat_screen.dart';
import 'fullscreen_image_viewer.dart';
import 'l10n.dart';
import 'local_image_gallery_dialog.dart';
import 'my_secretly_id_screen.dart';
import 'premium/cosmetic_animation_scope.dart';
import 'premium/cosmetics_catalog.dart';
import 'premium/live_frames.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'cover_crop_screen.dart';
import 'emoji/emoji_status_picker.dart';
import 'emoji/noto_status_emoji.dart';
import 'paywall_screen.dart' show PaywallTrigger;
import 'profile_cosmetics_screen.dart';
import 'profile_icon_picker_screen.dart';
import 'room_policy_error_text.dart';
import 'security_lock_flow.dart';
import 'share_utils.dart';
import 'settings_screen.dart';
import 'wave1_l10n.dart';
import 'widgets/app_background.dart';
import 'widgets/avatar_initials.dart';
import 'liquid_glass_flags.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/liquid_pressable.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/premium_glass.dart';
import 'widgets/secretly_glass_fab.dart';
import 'widgets/secretly_glass_sheet.dart';
import '../security/app_security_manager.dart';
import 'widgets/broken_media_box.dart';

/// A profile top-island action button: jelly press on liquid glass (iOS),
/// standard IconButton elsewhere. Icon colour follows the theme icon colour so
/// it is black in light and white in dark, like the rest of the island.
Widget _profileIslandButton(
  BuildContext context, {
  required IconData icon,
  required VoidCallback onPressed,
  String? tooltip,
  double size = 24,
}) {
  final color = Theme.of(context).iconTheme.color;
  if (liquidGlassIslandsEnabled) {
    return LiquidIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      size: size,
      color: color,
    );
  }
  return IconButton(
    tooltip: tooltip,
    icon: Icon(icon, size: size),
    onPressed: onPressed,
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _ProfileMusicMenuAction { send, forward, download, delete }

class _ProfileMusicMetadata {
  const _ProfileMusicMetadata({this.title, this.artist});

  final String? title;
  final String? artist;
}

class _ProfileMediaPickResult {
  const _ProfileMediaPickResult({required this.paths, this.rejectedCount = 0});

  final List<String> paths;
  final int rejectedCount;
}

class _ProfileMusicProgressBar extends StatelessWidget {
  const _ProfileMusicProgressBar({
    required this.progress,
    required this.color,
    required this.duration,
    this.onSeek,
  });

  final double progress;
  final Color color;
  final Duration duration;
  final void Function(Duration)? onSeek;

  void _emitSeek(double dx, double width) {
    if (onSeek == null || duration <= Duration.zero || width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0).toDouble();
    onSeek!(
      Duration(milliseconds: (duration.inMilliseconds * fraction).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
        const trackHeight = 2.0;
        const thumbSize = 8.0;
        final thumbLeft = ((barWidth - thumbSize) * clampedProgress).clamp(
          0.0,
          (barWidth - thumbSize).clamp(0.0, double.infinity).toDouble(),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onSeek == null
              ? null
              : (details) => _emitSeek(details.localPosition.dx, barWidth),
          onHorizontalDragStart: onSeek == null
              ? null
              : (details) => _emitSeek(details.localPosition.dx, barWidth),
          onHorizontalDragUpdate: onSeek == null
              ? null
              : (details) => _emitSeek(details.localPosition.dx, barWidth),
          child: SizedBox(
            height: 12,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: clampedProgress,
                  child: Container(
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  left: thumbLeft,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileConversationPickerSheet extends StatelessWidget {
  const _ProfileConversationPickerSheet({
    required this.controller,
    required this.title,
    required this.subtitle,
  });

  final AppController controller;
  final String title;
  final String subtitle;

  Future<_ProfileConversationPickerData> _loadData() async {
    final conversations = await controller.listConversations();
    final visible = conversations
        .where((conversation) => conversation.archivedAtMs == null)
        .where((conversation) => !conversation.convoId.startsWith('req:'))
        .toList(growable: false);
    final chats = visible
        .where((conversation) => !conversation.convoId.startsWith('group:'))
        .toList(growable: false);
    final rooms = visible
        .where((conversation) => conversation.convoId.startsWith('group:'))
        .toList(growable: false);
    return _ProfileConversationPickerData(chats: chats, rooms: rooms);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.76;

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SecretlyGlassSheetSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        flushToEdges: true,
        child: SizedBox(
          // Плюс системная панель: лист уходит за неё, и без добавки полезная
          // площадь стала бы меньше прежней.
          height: maxHeight + safeBottom,
          child: DefaultTabController(
            length: 2,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + safeBottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: SecretlyGlassSheetHandle()),
                  const SizedBox(height: 12),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TabBar(
                    tabs: [
                      Tab(text: context.l10n.tabChats),
                      Tab(text: context.l10n.tabGroups),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<_ProfileConversationPickerData>(
                      future: _loadData(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            ),
                          );
                        }

                        final data = snapshot.data!;
                        return TabBarView(
                          children: [
                            _ProfileConversationPickerList(
                              conversations: data.chats,
                              emptyLabel: context.l10n.noChatsYet,
                            ),
                            _ProfileConversationPickerList(
                              conversations: data.rooms,
                              emptyLabel: wave1Text(
                                context,
                                ru: 'Комнат пока нет',
                                en: 'No rooms yet',
                                uk: 'Кімнат поки немає',
                                es: 'Aun no hay salas',
                                pt: 'Ainda nao ha salas',
                                fr: 'Aucun salon pour le moment',
                                de: 'Noch keine Räume',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileConversationPickerData {
  const _ProfileConversationPickerData({
    required this.chats,
    required this.rooms,
  });

  final List<Conversation> chats;
  final List<Conversation> rooms;
}

class _ProfileConversationPickerList extends StatelessWidget {
  const _ProfileConversationPickerList({
    required this.conversations,
    required this.emptyLabel,
  });

  final List<Conversation> conversations;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: conversations.length,
      padding: EdgeInsets.zero,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final isRoom = conversation.convoId.startsWith('group:');
        final colors = Theme.of(context).colorScheme;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          tileColor: colors.surfaceContainerLow,
          leading: _ProfileConversationAvatar(conversation: conversation),
          title: Text(
            conversation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            isRoom
                ? wave1Text(context, ru: 'Комната', en: 'Room')
                : wave1Text(context, ru: 'Чат', en: 'Chat'),
          ),
          trailing: const Icon(AppIcons.send, size: 18),
          onTap: () => Navigator.of(context).pop(conversation),
        );
      },
    );
  }
}

class _ProfileConversationAvatar extends StatelessWidget {
  const _ProfileConversationAvatar({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final resolvedPath = conversation.avatarPath?.trim();
    final hasAvatar =
        resolvedPath != null &&
        resolvedPath.isNotEmpty &&
        File(resolvedPath).existsSync();
    if (hasAvatar) {
      return CircleAvatar(backgroundImage: FileImage(File(resolvedPath)));
    }

    final seed = conversation.peerProfileId ?? conversation.convoId;
    return AvatarInitials.fallbackBubble(
      context: context,
      radius: 20,
      seed: seed,
      displayName: conversation.title,
      fallbackId: seed,
    );
  }
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  static const String _profileAvatarHeroTag = 'avatar:self-profile';
  static const String _copyIconAssetPath = AppAssetPaths.copyLottie;
  static const List<String> _profileImagePickerExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  ];
  static const List<String> _profileMusicPickerExtensions = <String>[
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'flac',
  ];
  static const List<String> _profileIconPreviewAssets = <String>[
    AppAssetPaths.profileSmilePng,
    AppAssetPaths.profileStarPng,
    AppAssetPaths.profileFavoritePng,
  ];
  final _nick = TextEditingController();
  final _nickFocus = FocusNode();
  Timer? _debounce;
  bool _syncing = false;
  final ScrollController _scrollController = ScrollController();
  // Round "+" add-media button: it floats pinned at the bottom-right while its
  // inline anchor is still below the dock line, then "docks" to the bottom-bar
  // level and scrolls with the content once the anchor scrolls up into view.
  // [_addAnchorKey] marks the inline button's slot (a zero-height marker placed
  // just below the media panes); we measure its global Y on every scroll tick.
  final GlobalKey _addAnchorKey = GlobalKey();
  bool _addFabFloating = true;
  bool _collapseGestureActive = false;
  double _pullExpand = 0;
  double _profilePullPx = 0;
  double _profileFullscreenPullPx = 0;
  bool _profilePhotoWasFullyExpanded = false;
  bool _profileViewerOpening = false;
  // 240px finger travel for a full open → photo expands at half the finger speed
  // (2× slower / more gradual) than a 1:1 drag.
  static const double _profilePullMaxPx = 240;
  static const double _profileSnapThreshold = 0.45;
  static const double _profileFullscreenPullThreshold = 28;
  late final AnimationController _pullSnapController;
  late final AnimationController _copyIconController;
  late final TabController _mediaTabController;
  final ImagePicker _imagePicker = ImagePicker();
  Animation<double>? _pullSnapAnimation;
  final Map<String, Future<_ProfileMusicMetadata?>>
  _profileMusicMetadataFutures = <String, Future<_ProfileMusicMetadata?>>{};

  SharedAudioPlaybackState get _sharedAudioPlayback =>
      widget.controller.sharedAudioPlayback.value;

  String? get _activeProfileMusicPath {
    final track = _sharedAudioPlayback.currentTrack;
    if (track?.kind != SharedAudioTrackKind.profile) {
      return null;
    }
    return track?.sourcePath;
  }

  String? get _profileMusicLoadingPath {
    final playback = _sharedAudioPlayback;
    final track = playback.currentTrack;
    if (track?.kind != SharedAudioTrackKind.profile ||
        playback.loadingTrackId == null) {
      return null;
    }
    return track?.sourcePath;
  }

  Duration get _profileMusicPosition => _sharedAudioPlayback.position;
  Duration get _profileMusicDuration => _sharedAudioPlayback.duration;

  void _handleSharedAudioPlaybackChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nick.text = widget.controller.myNickname;
    _pullSnapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final animation = _pullSnapAnimation;
          if (animation == null || !mounted) return;
          setState(() {
            _pullExpand = animation.value;
            _profilePullPx = (_pullExpand * _profilePullMaxPx).clamp(
              0.0,
              _profilePullMaxPx,
            );
          });
          _updateProfilePhotoFeedback();
        });
    _copyIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _mediaTabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!mounted || _mediaTabController.indexIsChanging) return;
        setState(() {});
      });
    widget.controller.sharedAudioPlayback.addListener(
      _handleSharedAudioPlaybackChanged,
    );
    _scrollController.addListener(_updateAddFabDock);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAddFabDock());
  }

  /// Decides whether the round "+" add-media button should float (pinned at the
  /// bottom-right, above the nav bar) or dock (sit inline and scroll with the
  /// content). The inline anchor [_addAnchorKey] marks the button's natural
  /// slot; while that slot is still below the dock line (≈ the top edge of the
  /// floating bottom nav bar) the FAB floats; once the slot scrolls up past the
  /// dock line the FAB hides and the identical inline button takes over.
  void _updateAddFabDock() {
    if (!mounted) return;
    final ctx = _addAnchorKey.currentContext;
    bool floating = _addFabFloating;
    if (ctx == null) {
      // Anchor not laid out yet (e.g. very top of a tall list) → float.
      floating = true;
    } else {
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.hasSize) {
        return;
      }
      final anchorTop = box.localToGlobal(Offset.zero).dy;
      final media = MediaQuery.of(context);
      // Dock line = top of the reserved nav-bar zone (mirrors the ListView's
      // `bottom: 112 + bottomInset` padding and the floating pill height).
      final dockLineY = media.size.height - (media.padding.bottom + 112);
      floating = anchorTop > dockLineY;
    }
    if (floating != _addFabFloating) {
      setState(() => _addFabFloating = floating);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.sharedAudioPlayback.removeListener(
      _handleSharedAudioPlaybackChanged,
    );
    _nick.dispose();
    _nickFocus.dispose();
    _scrollController.removeListener(_updateAddFabDock);
    _scrollController.dispose();
    _pullSnapController.dispose();
    _copyIconController.dispose();
    _mediaTabController.dispose();
    super.dispose();
  }

  Future<void> _copyProfileId() async {
    final id = widget.controller.profileId.trim();
    if (id.isEmpty || id == 'unknown') return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    _copyIconController.forward(from: 0);
    final msg = _label(
      context,
      ru: 'ID профиля скопирован',
      en: 'Profile ID copied',
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(msg)));
  }

  Future<void> _shareProfileLink() async {
    final id = widget.controller.profileId.trim();
    if (id.isEmpty || id == 'unknown') return;
    final text = buildProfileShareText(
      profileId: id,
      isRu: wave1LocaleIsRussian(context),
      displayName: widget.controller.myNickname,
    );
    await shareTextExternally(text: text);
  }

  void _stopPullSnap() {
    if (_pullSnapController.isAnimating) {
      _pullSnapController.stop();
    }
  }

  void _updateProfilePhotoFeedback() {
    final fullyOpen = _pullExpand >= 0.995;
    final fullyClosed = _pullExpand <= 0.001;
    if (fullyOpen && !_profilePhotoWasFullyExpanded) {
      _profilePhotoWasFullyExpanded = true;
      unawaited(widget.controller.triggerUiHaptic());
      return;
    }
    if (fullyClosed && _profilePhotoWasFullyExpanded) {
      _profilePhotoWasFullyExpanded = false;
      unawaited(widget.controller.triggerUiHaptic());
    }
  }

  Future<void> _openProfileAvatarFullScreen(String? avatarPath) async {
    final path = (avatarPath ?? '').trim();
    if (path.isEmpty || !File(path).existsSync() || _profileViewerOpening) {
      return;
    }
    _profileFullscreenPullPx = 0;
    _profileViewerOpening = true;
    try {
      await openFullscreenImageViewer(
        context,
        imagePath: path,
        title: widget.controller.myNickname.trim(),
        heroTag: _profileAvatarHeroTag,
      );
    } finally {
      _profileViewerOpening = false;
    }
  }

  void _handleProfileAvatarSurfaceDragUpdate(
    DragUpdateDetails details,
    String? avatarPath,
  ) {
    final delta = details.delta.dy;
    if (_pullExpand >= 0.995 && delta > 0) {
      _profileFullscreenPullPx += delta;
      if (_profileFullscreenPullPx >= _profileFullscreenPullThreshold) {
        _profileFullscreenPullPx = 0;
        unawaited(_openProfileAvatarFullScreen(avatarPath));
        return;
      }
    } else {
      _profileFullscreenPullPx = 0;
    }

    _stopPullSnap();
    setState(() {
      _profilePullPx = (_profilePullPx + delta).clamp(0.0, _profilePullMaxPx);
      _pullExpand = (_profilePullPx / _profilePullMaxPx).clamp(0.0, 1.0);
    });
    _updateProfilePhotoFeedback();
  }

  void _handleProfileAvatarSurfaceDragEnd(DragEndDetails _) {
    _profileFullscreenPullPx = 0;
    _animatePullTo(_pullExpand >= _profileSnapThreshold ? 1.0 : 0.0);
  }

  void _animatePullTo(double target) {
    final clamped = target.clamp(0.0, 1.0);
    if ((_pullExpand - clamped).abs() < 0.001) {
      setState(() {
        _pullExpand = clamped;
        _profilePullPx = (_pullExpand * _profilePullMaxPx).clamp(
          0.0,
          _profilePullMaxPx,
        );
      });
      _updateProfilePhotoFeedback();
      return;
    }
    _stopPullSnap();
    _pullSnapAnimation = Tween<double>(begin: _pullExpand, end: clamped)
        .animate(
          CurvedAnimation(
            parent: _pullSnapController,
            curve: Curves.easeOutCubic,
          ),
        );
    _pullSnapController
      ..reset()
      ..forward();
  }

  void _scheduleSave(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.controller.setMyNickname(v);
    });
  }

  Future<void> _chooseAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (x == null) return;
    if (!mounted) return;
    // Let the user pan/zoom the photo to fit the round avatar.
    final croppedPath = await Navigator.of(context).push<String>(
      SecretlyPageRoute(
        builder: (_) => CoverCropScreen(
          imagePath: x.path,
          circle: true,
          title: wave1Text(
            context,
            ru: 'Подгоните фото',
            en: 'Adjust photo',
            uk: 'Підлаштуйте фото',
            es: 'Ajusta la foto',
            pt: 'Ajuste a foto',
            ptBr: 'Ajuste a foto',
            fr: 'Ajustez la photo',
            de: 'Foto anpassen',
          ),
        ),
      ),
    );
    // Apply ONLY when the user pressed "Готово" (croppedPath != null). On back /
    // cancel the crop screen pops null — do NOT fall back to the raw picked photo
    // (FIX 2026-07-13: it was applying the uncropped original on cancel).
    if (croppedPath == null) return;
    final bytes = await File(croppedPath).readAsBytes();
    await widget.controller.setMyAvatarFromImageBytes(bytes);
  }

  Future<void> _openProfileIconPicker() async {
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => ProfileIconPickerScreen(
          controller: widget.controller,
          initialAssetPath: widget.controller.profileIconAssetPath,
          initialGradientIndex: widget.controller.profileAvatarGradientIndex,
        ),
      ),
    );
  }

  Future<void> _showAvatarSourceSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final safeBottom = MediaQuery.paddingOf(context).bottom;
        return SecretlyGlassSheetSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          flushToEdges: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + safeBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: SecretlyGlassSheetHandle()),
                const SizedBox(height: 12),
                Text(
                  _label(
                    context,
                    ru: 'Выберите фотографию или видео',
                    en: 'Choose photo or video',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: cs.surface.withValues(alpha: 0.35),
                  leading: const Icon(AppIcons.photo),
                  title: Text(
                    _label(context, ru: 'Открыть галерею', en: 'Open gallery'),
                  ),
                  onTap: () => Navigator.of(context).pop('gallery'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: cs.surface.withValues(alpha: 0.35),
                  leading: const Icon(Icons.movie_creation_rounded),
                  title: Text(
                    wave1Text(
                      context,
                      ru: 'Видео-аватар',
                      en: 'Video avatar',
                      uk: 'Відео-аватар',
                      es: 'Avatar de vídeo',
                      pt: 'Avatar de vídeo',
                      ptBr: 'Avatar de vídeo',
                      fr: 'Avatar vidéo',
                      de: 'Video-Avatar',
                    ),
                  ),
                  subtitle: Text(
                    wave1Text(
                      context,
                      ru: 'Анимированный · другим уходит кадр',
                      en: 'Animated · others get a still frame',
                      uk: 'Анімований · іншим надсилається кадр',
                      es: 'Animado · los demás reciben un fotograma',
                      pt: 'Animado · os outros recebem um fotograma',
                      ptBr: 'Animado · os outros recebem um quadro',
                      fr: 'Animé · les autres reçoivent une image fixe',
                      de: 'Animiert · andere erhalten ein Standbild',
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop('video'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: cs.surface.withValues(alpha: 0.35),
                  leading: const Icon(AppIcons.emoji),
                  title: Text(
                    wave1Text(
                      context,
                      ru: 'Выбрать иконку',
                      en: 'Choose icon',
                      uk: 'Обрати іконку',
                      es: 'Elegir icono',
                      pt: 'Escolher ícone',
                      ptBr: 'Escolher ícone',
                      fr: 'Choisir une icône',
                      de: 'Symbol wählen',
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(
                          context,
                          ru: 'Эмодзи/иконка + фон',
                          en: 'Emoji/icon + background',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final asset in _profileIconPreviewAssets)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.surfaceContainerHighest.withValues(
                                    alpha: 0.8,
                                  ),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: Image.asset(
                                  asset,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        AppIcons.emoji,
                                        size: 14,
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).pop('icon'),
                ),
                if ((widget.controller.myAvatarPath ?? '').isNotEmpty ||
                    (widget.controller.myAvatarVideoPath ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: cs.surface.withValues(alpha: 0.35),
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: cs.error,
                    ),
                    title: Text(
                      wave1Text(
                        context,
                        ru: 'Удалить фото',
                        en: 'Delete photo',
                        uk: 'Видалити фото',
                        es: 'Eliminar foto',
                        pt: 'Eliminar foto',
                        ptBr: 'Excluir foto',
                        fr: 'Supprimer la photo',
                        de: 'Foto löschen',
                      ),
                      style: TextStyle(color: cs.error),
                    ),
                    onTap: () => Navigator.of(context).pop('delete'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    if (selected == 'gallery') {
      await _chooseAvatar();
      return;
    }
    if (selected == 'video') {
      await _chooseAvatarVideo();
      return;
    }
    if (selected == 'icon') {
      await _openProfileIconPicker();
      return;
    }
    if (selected == 'delete') {
      await widget.controller.removeMyAvatar();
      if (mounted) setState(() {});
    }
  }

  /// Picks a video, trims it to a short square silent loop, grabs a still frame,
  /// and applies it as the premium animated (video) avatar. The video plays
  /// locally; the still rides avatar_png_b64 to interlocutors.
  Future<void> _chooseAvatarVideo() async {
    if (!await _ensureCosmeticAccess()) return;
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    var loaderOpen = true;
    void closeLoader() {
      if (loaderOpen && mounted) {
        loaderOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final videoOut = '${dir.path}/avatar_video_$stamp.mp4';
      final stillOut = '${dir.path}/avatar_video_still_$stamp.png';
      // Trim ≤8s, silent, downscaled to 480-wide. IMPORTANT: use a PLAIN scale
      // (proportional, even height) — `force_original_aspect_ratio=increase`
      // + `crop` SIGSEGVs libswscale (buffer overrun) on some Android ffmpeg
      // builds. The avatar is center-cropped to a circle at render time
      // (BoxFit.cover), so a square encode isn't needed.
      final enc =
          "-y -i '${x.path}' -t 8 -an "
          "-vf scale=480:-2 "
          "-c:v libx264 -pix_fmt yuv420p -crf 28 -preset veryfast '$videoOut'";
      final encRc = await (await FFmpegKit.execute(enc)).getReturnCode();
      String playPath;
      if (ReturnCode.isSuccess(encRc) && File(videoOut).existsSync()) {
        playPath = videoOut;
      } else {
        try {
          await File(x.path).copy(videoOut);
          playPath = videoOut;
        } catch (_) {
          playPath = x.path;
        }
      }
      final stillCmd = "-y -i '$playPath' -frames:v 1 '$stillOut'";
      final stillRc = await (await FFmpegKit.execute(stillCmd)).getReturnCode();
      if (!(ReturnCode.isSuccess(stillRc) && File(stillOut).existsSync())) {
        return; // no still → abort (closeLoader runs in finally)
      }
      final stillBytes = await File(stillOut).readAsBytes();
      if (stillBytes.isEmpty) return;
      await widget.controller.setMyAvatarVideo(playPath, stillBytes);
      if (mounted) setState(() {});
    } catch (_) {
      // best-effort
    } finally {
      closeLoader();
    }
  }

  Future<void> _showProfileMoreMenu() async {
    final cs = Theme.of(context).colorScheme;
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      builder: (context) {
        final safeTop = MediaQuery.of(context).padding.top;
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: safeTop + kToolbarHeight - 10,
                    right: 10,
                  ),
                  child: FrostedPopupContainer(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 210,
                        maxWidth: 250,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context).pop('edit-name'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    AppIcons.badge,
                                    size: 22,
                                    color: cs.onSurface.withValues(alpha: 0.92),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      _label(
                                        context,
                                        ru: 'Изменить имя',
                                        en: 'Change name',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(context).pop('copy-link'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.share_outlined,
                                    size: 22,
                                    color: cs.onSurface.withValues(alpha: 0.92),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      _label(
                                        context,
                                        ru: 'Поделиться профилем',
                                        en: 'Share profile',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () =>
                                Navigator.of(context).pop('remove-avatar'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    AppIcons.delete,
                                    size: 22,
                                    color: cs.onSurface.withValues(alpha: 0.92),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      _label(
                                        context,
                                        ru: 'Удалить',
                                        en: 'Delete',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    switch (selected) {
      case 'edit-name':
        _nickFocus.requestFocus();
        return;
      case 'copy-link':
        await _shareProfileLink();
        return;
      case 'remove-avatar':
        final hasAvatar =
            widget.controller.myAvatarPath != null &&
            widget.controller.myAvatarPath!.isNotEmpty;
        if (!hasAvatar) {
          ScaffoldMessenger.of(context).showSnackBar(
            SecretlySnackBar(
              content: Text(
                _label(
                  context,
                  ru: 'Фото не установлено',
                  en: 'No profile photo set',
                ),
              ),
            ),
          );
          return;
        }
        await widget.controller.removeMyAvatar();
        return;
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => SettingsScreen(controller: widget.controller),
      ),
    );
  }

  String _label(
    BuildContext context, {
    required String ru,
    required String en,
  }) {
    return wave1Text(context, ru: ru, en: en);
  }

  void _openMyId() {
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => MySecretlyIdScreen(controller: widget.controller),
      ),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'gallery':
        return _label(context, ru: 'Фото', en: 'Photos');
      case 'backgrounds':
        return _label(context, ru: 'Фоны', en: 'Backgrounds');
      case 'music':
        return _label(context, ru: 'Музыка', en: 'Music');
      default:
        return category;
    }
  }

  String? _normalizePickedProfileFilePath(String? rawPath) {
    final trimmed = (rawPath ?? '').trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(trimmed)) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      return trimmed;
    }
    if (uri.scheme.toLowerCase() == 'file') {
      return uri.toFilePath(windows: Platform.isWindows);
    }
    return null;
  }

  String? _pickedProfileFileExtension(PlatformFile file) {
    final candidates = <String>[
      file.name,
      if ((file.path ?? '').trim().isNotEmpty) file.path!.trim(),
    ];
    for (final candidate in candidates) {
      final extension = p.extension(candidate).trim().toLowerCase();
      if (extension.isNotEmpty) {
        return extension;
      }
    }
    return null;
  }

  String _normalizedProfilePickerExtension(
    String? rawExtension, {
    required String fallback,
  }) {
    final trimmed = (rawExtension ?? '').trim().toLowerCase();
    if (trimmed.isEmpty) return fallback;
    return trimmed.startsWith('.') ? trimmed : '.$trimmed';
  }

  String _profilePickerStagingBaseNameFromName(String rawName) {
    final cleanName = p.basenameWithoutExtension(rawName).trim();
    final sanitized = cleanName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return sanitized.isEmpty ? 'profile_media' : sanitized;
  }

  String _profilePickerStagingBaseName(PlatformFile file) {
    return _profilePickerStagingBaseNameFromName(file.name);
  }

  Future<String> _stageProfileMediaBytes({
    required Uint8List bytes,
    required String category,
    required String extension,
    required String rawName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final stagingDir = Directory(
      p.join(tempDir.path, 'profile_media_picker', category),
    );
    if (!await stagingDir.exists()) {
      await stagingDir.create(recursive: true);
    }

    final targetFile = File(
      p.join(
        stagingDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_${_profilePickerStagingBaseNameFromName(rawName)}$extension',
      ),
    );
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
  }

  Future<String?> _stagePickedProfileFile({
    required PlatformFile file,
    required String category,
    required String extension,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final stagingDir = Directory(
      p.join(tempDir.path, 'profile_media_picker', category),
    );
    if (!await stagingDir.exists()) {
      await stagingDir.create(recursive: true);
    }

    final targetFile = File(
      p.join(
        stagingDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_${_profilePickerStagingBaseName(file)}$extension',
      ),
    );

    final sourcePath = _normalizePickedProfileFilePath(file.path);
    if (sourcePath != null) {
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(targetFile.path);
        return targetFile.path;
      }
    }

    final readStream = file.readStream;
    if (readStream != null) {
      final sink = targetFile.openWrite();
      try {
        await readStream.pipe(sink);
      } finally {
        await sink.close();
      }
      if (await targetFile.exists()) {
        return targetFile.path;
      }
    }

    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      await targetFile.writeAsBytes(bytes, flush: true);
      return targetFile.path;
    }

    return null;
  }

  Future<String?> _resolveProfileMediaPick(
    PlatformFile file,
    String category,
  ) async {
    final extension = _pickedProfileFileExtension(file);
    if (extension == null || extension.isEmpty) {
      return null;
    }
    final normalizedExtension = extension.toLowerCase();
    if (!widget.controller.isSupportedProfileMediaPath(
      category: category,
      sourcePath: 'selected$normalizedExtension',
    )) {
      return null;
    }

    return _stagePickedProfileFile(
      file: file,
      category: category,
      extension: normalizedExtension,
    );
  }

  Future<String?> _resolveProfileImagePick(XFile file, String category) async {
    final normalizedExtension = _normalizedProfilePickerExtension(
      p.extension(file.path),
      fallback: '.jpg',
    );
    if (!widget.controller.isSupportedProfileMediaPath(
      category: category,
      sourcePath: 'selected$normalizedExtension',
    )) {
      return null;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return _stageProfileMediaBytes(
      bytes: bytes,
      category: category,
      extension: normalizedExtension,
      rawName: p.basename(file.path),
    );
  }

  Future<_ProfileMediaPickResult> _pickImageMediaFiles(String category) async {
    try {
      final picked = await _imagePicker.pickMultiImage(
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (picked.isEmpty) {
        return const _ProfileMediaPickResult(paths: <String>[]);
      }

      final paths = <String>[];
      var rejectedCount = 0;
      for (final file in picked) {
        final path = await _resolveProfileImagePick(file, category);
        if (path == null || path.trim().isEmpty) {
          rejectedCount++;
          continue;
        }
        paths.add(path);
      }
      return _ProfileMediaPickResult(
        paths: paths,
        rejectedCount: rejectedCount,
      );
    } catch (_) {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _profileImagePickerExtensions,
        allowMultiple: true,
        withData: true,
        withReadStream: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return const _ProfileMediaPickResult(paths: <String>[]);
      }

      final paths = <String>[];
      var rejectedCount = 0;
      for (final file in picked.files) {
        final path = await _resolveProfileMediaPick(file, category);
        if (path == null || path.trim().isEmpty) {
          rejectedCount++;
          continue;
        }
        paths.add(path);
      }
      return _ProfileMediaPickResult(
        paths: paths,
        rejectedCount: rejectedCount,
      );
    }
  }

  Future<_ProfileMediaPickResult> _pickMusicMediaFiles(String category) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _profileMusicPickerExtensions,
      allowMultiple: true,
      withData: true,
      withReadStream: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return const _ProfileMediaPickResult(paths: <String>[]);
    }

    final paths = <String>[];
    var rejectedCount = 0;
    for (final file in picked.files) {
      final path = await _resolveProfileMediaPick(file, category);
      if (path == null || path.trim().isEmpty) {
        rejectedCount++;
        continue;
      }
      paths.add(path);
    }
    return _ProfileMediaPickResult(paths: paths, rejectedCount: rejectedCount);
  }

  Future<void> _pickAndAddMedia(String category) async {
    final isMusic = category == 'music';
    final picked = isMusic
        ? await _pickMusicMediaFiles(category)
        : await _pickImageMediaFiles(category);
    if (picked.paths.isEmpty && picked.rejectedCount == 0) return;

    var addedCount = 0;
    var rejectedCount = picked.rejectedCount;
    for (final path in picked.paths) {
      try {
        await widget.controller.addProfileMediaFromPath(
          category: category,
          sourcePath: path,
        );
        addedCount++;
      } on ArgumentError {
        rejectedCount++;
      }
    }

    if (!mounted) return;
    if (addedCount == 0 && rejectedCount == 0) return;
    final msg = addedCount > 0
        ? rejectedCount > 0
              ? _label(
                  context,
                  ru: 'Добавлено: $addedCount. Пропущено файлов: $rejectedCount.',
                  en: 'Added: $addedCount. Skipped files: $rejectedCount.',
                )
              : _label(
                  context,
                  ru: 'Добавлено в «${_categoryLabel(category)}»',
                  en: 'Added to ${_categoryLabel(category)}',
                )
        : isMusic
        ? _label(
            context,
            ru: 'В музыку можно добавлять MP3, WAV, M4A, AAC, OGG, OPUS и FLAC.',
            en: 'Music supports MP3, WAV, M4A, AAC, OGG, OPUS, and FLAC files.',
          )
        : _label(
            context,
            ru: 'Подходящие файлы не найдены.',
            en: 'No supported files were selected.',
          );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(msg)));
  }

  List<String> _mediaPathsForCategory(String category) {
    switch (category) {
      case 'gallery':
        return widget.controller.profileGalleryPaths;
      case 'backgrounds':
        return widget.controller.profileBackgroundPaths;
      case 'music':
        return widget.controller.profileMusicPaths;
      default:
        return const <String>[];
    }
  }

  bool _isActiveProfileMusicPath(String path) {
    return _activeProfileMusicPath == path;
  }

  bool _isProfileMusicPlaying(String path) {
    return _isActiveProfileMusicPath(path) && _sharedAudioPlayback.playing;
  }

  Duration _profileMusicDurationForPath(String path) {
    if (!_isActiveProfileMusicPath(path)) return Duration.zero;
    return _profileMusicDuration;
  }

  Duration _profileMusicPositionForPath(String path) {
    if (!_isActiveProfileMusicPath(path)) return Duration.zero;
    final duration = _profileMusicDurationForPath(path);
    if (duration <= Duration.zero) return _profileMusicPosition;
    return _profileMusicPosition > duration ? duration : _profileMusicPosition;
  }

  double _profileMusicProgressForPath(String path) {
    final duration = _profileMusicDurationForPath(path);
    if (duration <= Duration.zero) return 0;
    return (_profileMusicPositionForPath(path).inMilliseconds /
            duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  String _formatProfileMusicDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours:${remainingMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<SharedAudioTrack> _buildProfileSharedAudioTrack(String path) async {
    final unknownArtist = _label(
      context,
      ru: 'Неизвестен',
      en: 'Unknown artist',
    );
    final metadata = await _resolveProfileMusicMetadata(path);
    final rawTitle = metadata?.title?.trim();
    final rawArtist = metadata?.artist?.trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : p.basenameWithoutExtension(path);
    final artist = (rawArtist != null && rawArtist.isNotEmpty)
        ? rawArtist
        : unknownArtist;
    return SharedAudioTrack(
      trackId: 'profile:$path',
      kind: SharedAudioTrackKind.profile,
      title: title,
      artist: artist,
      artworkPath: widget.controller.myAvatarPath,
      sourcePath: path,
      resolveFilePath: () async => path,
    );
  }

  Future<void> _toggleProfileMusicPlayback(String path) async {
    if (_profileMusicLoadingPath == path) return;
    try {
      if (_isActiveProfileMusicPath(path)) {
        await widget.controller.toggleSharedAudioPlayback();
        return;
      }

      final paths = widget.controller.profileMusicPaths;
      final index = paths.indexOf(path);
      if (index < 0) {
        return;
      }
      final queue = await Future.wait(
        paths.map((item) => _buildProfileSharedAudioTrack(item)),
      );
      await widget.controller.playSharedAudioQueue(queue: queue, index: index);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _label(
              context,
              ru: 'Не удалось воспроизвести трек: $error',
              en: 'Failed to play this track: $error',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _seekProfileMusic(String path, Duration position) async {
    if (!_isActiveProfileMusicPath(path)) return;
    final duration = _profileMusicDurationForPath(path);
    if (duration <= Duration.zero) return;
    final clamped = position > duration
        ? duration
        : (position < Duration.zero ? Duration.zero : position);
    await widget.controller.seekSharedAudio(clamped);
  }

  Future<void> _stopProfileMusicIfActive(String path) async {
    if (!_isActiveProfileMusicPath(path)) return;
    await widget.controller.stopSharedAudio();
  }

  Future<void> _removeMediaAt({
    required String category,
    required int index,
  }) async {
    final paths = _mediaPathsForCategory(category);
    if (index >= 0 && index < paths.length && category == 'music') {
      await _stopProfileMusicIfActive(paths[index]);
      _profileMusicMetadataFutures.remove(paths[index]);
    }
    await widget.controller.removeProfileMediaAt(
      category: category,
      index: index,
    );
    if (!mounted) return;
    final msg = _label(context, ru: 'Удалено', en: 'Removed');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(msg)));
  }

  Widget _buildImageCategoryPane({
    required String category,
    required List<String> paths,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (paths.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                _label(context, ru: 'Пока пусто', en: 'Empty for now'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.98,
            ),
            itemCount: paths.length,
            itemBuilder: (context, index) {
              final path = paths[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openProfileImageGallery(
                      category: category,
                      paths: paths,
                      initialIndex: index,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const BrokenMediaBox(),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _removeMediaAt(
                              category: category,
                              index: index,
                            ),
                            icon: const Icon(AppIcons.close, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 6),
        _inlineAddMediaButton(category),
      ],
    );
  }

  /// Round gold "+" add-media button shown inline at the end of a media pane.
  /// It is the dock target for the floating FAB: while the FAB is pinned
  /// (floating) this inline button is invisible but still reserves its slot, so
  /// the handoff between floating ⇄ docked is seamless (no layout jump). Always
  /// right-aligned so its on-screen X matches the end-float FAB.
  Widget _inlineAddMediaButton(String category) {
    final button = _addMediaFabButton(category);
    return Align(
      alignment: Alignment.centerRight,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _addFabFloating ? 0.0 : 1.0,
        child: IgnorePointer(ignoring: _addFabFloating, child: button),
      ),
    );
  }

  /// The shared round gold "+" button visual (used both inline and floating).
  Widget _addMediaFabButton(String category) {
    return SecretlyGlassFabButton(
      tooltip: _label(context, ru: 'Добавить', en: 'Add'),
      dimension: 52,
      cornerRadius: 26,
      icon: const Icon(AppIcons.add, size: 24),
      onPressed: () => _pickAndAddMedia(category),
    );
  }

  /// Maps the currently-selected mini-gallery tab to its media category so the
  /// floating FAB adds to whatever pane the user is viewing.
  String get _activeMediaCategory => switch (_mediaTabController.index) {
    1 => 'backgrounds',
    2 => 'music',
    _ => 'gallery',
  };

  String? _profileImageMime(String filePath) {
    switch (p.extension(filePath).trim().toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      default:
        return null;
    }
  }

  Future<void> _shareLocalFileExternally({
    required String path,
    String? mime,
  }) async {
    final source = File(path);
    if (!await source.exists()) {
      throw StateError('Local file is no longer available');
    }
    final suggestedName = p.basename(path).trim();
    await SharePlus.instance.share(
      ShareParams(
        title: suggestedName,
        subject: suggestedName,
        files: [XFile(source.path, mimeType: mime, name: suggestedName)],
        fileNameOverrides: [suggestedName],
      ),
    );
  }

  Future<void> _shareProfileImageExternally(String path) async {
    try {
      await _shareLocalFileExternally(
        path: path,
        mime: _profileImageMime(path),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _label(
              context,
              ru: 'Не удалось открыть панель пересылки: $error',
              en: 'Failed to open the share sheet: $error',
            ),
          ),
        ),
      );
    }
  }

  DateTime _profileMediaTimestamp(String path) {
    try {
      return File(path).statSync().modified;
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> _deleteProfileImageFromGallery({
    required String category,
    required String path,
  }) async {
    final index = _mediaPathsForCategory(category).indexOf(path);
    if (index < 0) return;
    await _removeMediaAt(category: category, index: index);
  }

  Future<void> _openProfileImageGallery({
    required String category,
    required List<String> paths,
    required int initialIndex,
  }) async {
    if (paths.isEmpty) return;
    final items = paths
        .map(
          (path) => LocalImageGalleryItem(
            id: path,
            imagePath: path,
            timestamp: _profileMediaTimestamp(path),
          ),
        )
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          child: LocalImageGalleryDialog(
            items: items,
            initialIndex: initialIndex,
            galleryTitle: _categoryLabel(category),
            onForward: (item) => _shareProfileImageExternally(item.imagePath),
            onShare: (item) => _shareProfileImageExternally(item.imagePath),
            onDelete: (item) => _deleteProfileImageFromGallery(
              category: category,
              path: item.imagePath,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMusicCategoryPane(List<String> paths) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (paths.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                _label(context, ru: 'Пока пусто', en: 'Empty for now'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paths.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final path = paths[index];
              return FutureBuilder<_ProfileMusicMetadata?>(
                future: _resolveProfileMusicMetadata(path),
                builder: (context, snapshot) {
                  final metadata = snapshot.data;
                  final title =
                      metadata?.title ??
                      p.basenameWithoutExtension(path).trim();
                  final artist = metadata?.artist ?? _unknownMusicArtistLabel();
                  final cs = Theme.of(context).colorScheme;
                  final extLabel = _profileMusicTypeLabel(path);
                  final isActive = _isActiveProfileMusicPath(path);
                  final isPlaying = _isProfileMusicPlaying(path);
                  final isLoading = _profileMusicLoadingPath == path;
                  final progress = _profileMusicProgressForPath(path);
                  final position = _profileMusicPositionForPath(path);
                  final duration = _profileMusicDurationForPath(path);
                  final subtitle = isActive && duration > Duration.zero
                      ? '${artist.isEmpty ? _unknownMusicArtistLabel() : artist} • ${_formatProfileMusicDuration(position)} / ${_formatProfileMusicDuration(duration)}'
                      : artist;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _toggleProfileMusicPlayback(path),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isLoading)
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: cs.primary,
                                        ),
                                      )
                                    else
                                      Icon(
                                        isPlaying
                                            ? AppIcons.pause
                                            : AppIcons.play,
                                        size: isPlaying ? 16 : 18,
                                        color: cs.primary,
                                      ),
                                    Positioned(
                                      bottom: 4,
                                      child: Text(
                                        extLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 8.6,
                                              letterSpacing: 0.25,
                                              height: 1,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title.isEmpty
                                            ? p.basename(path)
                                            : title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              height: 1.05,
                                            ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                              height: 1.05,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        height: 12,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: _ProfileMusicProgressBar(
                                            progress: progress,
                                            color: cs.primary,
                                            duration: duration,
                                            onSeek: isActive
                                                ? (nextPosition) =>
                                                      _seekProfileMusic(
                                                        path,
                                                        nextPosition,
                                                      )
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              PopupMenuButton<_ProfileMusicMenuAction>(
                                tooltip: _label(
                                  context,
                                  ru: 'Действия с музыкой',
                                  en: 'Music actions',
                                ),
                                onSelected: (action) =>
                                    _handleProfileMusicAction(
                                      action,
                                      index: index,
                                      path: path,
                                    ),
                                itemBuilder: (context) => [
                                  PopupMenuItem<_ProfileMusicMenuAction>(
                                    value: _ProfileMusicMenuAction.send,
                                    child: Row(
                                      children: [
                                        const Icon(AppIcons.send, size: 18),
                                        const SizedBox(width: 10),
                                        Text(context.l10n.send),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<_ProfileMusicMenuAction>(
                                    value: _ProfileMusicMenuAction.forward,
                                    child: Row(
                                      children: [
                                        const Icon(AppIcons.forward, size: 18),
                                        const SizedBox(width: 10),
                                        Text(context.l10n.chatMenuForward),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<_ProfileMusicMenuAction>(
                                    value: _ProfileMusicMenuAction.download,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          AppIcons.cloudDownload,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _label(
                                            context,
                                            ru: 'Скачать',
                                            en: 'Download',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<_ProfileMusicMenuAction>(
                                    value: _ProfileMusicMenuAction.delete,
                                    child: Row(
                                      children: [
                                        const Icon(AppIcons.delete, size: 18),
                                        const SizedBox(width: 10),
                                        Text(context.l10n.chatMenuDelete),
                                      ],
                                    ),
                                  ),
                                ],
                                icon: const Icon(AppIcons.moreVert),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        const SizedBox(height: 6),
        _inlineAddMediaButton('music'),
      ],
    );
  }

  Future<_ProfileMusicMetadata?> _resolveProfileMusicMetadata(String path) {
    final normalizedPath = path.trim();
    return _profileMusicMetadataFutures.putIfAbsent(
      normalizedPath,
      () => _readProfileMusicMetadata(normalizedPath),
    );
  }

  Future<_ProfileMusicMetadata?> _readProfileMusicMetadata(
    String filePath,
  ) async {
    try {
      // Общий чтец: на iPhone теги читает система — библиотека там отключена.
      final tag = await MusicTagReader.read(filePath);
      final title =
          _normalizeMusicMetadataLabel(tag?.title) ??
          _normalizeMusicMetadataLabel(p.basenameWithoutExtension(filePath));
      final artist = _normalizeMusicMetadataLabel(tag?.artist);
      if (title == null && artist == null) {
        return null;
      }
      return _ProfileMusicMetadata(title: title, artist: artist);
    } catch (_) {
      final title = _normalizeMusicMetadataLabel(
        p.basenameWithoutExtension(filePath),
      );
      if (title == null) return null;
      return _ProfileMusicMetadata(title: title);
    }
  }

  String? _normalizeMusicMetadataLabel(String? value) {
    if (value == null) return null;
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return null;
    return compact;
  }

  String _unknownMusicArtistLabel() {
    return _label(context, ru: 'Неизвестный исполнитель', en: 'Unknown artist');
  }

  String _profileMusicTypeLabel(String filePath) {
    final ext = p.extension(filePath).trim().toLowerCase();
    if (ext.isEmpty) return 'AUDIO';
    return ext.substring(1).toUpperCase();
  }

  String _profileMusicMime(String filePath) {
    switch (p.extension(filePath).trim().toLowerCase()) {
      case '.aac':
        return 'audio/aac';
      case '.flac':
        return 'audio/flac';
      case '.m4a':
        return 'audio/mp4';
      case '.ogg':
        return 'audio/ogg';
      case '.opus':
        return 'audio/opus';
      case '.wav':
        return 'audio/wav';
      case '.mp3':
      default:
        return 'audio/mpeg';
    }
  }

  Future<void> _handleProfileMusicAction(
    _ProfileMusicMenuAction action, {
    required int index,
    required String path,
  }) async {
    switch (action) {
      case _ProfileMusicMenuAction.send:
        await _sendProfileMusic(path, openConversation: false);
        return;
      case _ProfileMusicMenuAction.forward:
        await _forwardProfileMusicExternally(path);
        return;
      case _ProfileMusicMenuAction.download:
        await _downloadProfileMusic(path);
        return;
      case _ProfileMusicMenuAction.delete:
        await _removeMediaAt(category: 'music', index: index);
        return;
    }
  }

  Future<void> _forwardProfileMusicExternally(String path) async {
    try {
      await _shareLocalFileExternally(
        path: path,
        mime: _profileMusicMime(path),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _label(
              context,
              ru: 'Не удалось открыть панель пересылки: $error',
              en: 'Failed to open the share sheet: $error',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _sendProfileMusic(
    String path, {
    required bool openConversation,
  }) async {
    final conversation = await _pickConversationForMusicAction(path);
    if (!mounted || conversation == null) return;

    try {
      if (conversation.convoId.startsWith('group:')) {
        await widget.controller.sendGroupAttachmentFile(
          groupId: conversation.convoId,
          filePath: path,
          mime: _profileMusicMime(path),
        );
      } else {
        final normalizedPeerProfileId =
            (conversation.peerProfileId ?? conversation.convoId)
                .replaceFirst(RegExp(r'^req:'), '')
                .trim();
        if (normalizedPeerProfileId.isEmpty) {
          throw StateError('Missing peer profile id');
        }
        await widget.controller.sendAttachmentFile(
          peerProfileId: normalizedPeerProfileId,
          filePath: path,
          mime: _profileMusicMime(path),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _label(
              context,
              ru: 'Отправлено в «${conversation.title}»',
              en: 'Sent to ${conversation.title}',
            ),
          ),
        ),
      );
      if (openConversation) {
        await _openConversation(conversation);
      }
    } catch (error) {
      if (!mounted) return;
      final roomError = tryRoomPolicyErrorText(context.l10n, error);
      final message =
          roomError ??
          (error is AttachmentFailure
              ? attachmentErrorText(context.l10n, error)
              : context.l10n.sendFailed(error.toString()));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SecretlySnackBar(content: Text(message)));
    }
  }

  Future<Conversation?> _pickConversationForMusicAction(String path) {
    final title = p.basenameWithoutExtension(path).trim();
    return showModalBottomSheet<Conversation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProfileConversationPickerSheet(
          controller: widget.controller,
          title: _label(context, ru: 'Выберите чат', en: 'Choose a chat'),
          subtitle: title.isEmpty ? p.basename(path) : title,
        );
      },
    );
  }

  Future<void> _openConversation(Conversation conversation) async {
    final convoId = conversation.convoId.trim();
    if (convoId.isEmpty) return;
    final normalizedConvoId = convoId.replaceFirst(RegExp(r'^req:'), '');
    if (widget.controller.isPersonalChat(normalizedConvoId)) {
      final unlocked = await ensureSecurityScopeUnlocked(
        context: context,
        controller: widget.controller,
        scope: SecurityLockScope.personal,
      );
      if (!unlocked || !mounted) {
        return;
      }
    }

    final isGroup = convoId.startsWith('group:');
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          convoId: convoId,
          title: conversation.title,
          peerProfileIdForSend: isGroup
              ? null
              : (conversation.peerProfileId ?? normalizedConvoId),
        ),
      ),
    );
  }

  Future<Directory> _resolveProfileMediaDownloadDirectory() async {
    final downloads = await getDownloadsDirectory();
    final baseDir = downloads ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(baseDir.path, 'Secretly'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _uniqueProfileMediaTarget(
    Directory dir,
    String suggestedName,
  ) async {
    final ext = p.extension(suggestedName);
    final stem = ext.isEmpty
        ? suggestedName
        : suggestedName.substring(0, suggestedName.length - ext.length);
    var candidate = File(p.join(dir.path, suggestedName));
    var index = 2;
    while (await candidate.exists()) {
      candidate = File(p.join(dir.path, '${stem}_$index$ext'));
      index++;
    }
    return candidate;
  }

  Future<void> _downloadProfileMusic(String path) async {
    final source = File(path);
    if (!await source.exists()) return;

    try {
      final suggestedName = p.basename(source.path);
      String? savePath;
      var pickerSupported = true;
      try {
        savePath = await FilePicker.platform.saveFile(fileName: suggestedName);
      } catch (_) {
        pickerSupported = false;
      }

      if (pickerSupported && (savePath == null || savePath.isEmpty)) {
        return;
      }

      if (!pickerSupported) {
        final dir = await _resolveProfileMediaDownloadDirectory();
        final target = await _uniqueProfileMediaTarget(dir, suggestedName);
        await source.copy(target.path);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SecretlySnackBar(content: Text(context.l10n.savedTo(target.path))),
        );
        return;
      }

      var resolvedPath = savePath!;
      final ext = p.extension(suggestedName);
      if (ext.isNotEmpty && p.extension(resolvedPath).isEmpty) {
        resolvedPath = '$resolvedPath$ext';
      }
      final target = File(resolvedPath);
      await target.parent.create(recursive: true);
      await source.copy(target.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(context.l10n.savedTo(target.path))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(context.l10n.downloadFailed(error.toString())),
        ),
      );
    }
  }

  void _handleCollapseDrag(DragUpdateDetails details) {
    _stopPullSnap();
    _collapseGestureActive = true;
    setState(() {
      _profilePullPx = (_profilePullPx + details.delta.dy).clamp(
        0.0,
        _profilePullMaxPx,
      );
      _pullExpand = (_profilePullPx / _profilePullMaxPx).clamp(0.0, 1.0);
    });
    _updateProfilePhotoFeedback();
  }

  void _handleCollapseDragEnd(DragEndDetails _) {
    _collapseGestureActive = false;
    _animatePullTo(_pullExpand >= _profileSnapThreshold ? 1.0 : 0.0);
  }

  bool _handleProfilePull(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final atTop =
        notification.metrics.pixels <= 0.5 &&
        notification.metrics.extentBefore <= 0.5;

    if (notification is OverscrollNotification) {
      if (notification.dragDetails == null) return false;
      final delta = notification.overscroll;
      if (atTop && delta < 0) {
        _stopPullSnap();
        setState(() {
          _profilePullPx = (_profilePullPx + (-delta)).clamp(
            0.0,
            _profilePullMaxPx,
          );
          _pullExpand = (_profilePullPx / _profilePullMaxPx).clamp(0.0, 1.0);
        });
        _updateProfilePhotoFeedback();
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) return false;
      final delta = notification.scrollDelta ?? 0;
      if (atTop && delta < 0) {
        _stopPullSnap();
        setState(() {
          _profilePullPx = (_profilePullPx + (-delta)).clamp(
            0.0,
            _profilePullMaxPx,
          );
          _pullExpand = (_profilePullPx / _profilePullMaxPx).clamp(0.0, 1.0);
        });
        _updateProfilePhotoFeedback();
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      // Always settle on finger-up; dragDetails is usually null at scroll end, so
      // gating on it left the avatar frozen mid-zoom when released early.
      if (_profilePullPx > 0.001) {
        _animatePullTo(_pullExpand >= _profileSnapThreshold ? 1.0 : 0.0);
      }
      return false;
    }

    return false;
  }

  /// True if premium cosmetics are unlocked; otherwise shows the paywall and
  /// returns whether the user unlocked it afterwards.
  Future<bool> _ensureCosmeticAccess() async {
    bool unlocked() => isCosmeticAllowed(
      widget.controller.entitlementStateNow,
      CosmeticKind.avatarFrame,
      'x',
    );
    if (unlocked()) return true;
    await showPaywall(context, PaywallTrigger.cosmetic);
    if (!mounted) return false;
    setState(() {});
    return unlocked();
  }

  /// Premium emoji-status chip shown next to the profile name. Tap opens the
  /// status picker (premium-gated); shows a faint "add" icon when none is set.
  Widget _buildEmojiStatusButton(AppController controller) {
    final status = controller.myEmojiStatus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (!await _ensureCosmeticAccess()) return;
        if (!mounted) return;
        final picked = await showEmojiStatusPicker(context, current: status);
        if (picked == null) return;
        await controller.setMyEmojiStatus(picked.isEmpty ? null : picked);
        if (mounted) setState(() {});
      },
      child: (status != null && status.isNotEmpty)
          // Render through the Noto catalog so the user's OWN status loops the
          // same animated Lottie that contacts see (contact-details hero / chat
          // header / list rows). A plain Text glyph here showed a static,
          // non-animating emoji even though the icon is animatable.
          ? NotoStatusEmoji(emoji: status, size: 24)
          : Icon(
              Icons.add_reaction_outlined,
              size: 20,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
    );
  }

  Widget _circleAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    // Semi-square glass island with icon + label (matches the contact-details
    // action chips: frosted glass + specular highlight).
    return FrostedHeaderIsland(
      radius: 18,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = context.l10n;

    // Sit the floating FAB above the shared floating nav pill (mirrors the
    // ListView's reserved bottom padding). endFloat keeps its right edge at
    // screenWidth-16 — exactly where the inline button (right-aligned inside a
    // 16px-padded pane) docks, so the float→dock handoff has no horizontal jump.
    // Was the Android formula unconditionally, so on iOS — where the glass
    // pill ignores the home-indicator inset — this sat ~62px above the bar
    // instead of the 28px every other screen uses. Same helper now.
    final addFabBottomOffset = fabBottomOffsetFor(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: addFabBottomOffset + 4),
        child: AnimatedFab(
          visible: _addFabFloating,
          child: _addMediaFabButton(_activeMediaCategory),
        ),
      ),
      appBar: frostedAppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 176,
        // Top-left island: premium frames & covers editor.
        leading: Builder(
          builder: (context) {
            final canPop = Navigator.of(context).canPop();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canPop)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                else
                  const SizedBox(width: 6),
                Opacity(
                  opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: FrostedHeaderIsland(
                      radius: 24,
                      height: 48,
                      padding: EdgeInsets.zero,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfileCosmeticsScreen(
                                controller: controller,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 17,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 5),
                                ShimmerGoldText(
                                  'Premium',
                                  colors: premiumShimmerColors(context),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
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
              ],
            );
          },
        ),
        flexibleSpace: const SizedBox.shrink(),
        actions: [
          Opacity(
            opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              child: FrostedHeaderIsland(
                radius: 24,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _profileIslandButton(
                      context,
                      tooltip: _label(
                        context,
                        ru: 'QR профиля',
                        en: 'Profile QR',
                      ),
                      icon: AppIcons.qrCode,
                      size: 24,
                      onPressed: _openMyId,
                    ),
                    _profileIslandButton(
                      context,
                      tooltip: context.l10n.more,
                      icon: AppIcons.moreVert,
                      size: 23,
                      onPressed: _showProfileMoreMenu,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<void>(
        stream: controller.changed,
        builder: (context, _) {
          // Content height can change (media added/removed, tab switched)
          // without a scroll event, shifting the inline anchor — re-evaluate
          // the dock state after this frame lays out.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _updateAddFabDock(),
          );
          final current = controller.myNickname;
          if (!_nickFocus.hasFocus && !_syncing && _nick.text != current) {
            _syncing = true;
            _nick.text = current;
            _nick.selection = TextSelection.fromPosition(
              TextPosition(offset: _nick.text.length),
            );
            Future.microtask(() => _syncing = false);
          }

          final rawAvatarPath = controller.myAvatarPath;
          final avatarPath =
              (rawAvatarPath != null &&
                  rawAvatarPath.isNotEmpty &&
                  File(rawAvatarPath).existsSync())
              ? rawAvatarPath
              : null;
          final rawFullscreenAvatarPath = controller.myAvatarOriginalPath;
          final fullscreenAvatarPath =
              (rawFullscreenAvatarPath != null &&
                  rawFullscreenAvatarPath.isNotEmpty &&
                  File(rawFullscreenAvatarPath).existsSync())
              ? rawFullscreenAvatarPath
              : avatarPath;
          final displayAvatarPath = fullscreenAvatarPath ?? avatarPath;
          final hasAvatar = displayAvatarPath != null;

          final displayName = (controller.myNickname.trim().isNotEmpty)
              ? controller.myNickname.trim()
              : l10n.secretlyUser;
          final galleryPaths = controller.profileGalleryPaths;
          final backgroundPaths = controller.profileBackgroundPaths;
          final musicPaths = controller.profileMusicPaths;
          final bottomInset = MediaQuery.of(context).padding.bottom;

          final screen = MediaQuery.of(context).size;
          final safeTop = MediaQuery.of(context).padding.top;
          final screenW = screen.width;
          final expandedImageHeight = (screen.height * 0.52).clamp(
            320.0,
            520.0,
          );
          final avatarSize = lerpDouble(112, screenW, _pullExpand)!;
          final avatarHeight = lerpDouble(
            112,
            expandedImageHeight,
            _pullExpand,
          )!;
          final avatarRadius = lerpDouble(56, 0, _pullExpand)!;
          final collapsedAvatarTop = safeTop + 8;
          final expandedAvatarTop = 0.0;
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
          final myFrame = frameById(controller.myFrameId);
          // Держатель нажатия ставится только под живую рамку: у остальных
          // двадцати будить нечего, и лишнего узла в дереве не появляется.
          Widget wrapPress(String? id, Widget child) => isLiveFrameId(id)
              ? LiveFramePressHost(frameId: id, child: child)
              : child;

          // Back layer under the photo; [myCoverFront] (black hole only) is the
          // near disk edge drawn OVER the photo → avatar sits INSIDE the hole.
          final myCover = coverBackWidgetFor(
            controller.myCoverId,
            customImagePath: controller.myCoverImagePath,
            customVideoPath: controller.myCoverVideoPath,
          );
          final myCoverFront = coverFrontWidgetFor(
            controller.myCoverId,
            customImagePath: controller.myCoverImagePath,
            customVideoPath: controller.myCoverVideoPath,
          );

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (_pullExpand >= 1.0 || _collapseGestureActive)
                ? _handleCollapseDrag
                : null,
            onVerticalDragEnd: (_pullExpand >= 1.0 || _collapseGestureActive)
                ? _handleCollapseDragEnd
                : null,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleProfilePull,
              child: ListView(
                controller: _scrollController,
                physics: (_pullExpand >= 1.0 || _collapseGestureActive)
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                padding: EdgeInsets.only(top: 0, bottom: 112 + bottomInset),
                children: [
                  // 🔴 Держатель нажатия — НАД всей шапкой. Кнопка «Погладить»
                  // стоит у строки присутствия, а рамку рисует портрет двумя
                  // ветками выше; общий предок — единственное место, откуда о
                  // нажатии узнают оба. У обычных рамок держателя нет: будить
                  // нечего, и лишнего узла в дереве телефона не появляется.
                  wrapPress(
                    controller.myFrameId,
                    SizedBox(
                    height: heroHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Cover image and its shading are SEPARATE layers so the
                        // shading can extend lower without moving the cover.
                        if (myCover != null) ...[
                          // 1) The cover image — stays at its place: bottom aligned
                          //    to the action buttons. Never moves with the shading.
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: collapsedButtonsTop + 66,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: (1.0 - _pullExpand * 2.0).clamp(
                                  0.0,
                                  1.0,
                                ),
                                // Showcase: the banner is the biggest thing on this page,
                                // so it rasterises at full resolution here.
                                child: CosmeticShowcaseScope(child: myCover),
                              ),
                            ),
                          ),
                          // 2) The shading — a SEPARATE page-colour scrim that runs
                          //    DOWN PAST the cover to the top of the ID-profile card
                          //    (Clip.none lets it overflow the hero into the gap),
                          //    so the darkening reaches the ID placeholder while the
                          //    cover above stays exactly where it is.
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: collapsedHeroBottom + 16,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: (1.0 - _pullExpand * 2.0).clamp(
                                  0.0,
                                  1.0,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    // Page-colour scrim tied to the active theme
                                    // background so it blends on every theme
                                    // (light + dark), not a fixed midnight tone.
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.55, 1.0],
                                      colors: [
                                        AppBackground.scrimColorOf(
                                          context,
                                        ).withValues(alpha: 0.0),
                                        AppBackground.scrimColorOf(context),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        Positioned(
                          top: avatarTop,
                          left: (screenW - avatarSize) / 2,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: hasAvatar
                                ? () => _openProfileAvatarFullScreen(
                                    fullscreenAvatarPath,
                                  )
                                : null,
                            onVerticalDragUpdate: (details) =>
                                _handleProfileAvatarSurfaceDragUpdate(
                                  details,
                                  fullscreenAvatarPath,
                                ),
                            onVerticalDragEnd:
                                _handleProfileAvatarSurfaceDragEnd,
                            child: Hero(
                              tag: _profileAvatarHeroTag,
                              child: Container(
                                width: avatarSize,
                                height: avatarHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    avatarRadius,
                                  ),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                // hardEdge (no saveLayer) when a video avatar is
                                // playing — antiAlias breaks Texture compositing
                                // on iOS; antiAlias for a still keeps a smooth rim.
                                clipBehavior:
                                    controller.myAvatarVideoPath != null
                                    ? Clip.hardEdge
                                    : Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (controller.myAvatarVideoPath != null)
                                      // Premium animated (video) avatar — loops
                                      // locally; the synced still shows elsewhere.
                                      coverWidgetFor(
                                        null,
                                        customVideoPath:
                                            controller.myAvatarVideoPath,
                                        customImagePath: hasAvatar
                                            ? displayAvatarPath
                                            : null,
                                      )!
                                    else if (hasAvatar)
                                      Image.file(
                                        File(displayAvatarPath),
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.high,
                                        gaplessPlayback: true,
                                        errorBuilder: (_, _, _) =>
                                            const BrokenMediaBox(
                                              iconSize: 28,
                                              rounded: true,
                                            ),
                                      )
                                    else
                                      // No photo: the initials fallback in the
                                      // shared colours (matching every other
                                      // screen and the desktop) instead of a
                                      // grey person glyph.
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: AvatarInitials.backgroundColor(
                                            context,
                                            seed: controller.profileId,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            AvatarInitials.label(
                                              displayName: displayName,
                                              fallbackId: controller.profileId,
                                            ),
                                            style: TextStyle(
                                              color:
                                                  AvatarInitials.foregroundColor(
                                                    context,
                                                    seed: controller.profileId,
                                                  ),
                                              fontSize: lerpDouble(
                                                36,
                                                76,
                                                _pullExpand,
                                              ),
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.5,
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(
                                                alpha: lerpDouble(
                                                  0.0,
                                                  0.46,
                                                  _pullExpand,
                                                )!,
                                              ),
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
                        if (myFrame != null)
                          // Frame ring must ENCIRCLE the photo: the catalog ring
                          // sits at r≈0.455·S and the avatar hole is 0.78·S, so to
                          // wrap a photo of diameter [avatarSize] the frame box must
                          // be avatarSize/0.78 (matches FramedAvatar's gap).
                          Positioned(
                            top:
                                avatarTop +
                                avatarHeight / 2 -
                                (avatarSize / 0.86) / 2,
                            left: (screenW - avatarSize / 0.86) / 2,
                            child: IgnorePointer(
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
                                    child: myFrame.builder(avatarSize / 0.86),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (myCoverFront != null)
                          // Foreground cover pass (black hole's near disk edge)
                          // OVER the photo+frame — the avatar reads as sitting
                          // INSIDE the event horizon. Transparent where empty;
                          // ignores taps so the avatar stays tappable.
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: collapsedButtonsTop + 66,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: (1.0 - _pullExpand * 2.0).clamp(
                                  0.0,
                                  1.0,
                                ),
                                child: myCoverFront,
                              ),
                            ),
                          ),
                        Positioned(
                          top: nameTop,
                          left: 24,
                          right: 24,
                          child: Align(
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
                                      displayName,
                                      textAlign: _pullExpand > 0.35
                                          ? TextAlign.left
                                          : TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: _pullExpand > 0.35
                                                ? Colors.white
                                                : null,
                                          ),
                                    ),
                                  ),
                                  // Order: name → emoji status → premium star.
                                  const SizedBox(width: 8),
                                  _buildEmojiStatusButton(controller),
                                  if (controller.myPremiumBadge) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 18,
                                      color: Color(0xFFE8A33D),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: statusTop,
                          left: 24,
                          right: 24,
                          child: Align(
                            alignment: Alignment.lerp(
                              Alignment.topCenter,
                              Alignment.topLeft,
                              _pullExpand,
                            )!,
                            child: Transform.scale(
                              scale: subtitleScale,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.onlineStatus,
                                textAlign: _pullExpand > 0.35
                                    ? TextAlign.left
                                    : TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _pullExpand > 0.35
                                          ? Colors.white.withValues(alpha: 0.9)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        // 🔴 Кнопка, которая будит персонажа рамки. Справа в
                        // углу от строки присутствия — решение владельца от
                        // 23.09.2026. Стоит ОТДЕЛЬНЫМ слоем, а не в строке с
                        // присутствием: та ездит от центра к левому краю
                        // вместе с раскрытием шапки, и кнопку утащило бы за
                        // собой. У обычных рамок кнопки нет вовсе.
                        if (isLiveFrameId(controller.myFrameId))
                          Positioned(
                            top: statusTop - 4,
                            right: 20,
                            child: Builder(
                              builder: (ctx) => _LiveFrameWakeButton(
                                frameId: controller.myFrameId!,
                                onCover: _pullExpand > 0.35,
                              ),
                            ),
                          ),
                        Positioned(
                          top: buttonsTop,
                          left: 24,
                          right: 24,
                          // Three equal-width action chips (Expanded thirds).
                          child: Row(
                            children: [
                              Expanded(
                                child: _circleAction(
                                  context: context,
                                  icon: AppIcons.camera,
                                  label: _label(
                                    context,
                                    ru: 'Фото',
                                    en: 'Photo',
                                  ),
                                  onTap: _showAvatarSourceSheet,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _circleAction(
                                  context: context,
                                  icon: Icons.wallpaper_rounded,
                                  // L10N FIX (2026-07-17): full locale set —
                                  // matches the cosmetics screen's tab labels.
                                  label: wave1Text(
                                    context,
                                    ru: 'Обложки',
                                    en: 'Covers',
                                    uk: 'Обкладинки',
                                    es: 'Portadas',
                                    pt: 'Capas',
                                    ptBr: 'Capas',
                                    fr: 'Couvertures',
                                    de: 'Titelbilder',
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      // Default landing tab is Frames («Рамки»).
                                      builder: (_) => ProfileCosmeticsScreen(
                                        controller: controller,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _circleAction(
                                  context: context,
                                  icon: AppIcons.settings,
                                  label: _label(
                                    context,
                                    ru: 'Настройки',
                                    en: 'Settings',
                                  ),
                                  onTap: _openSettings,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(AppIcons.linkedDevices),
                            title: Text(
                              _label(
                                context,
                                ru: 'ID профиля',
                                en: 'Profile ID',
                              ),
                            ),
                            subtitle: Text(controller.profileId),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      shape: const CircleBorder(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: _shareProfileLink,
                                    child: const Icon(
                                      Icons.share_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      shape: const CircleBorder(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: _copyProfileId,
                                    child: ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                      child: Lottie.asset(
                                        _copyIconAssetPath,
                                        controller: _copyIconController,
                                        repeat: false,
                                        animate: false,
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                        onLoaded: (composition) {
                                          _copyIconController.duration =
                                              composition.duration;
                                        },
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              AppIcons.copyOutline,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.profileSectionTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _nick,
                              focusNode: _nickFocus,
                              decoration: InputDecoration(
                                labelText: l10n.myNicknameLabel,
                                hintText: l10n.myNicknameHint,
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.done,
                              onChanged: _scheduleSave,
                              onSubmitted: (v) => controller.setMyNickname(v),
                            ),
                            const SizedBox(height: 6),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.includeNicknameInQr),
                              subtitle: Text(
                                l10n.includeNicknameInQrSubtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                              value: controller.shareNicknameInQr,
                              onChanged: (v) =>
                                  controller.setShareNicknameInQr(v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _label(
                                  context,
                                  ru: 'Показывать меня в поиске по нику',
                                  en: 'Allow nickname discoverability',
                                ),
                              ),
                              subtitle: Text(
                                _label(
                                  context,
                                  ru: 'Если выключено, другие пользователи не найдут вас по нику.',
                                  en: 'If off, other users cannot find you by nickname.',
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                              value: controller.discoverableByNickname,
                              onChanged: (v) =>
                                  controller.setDiscoverableByNickname(v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _label(
                                  context,
                                  ru: 'Только проверенные устройства',
                                  en: 'Only verified devices',
                                ),
                              ),
                              subtitle: Text(
                                _label(
                                  context,
                                  ru: 'Блокировать отправку на непроверенные устройства контактов. В личной переписке; на группы не распространяется.',
                                  en: 'Block sending to unverified contact devices. In one-to-one chats; does not apply to groups.',
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                              value: controller.blockUnverified,
                              onChanged: (v) =>
                                  controller.setBlockUnverified(v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _label(
                            context,
                            ru: 'Мини-галерея',
                            en: 'Mini gallery',
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        TabBar(
                          controller: _mediaTabController,
                          isScrollable: false,
                          tabs: [
                            Tab(text: _categoryLabel('gallery')),
                            Tab(text: _categoryLabel('backgrounds')),
                            Tab(text: _categoryLabel('music')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(
                        key: ValueKey<int>(_mediaTabController.index),
                        child: switch (_mediaTabController.index) {
                          1 => _buildImageCategoryPane(
                            category: 'backgrounds',
                            paths: backgroundPaths,
                          ),
                          2 => _buildMusicCategoryPane(musicPaths),
                          _ => _buildImageCategoryPane(
                            category: 'gallery',
                            paths: galleryPaths,
                          ),
                        },
                      ),
                    ),
                  ),
                  // Zero-height marker just below the inline "Add" button. Its
                  // global Y tells us whether the inline button slot is below
                  // the dock line (→ float the FAB) or above it (→ dock).
                  SizedBox(key: _addAnchorKey, height: 0),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _label(
                        context,
                        ru: 'Фоны из раздела «Фоны» доступны в выборе обоев чата. Эти данные доступны только вам и не передаются другим пользователям.',
                        en: 'Backgrounds from the Backgrounds tab are also available in chat wallpaper pickers. These data are visible only to you and are not shared with other users.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Кнопка, которая будит персонажа живой рамки.
///
/// 🔴 ПОЧЕМУ У СТРОКИ ПРИСУТСТВИЯ, А НЕ СРЕДИ ТРЁХ БОЛЬШИХ ДЕЙСТВИЙ. Ряд ниже
/// («Фото», «Обложки», «Настройки») — это то, что МЕНЯЕТ профиль. Здесь ничего
/// не меняется: нажатие живёт до следующего нажатия и никуда не сохраняется.
/// Место в углу у присутствия отведено владельцем 23.09.2026.
///
/// 🔴 ПОДПИСЬ, А НЕ ЗНАЧОК. «Погладить», «Дедлайн!», «Пауза» — три разных
/// действия, и по одному значку не догадаться, какое именно. Глагол приходит
/// из каталога рамки, поэтому новая рамка приносит свою подпись сама.
class _LiveFrameWakeButton extends StatelessWidget {
  const _LiveFrameWakeButton({required this.frameId, required this.onCover});

  final String frameId;

  /// Шапка раскрыта и кнопка лежит на обложке: там свои цвета, как у имени и
  /// присутствия рядом.
  final bool onCover;

  @override
  Widget build(BuildContext context) {
    final press = LiveFramePressScope.controllerOf(context);
    final active = LiveFramePressScope.of(context);
    final label = liveFrameActionLabel(context, frameId);
    if (label == null || press == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final ink = onCover ? Colors.white : scheme.primary;
    final fill = onCover
        ? Colors.white.withValues(alpha: active ? 0.30 : 0.18)
        : scheme.primary.withValues(alpha: active ? 0.26 : 0.13);

    return Semantics(
      container: true,
      button: true,
      toggled: active,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => press.value = !press.value,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔴 Значок НЕ меняется на «паузу», когда выходка идёт.
                  // Пауза обещала бы, что нажатие её остановит, а она
                  // заканчивается сама — обещание было бы ложным.
                  Icon(Icons.bolt_rounded, size: 14, color: ink),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
