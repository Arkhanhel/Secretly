// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Долгое нажатие на свой аватар (макет «Profile Redesign», 21.11.2026):
/// держишь 380 мс — аватар чуть утапливается (0,94), вокруг него пружиной
/// раскрываются три кнопки (Фото, Рамка, Обложка) со сдвигом 30 мс, фон
/// темнеет. Ведёшь палец к нужной (она подрастает, отклик selection) и
/// отпускаешь — действие. Отпустил мимо — меню закрывается.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:flutter/services.dart';

@immutable
class AvatarMenuItem {
  const AvatarMenuItem({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
}

const SpringDescription _kMenuSpring = SpringDescription(
  mass: 1,
  stiffness: 420,
  damping: 26,
);

/// Оборачивает аватар: долгое нажатие открывает меню над экраном.
class AvatarRadialMenu extends StatefulWidget {
  const AvatarRadialMenu({
    super.key,
    required this.items,
    required this.child,
    this.enabled = true,
    this.hapticsEnabled,
    this.onOpenChanged,
  });

  /// Меню открылось/закрылось (экран на это время не тянет фото пальцем).
  final ValueChanged<bool>? onOpenChanged;

  final List<AvatarMenuItem> items;
  final Widget child;
  final bool enabled;
  final bool Function()? hapticsEnabled;

  @override
  State<AvatarRadialMenu> createState() => _AvatarRadialMenuState();
}

class _AvatarRadialMenuState extends State<AvatarRadialMenu>
    with TickerProviderStateMixin {
  OverlayEntry? _entry;
  late final AnimationController _open = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  final List<AnimationController> _itemCtl = [];
  int _hover = -1;
  Offset _center = Offset.zero;
  List<Offset> _targets = const [];

  bool get _haptics => widget.hapticsEnabled?.call() ?? true;

  void _haptic(void Function() f) {
    if (_haptics) f();
  }

  @override
  void dispose() {
    _entry?.remove();
    _open.dispose();
    _press.dispose();
    for (final c in _itemCtl) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void deactivate() {
    _entry?.remove();
    _entry = null;
    super.deactivate();
  }

  void _spring(AnimationController c, double to) {
    c.animateWith(SpringSimulation(_kMenuSpring, c.value, to, c.velocity));
  }

  void _show() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    _center = box.localToGlobal(box.size.center(Offset.zero));
    final r = math.max(box.size.shortestSide / 2, 40.0);
    // Как в макете: слева и справа чуть ниже центра, третья — под аватаром.
    _targets = [
      _center + Offset(-(r + 48), r * 0.55),
      _center + Offset(0, r + 56),
      _center + Offset(r + 48, r * 0.55),
    ].take(widget.items.length).toList();
    while (_itemCtl.length < widget.items.length) {
      _itemCtl.add(AnimationController.unbounded(vsync: this));
    }
    for (final c in _itemCtl) {
      c.value = 0;
    }
    _hover = -1;
    _haptic(() {
      if (defaultTargetPlatform == TargetPlatform.android) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    });
    _spring(_press, 0.94);
    _spring(_open, 1);
    // Кнопки — та же пружина со сдвигом 30 мс: сдвиг задаём начальной
    // «задержкой» в значении (отрицательное — ещё не выехала).
    for (var i = 0; i < _itemCtl.length; i++) {
      _itemCtl[i].value = -0.25 * i;
      _spring(_itemCtl[i], 1);
    }
    widget.onOpenChanged?.call(true);
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _move(Offset global) {
    var h = -1;
    for (var i = 0; i < _targets.length; i++) {
      if ((global - _targets[i]).distance < 40) h = i;
    }
    if (h != _hover) {
      _hover = h;
      if (h >= 0) _haptic(HapticFeedback.selectionClick);
      _entry?.markNeedsBuild();
    }
  }

  void _close({required bool commit}) {
    widget.onOpenChanged?.call(false);
    final h = _hover;
    _hover = -1;
    _spring(_press, 1);
    for (final c in _itemCtl) {
      _spring(c, 0);
    }
    // Слой снимается, когда затемнение погасло (без отдельного таймера).
    final entry = _entry;
    _open
        .animateWith(SpringSimulation(_kMenuSpring, _open.value, 0, _open.velocity))
        .whenCompleteOrCancel(() {
          if (_entry == entry) {
            entry?.remove();
            _entry = null;
          }
        });
    if (commit && h >= 0 && h < widget.items.length) {
      _haptic(HapticFeedback.lightImpact);
      widget.items[h].onSelected();
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_open, ..._itemCtl]),
        builder: (context, _) {
          final o = _open.value.clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45 * 0.9 * o),
                ),
              ),
              for (var i = 0; i < _targets.length; i++)
                () {
                  final m = _itemCtl[i].value;
                  final t = m.clamp(0.0, 1.1);
                  final p = Offset.lerp(_center, _targets[i], t)!;
                  final scale =
                      m.clamp(0.0, 1.3) * (_hover == i ? 1.16 : 1);
                  return Positioned(
                    left: p.dx - 32,
                    top: p.dy - 28,
                    width: 64,
                    child: Opacity(
                      opacity: (m * 1.4).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF26313D)
                                    : Colors.white,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    blurRadius: 20,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.items[i].icon,
                                size: 24,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.items[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0x80000000),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedBuilder(
      animation: _press,
      builder: (context, child) =>
          Transform.scale(scale: _press.value, child: child),
      child: widget.child,
    );
    // Выключенное меню — тот же RawGestureDetector без жестов: смена типа
    // обёртки пересоздавала аватар (видео, рамку) при прокрутке профиля.
    if (!widget.enabled) {
      return RawGestureDetector(
        gestures: const <Type, GestureRecognizerFactory>{},
        child: child,
      );
    }
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 380),
              ),
              (r) => r
                ..onLongPressStart = ((_) {
                  _show();
                })
                ..onLongPressMoveUpdate = ((d) {
                  _move(d.globalPosition);
                })
                ..onLongPressEnd = ((_) {
                  _close(commit: true);
                })
                ..onLongPressCancel = () {
                  if (_entry != null) _close(commit: false);
                },
            ),
      },
      child: child,
    );
  }
}
