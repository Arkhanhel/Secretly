// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../primitives/desktop_switch.dart';
import '../primitives/desktop_text_field.dart';
import '../primitives/hover_listener.dart';

/// Inline two-pane workspace used for Settings, Profile, etc. NOT a modal.
/// Left: sections list. Right: content for the active section.
class WorkspaceLayout extends StatefulWidget {
  const WorkspaceLayout({
    super.key,
    required this.title,
    required this.sections,
    this.initialIndex = 0,
    this.footer,
    this.sidebarWidth = 238,
    this.onClose,
    this.trailing,
  });

  final String title;
  final List<WorkspaceSection> sections;
  final int initialIndex;

  /// Строка, прижатая к низу боковой колонки.
  ///
  /// 🔴 В макете единственный выход из аккаунта — красный пункт «Выйти»,
  /// прижатый к низу. Слот сделан общим, потому что «внизу и отдельно» — это
  /// про важность действия, а не про настройки: любое окно-воркспейс может
  /// иметь такое действие, и рисовать его каждому по-своему значит получить
  /// три разных «Выйти».
  final Widget? footer;
  final double sidebarWidth;
  final VoidCallback? onClose;
  final Widget? trailing;

  @override
  State<WorkspaceLayout> createState() => _WorkspaceLayoutState();
}

class WorkspaceSection {
  const WorkspaceSection({
    required this.id,
    required this.icon,
    required this.label,
    required this.builder,
    this.subtitle,
    this.dangerous = false,
    this.group,
    this.keywords = const <String>[],
  });
  final String id;
  final IconData icon;
  final String label;
  final String? subtitle;
  final WidgetBuilder builder;
  final bool dangerous;

  /// Heading this section sits under in the sidebar. Sections sharing a group
  /// are rendered together under one quiet label; null keeps a section
  /// ungrouped at the top.
  final String? group;

