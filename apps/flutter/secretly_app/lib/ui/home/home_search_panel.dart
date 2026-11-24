// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Общий поиск главного экрана: одна строка внизу — чаты, комнаты, контакты
/// и текст сообщений. Движок — `search/smart_search.dart`.
///
/// Пустой запрос — «Недавние» (открытые из поиска, хранятся только на этом
/// устройстве). Набор — разделы, лучший раздел первым; раздел, из которого
/// начат поиск, при равенстве выше. «Найти» на клавиатуре открывает лучший
/// результат. Поиск по сообщениям — после короткой паузы в наборе и только
/// от 3 букв: он расшифровывает переписку, это дороже названий.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_controller.dart';
import '../../search/smart_search.dart';
import '../../storage/file_exists_cache.dart';
import '../animations/page_transitions.dart';
import '../chat_screen.dart';
import '../contact_action_error_text.dart';
import '../secretly_snackbar.dart';
import '../favorites_title.dart';
import '../l10n.dart';
import '../wave1_l10n.dart';
import '../widgets/app_background.dart';
import '../widgets/avatar_initials.dart';
import 'home_islands.dart';

/// Недавние из поиска — только на этом устройстве.
class HomeSearchRecents {
  HomeSearchRecents._();

  static const String _key = 'home_search_recent_v1';
  static const int _max = 12;

  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<void> remember(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = [...prefs.getStringList(_key) ?? const <String>[]]
        ..remove(id)
        ..insert(0, id);
      if (list.length > _max) list.removeRange(_max, list.length);
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

/// Панель результатов. Видна, пока острова в режиме поиска.
class HomeSearchPanel extends StatefulWidget {
  const HomeSearchPanel({
    super.key,
    required this.controller,
    required this.islands,
    required this.boostKind,
    required this.bottomReserve,
    this.submitBinding,
  });

  final AppController controller;
  final HomeIslandsController islands;

  /// Раздел, откуда начат поиск.
  final SmartSearchKind? boostKind;

  /// Сколько снизу занято клавиатурой и островами.
  final double bottomReserve;

  /// Оболочка кладёт сюда «открыть лучший результат» для «Найти».
  final HomeSearchSubmitBinding? submitBinding;

  @override
  State<HomeSearchPanel> createState() => _HomeSearchPanelState();
}

/// Связка «Найти» на клавиатуре → панель.
class HomeSearchSubmitBinding {
  VoidCallback? _submit;
  void submit() => _submit?.call();
}

class _MessageHit {
  const _MessageHit(this.convo, this.snippet);
  final Conversation convo;
  final String snippet;
}

class _HomeSearchPanelState extends State<HomeSearchPanel> {
  List<Conversation> _convos = const <Conversation>[];
  List<Contact> _contacts = const <Contact>[];
  List<String> _recents = const <String>[];
  int _loadedVersion = -1;

  String _query = '';
  List<SmartSearchHit> _hits = const <SmartSearchHit>[];

  Timer? _messageDebounce;
  int _messageToken = 0;

  // Глобальный поиск людей по нику (только в разделе Контакты — как
  // прежний поиск этого раздела; из Чатов и Комнат запрос на сервер не
  // уходит).
  Timer? _globalDebounce;
  int _globalToken = 0;
  bool _globalLoading = false;
  String? _globalError;
  List<UserLookupResult> _globalHits = const <UserLookupResult>[];

  bool get _peopleSearch => widget.boostKind == SmartSearchKind.contact;
  bool _searchingMessages = false;
  List<_MessageHit> _messageHits = const <_MessageHit>[];

  @override
  void initState() {
    super.initState();
    widget.islands.text.addListener(_onQuery);
    widget.submitBinding?._submit = _openBest;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant HomeSearchPanel old) {
    super.didUpdateWidget(old);
    if (old.islands != widget.islands) {
      old.islands.text.removeListener(_onQuery);
      widget.islands.text.addListener(_onQuery);
    }
    widget.submitBinding?._submit = _openBest;
    if (old.boostKind != widget.boostKind) _recompute();
  }

  @override
  void dispose() {
    widget.islands.text.removeListener(_onQuery);
    if (widget.submitBinding?._submit == _openBest) {
      widget.submitBinding?._submit = null;
    }
    _messageDebounce?.cancel();
    _globalDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final version = widget.controller.changeVersion;
    if (version == _loadedVersion) return;
    final results = await Future.wait<Object>([
      widget.controller.listConversations(),
      widget.controller.listContacts(),
      HomeSearchRecents.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _loadedVersion = version;
      _convos = results[0] as List<Conversation>;
      _contacts = results[1] as List<Contact>;
      _recents = results[2] as List<String>;
    });
    _recompute();
  }

  void _onQuery() {
    final q = widget.islands.query;
    if (q == _query) return;
    _query = q;
    _recompute();
    _scheduleMessageSearch();
    _scheduleGlobalSearch();
  }

  void _scheduleGlobalSearch() {
    _globalDebounce?.cancel();
    final q = _query.trim();
    final valid = q.contains('-') || q.runes.length >= 2;
    if (!_peopleSearch || !valid) {
      _globalToken++;
      if (_globalHits.isNotEmpty || _globalLoading || _globalError != null) {
        setState(() {
          _globalHits = const <UserLookupResult>[];
          _globalLoading = false;
          _globalError = null;
        });
      }
      return;
    }
    _globalDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runGlobalSearch(q));
    });
  }

  Future<void> _runGlobalSearch(String q) async {
    final token = ++_globalToken;
    setState(() => _globalLoading = true);
    try {
      final found = await widget.controller.lookupUsers(q);
      if (!mounted || token != _globalToken) return;
      setState(() {
        _globalHits = found;
        _globalError = null;
        _globalLoading = false;
      });
    } catch (e) {
      if (!mounted || token != _globalToken) return;
      setState(() {
        _globalHits = const <UserLookupResult>[];
        _globalError = contactLookupErrorText(context.l10n, e);
        _globalLoading = false;
      });
    }
  }

  /// Кого сейчас добавляем: второе касание «Добавить», пока идёт запрос, не
  /// отправляет его повторно (разбор 22.11.2026).
  final Set<String> _adding = <String>{};

  Future<void> _addFound(UserLookupResult r) async {
    if (!_adding.add(r.profileId)) return;
    try {
      await _addFoundOnce(r);
    } finally {
      _adding.remove(r.profileId);
    }
  }

  Future<void> _addFoundOnce(UserLookupResult r) async {
    HapticFeedback.selectionClick();
    final nick = (r.nickname ?? '').trim();
    try {
      await widget.controller.addContact(
        profileId: r.profileId,
        displayName: nick.isEmpty ? null : nick,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(contactActionErrorText(context.l10n, e)),
        ),
      );
      return;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      // Подтверждение, а не название кнопки «Добавить контакт».
      SecretlySnackBar(content: Text(context.l10n.desktopContactsAdded)),
    );
    _loadedVersion = -1;
    await _load();
    _scheduleGlobalSearch();
  }

  // ── Строки поиска ───────────────────────────────────────────────────────

  bool _isRoom(Conversation c) => c.convoId.startsWith('group:');

  String _titleOf(Conversation c) {
    if (widget.controller.isSavedMessagesConvo(c.convoId)) {
      return localizedFavoritesTitle(context);
    }
    final t = c.title.trim();
    return t.isEmpty ? (c.peerProfileId ?? c.convoId) : t;
  }

  List<SmartSearchItem> _items() {
    final chatPeers = <String>{};
    final items = <SmartSearchItem>[];
    // В Контактах контакты — целиком в своём разделе, их личные чаты не
    // повторяются в «Чатах».
    final contactIds = _peopleSearch
        ? {for (final p in _contacts) p.profileId}
        : const <String>{};
    for (final c in _convos) {
      if (c.convoId.startsWith('req:')) continue;
      final room = _isRoom(c);
      if (!room &&
          (contactIds.contains(c.convoId) ||
              contactIds.contains(c.peerProfileId))) {
        continue;
      }
      if (!room) {
        final peer = (c.peerProfileId ?? '').trim();
        if (peer.isNotEmpty) chatPeers.add(peer);
        chatPeers.add(c.convoId);
      }
      items.add(
        SmartSearchItem(
          id: c.convoId,
          kind: room ? SmartSearchKind.room : SmartSearchKind.chat,
          title: _titleOf(c),
          handle: room ? null : c.peerProfileId,
          lastActivityMs: c.lastEventAtMs,
          unread: c.unreadCount,
          pinned: c.pinnedAtMs != null,
          muted: c.muted,
        ),
      );
    }
    // Контакты без переписки (с перепиской они уже в «Чатах»).
    for (final p in _contacts) {
      if (!_peopleSearch && chatPeers.contains(p.profileId)) continue;
      final name = (p.displayName ?? '').trim();
      items.add(
        SmartSearchItem(
          id: p.profileId,
          kind: SmartSearchKind.contact,
          title: name.isEmpty ? p.profileId : name,
          handle: p.profileId,
        ),
      );
    }
    return items;
  }

  void _recompute() {
    if (!mounted) return;
    final recentIds = [
      for (final r in _recents)
        if (r.contains('|')) r.substring(r.indexOf('|') + 1),
    ];
    setState(() {
      _hits = SmartSearch.run(
        _items(),
        _query,
        boostKind: widget.boostKind,
        recentIds: recentIds,
      );
    });
  }

  // ── Сообщения ───────────────────────────────────────────────────────────

  void _scheduleMessageSearch() {
    _messageDebounce?.cancel();
    final q = _query.trim();
    if (q.length < 3) {
      _messageToken++;
      if (_messageHits.isNotEmpty || _searchingMessages) {
        setState(() {
          _messageHits = const <_MessageHit>[];
          _searchingMessages = false;
        });
      }
      return;
    }
    _messageDebounce = Timer(const Duration(milliseconds: 380), () {
      unawaited(_runMessageSearch(q));
    });
  }

  Future<void> _runMessageSearch(String q) async {
    final token = ++_messageToken;
    setState(() => _searchingMessages = true);
    final ordered = [..._convos]
      ..removeWhere((c) => c.convoId.startsWith('req:'))
      ..sort((a, b) => b.lastEventAtMs.compareTo(a.lastEventAtMs));
    final found = <_MessageHit>[];
    for (final c in ordered.take(60)) {
      if (token != _messageToken || !mounted) return;
      String? text;
      try {
        text = await widget.controller.searchChatFirstMatch(
          convoId: c.convoId,
          query: q,
        );
      } catch (_) {
        text = null;
      }
      if (text != null && text.trim().isNotEmpty) {
        found.add(_MessageHit(c, _snippet(text, q)));
        if (found.length >= 8) break;
      }
    }
    if (token != _messageToken || !mounted) return;
    setState(() {
      _messageHits = found;
      _searchingMessages = false;
    });
  }

  static String _snippet(String text, String q) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final at = flat.toLowerCase().indexOf(q.toLowerCase());
    if (at <= 24) return flat;
    return '…${flat.substring(at - 18)}';
  }

  // ── Открыть ─────────────────────────────────────────────────────────────

  Future<void> _open(SmartSearchItem item) async {
    HapticFeedback.selectionClick();
    unawaited(HomeSearchRecents.remember('${item.kind.name}|${item.id}'));
    final nav = Navigator.of(context);
    widget.islands.closeSearch(haptic: false);
    final convoId = item.id;
    final isRoom = item.kind == SmartSearchKind.room;
    await nav.push(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          convoId: convoId,
          title: item.title,
          peerProfileIdForSend: isRoom
              ? null
              : (item.kind == SmartSearchKind.contact
                    ? item.id
                    : (item.handle ?? convoId)),
        ),
      ),
    );
  }

  void _openBest() {
    if (_hits.isNotEmpty) {
      unawaited(_open(_hits.first.item));
    } else if (_messageHits.isNotEmpty) {
      unawaited(_openMessage(_messageHits.first));
    }
  }

  Future<void> _openMessage(_MessageHit hit) {
    final c = hit.convo;
    return _open(
      SmartSearchItem(
        id: c.convoId,
        kind: _isRoom(c) ? SmartSearchKind.room : SmartSearchKind.chat,
        title: _titleOf(c),
        handle: c.peerProfileId,
      ),
    );
  }

  Future<void> _clearRecents() async {
    HapticFeedback.selectionClick();
    await HomeSearchRecents.clear();
    if (!mounted) return;
    setState(() => _recents = const <String>[]);
  }

  // ── Вид ─────────────────────────────────────────────────────────────────

  String _t(String ru, String en, String uk, String es, String pt, String fr,
          String de) =>
      wave1Text(context, ru: ru, en: en, uk: uk, es: es, pt: pt, ptBr: pt,
          fr: fr, de: de);

  String _sectionTitle(SmartSearchKind kind) => switch (kind) {
    SmartSearchKind.chat => context.l10n.tabChats,
    SmartSearchKind.room => _t('Комнаты', 'Rooms', 'Кімнати', 'Salas',
        'Salas', 'Salons', 'Räume'),
    SmartSearchKind.contact => context.l10n.tabContacts,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final bg = AppBackground.scrimColorOf(context);
    final top = MediaQuery.viewPaddingOf(context).top;
    final secondary = dark ? const Color(0x8CEBEEF5) : const Color(0x993C3C43);

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
        child: Text(
          context.l10n.search,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
      ),
    ];

    final query = _query.trim();
    if (query.isEmpty) {
      children.addAll(_buildRecents(context, secondary));
    } else {
      // Разделы в порядке лучшего результата.
      final byKind = <SmartSearchKind, List<SmartSearchHit>>{};
      for (final h in _hits) {
        byKind.putIfAbsent(h.item.kind, () => <SmartSearchHit>[]).add(h);
      }
      final kinds = byKind.keys.toList()
        ..sort((a, b) =>
            byKind[b]!.first.score.compareTo(byKind[a]!.first.score));
      for (final kind in kinds) {
        children.add(_sectionHeader(_sectionTitle(kind), secondary));
        for (final h in byKind[kind]!.take(kind == kinds.first ? 8 : 5)) {
          children.add(_ResultRow(
            hit: h,
            subtitle: _subtitleOf(h.item),
            secondary: secondary,
            accent: cs.primary,
            avatarPath: _avatarOf(h.item),
            onTap: () => _open(h.item),
          ));
        }
      }
      if (_messageHits.isNotEmpty || _searchingMessages) {
        children.add(_sectionHeader(
          _t('Сообщения', 'Messages', 'Повідомлення', 'Mensajes', 'Mensagens',
              'Messages', 'Nachrichten'),
          secondary,
          trailing: _searchingMessages
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : null,
        ));
        for (final m in _messageHits) {
          final room = _isRoom(m.convo);
          children.add(_ResultRow(
            hit: SmartSearchHit(
              item: SmartSearchItem(
                id: m.convo.convoId,
                kind: room ? SmartSearchKind.room : SmartSearchKind.chat,
                title: _titleOf(m.convo),
              ),
              score: 0,
            ),
            subtitle: m.snippet,
            subtitleHighlight: query,
            secondary: secondary,
            accent: cs.primary,
            avatarPath: m.convo.avatarPath,
            onTap: () => _openMessage(m),
          ));
        }
      }
      // Люди на сервере по нику — только в Контактах.
      final known = {for (final h in _hits) h.item.id};
      final global = _globalHits
          .where((r) => !known.contains(r.profileId))
          .toList(growable: false);
      if (_peopleSearch &&
          (global.isNotEmpty || _globalLoading || _globalError != null)) {
        children.add(_sectionHeader(
          _t('Глобальный поиск', 'Global search', 'Глобальний пошук',
              'Búsqueda global', 'Pesquisa global', 'Recherche globale',
              'Globale Suche'),
          secondary,
          trailing: _globalLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : null,
        ));
        if (_globalError != null && global.isEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 6),
            child: Text(
              _globalError!,
              style: TextStyle(fontSize: 14, color: secondary),
            ),
          ));
        }
        for (final r in global) {
          final nick = (r.nickname ?? '').trim();
          final title = nick.isEmpty ? r.profileId : nick;
          children.add(_GlobalRow(
            title: title,
            subtitle: '@${r.profileId}',
            seed: r.profileId,
            secondary: secondary,
            known: r.alreadyInContacts,
            chatLabel: context.l10n.contactDetailsChat,
            addLabel: context.l10n.add,
            onChat: () => _open(SmartSearchItem(
              id: r.profileId,
              kind: SmartSearchKind.contact,
              title: title,
              handle: r.profileId,
            )),
            onAdd: () => _addFound(r),
          ));
        }
      }
      if (_hits.isEmpty &&
          _messageHits.isEmpty &&
          !_searchingMessages &&
          global.isEmpty &&
          !_globalLoading) {
        children.add(_NothingFound(secondary: secondary, query: query));
      }
    }

    return ColoredBox(
      color: bg,
      child: NotificationListener<ScrollStartNotification>(
        // Листнул результаты — убрать клавиатуру, как в iOS.
        onNotification: (n) {
          if (n.dragDetails != null) widget.islands.focus.unfocus();
          return false;
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            0,
            top + 10,
            0,
            widget.bottomReserve + 24,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          children: children,
        ),
      ),
    );
  }

  String? _avatarOf(SmartSearchItem item) {
    if (item.kind == SmartSearchKind.contact) {
      for (final p in _contacts) {
        if (p.profileId == item.id) return p.avatarPath;
      }
      return null;
    }
    for (final c in _convos) {
      if (c.convoId == item.id) return c.avatarPath;
    }
    return null;
  }

  String _subtitleOf(SmartSearchItem item) {
    final handle = (item.handle ?? '').trim();
    switch (item.kind) {
      case SmartSearchKind.room:
        return _t('Комната', 'Room', 'Кімната', 'Sala', 'Sala', 'Salon',
            'Raum');
      case SmartSearchKind.contact:
        return handle.isEmpty ? context.l10n.tabContacts : '@$handle';
      case SmartSearchKind.chat:
        if (widget.controller.isSavedMessagesConvo(item.id)) {
          return _t('Заметки для себя', 'Notes to self', 'Нотатки для себе',
              'Notas para mí', 'Notas para mim', 'Notes perso',
              'Notizen an mich');
        }
        return handle.isEmpty ? context.l10n.tabChats : '@$handle';
    }
  }

  Widget _sectionHeader(String title, Color secondary, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: secondary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  List<Widget> _buildRecents(BuildContext context, Color secondary) {
    final items = {for (final i in _items()) '${i.kind.name}|${i.id}': i};
    final recent = [
      for (final r in _recents)
        if (items[r] != null) items[r]!,
    ].take(8).toList();
    if (recent.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          child: Text(
            _t(
              'Ищите сразу по чатам, комнатам, контактам и сообщениям. '
                  'Можно набрать инициалы, @ник или ошибиться раскладкой.',
              'Search chats, rooms, contacts and messages at once. Initials, '
                  '@username or the wrong keyboard layout work too.',
              'Шукайте одразу в чатах, кімнатах, контактах і повідомленнях. '
                  'Можна ввести ініціали, @нік або помилитися розкладкою.',
              'Busca en chats, salas, contactos y mensajes a la vez. También '
                  'sirven las iniciales, el @usuario o un teclado equivocado.',
              'Pesquise em chats, salas, contatos e mensagens ao mesmo tempo. '
                  'Iniciais, @usuário ou o teclado errado também funcionam.',
              'Cherchez dans les discussions, salons, contacts et messages à '
                  'la fois. Initiales, @pseudo ou mauvais clavier : ça marche.',
              'Durchsuche Chats, Räume, Kontakte und Nachrichten auf einmal. '
                  'Initialen, @Name oder falsches Tastaturlayout gehen auch.',
            ),
            style: TextStyle(fontSize: 15, height: 1.45, color: secondary),
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 14, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _t('Недавние', 'Recent', 'Нещодавні', 'Recientes', 'Recentes',
                    'Récents', 'Zuletzt'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _clearRecents,
              child: Text(_t('Очистить', 'Clear', 'Очистити', 'Borrar',
                  'Limpar', 'Effacer', 'Löschen')),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: LayoutBuilder(
          builder: (context, c) {
            final cell = c.maxWidth / 4;
            return Wrap(
              runSpacing: 14,
              children: [
                for (final item in recent)
                  SizedBox(
                    width: cell,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _open(item),
                      child: Column(
                        children: [
                          _SearchAvatar(
                            title: item.title,
                            seed: item.id,
                            path: _avatarOf(item),
                            size: 58,
                            square: item.kind == SmartSearchKind.room,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: secondary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ];
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.hit,
    required this.subtitle,
    required this.secondary,
    required this.accent,
    required this.avatarPath,
    required this.onTap,
    this.subtitleHighlight,
  });

  final SmartSearchHit hit;
  final String subtitle;
  final String? subtitleHighlight;
  final Color secondary;
  final Color accent;
  final String? avatarPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = hit.item;
    const titleStyle = TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600);
    final title = item.title;
    final s = hit.highlightStart, e = hit.highlightEnd;
    final titleSpan = (s != null && e != null && e <= title.length && s < e)
        ? TextSpan(children: [
            TextSpan(text: title.substring(0, s)),
            TextSpan(
              text: title.substring(s, e),
              style: TextStyle(color: accent),
            ),
            TextSpan(text: title.substring(e)),
          ])
        : TextSpan(text: title);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
        child: Row(
          children: [
            _SearchAvatar(
              title: title,
              seed: item.id,
              path: avatarPath,
              size: 48,
              square: item.kind == SmartSearchKind.room,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    titleSpan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    _subtitleSpan(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: secondary),
                  ),
                ],
              ),
            ),
            if (item.unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 21),
                height: 21,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: item.muted ? secondary : accent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.unread > 99 ? '99+' : '${item.unread}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextSpan _subtitleSpan() {
    final q = (subtitleHighlight ?? '').trim();
    if (q.isEmpty) return TextSpan(text: subtitle);
    final at = subtitle.toLowerCase().indexOf(q.toLowerCase());
    if (at < 0) return TextSpan(text: subtitle);
    return TextSpan(children: [
      TextSpan(text: subtitle.substring(0, at)),
      TextSpan(
        text: subtitle.substring(at, at + q.length),
        style: TextStyle(color: accent, fontWeight: FontWeight.w600),
      ),
      TextSpan(text: subtitle.substring(at + q.length)),
    ]);
  }
}

/// Человек из глобального поиска: «Чат», если он уже в контактах, иначе
/// «Добавить» — как в прежнем поиске раздела Контакты.
class _GlobalRow extends StatelessWidget {
  const _GlobalRow({
    required this.title,
    required this.subtitle,
    required this.seed,
    required this.secondary,
    required this.known,
    required this.chatLabel,
    required this.addLabel,
    required this.onChat,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final String seed;
  final Color secondary;
  final bool known;
  final String chatLabel;
  final String addLabel;
  final VoidCallback onChat;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: known ? onChat : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
        child: Row(
          children: [
            _SearchAvatar(
              title: title,
              seed: seed,
              path: null,
              size: 48,
              square: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            known
                ? FilledButton.tonal(onPressed: onChat, child: Text(chatLabel))
                : FilledButton(onPressed: onAdd, child: Text(addLabel)),
          ],
        ),
      ),
    );
  }
}

/// Портрет в результатах: фото или заглушка. Комнаты — скруглённый квадрат,
/// люди — круг.
class _SearchAvatar extends StatelessWidget {
  const _SearchAvatar({
    required this.title,
    required this.seed,
    required this.path,
    required this.size,
    required this.square,
  });

  final String title;
  final String seed;
  final String? path;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final p = (path ?? '').trim();
    final radius = BorderRadius.circular(square ? size * 0.3 : size / 2);
    final Widget child;
    if (p.isNotEmpty && FileExistsCache.exists(p)) {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
      child = Image(
        image: ResizeImage(FileImage(File(p)), width: (size * dpr).round()),
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
      );
    } else {
      final ink = AvatarInitials.colors(context, seed: seed);
      child = ColoredBox(
        color: ink.fill,
        child: Center(
          child: Text(
            AvatarInitials.label(displayName: title, fallbackId: seed),
            style: TextStyle(
              color: ink.ink,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.secondary, required this.query});

  final Color secondary;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 0),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: secondary),
          const SizedBox(height: 12),
          Text(
            wave1Text(
              context,
              ru: 'Ничего не найдено',
              en: 'No results',
              uk: 'Нічого не знайдено',
              es: 'Sin resultados',
              pt: 'Nenhum resultado',
              ptBr: 'Nenhum resultado',
              fr: 'Aucun résultat',
              de: 'Keine Ergebnisse',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '«$query»',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: secondary),
          ),
        ],
      ),
    );
  }
}
