// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Верхние острова главного экрана, v3: слева название приложения — нажатие
/// открывает меню (бывший «⋯»), шеврон поворачивается; справа «+» (что
/// создать — зависит от раздела) и «Контакты». Поиск переехал вниз.
///
/// Это только СОДЕРЖИМОЕ островков: сами стеклянные рамки и их превращение в
/// режим выделения остаются у `MorphingSelectionIslands` каждого раздела.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animations/dialog_transitions.dart';
import '../icons/app_icons.dart';
import '../motion/press_feedback.dart';
import '../widgets/apple_menu.dart';

/// Ширина правого островка с «+» и «Контакты».
const double kHomeTopActionsWidth = 100;

/// Ширина правого островка без «+» (раздел профиля).
const double kHomeTopActionsNarrowWidth = 56;

/// Пункт меню «+».
class HomePlusAction {
  const HomePlusAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Левый островок: название приложения + шеврон.
class HomeTitleIslandContent extends StatelessWidget {
  const HomeTitleIslandContent({
    super.key,
    required this.brand,
    required this.onTap,
    required this.menuOpen,
    required this.semanticLabel,
  });

  final Widget brand;
  final VoidCallback onTap;
  final bool menuOpen;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      expanded: menuOpen,
      label: semanticLabel,
      child: PressFeedback(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: brand),
              const SizedBox(width: 6),
              AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                turns: menuOpen ? 0.5 : 0,
                child: Icon(
                  AppIcons.chevronDown,
                  size: 14,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Правый островок: «+» и «Контакты».
class HomeTopActionsContent extends StatefulWidget {
  const HomeTopActionsContent({
    super.key,
    required this.plus,
    required this.contactsActive,
    required this.onContacts,
    required this.plusLabel,
    required this.contactsLabel,
  });

  /// Пусто — «+» нет (раздел профиля).
  final List<HomePlusAction> plus;
  final bool contactsActive;
  final VoidCallback onContacts;
  final String plusLabel;
  final String contactsLabel;

  @override
  State<HomeTopActionsContent> createState() => _HomeTopActionsContentState();
}

class _HomeTopActionsContentState extends State<HomeTopActionsContent> {
  bool _plusOpen = false;

  Future<void> _openPlus() async {
    HapticFeedback.selectionClick();
    setState(() => _plusOpen = true);
    final picked = await showFrostedPopup<int>(
      context: context,
      alignment: Alignment.topRight,
      builder: (context) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 58,
                right: 10,
                child: FrostedPopupContainer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 220,
                      maxWidth: 260,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < widget.plus.length; i++)
                          AppMenuRow(
                            title: widget.plus[i].label,
                            icon: widget.plus[i].icon,
                            onTap: () => Navigator.of(context).pop(i),
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
    if (!mounted) return;
    setState(() => _plusOpen = false);
    if (picked != null && picked >= 0 && picked < widget.plus.length) {
      widget.plus[picked].onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;
    Widget button({
      required String label,
      required Widget icon,
      required VoidCallback onTap,
      bool active = false,
    }) {
      return Semantics(
        button: true,
        selected: active,
        label: label,
        child: PressFeedback(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 44,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active
                    ? onSurface.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: icon,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.plus.isNotEmpty)
          button(
            label: widget.plusLabel,
            active: _plusOpen,
            onTap: _openPlus,
            icon: AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              turns: _plusOpen ? 0.125 : 0,
              child: Icon(AppIcons.add, size: 26, color: cs.primary),
            ),
          ),
        button(
          label: widget.contactsLabel,
          active: widget.contactsActive,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onContacts();
          },
          icon: Icon(
            widget.contactsActive
                ? AppIcons.contactsFilled
                : AppIcons.contacts,
            size: 22,
            color: widget.contactsActive ? cs.primary : onSurface,
          ),
        ),
      ],
    );
  }
}

/// Название раздела в отдельном островке посередине шапки (21.11, решение
/// владельца): между названием приложения и «+».
///
/// Занимает только свободное место между боковыми островками. Длинное
/// название («Discussions», «Kontakte») не вылезает: надпись плавно
/// уменьшается целиком; на совсем узком месте (крупный шрифт на маленьком
/// экране) островок не показывается вовсе, а не мнётся.
class HomeSectionIsland extends StatelessWidget {
  const HomeSectionIsland({
    super.key,
    required this.title,
    required this.island,
  });

  final String title;

  /// Рамка островка той же формы, что у соседних (стекло/матовое).
  final Widget Function(Widget child) island;

  /// Меньше этого места — островка нет.
  static const double minWidth = 64;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < minWidth) return const SizedBox.shrink();
        // Текст не крупнее 1,3 от обычного: островок фиксированной высоты.
        final scaler = MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 1.3);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: c.maxWidth),
            child: Semantics(
              header: true,
              label: title,
              excludeSemantics: true,
              child: island(
                // По центру по высоте; не помещается — плавно уменьшается
                // целиком (без многоточия и обрезки).
                Align(
                  widthFactor: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      textScaler: scaler,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
