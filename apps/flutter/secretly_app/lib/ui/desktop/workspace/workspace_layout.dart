// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import '../../../l10n/app_localizations.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../primitives/context_menu.dart';
import '../primitives/hover_listener.dart';
import 'settings_kit.dart';
import 'settings_style.dart';

/// Inline two-pane workspace used for Settings, Profile, etc. NOT a modal.
/// Left: sections list. Right: content for the active section.
///
/// 🔴 ВИД — ПО МАКЕТУ ВЛАДЕЛЬЦА «НАСТРОЙКИ ВНЕШНЕГО ВИДА» (29.09.2026).
/// Серая гамма ([SettingsPalette]), колонка разделов на тон темнее страницы,
/// строки без плиток — голый значок и подпись. Одно отступление от макета
/// сделано по слову владельца: значки ВСЕ цветные, каждый своим цветом
/// раздела, а не серые с цветным выбранным.
class WorkspaceLayout extends StatefulWidget {
  const WorkspaceLayout({
    super.key,
    required this.title,
    required this.sections,
    this.initialIndex = 0,
    this.footer,
    this.sidebarWidth = 232,
    this.onClose,
    this.trailing,
    this.contentMaxWidth,
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

  /// Наибольшая ширина СОДЕРЖИМОГО. `null` — во всю ширину области.
  ///
  /// 🔴 БЕЗ НЕЁ НАСТРОЙКИ РАЗВАЛИВАЮТСЯ НА ПОЛНОМ ЭКРАНЕ. Область содержимого
  /// занимала всё, что осталось от боковой колонки: на мониторе 3440 точек это
  /// строка настройки шириной больше трёх тысяч — подпись прижата к левому
  /// краю, переключатель к правому, между ними метр пустоты. Глаз перестаёт
  /// связывать одно с другим, и страница выглядит не «просторной», а
  /// недоделанной.
  ///
  /// Так же поступают и Telegram, и Discord, и системные настройки macOS:
  /// колонка содержимого имеет предел и стоит по центру области, а не
  /// растягивается. Предел применяется И К ШАПКЕ раздела, иначе её заголовок
  /// уезжал бы влево от карточек, которые он называет. Раздел может задать
  /// свой предел ([WorkspaceSection.contentMaxWidth]) — «Внешнему виду» нужна
  /// ещё колонка предпросмотра.
  final double? contentMaxWidth;

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
    this.trailing,
    this.tint,
    this.contentMaxWidth,
    this.ownHeader = false,
  });
  final String id;
  final IconData icon;
  final String label;
  final String? subtitle;
  final WidgetBuilder builder;
  final bool dangerous;

  /// Цвет значка раздела — второе имя раздела.
  ///
  /// 🔴 ЗАЧЕМ ЦВЕТ, ЕСЛИ ЕСТЬ ПОДПИСЬ. Разделов семнадцать, и в одноцветном
  /// списке они отличаются только текстом: чтобы найти «Уведомления», список
  /// приходится ЧИТАТЬ сверху вниз. С телефона человек уже помнит, что
  /// уведомления красные, а устройства голубые, и находит строку, не читая.
  /// Поэтому числа взяты с телефона ([DIconTint]), а не подобраны заново.
  ///
  /// `null` — значок цвета подписи: так выглядят разделы окон-воркспейсов, у
  /// которых своей палитры нет.
  final Color? tint;

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

  /// Значок справа в строке раздела.
  ///
  /// 🔴 ЗАЧЕМ. Поддержка отвечает не сразу, и ответ приходит в раздел, который
  /// человек закрыл час назад. Без отметки о нём узнают случайно — то есть
  /// никогда. Телефон её показывает, компьютер молчал.
  final Widget? trailing;

  /// Свой предел ширины колонки; `null` — общий [WorkspaceLayout.contentMaxWidth].
  final double? contentMaxWidth;

