// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// УПРАВЛЕНИЕ ГРУППОЙ НА ПК — КАК «УПРАВЛЕНИЕ ГРУППОЙ» В TELEGRAM DESKTOP.
///
/// 🔴 ЗАЧЕМ (28.09.2026, владелец: «нет кнопки поменять название группы у
/// админа и т. д. Я хочу, чтобы было полностью как в Телеграме»). Протокол и
/// контроллер умели всё давно: название, описание, фото, разрешения, удаление
/// группы, передачу владения. На телефоне для этого есть экраны, а на ПК не
/// было ни одного входа: карандаш у названия группы не подключён, в меню
/// только «пригласить», «звук», «выйти».
///
/// Здесь — окна. Контроллер вызывает вид группы (`room_details_view.dart`):
/// окна только спрашивают человека и возвращают ответ. Так каждое правило
/// проверяется без сети, а новый файл не тянет контроллер напрямую.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../rooms/room_models.dart';
import '../../design/tokens.dart';
import '../../primitives/avatar.dart';
import '../../primitives/desktop_button.dart';
import '../../primitives/desktop_dialog.dart';
import '../../primitives/desktop_segmented.dart';
import '../../primitives/desktop_switch.dart';
import '../../primitives/desktop_text_field.dart';
import '../outgoing_media.dart' show OutgoingMediaPrep;
import 'avatar_crop_dialog.dart';

/// Пределы — те же, что у телефона (`room_details_screen.dart`).
const int kDesktopRoomTitleMaxLength = 96;
const int kDesktopRoomDescriptionMaxLength = 240;

// ─────────────────────────────────────────────────────────────────────────
// «Изменить группу»: фото, название, описание.
// ─────────────────────────────────────────────────────────────────────────

/// Что человек задал в окне «Изменить группу».
@immutable
class RoomEditResult {
  const RoomEditResult({
    required this.title,
    required this.description,
    this.avatarBytes,
    this.clearAvatar = false,
  });

  final String title;
  final String description;

  /// Новое фото; `null` — фото не меняли.
  final Uint8List? avatarBytes;

  /// Фото убрали.
  final bool clearAvatar;
}

/// Проверка названия. `null` — годится, иначе текст ошибки.
String? validateRoomTitle(String raw, AppLocalizations l10n) {
  final t = raw.trim();
  if (t.isEmpty) return l10n.desktopRoomEditNameEmpty;
  return null;
}

