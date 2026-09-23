// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../app/app_controller.dart';
import '../../../models/e2e_payload_v1.dart';
import '../../../security/app_security_manager.dart' show SecurityLockScope;
import '../chat/details/desktop_selection_store.dart';
import 'desktop_file_match.dart';
import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../shell/sidebar.dart' show DesktopSection;
import '../shell/window_chrome.dart' show desktopSearchScopeLabel;

/// Cmd+K spotlight palette: a modal overlay that lets the user fuzzy-find
/// across conversations and section shortcuts, then jumps to the picked
/// chat / section.
///
/// Wiring (see desktop_production_app.dart):
///   • Cmd+K (shell-level shortcut) → `_openSpotlight()`
///   • on chat pick → set the matching selection-store + switch section
///   • Esc / backdrop tap → close
///
/// The widget is intentionally self-contained: it does its own data load via
/// [AppController.listConversations] when mounted, so the palette stays
/// responsive even before the surrounding section is mounted.
class SpotlightPalette extends StatefulWidget {
  const SpotlightPalette({
    super.key,
    required this.controller,
    required this.chatsSelection,
    required this.roomsSelection,
    required this.selectSection,
    required this.onClose,
    this.onOpenSettings,
    this.onOpenProfile,
    this.onOpenProfileChat,
  });

  final AppController controller;
  final DesktopChatSelectionStore chatsSelection;
  final DesktopChatSelectionStore roomsSelection;
  final ValueChanged<DesktopSection> selectSection;
  final VoidCallback onClose;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenProfile;

  /// Открыть (при необходимости — завести) переписку с профилем. Так палитра
  /// доводит найденного человека до чата: иначе «нашёл» означало бы «увидел
  /// строку и ничего не может сделать».
  final ValueChanged<String>? onOpenProfileChat;

  @override
  State<SpotlightPalette> createState() => _SpotlightPaletteState();
}

class _SpotlightPaletteState extends State<SpotlightPalette> {
  /// Подписи окна поиска.
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _rootFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  List<Conversation> _conversations = const [];

  /// Собеседники ВСЕХ переписок, включая скрытые личные: человек с закрытым
  /// личным чатом не должен всплыть строкой «контакт без переписки».
  Set<String> _knownPeerIds = const <String>{};

  /// 🔴 ЛЮДИ, С КОТОРЫМИ ПЕРЕПИСКИ ЕЩЁ НЕТ (14.09.2026).
  ///
  /// Поле в шапке обещает поиск «по чатам и людям», а искало только переписки:
  /// человека из контактов, которому ещё ни разу не писали, палитра не находила
  /// ни разу. Обещание в приглашении — тоже обещание.
  List<Contact> _contacts = const [];
  String _query = '';
  int _cursor = 0;
  bool _loading = true;

  // ---- F-04: global message search ----
  //
  // Bounded on purpose. `searchChatMatches` reads a conversation's newest-200
  // window and filters in memory, so an unbounded sweep across every chat
  // would stall the palette on each keystroke. We debounce, walk conversations
  // most-recent-first, and stop at the caps below — the hits people want are
  // overwhelmingly in recent chats, and a fast partial answer beats a slow
  // complete one in a command palette.
  static const int _kMaxConvosScanned = 25;
  static const int _kMaxMessageHits = 12;
  static const int _kMinQueryLength = 2;

  List<_SpotlightEntry> _messageHits = const [];
  bool _searchingMessages = false;

  // ---- Поиск ПО ФАЙЛАМ ----
  //
  // 🔴 Шапка обещает поиск по чатам, людям и сообщениям — а вложений не
  // находил никто: `searchChatMatches` работает по ТЕКСТУ сообщения, и
  // присланный «договор.pdf» был для поиска невидим. Имя файла лежит внутри
  // зашифрованного груза, указателя по нему нет, поэтому обход свой.
  //
  // Обход дороже текстового: на каждое событие — разбор груза. Поэтому
  // переписок берём вдвое меньше. Выдача всё равно нужна быстрая и неполная,
  // а не полная и медленная: искомый файл почти всегда в свежих переписках.
  static const int _kMaxConvosScannedForFiles = 12;
  static const int _kMaxFileHits = 8;

