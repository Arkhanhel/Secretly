// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../app/app_controller.dart';
import 'desktop_app_view_model.dart';
import 'desktop_selector.dart';
import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_text_field.dart';
import '../primitives/desktop_tooltip.dart';
import '../shell/desktop_shell.dart' show DesktopShellApi;
import '../shell/list_thread_split.dart';

/// Contacts section reading [AppController.listContacts] on the desktop
/// production build. Sorted alphabetically with a search field; selecting a
/// contact shows its card on the right, and «Написать сообщение» opens (creating
/// if needed) the 1:1 chat with that profile and jumps to the Chats section via
/// [onOpenChat].
class DesktopContactsSection extends StatefulWidget {
  const DesktopContactsSection({
    super.key,
    required this.vm,
    this.onOpenChat,
    this.shellApi,
  });

  /// Ширина левой колонки и ручка её края — общие с чатами, см.
  /// [ListThreadSplit]. `null` — колонка прежней ширины и не тянется.
  final DesktopShellApi? shellApi;

  /// The controller seam. [controller] is derived from it, so every
  /// `widget.controller` use site below keeps working unchanged.
  final DesktopAppViewModel vm;
  AppController get controller => vm.controller;

  /// Opens (creating if needed) the 1:1 chat with the given profile id and
  /// switches to the Chats section. Wired by the shell host.
  final ValueChanged<String>? onOpenChat;

  @override
  State<DesktopContactsSection> createState() => _DesktopContactsSectionState();
}

class _DesktopContactsSectionState extends State<DesktopContactsSection> {
  final TextEditingController _searchCtrl = TextEditingController();

  /// The contact list, loaded once per settled burst of controller ticks and
  /// republished only when a contact actually looks different.
  ///
  /// This used to run `listContacts()` on EVERY `changed` tick and rebuild
  /// unconditionally — `changed` fires on the outbox pump and presence
  /// heartbeats, none of which touch the address book.
  late final DesktopSelector<List<Contact>> _contactsSel;