  /// Раздел рисует шапку сам ([WorkspaceContentHeader]) — «Внешнему виду»
  /// справа от содержимого нужна колонка предпросмотра во всю высоту, а шапка
  /// должна стоять только над настройками, как в макете.
  final bool ownHeader;

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

  /// Узел, через который окно слушает клавиши. Свой, а не безымянный: Esc в
  /// поле раздела возвращает фокус сюда — после простого `unfocus()` фокус
  /// ушёл бы выше этого узла, и окно перестало бы слышать клавиши совсем.
  final FocusNode _keysFocus = FocusNode(debugLabel: 'WorkspaceLayout.keys');

  @override
  void dispose() {
    _search.dispose();
    _keysFocus.dispose();
    super.dispose();
  }

  /// Фокус в поле ввода раздела — не в поиске по разделам.
  ///
  /// 🔴 КЛАВИШИ В ПОЛЕ — ПОЛЮ (30.09.2026). Обработчик окна стоит выше любого
  /// поля и слышит нажатие раньше правки текста: ↑/↓ в «Поддержке»
  /// переключали раздел, и набранное письмо пропадало вместе с панелью. Поиск
  /// — исключение: из него стрелки по-прежнему ходят по найденным разделам.
  bool _typingInPaneField() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    final inField = ctx.widget is EditableText ||
        ctx.findAncestorStateOfType<EditableTextState>() != null;
    return inField &&
        ctx.findAncestorWidgetOfExactType<_SidebarSearch>() == null;
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
      // Первый Esc в поле раздела только выводит из поля, окно закрывает
      // второй: иначе набранное пропадало вместе с окном.
      if (_typingInPaneField()) {
        _keysFocus.requestFocus();
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
    if (_typingInPaneField()) return KeyEventResult.ignored;

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
  Widget _buildSectionList(SettingsPalette p) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _visibleIndices;
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(DSpace.l),
        child: Text(
          l10n.desktopListNothingFound,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: DType.family,
            fontSize: 13,
            color: p.faint,
          ),
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
        // Макет: 11/700 капсом, разрядка .04em, третьим тоном; поля 12 8 4 8.
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Text(
            g.toUpperCase(),
            style: TextStyle(
              fontFamily: DType.family,
              fontSize: 11,
              height: 14 / 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.44,
              color: p.faint,
            ),
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
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      children: rows,
    );
  }

  /// Колонка содержимого: шире предела не растёт, по центру области.
  ///
  /// Полоса прокрутки при этом остаётся ВНУТРИ колонки, у самого её края, а не
  /// улетает к краю окна за пустым полем: полоса — часть того, что ты
  /// листаешь, и на ультрашироком мониторе тянуться к ней через полметра
  /// пустоты было бы хуже, чем не иметь её вовсе.
  Widget _constrain(Widget child, double? max) {
    if (max == null) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }

