// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';

/// Одна запись очереди — строка списка под островком.
@immutable
class DesktopNowPlayingEntry {
  const DesktopNowPlayingEntry({required this.title, this.artist = ''});

  final String title;
  final String artist;
}

/// Что играет — ровно то, что островку нужно показать.
///
/// Свой маленький тип, а не состояние плеера целиком: островок ничего не
/// спрашивает у контроллера и ничего в нём не меняет сам — он показывает и
/// зовёт переданные ему действия. Переводит состояние плеера в это описание
/// корень окна, который контроллер и так знает.
@immutable
class DesktopNowPlaying {
  const DesktopNowPlaying({
    required this.title,
    required this.playing,
    this.artist = '',
    this.sourceConvoId,
    this.loading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const <DesktopNowPlayingEntry>[],
    this.queueIndex = 0,
  });

  /// Песня («Исполнитель — Название») или «Голосовое».
  final String title;

  /// Кто прислал.
  final String artist;

  /// Переписка, откуда звук; `null` — вести некуда.
  final String? sourceConvoId;
  final bool playing;

  /// Файл ещё готовится (скачивается, расшифровывается).
  final bool loading;
  final Duration position;
  final Duration duration;

  /// Всё того же вида в этой переписке — песни или голосовые, — по порядку.
  final List<DesktopNowPlayingEntry> queue;
  final int queueIndex;

  /// Кнопки «назад/вперёд» — только когда есть куда: у одиночной записи они
  /// обещали бы переход, которого нет.
  bool get queued => queue.length > 1;
  bool get canPrevious => queued && queueIndex > 0;
  bool get canNext => queued && queueIndex < queue.length - 1;
}

/// Островок «сейчас играет» в середине шапки окна.
///
/// 🔴 ЗАЧЕМ (24.09.2026, указание владельца). На телефоне у музыки есть
/// островок сверху, на компьютере его не было вовсе: песня, запущенная в одной
/// переписке, продолжала играть, когда человек уходил в другую, — и управлять
/// ею было неоткуда, кроме самого пузыря, который к тому времени уехал из
/// виду. Остановить звук значило искать, откуда он.
///
/// Островок показывает то же, что общий плеер, которым играют и голосовые, и
/// песни: пока в плеере есть дорожка — на паузе или нет, — островок на месте;
/// крестик останавливает плеер и убирает его.
///
/// Нажатие на название раскрывает под островком список: всё того же вида в
/// этой переписке. Отсюда же — переход к сообщению, откуда звук.
class DesktopNowPlayingIsland extends StatefulWidget {
  const DesktopNowPlayingIsland({
    super.key,
    required this.state,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onClose,
    this.onPrevious,
    this.onNext,
    this.onPlayIndex,
    this.onOpenSource,
  });

  /// Что играет; `null` — плеер пуст, и островка нет.
  final DesktopNowPlaying? state;
  final VoidCallback onTogglePlay;

  /// Перемотка в точку записи.
  final ValueChanged<Duration> onSeek;
  final VoidCallback onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Включить запись очереди с этим номером.
  final ValueChanged<int>? onPlayIndex;

  /// Открыть переписку, откуда звук. Получает её идентификатор.
  final ValueChanged<String>? onOpenSource;

  /// Ниже этой ширины островку не на чем показать название — шапка его
  /// прячет целиком, а не сжимает в неразборчивую полоску.
  static const double minUsefulWidth = 180;

  @override
  State<DesktopNowPlayingIsland> createState() =>
      _DesktopNowPlayingIslandState();
}

