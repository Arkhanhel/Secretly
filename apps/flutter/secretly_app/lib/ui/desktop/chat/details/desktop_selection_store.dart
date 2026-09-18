// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

import '../../../../app/app_controller.dart';
import '../../../../app/message_command_utils.dart' show RoomTopicRef;

/// Shared store for the currently selected conversation across the desktop
/// shell. Written by [DesktopChatsSection] when the user picks a chat/room,
/// read by the `detailsBuilder` slot of [DesktopShell] to render the right
/// third-column content.
///
/// Why a separate store (vs hoisting state into the shell): keeps each
/// section's selection logic self-contained, lets us cleanly clear the
/// selection on section switches, and avoids re-wiring the shell's
/// content/details builder signatures.
class DesktopChatSelectionStore extends ChangeNotifier {
  Conversation? _selected;

  /// Currently selected conversation, or `null` if no chat is opened.
  Conversation? get selected => _selected;

  /// Convenience: convoId of the selection, empty when nothing is selected.
  String get selectedConvoId => _selected?.convoId ?? '';

  /// Select [convo]; pass `null` to clear. Notifies listeners only when the
  /// effective convoId actually changes — prevents redundant rebuilds when
  /// the chat list refreshes the same Conversation row.
  void select(Conversation? convo) {
    final newId = convo?.convoId ?? '';
    final oldId = _selected?.convoId ?? '';
    final identityChanged = newId != oldId;
    _selected = convo;
    if (identityChanged) notifyListeners();
  }

  /// Re-publishes the selection (e.g. after a list reload that updated the
  /// peerLastSeenAtMs of the open chat). Always notifies.
  void refresh(Conversation? convo) {
    _selected = convo;
    notifyListeners();
  }

  /// Clears the selection. Idempotent.
  void clear() {
    if (_selected == null) return;
    _selected = null;
    _topics = const <RoomTopicRef>[];
    _baseTopicMark = '';
    _currentTopicId = null;
    _topicUnread = const <String, int>{};
    _topicLastActivityMs = const <String, int>{};
    _canManageTopics = false;
    notifyListeners();
  }

  // ── Темы открытой комнаты ─────────────────────────────────────────────
  //
  // 🔴 Почему темы живут ЗДЕСЬ, а не читаются панелью самостоятельно.
  //
  // Темы приезжают управляющим сообщением `__secretly_topics_v1__` и
  // разбираются секцией чатов по ходу ленты — отдельной таблицы, которую можно
  // было бы спросить, у них нет. Панель подробностей строится в другом месте
  // дерева и до состояния секции не достаёт.
  //
  // Этот склад у секции и панели уже общий, поэтому темы публикуются в него:
  // секция остаётся единственным местом, где они разбираются, а панель получает
  // готовый список. Второго разбора нет — значит и разойтись двум спискам не с
  // чем.

  List<RoomTopicRef> _topics = const <RoomTopicRef>[];

  /// Знак «Основы» — общего потока комнаты. Пусто — решётка.
  String _baseTopicMark = '';
  String? _currentTopicId;
  Map<String, int> _topicUnread = const <String, int>{};
  Map<String, int> _topicLastActivityMs = const <String, int>{};

  /// Темы открытой комнаты. Пусто у личной переписки и у комнаты без тем.
  List<RoomTopicRef> get topics => _topics;

  /// Знак «Основы». Записи в списке тем у неё нет: у её сообщений нет
  /// `topic_id`, и выдуманный идентификатор развёл бы фильтр ленты со списком.
  String get baseTopicMark => _baseTopicMark;

  /// Выбранная тема; `null` — «Общий».
  String? get currentTopicId => _currentTopicId;

  /// Непрочитанное по теме; пустая строка ключа — «Общий».
  Map<String, int> get topicUnread => _topicUnread;

  /// Время последнего сообщения по теме; пустая строка ключа — «Общий».
  ///
  /// Считается по ЗАГРУЖЕННОЙ ленте: у темы, чьи сообщения остались за краем
  /// подгруженного, ключа не будет вовсе. Отсутствие ключа — «не знаем», а не
  /// «давно»: показывать вместо него что-нибудь нельзя.
  Map<String, int> get topicLastActivityMs => _topicLastActivityMs;

  /// Секция просит открыть тему. Ставится ей же при подписке.
  void Function(String? topicId)? onSelectTopic;

  /// Завести новую тему. `null` — у этого человека нет такого права.
  ///
  /// 🔴 Зачем это здесь, а не только в полосе тем. Полоса появляется лишь
  /// когда тема уже есть хотя бы одна — иначе она отнимала бы 36 точек высоты
  /// у каждой обычной комнаты. Но тогда у комнаты БЕЗ тем не остаётся ни
  /// одного входа, чтобы создать первую: на десктопе темы становились
  /// недостижимы, пока кто-нибудь не заведёт их с телефона.
  VoidCallback? onCreateTopic;

  bool _canManageTopics = false;

  /// Может ли текущий человек заводить и переименовывать темы этой комнаты.
  bool get canManageTopics => _canManageTopics;

  /// Публикует состояние тем. Оповещает только при настоящем изменении —
  /// иначе каждый тик ленты перестраивал бы панель на ровном месте.
  void publishTopics({
    required List<RoomTopicRef> topics,
    required String? currentTopicId,
    required Map<String, int> unread,
    Map<String, int> lastActivityMs = const <String, int>{},
    bool canManage = false,
    String baseMark = '',
  }) {
    final sameTopics =
        _topics.length == topics.length &&
        List.generate(topics.length, (i) => i).every(
          (i) =>
              _topics[i].id == topics[i].id &&
              _topics[i].title == topics[i].title,
        );
    final sameUnread =
        _topicUnread.length == unread.length &&
        unread.entries.every((e) => _topicUnread[e.key] == e.value);
    final sameActivity =
        _topicLastActivityMs.length == lastActivityMs.length &&
        lastActivityMs.entries.every(
          (e) => _topicLastActivityMs[e.key] == e.value,
        );
    if (sameTopics &&
        sameUnread &&
        sameActivity &&
        _currentTopicId == currentTopicId &&
        _baseTopicMark == baseMark &&
        _canManageTopics == canManage) {
      return;
    }
    _canManageTopics = canManage;
    _baseTopicMark = baseMark;
    _topics = topics;
    _currentTopicId = currentTopicId;
    _topicUnread = unread;
    _topicLastActivityMs = lastActivityMs;
    notifyListeners();
  }
}