  Widget _buildSearch(SettingsPalette p, AppLocalizations l10n) {
    // Макет: поле 32 высотой, самый тёмный тон, скругление 6, без рамки;
    // значок лупы 18 третьим тоном. Рамка появляется только в фокусе — иначе
    // не видно, куда уходят нажатия клавиш.
    return _SidebarSearch(
      controller: _search,
      hint: l10n.desktopSettingsSearchHint,
      clearLabel: l10n.clear,
      palette: p,
      onChanged: _applyQuery,
      onClear: () {
        _search.clear();
        _applyQuery('');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final p = SettingsScope.paletteOf(context);
    final section = widget.sections[_index];
    final maxWidth = section.contentMaxWidth ?? widget.contentMaxWidth;
    // Полоса прокрутки — та же, что в ленте переписки (`chat_thread_panel`):
    // 6 точек, скругление 3, приглушённый ползунок. Задаётся темой, а не
    // обёрткой вокруг каждого списка: списков внутри настроек больше десятка
    // (разделы, устройства, переписка с поддержкой), и обернуть каждый значит
    // однажды забыть — и получить в одном окне две разные полосы.
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thickness: const WidgetStatePropertyAll<double>(6),
          radius: const Radius.circular(3),
          // Ползунок ТАЩАТ мышью — ради этого он на компьютере и нужен.
          interactive: true,
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.dragged)) {
              return p.muted.withValues(alpha: 0.85);
            }
            if (states.contains(WidgetState.hovered)) {
              return p.faint.withValues(alpha: 0.75);
            }
            return p.faint.withValues(alpha: 0.40);
          }),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: c.accentPrimary,
          selectionColor: c.accentPrimary.withValues(alpha: 0.32),
        ),
      ),
      child: Focus(
      focusNode: _keysFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
      color: p.main,
      child: Row(
        children: [
          // Sections sidebar
          Container(
            width: widget.sidebarWidth,
            decoration: BoxDecoration(
              color: p.side,
              border: Border(right: BorderSide(color: p.ter)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: DType.family,
                            fontSize: 17,
                            height: 22 / 17,
                            fontWeight: FontWeight.w700,
                            color: p.head,
                          ),
                        ),
                      ),
                      if (widget.onClose != null)
                        Semantics(
                          button: true,
                          label: l10n.close,
                          excludeSemantics: true,
                          child: HoverListener(
                            onTap: widget.onClose,
                            builder: (ctx, h, _) => AnimatedContainer(
                              duration: DMotion.fast,
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: h ? p.hover : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: h ? p.head : p.faint,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: _buildSearch(p, l10n),
                ),
                Expanded(child: _buildSectionList(p)),
                if (widget.footer != null)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: p.border)),
                    ),
                    child: widget.footer!,
                  ),
              ],
            ),
          ),
          // Content pane
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Шапка стоит над прокруткой (в макете она «липкая»): при
                // долгом списке человек всегда видит, в каком он разделе, и
                // вкладки раздела остаются под рукой. ТЕКСТ шапки живёт в той
                // же колонке, что и содержимое ниже, — иначе заголовок стоял
                // бы у левого края, а названная им карточка посередине.
                if (!section.ownHeader)
                WorkspaceContentHeader(
                  title: section.label,
                  subtitle: section.subtitle,
                  icon: section.icon,
                  tint: section.dangerous ? p.danger : section.tint,
                  trailing: widget.trailing,
                  maxWidth: maxWidth,
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
                      key: ValueKey(section.id),
                      child: _constrain(section.builder(context), maxWidth),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }
}

