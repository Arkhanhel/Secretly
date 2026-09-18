// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../primitives/hover_listener.dart';
import '../primitives/desktop_tooltip.dart';
import '../design/tokens.dart';
import 'details_panel.dart';
import 'pane_widths.dart';
import 'shortcuts_help.dart';
import 'resizable_divider.dart';
import 'sidebar.dart';
import 'dnd_button.dart';
import 'window_chrome.dart';
import '../services/desktop_nav_history.dart';

/// Top-level desktop layout. Holds sidebar + (optional list pane) + content + details.
///
/// This is the structural shell only — actual section content (Chats / Rooms /
/// Calls / Contacts) is provided by callers via [contentBuilder] keyed by
/// [DesktopSection]. The shell owns: section state, details panel open/close,
/// keyboard shortcuts, and window chrome.
class DesktopShell extends StatefulWidget {
  const DesktopShell({
    super.key,
    required this.contentBuilder,
    this.detailsBuilder,
    this.detailsWidth = 330,
    this.initialSection = DesktopSection.chats,
    this.unreadByTab = const <DesktopSection, int>{},
    this.sidebarBuilder,
    this.breadcrumbsBuilder,
    this.connectionStatus = ConnectionStatus.connected,
    this.onOpenSettings,
    this.onOpenProfile,
    this.onOpenSpotlight,
    this.navHistory,
    this.onNavigateHistory,
    this.windowTitle = 'Secretly',
    this.activeCallBar,
  });

  final Widget Function(
    BuildContext,
    DesktopSection section,
    DesktopShellApi api,
  )
  contentBuilder;
  final Widget Function(
    BuildContext,
    DesktopSection section,
    DesktopShellApi api,
  )?
  detailsBuilder;

  /// Width of the right-side details panel when open. The panel animates
  /// width 0 ↔ this value via [DetailsPanel].
  final double detailsWidth;
  final DesktopSection initialSection;
  final Map<DesktopSection, int> unreadByTab;

  /// Своя рейка вместо стандартной.
  ///
  /// 🔴 Оболочка намеренно не знает ни о переписках, ни о счётчиках: она
  /// раздаёт место и разделы. Живые данные рейке нужны (непрочитанное,
  /// закреплённые комнаты), но подписываться за неё должна не оболочка — иначе
  /// тик контроллера перерисовывал бы всё окно. Поэтому тот, у кого есть шов к
  /// приложению, собирает рейку сам, а оболочка отдаёт ей раздел и обработчик
  /// переключения.
  final Widget Function(
    BuildContext ctx,
    DesktopSection active,
    ValueChanged<DesktopSection> onSelect,
  )?
  sidebarBuilder;

  /// 🔴 Полоса идущего созвона — НАД ВСЕМ окном, а не внутри одной комнаты.
  ///
  /// Стоит между шапкой окна и содержимым, поэтому видна в любом разделе: в
  /// другом чате, в контактах, в настройках. Раньше о идущем разговоре
  /// напоминала только плашка внутри своей комнаты, и, уйдя из неё, человек
  /// терял дорогу назад. `null` — полосы нет вовсе.
  final Widget? activeCallBar;

  /// Хлебные крошки для шапки окна. Строит их тот, кто знает выбранный чат и
  /// открытую тему, — оболочка про них не знает и знать не должна.
  final Widget? Function(BuildContext ctx, DesktopSection section)?
  breadcrumbsBuilder;
  final ConnectionStatus connectionStatus;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSpotlight;

  /// История открытых переписок для стрелок в шапке. `null` — стрелок нет
  /// вовсе (например, в тестах, где шапка строится отдельно).
  final DesktopNavHistory? navHistory;

