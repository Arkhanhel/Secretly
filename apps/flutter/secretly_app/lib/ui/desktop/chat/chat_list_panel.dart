// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../widgets/avatar_initials.dart';
import '../primitives/verified_badge.dart';
import 'room_call_banner.dart' show formatParticipantsRu;
import '../../../app/message_command_utils.dart' show RoomTopicRef;
import '../../room_topic_marks.dart';
import '../design/tokens.dart';
import 'message_bubble.dart' show DeliveryStatus, deliveryTickGlyph;
import '../primitives/avatar.dart';
import '../primitives/context_menu.dart';
import '../primitives/desktop_text_field.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';
import 'chat_category_bar.dart';

export 'chat_category_bar.dart' show ChatCategory, ChatCategoryIds;

enum ChatKind { direct, group, channel }

/// Цвет счётчика непрочитанного по ТИПУ разговора.
///
/// 🔴 Красный — личная переписка, синий — комната, фиолетовый — канал
/// (14.09.2026, указание владельца по макету). Живёт здесь, рядом с самим
/// типом, чтобы у рейки, списка и ленты не завелось три разных мнения о том,
/// какого цвета непрочитанное.
Color unreadColorFor(ChatKind kind, DColorSet c) {
  switch (kind) {
    case ChatKind.direct:
      return c.unreadDot;
    case ChatKind.group:
      return c.unreadRoom;
    case ChatKind.channel:
      return c.unreadChannel;
  }
}

/// Заливка ВЫБРАННОЙ строки списка: цвет окна, притемнённый ровно настолько,
/// чтобы белый текст на нём читался.
///
/// 🔴 16.09.2026 выбранная строка стала сплошной заливкой с белым текстом,
/// как в телеграме. Но цвет окна выбирает человек, и у светлых пресетов
/// (сиреневый #AF89FB) белый текст на нём давал контраст 2,7 : 1 — имя чата
/// едва читалось. У телеграма заливка тоже темнее его акцента.
///
/// Оттенок сохраняется: цвет только затемняется, шагами, до контраста с белым
/// не ниже 4,5 : 1 (порог WCAG для обычного текста). Достаточно тёмный цвет
/// возвращается как есть.
Color selectedChatRowFill(Color accent) {
  final hit = _selectedFillCache[accent.toARGB32()];
  if (hit != null) return hit;
  var fill = accent;
  for (var step = 0; step <= 12; step++) {
    fill = Color.lerp(accent, const Color(0xFF000000), step * 0.05)!;
    if (1.05 / (fill.computeLuminance() + 0.05) >= 4.5) break;
  }
  return _selectedFillCache[accent.toARGB32()] = fill;
}

final Map<int, Color> _selectedFillCache = <int, Color>{};

/// Чем было последнее сообщение — для значка в строке превью.
///
/// 🔴 Свой перечень, а не общий `ChatListPreviewKind`. Список чатов — тупой
/// рисовальщик: он не должен тянуть за собой контроллер со всей моделью
/// приложения ради одного значка. Секция переводит одно в другое в одном месте
/// и там же решает, что показывать.
enum ChatPreviewIcon { none, photo, video, music, voice, file, link, call }

/// Знак доставки СВОЕГО последнего сообщения в строке списка.
///
/// 🔴 Свой перечень, а не `DeliveryStatus` переписки. Строке списка нужно
/// ровно три состояния: «ушло», «дошло», «прочитано»; «отправляется»,
/// «по расписанию» и «не ушло» в строке показывать нечего — о них человек
/// узнаёт внутри чата, где может что-то сделать. [none] — последнее сообщение
/// не своё, знака нет вовсе.
enum ChatDelivery { none, sent, delivered, read }

class ChatListItem {
  const ChatListItem({
    required this.id,
    required this.name,
    required this.preview,
    required this.time,
    this.unread = 0,
    this.kind = ChatKind.direct,
    this.online = false,
    this.muted = false,
    this.verified = false,
    this.pinned = false,
    this.archived = false,
    this.typing = false,
    this.draft = false,
    this.draftText,
    this.previewAuthor,
    this.previewAuthorSeed,
    this.mention = false,
    this.avatarPath,
    this.seed,
    this.frameId,
    this.emojiStatus,
    this.premiumBadge = false,
    this.previewIcon = ChatPreviewIcon.none,
    this.previewIsMine = false,
    this.delivery = ChatDelivery.none,
    this.timestampMs = 0,
    this.roomCall,
  });

  /// Значок перед текстом превью: вложение, голосовое, ссылка.
  final ChatPreviewIcon previewIcon;

  /// Последнее сообщение — своё.
  ///
  /// 🔴 Считается на стороне десктопа сравнением `senderDeviceId` превью со
  /// своим устройством. Общая с телефоном функция подписи автора для личной
  /// переписки честно возвращает `null`, и править её ради «Вы:» в чужом окне
  /// значит тронуть код, который работает у тысяч людей. Данных хватает и без
  /// этого.
  final bool previewIsMine;

  /// Дошло ли своё последнее сообщение. В макете этот знак стоит справа во
  /// второй строке — там же, где счётчик непрочитанного, и никогда вместе с
  /// ним: непрочитанное означает, что последнее сообщение НЕ своё.
  final ChatDelivery delivery;

  final String id;

  /// Устойчивый ключ для оттенка заглушки — `peerProfileId` у человека,
  /// `convoId` у комнаты. Тот же, по которому считает телефон: иначе один
  /// собеседник выходил бы на двух устройствах разного цвета, а
  /// переименование меняло бы оттенок только на компьютере.
  final String? seed;
  final String name;
  final String preview;
  final String time;

  /// Время последнего события — по нему список делится на «Сегодня»,
  /// «Вчера» и так далее. Подпись [time] для этого не годится: она уже
  /// отформатирована и по ней нельзя отличить «вчера» от «позавчера».
  final int timestampMs;

  /// Идёт ли в комнате созвон и сколько человек внутри.
  ///
  /// 🔴 В макете это стоит В СТРОКЕ СПИСКА («Обсуждение · 3 участника» со
  /// значком-эквалайзером), и по делу: созвон видно только войдя в комнату, а
  /// узнать о нём надо из списка — иначе о разговоре узнаёшь, когда он кончился.
  final RoomCallHint? roomCall;
  final int unread;
  final ChatKind kind;
  final bool online;
  final bool muted;
  final bool verified;
  final bool pinned;
  final bool archived;
  final bool typing;
  final bool draft;

  /// Текст черновика — его и показывает строка после «Черновик:».
  ///
  /// 🔴 Найдено 16.09.2026 при живой проверке: строка знала только, ЧТО
  /// черновик есть, и после «Черновик:» ставила последнее сообщение. Чужая
  /// фраза «I see it, all there» читалась как недописанное своё. В телеграме
  /// после этой подписи стоит сам черновик.
  final String? draftText;
  final String? previewAuthor;

  /// Ключ цвета автора превью — устройство отправителя, как у телефона
  /// (`nicknameColor(seed: preview.senderDeviceId)` в списке чатов) и как у
  /// имени в пузыре. Один человек — один цвет везде.
  final String? previewAuthorSeed;
  final bool mention;

  /// Local file path of the conversation's avatar photo (peer/group), or null
  /// → the Avatar widget falls back to initials.
  final String? avatarPath;

  /// Peer premium cosmetics (rendered regardless of the local user's tier):
  /// animated avatar frame id, emoji status next to the name, and the premium
  /// star badge.
  final String? frameId;
  final String? emojiStatus;
  final bool premiumBadge;
}