/// Поле поиска боковой колонки — по макету.
class _SidebarSearch extends StatefulWidget {
  const _SidebarSearch({
    required this.controller,
    required this.hint,
    required this.clearLabel,
    required this.palette,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final String clearLabel;
  final SettingsPalette palette;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_SidebarSearch> createState() => _SidebarSearchState();
}

class _SidebarSearchState extends State<_SidebarSearch> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted && _focused != _focus.hasFocus) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final accent = DColors.of(context).accentPrimary;
    final hasText = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: DMotion.fast,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: p.ter,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _focused ? accent.withValues(alpha: 0.7) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.search_24_regular, size: 18, color: p.faint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: (v) {
                widget.onChanged(v);
                setState(() {});
              },
              style: TextStyle(
                fontFamily: DType.family,
                fontSize: 13,
                color: p.head,
              ),
              cursorColor: accent,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontFamily: DType.family,
                  fontSize: 13,
                  color: p.faint,
                ),
              ),
            ),
          ),
          if (hasText)
            Semantics(
              button: true,
              label: widget.clearLabel,
              child: GestureDetector(
                onTap: () {
                  widget.onClear();
                  setState(() {});
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(
                    FluentIcons.dismiss_circle_24_regular,
                    size: 15,
                    color: p.faint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Значок раздела: в боковой колонке — голый цветной знак, в шапке — плитка.
///
/// 🔴 ВЛАДЕЛЕЦ (29.09.2026): колонка — «в тех же цветах и стиле, что в
/// макете, только чтобы иконки были сразу все цветные». Макет рисует строку
/// без плитки: знак 19 и подпись. Плитка осталась там, где она работает как
/// «ты здесь», — в шапке открытого раздела, крупной (36, скругление 10).
class WorkspaceIconPlate extends StatelessWidget {
  const WorkspaceIconPlate({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 19,
    this.selected = false,
    this.plain = true,
  });

  final IconData icon;

  /// `null` — знак цвета подписи.
  final Color? tint;

  /// Сторона: у голого знака — размер знака, у плитки — плитки.
  final double size;

  /// Выбранный раздел: знак на ступень ярче.
  final bool selected;

  /// Голый знак (строка колонки) или плитка (шапка).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final tint = this.tint;
    if (plain) {
      return Icon(
        icon,
        size: size,
        color: tint == null
            ? (selected ? p.head : p.muted)
            : p.glyph(tint, selected: selected),
      );
    }
    final glyph = tint == null ? p.muted : p.glyph(tint, selected: true);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint == null ? p.sel : p.tile(tint),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(child: Icon(icon, size: size * 0.58, color: glyph)),
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
    final p = SettingsScope.paletteOf(context);
    // Имя строке даёт сама подпись: метка здесь прозвучала бы дважды.
    return Semantics(
      button: true,
      selected: active,
      child: HoverListener(
        onTap: onTap,
        cursor: SystemMouseCursors.click,
        builder: (ctx, h, _) {
          // Макет: поля 7 8, скругление 6, выбранная строка — светлый тон и
          // подпись 600, наведённая — тон наведения.
          final fg = section.dangerous
              ? p.danger
              : (active || h ? p.head : p.muted);
          return AnimatedContainer(
            duration: DMotion.fast,
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: active ? p.sel : (h ? p.hover : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                WorkspaceIconPlate(
                  icon: section.icon,
                  tint: section.dangerous ? p.danger : section.tint,
                  selected: active,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: 14,
                      height: 1.3,
                      color: fg,
                      // Макет даёт невыбранным 500; этого веса в окне нет
                      // (см. `DType.label`) — ближайший спокойный 400.
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (section.trailing != null) ...[
                  const SizedBox(width: DSpace.xs),
                  section.trailing!,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Шапка раздела: плитка со знаком, заголовок, пояснение, справа — действия,
/// снизу — вкладки или черта. Раздел со своей шапкой ([WorkspaceSection.ownHeader])
/// рисует её сам — этим же виджетом.
class WorkspaceContentHeader extends StatelessWidget {
  const WorkspaceContentHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.tint,
    this.trailing,
    this.bottom,
    this.maxWidth,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? tint;
  final Widget? trailing;
  final Widget? bottom;
  final double? maxWidth;
  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Тот же знак и тот же цвет, что в боковой колонке. Это не
        // украшение: человек щёлкнул по строке слева и должен УВИДЕТЬ, что
        // попал туда, куда целился, — одинаковый цвет отвечает на это
        // быстрее, чем совпадение подписей.
        if (icon != null) ...[
          WorkspaceIconPlate(icon: icon!, tint: tint, size: 36, plain: false),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: DType.family,
                  fontSize: 19,
                  height: 24 / 19,
                  fontWeight: FontWeight.w700,
                  color: p.head,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DType.family,
                    fontSize: 13,
                    height: 1.35,
                    color: p.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
    // Поля 32 лежат ВНУТРИ ограниченной колонки, а не снаружи её: снаружи
    // они сдвигали бы шапку относительно содержимого, и заголовок раздела
    // вставал бы левее карточки, которую называет. Черта под шапкой — тоже
    // в колонке, как в макете: от поля до поля, а не от края до края окна.
    final column = Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          if (bottom != null) ...[
            const SizedBox(height: 16),
            bottom!,
          ] else
            Container(
              height: 16,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.border)),
              ),
            ),
        ],
      ),
    );
    return ColoredBox(
      color: p.main,
      child: maxWidth == null
          ? column
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth!),
                child: column,
              ),
            ),
    );
  }
}

/// Раздел страницы настроек: заголовок капсом, пояснение, под ними — карточка
/// со строками. Разделы отделены чертой, как в макете.
class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({
    super.key,
    this.title,
    this.description,
    required this.child,
    this.padding,
    this.framed = true,
    this.rows = true,
    this.titleTrailing,
  });
  final String? title;
  final String? description;
  final Widget child;

  /// Поля внутри карточки; `null` — подобрать по содержимому
  /// ([_innerPadding]). [EdgeInsets.zero] — вплотную: так передают строку,
  /// собранную своим виджетом, — она несёт поля сама.
  final EdgeInsets? padding;

  /// Карточка под содержимым. Сетки выбора (обои, цвета) лежат прямо на
  /// странице, как в макете, — им подложка не нужна.
  final bool framed;

  /// Справа от заголовка — текущий выбор.
  final Widget? titleTrailing;

  /// В карточке — строки настроек, и между ними нужны черты.
  ///
  /// 🔴 `false` — свободное содержимое: поле ввода, кнопки, текст (30.09.2026).
  /// Черты ставились между ЛЮБЫМИ детьми столбца, а поля карточка давала
  /// только тому, что не столбец: у «О программе», «Удалить аккаунт» и
  /// «Поддержки» текст и поле ввода прилипали к краям рамки, а отступы между
  /// ними превращались в перечёркнутые полосы.
  final bool rows;

  /// Inserts hairline dividers between the rows of a [Column] child.
  ///
  /// Only touches a direct Column of two or more children — anything else (a
  /// grid, a single control, custom layout) is passed through untouched, so
  /// this cannot quietly restructure a pane that wanted its own arrangement.
  Widget _withDividers(SettingsPalette p, Widget child) {
    if (!rows || child is! Column || child.children.length < 2) return child;
    final out = <Widget>[];
    for (var i = 0; i < child.children.length; i++) {
      if (i > 0) {
        out.add(Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          color: p.border.withValues(alpha: p.dark ? 0.7 : 1),
        ));
      }
      out.add(child.children[i]);
    }
    return Column(
      crossAxisAlignment: child.crossAxisAlignment,
      mainAxisSize: child.mainAxisSize,
      children: out,
    );
  }

  /// Поля внутри карточки. Строки ([WorkspaceRow]) и их столбцы несут свои
  /// поля сами; всё прочее (строка со значком и текстом, полоса, код) раньше
  /// прилипало к краям рамки — теперь получает поля макета.
  EdgeInsets _innerPadding() {
    if (padding != null) return padding!;
    if (!rows) return const EdgeInsets.all(14);
    if (child is WorkspaceRow || child is Column) return EdgeInsets.zero;
    if (child is SizedBox) return EdgeInsets.zero;
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
  }

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final hasHeading = title != null || description != null;
    final body = framed
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: p.card,
              // Hairlines are inserted here rather than by every pane, so a
              // group of rows is separated consistently and adding a row never
              // means remembering to add a divider.
              child: Padding(
                padding: _innerPadding(),
                child: _withDividers(p, child),
              ),
            ),
          )
        : Padding(padding: padding ?? EdgeInsets.zero, child: child);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            SettingsSectionTitle(title!, trailing: titleTrailing),
          if (description != null) ...[
            const SizedBox(height: 4),
            SettingsDescription(description!),
          ],
          if (hasHeading) const SizedBox(height: 12),
          body,
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
    final p = SettingsScope.paletteOf(context);
    // 🔴 Название строки уходит ВГЛУБЬ. Переключатель стоит в `trailing`, то
    // есть его собирает вызывающий, а не строка, — дотянуться до него правкой
    // здесь нельзя. Передавать подпись в каждом из двадцати восьми мест
    // значило бы двадцать восемь поводов забыть; унаследованное значение
    // забыть нельзя, и новые строки получают подпись даром.
    return _WorkspaceRowLabel(
      label: label,
      child: HoverListener(
      onTap: onTap,
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (ctx, h, _) {
        return AnimatedContainer(
          duration: DMotion.fast,
          // Rows own their insets and sit flush inside the card, so a group
          // reads as one surface with hairlines rather than as loose tiles.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: h && onTap != null ? p.hover : Colors.transparent,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: dangerous ? p.danger : p.muted),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: DType.family,
                        fontSize: 14,
                        height: 1.3,
                        // Как заголовок строки-карточки макета — 600.
                        fontWeight: FontWeight.w600,
                        color: dangerous ? p.danger : p.head,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: TextStyle(
                          fontFamily: DType.family,
                          fontSize: 12.5,
                          height: 1.35,
                          color: p.faint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        );
      },
      ),
    );
  }
}

