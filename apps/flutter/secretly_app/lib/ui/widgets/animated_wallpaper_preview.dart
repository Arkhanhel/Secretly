// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme_presets.dart';
import '../wave1_l10n.dart';
import 'telegram_wallpaper.dart';

/// Near-fullscreen preview of an animated wallpaper with a faithful mock chat on
/// top and a frosted "island" control to pick the animation mode + apply.
///
/// Returns the chosen mode + «проводит сообщения» when the user taps Apply, or
/// null if dismissed (the caller then applies the wallpaper id + persists both).
Future<({ChatWallpaperAnimMode mode, bool conduct})?>
    showAnimatedWallpaperPreview(
  BuildContext context, {
  required WallpaperStyle style,
  required ChatWallpaperAnimMode initialMode,
  required bool initialConduct,
}) {
  return showGeneralDialog<({ChatWallpaperAnimMode mode, bool conduct})>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'animated-wallpaper-preview',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) => _AnimatedWallpaperPreview(
      style: style,
      initialMode: initialMode,
      initialConduct: initialConduct,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AnimatedWallpaperPreview extends StatefulWidget {
  const _AnimatedWallpaperPreview({
    required this.style,
    required this.initialMode,
    required this.initialConduct,
  });

  final WallpaperStyle style;
  final ChatWallpaperAnimMode initialMode;
  final bool initialConduct;

  @override
  State<_AnimatedWallpaperPreview> createState() =>
      _AnimatedWallpaperPreviewState();
}

class _AnimatedWallpaperPreviewState extends State<_AnimatedWallpaperPreview> {
  final GlobalKey<TelegramWallpaperState> _wpKey =
      GlobalKey<TelegramWallpaperState>();
  late ChatWallpaperAnimMode _mode = widget.initialMode;
  late bool _conduct = widget.initialConduct;
  // Предпросмотр чередует стороны, чтобы одним касанием было видно ОБА
  // направления: исходящее уходит вверх, входящее стекает сверху.
  bool _nextPulseIncoming = false;

  void _selectMode(ChatWallpaperAnimMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  void _setConduct(bool value) {
    if (_conduct == value) return;
    setState(() => _conduct = value);
    // Включили — показываем сразу, не заставляя догадываться, что изменилось.
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _firePulse());
    }
  }

  void _firePulse() {
    if (!_conduct) return;
    _wpKey.currentState?.conductMessage(incoming: _nextPulseIncoming);
    _nextPulseIncoming = !_nextPulseIncoming;
  }

  void _onPreviewTap() {
    // Пока «проводит сообщения» включено, тап показывает именно волну — это то,
    // что человек сейчас настраивает. Иначе поведение прежнее.
    if (_conduct) {
      _firePulse();
      return;
    }
    if (_mode == ChatWallpaperAnimMode.tap) _wpKey.currentState?.shimmer();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // A Material ancestor is required so the mock-chat / island text renders
    // with a proper text style (without it Flutter draws the debug yellow
    // underline under every Text).
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(
          top: mq.padding.top + 8,
          left: 8,
          right: 8,
          bottom: mq.padding.bottom + 8,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Live animated wallpaper.
              TelegramWallpaper(
                key: _wpKey,
                style: widget.style,
                mode: _mode,
                conduct: _conduct,
              ),
              // Tap anywhere on the empty area to shimmer (only meaningful in
              // tap mode — mirrors the in-chat behaviour). Sits under the mock
              // chat + island, both of which handle their own gestures.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (_conduct || _mode == ChatWallpaperAnimMode.tap)
                      ? _onPreviewTap
                      : null,
                ),
              ),
              // Mock chat (non-interactive) — real bubble styling.
              const Positioned.fill(child: IgnorePointer(child: _MockChat())),
              // Top row: style name + close.
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _GlassPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.motion_photos_on,
                              size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            widget.style.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              // Bottom island: mode selector + apply.
              Positioned(
                left: 12,
                right: 12,
                bottom: 14,
                child: _ControlIsland(
                  mode: _mode,
                  onModeChanged: _selectMode,
                  conduct: _conduct,
                  onConductChanged: _setConduct,
                  onApply: () => Navigator.of(context)
                      .pop((mode: _mode, conduct: _conduct)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short, realistic conversation so the preview clearly reflects our chats —
/// real bubble gradient, timestamps and read receipts.
class _MockChat extends StatelessWidget {
  const _MockChat();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 62, 14, 168),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _dateChip(context, wave1Text(context, ru: 'Сегодня', en: 'Today')),
          const SizedBox(height: 12),
          _Bubble(
            outgoing: false,
            time: '14:21',
            text: wave1Text(
              context,
              ru: 'Слушай, обновил Secretly — тут теперь живые обои для чатов 🌌',
              en: 'Hey, I updated Secretly — it has living chat wallpapers now 🌌',
            ),
          ),
          _Bubble(
            outgoing: true,
            time: '14:22',
            read: true,
            text: wave1Text(
              context,
              ru: 'Ого, только что поставил Aurora. Переливается так мягко, что глаз не оторвать 🔥',
              en: 'Whoa, just set Aurora. It shimmers so smoothly I can’t look away 🔥',
            ),
          ),
          _Bubble(
            outgoing: false,
            time: '14:22',
            text: wave1Text(
              context,
              ru: 'А на батарею не влияет? Обычно анимации быстро сажают телефон',
              en: 'Doesn’t it drain the battery? Animations usually kill the phone',
            ),
          ),
          _Bubble(
            outgoing: true,
            time: '14:23',
            read: true,
            text: wave1Text(
              context,
              ru: 'Нет — между переливами всё статично, расход почти нулевой. И режим на выбор: постоянно, при входе или по тапу',
              en: 'Nope — it’s static between shimmers, near-zero drain. And you pick the mode: always, on open, or on tap',
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.outgoing,
    required this.text,
    required this.time,
    this.read = false,
  });

  final bool outgoing;
  final String text;
  final String time;
  final bool read;

  @override
  Widget build(BuildContext context) {
    final visuals = Theme.of(context).extension<ChatVisualsThemeExtension>();
    final cs = Theme.of(context).colorScheme;
    final bubbleTop = visuals?.bubbleTop ?? cs.primary;
    final bubbleBottom = visuals?.bubbleBottom ?? cs.primaryContainer;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(outgoing ? 20 : 6),
      bottomRight: Radius.circular(outgoing ? 6 : 20),
    );
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
        decoration: BoxDecoration(
          gradient: outgoing
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bubbleTop, bubbleBottom],
                )
              : null,
          // Incoming: matte, nearly opaque — a flat frosted fill (no gradient /
          // no highlight line) that the wallpaper barely shows through.
          color: outgoing ? null : const Color(0xFF2C303A).withValues(alpha: 0.9),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 9,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 10.5,
                    ),
                  ),
                  if (outgoing) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: read
                          ? const Color(0xFF8FD6FF)
                          : Colors.white.withValues(alpha: 0.72),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted "island" holding the animation-mode segments + the apply button.
class _ControlIsland extends StatelessWidget {
  const _ControlIsland({
    required this.mode,
    required this.onModeChanged,
    required this.conduct,
    required this.onConductChanged,
    required this.onApply,
  });

  final ChatWallpaperAnimMode mode;
  final ValueChanged<ChatWallpaperAnimMode> onModeChanged;
  final bool conduct;
  final ValueChanged<bool> onConductChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _segment(context, ChatWallpaperAnimMode.continuous,
                      Icons.all_inclusive, wave1Text(context, ru: 'Всегда', en: 'Always')),
                  _segment(context, ChatWallpaperAnimMode.onEnter, Icons.login,
                      wave1Text(context, ru: 'При входе', en: 'On open')),
                  _segment(context, ChatWallpaperAnimMode.tap, Icons.touch_app,
                      wave1Text(context, ru: 'По тапу', en: 'On tap')),
                  _segment(context, ChatWallpaperAnimMode.off, Icons.block,
                      wave1Text(context, ru: 'Без', en: 'Off')),
                ],
              ),
              const SizedBox(height: 8),
              _conductRow(context),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onApply,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    wave1Text(context, ru: 'Установить', en: 'Set wallpaper'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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

  /// Переключатель «фон проводит сообщения» — отдельной строкой, а не пятым
  /// сегментом сверху: сегменты отвечают на вопрос «как обои ведут себя сами»,
  /// а это — «участвуют ли обои в разговоре». Разные вопросы, и их сочетание
  /// осмысленно: можно оставить обои полностью статичными и всё равно видеть,
  /// как фон проводит каждое сообщение.
  Widget _conductRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onConductChanged(!conduct),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(11, 9, 7, 9),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: conduct
              ? cs.primary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: conduct
                ? cs.primary.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.electric_bolt,
              size: 18,
              color: conduct ? cs.primary : Colors.white,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    wave1Text(
                      context,
                      ru: 'Проводит сообщения',
                      en: 'Conducts messages',
                      uk: 'Проводить повідомлення',
                      es: 'Conduce los mensajes',
                      pt: 'Conduz as mensagens',
                      ptBr: 'Conduz as mensagens',
                      fr: 'Conduit les messages',
                      de: 'Leitet Nachrichten',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    wave1Text(
                      context,
                      ru: 'Свет идёт по узору: от вас — вверх, к вам — сверху',
                      en: 'Light runs along the pattern: yours up, theirs down',
                      uk: 'Світло йде візерунком: від вас — угору, до вас — згори',
                      es: 'La luz recorre el patron: tuyo arriba, suyo abajo',
                      pt: 'A luz percorre o padrao: seu para cima, dele para baixo',
                      ptBr: 'A luz percorre o padrao: seu para cima, dele para baixo',
                      fr: 'La lumiere suit le motif : vous vers le haut, eux vers le bas',
                      de: 'Licht folgt dem Muster: deins nach oben, ihres nach unten',
                    ),
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 10.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: conduct,
              onChanged: onConductChanged,
              activeThumbColor: cs.onPrimary,
              activeTrackColor: cs.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    ChatWallpaperAnimMode value,
    IconData icon,
    String label,
  ) {
    final cs = Theme.of(context).colorScheme;
    final selected = mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onModeChanged(value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? cs.onPrimary : Colors.white,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? cs.onPrimary
                      : Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.black.withValues(alpha: 0.34),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.close, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
