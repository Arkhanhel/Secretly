// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';

/// Угол окна, к которому прилипает мини-окно звонка.
enum DesktopCallMiniCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Угол из сохранённой строки; испорченное значение — правый верхний.
DesktopCallMiniCorner desktopCallMiniCornerFrom(String? raw) {
  for (final c in DesktopCallMiniCorner.values) {
    if (c.name == raw) return c;
  }
  return DesktopCallMiniCorner.topRight;
}

/// Отступы мини-окна от краёв окна приложения.
///
/// 🔴 ЧИСЛА — ОТ ТОГО, ЧТО ПОД НИМ ЛЕЖИТ, А НЕ ОТ КРАСОТЫ.
///
/// * Сверху — шапка окна (48), полоса идущего звонка (34) и плавающая шапка
///   переписки с её кнопками (64): мини-окно, севшее на кнопку звонка или
///   поиска, прячет ровно то, чем в этот момент пользуются.
/// * Снизу — поле ввода: мини-окно в правом нижнем углу закрывало бы кнопку
///   «Отправить».
/// * Слева — рейка разделов.
const EdgeInsets kDesktopCallMiniInsets = EdgeInsets.fromLTRB(78, 154, 16, 96);

/// Промежуток между двумя мини-окнами, когда звонков два.
const double kDesktopCallMiniGap = 10;

/// Где лежит левый верхний угол мини-окна размера [size] в углу [corner].
///
/// Окно меньше мини-окна с отступами — прижимаем к краю, а не уводим за
/// него: мини-окно, которое нельзя увидеть, нельзя и развернуть.
Offset desktopCallMiniOrigin({
  required DesktopCallMiniCorner corner,
  required Size area,
  required Size size,
  EdgeInsets insets = kDesktopCallMiniInsets,
}) {
  final left =
      corner == DesktopCallMiniCorner.topLeft ||
      corner == DesktopCallMiniCorner.bottomLeft;
  final top =
      corner == DesktopCallMiniCorner.topLeft ||
      corner == DesktopCallMiniCorner.topRight;
  final maxX = (area.width - size.width).clamp(0.0, double.infinity);
  final maxY = (area.height - size.height).clamp(0.0, double.infinity);
  final x = left ? insets.left : area.width - insets.right - size.width;
  final y = top ? insets.top : area.height - insets.bottom - size.height;
  return Offset(x.clamp(0.0, maxX), y.clamp(0.0, maxY));
}

/// Ближайший угол: куда мини-окно прилипает, когда его отпускают.
DesktopCallMiniCorner desktopCallMiniNearestCorner({
  required Offset center,
  required Size area,
}) {
  final left = center.dx < area.width / 2;
  final top = center.dy < area.height / 2;
  if (top) {
    return left ? DesktopCallMiniCorner.topLeft : DesktopCallMiniCorner.topRight;
  }
  return left
      ? DesktopCallMiniCorner.bottomLeft
      : DesktopCallMiniCorner.bottomRight;
}

/// Одно мини-окно в слое: его размер и содержимое.
class DesktopCallMiniEntry {
  const DesktopCallMiniEntry({
    required this.id,
    required this.size,
    required this.child,
  });

  /// Постоянный ключ: звонок один на один или созвон комнаты.
  final String id;
  final Size size;
  final Widget child;
}

/// Слой мини-окон поверх всего приложения.
///
/// Мини-окна стоят столбиком в одном углу. Их можно утащить мышью в любое
/// место; отпущенные, они прилипают к ближайшему углу — тому, который потом
/// и запоминается. Свободное положение не запоминаем нарочно: после смены
/// размера окна «где-то посередине» становится «поверх переписки».
///
/// Вне самих мини-окон слой прозрачен для мыши: нажатия проходят в
/// приложение под ним.
class DesktopCallMiniLayer extends StatefulWidget {
  const DesktopCallMiniLayer({
    super.key,
    required this.entries,
    required this.corner,
    required this.onCornerChanged,
    this.insets = kDesktopCallMiniInsets,
  });

  final List<DesktopCallMiniEntry> entries;
  final DesktopCallMiniCorner corner;
  final ValueChanged<DesktopCallMiniCorner> onCornerChanged;
  final EdgeInsets insets;

  @override
  State<DesktopCallMiniLayer> createState() => _DesktopCallMiniLayerState();
}

class _DesktopCallMiniLayerState extends State<DesktopCallMiniLayer> {
  late DesktopCallMiniCorner _corner = widget.corner;

