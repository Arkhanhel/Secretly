// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
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
    this.speed = 1.0,
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

  /// Скорость воспроизведения, 1.0 — обычная.
  final double speed;

  /// Кнопки «назад/вперёд» — только когда есть куда: у одиночной записи они
  /// обещали бы переход, которого нет.
  bool get queued => queue.length > 1;
  bool get canPrevious => queued && queueIndex > 0;
  bool get canNext => queued && queueIndex < queue.length - 1;
}

/// Ступени скорости — как в Telegram: половина, обычная, полторы, две.
///
/// Список закрытый. Плавный ползунок скорости ищут на слух дольше, чем
/// выбирают одну из четырёх ступеней, а ступени Telegram люди уже знают.
const List<double> kDesktopPlayerSpeeds = <double>[0.5, 1.0, 1.5, 2.0];

/// «1×», «1.5×», «0.5×» — подпись скорости без лишних нулей.
String desktopSpeedLabel(double speed) {
  final whole = speed == speed.roundToDouble();
  return '${whole ? speed.toStringAsFixed(0) : speed.toString()}×';
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
/// крестик останавливает плеер и убирает его. Кнопки — как у мини-плеера
/// Telegram: назад, играть, вперёд, скорость, громкость.
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
    this.onSetSpeed,
    this.volume,
    this.onSetVolume,
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

  /// Сменить скорость; `null` — кнопки скорости нет.
  final ValueChanged<double>? onSetSpeed;

  /// Громкость 0..1 и её смена; без обоих — кнопки громкости нет.
  final ValueListenable<double>? volume;
  final ValueChanged<double>? onSetVolume;

  /// Ниже этой ширины островку не на чем показать название — шапка его
  /// прячет целиком, а не сжимает в неразборчивую полоску.
  static const double minUsefulWidth = 220;

  /// Высота островка: на семь точек меньше шапки с каждой стороны.
  static const double height = 34;

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
        final listWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        return TapRegion(
          groupId: _tapGroup,
          onTapOutside: (_) => _hideList(),
          child: CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _portal,
              overlayChildBuilder: (ctx) => show
                  ? _playlist(ctx, now, listWidth)
                  : const SizedBox.shrink(),
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
                        onSetSpeed: widget.onSetSpeed,
                        volume: widget.volume,
                        onSetVolume: widget.onSetVolume,
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
  Widget _playlist(BuildContext context, DesktopNowPlaying now, double width) {
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
          child: _PopoverCard(
            width: width,
            maxHeight: maxH,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: DSpace.xs),
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
    );
  }
}

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
    this.onSetSpeed,
    this.volume,
    this.onSetVolume,
  });

  final DesktopNowPlaying state;
  final bool listOpen;
  final VoidCallback onTitleTap;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<double>? onSetSpeed;
  final ValueListenable<double>? volume;
  final ValueChanged<double>? onSetVolume;

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

    Widget iconButton(
      IconData icon,
      String tip,
      VoidCallback? onTap, {
      double iconSize = 16,
    }) => DesktopIconButton(
      icon: icon,
      size: 28,
      iconSize: iconSize,
      tooltip: tip,
      onPressed: onTap,
    );

    // 🔴 Шрифт — обычный, как в Telegram, а не моноширинный. Время держат
    // цифры ОДНОЙ ширины (tabular figures): отсчёт секунд не дёргает строку, а
    // надпись при этом читается текстом, а не распечаткой терминала.
    final titleText = Text.rich(
      TextSpan(
        text: title,
        style: TextStyle(
          fontFamily: DType.family,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
          height: 1.2,
        ),
        children: [
          if (artist.isNotEmpty)
            TextSpan(
              text: '  $artist',
              style: TextStyle(
                fontFamily: DType.family,
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
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
                      const SizedBox(width: 3),
                      Icon(
                        listOpen
                            ? FluentIcons.chevron_up_16_regular
                            : FluentIcons.chevron_down_16_regular,
                        size: 13,
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
        Text(
          duration > Duration.zero
              ? '${_mmss(position)} / ${_mmss(duration)}'
              : _mmss(position),
          style: TextStyle(
            fontFamily: DType.family,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: c.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 4),
        if (onSetSpeed != null)
          _SpeedButton(speed: state.speed, onSet: onSetSpeed!),
        if (volume != null && onSetVolume != null)
          _VolumeButton(volume: volume!, onSet: onSetVolume!),
        iconButton(
          FluentIcons.dismiss_20_regular,
          l10n.desktopPlayerClose,
          onClose,
          iconSize: 15,
        ),
      ],
    );

    return Semantics(
      container: true,
      label: l10n.desktopPlayerNowPlaying(spoken),
      child: Container(
        height: DesktopNowPlayingIsland.height,
        decoration: BoxDecoration(
          color: c.accentPrimary.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: c.accentPrimary.withValues(alpha: 0.30)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 3, 0),
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

/// Карточка выпадающего окошка островка: список, скорость, громкость.
class _PopoverCard extends StatelessWidget {
  const _PopoverCard({required this.child, this.width, this.maxHeight = 360});

  final Widget child;
  final double? width;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width ?? 0,
        maxWidth: width ?? double.infinity,
        maxHeight: maxHeight,
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
          child: child,
        ),
      ),
    );
  }
}

/// Кнопка с выпадающим окошком под ней: скорость, громкость.
///
/// Окошко привязано к кнопке и живёт в слое над окном; щелчок мимо обоих
/// закрывает его. Колесо мыши над кнопкой — по желанию вызывающего (так
/// громкость крутится, не открывая ползунка).
class _PopoverButton extends StatefulWidget {
  const _PopoverButton({
    required this.builder,
    required this.popover,
    this.onScroll,
  });

  final Widget Function(BuildContext context, bool open, VoidCallback toggle)
  builder;
  final Widget Function(BuildContext context, VoidCallback close) popover;

  /// Колесо над кнопкой: вверх — отрицательное смещение.
  final ValueChanged<double>? onScroll;

  @override
  State<_PopoverButton> createState() => _PopoverButtonState();
}

class _PopoverButtonState extends State<_PopoverButton> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final Object _group = Object();

  void _toggle() => setState(() {
    if (_portal.isShowing) {
      _portal.hide();
    } else {
      _portal.show();
    }
  });

  void _close() {
    if (!_portal.isShowing) return;
    setState(_portal.hide);
  }

  @override
  Widget build(BuildContext context) {
    Widget button = widget.builder(context, _portal.isShowing, _toggle);
    final scroll = widget.onScroll;
    if (scroll != null) {
      button = Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) scroll(e.scrollDelta.dy);
        },
        child: button,
      );
    }
    return TapRegion(
      groupId: _group,
      onTapOutside: (_) => _close(),
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (ctx) => Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
              offset: const Offset(0, 8),
              child: TapRegion(
                groupId: _group,
                child: widget.popover(ctx, _close),
              ),
            ),
          ),
          child: button,
        ),
      ),
    );
  }
}

