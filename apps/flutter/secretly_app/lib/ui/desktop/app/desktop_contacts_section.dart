// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../app/app_controller.dart';
import '../../../security/qr_payload.dart';
import '../../contact_action_error_text.dart';
import 'contact_rename.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_snackbar.dart';
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
/// Что человек вставил в поле «добавить контакт» — и какой из этого ID.
///
/// 🔴 ТРИ ФОРМЫ ОДНОГО И ТОГО ЖЕ, И ЧЕЛОВЕК НЕ ОБЯЗАН ИХ РАЗЛИЧАТЬ.
/// Секретли-ID ходит по свету в трёх видах: сам по себе, ссылкой-приглашением
/// (`secretly://profile/…` или `https://links.secretlyapp.com/profile/…`) и
/// содержимым QR-кода (`secretly_id=…&nickname=…`). Человек вставляет то, что
/// ему прислали, и поле, принимающее только первую форму, отвечало бы «такого
/// ID нет» на совершенно правильную ссылку.
///
/// Порядок разбора не случаен: ссылка проверяется ПЕРВОЙ, потому что её
/// содержимое (`?profile=…`) разобрал бы и разборщик QR, но неверно.
@visibleForTesting
String? resolveDesktopContactInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    final fromLink = tryParseProfileShareUri(uri);
    if (fromLink != null && fromLink.isNotEmpty) return fromLink;
  }

  final fromQr = (QrPayload.tryParse(text).secretlyId ?? '').trim();
  if (fromQr.isNotEmpty) return fromQr;

  // Ни ссылка, ни QR — значит сам ID. Проверять его здесь нечем и не надо:
  // это делает `addContact`, спрашивая сервер ключей, и делает честнее любой
  // проверки по виду строки.
  return text;
}