/// Переключатель строки настроек.
///
/// 🔴 Своей отрисовки НЕТ — это [SettingsSwitch], то есть [DesktopSwitch] в
/// размере макета настроек (40×24). Две почти одинаковые копии расходились
/// бы; имя оставлено, чтобы не трогать полтора десятка строк настроек.
class WorkspaceSwitch extends StatelessWidget {
  const WorkspaceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SettingsSwitch(
    value: value,
    onChanged: onChanged,
    semanticsLabel: _WorkspaceRowLabel.of(context),
  );
}

/// Выбор из списка в строке настроек: текущее значение и шеврон, по щелчку —
/// меню ПК с галочкой у выбранного.
///
/// 🔴 Заменил телефонный `DropdownButton` (30.09.2026). Тот рисовал поле
/// высотой 48 (строки с ним были выше соседних на треть), открывал список в
/// виде Material — другая форма, другие тени, — и на светлой схеме серой гаммы
/// настроек подбирал цвета текста сам.
class WorkspaceSelect<T> extends StatelessWidget {
  const WorkspaceSelect({
    super.key,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labelOf;

  /// `null` — выбор недоступен: значение видно, меню не открывается.
  final ValueChanged<T>? onChanged;

  void _open(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset(0, box.size.height + 4));
    final pick = onChanged!;
    unawaited(
      ContextMenu.show(
        context,
        globalPosition: origin,
        width: box.size.width < 200 ? 200 : box.size.width,
        sections: [
          [
            for (final v in values)
              CtxMenuItem(
                label: labelOf(v),
                icon: v == value ? FluentIcons.checkmark_16_regular : null,
                onTap: v == value ? null : () => pick(v),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final enabled = onChanged != null;
    final label = labelOf(value);
    return Semantics(
      button: true,
      enabled: enabled,
      label: _WorkspaceRowLabel.of(context),
      value: label,
      excludeSemantics: true,
      child: HoverListener(
        onTap: enabled ? () => _open(context) : null,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (ctx, hovered, _) => AnimatedContainer(
          duration: DMotion.fast,
          height: 32,
          padding: const EdgeInsets.only(left: 12, right: 8),
          decoration: BoxDecoration(
            color: hovered && enabled ? p.hover : p.ter,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DType.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled ? p.head : p.faint,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                FluentIcons.chevron_down_16_regular,
                size: 14,
                color: enabled ? p.muted : p.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Название строки настройки — вглубь, для тех, кто внутри неё нарисован.
///
/// 🔴 Существует ради экранного диктора. Переключатель в строке — отдельный
/// предмет обхода, и своего имени у него нет: имя написано слева текстом,
/// который к нему никак не привязан. Отсюда переключатель берёт его сам.
class _WorkspaceRowLabel extends InheritedWidget {
  const _WorkspaceRowLabel({required this.label, required super.child});

  final String label;

  static String? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_WorkspaceRowLabel>()
      ?.label;

  @override
  bool updateShouldNotify(_WorkspaceRowLabel old) => old.label != label;
}