/// Скорость: подпись «1×» на кнопке и ступени Telegram в выпадающем окошке.
///
/// Не обычная скорость подсвечена акцентом — как в Telegram: ускоренное
/// голосовое видно сразу, а не только на слух.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.onSet});

  final double speed;
  final ValueChanged<double> onSet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final changed = (speed - 1.0).abs() > 0.01;
    return _PopoverButton(
      builder: (ctx, open, toggle) => DesktopTooltip(
        message: l10n.desktopPlayerSpeed,
        child: Semantics(
          button: true,
          expanded: open,
          label: '${l10n.desktopPlayerSpeed} ${desktopSpeedLabel(speed)}',
          child: HoverListener(
            onTap: toggle,
            builder: (ctx, hovered, pressed) => Container(
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: open || pressed
                    ? c.pressed
                    : (hovered ? c.hover : Colors.transparent),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: changed
                      ? c.accentPrimary.withValues(alpha: 0.7)
                      : c.textTertiary.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                desktopSpeedLabel(speed),
                style: TextStyle(
                  fontFamily: DType.family,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: changed ? c.accentPrimary : c.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
      popover: (ctx, close) => _PopoverCard(
        width: 150,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: DSpace.xs),
            for (final s in kDesktopPlayerSpeeds)
              _SpeedRow(
                label: s == 1.0
                    ? '${desktopSpeedLabel(s)}  ·  ${l10n.desktopPlayerSpeedNormal}'
                    : desktopSpeedLabel(s),
                selected: (s - speed).abs() < 0.01,
                onTap: () {
                  close();
                  onSet(s);
                },
              ),
            const SizedBox(height: DSpace.xs),
          ],
        ),
      ),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: HoverListener(
          onTap: onTap,
          builder: (ctx, hovered, pressed) => Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: DSpace.m),
            color: hovered ? c.hover : Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? c.accentPrimary : c.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    FluentIcons.checkmark_16_regular,
                    size: 14,
                    color: c.accentPrimary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Громкость: значок динамика по уровню и вертикальный ползунок под ним.
///
/// Минималистично, как в Telegram: ползунок без подписей и делений, только
/// дорожка и бегунок. Колесо мыши над значком меняет громкость на двадцатую
/// долю, не открывая окошка.
class _VolumeButton extends StatelessWidget {
  const _VolumeButton({required this.volume, required this.onSet});

  final ValueListenable<double> volume;
  final ValueChanged<double> onSet;

  static IconData _iconFor(double v) {
    if (v <= 0.001) return FluentIcons.speaker_mute_20_regular;
    if (v < 0.5) return FluentIcons.speaker_1_20_regular;
    return FluentIcons.speaker_2_20_regular;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<double>(
      valueListenable: volume,
      builder: (ctx, v, _) => _PopoverButton(
        onScroll: (dy) {
          if (dy == 0) return;
          onSet((volume.value + (dy < 0 ? 0.05 : -0.05)).clamp(0.0, 1.0));
        },
        builder: (ctx, open, toggle) => DesktopIconButton(
          icon: _iconFor(v),
          size: 28,
          iconSize: 16,
          tooltip: l10n.desktopPlayerVolume,
          onPressed: toggle,
        ),
        popover: (ctx, close) => _PopoverCard(
          width: 40,
          child: ValueListenableBuilder<double>(
            valueListenable: volume,
            builder: (ctx, value, _) => _VolumeSlider(
              value: value,
              onChanged: onSet,
              label: l10n.desktopPlayerVolume,
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String label;

  static const double _h = 120;
  static const double _pad = 12;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final v = value.clamp(0.0, 1.0);
    void at(Offset local) {
      final t = 1 - ((local.dy - _pad) / (_h - 2 * _pad));
      onChanged(t.clamp(0.0, 1.0));
    }

    return Semantics(
      slider: true,
      label: label,
      value: '${(v * 100).round()}%',
      increasedValue: '${((v + 0.1).clamp(0.0, 1.0) * 100).round()}%',
      decreasedValue: '${((v - 0.1).clamp(0.0, 1.0) * 100).round()}%',
      onIncrease: () => onChanged((v + 0.1).clamp(0.0, 1.0)),
      onDecrease: () => onChanged((v - 0.1).clamp(0.0, 1.0)),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => at(d.localPosition),
          onVerticalDragUpdate: (d) => at(d.localPosition),
          child: SizedBox(
            width: 40,
            height: _h,
            child: CustomPaint(
              painter: _VolumePainter(
                value: v,
                track: c.textTertiary.withValues(alpha: 0.35),
                fill: c.accentPrimary,
                knob: Colors.white,
                pad: _pad,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumePainter extends CustomPainter {
  _VolumePainter({
    required this.value,
    required this.track,
    required this.fill,
    required this.knob,
    required this.pad,
  });

  final double value;
  final Color track;
  final Color fill;
  final Color knob;
  final double pad;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final top = pad;
    final bottom = size.height - pad;
    const w = 4.0;
    final whole = RRect.fromLTRBR(
      cx - w / 2,
      top,
      cx + w / 2,
      bottom,
      const Radius.circular(w / 2),
    );
    canvas.drawRRect(whole, Paint()..color = track);
    final y = bottom - (bottom - top) * value;
    canvas.drawRRect(
      RRect.fromLTRBR(
        cx - w / 2,
        y,
        cx + w / 2,
        bottom,
        const Radius.circular(w / 2),
      ),
      Paint()..color = fill,
    );
    canvas.drawCircle(
      Offset(cx, y),
      6,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawCircle(Offset(cx, y), 5.5, Paint()..color = knob);
  }

  @override
  bool shouldRepaint(_VolumePainter old) =>
      old.value != value ||
      old.track != track ||
      old.fill != fill ||
      old.knob != knob;
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
            height: 42,
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
                        style: TextStyle(
                          fontFamily: DType.family,
                          fontSize: 13,
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
                          style: TextStyle(
                            fontFamily: DType.family,
                            fontSize: 11.5,
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
                  style: TextStyle(
                    fontFamily: DType.family,
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
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pressed
                  ? c.accentPrimary.withValues(alpha: 0.8)
                  : (hovered ? c.accentPrimaryAlt : c.accentPrimary),
            ),
            child: loading
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Icon(
                    playing
                        ? FluentIcons.pause_20_filled
                        : FluentIcons.play_20_filled,
                    size: 15,
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