class ChatListPanel extends StatefulWidget {
  const ChatListPanel({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.onArchive,
    this.onMute,
    this.onPin,
    this.onDelete,
    this.onMarkRead,
    this.onClear,
    this.width = 300,
    this.categories = const <ChatCategory>[],
    this.selectedCategoryId = ChatCategoryIds.all,
    this.onSelectCategory,
    this.onCategoryContextMenu,
    this.emptyCategoryText,
    this.footer,
    this.extraChatActions,
    this.onDropOnChat,
    this.topics = const <RoomTopicRef>[],
    this.baseTopicMark = '',
    this.currentTopicId,
    this.topicUnread = const <String, int>{},
    this.onSelectTopic,
    this.title = 'Чаты',
    this.onCompose,
    this.onFilters,
    this.compact = false,
    this.onExpand,
  });

  /// 🔴 СВЁРНУТЫЙ СПИСОК — СТОЛБИК ПОРТРЕТОВ, КАК В ТЕЛЕГРАМЕ (указание
  /// владельца 16.09.2026).
  ///
  /// Край списка тянут влево дальше минимума — и вместо узкой панели, где имя
  /// уже не читается, остаётся столбик портретов со счётчиками. Имя и
  /// последнее сообщение показывает подсказка при наведении; правый щелчок и
  /// перетаскивание файла на портрет работают, как на обычной строке.
  ///
  /// Поля поиска и полосы папок в столбике нет: лупа в шапке разворачивает
  /// список и ставит курсор в поиск.
  final bool compact;

  /// Развернуть свёрнутый список. `null` — лупы в свёрнутой шапке нет.
  final VoidCallback? onExpand;

  /// ◆ ВЕТКИ ОТКРЫТОЙ КОМНАТЫ — ПРЯМО ПОД ЕЁ СТРОКОЙ (указание владельца
  /// 15.09.2026).
  ///
  /// До сих пор единственным местом выбора ветки была полоса в шапке
  /// переписки, и это было решением: раньше ветки дублировались в двух местах
  /// сразу. Владелец просит вернуть их в список — но ТОЛЬКО у открытой
  /// комнаты, а не у всех подряд, как было прежде. Так они не спорят с полосой
  /// и не растягивают список чужими ветками.
  final List<RoomTopicRef> topics;

  /// Знак «Основы». Пусто — решётка.
  final String baseTopicMark;

  final String? currentTopicId;
  final Map<String, int> topicUnread;
  final ValueChanged<String?>? onSelectTopic;

  /// Заголовок панели: «Чаты» или «Комнаты».
  final String title;

  /// Меню создания (чат / комната). `null` — кнопки нет.
  ///
  /// 🔴 Кнопка без действия хуже её отсутствия: человек нажимает, ничего не
  /// происходит, и дальше он не верит остальным кнопкам тоже. Поэтому
  /// отсутствие обработчика убирает саму кнопку, а не делает её серой.
  final void Function(Offset globalPosition)? onCompose;

  /// Меню папок. `null` — кнопки нет, по той же причине.
  final void Function(Offset globalPosition)? onFilters;

  // ── ТЕМ ЗДЕСЬ БОЛЬШЕ НЕТ (14.09.2026) ────────────────────────────────────
  //
  // 🔴 Панель раскрывала темы открытой комнаты подстроками — «Общий» и все
  // темы следом. Ровно те же темы в тот же момент показывала полоса в шапке
  // переписки (`RoomTopicsStrip`), с теми же счётчиками и тем же выбором.
  // Один выбор в двух местах окна: человек нажимал в одном, а подсветка
  // менялась в обоих, и было непонятно, какое из них главное.
  //
  // В макете у открытой комнаты в списке НЕТ НИ ОДНОЙ подстроки: темы живут
  // только полосой в шапке. Сведений человек не теряет — счётчики
  // непрочитанного по темам показывает та же полоса.
  //
  // Управление темами (создать, переименовать) осталось в правой панели.

  /// Files dropped onto a specific chat row. Null disables the affordance
  /// entirely, so a caller that cannot send shows no drop highlight either.
  final Future<void> Function(String convoId, List<String> paths)? onDropOnChat;

  /// Extra sections appended to a chat row's right-click menu — folder
  /// membership, personal, archive. Supplied by the host because only it
  /// knows the folder model; the panel stays a dumb renderer.
  final List<List<CtxMenuItem>> Function(String convoId)? extraChatActions;

  /// Horizontal categories shown above the list. Empty hides the strip
  /// entirely, which is what the Rooms tab wants.
  final List<ChatCategory> categories;
  final String selectedCategoryId;
  final ValueChanged<String>? onSelectCategory;
  final void Function(ChatCategory category, Offset globalPosition)?
  onCategoryContextMenu;

  /// Shown when the ACTIVE CATEGORY is empty but a search is not in play —
  /// "no archived chats" reads very differently from "no chats at all".
  final String? emptyCategoryText;

  /// Подвал панели — состояние связи и вход в архив.
  ///
  /// Слотом, а не готовым виджетом: панель списка ничего не знает ни про
  /// синхронизацию, ни про архив, и знать не должна. Кто знает — тот и
  /// собирает. `null` — подвала нет вовсе (тесты, снимки).
  final Widget? footer;

  final List<ChatListItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String>? onArchive;
  final ValueChanged<String>? onMute;
  final ValueChanged<String>? onPin;
  final ValueChanged<String>? onDelete;
  final ValueChanged<String>? onMarkRead;
  final ValueChanged<String>? onClear;
  final double width;

  @override
  State<ChatListPanel> createState() => _ChatListPanelState();
}

/// Подписи разделов. Вынесены в постоянные: заголовок одновременно и
/// показывается, и служит признаком раздела при выборе значка — сравнение
/// литералом в двух местах разъехалось бы при первой правке текста.
const String _kPinnedHeader = 'ЗАКРЕПЛЁННЫЕ';

/// Подпись поиска: у поля и у лупы свёрнутого списка — одна.
const String _kSearchHint = 'Поиск';

/// Подпись раздела по времени последнего события.
///
/// 🔴 Было одно «ВСЕ ЧАТЫ» на всё. В макете владельца список делится по
/// дням — и это не украшение: человек, у которого тридцать переписок, ищет
/// глазами не «все», а «то, что было сегодня». Заголовок отвечает на это
/// сразу, без чтения времени в каждой строке.
String _dateHeaderFor(int timestampMs, DateTime now) {
  if (timestampMs <= 0) return 'РАНЬШЕ';
  final at = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'СЕГОДНЯ';
  if (diff == 1) return 'ВЧЕРА';
  if (diff < 7) return 'НА ЭТОЙ НЕДЕЛЕ';
  return 'РАНЬШЕ';
}

/// Идёт ли в комнате созвон — для строки списка.
class RoomCallHint {
  const RoomCallHint({required this.participants});

  /// Сколько человек ВНУТРИ созвона (не в комнате).
  final int participants;
}

/// Одна позиция ленты: либо заголовок раздела, либо чат.
///
/// Нужна, чтобы разделы не сломали ЛЕНИВУЮ отрисовку. Разложить список на две
/// секции было бы проще, но тогда обе строились бы целиком на каждой
/// перерисовке — а в категории бывают сотни чатов, и именно от этого список
/// когда-то и перевели на builder.
class _ListEntry {
  const _ListEntry.header(this.header)
    : item = null,
      topic = null,
      isBaseTopic = false;
  const _ListEntry.chat(this.item)
    : header = null,
      topic = null,
      isBaseTopic = false;

  /// Ветка открытой комнаты. `topic == null && isBaseTopic` — «Основа».
  const _ListEntry.topic(this.topic)
    : header = null,
      item = null,
      isBaseTopic = false;
  const _ListEntry.baseTopic()
    : header = null,
      item = null,
      topic = null,
      isBaseTopic = true;