  /// Применить шаг по истории. Сам шаг делает [DesktopNavHistory]; здесь —
  /// только «открой вот это»: переключить раздел и выбрать переписку умеет
  /// приложение, а не оболочка.
  final void Function(DesktopNavEntry entry)? onNavigateHistory;
  final String windowTitle;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class DesktopShellApi {
  const DesktopShellApi({
    required this.detailsOpen,
    required this.toggleDetails,
    required this.openDetails,
    required this.closeDetails,
    required this.selectSection,
    required this.listWidth,
    required this.onListResize,
    this.onListReset,
    this.onListResizeStart,
    this.onListResizeEnd,
    this.listCompact = false,
    this.onListExpand,
    required this.findRequests,
    required this.chatCycle,
  });

  final bool detailsOpen;
  final VoidCallback toggleDetails;
  final VoidCallback openDetails;
  final VoidCallback closeDetails;
  final ValueChanged<DesktopSection> selectSection;

  /// Width the chat list should use, and the drag handler for its edge. Owned
  /// by the shell so the width survives a section switch and is persisted in
  /// one place, rather than each section keeping its own idea of it.
  final double listWidth;
  final ValueChanged<double> onListResize;

  /// Двойной щелчок по краю списка — вернуть ширину по умолчанию.
  final VoidCallback? onListReset;

  /// Перетаскивание края списка началось / закончилось.
  final VoidCallback? onListResizeStart;
  final VoidCallback? onListResizeEnd;

  /// Список свёрнут в столбик портретов (как в телеграме). [listWidth] при
  /// этом — ширина столбика.
  final bool listCompact;

  /// Развернуть свёрнутый список — например, нажатием на лупу в его шапке.
  final VoidCallback? onListExpand;

  /// Ticks once per Cmd+F. The open conversation listens and opens its search.
  final ValueListenable<int> findRequests;

  /// Ticks by +1 / -1 as the user walks the chat list from the keyboard.
  final ValueListenable<int> chatCycle;
}

class _DesktopShellState extends State<DesktopShell> {
  late DesktopSection _section = widget.initialSection;
  bool _detailsOpen = false;


  // ── Resizable panes ────────────────────────────────────────────────
  //
  // Widths were fixed, which is a phone habit: on a wide display the chat
  // list is needlessly cramped for long room names, and on a small laptop it
  // steals width the conversation needs.
  //
  // 🔴 16.09.2026, по скриншотам телеграма от владельца: список тянется от
  // узкого до почти всего окна — у растянутого превью читается целиком, а не
  // обрывком. Потолка «на вкус» у списка больше нет (был 720): предел ставит
  // пол переписки. Нижний предел — 260: при портрете 50 уже́ список не
  // вмещает имя рядом со временем. Правая панель — от 260 до 720 (было 520).
  // Арифметика перетаскивания — в [dragListEdge] и [dragDetailsEdge].
  static const String _kListWidthKey = 'desktop_pane_list_w_v1';
  static const String _kDetailsWidthKey = 'desktop_pane_details_w_v1';
  static const String _kDetailsOpenKey = 'desktop_pane_details_open_v1';
  static const String _kListCompactKey = 'desktop_pane_list_compact_v1';
  static const double _minListW = 260;
  static const double _minDetailsW = 260;
  static const double _maxDetailsW = 720;

  /// Пол переписки: уже́ этого шапка с кнопками и поле ввода теснятся.
  static const double _threadFloor = 460;

  /// Ширины, которые колонки получили на ПОСЛЕДНЕЙ раскладке. Перетаскивание
  /// считает от них, а не от сохранённых: правая панель может сжимать список,
  /// и шаг, прибавленный к сохранённой ширине, край не двигал. Обновляются и
  /// в самом обработчике — несколько шагов мыши за один кадр иначе считались
  /// бы от одной и той же старой ширины.
  double _shownListW = 322;
  double _shownDetailsW = 330;
  double _available = 0;

  /// Всё, что стоит в ряду помимо самих колонок: рейка, шов «список |
  /// переписка» в точку и — при открытой панели — её ручка в восемь точек.
  /// Без них переписка уходила под свой пол ровно на их ширину.
  double get _fixedW => kRailWidth + 1 + (_detailsOpen ? 8 : 0);