  List<_SpotlightEntry> _fileHits = const [];
  bool _searchingFiles = false;

  /// Guards against a slow search for an old query overwriting a newer one.
  int _searchSeq = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtl.addListener(() {
      final q = _searchCtl.text;
      if (q == _query) return;
      setState(() {
        _query = q;
        _cursor = 0;
      });
      _scheduleMessageSearch(q);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtl.dispose();
    _searchFocus.dispose();
    _rootFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Debounces message search so typing does not fire a sweep per keystroke.
  void _scheduleMessageSearch(String rawQuery) {
    _searchDebounce?.cancel();
    final q = rawQuery.trim();
    if (q.length < _kMinQueryLength) {
      // Bump the sequence so any in-flight search discards its result.
      _searchSeq++;
      if (_messageHits.isNotEmpty ||
          _fileHits.isNotEmpty ||
          _searchingMessages ||
          _searchingFiles) {
        setState(() {
          _messageHits = const [];
          _fileHits = const [];
          _searchingMessages = false;
          _searchingFiles = false;
        });
      }
      return;
    }
    setState(() {
      _searchingMessages = true;
      _searchingFiles = true;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      final seq = ++_searchSeq;
      // Два обхода идут рядом и НЕ ждут друг друга: текст находится быстрее,
      // и держать его до конца файлового обхода значило бы показать пустую
      // палитру там, где ответ уже есть.
      unawaited(_runMessageSearch(q, seq));
      unawaited(_runFileSearch(q, seq));
    });
  }

  /// Sweeps recent conversations for message-body hits.
  ///
  /// Yields between conversations so the palette keeps painting, and abandons
  /// the sweep the moment a newer query supersedes it.
  Future<void> _runMessageSearch(String query, int seq) async {
    final convos = List<Conversation>.from(
      _conversations.where((c) => c.archivedAtMs == null),
    )..sort((a, b) => b.lastEventAtMs.compareTo(a.lastEventAtMs));

    final hits = <_SpotlightEntry>[];
    var scanned = 0;
    for (final convo in convos) {
      if (!mounted || seq != _searchSeq) return; // superseded
      if (scanned >= _kMaxConvosScanned || hits.length >= _kMaxMessageHits) {
        break;
      }
      scanned++;
      try {
        final matches = await widget.controller.searchChatMatches(
          convoId: convo.convoId,
          query: query,
          limit: _kMaxMessageHits,
        );
        for (final m in matches) {
          if (hits.length >= _kMaxMessageHits) break;
          final snippet = _snippet(m.text, m.matchStart);
          if (snippet.isEmpty) continue;
          hits.add(
            _SpotlightEntry.message(l10n: l10n, conversation: convo, snippet: snippet),
          );
        }
      } catch (_) {
        // A single unreadable conversation must not kill the whole search.
      }
    }

    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _messageHits = List<_SpotlightEntry>.unmodifiable(hits);
      _searchingMessages = false;
    });
  }