  final String? header;
  final ChatListItem? item;
  final RoomTopicRef? topic;
  final bool isBaseTopic;

  bool get isTopicRow => topic != null || isBaseTopic;
}

class _ChatListPanelState extends State<ChatListPanel> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  /// Список развернули лупой — поставить курсор в поиск, как только поле
  /// появится.
  bool _focusSearch = false;

  void _expandForSearch() {
    _focusSearch = true;
    widget.onExpand?.call();
  }

  @override
  void didUpdateWidget(covariant ChatListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Свернули иначе, чем лупой, — просьба о курсоре больше не в силе.
    if (widget.compact && !oldWidget.compact) _focusSearch = false;
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<ChatListItem> _filter(List<ChatListItem> src) {
    if (_query.isEmpty) return src;
    final q = _query.toLowerCase();
    return src
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.preview.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Pinned chats float to the top of whatever category is showing, keeping
  /// their relative order. This is the one grouping worth keeping inline —
  /// it is an ordering rule, not a category, and it applies within every view.
  List<ChatListItem> _pinnedFirst(List<ChatListItem> src) {
    final pinned = <ChatListItem>[];
    final rest = <ChatListItem>[];
    for (final i in src) {
      (i.pinned ? pinned : rest).add(i);
    }
    return [...pinned, ...rest];
  }

  /// Раскладывает список на «Закреплённые» и «Все чаты».
  ///
  /// Заголовки появляются ТОЛЬКО когда есть что разделять: если закреплённых
  /// нет, подпись «Все чаты» над единственной секцией ничего не сообщает и лишь
  /// съедает строку. При поиске заголовков тоже нет — там результат один и
  /// делить его не на что.
  List<_ListEntry> _withSectionHeaders(List<ChatListItem> visible) {
    if (visible.isEmpty) return const <_ListEntry>[];
    // При поиске разделов нет: результат один, делить его не на что.
    if (_query.isNotEmpty) {
      return [for (final i in visible) _ListEntry.chat(i)];
    }
    final now = DateTime.now();
    final out = <_ListEntry>[];
    final pinnedCount = visible.where((i) => i.pinned).length;
    if (pinnedCount > 0) {
      out.add(const _ListEntry.header(_kPinnedHeader));
      for (final i in visible.take(pinnedCount)) {
        out.add(_ListEntry.chat(i));
        _appendTopics(out, i);
      }
    }
    String? lastHeader;
    for (final i in visible.skip(pinnedCount)) {
      final header = _dateHeaderFor(i.timestampMs, now);
      if (header != lastHeader) {
        lastHeader = header;
        out.add(_ListEntry.header(header));
      }
      out.add(_ListEntry.chat(i));
      _appendTopics(out, i);
    }
    // Единственный раздел без закреплённых подписывать незачем: подпись над
    // всем списком ничего не сообщает и лишь съедает строку.
    if (pinnedCount == 0 && out.isNotEmpty && out.first.header != null) {
      final headers = out.where((e) => e.header != null).length;
      if (headers == 1) out.removeAt(0);
    }
    return out;
  }

  /// Ветки открытой комнаты — сразу под её строкой.
  ///
  /// Только у ОТКРЫТОЙ: у всех подряд это растянуло бы список чужими ветками
  /// и повторило бы то, из-за чего подстроки однажды убрали.
  void _appendTopics(List<_ListEntry> out, ChatListItem item) {
    if (widget.topics.isEmpty) return;
    if (item.id != widget.selectedId) return;
    if (widget.onSelectTopic == null) return;
    out.add(const _ListEntry.baseTopic());
    for (final t in widget.topics) {
      out.add(_ListEntry.topic(t));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (widget.compact) return _buildCompact(c);
    final visible = _pinnedFirst(_filter(widget.items));
    final entries = _withSectionHeaders(visible);
    if (_focusSearch) {
      // Курсор ставим сами: `autofocus` поля тут не сработал бы — фокус в
      // окне уже держит оболочка, а он уступает место только пустому.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusSearch) return;
        _focusSearch = false;
        _searchFocus.requestFocus();
      });
    }

    final body = Container(
      width: widget.width,
      color: c.chatList,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: widget.title,
            onCompose: widget.onCompose,
            onFilters: widget.onFilters,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DSpace.m, 0, DSpace.m, DSpace.s),
            child: DesktopTextField(
              // Развернули лупой — курсор сразу в поле, как в телеграме.
              focusNode: _searchFocus,
              controller: _search,
              hintText: _kSearchHint,
              prefixIcon: FluentIcons.search_24_regular,
              suffixIcon: _query.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () {
                        setState(() => _query = '');
                        _search.clear();
                      },
                      child: Icon(
                        FluentIcons.dismiss_circle_24_regular,
                        size: 16,
                        color: c.textSecondary,
                      ),
                    ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // Categories sit directly under the search field: a filter belongs
          // next to the other filter, not inside the results.
          if (widget.categories.isNotEmpty) ...[
            ChatCategoryBar(
              categories: widget.categories,
              selectedId: widget.selectedCategoryId,
              onSelect: widget.onSelectCategory ?? (_) {},
              onContextMenu: widget.onCategoryContextMenu,
            ),
            const SizedBox(height: DSpace.xs),
          ],
          Container(height: 1, color: c.borderSubtle),
          Expanded(
            // 🔴 ЗАТЕНЕНИЕ У НИЖНЕГО КРАЯ СПИСКА — ИЗ МАКЕТА.
            //
            // Без него последняя видимая строка обрывается ровной чертой:
            // список выглядит закончившимся там, где он продолжается.
            // Шестьдесят точек плавного перехода в цвет панели говорят «ниже
            // ещё есть» без полосы прокрутки и без единой подписи.
            //
            // Лежит ВНУТРИ области списка, а не поверх всей панели: иначе оно
            // затеняло бы и подвал с состоянием связи, который под ним.
            // Сквозное для мыши — иначе нижние строки перестали бы нажиматься.
            child: Stack(
              children: [
                Positioned.fill(child: _list(c, visible, entries)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 60,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            c.chatList.withValues(alpha: 0),
                            c.chatList,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.footer != null) widget.footer!,
        ],
      ),
    );

    return body;
  }

  /// Свёрнутый вид — см. [ChatListPanel.compact].
  Widget _buildCompact(DColorSet c) {
    // Поиска в столбике не видно — значит, он и не действует: иначе список
    // оставался бы отфильтрованным по слову, которого человек не видит.
    final visible = _pinnedFirst(widget.items);
    final pinnedCount = visible.where((i) => i.pinned).length;
    return Container(
      width: widget.width,
      color: c.chatList,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompactHeader(
            onSearch: widget.onExpand == null ? null : _expandForSearch,
            onFilters: widget.onFilters,
            onCompose: widget.onCompose,
          ),
          Container(height: 1, color: c.borderSubtle),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: DSpace.p5,
                vertical: DSpace.xs,
              ),
              itemCount: visible.length,
              itemBuilder: (ctx, i) {
                final item = visible[i];
                final row = _CompactChatRow(
                  item: item,
                  selected: item.id == widget.selectedId,
                  // Вместо заголовков разделов — одна черта между
                  // закреплёнными и остальными.
                  dividerAbove: pinnedCount > 0 && i == pinnedCount,
                  onTap: () => widget.onSelect(item.id),
                  onMore: () => _moreSections(item),
                );
                final onDrop = widget.onDropOnChat;
                if (onDrop == null) return row;
                return _RowDropTarget(
                  onDrop: (paths) => onDrop(item.id, paths),
                  child: row,
                );
              },
            ),
          ),
          if (widget.footer != null) widget.footer!,
        ],
      ),
    );
  }

  /// Сам список — вынесен из [build], чтобы затенение снизу не пришлось
  /// заворачивать вокруг двухсот строк разметки.
  Widget _list(
    DColorSet c,
    List<ChatListItem> visible,
    List<_ListEntry> entries,
  ) {
    return visible.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(DSpace.xl2),
                    child: Center(
                      child: Text(
                        _query.isNotEmpty
                            ? 'Ничего не найдено'
                            : (widget.emptyCategoryText ?? 'Чатов пока нет'),
                        textAlign: TextAlign.center,
                        style: DType.caption.copyWith(color: c.textSecondary),
                      ),
                    ),
                  )
                // Flat and lazy. The old build materialised every row of every
                // section on each rebuild; a builder only creates what is on
                // screen, which matters once a category holds hundreds of rows.
                // Отступ по бокам — под скруглённые строки: плитка,
                // упёртая в края панели, читается как оборванная.
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      DSpace.s,
                      DSpace.xs,
                      DSpace.s,
                      DSpace.xs,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (ctx, i) {
                      final entry = entries[i];
                      final header = entry.header;
                      if (header != null) {
                        return _SectionHeader(
                          label: header,
                          colors: c,
                          icon: header == _kPinnedHeader
                              ? FluentIcons.pin_24_filled
                              : null,
                        );
                      }
                      if (entry.isTopicRow) {
                        final t = entry.topic;
                        final id = t?.id;
                        return _TopicSubRow(
                          colors: c,
                          icon: t == null
                              ? roomTopicIconFor(widget.baseTopicMark)
                              : roomTopicIcon(t),
                          iconColor: t == null
                              ? roomTopicIconColorFor(widget.baseTopicMark)
                              : roomTopicIconColor(t),
                          label: t == null
                              ? kRoomBaseTopicTitleRu
                              : normalizeRoomTopicTitle(t.title),
                          selected: widget.currentTopicId == id,
                          unread: widget.topicUnread[id ?? ''] ?? 0,
                          onTap: () => widget.onSelectTopic?.call(id),
                        );
                      }
                      final item = entry.item!;
                      // Черта — только между двумя строками чатов подряд:
                      // под заголовком раздела и под ветками комнаты она была
                      // бы лишней, а у выбранного соседа резала бы заливку.
                      final above = i > 0 ? entries[i - 1].item : null;
                      final row = _ChatRow(
                        item: item,
                        selected: item.id == widget.selectedId,
                        showDivider:
                            above != null && above.id != widget.selectedId,
                        onTap: () => widget.onSelect(item.id),
                        // Lazy on purpose: the menu is only built when the
                        // row is actually right-clicked.
                        onMore: () => _moreSections(item),
                      );
                      final onDrop = widget.onDropOnChat;
                      if (onDrop == null) return row;
                      return _RowDropTarget(
                        onDrop: (paths) => onDrop(item.id, paths),
                        child: row,
                      );
                    },
                  );
  }

  List<List<CtxMenuItem>> _moreSections(ChatListItem item) {
    // Folder / personal / archive rows sit between the quick toggles and the
    // destructive ones, so a mis-click near "Удалить" cannot land on them.
    final extra =
        widget.extraChatActions?.call(item.id) ?? const <List<CtxMenuItem>>[];
    return [
      [
        // 🔴 «В избранное», а не «Закрепить» (14.09.2026).
        //
        // Действие одно, а называлось оно по своему побочному следствию —
        // «переписка встанет вверху списка». Главное же следствие в другом:
        // она появляется ПЛИТКОЙ НА РЕЙКЕ, то есть в одном нажатии из любого
        // раздела. Человек, которому нужно именно это, слово «закрепить» не
        // ищет.
        CtxMenuItem(
          label: item.pinned ? 'Убрать из избранного' : 'В избранное',
          icon: item.pinned
              ? FluentIcons.star_off_24_regular
              : FluentIcons.star_24_regular,
          onTap: () => widget.onPin?.call(item.id),
        ),
        CtxMenuItem(
          label: item.muted ? 'Включить уведомления' : 'Заглушить',
          icon: FluentIcons.alert_off_24_regular,
          onTap: () => widget.onMute?.call(item.id),
        ),
        CtxMenuItem(
          label: 'Отметить прочитанным',
          icon: FluentIcons.checkmark_circle_24_regular,
          enabled: item.unread > 0,
          onTap: () => widget.onMarkRead?.call(item.id),
        ),
        CtxMenuItem(
          label: item.archived ? 'Из архива' : 'В архив',
          icon: item.archived
              ? FluentIcons.archive_arrow_back_24_regular
              : FluentIcons.archive_24_regular,
          onTap: () => widget.onArchive?.call(item.id),
        ),
      ],
      ...extra,
      [
        CtxMenuItem(
          label: 'Очистить историю',
          icon: FluentIcons.broom_24_regular,
          isDanger: true,
          onTap: () => widget.onClear?.call(item.id),
        ),
        CtxMenuItem(
          label: 'Удалить',
          icon: FluentIcons.delete_24_regular,
          isDanger: true,
          onTap: () => widget.onDelete?.call(item.id),
        ),
      ],
    ];
  }
}