  /// Incremented on every Cmd+F. The open conversation watches this and opens
  /// its search bar; the shell does not need to know which chat that is.
  final ValueNotifier<int> _findRequests = ValueNotifier<int>(0);

  /// Running total of chat-cycle steps. The chats section watches the DELTA
  /// between ticks, so a single notifier carries both direction and count.
  final ValueNotifier<int> _chatCycle = ValueNotifier<int>(0);

  double? _listWidth;

  /// Список свёрнут в столбик портретов. [_listWidth] при этом хранит ширину,
  /// до которой он развернётся.
  bool _listCompact = false;

  /// Где был бы край списка, если бы его ничто не держало, — на время одного
  /// перетаскивания. См. [listEdgeAt]: край меряется от курсора.
  double? _dragPointer;

  /// Ширина правой панели, которую ВЫБРАЛ человек, — её и сохраняем.
  late double _detailsWidth = widget.detailsWidth;

  /// Ширина, до которой панель ПОТЕСНИЛ растущий список, — временная.
  ///
  /// Сохранять её вместо выбранной нельзя: тогда, сузив список обратно,
  /// человек не получил бы панель прежней ширины — она так и осталась бы
  /// потеснённой. `null` — панель не потеснена.
  double? _detailsPushed;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreWidths());
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _findRequests.dispose();
    _chatCycle.dispose();
    super.dispose();
  }

  Future<void> _restoreWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getDouble(_kListWidthKey);
      final details = prefs.getDouble(_kDetailsWidthKey);
      final open = prefs.getBool(_kDetailsOpenKey) ?? false;
      final compact = prefs.getBool(_kListCompactKey) ?? false;
      if (!mounted) return;
      setState(() {
        // Колонку, оставленную открытой, возвращаем открытой — но только там,
        // где ей есть что показать.
        _detailsWanted = open;
        if (open && _sectionHasDetails(_section)) _detailsOpen = true;
        // Верхний предел ставит окно на каждой раскладке, здесь — только
        // нижний: сохранённая широкая колонка на узком окне ужмётся сама и
        // вернётся, когда окно растянут.
        if (list != null) _listWidth = list < _minListW ? _minListW : list;
        _listCompact = compact;
        if (details != null) {
          _detailsWidth = details.clamp(_minDetailsW, _maxDetailsW);
        }
      });
    } catch (_) {
      // Defaults already hold; a preferences failure must not block the shell.
    }
  }

  /// Debounced so a drag writes once when it settles, not once per frame.
  void _persistWidths() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = _listWidth;
        if (list != null) {
          await prefs.setDouble(_kListWidthKey, list);
        } else {
          await prefs.remove(_kListWidthKey);
        }
        await prefs.setDouble(_kDetailsWidthKey, _detailsWidth);
        await prefs.setBool(_kListCompactKey, _listCompact);
      } catch (_) {}
    });
  }

  void _selectSection(DesktopSection s) {
    if (s == _section) return;
    setState(() {
      _section = s;
      // 🔴 ПАНЕЛЬ НЕ ЗАХЛОПЫВАЕТСЯ ПРИ СМЕНЕ РАЗДЕЛА (15.09.2026).
      //
      // В макете (артборд 1c) справа ПОСТОЯННАЯ колонка участников, а у нас
      // выдвижной ящик, который закрывался на каждом переходе. Тот, кто держит
      // состав комнаты открытым, открывал его заново после каждого захода в
      // «Звонки» — то есть колонка вела себя ящиком не по замыслу, а по
      // недосмотру.
      //
      // Второго нативного окна и отдельной раскладки под 1c у нас нет, но
      // постоянство колонки достигается проще: панель остаётся там, где её
      // оставили. В разделах, где показывать нечего, она просто не рисуется —
      // признак при этом не теряется и вернётся вместе с чатами.
      // В разделе без панели её НЕТ, даже если человек хочет её видеть: там
      // она показала бы подробности чата, из которого он ушёл. Признак
      // `_detailsWanted` при этом сохраняется и вернёт колонку вместе с
      // чатами — именно он и делает её постоянной.
      _detailsOpen = _sectionHasDetails(s) && _detailsWanted;
    });
  }

  /// Хочет ли человек видеть правую колонку. Отличается от [_detailsOpen] тем,
  /// что переживает переход в раздел, где панели нет вовсе.
  bool _detailsWanted = false;

  /// Есть ли в этом разделе что показывать в правой панели.
  ///
  /// «Звонки» и «Контакты» своей панели подробностей не имеют: `detailsBuilder`
  /// отдаёт там ящик, привязанный к складу ЧАТОВ, то есть пустое состояние.
  /// Кнопка, открывающая пустоту, хуже погашенной.
  static bool _sectionHasDetails(DesktopSection s) =>
      s == DesktopSection.chats || s == DesktopSection.rooms;

  void _toggleDetails() {
    setState(() {
      _detailsPushed = null;
      _detailsOpen = !_detailsOpen;
      _detailsWanted = _detailsOpen;
    });
    unawaited(_persistDetailsOpen());
  }

  void _setDetails(bool v) {
    if (_detailsOpen == v) return;
    setState(() {
      _detailsPushed = null;
      _detailsOpen = v;
      _detailsWanted = v;
    });
    unawaited(_persistDetailsOpen());
  }

  void _dragList(double dx) {
    // Первый шаг жеста: запоминаем, откуда пошёл край, и ширину, к которой
    // список вернётся, если этим жестом его свернут.
    if (_dragPointer == null) {
      _dragPointer = _shownListW;
      _widthBeforeDrag = _listCompact ? _listWidth : _shownListW;
    }
    final pointer = _dragPointer! + dx;
    _dragPointer = pointer;
    final r = listEdgeAt(
      pointer: pointer,
      available: _available,
      rail: _fixedW,
      threadFloor: _threadFloor,
      minList: _minListW,
      desiredDetails: _detailsOpen ? _detailsWidth : null,
      minDetails: _minDetailsW,
      compactWidth: kCompactListWidth,
    );
    _shownListW = r.listWidth;
    setState(() {
      if (r.compact) {
        // Свернули: развернётся список к той ширине, что была ДО жеста, а не
        // к минимуму, через который курсор только что прошёл.
        if (!_listCompact) _listWidth = _widthBeforeDrag;
      } else {
        _listWidth = r.listWidth;
      }
      _listCompact = r.compact;
      final d = r.detailsWidth;
      if (d != null) {
        _detailsPushed = d < _detailsWidth ? d : null;
        _shownDetailsW = d;
      }
    });
    _persistWidths();
  }

  /// Ширина развёрнутого списка в начале текущего жеста.
  double? _widthBeforeDrag;

  /// Начало и конец жеста одинаково забывают прошлый: отсчёт от курсора
  /// начинается заново с первого шага.
  void _endListDrag() {
    _dragPointer = null;
    _widthBeforeDrag = null;
  }

  void _expandList() {
    if (!_listCompact) return;
    setState(() => _listCompact = false);
    _persistWidths();
  }

  void _dragDetails(double dx) {
    final d = dragDetailsEdge(
      dx: dx,
      shownDetails: _shownDetailsW,
      available: _available,
      rail: _fixedW,
      threadFloor: _threadFloor,
      minList: _listCompact ? kCompactListWidth : _minListW,
      minDetails: _minDetailsW,
      maxDetails: _maxDetailsW,
    );
    _shownDetailsW = d;
    setState(() {
      _detailsWidth = d;
      _detailsPushed = null;
    });
    _persistWidths();
  }

  void _resetList() {
    setState(() {
      _listWidth = null;
      _listCompact = false;
    });
    _persistWidths();
  }

  void _resetDetails() {
    setState(() {
      _detailsWidth = widget.detailsWidth;
      _detailsPushed = null;
    });
    _persistWidths();
  }

  Future<void> _persistDetailsOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDetailsOpenKey, _detailsWanted);
    } catch (_) {
      // Не сохранилось — панель просто откроется закрытой в следующий раз.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);

    // The ceiling has to answer to the window, not just to taste: on a narrow
    // laptop a 720px list would leave the conversation a gutter. Reserve room
    // for a readable thread and never let the drag cross it. Recomputed every
    // build so shrinking the window pulls an over-wide stored list back in
    // rather than stranding the thread off-screen.
    const double kThreadFloor = _threadFloor;
    final available = MediaQuery.sizeOf(context).width;
    // Рейку учитываем: раньше потолок считался от всего окна, и переписка
    // могла уйти под свой пол на ширину рейки.
    final ceiling = listCeiling(
      available: available,
      rail: _fixedW,
      threadFloor: kThreadFloor,
      minList: _minListW,
    );
    // · ШИРИНА ПАНЕЛИ СПИСКА ПО УМОЛЧАНИЮ — 322 (макет), а не 300.
    //
    // Двадцать две точки решают: именно на 300–320 в полосу фильтров не
    // влезал четвёртый чип, из-за чего подпись пришлось сократить до
    // «Непрочит.». Сохранённую человеком ширину это не трогает — она
    // приходит из `_listWidth`.
    final effectiveListW = _listCompact
        ? kCompactListWidth
        : (_listWidth ?? 322).clamp(_minListW, ceiling);

    // 🔴 Панель подробностей НЕ ложится поверх переписки: она выдвигается
    // своей колонкой, а место ей уступают соседи — сначала список чатов, потом
    // она сама, и только в последнюю очередь переписка. См.
    // [resolveDetailsLayout].
    final detailsLayout = _detailsOpen
        ? resolveDetailsLayout(
            available: available,
            // Рейка значков, шов и ручка панели — см. [_fixedW].
            sidebarWidth: _fixedW,
            desiredListWidth: effectiveListW,
            // Свёрнутый список ужимать некуда: он и так один столбик.
            minListWidth: _listCompact ? kCompactListWidth : _minListW,
            desiredDetailsWidth: _detailsPushed ?? _detailsWidth,
            minDetailsWidth: _minDetailsW,
            threadFloor: kThreadFloor,
          )
        : DetailsLayout(detailsWidth: _detailsWidth, listWidth: effectiveListW);
    _available = available;
    _shownListW = detailsLayout.listWidth;
    _shownDetailsW = detailsLayout.detailsWidth;

    final api = DesktopShellApi(
      detailsOpen: _detailsOpen,
      toggleDetails: _toggleDetails,
      openDetails: () => _setDetails(true),
      closeDetails: () => _setDetails(false),
      selectSection: _selectSection,
      listWidth: detailsLayout.listWidth,
      findRequests: _findRequests,
      chatCycle: _chatCycle,
      onListResize: _dragList,
      onListReset: _resetList,
      onListResizeStart: _endListDrag,
      onListResizeEnd: _endListDrag,
      listCompact: _listCompact,
      onListExpand: _expandList,
    );

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.digit1, meta: true): _SectionIntent(
          DesktopSection.chats,
        ),
        SingleActivator(LogicalKeyboardKey.digit1, control: true):
            _SectionIntent(DesktopSection.chats),
        SingleActivator(LogicalKeyboardKey.digit2, meta: true): _SectionIntent(
          DesktopSection.rooms,
        ),
        SingleActivator(LogicalKeyboardKey.digit2, control: true):
            _SectionIntent(DesktopSection.rooms),
        SingleActivator(LogicalKeyboardKey.digit3, meta: true): _SectionIntent(
          DesktopSection.calls,
        ),
        SingleActivator(LogicalKeyboardKey.digit3, control: true):
            _SectionIntent(DesktopSection.calls),
        SingleActivator(LogicalKeyboardKey.digit4, meta: true): _SectionIntent(
          DesktopSection.contacts,
        ),
        SingleActivator(LogicalKeyboardKey.digit4, control: true):
            _SectionIntent(DesktopSection.contacts),
        SingleActivator(LogicalKeyboardKey.comma, meta: true):
            _OpenSettingsIntent(),
        SingleActivator(LogicalKeyboardKey.comma, control: true):
            _OpenSettingsIntent(),
        // Cmd/Ctrl+F searches inside the open conversation. It existed only
        // as a header button, so the reflex every desktop user has produced
        // nothing.
        // Alt+Arrow walks the chat list. Plain arrows belong to whatever has
        // focus (the message list, a text field), so the modifier is what
        // makes this safe to bind globally — the same choice Slack makes.
        SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
            _CycleChatIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp, alt: true):
            _CycleChatIntent(-1),
        // Cmd+/ is the near-universal "what are the shortcuts" key.
        SingleActivator(LogicalKeyboardKey.slash, meta: true):
            _ShortcutsHelpIntent(),
        SingleActivator(LogicalKeyboardKey.slash, control: true):
            _ShortcutsHelpIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _FindInChatIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _FindInChatIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _OpenSpotlightIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenSpotlightIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SectionIntent: CallbackAction<_SectionIntent>(
            onInvoke: (intent) {
              _selectSection(intent.section);
              return null;
            },
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              widget.onOpenSettings?.call();
              return null;
            },
          ),
          _CycleChatIntent: CallbackAction<_CycleChatIntent>(
            onInvoke: (intent) {
              // Same counter trick as find: the value must CHANGE for
              // listeners to fire, so the direction rides in the sign and the
              // magnitude keeps growing.
              _chatCycle.value += intent.delta;
              return null;
            },
          ),
          _ShortcutsHelpIntent: CallbackAction<_ShortcutsHelpIntent>(
            onInvoke: (_) {
              showShortcutsHelp(context);
              return null;
            },
          ),
          _FindInChatIntent: CallbackAction<_FindInChatIntent>(
            onInvoke: (_) {
              // Bumped rather than set to true: a ValueNotifier suppresses a
              // no-op write, so a second Cmd+F would not re-open a search the
              // user had just closed.
              _findRequests.value++;
              return null;
            },
          ),
          _OpenSpotlightIntent: CallbackAction<_OpenSpotlightIntent>(
            onInvoke: (_) {
              widget.onOpenSpotlight?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: c.bg,
            body: Column(
              children: [
                _ChromeWithHistory(
                  history: widget.navHistory,
                  builder: (ctx, back, forward) => DesktopWindowChrome(
                    title: widget.windowTitle,
                    leading: widget.breadcrumbsBuilder?.call(ctx, _section),
                    center: widget.onOpenSpotlight == null
                        ? null
                        : WindowSearchEntry(onTap: widget.onOpenSpotlight!),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DesktopDndButton(),
                        const SizedBox(width: 2),
                        // 🔴 Переключатель правой панели в ШАПКЕ ОКНА — из
                        // макета. Он же есть в шапке переписки, и это не
                        // дубль: там он про выбранный чат, здесь — про окно.
                        // Состояние у обоих одно (`_detailsOpen`), поэтому
                        // разойтись им не на чем.
                        //
                        // В разделах, где правой панели нечего показывать,
                        // кнопка ГАСНЕТ, а не исчезает: пропадающая кнопка
                        // сдвигает соседнюю под курсор.
                        _DetailsToggleButton(
                          open: _detailsOpen,
                          onPressed: _sectionHasDetails(_section)
                              ? _toggleDetails
                              : null,
                        ),
                      ],
                    ),
                    navBack: back,
                    navForward: forward,
                  ),
                ),
                if (widget.activeCallBar != null) widget.activeCallBar!,
                Expanded(
                  child: Row(
                    children: [
                      if (widget.sidebarBuilder != null)
                        widget.sidebarBuilder!(
                          context,
                          _section,
                          _selectSection,
                        )
                      else
                        DesktopSidebar(
                          active: _section,
                          onSelect: _selectSection,
                          onOpenSettings: widget.onOpenSettings,
                          onOpenProfile: widget.onOpenProfile,
                          unreadByTab: widget.unreadByTab,
                          connectionStatus: widget.connectionStatus,
                        ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: DMotion.base,
                          switchInCurve: DMotion.easeOutCubic,
                          switchOutCurve: DMotion.easeInCubic,
                          transitionBuilder: (child, anim) {
                            return FadeTransition(opacity: anim, child: child);
                          },
                          child: KeyedSubtree(
                            key: ValueKey(_section),
                            child: widget.contentBuilder(
                              context,
                              _section,
                              api,
                            ),
                          ),
                        ),
                      ),
                      if (widget.detailsBuilder != null && _detailsOpen)
                        ResizableDivider(
                          // Dragging LEFT widens the details pane, so the
                          // delta is negated: the pane grows as its edge moves
                          // toward the middle of the window.
                          onDelta: _dragDetails,
                          onReset: _resetDetails,
                        ),
                      if (widget.detailsBuilder != null)
                        DetailsPanel(
                          open: _detailsOpen,
                          width: detailsLayout.detailsWidth,
                          child: widget.detailsBuilder!(context, _section, api),
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

class _FindInChatIntent extends Intent {
  const _FindInChatIntent();
}

/// Move the chat-list selection by [delta] (+1 = next, -1 = previous).
class _CycleChatIntent extends Intent {
  const _CycleChatIntent(this.delta);
  final int delta;
}

class _ShortcutsHelpIntent extends Intent {
  const _ShortcutsHelpIntent();
}

class _SectionIntent extends Intent {
  const _SectionIntent(this.section);
  final DesktopSection section;
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _OpenSpotlightIntent extends Intent {
  const _OpenSpotlightIntent();
}

/// Шапка окна, подписанная на историю переходов.
///
/// Отдельный виджет, потому что при шаге по истории перерисовать нужно ТОЛЬКО
/// шапку: оболочка целиком тянет за собой список и переписку, а меняются две
/// стрелки.
class _ChromeWithHistory extends StatelessWidget {
  const _ChromeWithHistory({required this.history, required this.builder});

  final DesktopNavHistory? history;
  final Widget Function(
    BuildContext ctx,
    VoidCallback? back,
    VoidCallback? forward,
  ) builder;

  @override
  Widget build(BuildContext context) {
    final h = history;
    if (h == null) return builder(context, null, null);
    return AnimatedBuilder(
      animation: h,
      builder: (ctx, _) => builder(
        ctx,
        h.canBack ? () => _step(ctx, h.back()) : null,
        h.canForward ? () => _step(ctx, h.forward()) : null,
      ),
    );
  }

  void _step(BuildContext ctx, DesktopNavEntry? entry) {
    if (entry == null) return;
    final state = ctx.findAncestorStateOfType<_DesktopShellState>();
    state?.widget.onNavigateHistory?.call(entry);
  }
}

/// Кнопка «правая панель» в шапке окна.
///
/// Включённое состояние залито, как в макете: панель открыта — кнопка видна
/// нажатой, и её не приходится искать глазами, чтобы понять, откуда взялась
/// третья колонка.
class _DetailsToggleButton extends StatelessWidget {
  const _DetailsToggleButton({required this.open, this.onPressed});

  final bool open;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final enabled = onPressed != null;
    final btn = HoverListener(
      onTap: onPressed,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: open
              ? Colors.white.withValues(alpha: 0.07)
              : (enabled && (hovered || pressed)
                    ? (pressed ? c.pressed : c.hover)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Icon(
            FluentIcons.panel_right_24_regular,
            size: 19,
            color: open ? c.textPrimary : c.textSecondary,
          ),
        ),
      ),
    );
    if (!enabled) return btn;
    return DesktopTooltip(
      message: open ? 'Скрыть панель' : 'Показать панель',
      child: btn,
    );
  }
}