  /// Extra words this section should match when searching — the names of the
  /// individual settings inside it.
  ///
  /// Search is what makes a seventeen-section page usable: people look for
  /// «пароль» or «автозагрузка», not for the section that happens to contain
  /// them. Without keywords they would have to already know the structure,
  /// which is exactly what they are searching to avoid.
  final List<String> keywords;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (label.toLowerCase().contains(q)) return true;
    if ((subtitle ?? '').toLowerCase().contains(q)) return true;
    if ((group ?? '').toLowerCase().contains(q)) return true;
    for (final k in keywords) {
      if (k.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

class _WorkspaceLayoutState extends State<WorkspaceLayout> {
  late int _index = widget.initialIndex;

  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Sections surviving the current query, in declaration order.
  List<int> get _visibleIndices => [
        for (var i = 0; i < widget.sections.length; i++)
          if (widget.sections[i].matches(_query)) i,
      ];

  void _applyQuery(String v) {
    setState(() {
      _query = v.trim();
      // Keep the pane in step with the filter: if the active section was
      // filtered away, jump to the first surviving one so the right-hand pane
      // never shows something the sidebar no longer lists.
      final visible = _visibleIndices;
      if (visible.isNotEmpty && !visible.contains(_index)) {
        _index = visible.first;
      }
    });
  }

  /// Arrow keys walk the sidebar, Escape clears the search then closes.
  /// Keyboard is how anyone actually navigates a settings window on a desktop.
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final visible = _visibleIndices;
    if (visible.isEmpty) return KeyEventResult.ignored;

    if (e.logicalKey == LogicalKeyboardKey.escape) {
      if (_query.isNotEmpty) {
        _search.clear();
        _applyQuery('');
        return KeyEventResult.handled;
      }
      if (widget.onClose != null) {
        widget.onClose!();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    final up = e.logicalKey == LogicalKeyboardKey.arrowUp;
    if (!down && !up) return KeyEventResult.ignored;

    final pos = visible.indexOf(_index);
    final next = pos < 0
        ? 0
        : (down
            ? (pos + 1).clamp(0, visible.length - 1)
            : (pos - 1).clamp(0, visible.length - 1));
    setState(() => _index = visible[next]);
    return KeyEventResult.handled;
  }

  /// Sidebar list: quiet group headings over the section rows, and an honest
  /// empty state when a search matches nothing.
  Widget _buildSectionList(DColorSet c) {
    final visible = _visibleIndices;
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(DSpace.l),
        child: Text(
          'Ничего не найдено',
          textAlign: TextAlign.center,
          style: DType.caption.copyWith(color: c.textSecondary),
        ),
      );
    }
    // 🔴 РАЗДЕЛЫ СОБИРАЮТСЯ ПО ГРУППАМ, А НЕ ПО ПОРЯДКУ ОБЪЯВЛЕНИЯ.
    //
    // Заголовок рисовался всякий раз, когда группа отличалась от предыдущей, —
    // и стоило одному разделу оказаться в списке не среди своих, как в панели
    // появлялись «ПРИВАТНОСТЬ И БЕЗОПАСНОСТЬ» дважды и «АККАУНТ И ДАННЫЕ»
    // дважды. Человек читает это как два разных раздела с одинаковым именем.
    //
    // Порядок САМИХ ГРУПП — по первому появлению: он задан объявлением и
    // осмыслен (сначала приложение, потом приватность, потом аккаунт).
    // Порядок внутри группы тоже сохраняется. Сортировки по алфавиту здесь
    // быть не должно: «Удалить аккаунт» обязан остаться последним.
    final order = <String>[];
    final byGroup = <String, List<int>>{};
    for (final i in visible) {
      final g = widget.sections[i].group ?? '';
      if (!byGroup.containsKey(g)) {
        byGroup[g] = <int>[];
        order.add(g);
      }
      byGroup[g]!.add(i);
    }
    final rows = <Widget>[];
    for (final g in order) {
      if (g.isNotEmpty) {
        rows.add(Padding(
          padding: EdgeInsets.fromLTRB(
            DSpace.m,
            rows.isEmpty ? DSpace.xs : DSpace.m,
            DSpace.m,
            DSpace.xs,
          ),
          child: Text(
            g.toUpperCase(),
            style: DType.meta.copyWith(color: c.textDisabled),
          ),
        ));
      }
      for (final i in byGroup[g]!) {
        rows.add(_SectionRow(
          section: widget.sections[i],
          active: _index == i,
          onTap: () => setState(() => _index = i),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: DSpace.s),
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
      color: c.bg,
      child: Row(
        children: [
          // Sections sidebar
          Container(
            width: widget.sidebarWidth,
            color: c.chatList,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(DSpace.l, DSpace.l, DSpace.l, DSpace.s),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: DType.title.copyWith(color: c.textPrimary),
                        ),
                      ),
                      if (widget.onClose != null)
                        HoverListener(
                          onTap: widget.onClose,
                          builder: (ctx, h, p) => Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: h ? c.hover : Colors.transparent,
                              borderRadius: BorderRadius.circular(DRadii.sm),
                            ),
                            child: Icon(Icons.close_rounded, size: 16, color: c.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      DSpace.m, 0, DSpace.m, DSpace.s),
                  child: DesktopTextField(
                    controller: _search,
                    // «Найти настройку» из макета: глагол называет, что
                    // случится, а «Поиск настроек» — только раздел, в котором
                    // человек и так стоит.
                    hintText: 'Найти настройку',
                    prefixIcon: FluentIcons.search_24_regular,
                    suffixIcon: _query.isEmpty
                        ? null
                        : GestureDetector(
                            onTap: () {
                              _search.clear();
                              _applyQuery('');
                            },
                            child: Icon(
                              FluentIcons.dismiss_circle_24_regular,
                              size: 15,
                              color: c.textSecondary,
                            ),
                          ),
                    onChanged: _applyQuery,
                  ),
                ),
                Expanded(child: _buildSectionList(c)),
                if (widget.footer != null) ...[
                  Container(height: 1, color: c.borderSubtle),
                  widget.footer!,
                ],
              ],
            ),
          ),
          // Vertical divider
          Container(width: 1, color: c.borderSubtle),
          // Content pane
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ContentHeader(
                  title: widget.sections[_index].label,
                  subtitle: widget.sections[_index].subtitle,
                  trailing: widget.trailing,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: DMotion.base,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: anim, curve: DMotion.easeOutCubic)),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(widget.sections[_index].id),
                      child: widget.sections[_index].builder(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section, required this.active, required this.onTap});
  final WorkspaceSection section;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final fg = section.dangerous
        ? c.danger
        : (active ? c.textPrimary : c.textSecondary);
    return HoverListener(
      onTap: onTap,
      builder: (ctx, h, p) {
        return AnimatedContainer(
          duration: DMotion.fast,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: DSpace.s, vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.selected : (h ? c.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(DRadii.sm),
          ),
          child: Row(
            children: [
              Icon(section.icon, size: 18, color: fg),
              const SizedBox(width: DSpace.s),
              Expanded(
                child: Text(
                  section.label,
                  style: DType.label.copyWith(
                    color: fg,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(DSpace.xl, DSpace.l, DSpace.xl, DSpace.m),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: DType.title.copyWith(color: c.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: DType.label.copyWith(color: c.textSecondary)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Standard content section card with title + child. Used inside workspace
/// content panes for consistent grouping.
class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({
    super.key,
    this.title,
    this.description,
    required this.child,
    this.padding = EdgeInsets.zero,
  });
  final String? title;
  final String? description;
  final Widget child;
  final EdgeInsets padding;

  /// Inserts hairline dividers between the rows of a [Column] child.
  ///
  /// Only touches a direct Column of two or more children — anything else (a
  /// grid, a single control, custom layout) is passed through untouched, so
  /// this cannot quietly restructure a pane that wanted its own arrangement.
  Widget _withDividers(DColorSet c, Widget child) {
    if (child is! Column || child.children.length < 2) return child;
    final out = <Widget>[];
    for (var i = 0; i < child.children.length; i++) {
      if (i > 0) {
        out.add(Container(height: 1, color: c.borderSubtle.withValues(alpha: 0.6)));
      }
      out.add(child.children[i]);
    }
    return Column(
      crossAxisAlignment: child.crossAxisAlignment,
      mainAxisSize: child.mainAxisSize,
      children: out,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    // Heading OUTSIDE the container, controls inside it.
    //
    // The old card wrapped title, description and controls in one bordered
    // box, so a pane with six settings drew six heavy boxes and the page read
    // as a stack of containers rather than a list of choices. Lifting the text
    // out leaves exactly one bordered surface per group — the controls — and
    // lets the headings form a quiet vertical rhythm down the page.
    final hasHeading = title != null || description != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: DSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeading)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: DSpace.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    // · ЗАГОЛОВОК КАРТОЧКИ — МИКРО-ЯРЛЫК КАПСОМ (макет:
                    // «РАМКА АВАТАРА», «АКЦЕНТ ИНТЕРФЕЙСА», «УСТРОЙСТВА · 3»).
                    //
                    // Он набирался тем же 14-м, что и подписи настроек внутри
                    // карточки, только жирнее — и на странице из шести групп
                    // заголовки не отличались от содержимого ничем, кроме
                    // веса. Моноширинный капс отделяет их сменой шрифта, а не
                    // размером: ровно тот же приём, что у заголовков групп в
                    // боковом списке рядом.
                    Text(
                      title!.toUpperCase(),
                      style: DType.meta.copyWith(color: c.textTertiary),
                    ),
                  if (description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      description!,
                      style: DType.label
                          .copyWith(color: c.textSecondary, height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(DRadii.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.chatList,
                border: Border.all(color: c.borderSubtle),
                borderRadius: BorderRadius.circular(DRadii.md),
              ),
              // Hairlines are inserted here rather than by every pane, so a
              // group of rows is separated consistently and adding a row never
              // means remembering to add a divider.
              child: Padding(padding: padding, child: _withDividers(c, child)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row inside a workspace card. Label on the left, control on the right.
class WorkspaceRow extends StatelessWidget {
  const WorkspaceRow({
    super.key,
    required this.label,
    this.description,
    this.icon,
    this.trailing,
    this.onTap,
    this.dangerous = false,
  });
  final String label;
  final String? description;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dangerous;
  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (ctx, h, p) {
        return AnimatedContainer(
          duration: DMotion.fast,
          // Rows own their insets and sit flush inside the card, so a group
          // reads as one surface with hairlines rather than as loose tiles.
          padding: const EdgeInsets.symmetric(
              horizontal: DSpace.l, vertical: DSpace.m),
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: h && onTap != null ? c.hover : Colors.transparent,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: dangerous ? c.danger : c.textSecondary),
                const SizedBox(width: DSpace.m),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: DType.body.copyWith(
                        color: dangerous ? c.danger : c.textPrimary,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(description!, style: DType.label.copyWith(color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: DSpace.m),
                trailing!,
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Переключатель строки настроек.
///
/// 🔴 Своей отрисовки БОЛЬШЕ НЕТ — это [DesktopSwitch]. Здесь жила почти такая
/// же копия (36×22, белый кружок, радиус-таблетка), и две почти одинаковые
/// копии расходились: в панели подробностей стоял материальный переключатель
/// вдвое крупнее, а здесь — свой. Имя оставлено, чтобы не трогать полтора
/// десятка строк настроек.
class WorkspaceSwitch extends StatelessWidget {
  const WorkspaceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) =>
      DesktopSwitch(value: value, onChanged: onChanged);
}