/// Makes a chat row accept dropped files.
///
/// A wrapper rather than state on the row itself: the row is a pure renderer
/// and dropping is the host's concern, so keeping them apart means the row
/// cannot accidentally depend on drop state.
class _RowDropTarget extends StatefulWidget {
  const _RowDropTarget({required this.onDrop, required this.child});

  final Future<void> Function(List<String> paths) onDrop;
  final Widget child;

  @override
  State<_RowDropTarget> createState() => _RowDropTargetState();
}

class _RowDropTargetState extends State<_RowDropTarget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return DropTarget(
      // 🔴 Только пока список — верхний экран: цель броска слышит события и
      // под открытым окном, и файл, брошенный на окно отправки, иначе ушёл бы
      // ещё и в чат под ним.
      enable: ModalRoute.isCurrentOf(context) ?? true,
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (detail) {
        setState(() => _hovering = false);
        final paths = detail.files.map((f) => f.path).toList(growable: false);
        if (paths.isEmpty) return;
        unawaited(widget.onDrop(paths));
      },
      child: DecoratedBox(
        // The highlight names the target row explicitly. A drag has no undo,
        // so "which row am I about to send this to" must be unambiguous.
        decoration: BoxDecoration(
          color: _hovering
              ? c.accentPrimary.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: _hovering ? c.accentPrimary : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(DRadii.md),
        ),
        child: widget.child,
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onMore,
    this.showDivider = false,
  });

  final ChatListItem item;
  final bool selected;
  final VoidCallback onTap;
  final List<List<CtxMenuItem>> Function() onMore;

  /// Тонкая черта над строкой — как в телеграме, от колонки текста до края.
  /// Список сам решает, где она нужна: не над первой строкой раздела и не
  /// рядом с выбранной, чью заливку черта резала бы.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      onSecondaryTapDown: (d) => ContextMenu.show(
        context,
        globalPosition: d.globalPosition,
        sections: onMore(),
      ),
      builder: (ctx, hovered, pressed) {
        // 🔴 ВЫДЕЛЕНИЕ — РОВНАЯ ЗАЛИВКА И ПОЛОСКА СЛЕВА (14.09.2026).
        //
        // Здесь раньше стояло рассуждение, что полоска у края отмечает строку,
        // но не отделяет её от соседей, и потому плитка с градиентом лучше.
        // Рассуждение было построено на ложном выборе: в макете владельца есть
        // И ТО И ДРУГОЕ. Заливка отделяет строку от соседей, полоска называет
        // её выбранной — они отвечают на разные вопросы и не заменяют друг
        // друга.
        //
        // Заливка ровная, а не градиентная: градиент по горизонтали тянул
        // взгляд вправо, к времени, вместо имени. Цвет — общий токен
        // выделения, тот же, что у выбранной темы и вкладки.
        //
        // Полоска — тем же градиентом, что свои пузыри и активная плитка
        // рейки: «ты здесь» во всём окне одного цвета.
        // 🔴 ВЫДЕЛЕНИЕ — СПЛОШНОЙ ЗАЛИВКОЙ ЦВЕТОМ ОКНА, КАК В ТЕЛЕГРАМЕ
        // (16.09.2026, скриншот владельца).
        //
        // Была тихая подсветка и полоска у края. В телеграме открытый чат
        // залит цветом целиком, и весь текст на нём белый: где ты сейчас,
        // видно боковым зрением через всю панель, а не только вблизи.
        return AnimatedContainer(
          duration: DMotion.fast,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: selected
                ? selectedChatRowFill(c.accentPrimary)
                : (pressed
                      ? c.pressed
                      : (hovered ? c.hover : Colors.transparent)),
            borderRadius: BorderRadius.circular(DRadii.r12),
          ),
          child: Stack(
            // Черта живёт в зазоре между строками, над заливкой: так её не
            // перекрывает ни подсветка наведения, ни выделение соседа.
            clipBehavior: Clip.none,
            children: [
              if (showDivider && !selected)
                Positioned(
                  top: -1,
                  left: DSpace.p10 + _avatar + DSpace.p10,
                  right: 0,
                  child: Container(height: 1, color: c.borderHairline),
                ),
              Padding(
                // · ОТСТУПЫ СТРОКИ — 9 И 10 ИЗ МАКЕТА, а не 8 и «8 + 2».
                //
                // Портрет 42 плюс девятки сверху и снизу дают ровно 60 точек
                // высоты — ту самую строку, что в макете. На восьмёрках
                // выходило 58: разница в две точки на строку, а строк в списке
                // два десятка, и к низу панели список уезжал на сорок.
                //
                // Горизонталь и была десяткой, только писалась как «DSpace.s +
                // 2»: ступени 10 в шкале просто не существовало.
                // 🔴 16.09.2026 строка — ТЕЛЕГРАМНАЯ, по замерам скриншота
                // владельца: шаг строк ровно 70, портрет 50, текст — ТРИ
                // строки (имя 18 и две строки превью по 16), то есть 50, ровно
                // в рост портрета. 9 сверху и снизу плюс зазор 1+1 между
                // строками и дают те самые 70.
                padding: const EdgeInsets.symmetric(
                  horizontal: DSpace.p10,
                  vertical: DSpace.p9,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Avatar(
                      name: item.name,
                      seed: item.seed,
                      image: Avatar.fileImage(item.avatarPath),
                      frameId: item.frameId,
                      // 🔴 50, как в телеграме (16.09.2026, замер скриншота).
                      // Было 42 по макету — рядом с тремя строками текста
                      // такой портрет терялся, а узнают чат в списке прежде
                      // всего по нему.
                      size: _avatar,
                      online: item.online,
                      // Вырез вокруг точки — цвета ТОГО, что под портретом:
                      // у выделенной строки это заливка выделения поверх
                      // панели, а не сама панель. Иначе вокруг точки видно
                      // кольцо чужого цвета.
                      ringColor: selected
                          ? selectedChatRowFill(c.accentPrimary)
                          : c.chatList,
                      muted: false,
                      // Признак проверки стоит у ИМЕНИ, как в макете: на
                      // портрете он спорил с точкой присутствия за тот же угол.
                      verified: false,
                      // Форма = тип разговора. В списке это единственное, что
                      // работает боковым зрением: «человек» или «комната, где
                      // сообщение увидят двадцать человек».
                      shape: item.kind == ChatKind.direct
                          ? AvatarShape.round
                          : AvatarShape.room,
                    ),
                    // Зазор портрет↔текст — 10 из макета (был 12).
                    const SizedBox(width: DSpace.p10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              // 🔴 ИМЯ И ЕГО ЗНАЧКИ — ОДНОЙ ГРУППОЙ, ЗАНИМАЮЩЕЙ ВСЁ
                              // МЕСТО ДО ВРЕМЕНИ (16.09.2026).
                              //
                              // Было `Flexible` у имени и `Spacer` перед временем
                              // в одном ряду. Свободное место ряд делит между
                              // ними ПОРОВНУ, поэтому имени доставалось не больше
                              // половины: «Sophie Benne…» при пустом месте рядом.
                              // А время вставало сразу за этой половиной, то есть
                              // у каждой строки на своём месте, а не у края.
                              Expanded(
                                child: Row(
                                  children: [
                                  // · БУЛАВКИ НА САМОЙ СТРОКЕ НЕТ (макет).
                                  //
                                  // Она повторяла то, что уже сказано заголовком
                                  // раздела «ЗАКРЕПЛЁННЫЕ» — и при этом сдвигала
                                  // имя вправо, то есть ломала ровный столбик
                                  // имён ради повтора.
                                  //
                                  // Признак остаётся у заголовка раздела, а само
                                  // поле `pinned` по-прежнему строит раздел.
                                  // 🔴 Значок ставим ТОЛЬКО каналу, а не всякой
                                  // комнате.
                                  //
                                  // В макете перед комнатой стоит «#», перед
                                  // каналом — рупор. «#» мы забираем темам: два
                                  // разных смысла у одного знака в одном окне —
                                  // это путаница, которую потом не развести.
                                  //
                                  // Комнату и так называет форма портрета. А канал
                                  // меняет то, что человек МОЖЕТ СДЕЛАТЬ: туда
                                  // нельзя ответить. Вот это и стоит отметить.
                                  if (item.kind == ChatKind.channel) ...[
                                    Icon(
                                      FluentIcons.megaphone_loud_16_regular,
                                      size: 13,
                                      color: selected
                                          ? Colors.white
                                          : c.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      item.name,
                                      // 13,5/600 из макета: строка набрана мельче
                                      // основного текста, и это держит плотность.
                                      style: DType.rowName.copyWith(
                                        // Телеграмный кегль имени — 14 на
                                        // строке 18.
                                        fontSize: 14,
                                        height: 18 / 14,
                                        // Молчащий чат приглушается ИМЕНЕМ, а не
                                        // слоем прозрачности поверх строки:
                                        // `Opacity` заводит отдельный слой на
                                        // каждую такую строку, а их в списке
                                        // бывает половина.
                                        color: selected
                                            ? Colors.white
                                            : (item.muted
                                                  ? c.textSecondary
                                                  : c.textPrimary),
                                        // В макете имя КОМНАТЫ и КАНАЛА набрано
                                        // жирнее имени человека: у человека имя
                                        // одно, а у комнаты за именем стоит
                                        // двадцать человек, и в списке это
                                        // разные веса.
                                        fontWeight: item.kind == ChatKind.direct
                                            ? FontWeight.w600
                                            : FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // · ЗНАЧОК МОЛЧАНИЯ — СРАЗУ ПОСЛЕ ИМЕНИ (макет).
                                  //
                                  // Он стоял в ПРАВОЙ части второй строки, рядом
                                  // со счётчиком: там читается как свойство
                                  // счётчика («это молчаливые непрочитанные»), а
                                  // не как свойство ЧАТА. Рядом с именем вопрос
                                  // «звенит ли этот разговор» закрыт сразу.
                                  if (item.muted) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      FluentIcons.alert_off_24_regular,
                                      size: 13,
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : c.textDisabled,
                                    ),
                                  ],
                                  if (item.emojiStatus != null &&
                                      item.emojiStatus!.isNotEmpty) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      item.emojiStatus!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                  // 🔴 ГАЛОЧКА ЗНАЧИТ «КОНТАКТ ПРОВЕРЕН», А НЕ
                                  // «ЗАПЛАТИЛ» (14.09.2026, разбор макета).
                                  //
                                  // Значок висел на признаке премиума: тот, кто
                                  // оплатил подписку, получал рядом с именем знак,
                                  // который во всех мессенджерах читается как
                                  // «личность подтверждена». Это не украшение, а
                                  // ложное обещание безопасности — ровно то, чего
                                  // в приложении про приватность быть не должно.
                                  //
                                  // Платный тариф в макете назван отдельно — чипом
                                  // PRO в карточке профиля, где ему и место.
                                  if (item.verified) ...[
                                    const SizedBox(width: 3),
                                    const DesktopVerifiedBadge(size: 13),
                                  ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // 🔴 ГАЛОЧКИ — РЯДОМ СО ВРЕМЕНЕМ, А НЕ В СТРОКЕ
                              // ПРЕВЬЮ (16.09.2026, скриншот телеграма от
                              // владельца).
                              //
                              // Они стояли справа от превью и показывались
                              // ТОЛЬКО когда непрочитанного нет — то есть о
                              // судьбе своего последнего сообщения строка
                              // сообщала через раз. В телеграме галочки живут
                              // на строке имени, слева от времени, и видны
                              // всегда: «доставлено» и «прочитано» — про моё
                              // сообщение, а счётчик — про чужие, это разные
                              // сведения и разные места.
                              if (item.delivery != ChatDelivery.none) ...[
                                _DeliveryTick(
                                  delivery: item.delivery,
                                  colors: c,
                                  onFill: selected,
                                ),
                                const SizedBox(width: 4),
                              ],
                              // Третьим тоном, а не вторым: время — служебная
                              // подпись, и в макете оно заметно тусклее имени
                              // рядом. См. DColorSet.textTertiary.
                              Text(
                                item.time,
                                style: DType.timeSmall.copyWith(
                                  fontSize: 12,
                                  height: 15 / 12,
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : c.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          // 🔴 ДВЕ СТРОКИ ПРЕВЬЮ, И СЧЁТЧИК ПОД ВРЕМЕНЕМ, А НЕ
                          // ПОСРЕДИ ТЕКСТА (16.09.2026). Так в телеграме: у
                          // длинного сообщения видна вторая строка, у комнаты
                          // первая строка — КТО написал, вторая — ЧТО.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Две строки держатся всегда — и когда сообщение
                              // короткое. Иначе строки списка были бы разного
                              // роста, и столбик имён шёл бы зигзагом.
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 2 * _previewSize * _previewLine,
                                  ),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: _preview(c),
                                  ),
                                ),
                              ),
                              if (item.unread > 0) ...[
                                const SizedBox(width: 6),
                                _unreadBadge(c),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Портрет строки — телеграмные 50.
  static const double _avatar = ChatRowGeometry.avatar;

  /// Кегль превью — телеграмный, 13 (было 12 по макету), строки — по 16:
  /// ровно такой шаг у двух строк превью на скриншоте владельца.
  static const double _previewSize = 13;
  static const double _previewLine = 16 / 13;

  /// Превью под именем — ДВЕ строки, как в телеграме (16.09.2026).
  ///
  /// 🔴 У КОМНАТЫ ПЕРВАЯ СТРОКА — КТО, ВТОРАЯ — ЧТО. Было «Игорь: текст» одной
  /// строкой: при длинном имени текст сообщения обрезался до пары слов, а
  /// иногда и до пустоты. В телеграме автор стоит своей строкой, светлее
  /// текста, а сообщение — под ним.
  ///
  /// 🔴 У ЛИЧНОГО ЧАТА — ДВЕ СТРОКИ САМОГО СООБЩЕНИЯ, и без «Вы:». Своё
  /// сообщение и так видно по галочкам у времени — ровно так в телеграме, где
  /// «Отака фигня ребятки ✓✓» не подписано «Вы».
  ///
  /// На выделенной строке весь текст белый: под ним сплошная заливка окна.
  Widget _preview(DColorSet c) {
    final sub = selected
        ? Colors.white.withValues(alpha: 0.85)
        : c.textSecondary;
    final strong = selected ? Colors.white : c.textPrimary;
    TextStyle style(Color color) => DType.preview.copyWith(
          fontSize: _previewSize,
          height: _previewLine,
          color: color,
        );

    // 🔴 ИДУЩИЙ СОЗВОН ВАЖНЕЕ ПОСЛЕДНЕГО СООБЩЕНИЯ.
    //
    // В макете это стоит прямо в строке списка — и по делу: о разговоре надо
    // узнать, пока он идёт. Раньше плашка была только ВНУТРИ комнаты, то есть
    // о созвоне узнавал тот, кто и так туда зашёл.
    final call = item.roomCall;
    if (call != null) {
      final tint = selected ? Colors.white : c.success;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.pulse_24_filled, size: 13, color: tint),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Обсуждение · ${formatParticipantsRu(call.participants)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style(tint).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    if (item.typing) {
      final tint = selected ? Colors.white : c.accentPrimary;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'печатает',
            style: style(tint).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(width: 4),
          _TypingDots(color: tint),
        ],
      );
    }
    if (item.draft) {
      return RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Черновик: ',
              style: style(selected ? Colors.white : c.danger).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // Черновик — одной строкой: переносы набранного текста в
            // превью только съедали бы место.
            TextSpan(
              text: (item.draftText ?? item.preview)
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim(),
              style: style(sub),
            ),
          ],
        ),
      );
    }

    final icon = _previewIconData(item.previewIcon);
    // Звонок — единственный вид превью, который красится: в макете трубка и
    // подпись зелёные. Остальные значки служебные и идут цветом подписи, иначе
    // список превратится в светофор.
    final isCall = item.previewIcon == ChatPreviewIcon.call;
    final tint = isCall && !selected ? c.success : sub;
    final author = (item.previewAuthor ?? '').trim();
    final showAuthor = author.isNotEmpty && item.kind != ChatKind.direct;

    // Сам текст сообщения: у комнаты — одна строка (вторую занял автор), у
    // личного чата — две.
    final body = Text(
      item.preview,
      style: style(tint),
      maxLines: showAuthor ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );
    final line = icon == null
        ? body
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: isCall ? 14 : 13, color: tint),
              ),
              const SizedBox(width: 4),
              Flexible(child: body),
            ],
          );
    if (!showAuthor) return line;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // 🔴 АВТОР — ЦВЕТОМ ЭТОГО ЧЕЛОВЕКА, как на телефоне (16.09.2026).
          //
          // Телефон пишет автора превью его цветом и полужирным — тем же
          // цветом, что имя в пузыре. В телеграме «кто» подсказывает маленький
          // портрет перед именем; цвет делает то же самое без лишнего запроса
          // «устройство → профиль → фото» на каждую строку списка.
          //
          // На выделенной строке — белый: цветное имя на сплошной заливке
          // читалось бы хуже.
          style: style(
            selected
                ? strong
                : AvatarInitials.nicknameColor(
                    seed: (item.previewAuthorSeed ?? '').trim().isNotEmpty
                        ? item.previewAuthorSeed!
                        : author,
                  ),
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        line,
      ],
    );
  }

  /// 🔴 Значок вместо эмодзи.
  ///
  /// Раньше вид вложения подставлялся символами «📷 🎵 📎» прямо в текст. На
  /// тёмном фоне цветной эмодзи светится и выбивается кеглем из всей остальной
  /// типографики строки, а главное — он часть ТЕКСТА: попадает в обрезку по
  /// ширине и в поиск по превью. Значок в цвете подписи ведёт себя как
  /// оформление, которым и является.
  static IconData? _previewIconData(ChatPreviewIcon kind) {
    switch (kind) {
      case ChatPreviewIcon.none:
        return null;
      case ChatPreviewIcon.photo:
        return FluentIcons.image_24_regular;
      case ChatPreviewIcon.video:
        return FluentIcons.video_24_regular;
      case ChatPreviewIcon.music:
        return FluentIcons.music_note_2_24_regular;
      case ChatPreviewIcon.voice:
        return FluentIcons.mic_24_regular;
      case ChatPreviewIcon.file:
        return FluentIcons.document_24_regular;
      case ChatPreviewIcon.link:
        return FluentIcons.link_24_regular;
      case ChatPreviewIcon.call:
        return FluentIcons.call_24_regular;
    }
  }

  Widget _unreadBadge(DColorSet c) =>
      _chatUnreadBadge(c, item, onFill: selected);
}

