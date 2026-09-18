// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../calls/call_manager.dart';
import '../calls/call_state.dart';
import 'icons/app_icons.dart';
import 'widgets/call_return_banner.dart';
import 'l10n.dart';
import 'thermal_guard.dart';
import 'widgets/liquid_pressable.dart';
import 'widgets/frosted_header_island.dart';

Future<void> showSharedAudioPlayerSheet(
  BuildContext context, {
  required AppController controller,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.78,
        child: _SharedAudioPlayerSheet(controller: controller),
      );
    },
  );
}

/// Total laid-out height of [SharedAudioMiniPlayerBanner] when a track is
/// playing: the 38px island + the default vertical margin (8 top + 6 bottom).
/// (ISLAND UNIFY 2026-07-17: matches the in-chat now-playing strip exactly.)
/// Used to reserve space in scrolling lists where the banner itself is rendered
/// as a pinned overlay instead of an inline (scrolling) item.
const double kSharedAudioMiniPlayerBannerHeight = 38 + 8 + 6;

/// Row height of the bare (merged) island — the chat's shared strip height.
const double kSharedAudioIslandRowHeight = 38;

/// The call row inside the glued call+music island is deliberately SLIMMER than
/// the music row — its content is a single line (name + status), so a full 38px
/// read as a fat band next to the player.
const double kSharedAudioCallRowHeight = 32;

