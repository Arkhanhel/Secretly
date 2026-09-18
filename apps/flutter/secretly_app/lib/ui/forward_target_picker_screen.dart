// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import 'chat_screen_l10n.dart';
import 'icons/app_icons.dart';
import 'widgets/avatar_initials.dart';

/// Full-screen «Переслать…» target picker. Returns the chosen [Conversation]
/// (or null if cancelled). Tabs: «Чаты» (all non-archived), «Комнаты» (groups),
/// «Личные» (personal + archived). A search box filters across the active tab.
class ForwardTargetPickerScreen extends StatefulWidget {
  const ForwardTargetPickerScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ForwardTargetPickerScreen> createState() =>
      _ForwardTargetPickerScreenState();
}

enum _ForwardTab { all, rooms, personal }

class _ForwardTargetPickerScreenState extends State<ForwardTargetPickerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _search = TextEditingController();
  List<Conversation> _conversations = const <Conversation>[];
  Set<String> _personalIds = <String>{};
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _search.addListener(() {
      if (_query != _search.text.trim()) {
        setState(() => _query = _search.text.trim());
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final convos = await widget.controller.listConversations();
      if (!mounted) return;
      setState(() {
        _conversations = convos;
        _personalIds = widget.controller.personalConvoIds;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool _isGroup(Conversation c) => c.convoId.startsWith('group:');
  bool _isArchived(Conversation c) => c.archivedAtMs != null;
  bool _isPersonal(Conversation c) =>
      _personalIds.contains(c.convoId) || _isArchived(c);

  List<Conversation> _forTab(_ForwardTab tab) {
    final query = _query.toLowerCase();
    final base = _conversations.where((c) {
      switch (tab) {
        case _ForwardTab.all:
          return !_isArchived(c);
        case _ForwardTab.rooms:
          return _isGroup(c) && !_isArchived(c);
        case _ForwardTab.personal:
          return _isPersonal(c);
      }
    });
    final filtered = query.isEmpty
        ? base
        : base.where((c) => c.title.toLowerCase().contains(query));
    final list = filtered.toList(growable: false)
      ..sort((a, b) => b.lastEventAtMs.compareTo(a.lastEventAtMs));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(chatText(context, ru: 'Переслать…', en: 'Forward to…')),
        bottom: TabBar(
          controller: _tabs,
          tabs: <Widget>[
            Tab(text: chatText(context, ru: 'Чаты', en: 'Chats')),
            Tab(text: chatText(context, ru: 'Комнаты', en: 'Rooms')),
            Tab(text: chatText(context, ru: 'Личные', en: 'Personal')),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(AppIcons.search, size: 20),
                hintText: chatText(
                  context,
                  ru: 'Поиск чатов',
                  en: 'Search chats',
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: <Widget>[
                      _buildList(_forTab(_ForwardTab.all)),
                      _buildList(_forTab(_ForwardTab.rooms)),
                      _buildList(_forTab(_ForwardTab.personal)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Conversation> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          chatText(context, ru: 'Ничего не найдено', en: 'Nothing found'),
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final c = items[index];
        return ListTile(
          leading: _ForwardAvatar(
            title: c.title,
            avatarPath: c.avatarPath,
            seed: c.convoId,
          ),
          title: Text(
            c.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: _isGroup(c)
              ? Text(chatText(context, ru: 'Комната', en: 'Room'))
              : null,
          onTap: () => Navigator.of(context).pop<Conversation>(c),
        );
      },
    );
  }
}

class _ForwardAvatar extends StatelessWidget {
  const _ForwardAvatar({
    required this.title,
    required this.seed,
    this.avatarPath,
  });

  final String title;
  final String seed;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final path = avatarPath?.trim() ?? '';
    if (path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(radius: 22, backgroundImage: FileImage(File(path)));
    }
    final fallback = AvatarInitials.colors(context, seed: seed);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fallback.fill),
      child: Text(
        AvatarInitials.label(displayName: title, fallbackId: seed),
        style: TextStyle(
          color: fallback.ink,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}