/// Размеры строки списка, общие для обычного и свёрнутого вида.
abstract final class ChatRowGeometry {
  /// Портрет — телеграмные 50 (замер скриншота владельца, 16.09.2026).
  static const double avatar = 50;
}

/// Счётчик непрочитанного — один на обычную и свёрнутую строку списка.
///
/// [onFill] — строка выделена и залита цветом окна.
Widget _chatUnreadBadge(
  DColorSet c,
  ChatListItem item, {
  required bool onFill,
}) {
  final txt = item.unread > 99 ? '99+' : '${item.unread}';
  // На выделенной строке — белая плашка с цветным числом, как в телеграме:
  // цветная плашка на заливке того же цвета исчезла бы.
  if (onFill) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        txt,
        style: DType.tiny.copyWith(
          fontSize: 11,
          // Цветом заливки строки: он и читается на белом не хуже, чем
          // белый на нём.
          color: selectedChatRowFill(c.accentPrimary),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
  // · У ПРИГЛУШЁННОГО ЧАТА — ТА ЖЕ ПЛАШКА С ЧИСЛОМ, но тихая (макет).
  //
  // Была точка 8×8. Она говорила «что-то есть» и отнимала само число — а
  // у молчаливого чата число как раз и решает, заходить сейчас или потом:
  // звук выключен, и напомнить о разговоре больше нечему.
  if (item.muted) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        txt,
        style: DType.tiny.copyWith(
          fontSize: 11,
          color: c.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
  return Container(
    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      // 🔴 Упоминание красится ГРАДИЕНТОМ, а не своим цветом.
      //
      // В макете отдельного значка «@» нет — есть счётчик, залитый
      // сиренево-розовым переходом. Плашка «@» рядом со счётчиком (она тут
      // была и никогда не показывалась) занимала место и дублировала то же
      // сообщение: «тут звали тебя лично».
      gradient: item.mention
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7C5CE0), Color(0xFFEC4899)],
            )
          : null,
      // Цвет называет тип разговора — см. [unreadColorFor].
      color: item.mention ? null : unreadColorFor(item.kind, c),
      // Радиус 9 из макета, а не «таблетка»: при двузначном числе таблетка
      // вытягивается в овал, а девятка держит плашку почти квадратной — и
      // «7» с «12» выглядят одним знаком, а не двумя разными.
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      txt,
      style: const TextStyle(
        fontFamily: DType.family,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        height: 1.0,
      ),
    ),
  );
}

