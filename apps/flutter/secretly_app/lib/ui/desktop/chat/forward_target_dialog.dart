// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../app/app_controller.dart';
import '../design/colors.dart';
import '../design/radii.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../primitives/avatar.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_text_field.dart';
import '../primitives/hover_listener.dart';

/// Desktop «Переслать…» target picker.
///
/// Mirrors the role of the mobile `ForwardTargetPickerScreen`, but as a
/// desktop-native dialog: searchable, keyboard-first, and mouse-hover aware
/// instead of a full-screen route.
///
/// Returns the chosen [Conversation], or `null` if the user cancelled.
class ForwardTargetDialog extends StatefulWidget {
  const ForwardTargetDialog({
    super.key,
    required this.controller,
    this.excludeConvoId,
  });

  final AppController controller;

  /// The conversation the message is being forwarded FROM. Forwarding into the
  /// same chat is pointless, so it is filtered out of the list.
  final String? excludeConvoId;

  /// Opens the picker. Resolves to the chosen conversation or `null`.
  /// [title] — зачем открыли окно. По умолчанию «Переслать в…», но тем же
  /// окном выбирают переписку и для избранного: список всех переписок с
  /// поиском уже написан, и второй такой же был бы копией.
  static Future<Conversation?> show(
    BuildContext context, {
    required AppController controller,
    String? excludeConvoId,
    String? title,
  }) {
    return DesktopDialog.show<Conversation>(
      context,
      title: title ?? AppLocalizations.of(context)!.desktopForwardTitle,
      size: DDialogSize.medium,
      body: ForwardTargetDialog(
        controller: controller,
        excludeConvoId: excludeConvoId,
      ),
      secondary: DDialogAction(
        label: AppLocalizations.of(context)!.cancel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  @override
  State<ForwardTargetDialog> createState() => _ForwardTargetDialogState();
}

class _ForwardTargetDialogState extends State<ForwardTargetDialog> {
  final TextEditingController _search = TextEditingController();
  List<Conversation> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final convos = await widget.controller.listConversations();
      if (!mounted) return;
      final exclude = widget.excludeConvoId;
      final usable = convos
          .where((c) => c.convoId != exclude)
          // Archived chats are not sensible forward targets.
          .where((c) => c.archivedAtMs == null)
          .toList(growable: false);
      setState(() {
        _all = usable;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Conversation> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final list = q.isEmpty
        ? _all
        : _all
              .where((c) => c.title.toLowerCase().contains(q))
              .toList(growable: false);
    // Most-recently-active first — the likely target is near the top.
    final sorted = List<Conversation>.from(list)
      ..sort((a, b) => b.lastEventAtMs.compareTo(a.lastEventAtMs));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return SizedBox(
      height: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopTextField(
            controller: _search,
            hintText: l10n.desktopForwardSearchHint,
            prefixIcon: FluentIcons.search_24_regular,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: DSpace.m),
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(c.accentPrimary),
                      ),
                    ),
                  )
                : _buildList(c),
          ),
        ],
      ),
    );
  }

  Widget _buildList(DColorSet c) {
    final l10n = AppLocalizations.of(context)!;
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _search.text.trim().isEmpty
              ? l10n.desktopForwardNoChats
              : l10n.desktopListNothingFound,
          style: TextStyle(
            fontFamily: DType.family,
            fontSize: 13,
            color: c.textSecondary,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (ctx, i) => _row(c, items[i]),
    );
  }

  Widget _row(DColorSet c, Conversation convo) {
    final l10n = AppLocalizations.of(context)!;
    final isGroup = convo.peerProfileId == null;
    return HoverListener(
      onTap: () => Navigator.of(context).maybePop(convo),
      builder: (ctx, hovered, pressed) => Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: DSpace.s),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: pressed ? c.pressed : (hovered ? c.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(DRadii.md),
        ),
        child: Row(
          children: [
            Avatar(
              name: convo.title,
              image: Avatar.fileImage(convo.avatarPath),
              size: 36,
              frameId: convo.frameId,
              // 🔴 Здесь форма важнее, чем где-либо ещё: пересылка
              // необратима, и отличить «человеку» от «в комнату» надо
              // ДО нажатия, а не по последствиям.
              shape: isGroup ? AvatarShape.room : AvatarShape.round,
            ),
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    convo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isGroup ? l10n.desktopSpotlightRoom : l10n.desktopForwardKindDirect,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: 11,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (hovered)
              Icon(
                FluentIcons.send_24_regular,
                size: 18,
                color: c.accentPrimary,
              ),
          ],
        ),
      ),
    );
  }
}