  /// Обход вложений: имя файла, теги музыки, подпись.
  ///
  /// Устроен так же, как текстовый: свежие переписки первыми, обрыв по
  /// пределам, отмена по номеру запроса. Отличие одно — груз каждого события
  /// приходится разбирать, поэтому переписок берётся вдвое меньше.
  ///
  /// Нечитаемое событие и нечитаемая переписка пропускаются молча: одна
  /// сломанная строка не должна уносить с собой весь поиск.
  Future<void> _runFileSearch(String query, int seq) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      if (mounted && seq == _searchSeq) setState(() => _searchingFiles = false);
      return;
    }
    final convos = List<Conversation>.from(
      _conversations.where((c) => c.archivedAtMs == null),
    )..sort((a, b) => b.lastEventAtMs.compareTo(a.lastEventAtMs));

    final hits = <_SpotlightEntry>[];
    var scanned = 0;
    for (final convo in convos) {
      if (!mounted || seq != _searchSeq) return; // запрос устарел
      if (scanned >= _kMaxConvosScannedForFiles || hits.length >= _kMaxFileHits) {
        break;
      }
      scanned++;
      try {
        final events = await widget.controller.loadEvents(convo.convoId);
        for (final event in events) {
          if (!mounted || seq != _searchSeq) return;
          if (hits.length >= _kMaxFileHits) break;
          AttachmentEventV1 attachment;
          try {
            final payload = await widget.controller.payloadEventForChatEvent(
              event,
            );
            if (payload is! AttachmentEventV1) continue;
            attachment = payload;
          } catch (_) {
            continue; // одно нечитаемое событие
          }
          if (!attachmentMatchesQuery(attachment, q)) continue;
          final name = attachmentDisplayName(attachment);
          if (name.isEmpty) continue;
          hits.add(
            _SpotlightEntry.file(
              l10n: l10n,
              conversation: convo,
              name: name,
              meta: attachmentMetaLine(attachment, l10n),
            ),
          );
        }
      } catch (_) {
        // одна нечитаемая переписка не должна убивать весь обход
      }
    }

    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _fileHits = List<_SpotlightEntry>.unmodifiable(hits);
      _searchingFiles = false;
    });
  }

  static String _snippet(String text, int matchStart) =>
      spotlightSnippet(text, matchStart);

  Future<void> _load() async {
    try {
      final convos = await widget.controller.listConversations();
      List<Contact> contacts = const <Contact>[];
      try {
        contacts = await widget.controller.listContacts();
      } catch (_) {
        // Контакты — добавка к поиску: без них палитра работает как прежде.
      }
      if (!mounted) return;
      // 🔴 ЗАКРЫТЫЕ «ЛИЧНЫЕ» В ПОИСК НЕ ПОПАДАЮТ (17.09.2026).
      //
      // Палитра обходила все переписки, и ⌘K показывал названия и куски
      // текста личных чатов, спрятанных за паролем: пароль был декорацией,
      // ровно как в списке до его исправления. Пока область заперта, их нет
      // ни в названиях, ни в тексте, ни в файлах — все три обхода идут по
      // этому списку.
      final visible = spotlightSearchableConversations(
        convos,
        personalLocked: widget.controller.security.isLocked(
          SecurityLockScope.personal,
        ),
        isPersonal: widget.controller.isPersonalChat,
      );
      setState(() {
        _conversations = visible;
        _knownPeerIds = <String>{
          for (final c in convos)
            if ((c.peerProfileId ?? '').trim().isNotEmpty)
              c.peerProfileId!.trim(),
        };
        _contacts = contacts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ---------------- Result computation ----------------

  /// Computed entries shown in the palette. Order = matched chats first
  /// (sorted by last-event), then section quick-actions.
  List<_SpotlightEntry> _entries() {
    final q = _query.trim().toLowerCase();
    final out = <_SpotlightEntry>[];

    // Chats / Rooms.
    final chats = <Conversation>[];
    for (final c in _conversations) {
      if (c.archivedAtMs != null) continue;
      if (q.isEmpty || c.title.toLowerCase().contains(q)) {
        chats.add(c);
      }
    }
    chats.sort((a, b) => b.lastEventAtMs.compareTo(a.lastEventAtMs));
    // Cap chat results so the action rows always remain visible/searchable.
    final maxChats = q.isEmpty ? 8 : 20;
    for (final c in chats.take(maxChats)) {
      out.add(_SpotlightEntry.chat(c, l10n));
    }

    // Люди из контактов, с которыми переписки ещё НЕТ. Те, с кем есть, уже
    // стоят выше строкой чата — показывать их дважды значит засорить выдачу.
    if (q.isNotEmpty) {
      final known = _knownPeerIds;
      var shown = 0;
      for (final contact in _contacts) {
        if (shown >= 8) break;
        final pid = contact.profileId.trim();
        if (pid.isEmpty || known.contains(pid)) continue;
        final name = (contact.displayName ?? '').trim();
        final haystack = '$name $pid'.toLowerCase();
        if (!haystack.contains(q)) continue;
        shown++;
        out.add(
          _SpotlightEntry.contact(
            l10n: l10n,
            profileId: pid,
            name: name.isEmpty ? pid : name,
            onActivate: () {
              widget.onClose();
              widget.onOpenProfileChat?.call(pid);
            },
          ),
        );
      }
    }

    // F-04: message-body hits, below the chats they belong to. Populated
    // asynchronously, so they simply appear as the sweep completes.
    out.addAll(_messageHits);

    // Файлы — своим обходом и своей строкой: «имя · тип · размер».
    out.addAll(_fileHits);

    // Section quick-actions (only when query is empty or matches the label).
    void addAction({
      required String label,
      required IconData icon,
      required VoidCallback onActivate,
    }) {
      if (q.isNotEmpty && !label.toLowerCase().contains(q)) return;
      out.add(
        _SpotlightEntry.action(
          l10n: l10n,
          label: label,
          icon: icon,
          onActivate: onActivate,
        ),
      );
    }

    addAction(
      label: l10n.desktopSpotlightGoChats,
      icon: FluentIcons.chat_24_regular,
      onActivate: () => _jumpToSection(DesktopSection.chats),
    );
    addAction(
      label: l10n.desktopSpotlightGoRooms,
      icon: FluentIcons.people_24_regular,
      onActivate: () => _jumpToSection(DesktopSection.rooms),
    );
    addAction(
      label: l10n.desktopSpotlightGoContacts,
      icon: FluentIcons.person_24_regular,
      onActivate: () => _jumpToSection(DesktopSection.contacts),
    );
    addAction(
      label: l10n.desktopSpotlightGoCalls,
      icon: FluentIcons.call_24_regular,
      onActivate: () => _jumpToSection(DesktopSection.calls),
    );
    if (widget.onOpenSettings != null) {
      addAction(
        label: l10n.desktopSettingsTitle,
        icon: FluentIcons.settings_24_regular,
        onActivate: () {
          widget.onClose();
          widget.onOpenSettings!.call();
        },
      );
    }
    if (widget.onOpenProfile != null) {
      addAction(
        label: l10n.desktopAccountProfile,
        icon: FluentIcons.person_circle_24_regular,
        onActivate: () {
          widget.onClose();
          widget.onOpenProfile!.call();
        },
      );
    }

    return out;
  }

  // ---------------- Activation ----------------

  void _activate(_SpotlightEntry e) {
    // A message hit opens the conversation it lives in — same jump as picking
    // the chat directly.
    if ((e.kind == _SpotlightKind.chat || e.kind == _SpotlightKind.message) &&
        e.conversation != null) {
      _jumpToChat(e.conversation!);
      return;
    }
    e.onActivate();
  }

  void _jumpToChat(Conversation c) {
    final isGroup = c.peerProfileId == null;
    if (isGroup) {
      widget.roomsSelection.select(c);
      widget.selectSection(DesktopSection.rooms);
    } else {
      widget.chatsSelection.select(c);
      widget.selectSection(DesktopSection.chats);
    }
    widget.onClose();
  }

  void _jumpToSection(DesktopSection s) {
    widget.selectSection(s);
    widget.onClose();
  }

  // ---------------- Keyboard ----------------

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final entries = _entries();
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (entries.isNotEmpty) {
        setState(() => _cursor = (_cursor + 1) % entries.length);
        _ensureVisible();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (entries.isNotEmpty) {
        setState(
          () => _cursor = (_cursor - 1 + entries.length) % entries.length,
        );
        _ensureVisible();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (entries.isNotEmpty && _cursor < entries.length) {
        _activate(entries[_cursor]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _ensureVisible() {
    // Best-effort scroll-to-cursor; relies on a uniform row height of 56.
    if (!_scroll.hasClients) return;
    const rowH = 56.0;
    final target = _cursor * rowH;
    final pos = _scroll.position;
    if (target < pos.pixels) {
      _scroll.animateTo(
        target,
        duration: DMotion.fast,
        curve: DMotion.easeOutCubic,
      );
    } else if (target + rowH > pos.pixels + pos.viewportDimension) {
      _scroll.animateTo(
        target + rowH - pos.viewportDimension,
        duration: DMotion.fast,
        curve: DMotion.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final entries = _entries();
    if (_cursor >= entries.length) {
      _cursor = entries.isEmpty ? 0 : entries.length - 1;
    }

    return Focus(
      focusNode: _rootFocus,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          // Backdrop: tap to dismiss.
          Positioned.fill(
            child: Semantics(
                     button: true,
                     label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                     child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Container(color: const Color(0x99000000)),
              ),
                   ),
          ),
          // Centered card.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 480),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: DSpace.xl,
                    vertical: DSpace.xl,
                  ),
                  decoration: BoxDecoration(
                    color: c.elevated,
                    borderRadius: BorderRadius.circular(DRadii.lg),
                    border: Border.all(color: c.borderSubtle),
                    boxShadow: DShadows.dialog,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _searchField(c),
                      Container(height: 1, color: c.borderSubtle),
                      Flexible(
                        // 🔴 «НИЧЕГО НЕ НАЙДЕНО» — ТОЛЬКО КОГДА ОБХОДЫ
                        // ЗАКОНЧИЛИСЬ.
                        //
                        // Обходы идут секундами (сообщения и файлы
                        // расшифровываются по событию), и всё это время
                        // палитра писала «Ничего не найдено» над пустотой, а
                        // потом выкладывала находки. Ответ «нет» до того, как
                        // поиск закончен, — это неправда, и человек уходит,
                        // не дождавшись.
                        child: _loading
                            ? _loadingRow(c)
                            : (entries.isEmpty
                                  ? ((_searchingMessages || _searchingFiles)
                                        ? _loadingRow(c)
                                        : _emptyState(c))
                                  : ListView.builder(
                                      controller: _scroll,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: DSpace.xs,
                                      ),
                                      itemCount: entries.length,
                                      itemBuilder: (ctx, i) {
                                        return _SpotlightRow(
                                          entry: entries[i],
                                          selected: i == _cursor,
                                          onHover: () =>
                                              setState(() => _cursor = i),
                                          onTap: () => _activate(entries[i]),
                                        );
                                      },
                                    )),
                      ),
                      Container(height: 1, color: c.borderSubtle),
                      _footer(c),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(DColorSet c) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.l,
        vertical: DSpace.m,
      ),
      child: Row(
        children: [
          Icon(FluentIcons.search_24_regular, size: 20, color: c.textSecondary),
          const SizedBox(width: DSpace.s),
          Expanded(
            child: TextField(
              controller: _searchCtl,
              focusNode: _searchFocus,
              autofocus: true,
              style: DType.bodyStrong.copyWith(color: c.textPrimary),
              cursorColor: c.accentPrimary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '${desktopSearchScopeLabel(l10n)}…',
                hintStyle: DType.bodyStrong.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              onSubmitted: (_) {
                final entries = _entries();
                if (entries.isNotEmpty && _cursor < entries.length) {
                  _activate(entries[_cursor]);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingRow(DColorSet c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSpace.xl),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(c.accentPrimary),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(DColorSet c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSpace.xl),
      child: Center(
        child: Text(
          l10n.desktopListNothingFound,
          style: DType.body.copyWith(color: c.textSecondary),
        ),
      ),
    );
  }

  Widget _footer(DColorSet c) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.l,
        vertical: DSpace.s,
      ),
      child: Row(
        children: [
          _hint(c, '↑ ↓', l10n.desktopSpotlightSelect),
          const SizedBox(width: DSpace.m),
          _hint(c, 'Enter', l10n.desktopSpotlightOpen),
          const Spacer(),
          _hint(c, 'Esc', l10n.desktopSpotlightClose),
        ],
      ),
    );
  }

  Widget _hint(DColorSet c, String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: c.chatList,
            borderRadius: BorderRadius.circular(DRadii.sm),
            border: Border.all(color: c.borderSubtle),
          ),
          child: Text(
            key,
            style: DType.caption.copyWith(
              color: c.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: DType.caption.copyWith(color: c.textSecondary)),
      ],
    );
  }
}

// ---------- Entry + row ----------

class _SpotlightEntry {
  _SpotlightEntry._({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onActivate,
    this.conversation,
  });

  factory _SpotlightEntry.chat(Conversation c, AppLocalizations l10n) {
    return _SpotlightEntry._(
      kind: _SpotlightKind.chat,
      title: c.title.isEmpty ? '—' : c.title,
      subtitle: c.peerProfileId == null ? l10n.desktopSpotlightRoom : l10n.contactDetailsChat,
      icon: c.peerProfileId == null
          ? FluentIcons.people_24_regular
          : FluentIcons.chat_24_regular,
      onActivate: () {},
      conversation: c,
    );
  }

  /// F-04: a message-body hit. Carries its conversation so activating it opens
  /// the chat the message lives in.
  factory _SpotlightEntry.message({
    required AppLocalizations l10n,
    required Conversation conversation,
    required String snippet,
  }) {
    return _SpotlightEntry._(
      kind: _SpotlightKind.message,
      title: snippet,
      subtitle: conversation.title.isEmpty ? l10n.desktopSpotlightMessage : conversation.title,
      icon: FluentIcons.search_24_regular,
      onActivate: () {},
      conversation: conversation,
    );
  }

  /// Вложение: имя файла, под ним тип с размером и переписка, где он лежит.
  factory _SpotlightEntry.file({
    required AppLocalizations l10n,
    required Conversation conversation,
    required String name,
    required String meta,
  }) {
    final where = conversation.title.isEmpty ? l10n.file : conversation.title;
    return _SpotlightEntry._(
      kind: _SpotlightKind.message,
      title: name,
      subtitle: '$meta · $where',
      icon: FluentIcons.document_24_regular,
      onActivate: () {},
      conversation: conversation,
    );
  }

  /// Человек из контактов, с которым переписки ещё нет.
  factory _SpotlightEntry.contact({
    required AppLocalizations l10n,
    required String profileId,
    required String name,
    required VoidCallback onActivate,
  }) {
    return _SpotlightEntry._(
      kind: _SpotlightKind.action,
      title: name,
      subtitle: l10n.desktopMenuContact,
      icon: FluentIcons.person_24_regular,
      onActivate: onActivate,
    );
  }

  factory _SpotlightEntry.action({
    required AppLocalizations l10n,
    required String label,
    required IconData icon,
    required VoidCallback onActivate,
  }) {
    return _SpotlightEntry._(
      kind: _SpotlightKind.action,
      title: label,
      subtitle: l10n.desktopSpotlightCommand,
      icon: icon,
      onActivate: onActivate,
    );
  }

  final _SpotlightKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onActivate;
  final Conversation? conversation;
}

/// Переписки, по которым палитре можно искать: пока «Личные» заперты, их нет.
///
/// Отдельной функцией, чтобы правило проверялось напрямую, без контроллера.
List<Conversation> spotlightSearchableConversations(
  List<Conversation> all, {
  required bool personalLocked,
  required bool Function(String convoId) isPersonal,
}) {
  if (!personalLocked) return all;
  return all.where((c) => !isPersonal(c.convoId)).toList(growable: false);
}

/// Trims a search match down to one readable line centred on the hit.
///
/// Top-level and public so the index arithmetic — the part that actually
/// breaks, especially on a match near either end of a long message — is
/// directly testable. Collapses whitespace so a multi-line message cannot
/// blow up a single-line palette row.
String spotlightSnippet(String text, int matchStart) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return '';
  const window = 72;
  if (flat.length <= window) return flat;
  // Keep a little context before the match, but never run off either end.
  final maxStart = flat.length - window;
  final start = (matchStart - 24).clamp(0, maxStart < 0 ? 0 : maxStart);
  final end = (start + window).clamp(0, flat.length);
  final core = flat.substring(start, end).trim();
  return '${start > 0 ? '…' : ''}$core${end < flat.length ? '…' : ''}';
}

enum _SpotlightKind { chat, message, action }

class _SpotlightRow extends StatelessWidget {
  const _SpotlightRow({
    required this.entry,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  final _SpotlightEntry entry;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final isChat = entry.kind == _SpotlightKind.chat;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: DSpace.l),
          color: selected
              ? c.accentPrimary.withValues(alpha: 0.12)
              : Colors.transparent,
          child: Row(
            children: [
              if (isChat && entry.conversation != null)
                Avatar(
                  name: entry.title,
                  size: 32,
                  shape: entry.conversation!.peerProfileId == null
                      ? AvatarShape.room
                      : AvatarShape.round,
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.chatList,
                    borderRadius: BorderRadius.circular(DRadii.md),
                    border: Border.all(color: c.borderSubtle),
                  ),
                  child: Icon(entry.icon, size: 18, color: c.textPrimary),
                ),
              const SizedBox(width: DSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.bodyStrong.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.caption.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  FluentIcons.arrow_right_24_regular,
                  size: 18,
                  color: c.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