class _DesktopNowPlayingIslandState extends State<DesktopNowPlayingIsland> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  /// Островок и список — одна область для «щелчка мимо».
  final Object _tapGroup = Object();

  void _toggleList() {
    setState(() {
      if (_portal.isShowing) {
        _portal.hide();
      } else {
        _portal.show();
      }
    });
  }

  void _hideList() {
    if (!_portal.isShowing) return;
    setState(_portal.hide);
  }

  @override
  void didUpdateWidget(covariant DesktopNowPlayingIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Плеер опустел — список закрывается вместе с островком.
    if (widget.state == null && _portal.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hideList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final roomy =
            constraints.maxWidth >= DesktopNowPlayingIsland.minUsefulWidth;
        final now = widget.state;
        final show = roomy && now != null;
        return TapRegion(
          groupId: _tapGroup,
          onTapOutside: (_) => _hideList(),
          child: CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _portal,
              overlayChildBuilder: (ctx) =>
                  show ? _playlist(ctx, now) : const SizedBox.shrink(),
              child: AnimatedSwitcher(
                duration: DMotion.fast,
                switchInCurve: DMotion.easeOutCubic,
                switchOutCurve: DMotion.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1).animate(anim),
                    child: child,
                  ),
                ),
                child: show
                    ? _IslandBody(
                        key: const ValueKey<String>('island'),
                        state: now,
                        listOpen: _portal.isShowing,
                        onTitleTap: _toggleList,
                        onTogglePlay: widget.onTogglePlay,
                        onSeek: widget.onSeek,
                        onClose: () {
                          _hideList();
                          widget.onClose();
                        },
                        onPrevious: widget.onPrevious,
                        onNext: widget.onNext,
                      )
                    : const SizedBox.shrink(key: ValueKey<String>('empty')),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Список под островком: вся очередь этого вида и переход к сообщению.
  Widget _playlist(BuildContext context, DesktopNowPlaying now) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final screen = MediaQuery.sizeOf(context);
    final maxH = (screen.height - 72).clamp(120.0, 360.0);
    final convoId = (now.sourceConvoId ?? '').trim();
    final open = widget.onOpenSource;
    final pick = widget.onPlayIndex;
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 8),
        child: TapRegion(
          groupId: _tapGroup,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: _kListWidth,
              maxWidth: _kListWidth,
              maxHeight: maxH,
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: c.elevated,
                  borderRadius: BorderRadius.circular(DRadii.lg),
                  border: Border.all(color: c.borderSubtle),
                  boxShadow: DShadows.dialog,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          vertical: DSpace.xs,
                        ),
                        itemCount: now.queue.length,
                        itemBuilder: (ctx, i) => _PlaylistRow(
                          entry: now.queue[i],
                          current: i == now.queueIndex,
                          playing: now.playing,
                          onTap: pick == null
                              ? null
                              : () => i == now.queueIndex
                                    ? widget.onTogglePlay()
                                    : pick(i),
                        ),
                      ),
                    ),
                    if (open != null && convoId.isNotEmpty) ...[
                      Container(height: 1, color: c.borderSubtle),
                      _ActionRow(
                        icon: FluentIcons.chat_arrow_back_20_regular,
                        label: l10n.desktopPlayerOpenSource,
                        onTap: () {
                          _hideList();
                          open(convoId);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ширина списка под островком — как у самого островка в шапке.
const double _kListWidth = 340;

class _IslandBody extends StatelessWidget {
  const _IslandBody({
    super.key,
    required this.state,
    required this.listOpen,
    required this.onTitleTap,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onClose,
    this.onPrevious,
    this.onNext,
  });

  final DesktopNowPlaying state;
  final bool listOpen;
  final VoidCallback onTitleTap;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final duration = state.duration;
    final position = state.position > duration && duration > Duration.zero
        ? duration
        : state.position;
    final progress = duration > Duration.zero
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final title = state.title.trim();
    final artist = state.artist.trim();
    final spoken = artist.isEmpty ? title : '$title · $artist';

    Widget iconButton(IconData icon, String tip, VoidCallback? onTap) =>
        DesktopIconButton(
          icon: icon,
          size: 22,
          iconSize: 14,
          tooltip: tip,
          onPressed: onTap,
        );

    final titleText = Text.rich(
      TextSpan(
        text: title,
        style: DType.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
        children: [
          if (artist.isNotEmpty)
            TextSpan(
              text: '  $artist',
              style: DType.caption.copyWith(
                fontSize: 12,
                color: c.textTertiary,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final body = Row(
      children: [
        if (state.queued)
          iconButton(
            FluentIcons.previous_20_filled,
            l10n.desktopPlayerPrevious,
            state.canPrevious ? onPrevious : null,
          ),
        _PlayPauseButton(
          playing: state.playing,
          loading: state.loading,
          onTap: onTogglePlay,
        ),
        if (state.queued)
          iconButton(
            FluentIcons.next_20_filled,
            l10n.desktopPlayerNext,
            state.canNext ? onNext : null,
          ),
        const SizedBox(width: 8),
        // Название — вход в список «что ещё есть в этом чате». Стрелка
        // рядом говорит, что здесь раскрывается, а не просто написано.
        Expanded(
          child: DesktopTooltip(
            message: l10n.desktopPlayerMore,
            child: Semantics(
              button: true,
              expanded: listOpen,
              label: l10n.desktopPlayerMore,
              child: HoverListener(
                onTap: onTitleTap,
                builder: (ctx, hovered, pressed) => Opacity(
                  opacity: pressed ? 0.7 : (hovered ? 0.85 : 1),
                  child: Row(
                    children: [
                      Flexible(child: titleText),
                      const SizedBox(width: 2),
                      Icon(
                        listOpen
                            ? FluentIcons.chevron_up_16_regular
                            : FluentIcons.chevron_down_16_regular,
                        size: 12,
                        color: c.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Моноширинным, как время у голосового: секунды одинаковой ширины не
        // дёргают название при каждом тике.
        Text(
          duration > Duration.zero
              ? '${_mmss(position)} / ${_mmss(duration)}'
              : _mmss(position),
          style: DType.mono.copyWith(fontSize: 10.5, color: c.textSecondary),
        ),
        const SizedBox(width: 2),
        iconButton(
          FluentIcons.dismiss_16_regular,
          l10n.desktopPlayerClose,
          onClose,
        ),
      ],
    );

    return Semantics(
      container: true,
      label: l10n.desktopPlayerNowPlaying(spoken),
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color: c.accentPrimary.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.accentPrimary.withValues(alpha: 0.30)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 3, 0),
                child: body,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 6,
                child: _IslandSeekBar(
                  progress: progress,
                  enabled: duration > Duration.zero,
                  label: l10n.desktopA11yAudioProgress,
                  onSeek: (f) => onSeek(
                    Duration(
                      milliseconds: (duration.inMilliseconds * f).round(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка списка: значок состояния, название, отправитель.
///
/// Текущая запись — цветом акцента и значком того, что с ней сейчас: играет
/// или стоит. Щелчок по текущей — пауза или продолжение, по другой — включить
/// её.
class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.entry,
    required this.current,
    required this.playing,
    this.onTap,
  });

  final DesktopNowPlayingEntry entry;
  final bool current;
  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final icon = current
        ? (playing ? FluentIcons.pause_16_filled : FluentIcons.play_16_filled)
        : FluentIcons.music_note_2_16_regular;
    return Semantics(
      button: onTap != null,
      selected: current,
      label: entry.artist.isEmpty
          ? entry.title
          : '${entry.title}, ${entry.artist}',
      child: ExcludeSemantics(
        child: HoverListener(
          onTap: onTap,
          builder: (ctx, hovered, pressed) => Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: DSpace.m),
            color: current
                ? c.accentPrimary.withValues(alpha: 0.12)
                : (hovered ? c.hover : Colors.transparent),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(
                    icon,
                    size: 14,
                    color: current ? c.accentPrimary : c.textTertiary,
                  ),
                ),
                const SizedBox(width: DSpace.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DType.caption.copyWith(
                          fontSize: 12.5,
                          fontWeight: current
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: current ? c.accentPrimary : c.textPrimary,
                        ),
                      ),
                      if (entry.artist.isNotEmpty)
                        Text(
                          entry.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DType.caption.copyWith(
                            fontSize: 11,
                            color: c.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: HoverListener(
          onTap: onTap,
          builder: (ctx, hovered, pressed) => Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: DSpace.m),
            color: hovered ? c.hover : Colors.transparent,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(icon, size: 15, color: c.textSecondary),
                ),
                const SizedBox(width: DSpace.s),
                Text(
                  label,
                  style: DType.caption.copyWith(
                    fontSize: 12.5,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка «играть/пауза»: залитый кружок цвета акцента, как у песни в пузыре.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.playing,
    required this.loading,
    required this.onTap,
  });

  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final tip = playing ? l10n.desktopA11yPause : l10n.desktopA11yPlay;
    return DesktopTooltip(
      message: tip,
      child: Semantics(
        button: true,
        label: tip,
        child: HoverListener(
          onTap: onTap,
          builder: (ctx, hovered, pressed) => Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pressed
                  ? c.accentPrimary.withValues(alpha: 0.8)
                  : (hovered ? c.accentPrimaryAlt : c.accentPrimary),
            ),
            child: loading
                ? const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Icon(
                    playing
                        ? FluentIcons.pause_16_filled
                        : FluentIcons.play_16_filled,
                    size: 12,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Тонкая полоса прогресса по нижнему краю островка; щелчок и протяжка
/// перематывают. Под курсором полоса толще — чтобы было видно, что за неё
/// можно взяться.
class _IslandSeekBar extends StatefulWidget {
  const _IslandSeekBar({
    required this.progress,
    required this.enabled,
    required this.label,
    required this.onSeek,
  });

  final double progress;
  final bool enabled;
  final String label;
  final ValueChanged<double> onSeek;

  @override
  State<_IslandSeekBar> createState() => _IslandSeekBarState();
}

class _IslandSeekBarState extends State<_IslandSeekBar> {
  bool _hover = false;

  void _at(Offset local) {
    final w = context.size?.width ?? 0;
    if (w <= 0) return;
    widget.onSeek((local.dx / w).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final h = _hover && widget.enabled ? 3.0 : 2.0;
    final bar = Align(
      alignment: Alignment.bottomLeft,
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widget.progress.clamp(0.0, 1.0),
          child: ColoredBox(color: c.accentPrimary),
        ),
      ),
    );
    return Semantics(
      container: true,
      label: widget.label,
      value: '${(widget.progress.clamp(0.0, 1.0) * 100).round()}%',
      child: ExcludeSemantics(
        child: !widget.enabled
            ? bar
            : MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _at(d.localPosition),
                  onHorizontalDragUpdate: (d) => _at(d.localPosition),
                  child: bar,
                ),
              ),
      ),
    );
  }
}

String _mmss(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}