  List<Contact> _contacts = const [];
  String _query = '';
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _contactsSel = widget.vm.select<List<Contact>>(
      debugName: 'contacts',
      initial: const <Contact>[],
      load: _loadContacts,
      signature: _contactsSignature,
    )..addListener(_onContacts);
  }

  @override
  void dispose() {
    _contactsSel.removeListener(_onContacts);
    _contactsSel.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Contact>> _loadContacts() async {
    final list = await widget.controller.listContacts();
    list.sort((a, b) => _displayName(a)
        .toLowerCase()
        .compareTo(_displayName(b).toLowerCase()));
    return list;
  }

  /// Every field of [Contact], because the row and the details pane between
  /// them render all of it. Nine fields — small enough that "all of them" is
  /// verifiably complete, rather than a subset that drifts.
  String _contactsSignature(List<Contact> list) {
    final buffer = StringBuffer()..write(list.length);
    for (final c in list) {
      buffer
        // Unit separator: cannot occur inside an id or a name.
        ..write('\u001f')
        ..write(c.profileId)
        ..write(c.displayName ?? '')
        ..write(c.avatarPath ?? '')
        ..write(c.emoji ?? '')
        ..write(c.emojiStatus ?? '')
        ..write(c.premiumBadge)
        ..write(c.frameId ?? '')
        ..write(c.coverId ?? '')
        ..write(c.coverImagePath ?? '');
    }
    return buffer.toString();
  }

  void _onContacts() {
    if (!mounted) return;
    setState(() => _contacts = _contactsSel.value);
  }

  String _displayName(Contact c) {
    final n = (c.displayName ?? '').trim();
    return n.isEmpty ? c.profileId : n;
  }

  List<Contact> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts.where((c) {
      return _displayName(c).toLowerCase().contains(q) ||
          c.profileId.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final filtered = _filtered;

    final list = _listColumn(c, filtered);
    final details = _ContactDetails(
      contact: _selectedById(_selectedId),
      displayName: _selectedById(_selectedId) == null
          ? ''
          : _displayName(_selectedById(_selectedId)!),
      onMessage: widget.onOpenChat,
    );
    // Левая колонка — общая с чатами: та же ширина и тот же край, который
    // тянется. `shellApi == null` — прежняя неподвижная колонка.
    final api = widget.shellApi;
    if (api != null) {
      return ListThreadSplit.fromApi(
        api,
        list: list,
        thread: details,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 320, child: list),
        Container(width: 1, color: c.borderSubtle),
        Expanded(child: details),
      ],
    );
  }

  Widget _listColumn(DColorSet c, List<Contact> filtered) {
    final api = widget.shellApi;
    if (api != null && api.listCompact) return _compactColumn(c, api);
    return Container(
      color: c.chatList,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(DSpace.m),
            child: DesktopTextField(
              controller: _searchCtrl,
              hintText: 'Поиск контактов',
              prefixIcon: FluentIcons.search_24_regular,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: !_contactsSel.hasLoaded
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation(c.accentPrimary),
                      ),
                    ),
                  )
                : filtered.isEmpty
                    ? _EmptyList(query: _query)
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final contact = filtered[i];
                          return _ContactRow(
                            contact: contact,
                            displayName: _displayName(contact),
                            selected:
                                _selectedId == contact.profileId,
                            onTap: () => setState(() =>
                                _selectedId = contact.profileId),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// Столбик портретов — как свёрнутый список чатов. Поиска в нём нет —
  /// значит, и фильтр по слову не действует: лупа разворачивает колонку.
  Widget _compactColumn(DColorSet c, DesktopShellApi api) {
    final expand = api.onListExpand;
    return Container(
      color: c.chatList,
      child: Column(
        children: [
          SizedBox(
            height: 60,
            child: Center(
              child: expand == null
                  ? Icon(
                      FluentIcons.people_24_regular,
                      size: 20,
                      color: c.textSecondary,
                    )
                  : DesktopIconButton(
                      icon: FluentIcons.search_24_regular,
                      tooltip: 'Поиск контактов',
                      size: 30,
                      iconSize: 17,
                      onPressed: expand,
                    ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: DSpace.p5,
                vertical: DSpace.xs,
              ),
              itemCount: _contacts.length,
              itemBuilder: (ctx, i) {
                final contact = _contacts[i];
                return _ContactRow(
                  contact: contact,
                  displayName: _displayName(contact),
                  selected: _selectedId == contact.profileId,
                  compact: true,
                  onTap: () => setState(() => _selectedId = contact.profileId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Contact? _selectedById(String? pid) {
    if (pid == null) return null;
    for (final c in _contacts) {
      if (c.profileId == pid) return c;
    }
    return null;
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.displayName,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final Contact contact;
  final String displayName;
  final bool selected;
  final VoidCallback onTap;

  /// Столбик портретов: имя — в подсказке.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (compact) {
      return DesktopTooltip(
        message: displayName,
        child: Material(
          color: selected ? c.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(DRadii.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: c.hover,
            child: SizedBox(
              height: 52,
              child: Center(
                child: Avatar(
                  name: displayName,
                  image: _avatarImage(contact.avatarPath),
                  size: 36,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: selected ? c.selected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: c.hover,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DSpace.m,
            vertical: DSpace.s,
          ),
          child: Row(
            children: [
              Avatar(
                name: displayName,
                image: _avatarImage(contact.avatarPath),
                size: 36,
              ),
              const SizedBox(width: DSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.body.copyWith(color: c.textPrimary),
                    ),
                    if (contact.profileId != displayName) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.profileId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DType.caption.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _avatarImage(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      return FileImage(File(path));
    } catch (_) {
      return null;
    }
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({
    required this.contact,
    required this.displayName,
    this.onMessage,
  });

  final Contact? contact;
  final String displayName;
  final ValueChanged<String>? onMessage;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (contact == null) {
      return Container(
        color: c.thread,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.elevated,
                shape: BoxShape.circle,
                border: Border.all(color: c.borderSubtle),
              ),
              child: Icon(
                FluentIcons.person_24_regular,
                size: 30,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: DSpace.l),
            Text('Выберите контакт',
                style: DType.title.copyWith(color: c.textPrimary)),
            const SizedBox(height: DSpace.xs),
            Text('Карточка появится справа.',
                style: DType.body.copyWith(color: c.textSecondary)),
          ],
        ),
      );
    }
    return Container(
      color: c.thread,
      padding: const EdgeInsets.all(DSpace.xl2),
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(
              name: displayName,
              image: _avatarImage(contact!.avatarPath),
              size: 96,
            ),
            const SizedBox(height: DSpace.l),
            Text(
              displayName,
              style: DType.title.copyWith(color: c.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DSpace.xs),
            SelectableText(
              contact!.profileId,
              style: DType.caption.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DSpace.xl),
            if (onMessage != null)
              DesktopButton(
                label: 'Написать сообщение',
                kind: DButtonKind.filled,
                icon: FluentIcons.chat_24_regular,
                expand: true,
                onPressed: () => onMessage!(contact!.profileId),
              ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _avatarImage(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      return FileImage(File(path));
    } catch (_) {
      return null;
    }
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DSpace.xl),
        child: Text(
          query.isEmpty
              ? 'Контакты появятся после синхронизации.'
              : 'Ничего не найдено по запросу «$query».',
          textAlign: TextAlign.center,
          style: DType.caption.copyWith(color: c.textSecondary),
        ),
      ),
    );
  }
}