/// Тема открытой комнаты — подстрока под её строкой в списке.
///
/// 🔴 Отступ слева ровно под именем комнаты, а не произвольный. Подстрока
/// должна читаться как продолжение строки выше, а не как отдельный чат с
/// маленьким портретом: выравнивание по имени — это и есть заявление
/// «я принадлежу ей».
///
/// Знак «#» закреплён за темами и больше нигде в окне не используется: у
/// комнаты свой признак — форма портрета.
/// Шапка панели: название раздела и две кнопки.
///
/// 🔴 Кнопок ровно две, и обе ведут туда, куда иначе не попасть.
///
/// «Создать» — единственный на десктопе вход в создание чата и комнаты: до
/// 13.09 комнату можно было завести только с телефона, а новый чат — только
/// найдя человека в отдельном разделе «Контакты».
///
/// «Фильтры» — видимый вход в папки. Папки работали и раньше, но попасть в них
/// можно было лишь правым щелчком по строке чата, то есть никак, если не знать
/// заранее. Кнопка не добавляет возможностей, она перестаёт их прятать.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.onCompose,
    required this.onFilters,
  });

  final String title;
  final void Function(Offset globalPosition)? onCompose;
  final void Function(Offset globalPosition)? onFilters;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final compose = onCompose;
    final filters = onFilters;
    if (compose == null && filters == null) {
      // Заголовок сам по себе занял бы строку и ничего не сообщил: раздел и
      // так назван в рейке слева. Без кнопок шапки нет.
      return const SizedBox(height: DSpace.m);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSpace.m,
        DSpace.m,
        DSpace.s,
        DSpace.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 17/800 с отрицательным трекингом — заголовок панели из
              // макета; `title` (16/600) был на шаг легче и шире.
              style: DType.panelTitle.copyWith(color: c.textPrimary),
            ),
          ),
          if (filters != null)
            _HeaderButton(
              icon: FluentIcons.filter_24_regular,
              tooltip: 'Папки',
              onTap: filters,
            ),
          if (filters != null && compose != null) const SizedBox(width: 2),
          if (compose != null)
            _HeaderButton(
              icon: FluentIcons.compose_24_regular,
              tooltip: 'Создать',
              accent: true,
              onTap: compose,
            ),
        ],
      ),
    );
  }
}

