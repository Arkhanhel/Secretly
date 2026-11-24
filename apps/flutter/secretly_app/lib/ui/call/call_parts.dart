// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Части экрана звонка по макету «Calls», 4b (21.11.2026).
///
/// Один экран и одна панель на голосовой и видео: Микрофон, Звук, Камера,
/// Ещё, Завершить. Выключенное — белая кнопка с тёмным знаком (видно
/// издалека). Живой фон: мягкое свечение медленно плывёт; вокруг портрета —
/// кольцо, когда собеседник говорит. Замок в шапке открывает ключ звонка —
/// четыре знака, одинаковые у обоих.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../icons/adaptive_icons.dart';
import '../motion/motion.dart';

const Color kCallBg = Color(0xFF0B1016);
const Color kCallRed = Color(0xFFE5484D);
const Color kCallGreen = Color(0xFF2FA66A);
const Color kCallSafe = Color(0xFF9BE3B0);
const Color kCallWarn = Color(0xFFE09A2B);
const Color kCallAccent = Color(0xFF7FD0FF);
const Color kCallGlass = Color(0x8C141A22);

abstract final class CallIcons {
  static const IconData minimize = AdaptiveIconData(
    Icons.keyboard_arrow_down_rounded,
    CupertinoIcons.chevron_down,
  );
  static const IconData lock = AdaptiveIconData(
    Icons.lock_rounded,
    CupertinoIcons.lock_fill,
  );
  static const IconData signal = AdaptiveIconData(
    Icons.signal_cellular_alt_rounded,
    CupertinoIcons.chart_bar_fill,
  );
  static const IconData signalWeak = AdaptiveIconData(
    Icons.signal_cellular_alt_1_bar_rounded,
    CupertinoIcons.chart_bar,
  );
  static const IconData mic = AdaptiveIconData(
    Icons.mic_rounded,
    CupertinoIcons.mic_fill,
  );
  static const IconData micOff = AdaptiveIconData(
    Icons.mic_off_rounded,
    CupertinoIcons.mic_slash_fill,
  );
  static const IconData earpiece = AdaptiveIconData(
    Icons.phone_in_talk_rounded,
    CupertinoIcons.phone_fill,
  );
  static const IconData speaker = AdaptiveIconData(
    Icons.volume_up_rounded,
    CupertinoIcons.speaker_3_fill,
  );
  static const IconData headphones = AdaptiveIconData(
    Icons.headphones_rounded,
    CupertinoIcons.headphones,
  );
  static const IconData bluetooth = AdaptiveIconData(
    Icons.bluetooth_audio_rounded,
    CupertinoIcons.bluetooth,
  );
  static const IconData camera = AdaptiveIconData(
    Icons.videocam_rounded,
    CupertinoIcons.videocam_fill,
  );
  static const IconData cameraOff = AdaptiveIconData(
    Icons.videocam_off_rounded,
    CupertinoIcons.video_camera,
  );
  static const IconData more = AdaptiveIconData(
    Icons.more_horiz_rounded,
    CupertinoIcons.ellipsis,
  );
  static const IconData close = AdaptiveIconData(
    Icons.close_rounded,
    CupertinoIcons.xmark,
  );
  static const IconData end = AdaptiveIconData(
    Icons.call_end_rounded,
    CupertinoIcons.phone_down_fill,
  );
  static const IconData accept = AdaptiveIconData(
    Icons.call_rounded,
    CupertinoIcons.phone_fill,
  );
  static const IconData screen = AdaptiveIconData(
    Icons.screen_share_rounded,
    CupertinoIcons.rectangle_on_rectangle,
  );
  static const IconData flip = AdaptiveIconData(
    Icons.cameraswitch_rounded,
    CupertinoIcons.camera_rotate_fill,
  );
  static const IconData chat = AdaptiveIconData(
    Icons.chat_bubble_rounded,
    CupertinoIcons.chat_bubble_fill,
  );
  static const IconData key = AdaptiveIconData(
    Icons.verified_user_rounded,
    CupertinoIcons.checkmark_shield_fill,
  );
  static const IconData check = AdaptiveIconData(
    Icons.check_rounded,
    CupertinoIcons.checkmark_alt,
  );
  static const IconData spin = AdaptiveIconData(
    Icons.autorenew_rounded,
    CupertinoIcons.arrow_2_circlepath,
  );
  static const IconData chevronLeft = AdaptiveIconData(
    Icons.chevron_left_rounded,
    CupertinoIcons.chevron_left,
  );
  static const IconData chevronRight = AdaptiveIconData(
    Icons.chevron_right_rounded,
    CupertinoIcons.chevron_right,
  );
  static const IconData up = AdaptiveIconData(
    Icons.keyboard_arrow_up_rounded,
    CupertinoIcons.chevron_up,
  );
}