Future<RoomEditResult?> showRoomEditDialog(
  BuildContext context, {
  required String groupId,
  required String title,
  required String description,
  required String? avatarPath,
}) {
  final l10n = AppLocalizations.of(context)!;
  final form = GlobalKey<_RoomEditFormState>();
  return DesktopDialog.show<RoomEditResult>(
    context,
    title: l10n.desktopRoomEditTitle,
    size: DDialogSize.medium,
    body: _RoomEditForm(
      key: form,
      groupId: groupId,
      title: title,
      description: description,
      avatarPath: avatarPath,
    ),
    primary: DDialogAction(
      label: l10n.contactDetailsSave,
      onPressed: () {
        final result = form.currentState?.submit();
        if (result != null) Navigator.of(context).maybePop(result);
      },
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      kind: DButtonKind.ghost,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}

class _RoomEditForm extends StatefulWidget {
  const _RoomEditForm({
    super.key,
    required this.groupId,
    required this.title,
    required this.description,
    required this.avatarPath,
  });

  final String groupId;
  final String title;
  final String description;
  final String? avatarPath;

  @override
  State<_RoomEditForm> createState() => _RoomEditFormState();
}

class _RoomEditFormState extends State<_RoomEditForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.title);
  late final TextEditingController _description =
      TextEditingController(text: widget.description);
  Uint8List? _pickedBytes;
  bool _cleared = false;
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Проверить и собрать ответ; `null` — есть ошибка, окно не закрываем.
  RoomEditResult? submit() {
    final l10n = AppLocalizations.of(context)!;
    final error = validateRoomTitle(_title.text, l10n);
    if (error != null) {
      setState(() => _titleError = error);
      return null;
    }
    return RoomEditResult(
      title: _title.text.trim(),
      description: _description.text.trim(),
      avatarBytes: _pickedBytes,
      clearAvatar: _cleared && _pickedBytes == null,
    );
  }

  Future<void> _pickPhoto() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    final file = picked?.files.firstOrNull;
    if (file == null || !mounted) return;
    final path = file.path;
    // HEIC с iPhone — через системную перекодировку; затем кадрирование,
    // как у портрета группы в правой панели (29.09.2026).
    final bytes = path == null
        ? file.bytes
        : await OutgoingMediaPrep.decodableImageBytes(path);
    if (bytes == null || bytes.isEmpty || !mounted) return;
    Uint8List? cropped;
    try {
      cropped = await showDesktopAvatarCropDialog(
        context,
        bytes: bytes,
        round: false,
      );
    } on FormatException {
      return;
    }
    if (cropped == null || !mounted) return;
    setState(() {
      _pickedBytes = cropped;
      _cleared = false;
    });
  }

  bool get _hasPhoto {
    if (_pickedBytes != null) return true;
    if (_cleared) return false;
    final path = widget.avatarPath?.trim() ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  ImageProvider? get _image {
    final bytes = _pickedBytes;
    if (bytes != null) return MemoryImage(bytes);
    if (_cleared) return null;
    final path = widget.avatarPath?.trim() ?? '';
    if (path.isEmpty || !File(path).existsSync()) return null;
    return Avatar.fileImage(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Avatar(
              name: _title.text.trim().isEmpty ? widget.title : _title.text,
              seed: widget.groupId,
              image: _image,
              size: 72,
              shape: AvatarShape.room,
            ),
            const SizedBox(width: DSpace.l),
            Expanded(
              child: Wrap(
                spacing: DSpace.s,
                runSpacing: DSpace.s,
                children: [
                  DesktopButton(
                    label: l10n.desktopRoomEditPhotoChoose,
                    icon: FluentIcons.image_24_regular,
                    kind: DButtonKind.tonal,
                    size: DButtonSize.small,
                    onPressed: _pickPhoto,
                  ),
                  if (_hasPhoto)
                    DesktopButton(
                      label: l10n.desktopRoomEditPhotoRemove,
                      icon: FluentIcons.delete_24_regular,
                      kind: DButtonKind.ghost,
                      size: DButtonSize.small,
                      onPressed: () => setState(() {
                        _pickedBytes = null;
                        _cleared = true;
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DSpace.l),
        Text(
          l10n.desktopRoomEditName,
          style: DType.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: DSpace.xs),
        DesktopTextField(
          controller: _title,
          autofocus: true,
          hintText: l10n.desktopRoomEditNameHint,
          maxLength: kDesktopRoomTitleMaxLength,
          onChanged: (_) {
            if (_titleError != null) setState(() => _titleError = null);
            setState(() {});
          },
        ),
        if (_titleError != null) ...[
          const SizedBox(height: DSpace.xs),
          Text(
            _titleError!,
            style: DType.caption.copyWith(color: c.danger),
          ),
        ],
        const SizedBox(height: DSpace.m),
        Text(
          l10n.desktopRoomEditDescription,
          style: DType.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: DSpace.xs),
        DesktopTextField(
          controller: _description,
          hintText: l10n.desktopRoomEditDescriptionHint,
          minLines: 2,
          maxLines: 5,
          maxLength: kDesktopRoomDescriptionMaxLength,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// «Разрешения участников».
// ─────────────────────────────────────────────────────────────────────────

/// Ступени медленного режима — те же, что у телефона.
const List<int> kDesktopRoomSlowModeSteps = <int>[
  0,
  5,
  10,
  30,
  60,
  5 * 60,
  15 * 60,
  60 * 60,
];

/// Подпись ступени медленного режима.
String roomSlowModeLabel(int seconds, AppLocalizations l10n) {
  if (seconds <= 0) return l10n.desktopRoomSlowOff;
  if (seconds < 60) return l10n.desktopRoomSlowSeconds(seconds);
  if (seconds < 3600) return l10n.desktopRoomSlowMinutes(seconds ~/ 60);
  return l10n.desktopRoomSlowHours(seconds ~/ 3600);
}

Future<RoomSettings?> showRoomPermissionsDialog(
  BuildContext context, {
  required RoomSettings settings,
}) {
  final l10n = AppLocalizations.of(context)!;
  final form = GlobalKey<_RoomPermissionsFormState>();
  return DesktopDialog.show<RoomSettings>(
    context,
    title: l10n.desktopRoomPermissionsTitle,
    size: DDialogSize.medium,
    body: _RoomPermissionsForm(key: form, settings: settings),
    primary: DDialogAction(
      label: l10n.contactDetailsSave,
      onPressed: () {
        final next = form.currentState?.value;
        if (next != null) Navigator.of(context).maybePop(next);
      },
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      kind: DButtonKind.ghost,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}

class _RoomPermissionsForm extends StatefulWidget {
  const _RoomPermissionsForm({super.key, required this.settings});

  final RoomSettings settings;

  @override
  State<_RoomPermissionsForm> createState() => _RoomPermissionsFormState();
}

class _RoomPermissionsFormState extends State<_RoomPermissionsForm> {
  late RoomSettings value = widget.settings;

  void _set(RoomSettings next) => setState(() => value = next);

  Widget _section(String title, List<Widget> rows) {
    final c = DColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: DType.caption.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DSpace.xs),
          ...rows,
        ],
      ),
    );
  }

  Widget _toggle(
    String label,
    bool on,
    ValueChanged<bool> onChanged, {
    String? hint,
  }) {
    final c = DColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DType.body.copyWith(color: c.textPrimary)),
                if (hint != null)
                  Text(
                    hint,
                    style: DType.caption.copyWith(color: c.textTertiary),
                  ),
              ],
            ),
          ),
          DesktopSwitch(value: on, onChanged: onChanged),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final s = value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(l10n.desktopRoomPermMembersSection, [
          _toggle(l10n.desktopRoomPermSendText, s.allowTextMessages,
              (v) => _set(s.copyWith(allowTextMessages: v))),
          _toggle(l10n.desktopRoomPermSendMedia, s.allowMedia,
              (v) => _set(s.copyWith(allowMedia: v))),
          _toggle(l10n.desktopRoomPermPin, s.allowPinMessages,
              (v) => _set(s.copyWith(allowPinMessages: v))),
          _toggle(l10n.desktopRoomPermAddMembers, s.allowAddMembers,
              (v) => _set(s.copyWith(allowAddMembers: v))),
          _toggle(l10n.desktopRoomPermChangeInfo, s.allowChangeGroupInfo,
              (v) => _set(s.copyWith(allowChangeGroupInfo: v))),
          _toggle(l10n.desktopRoomPermChangeTag, s.allowChangeTag,
              (v) => _set(s.copyWith(allowChangeTag: v))),
        ]),
        _section(l10n.desktopRoomPermJoinSection, [
          _toggle(l10n.desktopRoomPermApproval, s.joinApprovalRequired,
              (v) => _set(s.copyWith(joinApprovalRequired: v))),
          _toggle(
            l10n.desktopRoomPermHistory,
            s.chatHistoryVisible,
            (v) => _set(s.copyWith(chatHistoryVisible: v)),
            hint: l10n.desktopRoomPermHistoryHint,
          ),
        ]),
        _section(l10n.desktopRoomPermReactions, [
          DesktopSegmented<RoomReactionsMode>(
            values: const [
              RoomReactionsMode.all,
              RoomReactionsMode.selected,
              RoomReactionsMode.none,
            ],
            labels: [
              l10n.desktopRoomReactionsAll,
              l10n.desktopRoomReactionsSome,
              l10n.desktopRoomReactionsNone,
            ],
            value: s.reactionsMode,
            onChanged: (m) => _set(s.copyWith(reactionsMode: m)),
          ),
        ]),
        _section(l10n.desktopRoomPermSlowMode, [
          Text(
            l10n.desktopRoomPermSlowModeHint,
            style: DType.caption.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: DSpace.s),
          Wrap(
            spacing: DSpace.xs,
            runSpacing: DSpace.xs,
            children: [
              for (final step in kDesktopRoomSlowModeSteps)
                DesktopButton(
                  label: roomSlowModeLabel(step, l10n),
                  size: DButtonSize.small,
                  kind: s.slowModeSeconds == step
                      ? DButtonKind.filled
                      : DButtonKind.ghost,
                  onPressed: () => _set(s.copyWith(slowModeSeconds: step)),
                ),
            ],
          ),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Выход владельца: передать группу или удалить её.
// ─────────────────────────────────────────────────────────────────────────

/// Что выбрал владелец, уходя из группы.
@immutable
class RoomOwnerLeaveChoice {
  const RoomOwnerLeaveChoice.transfer(this.nextOwner) : delete = false;
  const RoomOwnerLeaveChoice.delete()
      : nextOwner = null,
        delete = true;

  final RoomMember? nextOwner;
  final bool delete;
}

/// Кому можно передать группу: активные участники, кроме себя; админы
/// первыми — им группу отдают чаще всего.
List<RoomMember> roomOwnershipCandidates(
  List<RoomMember> members, {
  required String selfProfileId,
}) {
  final self = selfProfileId.trim();
  final out = members
      .where((m) => m.isActive && m.profileId != self && !m.isGuest)
      .toList();
  out.sort((a, b) {
    int rank(RoomMember m) => m.isAdmin
        ? 0
        : m.isModerator
            ? 1
            : 2;
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return out;
}

Future<RoomOwnerLeaveChoice?> showRoomOwnerLeaveDialog(
  BuildContext context, {
  required List<RoomMember> candidates,
  required String Function(RoomMember) nameOf,
}) {
  final l10n = AppLocalizations.of(context)!;
  final form = GlobalKey<_OwnerLeaveFormState>();
  return DesktopDialog.show<RoomOwnerLeaveChoice>(
    context,
    title: l10n.desktopRoomOwnerLeaveTitle,
    size: DDialogSize.medium,
    body: _OwnerLeaveForm(
      key: form,
      candidates: candidates,
      nameOf: nameOf,
      onDelete: () => Navigator.of(context)
          .maybePop(const RoomOwnerLeaveChoice.delete()),
    ),
    primary: candidates.isEmpty
        ? null
        : DDialogAction(
            label: l10n.desktopRoomOwnerLeaveTransfer,
            kind: DButtonKind.danger,
            onPressed: () {
              final picked = form.currentState?.picked;
              if (picked == null) return;
              Navigator.of(context)
                  .maybePop(RoomOwnerLeaveChoice.transfer(picked));
            },
          ),
    secondary: DDialogAction(
      label: l10n.cancel,
      kind: DButtonKind.ghost,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}

class _OwnerLeaveForm extends StatefulWidget {
  const _OwnerLeaveForm({
    super.key,
    required this.candidates,
    required this.nameOf,
    required this.onDelete,
  });

  final List<RoomMember> candidates;
  final String Function(RoomMember) nameOf;
  final VoidCallback onDelete;

  @override
  State<_OwnerLeaveForm> createState() => _OwnerLeaveFormState();
}

class _OwnerLeaveFormState extends State<_OwnerLeaveForm> {
  RoomMember? picked;

  @override
  void initState() {
    super.initState();
    // Первый кандидат уже отмечен: чаще всего группу отдают админу.
    picked = widget.candidates.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.candidates.isEmpty
              ? l10n.desktopRoomOwnerLeaveNoMembers
              : l10n.desktopRoomOwnerLeaveBody,
          style: DType.body.copyWith(color: c.textSecondary, height: 1.45),
        ),
        const SizedBox(height: DSpace.m),
        if (widget.candidates.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in widget.candidates)
                  InkWell(
                    borderRadius: BorderRadius.circular(DRadii.md),
                    onTap: () => setState(() => picked = m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DSpace.s,
                        vertical: DSpace.xs,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            picked?.profileId == m.profileId
                                ? FluentIcons.radio_button_24_filled
                                : FluentIcons.radio_button_24_regular,
                            size: 18,
                            color: picked?.profileId == m.profileId
                                ? c.accentPrimary
                                : c.textTertiary,
                          ),
                          const SizedBox(width: DSpace.s),
                          Avatar(
                            name: widget.nameOf(m),
                            seed: m.profileId,
                            image: Avatar.fileImage(m.avatarPath),
                            size: 28,
                          ),
                          const SizedBox(width: DSpace.s),
                          Expanded(
                            child: Text(
                              widget.nameOf(m),
                              overflow: TextOverflow.ellipsis,
                              style: DType.body.copyWith(color: c.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: DSpace.m),
        Align(
          alignment: Alignment.centerLeft,
          child: DesktopButton(
            label: l10n.desktopRoomDelete,
            icon: FluentIcons.delete_24_regular,
            kind: DButtonKind.ghost,
            size: DButtonSize.small,
            onPressed: widget.onDelete,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Добавить участников (ТЗ «ПК как Telegram» §2).
// ─────────────────────────────────────────────────────────────────────────

/// Кого можно позвать в комнату: контакт человека.
@immutable
class RoomAddCandidate {
  const RoomAddCandidate({
    required this.profileId,
    required this.name,
    this.avatarPath,
    this.online = false,
    this.inRoom = false,
  });

  final String profileId;
  final String name;
  final String? avatarPath;
  final bool online;

  /// Уже участник — строка видна, но выбрать её нельзя.
  final bool inRoom;
}

/// Окно выбора людей из контактов. Ответ — выбранные Secretly ID; `null` —
/// передумал. Сам вызов `addGroupMembers` — у вида комнаты.
Future<Set<String>?> showRoomAddMembersDialog(
  BuildContext context, {
  required List<RoomAddCandidate> candidates,
}) {
  final l10n = AppLocalizations.of(context)!;
  final picked = ValueNotifier<Set<String>>(<String>{});
  return DesktopDialog.show<Set<String>>(
    context,
    title: l10n.desktopRoomAddMembers,
    size: DDialogSize.medium,
    body: _AddMembersForm(candidates: candidates, picked: picked),
    primary: DDialogAction(
      label: l10n.desktopRoomAddMembers,
      onPressed: () {
        if (picked.value.isEmpty) return;
        Navigator.of(context).maybePop(Set<String>.of(picked.value));
      },
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      kind: DButtonKind.ghost,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  ).whenComplete(picked.dispose);
}

class _AddMembersForm extends StatefulWidget {
  const _AddMembersForm({required this.candidates, required this.picked});

  final List<RoomAddCandidate> candidates;
  final ValueNotifier<Set<String>> picked;

  @override
  State<_AddMembersForm> createState() => _AddMembersFormState();
}

class _AddMembersFormState extends State<_AddMembersForm> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<RoomAddCandidate> get _visible {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.candidates;
    return widget.candidates
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.profileId.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  void _toggle(RoomAddCandidate c) {
    if (c.inRoom) return;
    final next = Set<String>.of(widget.picked.value);
    next.contains(c.profileId) ? next.remove(c.profileId) : next.add(c.profileId);
    setState(() => widget.picked.value = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    if (widget.candidates.isEmpty) {
      return Text(
        l10n.desktopRoomAddMembersNoContacts,
        style: DType.body.copyWith(color: c.textSecondary, height: 1.45),
      );
    }
    final visible = _visible;
    final picked = widget.picked.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesktopTextField(
          controller: _query,
          autofocus: true,
          hintText: l10n.desktopRoomAddMembersSearch,
          prefixIcon: FluentIcons.search_24_regular,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: DSpace.s),
        SizedBox(
          height: 320,
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    l10n.desktopRoomAddMembersNone,
                    style: DType.body.copyWith(color: c.textTertiary),
                  ),
                )
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (ctx, i) {
                    final m = visible[i];
                    final checked = picked.contains(m.profileId);
                    return Semantics(
                      container: true,
                      button: !m.inRoom,
                      checked: m.inRoom ? null : checked,
                      enabled: !m.inRoom,
                      label: m.name,
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(DRadii.md),
                        onTap: m.inRoom ? null : () => _toggle(m),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DSpace.s,
                            vertical: DSpace.xs,
                          ),
                          child: Row(
                            children: [
                              Avatar(
                                name: m.name,
                                seed: m.profileId,
                                image: Avatar.fileImage(m.avatarPath),
                                size: 34,
                                online: m.online,
                              ),
                              const SizedBox(width: DSpace.s),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      m.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DType.body.copyWith(
                                        color: m.inRoom
                                            ? c.textTertiary
                                            : c.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      m.inRoom
                                          ? l10n.desktopRoomAddMembersAlready
                                          : m.profileId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DType.caption.copyWith(
                                        color: c.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: DSpace.s),
                              Icon(
                                m.inRoom || checked
                                    ? FluentIcons.checkmark_circle_24_filled
                                    : FluentIcons.circle_24_regular,
                                size: 20,
                                color: m.inRoom
                                    ? c.textTertiary.withValues(alpha: 0.5)
                                    : (checked ? c.accentPrimary : c.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (picked.isNotEmpty) ...[
          const SizedBox(height: DSpace.s),
          Text(
            l10n.desktopRoomAddMembersAction(picked.length),
            style: DType.label.copyWith(color: c.accentPrimary),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Недавние действия (журнал комнаты, как «Журнал действий» телефона).
// ─────────────────────────────────────────────────────────────────────────

Future<void> showRoomAuditLogDialog(
  BuildContext context, {
  required List<({int createdAtMs, String text})> entries,
  required String Function(int ms) timeLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  return DesktopDialog.show<void>(
    context,
    title: l10n.desktopRoomAuditLog,
    size: DDialogSize.medium,
    body: _AuditLogBody(entries: entries, timeLabel: timeLabel),
    secondary: DDialogAction(
      label: l10n.desktopPairClose,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}

class _AuditLogBody extends StatelessWidget {
  const _AuditLogBody({required this.entries, required this.timeLabel});

  final List<({int createdAtMs, String text})> entries;
  final String Function(int ms) timeLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          entries.isEmpty ? l10n.desktopRoomAuditLogEmpty : l10n.desktopRoomAuditLogHint,
          style: DType.body.copyWith(color: c.textSecondary, height: 1.45),
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: DSpace.m),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  Container(height: 1, color: c.borderHairline),
              itemBuilder: (ctx, i) {
                final e = entries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: DSpace.s),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          FluentIcons.history_24_regular,
                          size: 16,
                          color: c.textTertiary,
                        ),
                      ),
                      const SizedBox(width: DSpace.s),
                      Expanded(
                        child: Text(
                          e.text,
                          style: DType.body.copyWith(color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(width: DSpace.s),
                      Text(
                        timeLabel(e.createdAtMs),
                        style: DType.caption.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Старше ли [actor] участника [target] настолько, чтобы исключить или
/// заблокировать его, — то же правило, что у контроллера
/// (`_canModerateRoomMember`): владелец — всех, админ — всех, кроме админов,
/// модератор — только рядовых, прочие — никого. Владельца не трогает никто.
bool roomRoleOutranks(RoomMemberRole actor, RoomMemberRole target) {
  if (target == RoomMemberRole.owner) return false;
  return switch (actor) {
    RoomMemberRole.owner => true,
    RoomMemberRole.admin => target != RoomMemberRole.admin,
    RoomMemberRole.moderator =>
      target == RoomMemberRole.member ||
          target == RoomMemberRole.restricted ||
          target == RoomMemberRole.guest,
    RoomMemberRole.member ||
    RoomMemberRole.restricted ||
    RoomMemberRole.guest => false,
  };
}