/// Кнопка шапки. Сообщает положение нажатия: оба её меню открываются от самой
/// кнопки, а не по центру экрана.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final void Function(Offset globalPosition) onTap;

  /// Главное действие панели — с заливкой градиентом, как в макете.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return DesktopTooltip(
      message: tooltip,
      child: Builder(
        builder: (btnCtx) => HoverListener(
          onTap: () {
            final box = btnCtx.findRenderObject();
            final at = box is RenderBox
                ? box.localToGlobal(box.size.bottomLeft(Offset.zero))
                : Offset.zero;
            onTap(at);
          },
          builder: (ctx, hovered, pressed) => AnimatedContainer(
            duration: DMotion.fast,
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: accent
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.accentPrimary, c.accentPrimaryAlt],
                    )
                  : null,
              color: accent
                  ? null
                  : (pressed
                        ? c.pressed
                        : (hovered
                              ? c.hover
                              : c.elevated.withValues(alpha: 0.6))),
              borderRadius: BorderRadius.circular(DRadii.sm),
            ),
            child: Icon(
              icon,
              size: 17,
              color: accent ? Colors.white : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Шапка свёрнутого списка: лупа, папки и «создать» — столбиком.
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({this.onSearch, this.onFilters, this.onCompose});

  final VoidCallback? onSearch;
  final void Function(Offset globalPosition)? onFilters;
  final void Function(Offset globalPosition)? onCompose;

  @override
  Widget build(BuildContext context) {
    final search = onSearch;
    final filters = onFilters;
    final compose = onCompose;
    final buttons = <Widget>[
      if (compose != null)
        _HeaderButton(
          icon: FluentIcons.compose_24_regular,
          tooltip: 'Создать',
          accent: true,
          onTap: compose,
        ),
      if (search != null)
        _HeaderButton(
          icon: FluentIcons.search_24_regular,
          tooltip: _kSearchHint,
          onTap: (_) => search(),
        ),
      if (filters != null)
        _HeaderButton(
          icon: FluentIcons.filter_24_regular,
          tooltip: 'Папки',
          onTap: filters,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSpace.m),
      child: Column(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: DSpace.p6),
            buttons[i],
          ],
        ],
      ),
    );
  }
}