  /// Левый верхний угол столбика, пока его тащат. `null` — не тащат.
  Offset? _drag;

  @override
  void didUpdateWidget(DesktopCallMiniLayer old) {
    super.didUpdateWidget(old);
    if (old.corner != widget.corner) _corner = widget.corner;
  }

  Size get _columnSize {
    var w = 0.0;
    var h = 0.0;
    for (var i = 0; i < widget.entries.length; i++) {
      final s = widget.entries[i].size;
      if (s.width > w) w = s.width;
      h += s.height;
      if (i > 0) h += kDesktopCallMiniGap;
    }
    return Size(w, h);
  }

  Offset _clamp(Offset o, Size area, Size size) {
    final maxX = (area.width - size.width).clamp(0.0, double.infinity);
    final maxY = (area.height - size.height).clamp(0.0, double.infinity);
    return Offset(o.dx.clamp(0.0, maxX), o.dy.clamp(0.0, maxY));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (ctx, box) {
        final area = box.biggest;
        final size = _columnSize;
        final rest = desktopCallMiniOrigin(
          corner: _corner,
          area: area,
          size: size,
          insets: widget.insets,
        );
        final origin = _drag ?? rest;
        final bottomAligned =
            _corner == DesktopCallMiniCorner.bottomLeft ||
            _corner == DesktopCallMiniCorner.bottomRight;
        return Stack(
          children: [
            AnimatedPositioned(
              // Пока тащат — без задержки, за курсором. Отпустили — плавно
              // доезжает до угла.
              duration: _drag != null ? Duration.zero : DMotion.medium,
              curve: DMotion.easeOutCubic,
              left: origin.dx,
              top: origin.dy,
              width: size.width,
              height: size.height,
              child: GestureDetector(
                onPanStart: (_) => setState(() => _drag = origin),
                onPanUpdate: (d) => setState(
                  () => _drag = _clamp((_drag ?? origin) + d.delta, area, size),
                ),
                onPanEnd: (_) => _release(area, size),
                onPanCancel: () => _release(area, size),
                child: MouseRegion(
                  cursor: _drag != null
                      ? SystemMouseCursors.grabbing
                      : MouseCursor.defer,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    // Прилипшие к низу стоят от низа: второе мини-окно
                    // появляется над первым, а не уезжает под край.
                    verticalDirection: bottomAligned
                        ? VerticalDirection.up
                        : VerticalDirection.down,
                    children: [
                      for (var i = 0; i < widget.entries.length; i++) ...[
                        if (i > 0) const SizedBox(height: kDesktopCallMiniGap),
                        KeyedSubtree(
                          key: ValueKey(widget.entries[i].id),
                          child: SizedBox.fromSize(
                            size: widget.entries[i].size,
                            child: widget.entries[i].child,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _release(Size area, Size size) {
    final drag = _drag;
    if (drag == null) return;
    final next = desktopCallMiniNearestCorner(
      center: drag + Offset(size.width / 2, size.height / 2),
      area: area,
    );
    setState(() {
      _drag = null;
      _corner = next;
    });
    if (next != widget.corner) widget.onCornerChanged(next);
  }
}

/// Размеры мини-окна: ширина одна, высота — по тому, есть ли картинка.
abstract final class DesktopCallMiniSize {
  static const double width = 288;

  /// Полоса кнопок внизу.
  static const double bar = 48;

  /// Сцена без видео: портрет, имя и состояние в одну строку.
  static const double voiceStage = 76;

  /// Сцена с видео — 16:9 по ширине.
  static const double videoStage = 162;

  static Size of({required bool video}) =>
      Size(width, (video ? videoStage : voiceStage) + bar);
}

/// Сцена мини-окна «чёрная в любой теме», как сцена звонка во весь окно.
const Color kDesktopCallMiniStage = Color(0xFF0E1015);
const Color _kMiniBar = Color(0xFF15181E);

/// Мини-окно звонка: сцена сверху и полоса кнопок снизу.
///
/// 🔴 КНОПКИ ВИДНЫ ВСЕГДА, А НЕ ПО НАВЕДЕНИЮ. Мини-окно — это пульт идущего
/// разговора: выключить микрофон или положить трубку нужно сразу и не
/// целясь. Кнопки, которые появляются только под курсором, сначала надо
/// найти, а в звонке ищут быстро.
///
/// Двойной щелчок по сцене разворачивает звонок; одиночный ничего не делает —
/// иначе мини-окно раскрывалось бы от каждой попытки его передвинуть.
class DesktopCallMiniCard extends StatelessWidget {
  const DesktopCallMiniCard({
    super.key,
    required this.stage,
    required this.video,
    required this.controls,
    required this.onExpand,
    required this.expandTooltip,
    required this.end,
    this.semanticLabel,
  });

  /// Что на сцене: картинка или портрет с подписью.
  final Widget stage;

  /// Сцена с картинкой — она выше.
  final bool video;

  /// Кнопки слева: микрофон, камера.
  final List<Widget> controls;

  final VoidCallback onExpand;
  final String expandTooltip;

  /// Красная кнопка справа: завершить или выйти.
  final Widget end;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final stageHeight = video
        ? DesktopCallMiniSize.videoStage
        : DesktopCallMiniSize.voiceStage;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        decoration: const BoxDecoration(
          color: kDesktopCallMiniStage,
          borderRadius: BorderRadius.all(Radius.circular(DRadii.r16)),
          boxShadow: [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        // Кромка рисуется ПОВЕРХ: рамка в `decoration` отнимает у содержимого
        // по точке с каждой стороны, и сцена с полосой кнопок в свою высоту
        // уже не помещались.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DRadii.r16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: stageHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: onExpand,
                child: stage,
              ),
            ),
            Container(
              height: DesktopCallMiniSize.bar,
              padding: const EdgeInsets.symmetric(horizontal: DSpace.s),
              color: _kMiniBar,
              child: Row(
                children: [
                  for (var i = 0; i < controls.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    controls[i],
                  ],
                  const Spacer(),
                  DesktopCallMiniButton(
                    icon: FluentIcons.arrow_maximize_20_regular,
                    tooltip: expandTooltip,
                    onTap: onExpand,
                  ),
                  const SizedBox(width: 6),
                  end,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Как выглядит кнопка мини-окна.
enum DesktopCallMiniTone {
  /// Обычная: полупрозрачная.
  normal,

  /// Выключенный микрофон: красная заливка — «меня не слышно» должно быть
  /// видно издалека.
  off,

  /// Завершить: красная и шире остальных.
  end,
}

/// Кнопка мини-окна: 34×34, а завершающая — 46 в ширину.
class DesktopCallMiniButton extends StatelessWidget {
  const DesktopCallMiniButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tone = DesktopCallMiniTone.normal,
  });

  final IconData icon;
  final String tooltip;

  /// `null` — кнопка недоступна сейчас (действие уже летит на сервер).
  final VoidCallback? onTap;
  final DesktopCallMiniTone tone;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final enabled = onTap != null;
    return DesktopTooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: HoverListener(
          onTap: onTap,
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          builder: (ctx, hovered, pressed) {
            final Color bg = switch (tone) {
              DesktopCallMiniTone.normal => Colors.white.withValues(
                alpha: pressed ? 0.20 : (hovered ? 0.14 : 0.08),
              ),
              DesktopCallMiniTone.off => c.danger.withValues(
                alpha: pressed ? 0.75 : (hovered ? 0.95 : 0.85),
              ),
              DesktopCallMiniTone.end => pressed
                  ? c.danger.withValues(alpha: 0.80)
                  : (hovered ? c.danger.withValues(alpha: 0.92) : c.danger),
            };
            return Opacity(
              opacity: enabled ? 1 : 0.45,
              child: AnimatedContainer(
                duration: DMotion.fast,
                width: tone == DesktopCallMiniTone.end ? 46 : 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(DRadii.r11),
                ),
                child: Icon(icon, size: 17, color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Чип состояния поверх картинки: замок и время разговора.
class DesktopCallMiniChip extends StatelessWidget {
  const DesktopCallMiniChip({
    super.key,
    required this.label,
    required this.secure,
  });

  final String label;

  /// Замок — только когда разговор уже зашифрован сквозным шифрованием и
  /// идёт. Пока звоним, замка нет: шифровать ещё нечего. Умолчания нет
  /// намеренно: до 26.09.2026 оно было `true`, и групповой созвон без E2EE
  /// показывал зелёный замок. Каждый вызов решает сам.
  final bool secure;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(DRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (secure) ...[
            Icon(FluentIcons.lock_closed_16_filled, size: 11, color: c.success),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: DType.family,
              fontSize: 11,
              height: 1.0,
              fontWeight: FontWeight.w600,
              color: secure ? c.success : Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// Время разговора «мм:сс» или «ч:мм:сс».
String desktopCallMiniDuration(int startedAtMs, {int? nowMs}) {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  var total = (now - startedAtMs) ~/ 1000;
  if (total < 0) total = 0;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