/// Имя из вставленного, если оно там было.
///
/// QR и ссылка-приглашение несут ник отправителя. Подставить его в поле имени
/// — не догадка за человека: он это имя УЖЕ видел в приглашении, и пустое
/// поле после вставки выглядело бы так, будто половина данных потерялась.
@visibleForTesting
String? resolveDesktopContactName(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final fromQr = (QrPayload.tryParse(text).nickname ?? '').trim();
  if (fromQr.isNotEmpty) return fromQr;
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    for (final key in const ['name', 'nickname', 'displayName']) {
      final v = (uri.queryParameters[key] ?? '').trim();
      if (v.isNotEmpty) return v;
    }
  }
  return null;
}

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

  /// Завести контакт: ID или ссылка-приглашение плюс необязательное имя.
  ///
  /// 🔴 ДО 21.09.2026 ЭТОГО НА КОМПЬЮТЕРЕ НЕ БЫЛО ВООБЩЕ. Раздел умел искать
  /// среди уже известных, показать карточку и написать — то есть человек за
  /// компьютером не мог завести новое знакомство, не взяв телефон. Для
  /// ежедневного инструмента это не пробел удобства, а отсутствие входа.
  ///
  /// Сканера QR здесь нет и не будет: сканирует телефон, это направление
  /// привязки. Зато СОДЕРЖИМОЕ кода, присланное текстом, поле принимает —
  /// см. [resolveDesktopContactInput].
  Future<void> _addContact() async {
    final l10n = AppLocalizations.of(context)!;
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    // Вставили ссылку или QR с ником — имя подставляется само, но остаётся
    // правимым: своё имя для контакта человек вправе дать любое.
    var nameTouched = false;
    void syncName() {
      if (nameTouched) return;
      final guessed = resolveDesktopContactName(idCtrl.text);
      if (guessed != null && guessed != nameCtrl.text) nameCtrl.text = guessed;
    }
    idCtrl.addListener(syncName);

    final ok = await DesktopDialog.show<bool>(
      context,
      title: l10n.addContact,
      size: DDialogSize.small,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DesktopTextField(
            controller: idCtrl,
            autofocus: true,
            hintText: l10n.desktopContactsAddHint,
            prefixIcon: FluentIcons.person_add_24_regular,
          ),
          const SizedBox(height: DSpace.m),
          DesktopTextField(
            controller: nameCtrl,
            hintText: l10n.nameOptionalLabel,
            prefixIcon: FluentIcons.tag_24_regular,
            onChanged: (_) => nameTouched = true,
            onSubmitted: (_) => Navigator.of(context).maybePop(true),
          ),
        ],
      ),
      primary: DDialogAction(
        label: l10n.add,
        onPressed: () => Navigator.of(context).maybePop(true),
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        kind: DButtonKind.ghost,
        onPressed: () => Navigator.of(context).maybePop(false),
      ),
    );

    idCtrl.removeListener(syncName);
    final profileId = resolveDesktopContactInput(idCtrl.text);
    final name = nameCtrl.text.trim();
    idCtrl.dispose();
    nameCtrl.dispose();
    if (ok != true || profileId == null) return;
    if (!mounted) return;

    try {
      await widget.controller.addContact(
        profileId: profileId,
        displayName: name.isEmpty ? null : name,
        displayNameIsCustom: name.isNotEmpty,
      );
    } catch (e) {
      if (!mounted) return;
      // Те же слова, что на телефоне: «такого ID нет», «сервер недоступен».
      // Своя формулировка здесь означала бы два разных объяснения одному и
      // тому же отказу на двух экранах одного приложения.
      DesktopSnackbar.show(
        context,
        message: contactActionErrorText(l10n, e),
        kind: DSnackKind.error,
      );
      return;
    }
    if (!mounted) return;
    // Показать заведённого сразу: список перечитывается по тику управляющего,
    // но ждать его — значит оставить человека смотреть на прежний список.
    setState(() => _selectedId = profileId);
    unawaited(widget.vm.refreshNow());
    DesktopSnackbar.show(
      context,
      message: l10n.desktopContactsAdded,
      kind: DSnackKind.success,
    );
  }

  /// Своё имя для контакта — общим окном, одним на оба места, откуда
  /// переименовывают (здесь и карточка человека в переписке).
  Future<void> _renameContact(Contact contact) => showRenameContactDialog(
        context: context,
        vm: widget.vm,
        profileId: contact.profileId,
        currentName: contact.displayName,
      );

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final filtered = _filtered;

    final list = _listColumn(c, filtered);
    final selected = _selectedById(_selectedId);
    final details = _ContactDetails(
      contact: selected,
      displayName: selected == null ? '' : _displayName(selected),
      onMessage: widget.onOpenChat,
      onRename: selected == null ? null : () => unawaited(_renameContact(selected)),
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
    final l10n = AppLocalizations.of(context)!;
    final api = widget.shellApi;
    if (api != null && api.listCompact) return _compactColumn(c, api);
    return Container(
      color: c.chatList,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(DSpace.m),
            child: Row(
              children: [
                Expanded(
                  child: DesktopTextField(
                    controller: _searchCtrl,
                    hintText: l10n.desktopContactsSearchHint,
                    prefixIcon: FluentIcons.search_24_regular,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: DSpace.s),
                // Рядом с поиском, а не в шапке окна: искать среди своих и
                // заводить нового — соседние мысли, и разносить их по разным
                // углам значит заставлять искать вторую.
                // Квадратная со скруглением, а не кружок: она стоит вплотную
                // к полю поиска, и кружок рядом с полем спорит с его формой.
                DesktopIconButton(
                  icon: FluentIcons.person_add_24_regular,
                  tooltip: l10n.addContact,
                  radius: DRadii.r11,
                  bgColor: DColors.of(context).elevated,
                  onPressed: () => unawaited(_addContact()),
                ),
              ],
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
                    ? _EmptyList(
                        query: _query,
                        // Кнопка ТОЛЬКО когда список пуст сам по себе.
                        // Ничего не нашлось по слову — предлагать «добавить»
                        // значит отвечать не на тот вопрос: человек искал
                        // среди своих, а не заводил нового.
                        onAdd: _query.isEmpty
                            ? () => unawaited(_addContact())
                            : null,
                      )
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
    final l10n = AppLocalizations.of(context)!;
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
                      tooltip: l10n.desktopContactsSearchHint,
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
    this.onRename,
  });

  final Contact? contact;
  final String displayName;
  final ValueChanged<String>? onMessage;

  /// Дать контакту своё имя. `null` — строки нет вовсе: кнопка, которая
  /// ничего не открывает, учит не верить остальным кнопкам.
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            Text(l10n.desktopContactsPick,
                style: DType.title.copyWith(color: c.textPrimary)),
            const SizedBox(height: DSpace.xs),
            Text(l10n.desktopContactsCardRight,
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
                label: l10n.desktopContactsWrite,
                kind: DButtonKind.filled,
                icon: FluentIcons.chat_24_regular,
                expand: true,
                onPressed: () => onMessage!(contact!.profileId),
              ),
            if (onRename != null) ...[
              const SizedBox(height: DSpace.s),
              // Тише главного действия и ниже его: написать человеку хотят
              // каждый раз, переименовать — однажды.
              DesktopButton(
                label: l10n.desktopChatsRename,
                kind: DButtonKind.ghost,
                icon: FluentIcons.tag_24_regular,
                expand: true,
                onPressed: onRename,
              ),
            ],
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
  const _EmptyList({required this.query, this.onAdd});

  final String query;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              query.isEmpty
                  ? l10n.desktopContactsEmpty
                  : l10n.desktopContactsNothingFor(query),
              textAlign: TextAlign.center,
              style: DType.caption.copyWith(color: c.textSecondary),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: DSpace.l),
              DesktopButton(
                label: l10n.addContact,
                kind: DButtonKind.tonal,
                icon: FluentIcons.person_add_24_regular,
                onPressed: onAdd,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