/// Zero-height-when-idle spacer that mirrors [SharedAudioMiniPlayerBanner]'s
/// footprint. Place this where the banner used to live inside a scrolling list
/// and render the actual banner as a pinned overlay, so the first list item is
/// never hidden behind the pinned island while a track is playing.
class SharedAudioMiniPlayerReserve extends StatelessWidget {
  const SharedAudioMiniPlayerReserve({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SharedAudioPlaybackState>(
      valueListenable: controller.sharedAudioPlayback,
      builder: (context, playback, _) => SizedBox(
        height: playback.currentTrack != null
            ? kSharedAudioMiniPlayerBannerHeight
            : 0,
      ),
    );
  }
}

/// ISLAND GROUP (2026-07-17): pinned top overlay for the main screens.
/// Music island alone — or, when a minimized 1:1 call is live at the same
/// time, call + music glued into ONE glass island (FrostedIslandRowGroup),
/// exactly like the chat glues its pinned-message and now-playing strips.
class SharedAudioTopIslands extends StatelessWidget {
  const SharedAudioTopIslands({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SharedAudioPlaybackState>(
      valueListenable: controller.sharedAudioPlayback,
      builder: (context, playback, _) {
        final musicActive = playback.currentTrack != null;
        final manager = CallManager.instance;
        if (manager == null) {
          return musicActive
              ? SharedAudioMiniPlayerBanner(controller: controller)
              : const SizedBox.shrink();
        }
        return ValueListenableBuilder<CallState>(
          valueListenable: manager.state,
          builder: (context, call, _) {
            final callMinimized = call.isActive && call.isUiMinimized;
            if (musicActive && callMinimized) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: FrostedIslandRowGroup(
                  // Порядок закреплён: музыка сверху, звонок ВСЕГДА нижней
                  // строкой (уточнение 2026-07-17).
                  rowHeights: const [
                    kSharedAudioIslandRowHeight,
                    kSharedAudioCallRowHeight,
                  ],
                  rows: [
                    SharedAudioMiniPlayerBanner(
                      controller: controller,
                      merged: true,
                    ),
                    const CallReturnBanner(merged: true),
                  ],
                ),
              );
            }
            if (musicActive) {
              return SharedAudioMiniPlayerBanner(controller: controller);
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

/// Spacer mirroring [SharedAudioTopIslands]' footprint inside scrolling
/// lists (music-only = banner height; merged call+music = two 38px rows +
/// seam + margins).
class SharedAudioTopIslandsReserve extends StatelessWidget {
  const SharedAudioTopIslandsReserve({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SharedAudioPlaybackState>(
      valueListenable: controller.sharedAudioPlayback,
      builder: (context, playback, _) {
        final musicActive = playback.currentTrack != null;
        if (!musicActive) return const SizedBox.shrink();
        final manager = CallManager.instance;
        if (manager == null) {
          return const SizedBox(height: kSharedAudioMiniPlayerBannerHeight);
        }
        return ValueListenableBuilder<CallState>(
          valueListenable: manager.state,
          builder: (context, call, _) {
            final merged = call.isActive && call.isUiMinimized;
            return SizedBox(
              height: merged
                  ? 8 +
                        kSharedAudioIslandRowHeight +
                        kSharedAudioCallRowHeight +
                        0.5 +
                        6
                  : kSharedAudioMiniPlayerBannerHeight,
            );
          },
        );
      },
    );
  }
}

/// Standalone call banner for list headers that steps aside while the merged
/// overlay owns the call row (music playing → the overlay renders either the
/// merged group or nothing; a bare call banner here would double-render).
class SharedAudioCallBannerGate extends StatelessWidget {
  const SharedAudioCallBannerGate({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SharedAudioPlaybackState>(
      valueListenable: controller.sharedAudioPlayback,
      builder: (context, playback, _) {
        if (playback.currentTrack != null) return const SizedBox.shrink();
        return const CallReturnBanner();
      },
    );
  }
}

class SharedAudioMiniPlayerBanner extends StatelessWidget {
  const SharedAudioMiniPlayerBanner({
    super.key,
    required this.controller,
    this.margin = const EdgeInsets.fromLTRB(10, 8, 10, 6),
    this.merged = false,
  });

  final AppController controller;
  final EdgeInsetsGeometry margin;

  /// Bare 38px row for embedding inside a [FrostedIslandRowGroup] — no glass,
  /// margin, highlight or shadow of its own (the group owns them), mirroring
  /// the chat's merged now-playing strip.
  final bool merged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SharedAudioPlaybackState>(
      valueListenable: controller.sharedAudioPlayback,
      builder: (context, playback, _) {
        final current = playback.currentTrack;
        if (current == null) {
          return const SizedBox.shrink();
        }

        final durationMs = playback.duration.inMilliseconds;
        final progress = durationMs > 0
            ? (playback.position.inMilliseconds / durationMs).clamp(0.0, 1.0)
            : 0.0;
        final hasArtist = current.artist.trim().isNotEmpty;
        final timingText =
            '${_formatSharedAudioDuration(playback.position)} / '
            '${playback.duration > Duration.zero ? _formatSharedAudioDuration(playback.duration) : '--:--'}';

        final island = _NowPlayingIsland(
          title: current.title,
          artist: hasArtist ? current.artist : null,
          timeText: timingText,
          progress: progress,
          isPlaying: playback.playing,
          merged: merged,
          onPlayPause: controller.toggleSharedAudioPlayback,
          onClose: controller.stopSharedAudio,
          onOpen: () => showSharedAudioPlayerSheet(
            context,
            controller: controller,
          ),
        );
        if (merged) return island;
        return Padding(padding: margin, child: island);
      },
    );
  }
}

/// Slim glass "island" mini-player matching the chat-header islands: matte
/// backdrop blur, soft top→bottom white fill, specular top-edge highlight.
/// Layout: [round play] [title • artist] … [time] [×], with a hairline
/// progress line pinned to the bottom edge.
class _NowPlayingIsland extends StatelessWidget {
  const _NowPlayingIsland({
    this.merged = false,
    required this.title,
    required this.artist,
    required this.timeText,
    required this.progress,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onClose,
    required this.onOpen,
  });

  final String title;
  final String? artist;
  final String timeText;
  final double progress;
  final bool isPlaying;
  final bool merged;
  final VoidCallback onPlayPause;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  // ISLAND UNIFY (2026-07-17): radius/height/fill/rail now mirror the chat's
  // in-chat now-playing strip (radius 16, 38px, dense light fill, full-bleed
  // 2px rail flush with the bottom edge).
  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = cs.primary;

    final fillTop = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.65);
    final fillBottom = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.55);
    final br = BorderRadius.circular(_radius);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 4, 0),
      child: Row(
        children: [
          _RoundTapTarget(
            size: 32,
            background: accent.withValues(alpha: isDark ? 0.22 : 0.14),
            onTap: onPlayPause,
            tooltip: isPlaying ? 'Pause' : 'Play',
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isPlaying ? AppIcons.pauseFill : AppIcons.playFill,
                key: ValueKey<bool>(isPlaying),
                size: 14,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if ((artist ?? '').trim().isNotEmpty)
                        TextSpan(
                          text: '  •  $artist',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeText,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 2),
          _RoundTapTarget(
            size: 28,
            background: Colors.transparent,
            onTap: onClose,
            tooltip: context.l10n.close,
            child: Icon(
              AppIcons.close,
              size: 15,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );

    final rowStack = Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: cs.onSurface.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(
                accent.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ],
    );
    if (merged) {
      // Bare strip: the enclosing FrostedIslandRowGroup owns glass/highlight.
      return SizedBox(height: 38, child: rowStack);
    }

    Widget buildClassic() {
    Widget island = SizedBox(
      height: 38,
      child: CustomPaint(
        foregroundPainter: GlassHighlightBorderPainter(
          radius: _radius,
          strokeWidth: 1.2,
          color: isDark
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.40),
        ),
        child: ClipRRect(
          borderRadius: br,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [fillTop, fillBottom],
                ),
                borderRadius: br,
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: content),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: cs.onSurface.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          accent.withValues(alpha: 0.85),
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
    );
    if (!isDark) {
      // Light-only soft drop shadow — parity with the chat island.
      island = CustomPaint(
        painter: IslandOuterShadowPainter(
          radius: _radius,
          color: const Color(0x12000000),
        ),
        child: island,
      );
    }
    return island;
    }

    if (liquidGlassIslandsEnabled) {
      return ValueListenableBuilder<bool>(
        valueListenable: ThermalGuard.effectsAllowed,
        builder: (context, allowed, _) {
          if (!allowed) return buildClassic();
          return SizedBox(
            height: 38,
            child: LiquidGlassIslandSurface(
              radius: _radius,
              child: Stack(
                children: [
                  Positioned.fill(child: content),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            cs.onSurface.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          accent.withValues(alpha: 0.85),
                        ),
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
    return buildClassic();
  }
}

class _RoundTapTarget extends StatelessWidget {
  const _RoundTapTarget({
    required this.size,
    required this.background,
    required this.onTap,
    required this.child,
    this.tooltip,
  });

  final double size;
  final Color background;
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // Jelly press on the music-island buttons (they sit on liquid glass).
    // On iOS glass use LiquidPressable's squish-and-spring; elsewhere keep the
    // material ripple.
    final Widget btn;
    if (liquidGlassIslandsEnabled) {
      btn = LiquidPressable(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: child),
          ),
        ),
      );
    } else {
      btn = Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: child),
          ),
        ),
      );
    }
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Specular highlight stroke: bright white along the TOP edge, fading to
/// transparent toward the middle — gives the glass strip a convex, lit-from-
/// above look (same recipe as the chat-header islands).
class _SharedAudioPlayerSheet extends StatelessWidget {
  const _SharedAudioPlayerSheet({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return _SharedAudioGlassCard(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ValueListenableBuilder<SharedAudioPlaybackState>(
        valueListenable: controller.sharedAudioPlayback,
        builder: (context, playback, _) {
          final queue = playback.queue.isNotEmpty
              ? playback.queue
              : (playback.currentTrack == null
                    ? const <SharedAudioTrack>[]
                    : <SharedAudioTrack>[playback.currentTrack!]);
          final queueIndex =
              playback.queueIndex >= 0 && playback.queueIndex < queue.length
              ? playback.queueIndex
              : (queue.isEmpty ? -1 : 0);
          final current = queueIndex >= 0 && queueIndex < queue.length
              ? queue[queueIndex]
              : playback.currentTrack;
          final duration = playback.duration;
          final maxMs = duration.inMilliseconds <= 0
              ? 1.0
              : duration.inMilliseconds.toDouble();
          final positionMs = playback.position.inMilliseconds
              .clamp(0, maxMs.toInt())
              .toDouble();

          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;
          final muted = cs.onSurface.withValues(alpha: 0.55);

          return SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 18),
                // ── Album-art placeholder (rounded square, primary tint) ──
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withValues(alpha: isDark ? 0.30 : 0.18),
                        cs.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.10 : 0.40,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    AppIcons.musicNote,
                    size: 52,
                    color: cs.primary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 20),
                // ── Title + artist ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      Text(
                        current?.title ?? context.l10n.music,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if ((current?.artist ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          current!.artist,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // ── Scrubber ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      activeTrackColor: cs.primary,
                      inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
                      thumbColor: cs.primary,
                      overlayColor: cs.primary.withValues(alpha: 0.14),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      value: positionMs,
                      min: 0,
                      max: maxMs,
                      onChanged: (value) {
                        controller.seekSharedAudio(
                          Duration(milliseconds: value.round()),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    children: [
                      Text(
                        _formatSharedAudioDuration(playback.position),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatSharedAudioDuration(duration),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ── Transport controls ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: controller.playPreviousSharedAudio,
                      icon: const Icon(AppIcons.skipPrev),
                      iconSize: 26,
                      color: cs.onSurface.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 18),
                    // Large primary play/pause disc.
                    GestureDetector(
                      onTap: controller.toggleSharedAudioPlayback,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.32),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            playback.playing
                                ? AppIcons.pauseFill
                                : AppIcons.playFill,
                            key: ValueKey<bool>(playback.playing),
                            size: 26,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    IconButton(
                      onPressed: controller.playNextSharedAudio,
                      icon: const Icon(AppIcons.skipNext),
                      iconSize: 26,
                      color: cs.onSurface.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: cs.onSurface.withValues(alpha: 0.08),
                ),
                // ── Up-next queue ──
                Expanded(
                  child: queue.isEmpty
                      ? Center(
                          child: Text(
                            context.l10n.music,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: queue.length,
                          itemBuilder: (context, index) {
                            final track = queue[index];
                            final active = index == queueIndex;
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(
                                vertical: -2,
                              ),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: active
                                      ? cs.primary.withValues(alpha: 0.16)
                                      : cs.onSurface.withValues(alpha: 0.06),
                                ),
                                child: Icon(
                                  active && playback.playing
                                      ? AppIcons.pauseFill
                                      : AppIcons.playFill,
                                  size: 15,
                                  color: active
                                      ? cs.primary
                                      : cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active ? cs.primary : null,
                                ),
                              ),
                              subtitle: track.artist.trim().isEmpty
                                  ? null
                                  : Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: muted),
                                    ),
                              onTap: () {
                                controller.playSharedAudioQueue(
                                  queue: queue,
                                  index: index,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SharedAudioGlassCard extends StatelessWidget {
  const _SharedAudioGlassCard({
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface.withValues(alpha: isDark ? 0.34 : 0.84),
                colorScheme.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.28 : 0.76,
                ),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

String _formatSharedAudioDuration(Duration duration) {
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