/// Стеклянная подложка (шапка, панель, листы).
class CallGlass extends StatelessWidget {
  const CallGlass({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur = 20,
    this.color = kCallGlass,
    this.padding,
    this.shadow = false,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 50,
                  offset: Offset(0, 20),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: r,
              border: const Border(
                top: BorderSide(color: Color(0x29FFFFFF), width: 1),
              ),
            ),
            child: padding == null
                ? child
                : Padding(padding: padding!, child: child),
          ),
        ),
      ),
    );
  }
}

/// Живой фон: три мягких свечения медленно плывут. Слабая связь — тёплый
/// оттенок. [animate] `false` — стоит (окно ОС, фон под видео).
class CallAmbientBackground extends StatefulWidget {
  const CallAmbientBackground({
    super.key,
    this.warn = false,
    this.animate = true,
  });

  final bool warn;
  final bool animate;

  @override
  State<CallAmbientBackground> createState() => _CallAmbientBackgroundState();
}

class _CallAmbientBackgroundState extends State<CallAmbientBackground> {
  // Медленно (минута на круг). 🔴 22.11.2026 (разбор): раньше — кадр на
  // каждый тик экрана (60–120 в секунду), и четыре размытия поверх
  // пересчитывались каждый кадр — тяжело для слабых Android. Свечение
  // движется на несколько пикселей в секунду: 15 кадров хватает с запасом,
  // а без тикера экран между ними не перерисовывается вовсе.
  static const Duration _step = Duration(milliseconds: 66);
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;

  void _sync() {
    final on = widget.animate && TickerMode.valuesOf(context).enabled;
    if (on && _timer == null) {
      _clock.start();
      _timer = Timer.periodic(_step, (_) {
        _seconds.value = (_clock.elapsedMilliseconds / 1000) % 60;
      });
    } else if (!on && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant CallAmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.warn ? 1 : 0),
        duration: const Duration(milliseconds: 600),
        builder: (context, warn, _) => ValueListenableBuilder<double>(
          valueListenable: _seconds,
          builder: (context, t, _) => CustomPaint(
            painter: _AmbientPainter(t: t, warn: warn),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.t, required this.warn});
  final double t;
  final double warn;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kCallBg);
    void glow(double cx, double cy, Color c, double radius) {
      final center = Offset(size.width * cx, size.height * cy);
      final r = size.longestSide * radius;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = ui.Gradient.radial(center, r, [
            c,
            c.withValues(alpha: 0),
          ]),
      );
    }

    final blue = Color.lerp(
      const Color(0x8C2E9FE4),
      const Color(0x59E09A2B),
      warn,
    )!;
    glow(
      0.30 + 0.18 * math.sin(t / 5),
      0.22 + 0.10 * math.cos(t / 6),
      blue,
      0.55,
    );
    glow(
      0.72 + 0.14 * math.cos(t / 7),
      0.48 + 0.12 * math.sin(t / 4.5),
      const Color(0x80553BA8),
      0.55,
    );
    glow(0.45 + 0.20 * math.sin(t / 8), 1.05, const Color(0x730A7568), 0.6);
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.t != t || old.warn != warn;
}

/// Портрет собеседника: кольца вызова, «говорит» — живое кольцо.
class CallIdentity extends StatelessWidget {
  const CallIdentity({
    super.key,
    required this.name,
    required this.avatar,
    required this.status,
    required this.size,
    this.ringing = false,
    this.level,
  });

  final String name;

  /// Портрет (фото или общая заглушка) размером [size].
  final Widget avatar;
  final String status;
  final double size;
  final bool ringing;

  /// Громкость собеседника 0…1 (`null` — кольца нет).
  final ValueListenable<double>? level;

  @override
  Widget build(BuildContext context) {
    final avatar = ClipOval(
      child: SizedBox(width: size, height: size, child: this.avatar),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              if (ringing) ...[
                const _CallRing(delay: 0),
                const _CallRing(delay: 1000),
              ],
              if (level != null)
                ValueListenableBuilder<double>(
                  valueListenable: level!,
                  builder: (context, l, child) => DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kCallAccent.withValues(alpha: 0.08 + l * 0.18),
                          spreadRadius: 6 + l * 16,
                        ),
                        BoxShadow(
                          color: kCallAccent.withValues(alpha: 0.04 + l * 0.08),
                          spreadRadius: 12 + l * 34,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: avatar,
                )
              else
                DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x33000000), blurRadius: 40),
                    ],
                  ),
                  child: avatar,
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            status,
            key: ValueKey(status.replaceAll(RegExp(r'\d'), '0')),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _CallRing extends StatefulWidget {
  const _CallRing({required this.delay});
  final int delay;

  @override
  State<_CallRing> createState() => _CallRingState();
}