/// Строка свёрнутого списка: портрет со счётчиком.
class _CompactChatRow extends StatelessWidget {
  const _CompactChatRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onMore,
    this.dividerAbove = false,
  });

  final ChatListItem item;
  final bool selected;
  final VoidCallback onTap;
  final List<List<CtxMenuItem>> Function() onMore;
  final bool dividerAbove;

  /// Имя — первой строкой, последнее сообщение — второй: всё, что обычная
  /// строка говорит словами, столбик говорит при наведении.
  String get _tooltip {
    final preview = item.preview.trim();
    if (preview.isEmpty) return item.name;
    final author = (item.previewAuthor ?? '').trim();
    final line = author.isNotEmpty && item.kind != ChatKind.direct
        ? '$author: $preview'
        : preview;
    return '${item.name}\n$line';
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final fill = selectedChatRowFill(c.accentPrimary);
    // Под портретом и счётчиком — цвет того, что под строкой: вырез вокруг
    // точки присутствия и вокруг счётчика иначе светился бы чужим цветом.
    final under = selected ? fill : c.chatList;
    final row = HoverListener(
      onTap: onTap,
      onSecondaryTapDown: (d) => ContextMenu.show(
        context,
        globalPosition: d.globalPosition,
        sections: onMore(),
      ),
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        // Тот же шаг, что у обычной строки (68 + 1 + 1): свернули список —
        // портреты остались на своей высоте.
        height: 68,
        margin: const EdgeInsets.symmetric(vertical: 1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? fill
              : (pressed
                    ? c.pressed
                    : (hovered ? c.hover : Colors.transparent)),
          borderRadius: BorderRadius.circular(DRadii.r12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Avatar(
              name: item.name,
              seed: item.seed,
              image: Avatar.fileImage(item.avatarPath),
              frameId: item.frameId,
              size: ChatRowGeometry.avatar,
              online: item.online,
              ringColor: under,
              muted: false,
              verified: false,
              shape: item.kind == ChatKind.direct
                  ? AvatarShape.round
                  : AvatarShape.room,
            ),
            if (item.unread > 0)
              Positioned(
                top: -4,
                right: -7,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: under,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: _chatUnreadBadge(c, item, onFill: selected),
                ),
              ),
          ],
        ),
      ),
    );
    final withTip = DesktopTooltip(message: _tooltip, child: row);
    if (!dividerAbove) return withTip;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(
            horizontal: DSpace.m,
            vertical: DSpace.p5,
          ),
          color: c.borderSubtle,
        ),
        withTip,
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});
  final Color color;
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 8,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) {
          double phase(int i) {
            final t = (_ctrl.value + i * 0.18) % 1.0;
            return (1 - (2 * t - 1).abs()).clamp(0.0, 1.0);
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final p = phase(i);
              return Container(
                width: 4,
                height: 4 + p * 4,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.5 + p * 0.5),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Подпись раздела в списке чатов: «ЗАКРЕПЛЁННЫЕ», «ВСЕ ЧАТЫ».
///
/// Набрана мелко, разрядкой и приглушённым цветом — это указатель, а не
/// содержание. У человека с сотней чатов глаз должен находить границу секции
/// боковым зрением и не задерживаться на самой подписи.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.colors, this.icon});

  final String label;
  final DColorSet colors;

  /// Значок слева от подписи. Есть только у «Закреплённых»: там он повторяет
  /// булавку на самих строках и связывает раздел с признаком, по которому
  /// строки в него попали.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSpace.m,
        DSpace.m,
        DSpace.m,
        DSpace.xs,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.textFaint),
            const SizedBox(width: 6),
          ],
          // Моноширинный ярлык из макета: см. DType.meta — смена шрифта
          // отделяет подпись раздела от имён в той же колонке вернее любого
          // отступа.
          Text(label, style: DType.meta.copyWith(color: colors.textDisabled)),
          const SizedBox(width: DSpace.s),
          // · ЛИНИЯ — ТОЛЬКО У ДАТНЫХ РАЗДЕЛОВ (макет).
          //
          // У «ЗАКРЕПЛЁННЫХ» её нет: там признак несёт булавка, и линия
          // становилась второй чертой подряд — под шапкой списка и сразу под
          // ней. Даты же ничем, кроме линии, друг от друга не отделены.
          if (icon == null)
            Expanded(child: Container(height: 1, color: colors.borderHairline))
          else
            const Spacer(),
        ],
      ),
    );
  }
}

/// Знак доставки своего последнего сообщения — справа во второй строке.
///
/// 🔴 Рисует его [deliveryTickGlyph] — ТА ЖЕ функция, что под пузырями в
/// переписке. Своя копия галочек здесь уже была бы третьей: в шапке файла с
/// пузырями записано, как две копии разошлись и одна стала рисовать синюю
/// вторую галочку. Один и тот же знак не может значить в двух местах окна
/// разное.
class _DeliveryTick extends StatelessWidget {
  const _DeliveryTick({
    required this.delivery,
    required this.colors,
    this.onFill = false,
  });

  final ChatDelivery delivery;
  final DColorSet colors;

  /// Строка выделена — под галочками залитый цвет окна, и цветная галочка на
  /// нём пропала бы. Как в телеграме — белая.
  final bool onFill;

  @override
  Widget build(BuildContext context) {
    final read = delivery == ChatDelivery.read;
    if (onFill) {
      return Padding(
        padding: const EdgeInsets.only(left: 2),
        child: deliveryTickGlyph(
          switch (delivery) {
            ChatDelivery.read => DeliveryStatus.read,
            ChatDelivery.delivered => DeliveryStatus.delivered,
            _ => DeliveryStatus.sent,
          },
          Colors.white,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: deliveryTickGlyph(
        switch (delivery) {
          ChatDelivery.read => DeliveryStatus.read,
          ChatDelivery.delivered => DeliveryStatus.delivered,
          _ => DeliveryStatus.sent,
        },
        read ? colors.deliveryIndicator : colors.textTertiary,
      ),
    );
  }
}

/// Строка ветки под строкой открытой комнаты.
///
/// Отступ слева и меньший рост — чтобы ветки читались ПРИНАДЛЕЖАЩИМИ комнате,
/// а не соседними чатами: список с одинаковыми по весу строками потерял бы
/// границу между «комнатой» и «веткой внутри неё».
class _TopicSubRow extends StatelessWidget {
  const _TopicSubRow({
    required this.colors,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.selected,
    required this.unread,
    required this.onTap,
  });

  final DColorSet colors;
  final IconData icon;
  final Color? iconColor;
  final String label;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => Container(
        margin: const EdgeInsets.fromLTRB(26, 1, DSpace.xs, 1),
        padding: const EdgeInsets.symmetric(horizontal: DSpace.s, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? c.selected
              : (hovered ? c.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(DRadii.sm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: iconColor ?? c.textTertiary),
            const SizedBox(width: DSpace.p6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.label.copyWith(
                  fontSize: 12.5,
                  color: selected ? c.textPrimary : c.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (unread > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: c.unreadRoom,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
