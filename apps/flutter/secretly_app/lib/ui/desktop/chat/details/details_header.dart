// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../design/tokens.dart';
import '../../primitives/context_menu.dart';
import '../../primitives/desktop_button.dart';

/// Sticky header of the details (third-column) drawer.
///
/// Layout: [×] close — title — [⋮] menu. The menu is opened via
/// [ContextMenu] anchored under the trigger button. Items are supplied
/// by the caller so contact vs room can each declare their own set.
class DetailsHeader extends StatelessWidget {
  const DetailsHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.menuSections,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  /// Sections of menu items. Empty list -> menu button is hidden.
  final List<List<CtxMenuItem>> menuSections;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final menuKey = GlobalKey();
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: DSpace.s),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: [
          DesktopIconButton(
            icon: FluentIcons.dismiss_24_regular,
            tooltip: 'Скрыть',
            onPressed: onClose,
          ),
          const SizedBox(width: DSpace.xs),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DType.bodyStrong.copyWith(color: c.textPrimary),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.caption.copyWith(color: c.textSecondary),
                  ),
              ],
            ),
          ),
          if (menuSections.isNotEmpty)
            KeyedSubtree(
              key: menuKey,
              child: DesktopIconButton(
                icon: FluentIcons.more_vertical_24_regular,
                tooltip: 'Дополнительно',
                onPressed: () => _openMenu(context, menuKey),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openMenu(BuildContext context, GlobalKey anchor) async {
    final rb = anchor.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final origin = rb.localToGlobal(Offset.zero);
    // Anchor: bottom-right of trigger, then ContextMenu auto-clamps to screen.
    final pos = origin.translate(rb.size.width, rb.size.height + 4);
    await ContextMenu.show(
      context,
      globalPosition: pos,
      sections: menuSections,
    );
  }
}