class _CallRingState extends State<_CallRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = Curves.easeOut.transform(_c.value);
          return Transform.scale(
            scale: 1 + 0.9 * v,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: kCallAccent.withValues(
                    alpha: _c.isAnimating ? 0.6 * (1 - v) : 0,
                  ),
                  width: 1.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Круглая стеклянная кнопка шапки (свернуть, связь).
class CallHeaderButton extends StatelessWidget {
  const CallHeaderButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color = Colors.white,
    this.size = 22,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CallGlass(
          radius: 22,
          color: const Color(0x73141A22),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: color, size: size),
          ),
        ),
      ),
    );
  }
}

/// Плашка под шапкой: слабая связь, переподключение, показ экрана.
class CallBanner extends StatelessWidget {
  const CallBanner({
    super.key,
    required this.text,
    required this.icon,
    required this.background,
    required this.foreground,
    this.spinning = false,
  });

  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: 16, color: foreground);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinning) _Spin(child: glyph) else glyph,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spin extends StatefulWidget {
  const _Spin({required this.child});
  final Widget child;
  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _c, child: widget.child);
}

/// Кнопка нижней панели: круг 56 и подпись. Выключенное — белая с тёмным
/// знаком. «Завершить» — красный скруглённый квадрат.
class CallDockButton extends StatelessWidget {
  const CallDockButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.inverted = false,
    this.danger = false,
    this.onLongPress,
    this.semanticOn,
  });

  /// Что диктор называет «вкл.» (22.11.2026): у микрофона и камеры белая
  /// кнопка значит ВЫКЛЮЧЕНО, и прежний `toggled: inverted` читал «Камера,
  /// вкл.» при выключенной камере. `null` — как [inverted].
  final bool? semanticOn;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Белая кнопка с тёмным знаком: «выключено» / «открыто».
  final bool inverted;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? kCallRed
        : inverted
        ? Colors.white
        : const Color(0x1FFFFFFF);
    final fg = inverted && !danger ? kCallBg : Colors.white;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      toggled: danger ? null : (semanticOn ?? inverted),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(danger ? 20 : 28),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Motion.popElastic),
                  child: c,
                ),
                child: Icon(icon, key: ValueKey(icon), size: 26, color: fg),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Плитка панели «Ещё».
class CallMoreTile extends StatelessWidget {
  const CallMoreTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final fg = active ? kCallBg : const Color(0xFFE9EEF3);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      toggled: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 74,
          decoration: BoxDecoration(
            color: active ? Colors.white : const Color(0x12FFFFFF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: fg),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

/// Строка списка звуковых устройств с галочкой.
class CallRouteRow extends StatelessWidget {
  const CallRouteRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: const Color(0xFFCFD9E3)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: selected ? 1 : 0,
                  child: const Icon(
                    CallIcons.check,
                    size: 20,
                    color: kCallAccent,
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

/// Ключ звонка: четыре знака из отпечатков шифрования обеих сторон.
///
/// Отпечатки DTLS (из описаний соединения) сортируются и хэшируются — у
/// обоих получается одно и то же; подменённое соединение даёт другие знаки.
/// Знаки — эмодзи, а не слова: у собеседников может быть разный язык.
const List<String> kCallKeyEmoji = [
  '🦊', '🐼', '🦉', '🐙', '🦋', '🐢', '🦁', '🐳', //
  '🍎', '🍋', '🍇', '🍒', '🥑', '🌶️', '🍄', '🌽', //
  '⭐', '🌙', '☀️', '⚡', '❄️', '🔥', '🌈', '🌊', //
  '⚓', '🎈', '🎸', '🎲', '🔑', '🔔', '📌', '✏️', //
  '🚀', '🚲', '⛵', '🚗', '✈️', '🏠', '⛺', '🗼', //
  '🌵', '🌻', '🌲', '🍀', '🌸', '🐝', '🐞', '🦀', //
  '⚽', '🏀', '🎯', '🎁', '💎', '👑', '🎩', '🧲', //
  '🦄', '🐧', '🐸', '🐨', '🦒', '🐘', '🦜', '🐬', //
];

/// Четыре знака по байтам отпечатка (по 6 бит).
List<String> callKeyEmoji(List<int> digest) {
  if (digest.length < 3) return const [];
  final bits = (digest[0] << 16) | (digest[1] << 8) | digest[2];
  return [
    for (var i = 0; i < 4; i++) kCallKeyEmoji[(bits >> (18 - i * 6)) & 63],
  ];
}
